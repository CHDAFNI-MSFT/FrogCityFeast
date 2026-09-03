import { createHash } from "node:crypto";
import {
  lstat,
  open,
  readFile,
} from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { pathToFileURL } from "node:url";

import {
  apiRequest,
  findApp,
  findVersion,
  findVersionLocalization,
  query,
  requiredEnvironment,
  validateMetadata,
} from "./sync-app-store-metadata.mjs";
import {
  reviewDetailIdFromResponse,
  selectedBuildIdFromResponse,
  tokenFromEnvironment,
  waitForCandidateBuild,
} from "./inspect-app-store-candidate.mjs";

const METADATA_PATH = new URL(
  "../tools/app-store-metadata.json",
  import.meta.url,
);
const REVIEW_PATH = new URL(
  "../tools/app-store-review.json",
  import.meta.url,
);
const SCREENSHOT_MANIFEST_PATH = new URL(
  "../tools/app-store-screenshot-manifest.json",
  import.meta.url,
);
const EXPECTED_SOURCE_COMMIT =
  "cab65511405f5c6b17865d2283d4a636a59da8be";
const EXPECTED_BUILD_NUMBER = "33770597608.1";
const EXPECTED_SCREENSHOT_TYPE = "APP_IPAD_PRO_3GEN_129";
const SCREENSHOT_PROCESSING_TIMEOUT_MS = 180_000;
const SCREENSHOT_PROCESSING_DELAY_MS = 5_000;
const SCREENSHOT_REQUEST_TIMEOUT_MS = 20_000;
const SCREENSHOT_UPLOAD_TIMEOUT_MS = 60_000;

function fail(message) {
  throw new Error(message);
}

function collection(payload, label) {
  if (!Array.isArray(payload?.data)) {
    fail(`${label} response does not contain a data array.`);
  }
  return payload.data;
}

function validateResource(resource, type, label) {
  if (
    resource?.type !== type ||
    typeof resource.id !== "string" ||
    !resource.id.trim()
  ) {
    fail(`${label} response contains an invalid resource.`);
  }
  return resource;
}

function requiredProtectedValue(name) {
  const value = requiredEnvironment(name);
  if (value.includes("\r") || value.includes("\n")) {
    fail(`${name} contains unsupported line breaks.`);
  }
  return value;
}

export function reviewAttributes(environment, reviewConfiguration) {
  const contactFirstName = environment.APP_REVIEW_CONTACT_FIRST_NAME?.trim();
  const contactLastName = environment.APP_REVIEW_CONTACT_LAST_NAME?.trim();
  const contactEmail = environment.APP_REVIEW_CONTACT_EMAIL?.trim();
  const contactPhone = environment.APP_REVIEW_CONTACT_PHONE?.trim();
  for (const [name, value] of Object.entries({
    APP_REVIEW_CONTACT_FIRST_NAME: contactFirstName,
    APP_REVIEW_CONTACT_LAST_NAME: contactLastName,
    APP_REVIEW_CONTACT_EMAIL: contactEmail,
    APP_REVIEW_CONTACT_PHONE: contactPhone,
  })) {
    if (!value || value.includes("\r") || value.includes("\n")) {
      fail(`${name} is required and must occupy one line.`);
    }
  }
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(contactEmail)) {
    fail("APP_REVIEW_CONTACT_EMAIL is invalid.");
  }
  if (!/^\+[1-9]\d{7,14}$/.test(contactPhone)) {
    fail("APP_REVIEW_CONTACT_PHONE must use international E.164 format.");
  }
  if (
    reviewConfiguration.schema_version !== 1 ||
    reviewConfiguration.version !== "0.1.0" ||
    reviewConfiguration.build !== EXPECTED_BUILD_NUMBER ||
    reviewConfiguration.demo_account_required !== false ||
    typeof reviewConfiguration.notes_template !== "string"
  ) {
    fail("The App Review configuration is invalid.");
  }
  const notes = reviewConfiguration.notes_template
    .replaceAll("{VERSION}", reviewConfiguration.version)
    .replaceAll("{BUILD}", reviewConfiguration.build);
  if (
    !notes.trim() ||
    notes.includes("{VERSION}") ||
    notes.includes("{BUILD}") ||
    notes.length > 4000
  ) {
    fail("The App Review notes are incomplete or exceed 4000 characters.");
  }
  return {
    contactFirstName,
    contactLastName,
    contactPhone,
    contactEmail,
    demoAccountRequired: false,
    notes,
  };
}

function hash(buffer, algorithm) {
  return createHash(algorithm).update(buffer).digest("hex");
}

export function validateUploadOperations(operations, fileSize) {
  if (!Array.isArray(operations) || operations.length === 0) {
    fail("Apple did not provide screenshot upload operations.");
  }
  const sorted = [...operations].sort((left, right) => (
    left.offset - right.offset
  ));
  let expectedOffset = 0;
  for (const operation of sorted) {
    if (
      operation?.method !== "PUT" ||
      typeof operation.url !== "string" ||
      new URL(operation.url).protocol !== "https:" ||
      !Number.isInteger(operation.offset) ||
      !Number.isInteger(operation.length) ||
      operation.offset !== expectedOffset ||
      operation.length <= 0 ||
      !Array.isArray(operation.requestHeaders)
    ) {
      fail("Apple returned an invalid screenshot upload operation.");
    }
    for (const header of operation.requestHeaders) {
      if (
        typeof header?.name !== "string" ||
        !header.name.trim() ||
        typeof header.value !== "string" ||
        /[\r\n]/.test(header.name + header.value)
      ) {
        fail("Apple returned an invalid screenshot upload header.");
      }
    }
    expectedOffset += operation.length;
  }
  if (expectedOffset !== fileSize) {
    fail(
      `Screenshot upload operations cover ${expectedOffset} bytes; ` +
      `expected ${fileSize}.`,
    );
  }
  return sorted;
}

export async function loadScreenshotPackage(
  packagePath,
  imageDirectory,
  authoredManifest,
) {
  const packageRoot = path.resolve(path.dirname(packagePath));
  const resolvedImageDirectory = path.resolve(imageDirectory);
  if (path.dirname(resolvedImageDirectory) !== packageRoot) {
    fail("The screenshot directory is outside its release package root.");
  }
  const releasePackage = JSON.parse(await readFile(packagePath, "utf8"));
  if (
    releasePackage.schemaVersion !== 1 ||
    releasePackage.sourceCommit !== EXPECTED_SOURCE_COMMIT ||
    releasePackage.cleanTrackedWorktree !== true ||
    releasePackage.target?.width !== 2752 ||
    releasePackage.target?.height !== 2064 ||
    releasePackage.target?.transparent !== false
  ) {
    fail("The screenshot release package does not match the candidate source.");
  }
  const expectedFiles = authoredManifest.screenshots;
  if (
    !Array.isArray(expectedFiles) ||
    expectedFiles.length !== 7 ||
    !Array.isArray(releasePackage.files) ||
    releasePackage.files.length !== expectedFiles.length
  ) {
    fail("The screenshot package must contain exactly seven authored files.");
  }
  const images = [];
  for (let index = 0; index < expectedFiles.length; index += 1) {
    const expected = expectedFiles[index];
    const packaged = releasePackage.files[index];
    if (
      packaged.filename !== expected.filename ||
      packaged.id !== expected.id ||
      packaged.width !== 2752 ||
      packaged.height !== 2064 ||
      packaged.opaque !== true ||
      typeof packaged.sha256 !== "string"
    ) {
      fail(`Screenshot package entry ${index + 1} is invalid.`);
    }
    const imagePath = path.resolve(
      resolvedImageDirectory,
      packaged.filename,
    );
    if (path.dirname(imagePath) !== resolvedImageDirectory) {
      fail("A screenshot filename escapes the approved directory.");
    }
    const fileStatus = await lstat(imagePath);
    if (!fileStatus.isFile() || fileStatus.isSymbolicLink()) {
      fail(`Screenshot ${packaged.filename} is not a regular file.`);
    }
    const bytes = await readFile(imagePath);
    if (hash(bytes, "sha256") !== packaged.sha256) {
      fail(`Screenshot ${packaged.filename} failed its SHA-256 check.`);
    }
    images.push({
      filename: packaged.filename,
      path: imagePath,
      size: bytes.length,
      md5: hash(bytes, "md5"),
    });
  }
  return images;
}

async function findScreenshotSet(token, localizationId) {
  const payload = await apiRequest(
    token,
    "GET",
    `/v1/appStoreVersionLocalizations/${localizationId}` +
      `/appScreenshotSets?${query({
        "filter[screenshotDisplayType]": EXPECTED_SCREENSHOT_TYPE,
        "fields[appScreenshotSets]": "screenshotDisplayType",
        limit: 2,
      })}`,
  );
  const sets = collection(payload, "Screenshot set");
  if (sets.length > 1) {
    fail(`Expected at most one ${EXPECTED_SCREENSHOT_TYPE} screenshot set.`);
  }
  if (sets.length === 0) {
    return null;
  }
  const set = validateResource(
    sets[0],
    "appScreenshotSets",
    "Screenshot set",
  );
  if (set.attributes?.screenshotDisplayType !== EXPECTED_SCREENSHOT_TYPE) {
    fail("Apple returned the wrong screenshot display type.");
  }
  return set;
}

async function createScreenshotSet(token, localizationId) {
  const payload = await apiRequest(
    token,
    "POST",
    "/v1/appScreenshotSets",
    {
      data: {
        type: "appScreenshotSets",
        attributes: {
          screenshotDisplayType: EXPECTED_SCREENSHOT_TYPE,
        },
        relationships: {
          appStoreVersionLocalization: {
            data: {
              type: "appStoreVersionLocalizations",
              id: localizationId,
            },
          },
        },
      },
    },
  );
  return validateResource(
    payload.data,
    "appScreenshotSets",
    "Created screenshot set",
  );
}

async function listScreenshots(token, screenshotSetId) {
  const payload = await apiRequest(
    token,
    "GET",
    `/v1/appScreenshotSets/${screenshotSetId}/appScreenshots?${query({
      "fields[appScreenshots]": [
        "fileName",
        "fileSize",
        "sourceFileChecksum",
        "assetDeliveryState",
      ].join(","),
      limit: 50,
    })}`,
  );
  return collection(payload, "Screenshot").map((entry) => (
    validateResource(entry, "appScreenshots", "Screenshot")
  ));
}

function existingScreenshotsMatch(existing, images) {
  if (existing.length !== images.length) {
    return false;
  }
  return existing.every((screenshot, index) => {
    const attributes = screenshot.attributes ?? {};
    return (
      attributes.fileName === images[index].filename &&
      attributes.fileSize === images[index].size &&
      attributes.sourceFileChecksum?.toLowerCase() === images[index].md5 &&
      attributes.assetDeliveryState?.state === "COMPLETE"
    );
  });
}

async function reserveScreenshot(token, screenshotSetId, image) {
  const payload = await apiRequest(
    token,
    "POST",
    "/v1/appScreenshots",
    {
      data: {
        type: "appScreenshots",
        attributes: {
          fileSize: image.size,
          fileName: image.filename,
        },
        relationships: {
          appScreenshotSet: {
            data: {
              type: "appScreenshotSets",
              id: screenshotSetId,
            },
          },
        },
      },
    },
  );
  const screenshot = validateResource(
    payload.data,
    "appScreenshots",
    "Screenshot reservation",
  );
  return screenshot;
}

export async function readUploadPart(file, operation) {
  const bytes = Buffer.alloc(operation.length);
  let bytesRead = 0;
  while (bytesRead < operation.length) {
    const result = await file.read(
      bytes,
      bytesRead,
      operation.length - bytesRead,
      operation.offset + bytesRead,
    );
    if (result.bytesRead === 0) {
      fail("A screenshot upload part ended before its declared length.");
    }
    bytesRead += result.bytesRead;
  }
  return bytes;
}

async function uploadScreenshotParts(image, operations) {
  const file = await open(image.path, "r");
  try {
    for (const operation of operations) {
      const bytes = await readUploadPart(file, operation);
      const headers = {};
      for (const header of operation.requestHeaders) {
        headers[header.name] = header.value;
      }
      const controller = new AbortController();
      const timeout = setTimeout(() => {
        controller.abort();
      }, SCREENSHOT_UPLOAD_TIMEOUT_MS);
      let response;
      try {
        response = await fetch(operation.url, {
          method: operation.method,
          headers,
          body: bytes,
          signal: controller.signal,
        });
      } catch (error) {
        if (controller.signal.aborted) {
          fail(`Apple screenshot data upload timed out for ${image.filename}.`);
        }
        throw error;
      } finally {
        clearTimeout(timeout);
      }
      if (!response.ok) {
        fail(
          `Apple screenshot data upload failed with HTTP ` +
          `${response.status}.`,
        );
      }
    }
  } finally {
    await file.close();
  }
}

async function commitScreenshot(token, screenshotId, checksum) {
  await apiRequest(
    token,
    "PATCH",
    `/v1/appScreenshots/${screenshotId}`,
    {
      data: {
        type: "appScreenshots",
        id: screenshotId,
        attributes: {
          uploaded: true,
          sourceFileChecksum: checksum,
        },
      },
    },
  );
}

async function waitForScreenshot(
  token,
  screenshotId,
  filename,
  timeoutMs,
) {
  const payload = await apiRequest(
    token,
    "GET",
    `/v1/appScreenshots/${screenshotId}?${query({
      "fields[appScreenshots]": [
        "fileName",
        "fileSize",
        "sourceFileChecksum",
        "assetDeliveryState",
      ].join(","),
    })}`,
    undefined,
    { timeoutMs },
  );
  const screenshot = validateResource(
    payload.data,
    "appScreenshots",
    "Processed screenshot",
  );
  const state = screenshot.attributes?.assetDeliveryState?.state;
  if (state === "FAILED") {
    fail(`Apple rejected screenshot ${filename}.`);
  }
  if (!["AWAITING_UPLOAD", "UPLOAD_COMPLETE", "COMPLETE"].includes(state)) {
    fail(`Screenshot ${filename} has unknown state ${state ?? "UNKNOWN"}.`);
  }
  return screenshot;
}

async function waitForScreenshots(token, pendingScreenshots) {
  let pending = [...pendingScreenshots];
  const deadline = Date.now() + SCREENSHOT_PROCESSING_TIMEOUT_MS;
  while (pending.length > 0) {
    const nextPending = [];
    for (const pendingScreenshot of pending) {
      const remainingMs = deadline - Date.now();
      if (remainingMs <= 0) {
        fail(
          `${pending.length} screenshot uploads exceeded the processing ` +
          "deadline.",
        );
      }
      const screenshot = await waitForScreenshot(
        token,
        pendingScreenshot.id,
        pendingScreenshot.image.filename,
        Math.min(SCREENSHOT_REQUEST_TIMEOUT_MS, remainingMs),
      );
      if (screenshot.attributes.assetDeliveryState.state === "COMPLETE") {
        const image = pendingScreenshot.image;
        if (
          screenshot.attributes?.fileName !== image.filename ||
          screenshot.attributes?.fileSize !== image.size ||
          screenshot.attributes?.sourceFileChecksum?.toLowerCase() !== image.md5
        ) {
          fail(`Processed screenshot ${image.filename} failed verification.`);
        }
      } else {
        nextPending.push(pendingScreenshot);
      }
    }
    if (nextPending.length === 0) {
      return;
    }
    pending = nextPending;
    const remainingMs = deadline - Date.now();
    if (remainingMs <= 0) {
      fail(
        `${pending.length} screenshot uploads exceeded the processing ` +
        "deadline.",
      );
    }
    await new Promise((resolve) => {
      setTimeout(
        resolve,
        Math.min(SCREENSHOT_PROCESSING_DELAY_MS, remainingMs),
      );
    });
  }
}

async function deleteCreatedScreenshots(
  token,
  screenshotIds,
  screenshotSetId,
  deleteSet,
) {
  const failures = [];
  for (const screenshotId of [...screenshotIds].reverse()) {
    try {
      await apiRequest(
        token,
        "DELETE",
        `/v1/appScreenshots/${screenshotId}`,
      );
    } catch (error) {
      failures.push(`screenshot ${screenshotId}: ${error.message}`);
    }
  }
  if (deleteSet) {
    try {
      await apiRequest(
        token,
        "DELETE",
        `/v1/appScreenshotSets/${screenshotSetId}`,
      );
    } catch (error) {
      failures.push(`screenshot set ${screenshotSetId}: ${error.message}`);
    }
  }
  if (failures.length > 0) {
    fail(`Screenshot rollback was incomplete: ${failures.join("; ")}`);
  }
}

async function ensureScreenshots(token, localizationId, images) {
  let screenshotSet = await findScreenshotSet(token, localizationId);
  let setCreated = false;
  if (!screenshotSet) {
    screenshotSet = await createScreenshotSet(token, localizationId);
    setCreated = true;
  }
  const existing = await listScreenshots(token, screenshotSet.id);
  if (existingScreenshotsMatch(existing, images)) {
    return { screenshotSetId: screenshotSet.id, uploaded: 0, reused: 7 };
  }
  if (existing.length !== 0) {
    fail(
      "The existing 13-inch iPad screenshot set is incomplete or differs " +
      "from the approved release package.",
    );
  }

  const createdIds = [];
  try {
    const pendingScreenshots = [];
    for (const image of images) {
      const screenshot = await reserveScreenshot(
        token,
        screenshotSet.id,
        image,
      );
      createdIds.push(screenshot.id);
      const operations = validateUploadOperations(
        screenshot.attributes?.uploadOperations,
        image.size,
      );
      await uploadScreenshotParts(image, operations);
      await commitScreenshot(
        token,
        screenshot.id,
        image.md5,
      );
      pendingScreenshots.push({ id: screenshot.id, image });
    }
    await waitForScreenshots(
      tokenFromEnvironment(),
      pendingScreenshots,
    );
  } catch (error) {
    try {
      await deleteCreatedScreenshots(
        tokenFromEnvironment(),
        createdIds,
        screenshotSet.id,
        setCreated,
      );
    } catch (cleanupError) {
      fail(`${error.message} ${cleanupError.message}`);
    }
    throw error;
  }
  return {
    screenshotSetId: screenshotSet.id,
    uploaded: images.length,
    reused: 0,
  };
}

async function currentReviewDetail(token, versionId) {
  const response = await apiRequest(
    token,
    "GET",
    `/v1/appStoreVersions/${versionId}/relationships/appStoreReviewDetail`,
    undefined,
    { allowedStatuses: [404], includeStatus: true },
  );
  if (response.status === 404) {
    return null;
  }
  const reviewId = reviewDetailIdFromResponse(response.payload);
  if (!reviewId) {
    return null;
  }
  const payload = await apiRequest(
    token,
    "GET",
    `/v1/appStoreReviewDetails/${reviewId}?${query({
      "fields[appStoreReviewDetails]": [
        "contactFirstName",
        "contactLastName",
        "contactPhone",
        "contactEmail",
        "demoAccountRequired",
        "notes",
      ].join(","),
    })}`,
  );
  return validateResource(
    payload.data,
    "appStoreReviewDetails",
    "App Review detail",
  );
}

function reviewMatches(reviewDetail, attributes) {
  return Object.entries(attributes).every(
    ([name, value]) => reviewDetail.attributes?.[name] === value,
  );
}

async function ensureReviewDetail(
  token,
  versionId,
  attributes,
) {
  const existing = await currentReviewDetail(token, versionId);
  if (existing && reviewMatches(existing, attributes)) {
    return { id: existing.id, created: false, updated: false };
  }
  if (existing) {
    await apiRequest(
      token,
      "PATCH",
      `/v1/appStoreReviewDetails/${existing.id}`,
      {
        data: {
          type: "appStoreReviewDetails",
          id: existing.id,
          attributes,
        },
      },
    );
    return { id: existing.id, created: false, updated: true };
  }
  const payload = await apiRequest(
    token,
    "POST",
    "/v1/appStoreReviewDetails",
    {
      data: {
        type: "appStoreReviewDetails",
        attributes,
        relationships: {
          appStoreVersion: {
            data: { type: "appStoreVersions", id: versionId },
          },
        },
      },
    },
  );
  const created = validateResource(
    payload.data,
    "appStoreReviewDetails",
    "Created App Review detail",
  );
  return { id: created.id, created: true, updated: false };
}

async function ensureBuildSelected(token, versionId, buildId) {
  const selectedId = await currentSelectedBuildId(token, versionId);
  if (selectedId === buildId) {
    return false;
  }
  if (selectedId) {
    fail("A different build is already selected for version 0.1.0.");
  }
  await apiRequest(
    token,
    "PATCH",
    `/v1/appStoreVersions/${versionId}/relationships/build`,
    { data: { type: "builds", id: buildId } },
  );
  return true;
}

async function currentSelectedBuildId(token, versionId) {
  const response = await apiRequest(
    token,
    "GET",
    `/v1/appStoreVersions/${versionId}/relationships/build`,
    undefined,
    { allowedStatuses: [404], includeStatus: true },
  );
  const selectedId = response.status === 404
    ? null
    : selectedBuildIdFromResponse(response.payload);
  return selectedId;
}

async function main() {
  const metadata = validateMetadata(
    JSON.parse(await readFile(METADATA_PATH, "utf8")),
  );
  const reviewConfiguration = JSON.parse(
    await readFile(REVIEW_PATH, "utf8"),
  );
  const authoredManifest = JSON.parse(
    await readFile(SCREENSHOT_MANIFEST_PATH, "utf8"),
  );
  const packagePath = requiredEnvironment(
    "APP_STORE_SCREENSHOT_PACKAGE",
  );
  const imageDirectory = requiredEnvironment(
    "APP_STORE_SCREENSHOT_DIRECTORY",
  );
  const buildNumber = requiredEnvironment("IOS_BUILD_NUMBER");
  if (buildNumber !== EXPECTED_BUILD_NUMBER) {
    fail(`Only candidate build ${EXPECTED_BUILD_NUMBER} may be prepared.`);
  }
  const contactEnvironment = {};
  for (const name of [
    "APP_REVIEW_CONTACT_FIRST_NAME",
    "APP_REVIEW_CONTACT_LAST_NAME",
    "APP_REVIEW_CONTACT_EMAIL",
    "APP_REVIEW_CONTACT_PHONE",
  ]) {
    contactEnvironment[name] = requiredProtectedValue(name);
  }
  const attributes = reviewAttributes(
    contactEnvironment,
    reviewConfiguration,
  );
  const images = await loadScreenshotPackage(
    packagePath,
    imageDirectory,
    authoredManifest,
  );
  const token = tokenFromEnvironment();
  const bundleId = requiredEnvironment("IOS_BUNDLE_ID");
  const app = await findApp(token, bundleId);
  const version = await findVersion(token, app.id, metadata);
  if (
    !version ||
    version.attributes?.versionString !== metadata.version ||
    version.attributes?.releaseType !== "MANUAL"
  ) {
    fail("The editable manual-release App Store version was not found.");
  }
  const localization = await findVersionLocalization(
    token,
    version.id,
    metadata,
  );
  if (!localization) {
    fail(`${metadata.locale} App Store localization was not found.`);
  }
  const build = await waitForCandidateBuild(
    token,
    app.id,
    buildNumber,
    false,
  );
  if (
    build.attributes?.expired !== false ||
    build.attributes?.usesNonExemptEncryption !== false
  ) {
    fail("The candidate build is expired or export compliance is unresolved.");
  }
  const selectedBeforePreparation = await currentSelectedBuildId(
    token,
    version.id,
  );
  if (selectedBeforePreparation && selectedBeforePreparation !== build.id) {
    fail("A different build is already selected for version 0.1.0.");
  }

  const screenshots = await ensureScreenshots(
    token,
    localization.id,
    images,
  );
  const finalMutationToken = tokenFromEnvironment();
  const review = await ensureReviewDetail(
    finalMutationToken,
    version.id,
    attributes,
  );
  const buildSelected = await ensureBuildSelected(
    finalMutationToken,
    version.id,
    build.id,
  );

  console.log(JSON.stringify({
    result: "prepared",
    version: metadata.version,
    build: buildNumber,
    sourceCommit: EXPECTED_SOURCE_COMMIT,
    screenshots: {
      uploaded: screenshots.uploaded,
      reused: screenshots.reused,
      count: images.length,
      displayType: EXPECTED_SCREENSHOT_TYPE,
    },
    appReview: {
      configured: true,
      created: review.created,
      updated: review.updated,
      contactValuesPrinted: false,
      demoAccountRequired: false,
    },
    buildSelected,
    submissionPerformed: false,
    releasePerformed: false,
  }, null, 2));
}

if (
  process.argv[1] &&
  pathToFileURL(process.argv[1]).href === import.meta.url
) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}

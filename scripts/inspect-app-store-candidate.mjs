import { readFile } from "node:fs/promises";
import process from "node:process";
import { pathToFileURL } from "node:url";

import {
  apiRequest,
  createToken,
  findApp,
  findVersionByString,
  findVersionLocalization,
  query,
  requiredEnvironment,
  validateMetadata,
} from "./sync-app-store-metadata.mjs";

const METADATA_PATH = new URL(
  "../tools/app-store-metadata.json",
  import.meta.url,
);
const BUILD_NUMBER_PATTERN = /^\d+\.\d+$/;
const EXPECTED_BUILD_NUMBER = "33770597608.1";
const EXPECTED_SCREENSHOT_TYPE = "APP_IPAD_PRO_3GEN_129";
const EXPECTED_SCREENSHOT_COUNT = 7;
const MAX_PROCESSING_ATTEMPTS = 45;
const PROCESSING_DELAY_MS = 20_000;

function fail(message) {
  throw new Error(message);
}

function collection(payload, label) {
  if (!Array.isArray(payload?.data)) {
    fail(`${label} response does not contain a data array.`);
  }
  return payload.data;
}

export function selectCandidateBuild(payload, expectedBuildNumber) {
  const builds = collection(payload, "Build");
  if (builds.length > 1) {
    fail(
      `Expected at most one build ${expectedBuildNumber}; found ` +
      `${builds.length}.`,
    );
  }
  if (builds.length === 0) {
    return null;
  }
  const build = builds[0];
  if (
    build?.type !== "builds" ||
    typeof build.id !== "string" ||
    !build.id.trim()
  ) {
    fail("The build response contains an invalid resource.");
  }
  if (build.attributes?.version !== expectedBuildNumber) {
    fail(
      `Apple returned build ${build.attributes?.version ?? "UNKNOWN"}; ` +
      `expected ${expectedBuildNumber}.`,
    );
  }
  const processingState = build.attributes?.processingState;
  if (
    !["PROCESSING", "FAILED", "INVALID", "VALID"].includes(
      processingState,
    )
  ) {
    fail(
      `Build ${expectedBuildNumber} has an unknown processing state ` +
      `${processingState ?? "UNKNOWN"}.`,
    );
  }
  return build;
}

export function summarizeReviewDetail(reviewDetail) {
  if (!reviewDetail) {
    return {
      exists: false,
      contactFirstNamePresent: false,
      contactLastNamePresent: false,
      contactPhonePresent: false,
      contactEmailPresent: false,
      notesPresent: false,
      demoAccountRequired: null,
      complete: false,
    };
  }
  if (
    reviewDetail.type !== "appStoreReviewDetails" ||
    typeof reviewDetail.id !== "string" ||
    !reviewDetail.id.trim()
  ) {
    fail("The App Review detail response contains an invalid resource.");
  }
  const attributes = reviewDetail.attributes ?? {};
  const present = (name) => (
    typeof attributes[name] === "string" &&
    attributes[name].trim().length > 0
  );
  const summary = {
    exists: true,
    contactFirstNamePresent: present("contactFirstName"),
    contactLastNamePresent: present("contactLastName"),
    contactPhonePresent: present("contactPhone"),
    contactEmailPresent: present("contactEmail"),
    notesPresent: present("notes"),
    demoAccountRequired: attributes.demoAccountRequired ?? null,
  };
  return {
    ...summary,
    complete: (
      summary.contactFirstNamePresent &&
      summary.contactLastNamePresent &&
      summary.contactPhonePresent &&
      summary.contactEmailPresent &&
      summary.notesPresent &&
      summary.demoAccountRequired === false
    ),
  };
}

export function summarizeScreenshots(screenshotSets) {
  if (!Array.isArray(screenshotSets)) {
    fail("Screenshot summaries must be provided as an array.");
  }
  const matchingSets = screenshotSets.filter(
    (entry) => entry.displayType === EXPECTED_SCREENSHOT_TYPE,
  );
  if (matchingSets.length > 1) {
    fail(
      `Expected at most one ${EXPECTED_SCREENSHOT_TYPE} screenshot set; ` +
      `found ${matchingSets.length}.`,
    );
  }
  const screenshots = matchingSets[0]?.screenshots ?? [];
  const completeCount = screenshots.filter(
    (entry) => entry.deliveryState === "COMPLETE",
  ).length;
  return {
    expectedDisplayType: EXPECTED_SCREENSHOT_TYPE,
    setExists: matchingSets.length === 1,
    screenshotCount: screenshots.length,
    completeCount,
    complete: (
      screenshots.length === EXPECTED_SCREENSHOT_COUNT &&
      completeCount === EXPECTED_SCREENSHOT_COUNT
    ),
  };
}

export function failForBlockers(blockers) {
  if (!Array.isArray(blockers)) {
    fail("Candidate blockers must be provided as an array.");
  }
  if (blockers.length > 0) {
    fail(
      `Candidate is not ready for submission: ${blockers.join("; ")}.`,
    );
  }
}

export function tokenFromEnvironment() {
  const keyId = requiredEnvironment("APP_STORE_CONNECT_KEY_ID");
  const issuerId = requiredEnvironment("APP_STORE_CONNECT_ISSUER_ID");
  const privateKeyBase64 = requiredEnvironment(
    "APP_STORE_CONNECT_PRIVATE_KEY_BASE64",
  );
  const privateKeyPem = Buffer.from(
    privateKeyBase64,
    "base64",
  ).toString("utf8");
  if (!privateKeyPem.includes("PRIVATE KEY")) {
    fail("APP_STORE_CONNECT_PRIVATE_KEY_BASE64 is not a private key.");
  }
  return createToken(keyId, issuerId, privateKeyPem);
}

export async function findCandidateBuild(
  token,
  appId,
  expectedBuildNumber,
) {
  const payload = await apiRequest(
    token,
    "GET",
    `/v1/builds?${query({
      "filter[app]": appId,
      "filter[version]": expectedBuildNumber,
      "fields[builds]": [
        "version",
        "uploadedDate",
        "expirationDate",
        "expired",
        "minOsVersion",
        "processingState",
        "usesNonExemptEncryption",
      ].join(","),
      limit: 2,
    })}`,
  );
  return selectCandidateBuild(payload, expectedBuildNumber);
}

export async function waitForCandidateBuild(
  token,
  appId,
  expectedBuildNumber,
  shouldWait,
) {
  const attempts = shouldWait ? MAX_PROCESSING_ATTEMPTS : 1;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    const build = await findCandidateBuild(
      token,
      appId,
      expectedBuildNumber,
    );
    if (build?.attributes?.processingState === "VALID") {
      return build;
    }
    const state = build?.attributes?.processingState ?? "NOT_FOUND";
    if (state === "FAILED" || state === "INVALID") {
      fail(`Apple processing ended with state ${state}.`);
    }
    if (attempt === attempts) {
      fail(
        `Build ${expectedBuildNumber} did not become VALID; ` +
        `last state was ${state}.`,
      );
    }
    console.log(
      `Build ${expectedBuildNumber} processing state: ${state}.`,
    );
    await new Promise((resolve) => {
      setTimeout(resolve, PROCESSING_DELAY_MS);
    });
  }
  fail(`Build ${expectedBuildNumber} processing wait ended unexpectedly.`);
}

export async function selectedBuildId(token, versionId) {
  const response = await apiRequest(
    token,
    "GET",
    `/v1/appStoreVersions/${versionId}/relationships/build`,
    undefined,
    { allowedStatuses: [404], includeStatus: true },
  );
  if (response.status === 404) {
    return null;
  }
  return selectedBuildIdFromResponse(response.payload);
}

export function selectedBuildIdFromResponse(payload) {
  const linkage = payload?.data;
  if (linkage === null) {
    return null;
  }
  if (
    linkage?.type !== "builds" ||
    typeof linkage.id !== "string" ||
    !linkage.id.trim()
  ) {
    fail("The selected-build relationship is invalid.");
  }
  return linkage.id;
}

export async function reviewDetail(token, versionId) {
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
  const reviewDetailId = reviewDetailIdFromResponse(response.payload);
  if (!reviewDetailId) {
    return null;
  }
  const payload = await apiRequest(
    token,
    "GET",
    `/v1/appStoreReviewDetails/${reviewDetailId}?${query({
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
  if (payload?.data?.id !== reviewDetailId) {
    fail("The App Review detail ID does not match its relationship.");
  }
  return payload.data;
}

export function reviewDetailIdFromResponse(payload) {
  const linkage = payload?.data;
  if (linkage === null) {
    return null;
  }
  if (
    linkage?.type !== "appStoreReviewDetails" ||
    typeof linkage.id !== "string" ||
    !linkage.id.trim()
  ) {
    fail("The App Review detail relationship is invalid.");
  }
  return linkage.id;
}

export async function screenshotSummary(token, localizationId) {
  const setsPayload = await apiRequest(
    token,
    "GET",
    `/v1/appStoreVersionLocalizations/${localizationId}` +
      `/appScreenshotSets?${query({
        "fields[appScreenshotSets]": "screenshotDisplayType",
        limit: 50,
      })}`,
  );
  const sets = collection(setsPayload, "Screenshot set");
  const summaries = [];
  for (const set of sets) {
    if (
      set?.type !== "appScreenshotSets" ||
      typeof set.id !== "string" ||
      !set.id.trim() ||
      typeof set.attributes?.screenshotDisplayType !== "string"
    ) {
      fail("A screenshot set response is invalid.");
    }
    const screenshotsPayload = await apiRequest(
      token,
      "GET",
      `/v1/appScreenshotSets/${set.id}/appScreenshots?${query({
        "fields[appScreenshots]": "assetDeliveryState",
        limit: 50,
      })}`,
    );
    const screenshots = collection(
      screenshotsPayload,
      "Screenshot",
    ).map((screenshot) => {
      if (
        screenshot?.type !== "appScreenshots" ||
        typeof screenshot.id !== "string" ||
        !screenshot.id.trim()
      ) {
        fail("A screenshot response is invalid.");
      }
      return {
        deliveryState:
          screenshot.attributes?.assetDeliveryState?.state ?? "UNKNOWN",
      };
    });
    summaries.push({
      displayType: set.attributes.screenshotDisplayType,
      screenshots,
    });
  }
  return summarizeScreenshots(summaries);
}

async function main() {
  const metadata = validateMetadata(
    JSON.parse(await readFile(METADATA_PATH, "utf8")),
  );
  const bundleId = requiredEnvironment("IOS_BUNDLE_ID");
  const buildNumber = requiredEnvironment("IOS_BUILD_NUMBER");
  if (!BUILD_NUMBER_PATTERN.test(buildNumber)) {
    fail("IOS_BUILD_NUMBER must use the workflow run ID and attempt format.");
  }
  if (buildNumber !== EXPECTED_BUILD_NUMBER) {
    fail(
      `IOS_BUILD_NUMBER must be the explicitly authorized build ` +
      `${EXPECTED_BUILD_NUMBER}.`,
    );
  }
  const token = tokenFromEnvironment();
  const app = await findApp(token, bundleId);
  const version = await findVersionByString(token, app.id, metadata);
  if (!version || version.attributes?.versionString !== metadata.version) {
    fail(`Editable App Store version ${metadata.version} was not found.`);
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
    process.argv.includes("--wait-for-processing"),
  );
  const selectedId = await selectedBuildId(token, version.id);
  const screenshots = await screenshotSummary(token, localization.id);
  const review = summarizeReviewDetail(
    await reviewDetail(token, version.id),
  );
  const blockers = [];
  if (build.attributes?.expired !== false) {
    blockers.push("candidate build is expired or expiration is unresolved");
  }
  if (build.attributes?.usesNonExemptEncryption !== false) {
    blockers.push("export-compliance encryption status is unresolved");
  }
  if (version.attributes?.releaseType !== "MANUAL") {
    blockers.push("release type is not MANUAL");
  }
  if (selectedId !== build.id) {
    blockers.push("candidate build is not selected for version 0.1.0");
  }
  if (!screenshots.complete) {
    blockers.push("the seven final iPad screenshots are not complete");
  }
  if (!review.complete) {
    blockers.push("App Review contact or notes are incomplete");
  }

  const report = {
    result: "inspected",
    version: {
      versionString: version.attributes.versionString,
      appVersionState: version.attributes.appVersionState,
      releaseType: version.attributes.releaseType,
    },
    build: {
      number: build.attributes.version,
      processingState: build.attributes.processingState,
      uploadedDate: build.attributes.uploadedDate,
      expirationDate: build.attributes.expirationDate,
      expired: build.attributes.expired,
      minOsVersion: build.attributes.minOsVersion,
      usesNonExemptEncryption:
        build.attributes.usesNonExemptEncryption ?? null,
      selectedForVersion: selectedId === build.id,
    },
    screenshots,
    appReview: review,
    apiVisibleBlockers: blockers,
    manualConfirmationsStillRequired: [
      "App Privacy questionnaire",
      "content-rights declaration",
      "free pricing and storefront availability",
      "EU Digital Services Act status",
      "physical iPad acceptance",
    ],
  };
  console.log(JSON.stringify(report, null, 2));
  failForBlockers(blockers);
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

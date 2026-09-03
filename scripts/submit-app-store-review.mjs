import { readFile } from "node:fs/promises";
import process from "node:process";
import { pathToFileURL } from "node:url";

import {
  apiRequest,
  findApp,
  findVersionByString,
  findVersionLocalization,
  query,
  requiredEnvironment,
  validateMetadata,
} from "./sync-app-store-metadata.mjs";
import {
  failForBlockers,
  reviewDetail,
  selectedBuildId,
  tokenFromEnvironment,
  waitForCandidateBuild,
} from "./inspect-app-store-candidate.mjs";
import {
  loadScreenshotPackage,
  reviewAttributes,
  screenshotVerificationMismatches,
} from "./prepare-app-store-submission.mjs";

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
const EXPECTED_BUILD_NUMBER = "33770597608.1";
const EXPECTED_SCREENSHOT_TYPE = "APP_IPAD_PRO_3GEN_129";
const BUILD_NUMBER_PATTERN = /^\d+\.\d+$/;
const SUBMISSION_PROCESSING_TIMEOUT_MS = 120_000;
const SUBMISSION_PROCESSING_DELAY_MS = 5_000;
const READY_STATE = "READY_FOR_REVIEW";
const ACTIVE_SUBMISSION_STATES = new Set([
  READY_STATE,
  "WAITING_FOR_REVIEW",
  "IN_REVIEW",
  "UNRESOLVED_ISSUES",
  "CANCELING",
  "COMPLETING",
]);
const SUBMITTED_STATES = new Set([
  "WAITING_FOR_REVIEW",
  "IN_REVIEW",
  "COMPLETING",
  "COMPLETE",
]);
const REVIEW_ITEM_STATES = new Set([
  READY_STATE,
  "ACCEPTED",
  "APPROVED",
  "REJECTED",
  "REMOVED",
]);
const SUBMITTABLE_VERSION_STATES = new Set([
  "PREPARE_FOR_SUBMISSION",
  READY_STATE,
]);

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

export function planReviewSubmission(
  submissions,
  itemsBySubmissionId,
  expectedVersionId,
) {
  if (!Array.isArray(submissions)) {
    fail("Review submissions must be provided as an array.");
  }
  if (submissions.length > 1) {
    fail(
      `Expected at most one active iOS review submission; found ` +
      `${submissions.length}.`,
    );
  }
  if (submissions.length === 0) {
    return {
      action: "create_submission",
      submissionId: null,
      state: null,
    };
  }

  const submission = submissions[0];
  validateResource(
    submission,
    "reviewSubmissions",
    "Review submission",
  );
  const state = submission.attributes?.state;
  if (!ACTIVE_SUBMISSION_STATES.has(state)) {
    fail(`Review submission has unknown active state ${state ?? "UNKNOWN"}.`);
  }
  if (state === "CANCELING" || state === "UNRESOLVED_ISSUES") {
    fail(`Review submission state ${state} requires manual attention.`);
  }
  const items = itemsBySubmissionId[submission.id];
  if (!Array.isArray(items)) {
    fail("Review submission items were not loaded.");
  }
  if (items.length > 1) {
    fail("The active review submission contains unexpected extra items.");
  }
  const itemVersionId = items[0]?.versionId ?? null;
  const itemState = items[0]?.state ?? null;
  if (items.length === 1 && itemVersionId !== expectedVersionId) {
    fail("The active review submission targets a different item.");
  }
  if (state === READY_STATE) {
    if (items.length === 1 && itemState !== READY_STATE) {
      fail(`Draft review item has unexpected state ${itemState ?? "UNKNOWN"}.`);
    }
    return {
      action: items.length === 0 ? "add_item" : "submit",
      submissionId: submission.id,
      state,
    };
  }
  if (items.length !== 1) {
    fail("The submitted review submission has no exact App Store version.");
  }
  if (!REVIEW_ITEM_STATES.has(itemState) || itemState === "REMOVED") {
    fail(`Submitted review item has invalid state ${itemState ?? "UNKNOWN"}.`);
  }
  return {
    action: "already_submitted",
    submissionId: submission.id,
    state,
  };
}

export function reviewSubmissionCreateBody(appId, platform = "IOS") {
  return {
    data: {
      type: "reviewSubmissions",
      attributes: { platform },
      relationships: {
        app: {
          data: { type: "apps", id: appId },
        },
      },
    },
  };
}

export function reviewSubmissionItemCreateBody(submissionId, versionId) {
  return {
    data: {
      type: "reviewSubmissionItems",
      relationships: {
        reviewSubmission: {
          data: { type: "reviewSubmissions", id: submissionId },
        },
        appStoreVersion: {
          data: { type: "appStoreVersions", id: versionId },
        },
      },
    },
  };
}

export function reviewSubmissionSubmitBody(submissionId) {
  return {
    data: {
      type: "reviewSubmissions",
      id: submissionId,
      attributes: {
        submitted: true,
      },
    },
  };
}

export function reviewSubmissionCancelBody(submissionId) {
  return {
    data: {
      type: "reviewSubmissions",
      id: submissionId,
      attributes: {
        canceled: true,
      },
    },
  };
}

export function reviewDetailMismatches(reviewDetailResource, expected) {
  validateResource(
    reviewDetailResource,
    "appStoreReviewDetails",
    "App Review detail",
  );
  const attributes = reviewDetailResource.attributes ?? {};
  const mismatches = [];
  for (const [name, value] of Object.entries(expected)) {
    if (attributes[name] !== value) {
      mismatches.push(name);
    }
  }
  return mismatches;
}

async function exactScreenshotSummary(token, localizationId, images) {
  const setsPayload = await apiRequest(
    token,
    "GET",
    `/v1/appStoreVersionLocalizations/${localizationId}` +
      `/appScreenshotSets?${query({
        "fields[appScreenshotSets]": "screenshotDisplayType",
        limit: 50,
      })}`,
  );
  const matchingSets = collection(
    setsPayload,
    "Screenshot set",
  ).filter((set) => {
    validateResource(set, "appScreenshotSets", "Screenshot set");
    return set.attributes?.screenshotDisplayType === EXPECTED_SCREENSHOT_TYPE;
  });
  if (matchingSets.length !== 1) {
    return { complete: false, count: 0 };
  }
  const screenshotsPayload = await apiRequest(
    token,
    "GET",
    `/v1/appScreenshotSets/${matchingSets[0].id}/appScreenshots?${query({
      "fields[appScreenshots]": [
        "fileName",
        "fileSize",
        "sourceFileChecksum",
        "assetDeliveryState",
      ].join(","),
      limit: 50,
    })}`,
  );
  const screenshots = collection(
    screenshotsPayload,
    "Screenshot",
  ).map((screenshot) => (
    validateResource(screenshot, "appScreenshots", "Screenshot")
  ));
  if (screenshots.length !== images.length) {
    return { complete: false, count: screenshots.length };
  }
  for (let index = 0; index < screenshots.length; index += 1) {
    if (
      screenshots[index].attributes?.assetDeliveryState?.state !== "COMPLETE"
    ) {
      return { complete: false, count: screenshots.length };
    }
    const mismatches = screenshotVerificationMismatches(
      screenshots[index],
      images[index],
      { allowMissingChecksum: true },
    );
    if (mismatches.length > 0) {
      return { complete: false, count: screenshots.length };
    }
  }
  return {
    complete: true,
    count: screenshots.length,
  };
}

async function candidateSnapshot(
  token,
  bundleId,
  buildNumber,
  metadata,
  images,
  expectedReviewAttributes,
) {
  const app = await findApp(token, bundleId);
  const version = await findVersionByString(token, app.id, metadata);
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
  const selectedId = await selectedBuildId(token, version.id);
  const screenshots = await exactScreenshotSummary(
    token,
    localization.id,
    images,
  );
  const reviewResource = await reviewDetail(token, version.id);
  const reviewMismatches = reviewResource
    ? reviewDetailMismatches(reviewResource, expectedReviewAttributes)
    : ["missing"];
  const review = {
    complete: reviewMismatches.length === 0,
  };
  return {
    app,
    version,
    build,
    selectedId,
    screenshots,
    review,
  };
}

function candidateBlockers(snapshot, requireSubmittableState) {
  const blockers = [];
  if (snapshot.build.attributes?.processingState !== "VALID") {
    blockers.push("candidate build is not VALID");
  }
  if (snapshot.build.attributes?.expired !== false) {
    blockers.push("candidate build is expired or expiration is unresolved");
  }
  if (snapshot.build.attributes?.usesNonExemptEncryption !== false) {
    blockers.push("export-compliance encryption status is unresolved");
  }
  if (snapshot.version.attributes?.releaseType !== "MANUAL") {
    blockers.push("release type is not MANUAL");
  }
  if (snapshot.version.attributes?.reviewType !== "APP_STORE") {
    blockers.push("review type is not APP_STORE");
  }
  if (snapshot.selectedId !== snapshot.build.id) {
    blockers.push("the exact candidate build is not selected");
  }
  if (!snapshot.screenshots.complete) {
    blockers.push("the seven final iPad screenshots are not complete");
  }
  if (!snapshot.review.complete) {
    blockers.push("App Review contact or notes are incomplete");
  }
  if (
    requireSubmittableState &&
    !SUBMITTABLE_VERSION_STATES.has(
      snapshot.version.attributes?.appVersionState,
    )
  ) {
    blockers.push("the App Store version is not ready to submit");
  }
  return blockers;
}

async function listActiveReviewSubmissions(token, appId) {
  return listReviewSubmissionsByState(
    token,
    appId,
    ACTIVE_SUBMISSION_STATES,
  );
}

async function listReviewSubmissionsByState(token, appId, states) {
  const payload = await apiRequest(
    token,
    "GET",
    `/v1/reviewSubmissions?${query({
      "filter[app]": appId,
      "filter[platform]": "IOS",
      "filter[state]": [...states].join(","),
      "fields[reviewSubmissions]": "platform,state,submittedDate",
      limit: 50,
    })}`,
  );
  return collection(payload, "Review submission").map((submission) => {
    validateResource(
      submission,
      "reviewSubmissions",
      "Review submission",
    );
    if (!states.has(submission.attributes?.state)) {
      fail("Review submission response contains an unexpected state.");
    }
    if (submission.attributes?.platform !== "IOS") {
      fail("Review submission response contains a non-iOS platform.");
    }
    return submission;
  });
}

async function getReviewSubmission(token, submissionId) {
  const payload = await apiRequest(
    token,
    "GET",
    `/v1/reviewSubmissions/${submissionId}?${query({
      "fields[reviewSubmissions]": "platform,state,submittedDate",
    })}`,
  );
  const submission = validateResource(
    payload.data,
    "reviewSubmissions",
    "Review submission",
  );
  if (submission.attributes?.platform !== "IOS") {
    fail("Review submission response contains a non-iOS platform.");
  }
  return submission;
}

async function listReviewSubmissionItems(token, submissionId) {
  const payload = await apiRequest(
    token,
    "GET",
    `/v1/reviewSubmissions/${submissionId}/items?${query({
      "fields[reviewSubmissionItems]": "state,appStoreVersion",
      include: "appStoreVersion",
      limit: 50,
    })}`,
  );
  return collection(payload, "Review submission item").map((item) => {
    validateResource(
      item,
      "reviewSubmissionItems",
      "Review submission item",
    );
    const state = item.attributes?.state;
    if (!REVIEW_ITEM_STATES.has(state)) {
      fail(
        `Review submission item has unknown state ${state ?? "UNKNOWN"}.`,
      );
    }
    const linkage = item.relationships?.appStoreVersion?.data;
    if (linkage === null) {
      return { id: item.id, state, versionId: null };
    }
    if (
      linkage?.type !== "appStoreVersions" ||
      typeof linkage.id !== "string" ||
      !linkage.id.trim()
    ) {
      fail("Review submission item has an invalid App Store version.");
    }
    return {
      id: item.id,
      state,
      versionId: linkage.id,
    };
  });
}

async function currentSubmissionPlan(token, appId, versionId) {
  const submissions = await listActiveReviewSubmissions(token, appId);
  const itemsBySubmissionId = {};
  for (const submission of submissions) {
    itemsBySubmissionId[submission.id] = await listReviewSubmissionItems(
      token,
      submission.id,
    );
  }
  return {
    submissions,
    plan: planReviewSubmission(
      submissions,
      itemsBySubmissionId,
      versionId,
    ),
  };
}

export function validateExactSubmittedSubmission(
  submission,
  items,
  expectedVersionId,
) {
  validateResource(
    submission,
    "reviewSubmissions",
    "Review submission",
  );
  const state = submission.attributes?.state;
  if (!SUBMITTED_STATES.has(state)) {
    fail(`Review submission is not submitted (${state ?? "UNKNOWN"}).`);
  }
  if (submission.attributes?.platform !== "IOS") {
    fail("Review submission response contains a non-iOS platform.");
  }
  if (!Array.isArray(items) || items.length !== 1) {
    fail("The submitted review submission must contain exactly one item.");
  }
  if (items[0].versionId !== expectedVersionId) {
    fail("The submitted review submission targets a different version.");
  }
  if (
    !REVIEW_ITEM_STATES.has(items[0].state) ||
    items[0].state === "REMOVED"
  ) {
    fail(
      `Submitted review item has invalid state ` +
      `${items[0].state ?? "UNKNOWN"}.`,
    );
  }
  return state;
}

async function completedSubmissionForVersion(token, appId, versionId) {
  const submissions = await listReviewSubmissionsByState(
    token,
    appId,
    new Set(["COMPLETE"]),
  );
  const submissionsWithItems = [];
  for (const submission of submissions) {
    const items = await listReviewSubmissionItems(token, submission.id);
    submissionsWithItems.push({ submission, items });
  }
  return selectCompletedSubmissionForVersion(
    submissionsWithItems,
    versionId,
  );
}

export function selectCompletedSubmissionForVersion(
  submissionsWithItems,
  versionId,
) {
  if (!Array.isArray(submissionsWithItems)) {
    fail("Completed review submissions must be provided as an array.");
  }
  const matches = submissionsWithItems.filter(({ items }) => (
    Array.isArray(items) &&
    items.some((item) => item.versionId === versionId)
  ));
  if (matches.length > 1) {
    fail("Multiple completed submissions target the exact App Store version.");
  }
  if (matches.length === 0) {
    return null;
  }
  validateExactSubmittedSubmission(
    matches[0].submission,
    matches[0].items,
    versionId,
  );
  return matches[0].submission;
}

async function createReviewSubmission(token, appId) {
  const payload = await apiRequest(
    token,
    "POST",
    "/v1/reviewSubmissions",
    reviewSubmissionCreateBody(appId),
  );
  const submission = validateResource(
    payload.data,
    "reviewSubmissions",
    "Created review submission",
  );
  if (submission.attributes?.state !== READY_STATE) {
    fail("Created review submission is not READY_FOR_REVIEW.");
  }
  return submission;
}

async function createReviewSubmissionItem(
  token,
  submissionId,
  versionId,
) {
  const payload = await apiRequest(
    token,
    "POST",
    "/v1/reviewSubmissionItems",
    reviewSubmissionItemCreateBody(submissionId, versionId),
  );
  return validateResource(
    payload.data,
    "reviewSubmissionItems",
    "Created review submission item",
  );
}

async function submitReviewSubmission(token, submissionId) {
  const payload = await apiRequest(
    token,
    "PATCH",
    `/v1/reviewSubmissions/${submissionId}`,
    reviewSubmissionSubmitBody(submissionId),
  );
  return validateResource(
    payload.data,
    "reviewSubmissions",
    "Submitted review submission",
  );
}

async function cancelReviewSubmission(token, submissionId) {
  const payload = await apiRequest(
    token,
    "PATCH",
    `/v1/reviewSubmissions/${submissionId}`,
    reviewSubmissionCancelBody(submissionId),
  );
  return validateResource(
    payload.data,
    "reviewSubmissions",
    "Canceled review submission",
  );
}

async function waitForSubmittedState(submissionId) {
  const deadline = Date.now() + SUBMISSION_PROCESSING_TIMEOUT_MS;
  while (true) {
    const remainingMs = deadline - Date.now();
    if (remainingMs <= 0) {
      fail("Apple did not acknowledge the review submission before timeout.");
    }
    const payload = await apiRequest(
      tokenFromEnvironment(),
      "GET",
      `/v1/reviewSubmissions/${submissionId}?${query({
        "fields[reviewSubmissions]": "platform,state,submittedDate",
      })}`,
      undefined,
      { timeoutMs: Math.min(30_000, remainingMs) },
    );
    const submission = validateResource(
      payload.data,
      "reviewSubmissions",
      "Review submission status",
    );
    const state = submission.attributes?.state;
    if (SUBMITTED_STATES.has(state)) {
      return state;
    }
    if (state !== READY_STATE) {
      fail(`Review submission entered unknown state ${state ?? "UNKNOWN"}.`);
    }
    await new Promise((resolve) => {
      setTimeout(
        resolve,
        Math.min(SUBMISSION_PROCESSING_DELAY_MS, remainingMs),
      );
    });
  }
}

function printResult(snapshot, state, submissionPerformed) {
  console.log(JSON.stringify({
    result: submissionPerformed ? "submitted" : "already_submitted",
    version: snapshot.version.attributes.versionString,
    build: snapshot.build.attributes.version,
    reviewSubmissionState: state,
    releaseType: snapshot.version.attributes.releaseType,
    submissionPerformed,
    releasePerformed: false,
  }, null, 2));
}

async function main() {
  const metadata = validateMetadata(
    JSON.parse(await readFile(METADATA_PATH, "utf8")),
  );
  const reviewConfiguration = JSON.parse(
    await readFile(REVIEW_PATH, "utf8"),
  );
  const expectedReviewAttributes = reviewAttributes(
    process.env,
    reviewConfiguration,
  );
  const authoredScreenshotManifest = JSON.parse(
    await readFile(SCREENSHOT_MANIFEST_PATH, "utf8"),
  );
  const images = await loadScreenshotPackage(
    requiredEnvironment("APP_STORE_SCREENSHOT_PACKAGE"),
    requiredEnvironment("APP_STORE_SCREENSHOT_DIRECTORY"),
    authoredScreenshotManifest,
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

  let snapshot = await candidateSnapshot(
    tokenFromEnvironment(),
    bundleId,
    buildNumber,
    metadata,
    images,
    expectedReviewAttributes,
  );
  failForBlockers(candidateBlockers(snapshot, false));
  let context = await currentSubmissionPlan(
    tokenFromEnvironment(),
    snapshot.app.id,
    snapshot.version.id,
  );
  if (context.plan.action === "already_submitted") {
    printResult(snapshot, context.plan.state, false);
    return;
  }
  if (context.plan.action === "create_submission") {
    const completedSubmission = await completedSubmissionForVersion(
      tokenFromEnvironment(),
      snapshot.app.id,
      snapshot.version.id,
    );
    if (completedSubmission) {
      printResult(snapshot, "COMPLETE", false);
      return;
    }
  }
  failForBlockers(candidateBlockers(snapshot, true));

  let submissionId = context.plan.submissionId;
  if (context.plan.action === "create_submission") {
    const submission = await createReviewSubmission(
      tokenFromEnvironment(),
      snapshot.app.id,
    );
    submissionId = submission.id;
  }
  if (
    context.plan.action === "create_submission" ||
    context.plan.action === "add_item"
  ) {
    await createReviewSubmissionItem(
      tokenFromEnvironment(),
      submissionId,
      snapshot.version.id,
    );
  }

  snapshot = await candidateSnapshot(
    tokenFromEnvironment(),
    bundleId,
    buildNumber,
    metadata,
    images,
    expectedReviewAttributes,
  );
  failForBlockers(candidateBlockers(snapshot, true));
  context = await currentSubmissionPlan(
    tokenFromEnvironment(),
    snapshot.app.id,
    snapshot.version.id,
  );
  if (context.plan.action === "already_submitted") {
    printResult(snapshot, context.plan.state, false);
    return;
  }
  if (
    context.plan.action !== "submit" ||
    context.plan.submissionId !== submissionId
  ) {
    fail("The active review submission changed before final submission.");
  }

  await submitReviewSubmission(tokenFromEnvironment(), submissionId);
  const submittedState = await waitForSubmittedState(submissionId);
  const postSubmissionSnapshot = await candidateSnapshot(
    tokenFromEnvironment(),
    bundleId,
    buildNumber,
    metadata,
    images,
    expectedReviewAttributes,
  );
  const postSubmission = await getReviewSubmission(
    tokenFromEnvironment(),
    submissionId,
  );
  const postSubmissionItems = await listReviewSubmissionItems(
    tokenFromEnvironment(),
    submissionId,
  );
  const invariantViolations = candidateBlockers(
    postSubmissionSnapshot,
    false,
  );
  let verifiedSubmittedState;
  try {
    verifiedSubmittedState = validateExactSubmittedSubmission(
      postSubmission,
      postSubmissionItems,
      postSubmissionSnapshot.version.id,
    );
  } catch (error) {
    invariantViolations.push(error.message);
  }
  if (invariantViolations.length > 0) {
    await cancelReviewSubmission(tokenFromEnvironment(), submissionId);
    fail(
      `Post-submission invariants changed; cancellation was requested: ` +
      `${invariantViolations.join("; ")}.`,
    );
  }
  printResult(
    postSubmissionSnapshot,
    verifiedSubmittedState ?? submittedState,
    true,
  );
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

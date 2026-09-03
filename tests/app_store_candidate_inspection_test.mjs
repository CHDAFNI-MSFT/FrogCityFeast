import assert from "node:assert/strict";

import {
  failForBlockers,
  reviewDetailIdFromResponse,
  selectCandidateBuild,
  selectedBuildIdFromResponse,
  summarizeReviewDetail,
  summarizeScreenshots,
} from "../scripts/inspect-app-store-candidate.mjs";

const validBuild = {
  type: "builds",
  id: "build-id",
  attributes: {
    version: "33770597608.1",
    processingState: "VALID",
  },
};

assert.equal(
  selectCandidateBuild({ data: [validBuild] }, "33770597608.1"),
  validBuild,
);
assert.equal(
  selectCandidateBuild({ data: [] }, "33770597608.1"),
  null,
);
assert.throws(
  () => selectCandidateBuild(
    { data: [validBuild, { ...validBuild, id: "duplicate" }] },
    "33770597608.1",
  ),
  /Expected at most one build/,
);
assert.throws(
  () => selectCandidateBuild(
    { data: [{ ...validBuild, attributes: {
      ...validBuild.attributes,
      processingState: "UNKNOWN",
    } }] },
    "33770597608.1",
  ),
  /unknown processing state/,
);

const completeReview = summarizeReviewDetail({
  type: "appStoreReviewDetails",
  id: "review-id",
  attributes: {
    contactFirstName: "First",
    contactLastName: "Last",
    contactPhone: "+15555550100",
    contactEmail: "review@example.com",
    demoAccountRequired: false,
    notes: "Offline game. No account is required.",
  },
});
assert.equal(completeReview.complete, true);
assert.equal(
  Object.hasOwn(completeReview, "contactEmail"),
  false,
  "Inspection must not expose App Review contact values.",
);
assert.equal(summarizeReviewDetail(null).complete, false);

const completeScreenshots = summarizeScreenshots([{
  displayType: "APP_IPAD_PRO_3GEN_129",
  screenshots: Array.from(
    { length: 7 },
    () => ({ deliveryState: "COMPLETE" }),
  ),
}]);
assert.equal(completeScreenshots.complete, true);
assert.equal(
  summarizeScreenshots([{
    displayType: "APP_IPAD_PRO_3GEN_129",
    screenshots: [{ deliveryState: "AWAITING_UPLOAD" }],
  }]).complete,
  false,
);
assert.throws(
  () => summarizeScreenshots([
    {
      displayType: "APP_IPAD_PRO_3GEN_129",
      screenshots: [],
    },
    {
      displayType: "APP_IPAD_PRO_3GEN_129",
      screenshots: [],
    },
  ]),
  /at most one/,
);
assert.doesNotThrow(() => failForBlockers([]));
assert.throws(
  () => failForBlockers(["candidate build is not selected"]),
  /not ready for submission/,
);
assert.equal(selectedBuildIdFromResponse({ data: null }), null);
assert.equal(
  selectedBuildIdFromResponse({
    data: { type: "builds", id: "build-id" },
  }),
  "build-id",
);
assert.throws(
  () => selectedBuildIdFromResponse({
    data: { type: "appStoreVersions", id: "wrong-type" },
  }),
  /selected-build relationship is invalid/,
);
assert.equal(reviewDetailIdFromResponse({ data: null }), null);
assert.equal(
  reviewDetailIdFromResponse({
    data: { type: "appStoreReviewDetails", id: "review-id" },
  }),
  "review-id",
);

console.log("App Store candidate inspection tests passed.");

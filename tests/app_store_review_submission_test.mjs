import assert from "node:assert/strict";

import {
  planReviewSubmission,
  reviewDetailMismatches,
  reviewSubmissionCancelBody,
  reviewSubmissionCreateBody,
  reviewSubmissionItemCreateBody,
  reviewSubmissionSubmitBody,
  selectCompletedSubmissionForVersion,
  validateExactSubmittedSubmission,
} from "../scripts/submit-app-store-review.mjs";
import {
  formatApiErrors,
  selectVersionByString,
} from "../scripts/sync-app-store-metadata.mjs";

const versionId = "version-0.1.0";
const readySubmission = {
  type: "reviewSubmissions",
  id: "submission-1",
  attributes: {
    platform: "IOS",
    state: "READY_FOR_REVIEW",
  },
};

assert.equal(
  selectVersionByString(
    {
      data: [
        {
          type: "appStoreVersions",
          id: "older-version",
          attributes: {
            platform: "IOS",
            versionString: "0.0.9",
            appVersionState: "READY_FOR_SALE",
          },
        },
        {
          type: "appStoreVersions",
          id: versionId,
          attributes: {
            platform: "IOS",
            versionString: "0.1.0",
            appVersionState: "WAITING_FOR_REVIEW",
          },
        },
      ],
    },
    { platform: "IOS", version: "0.1.0" },
  ).id,
  versionId,
);
assert.match(
  formatApiErrors(
    [{
      status: "409",
      code: "STATE_ERROR",
      title: "Invalid state",
      detail: "The version cannot be reviewed.",
      meta: {
        associatedErrors: [{
          status: "409",
          code: "MISSING_METADATA",
          title: "Missing metadata",
          detail: "A required declaration is incomplete.",
        }],
      },
    }],
    409,
  ),
  /Associated validation errors: 409 MISSING_METADATA/,
);

const expectedReview = {
  contactFirstName: "Review",
  contactLastName: "Contact",
  contactEmail: "review@example.com",
  contactPhone: "+15555550100",
  demoAccountRequired: false,
  notes: "Exact reviewed notes.",
};
assert.deepEqual(
  reviewDetailMismatches(
    {
      type: "appStoreReviewDetails",
      id: "review-detail-1",
      attributes: expectedReview,
    },
    expectedReview,
  ),
  [],
);
assert.deepEqual(
  reviewDetailMismatches(
    {
      type: "appStoreReviewDetails",
      id: "review-detail-1",
      attributes: {
        ...expectedReview,
        notes: "Changed notes.",
      },
    },
    expectedReview,
  ),
  ["notes"],
);

assert.deepEqual(
  planReviewSubmission([], {}, versionId),
  {
    action: "create_submission",
    submissionId: null,
    state: null,
  },
);
assert.deepEqual(
  planReviewSubmission(
    [readySubmission],
    { "submission-1": [] },
    versionId,
  ),
  {
    action: "add_item",
    submissionId: "submission-1",
    state: "READY_FOR_REVIEW",
  },
);
assert.deepEqual(
  planReviewSubmission(
    [readySubmission],
    {
      "submission-1": [{
        id: "item-1",
        state: "READY_FOR_REVIEW",
        versionId,
      }],
    },
    versionId,
  ),
  {
    action: "submit",
    submissionId: "submission-1",
    state: "READY_FOR_REVIEW",
  },
);
assert.deepEqual(
  planReviewSubmission(
    [{
      ...readySubmission,
      attributes: {
        platform: "IOS",
        state: "WAITING_FOR_REVIEW",
      },
    }],
    {
      "submission-1": [{
        id: "item-1",
        state: "ACCEPTED",
        versionId,
      }],
    },
    versionId,
  ),
  {
    action: "already_submitted",
    submissionId: "submission-1",
    state: "WAITING_FOR_REVIEW",
  },
);
assert.throws(
  () => planReviewSubmission(
    [readySubmission],
    {
      "submission-1": [{
        id: "item-1",
        state: "READY_FOR_REVIEW",
        versionId: "different-version",
      }],
    },
    versionId,
  ),
  /targets a different item/,
);
assert.throws(
  () => planReviewSubmission(
    [readySubmission, {
      ...readySubmission,
      id: "submission-2",
    }],
    {
      "submission-1": [],
      "submission-2": [],
    },
    versionId,
  ),
  /at most one active iOS review submission/,
);
assert.throws(
  () => planReviewSubmission(
    [{
      ...readySubmission,
      attributes: {
        platform: "IOS",
        state: "CANCELING",
      },
    }],
    {
      "submission-1": [{
        id: "item-1",
        state: "REMOVED",
        versionId,
      }],
    },
    versionId,
  ),
  /requires manual attention/,
);
assert.throws(
  () => planReviewSubmission(
    [readySubmission],
    {
      "submission-1": [{
        id: "item-1",
        state: "REMOVED",
        versionId,
      }],
    },
    versionId,
  ),
  /unexpected state REMOVED/,
);
assert.equal(
  validateExactSubmittedSubmission(
    {
      type: "reviewSubmissions",
      id: "submission-1",
      attributes: {
        platform: "IOS",
        state: "COMPLETE",
      },
    },
    [{
      id: "item-1",
      state: "APPROVED",
      versionId,
    }],
    versionId,
  ),
  "COMPLETE",
);
assert.throws(
  () => selectCompletedSubmissionForVersion(
    [{
      submission: {
        type: "reviewSubmissions",
        id: "submission-1",
        attributes: {
          platform: "IOS",
          state: "COMPLETE",
        },
      },
      items: [{
        id: "item-1",
        state: "REMOVED",
        versionId,
      }],
    }],
    versionId,
  ),
  /invalid state REMOVED/,
);

assert.deepEqual(
  reviewSubmissionCreateBody("app-1"),
  {
    data: {
      type: "reviewSubmissions",
      attributes: { platform: "IOS" },
      relationships: {
        app: {
          data: { type: "apps", id: "app-1" },
        },
      },
    },
  },
);
assert.deepEqual(
  reviewSubmissionItemCreateBody("submission-1", versionId),
  {
    data: {
      type: "reviewSubmissionItems",
      relationships: {
        reviewSubmission: {
          data: {
            type: "reviewSubmissions",
            id: "submission-1",
          },
        },
        appStoreVersion: {
          data: {
            type: "appStoreVersions",
            id: versionId,
          },
        },
      },
    },
  },
);
assert.deepEqual(
  reviewSubmissionSubmitBody("submission-1"),
  {
    data: {
      type: "reviewSubmissions",
      id: "submission-1",
      attributes: {
        submitted: true,
      },
    },
  },
);
assert.equal(
  JSON.stringify(reviewSubmissionSubmitBody("submission-1"))
    .includes("release"),
  false,
);
assert.deepEqual(
  reviewSubmissionCancelBody("submission-1"),
  {
    data: {
      type: "reviewSubmissions",
      id: "submission-1",
      attributes: {
        canceled: true,
      },
    },
  },
);

console.log("App Store review submission tests passed.");

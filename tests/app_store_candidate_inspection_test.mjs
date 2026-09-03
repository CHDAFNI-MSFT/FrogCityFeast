import assert from "node:assert/strict";

import {
  failForBlockers,
  reviewDetailIdFromResponse,
  selectCandidateBuild,
  selectedBuildIdFromResponse,
  summarizeAgeRating,
  summarizeAvailability,
  summarizePriceSchedule,
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

assert.deepEqual(
  summarizeAgeRating({
    type: "ageRatingDeclarations",
    id: "rating-id",
    attributes: {
      socialMedia: false,
      violenceCartoonOrFantasy: "FREQUENT",
    },
  }, {
    socialMedia: false,
    violenceCartoonOrFantasy: "FREQUENT",
  }),
  {
    declarationExists: true,
    expectedFieldCount: 7,
    mismatchedFields: [],
    complete: true,
  },
);
assert.deepEqual(
  summarizeAgeRating({
    type: "ageRatingDeclarations",
    id: "rating-id",
    attributes: { socialMedia: null },
  }, {
    socialMedia: false,
  }).mismatchedFields,
  ["socialMedia"],
);
assert.deepEqual(
  summarizeAgeRating({
    type: "ageRatingDeclarations",
    id: "rating-id",
    attributes: {
      socialMedia: false,
      ageRatingOverrideV2: "EIGHTEEN_PLUS",
    },
  }, {
    socialMedia: false,
  }).mismatchedFields,
  ["ageRatingOverrideV2"],
);

assert.equal(
  summarizePriceSchedule({
    type: "appPriceSchedules",
    id: "price-id",
    relationships: {
      baseTerritory: {
        data: { type: "territories", id: "USA" },
      },
    },
  }, {
    data: [{
      type: "appPrices",
      id: "active-price-id",
      attributes: {
        manual: true,
        startDate: "2026-01-01",
        endDate: null,
      },
      relationships: {
        territory: {
          data: { type: "territories", id: "USA" },
        },
        appPricePoint: {
          data: { type: "appPricePoints", id: "free-point-id" },
        },
      },
    }],
    included: [{
      type: "appPricePoints",
      id: "free-point-id",
      attributes: { customerPrice: "0.00" },
    }],
  }, "2026-09-02").complete,
  true,
);
assert.equal(summarizePriceSchedule(null).complete, false);
assert.equal(
  summarizePriceSchedule({
    type: "appPriceSchedules",
    id: "price-id",
    relationships: {
      baseTerritory: {
        data: { type: "territories", id: "USA" },
      },
    },
  }, {
    data: [{
      type: "appPrices",
      id: "active-price-id",
      attributes: {
        manual: true,
        startDate: "2026-01-01",
        endDate: null,
      },
      relationships: {
        territory: {
          data: { type: "territories", id: "USA" },
        },
        appPricePoint: {
          data: { type: "appPricePoints", id: "paid-point-id" },
        },
      },
    }],
    included: [{
      type: "appPricePoints",
      id: "paid-point-id",
      attributes: { customerPrice: "1.99" },
    }],
  }, "2026-09-02").complete,
  false,
);
assert.equal(
  summarizePriceSchedule({
    type: "appPriceSchedules",
    id: "price-id",
    relationships: {
      baseTerritory: {
        data: { type: "territories", id: "USA" },
      },
    },
  }, {
    data: [
      {
        type: "appPrices",
        id: "expired-price-id",
        attributes: {
          manual: true,
          startDate: "2026-01-01",
          endDate: "2026-09-02",
        },
        relationships: {
          territory: {
            data: { type: "territories", id: "USA" },
          },
          appPricePoint: {
            data: { type: "appPricePoints", id: "paid-point-id" },
          },
        },
      },
      {
        type: "appPrices",
        id: "replacement-price-id",
        attributes: {
          manual: true,
          startDate: "2026-09-02",
          endDate: null,
        },
        relationships: {
          territory: {
            data: { type: "territories", id: "USA" },
          },
          appPricePoint: {
            data: { type: "appPricePoints", id: "free-point-id" },
          },
        },
      },
    ],
    included: [
      {
        type: "appPricePoints",
        id: "paid-point-id",
        attributes: { customerPrice: "1.99" },
      },
      {
        type: "appPricePoints",
        id: "free-point-id",
        attributes: { customerPrice: "0.00" },
      },
    ],
  }, "2026-09-02").complete,
  true,
);
assert.equal(
  summarizePriceSchedule({
    type: "appPriceSchedules",
    id: "price-id",
    relationships: {
      baseTerritory: {
        data: { type: "territories", id: "USA" },
      },
    },
  }, {
    data: [
      {
        type: "appPrices",
        id: "expired-sparse-price-id",
        attributes: {
          startDate: "2026-01-01",
          endDate: "2026-09-02",
        },
      },
      {
        type: "appPrices",
        id: "replacement-price-id",
        attributes: {
          manual: true,
          startDate: "2026-09-02",
          endDate: null,
        },
        relationships: {
          territory: {
            data: { type: "territories", id: "USA" },
          },
          appPricePoint: {
            data: { type: "appPricePoints", id: "free-point-id" },
          },
        },
      },
    ],
    included: [{
      type: "appPricePoints",
      id: "free-point-id",
      attributes: { customerPrice: "0.00" },
    }],
  }, "2026-09-02").complete,
  true,
);
assert.throws(
  () => summarizePriceSchedule({
    type: "appPriceSchedules",
    id: "price-id",
    relationships: {
      baseTerritory: {
        data: { type: "territories", id: "USA" },
      },
    },
  }, {
    data: [{
      type: "appPrices",
      id: "active-sparse-price-id",
      attributes: {
        startDate: "2026-01-01",
        endDate: null,
      },
    }],
    included: [],
  }, "2026-09-02"),
  /active app price response is invalid/,
);
assert.equal(
  summarizePriceSchedule({
    type: "appPriceSchedules",
    id: "price-id",
    relationships: {
      baseTerritory: {
        data: { type: "territories", id: "USA" },
      },
    },
  }, {
    data: [
      {
        type: "appPrices",
        id: "base-price-id",
        attributes: {
          manual: true,
          startDate: "2026-01-01",
          endDate: null,
        },
        relationships: {
          territory: {
            data: { type: "territories", id: "USA" },
          },
          appPricePoint: {
            data: { type: "appPricePoints", id: "free-point-id" },
          },
        },
      },
      {
        type: "appPrices",
        id: "override-price-id",
        attributes: {
          manual: true,
          startDate: "2026-01-01",
          endDate: null,
        },
        relationships: {
          territory: {
            data: { type: "territories", id: "CAN" },
          },
          appPricePoint: {
            data: { type: "appPricePoints", id: "paid-point-id" },
          },
        },
      },
    ],
    included: [
      {
        type: "appPricePoints",
        id: "free-point-id",
        attributes: { customerPrice: "0.00" },
      },
      {
        type: "appPricePoints",
        id: "paid-point-id",
        attributes: { customerPrice: "1.99" },
      },
    ],
  }, "2026-09-02").complete,
  false,
);

const completeAvailability = summarizeAvailability({
  data: {
    type: "appAvailabilities",
    id: "availability-id",
    attributes: { availableInNewTerritories: true },
  },
  totalCount: 2,
  territories: [
    {
      type: "territoryAvailabilities",
      id: "usa-availability",
      attributes: {
        available: true,
        contentStatuses: ["AVAILABLE"],
      },
      relationships: {
        territory: { data: { type: "territories", id: "USA" } },
      },
    },
    {
      type: "territoryAvailabilities",
      id: "chn-availability",
      attributes: {
        available: false,
        contentStatuses: [],
      },
      relationships: {
        territory: { data: { type: "territories", id: "CHN" } },
      },
    },
  ],
}, "all_except_china_mainland", ["USA", "CHN"]);
assert.equal(completeAvailability.complete, true);
assert.equal(completeAvailability.availableTerritoryCount, 1);
assert.deepEqual(
  summarizeAvailability({
    data: {
      type: "appAvailabilities",
      id: "availability-id",
      attributes: { availableInNewTerritories: true },
    },
    totalCount: 2,
    territories: [
      {
        type: "territoryAvailabilities",
        id: "usa-availability",
        attributes: {
          available: true,
          contentStatuses: ["MISSING_RATING"],
        },
        relationships: {
          territory: { data: { type: "territories", id: "USA" } },
        },
      },
      {
        type: "territoryAvailabilities",
        id: "chn-availability",
        attributes: {
          available: false,
          contentStatuses: [],
        },
        relationships: {
          territory: { data: { type: "territories", id: "CHN" } },
        },
      },
    ],
  }, "all_except_china_mainland", ["USA", "CHN"])
    .nonReadyContentStatuses,
  ["MISSING_RATING"],
);
assert.equal(
  summarizeAvailability({
    data: {
      type: "appAvailabilities",
      id: "availability-id",
      attributes: { availableInNewTerritories: true },
    },
    totalCount: 2,
    territories: [
      {
        type: "territoryAvailabilities",
        id: "usa-availability",
        attributes: {
          available: true,
          contentStatuses: [],
        },
        relationships: {
          territory: { data: { type: "territories", id: "USA" } },
        },
      },
      {
        type: "territoryAvailabilities",
        id: "chn-availability",
        attributes: {
          available: false,
          contentStatuses: [],
        },
        relationships: {
          territory: { data: { type: "territories", id: "CHN" } },
        },
      },
    ],
  }, "all_except_china_mainland", ["USA", "CHN"]).complete,
  false,
);
assert.throws(
  () => summarizeAvailability({
    data: {
      type: "appAvailabilities",
      id: "availability-id",
    },
    totalCount: 3,
    territories: [],
  }, "all_except_china_mainland", ["USA", "CHN"]),
  /availability response is invalid/,
);

console.log("App Store candidate inspection tests passed.");

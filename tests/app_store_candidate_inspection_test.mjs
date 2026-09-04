import assert from "node:assert/strict";

import {
  appleApiPath,
  availabilitySummary,
  completeAppPriceRelationships,
  failForBlockers,
  priceScheduleSummary,
  reviewDetailIdFromResponse,
  selectCandidateBuild,
  selectedBuildIdFromResponse,
  summarizeAgeRating,
  summarizeAvailability,
  summarizePriceSchedule,
  summarizeReviewDetail,
  summarizeScreenshots,
} from "../scripts/inspect-app-store-candidate.mjs";

assert.equal(
  appleApiPath(
    "https://api.appstoreconnect.apple.com/v2/appPrices/opaque-id",
    "App price",
  ),
  "/v2/appPrices/opaque-id",
);
assert.throws(
  () => appleApiPath(
    "https://example.com/v2/appPrices/opaque-id",
    "App price",
  ),
  /left Apple API/,
);
const sparsePriceId = Buffer.from(
  JSON.stringify({
    s: "schedule-id",
    t: "USA",
    p: "10000",
    sd: 0,
    ed: 0,
  }),
).toString("base64url");
const freePricePointId = Buffer.from(
  JSON.stringify({
    s: "schedule-id",
    t: "USA",
    p: "10000",
  }),
).toString("base64url");
assert.deepEqual(
  completeAppPriceRelationships({
    type: "appPrices",
    id: sparsePriceId,
    attributes: {
      manual: true,
      startDate: null,
      endDate: null,
    },
  }, "schedule-id").relationships,
  {
    appPricePoint: {
      data: {
        type: "appPricePoints",
        id: freePricePointId,
      },
    },
    territory: {
      data: {
        type: "territories",
        id: "USA",
      },
    },
  },
);
assert.equal(
  completeAppPriceRelationships({
    type: "appPrices",
    id:
      "eyJzIjoiNjQ0NzQwMjE5MiIsInQiOiJVU0EiLCJwIjoiMTAwMDciLCJzZCI6" +
      "MC4wLCJlZCI6MTY3NzU3MTIwMC4wMDAwMDAwMDB9",
  }, "6447402192").relationships.appPricePoint.data.id,
  "eyJzIjoiNjQ0NzQwMjE5MiIsInQiOiJVU0EiLCJwIjoiMTAwMDcifQ",
);
assert.throws(
  () => completeAppPriceRelationships({
    type: "appPrices",
    id: Buffer.from(
      JSON.stringify({
        s: "other-schedule",
        t: "USA",
        p: "10000",
        sd: 0,
        ed: 0,
      }),
    ).toString("base64url"),
  }, "schedule-id"),
  /sparse app price identity is invalid/,
);

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
        appPricePoint: {
          data: { type: "appPricePoints", id: "free-point-id" },
        },
      },
    }],
    included: [{
      type: "appPricePoints",
      id: "free-point-id",
      attributes: { customerPrice: "0.00" },
      relationships: {
        territory: {
          data: { type: "territories", id: "USA" },
        },
      },
    }],
  }, "2026-09-02").complete,
  true,
);
const nonBaseFallbackPrice = summarizePriceSchedule({
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
      appPricePoint: {
        data: { type: "appPricePoints", id: "free-point-id" },
      },
    },
  }],
  included: [{
    type: "appPricePoints",
    id: "free-point-id",
    attributes: { customerPrice: "0.00" },
    relationships: {
      territory: {
        data: { type: "territories", id: "CAN" },
      },
    },
  }],
}, "2026-09-02");
assert.equal(nonBaseFallbackPrice.activeManualPriceCount, 1);
assert.equal(nonBaseFallbackPrice.activeBasePricePresent, false);
assert.equal(nonBaseFallbackPrice.activeBasePriceFree, false);
assert.equal(nonBaseFallbackPrice.complete, false);
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
      id: "active-price-id",
      attributes: {
        manual: true,
        startDate: "2026-01-01",
        endDate: null,
      },
      relationships: {
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
  }, "2026-09-02"),
  /active app price territory is invalid/,
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
      id: "active-price-id",
      attributes: {
        manual: true,
        startDate: "2026-01-01",
        endDate: null,
      },
      relationships: {
        territory: {
          data: { type: "storefronts", id: "USA" },
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
      relationships: {
        territory: {
          data: { type: "territories", id: "USA" },
        },
      },
    }],
  }, "2026-09-02"),
  /active app price territory is invalid/,
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
  /active app price is not marked manual/,
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

const originalFetch = globalThis.fetch;
const priceRequests = [];
try {
  globalThis.fetch = async (url) => {
    const parsed = new URL(url);
    priceRequests.push(parsed);
    let payload;
    if (parsed.pathname === "/v1/apps/app-id/appPriceSchedule") {
      payload = {
        data: {
          type: "appPriceSchedules",
          id: "schedule-id",
          relationships: {
            baseTerritory: {
              data: { type: "territories", id: "USA" },
            },
            manualPrices: {
              meta: { paging: { total: 1 } },
              data: [{
                type: "appPrices",
                id: sparsePriceId,
              }],
            },
          },
        },
        included: [
          {
            type: "appPrices",
            id: sparsePriceId,
            attributes: {
              manual: true,
              startDate: null,
              endDate: null,
            },
          },
          {
            type: "appPrices",
            id: "unlinked-price-id",
            attributes: {
              manual: true,
              startDate: null,
              endDate: null,
            },
          },
        ],
      };
    } else if (
      parsed.pathname ===
        `/v3/appPricePoints/${encodeURIComponent(freePricePointId)}`
    ) {
      payload = {
        data: {
          type: "appPricePoints",
          id: freePricePointId,
          attributes: { customerPrice: "0.00" },
        },
      };
    } else {
      throw new Error(`Unexpected App Store request: ${parsed.pathname}`);
    }
    return {
      ok: true,
      status: 200,
      text: async () => JSON.stringify(payload),
    };
  };
  const hydratedPriceSummary = await priceScheduleSummary(
    "test-token",
    "app-id",
  );
  assert.equal(hydratedPriceSummary.complete, true);
  assert.equal(hydratedPriceSummary.activeManualPriceCount, 1);
  assert.equal(priceRequests.length, 2);
  assert.ok(
    priceRequests.some(
      (request) => (
        request.pathname ===
          `/v3/appPricePoints/${encodeURIComponent(freePricePointId)}`
      ),
    ),
  );
} finally {
  globalThis.fetch = originalFetch;
}

const availabilityRequests = [];
try {
  globalThis.fetch = async (url) => {
    const parsed = new URL(url);
    availabilityRequests.push(parsed);
    let payload;
    if (parsed.pathname === "/v1/apps/app-id/appAvailabilityV2") {
      payload = {
        data: {
          type: "appAvailabilities",
          id: "availability-id",
          attributes: { availableInNewTerritories: true },
        },
      };
    } else if (parsed.pathname === "/v1/territories") {
      payload = {
        data: [
          { type: "territories", id: "USA" },
          { type: "territories", id: "CHN" },
        ],
      };
    } else if (
      parsed.pathname ===
        "/v2/appAvailabilities/availability-id/territoryAvailabilities"
    ) {
      payload = {
        data: [
          {
            type: "territoryAvailabilities",
            id: "usa-availability",
            attributes: {
              available: true,
              contentStatuses: ["AVAILABLE_FOR_SALE_UNRELEASED_APP"],
            },
            relationships: {
              territory: {
                data: { type: "territories", id: "USA" },
              },
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
              territory: {
                data: { type: "territories", id: "CHN" },
              },
            },
          },
        ],
      };
    } else {
      throw new Error(`Unexpected App Store request: ${parsed.pathname}`);
    }
    return {
      ok: true,
      status: 200,
      text: async () => JSON.stringify(payload),
    };
  };
  const liveAvailabilitySummary = await availabilitySummary(
    "test-token",
    "app-id",
    "all_except_china_mainland",
  );
  assert.equal(liveAvailabilitySummary.complete, true);
  const territoryRequest = availabilityRequests.find(
    (request) => (
      request.pathname ===
        "/v2/appAvailabilities/availability-id/territoryAvailabilities"
    ),
  );
  assert.ok(territoryRequest);
  assert.deepEqual(
    territoryRequest.searchParams.getAll("include"),
    ["territory"],
  );
} finally {
  globalThis.fetch = originalFetch;
}

console.log("App Store candidate inspection tests passed.");

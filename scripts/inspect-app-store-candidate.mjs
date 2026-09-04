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
const EDITABLE_INFO_STATES = new Set([
  "DEVELOPER_REJECTED",
  "PREPARE_FOR_SUBMISSION",
  "READY_FOR_REVIEW",
  "REJECTED",
]);
const READY_AVAILABILITY_STATUSES = new Set([
  "AVAILABLE",
  "AVAILABLE_FOR_SALE_UNRELEASED_APP",
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

export function appleApiPath(url, label) {
  if (typeof url !== "string" || !url.trim()) {
    fail(`${label} URL is invalid.`);
  }
  const parsed = new URL(
    url,
    "https://api.appstoreconnect.apple.com",
  );
  if (parsed.origin !== "https://api.appstoreconnect.apple.com") {
    fail(`${label} URL left Apple API.`);
  }
  return `${parsed.pathname}${parsed.search}`;
}

async function paginatedCollection(token, initialPath, label) {
  const data = [];
  const included = [];
  let totalCount = null;
  let nextPath = initialPath;
  const visitedPaths = new Set();
  while (nextPath) {
    if (visitedPaths.has(nextPath) || visitedPaths.size >= 20) {
      fail(`${label} pagination is invalid.`);
    }
    visitedPaths.add(nextPath);
    const payload = await apiRequest(token, "GET", nextPath);
    data.push(...collection(payload, label));
    if (payload.included !== undefined) {
      if (!Array.isArray(payload.included)) {
        fail(`${label} included resources are invalid.`);
      }
      included.push(...payload.included);
    }
    const pageTotal = payload.meta?.paging?.total;
    if (pageTotal !== undefined && pageTotal !== null) {
      if (!Number.isInteger(pageTotal) || pageTotal < data.length) {
        fail(`${label} pagination metadata is invalid.`);
      }
      if (totalCount !== null && totalCount !== pageTotal) {
        fail(`${label} total changed during inspection.`);
      }
      totalCount = pageTotal;
    }
    const nextUrl = payload.links?.next;
    if (nextUrl === null || nextUrl === undefined) {
      nextPath = null;
    } else if (typeof nextUrl === "string") {
      nextPath = appleApiPath(nextUrl, `${label} pagination`);
    } else {
      fail(`${label} next-page link is invalid.`);
    }
  }
  if (totalCount !== null && data.length !== totalCount) {
    fail(`${label} pagination did not return every resource.`);
  }
  return {
    data,
    included,
    totalCount: totalCount ?? data.length,
  };
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

export function summarizeAgeRating(declaration, expectedAttributes) {
  if (
    declaration?.type !== "ageRatingDeclarations" ||
    typeof declaration.id !== "string" ||
    !declaration.id.trim()
  ) {
    fail("The age-rating declaration response is invalid.");
  }
  const attributes = declaration.attributes ?? {};
  const expected = {
    ...expectedAttributes,
    kidsAgeBand: [null],
    ageRatingOverride: [null, "NONE"],
    ageRatingOverrideV2: [null, "NONE"],
    koreaAgeRatingOverride: [null, "NONE"],
    developerAgeRatingInfoUrl: [null],
  };
  const mismatchedFields = Object.entries(expected)
    .filter(([name, value]) => {
      const accepted = Array.isArray(value) ? value : [value];
      return !accepted.includes(attributes[name] ?? null);
    })
    .map(([name]) => name)
    .sort();
  return {
    declarationExists: true,
    expectedFieldCount: Object.keys(expected).length,
    mismatchedFields,
    complete: mismatchedFields.length === 0,
  };
}

export function summarizePriceSchedule(
  schedule,
  pricePayload,
  currentDate = new Date().toISOString().slice(0, 10),
) {
  if (!schedule) {
    return {
      exists: false,
      baseTerritoryPresent: false,
      activeBasePricePresent: false,
      activeBasePriceFree: false,
      activeManualPriceCount: 0,
      allActiveManualPricesFree: false,
      complete: false,
    };
  }
  if (
    schedule.type !== "appPriceSchedules" ||
    typeof schedule.id !== "string" ||
    !schedule.id.trim()
  ) {
    fail("The app price-schedule response is invalid.");
  }
  const baseTerritory = schedule.relationships?.baseTerritory?.data;
  const baseTerritoryPresent = (
    baseTerritory?.type === "territories" &&
    typeof baseTerritory.id === "string" &&
    baseTerritory.id.trim().length > 0
  );
  if (
    !baseTerritoryPresent ||
    !Array.isArray(pricePayload?.data) ||
    !Array.isArray(pricePayload?.included) ||
    !/^\d{4}-\d{2}-\d{2}$/.test(currentDate)
  ) {
    fail("The app price-schedule details are invalid.");
  }
  const activeManualPrices = selectActiveManualPrices(
    pricePayload.data,
    currentDate,
  );
  const matchingPricePoint = (price) => {
    const pricePoint = price.relationships?.appPricePoint?.data;
    if (
      pricePoint?.type !== "appPricePoints" ||
      typeof pricePoint.id !== "string" ||
      !pricePoint.id.trim()
    ) {
      fail("The active app price-point relationship is invalid.");
    }
    const matchingPoints = pricePayload.included.filter(
      (entry) => (
        entry?.type === "appPricePoints" &&
        entry.id === pricePoint.id
      ),
    );
    const matchingPrices = new Set(
      matchingPoints.map((entry) => entry.attributes?.customerPrice),
    );
    if (
      matchingPoints.length !== 1 ||
      matchingPrices.size !== 1 ||
      typeof matchingPoints[0].attributes?.customerPrice !== "string"
    ) {
      fail("The active app price point is invalid.");
    }
    return matchingPoints[0];
  };
  const territoryId = (price) => {
    const directTerritory = price.relationships?.territory?.data;
    if (directTerritory !== undefined && directTerritory !== null) {
      if (
        directTerritory?.type !== "territories" ||
        typeof directTerritory.id !== "string" ||
        !directTerritory.id.trim()
      ) {
        fail("The active app price territory is invalid.");
      }
      return directTerritory.id;
    }
    const pricePointTerritory = matchingPricePoint(price)
      .relationships?.territory?.data;
    if (
      pricePointTerritory?.type !== "territories" ||
      typeof pricePointTerritory.id !== "string" ||
      !pricePointTerritory.id.trim()
    ) {
      fail("The active app price territory is invalid.");
    }
    return pricePointTerritory.id;
  };
  const activeBasePrices = activeManualPrices.filter(
    (price) => territoryId(price) === baseTerritory.id,
  );
  const activeBasePricePresent = activeBasePrices.length === 1;
  const customerPrice = (price) => {
    const pricePoint = matchingPricePoint(price);
    const value = Number(
      pricePoint.attributes.customerPrice,
    );
    if (!Number.isFinite(value)) {
      fail("The active app price point is not numeric.");
    }
    return value;
  };
  const activeBasePriceFree = (
    activeBasePricePresent &&
    customerPrice(activeBasePrices[0]) === 0
  );
  const allActiveManualPricesFree = (
    activeManualPrices.length > 0 &&
    activeManualPrices.every((price) => customerPrice(price) === 0)
  );
  return {
    exists: true,
    baseTerritoryPresent,
    activeBasePricePresent,
    activeBasePriceFree,
    activeManualPriceCount: activeManualPrices.length,
    allActiveManualPricesFree,
    complete: (
      baseTerritoryPresent &&
      activeBasePriceFree &&
      allActiveManualPricesFree
    ),
  };
}

function selectActiveManualPrices(prices, currentDate) {
  if (
    !Array.isArray(prices) ||
    !/^\d{4}-\d{2}-\d{2}$/.test(currentDate)
  ) {
    fail("App prices or the inspection date are invalid.");
  }
  const validDate = (value) => (
    value === null ||
    value === undefined ||
    (
      typeof value === "string" &&
      /^\d{4}-\d{2}-\d{2}$/.test(value)
    )
  );
  return prices.filter((price) => {
    const attributes = price.attributes ?? {};
    if (
      price?.type !== "appPrices" ||
      typeof price.id !== "string" ||
      !price.id.trim() ||
      !validDate(attributes.startDate) ||
      !validDate(attributes.endDate)
    ) {
      fail("An app price response is invalid.");
    }
    const isActive = (
      (!attributes.startDate || attributes.startDate <= currentDate) &&
      (!attributes.endDate || attributes.endDate > currentDate)
    );
    if (!isActive) {
      return false;
    }
    if (attributes.manual !== true) {
      fail("An active app price is not marked manual.");
    }
    return true;
  });
}

export function completeAppPriceRelationships(price, scheduleId) {
  const existingPricePoint = price.relationships?.appPricePoint?.data;
  const existingTerritory = price.relationships?.territory?.data;
  if (
    existingPricePoint?.type === "appPricePoints" &&
    typeof existingPricePoint.id === "string" &&
    existingPricePoint.id.trim() &&
    existingTerritory?.type === "territories" &&
    typeof existingTerritory.id === "string" &&
    existingTerritory.id.trim()
  ) {
    return price;
  }
  if (
    typeof price.id !== "string" ||
    !/^[A-Za-z0-9_-]+$/.test(price.id) ||
    typeof scheduleId !== "string" ||
    !scheduleId.trim()
  ) {
    fail("The sparse app price identity is invalid.");
  }
  let identity;
  try {
    const decoded = Buffer.from(price.id, "base64url").toString("utf8");
    if (Buffer.from(decoded, "utf8").toString("base64url") !== price.id) {
      fail("The sparse app price identity is invalid.");
    }
    identity = JSON.parse(decoded);
  } catch {
    fail("The sparse app price identity is invalid.");
  }
  if (
    identity === null ||
    typeof identity !== "object" ||
    Array.isArray(identity) ||
    identity.s !== scheduleId ||
    typeof identity.t !== "string" ||
    !/^[A-Z]{3}$/.test(identity.t) ||
    typeof identity.p !== "string" ||
    !/^\d+$/.test(identity.p) ||
    typeof identity.sd !== "number" ||
    !Number.isFinite(identity.sd) ||
    typeof identity.ed !== "number" ||
    !Number.isFinite(identity.ed)
  ) {
    fail("The sparse app price identity is invalid.");
  }
  const pricePointId = Buffer.from(
    JSON.stringify({
      s: identity.s,
      t: identity.t,
      p: identity.p,
    }),
    "utf8",
  ).toString("base64url");
  if (
    (
      existingPricePoint !== undefined &&
      existingPricePoint !== null &&
      (
        existingPricePoint?.type !== "appPricePoints" ||
        existingPricePoint.id !== pricePointId
      )
    ) ||
    (
      existingTerritory !== undefined &&
      existingTerritory !== null &&
      (
        existingTerritory?.type !== "territories" ||
        existingTerritory.id !== identity.t
      )
    )
  ) {
    fail("The sparse app price relationships are inconsistent.");
  }
  return {
    ...price,
    relationships: {
      ...(price.relationships ?? {}),
      appPricePoint: {
        data: {
          type: "appPricePoints",
          id: pricePointId,
        },
      },
      territory: {
        data: {
          type: "territories",
          id: identity.t,
        },
      },
    },
  };
}

export function summarizeAvailability(
  availability,
  expectedStorefronts,
  catalogTerritoryIds,
) {
  if (!availability) {
    return {
      exists: false,
      availableTerritoryCount: 0,
      unavailableTerritoryCount: 0,
      nonReadyContentStatuses: [],
      nonReadyTerritories: [],
      chinaMainlandAvailable: null,
      availableInNewTerritories: null,
      complete: false,
    };
  }
  if (
    availability.data?.type !== "appAvailabilities" ||
    typeof availability.data.id !== "string" ||
    !availability.data.id.trim() ||
    !Array.isArray(availability.territories) ||
    !Number.isInteger(availability.totalCount) ||
    availability.totalCount < 1 ||
    availability.territories.length !== availability.totalCount ||
    !Array.isArray(catalogTerritoryIds) ||
    catalogTerritoryIds.length < 2
  ) {
    fail("The app availability response is invalid.");
  }
  const territories = availability.territories.map((entry) => {
    const territory = entry.relationships?.territory?.data;
    if (
      entry?.type !== "territoryAvailabilities" ||
      typeof entry.id !== "string" ||
      !entry.id.trim() ||
      typeof entry.attributes?.available !== "boolean" ||
      !Array.isArray(entry.attributes?.contentStatuses) ||
      entry.attributes.contentStatuses.some(
        (status) => typeof status !== "string",
      ) ||
      territory?.type !== "territories" ||
      typeof territory.id !== "string" ||
      !territory.id.trim()
    ) {
      fail("A territory availability response is invalid.");
    }
    return {
      id: territory.id,
      available: entry.attributes.available,
      contentStatuses: entry.attributes.contentStatuses,
    };
  });
  if (new Set(territories.map((entry) => entry.id)).size !== territories.length) {
    fail("The territory availability response contains duplicate territories.");
  }
  const catalogIds = new Set(catalogTerritoryIds);
  if (
    catalogIds.size !== catalogTerritoryIds.length ||
    catalogTerritoryIds.some(
      (id) => typeof id !== "string" || !id.trim(),
    )
  ) {
    fail("The App Store territory catalog is invalid.");
  }
  const returnedIds = new Set(territories.map((entry) => entry.id));
  const fullCatalogReturned = (
    returnedIds.size === catalogIds.size &&
    [...catalogIds].every((id) => returnedIds.has(id))
  );
  const nonReadyTerritories = territories
    .filter((entry) => entry.id !== "CHN")
    .map((entry) => ({
      id: entry.id,
      statuses: entry.contentStatuses
        .filter((status) => !READY_AVAILABILITY_STATUSES.has(status))
        .sort(),
    }))
    .filter((entry) => entry.statuses.length > 0)
    .sort((left, right) => left.id.localeCompare(right.id));
  const nonReadyContentStatuses = [
    ...new Set(
      nonReadyTerritories.flatMap((entry) => entry.statuses),
    ),
  ].sort();
  const china = territories.find((entry) => entry.id === "CHN");
  const availableTerritoryCount = territories.filter(
    (entry) => entry.available,
  ).length;
  const unavailableTerritoryCount = territories.length -
    availableTerritoryCount;
  const chinaMainlandAvailable = china?.available ?? null;
  const availableInNewTerritories =
    availability.data.attributes?.availableInNewTerritories ?? null;
  const readyStatusesPresent = territories.every((entry) => (
    entry.id === "CHN" || entry.contentStatuses.length > 0
  ));
  const storefrontsMatch = (
    expectedStorefronts === "all_except_china_mainland" &&
    chinaMainlandAvailable === false &&
    availableInNewTerritories === true &&
    fullCatalogReturned &&
    territories.every((entry) => (
      entry.id === "CHN" || entry.available
    ))
  );
  return {
    exists: true,
    availableTerritoryCount,
    unavailableTerritoryCount,
    nonReadyContentStatuses,
    nonReadyTerritories,
    chinaMainlandAvailable,
    availableInNewTerritories,
    complete: (
      storefrontsMatch &&
      readyStatusesPresent &&
      nonReadyContentStatuses.length === 0
    ),
  };
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

export async function ageRatingSummary(token, appId, metadata) {
  const appInfosPayload = await apiRequest(
    token,
    "GET",
    `/v1/apps/${appId}/appInfos?${query({
      "fields[appInfos]": "state",
      limit: 10,
    })}`,
  );
  const appInfos = collection(appInfosPayload, "App info");
  const editable = appInfos.filter((entry) => (
    EDITABLE_INFO_STATES.has(entry.attributes?.state)
  ));
  if (editable.length !== 1) {
    fail(
      `Expected one editable app info; found ${editable.length}.`,
    );
  }
  const payload = await apiRequest(
    token,
    "GET",
    `/v1/appInfos/${editable[0].id}/ageRatingDeclaration`,
  );
  return summarizeAgeRating(payload.data, metadata.age_rating);
}

export async function priceScheduleSummary(token, appId) {
  const response = await apiRequest(
    token,
    "GET",
    `/v1/apps/${appId}/appPriceSchedule?${query({
      "fields[appPriceSchedules]": "baseTerritory,manualPrices",
      "fields[appPrices]":
        "manual,startDate,endDate,appPricePoint,territory",
      include: "baseTerritory,manualPrices",
      "limit[manualPrices]": 50,
    })}`,
    undefined,
    { allowedStatuses: [404], includeStatus: true },
  );
  if (response.status === 404) {
    return summarizePriceSchedule(null);
  }
  const schedule = response.payload.data;
  const baseTerritory = schedule?.relationships?.baseTerritory?.data;
  if (
    schedule?.type !== "appPriceSchedules" ||
    typeof schedule.id !== "string" ||
    !schedule.id.trim() ||
    baseTerritory?.type !== "territories" ||
    typeof baseTerritory.id !== "string" ||
    !baseTerritory.id.trim()
  ) {
    fail("The app price-schedule response is invalid.");
  }
  const includedPrices = (response.payload.included ?? []).filter(
    (entry) => entry?.type === "appPrices",
  );
  const manualPriceRelationship = schedule.relationships?.manualPrices;
  const manualPriceLinkages = manualPriceRelationship?.data;
  if (
    !Array.isArray(manualPriceLinkages) ||
    manualPriceLinkages.some(
      (linkage) => (
        linkage?.type !== "appPrices" ||
        typeof linkage.id !== "string" ||
        !linkage.id.trim()
      ),
    ) ||
    new Set(manualPriceLinkages.map((linkage) => linkage.id)).size !==
      manualPriceLinkages.length
  ) {
    fail("The app price schedule manual-price linkage is invalid.");
  }
  const prices = manualPriceLinkages.map((linkage) => {
    const matches = includedPrices.filter(
      (price) => price.id === linkage.id,
    );
    if (matches.length !== 1) {
      fail("The app price schedule manual-price inclusion is invalid.");
    }
    return matches[0];
  });
  const manualPriceTotal = manualPriceRelationship?.meta?.paging?.total;
  const totalIsPresent = (
    manualPriceTotal !== undefined &&
    manualPriceTotal !== null
  );
  if (
    !Array.isArray(response.payload.included) ||
    (
      totalIsPresent &&
      (
        !Number.isInteger(manualPriceTotal) ||
        manualPriceTotal !== prices.length
      )
    ) ||
    (!totalIsPresent && prices.length === 50)
  ) {
    fail("The app price schedule did not return every manual price.");
  }
  const currentDate = new Date().toISOString().slice(0, 10);
  const activePrices = selectActiveManualPrices(prices, currentDate)
    .map((price) => completeAppPriceRelationships(price, schedule.id));
  const pricePointIds = [
    ...new Set(
      activePrices.map(
        (price) => price.relationships?.appPricePoint?.data?.id,
      ),
    ),
  ];
  if (
    pricePointIds.some(
      (id) => typeof id !== "string" || !id.trim(),
    )
  ) {
    fail("An app price-point relationship is invalid.");
  }
  const pricePoints = [];
  for (const pricePointId of pricePointIds) {
    const payload = await apiRequest(
      token,
      "GET",
      `/v3/appPricePoints/${encodeURIComponent(pricePointId)}?${query({
        "fields[appPricePoints]": "customerPrice",
      })}`,
    );
    pricePoints.push(payload.data);
  }
  return summarizePriceSchedule(schedule, {
    data: activePrices,
    included: pricePoints,
  }, currentDate);
}

export async function availabilitySummary(
  token,
  appId,
  expectedStorefronts,
) {
  const response = await apiRequest(
    token,
    "GET",
    `/v1/apps/${appId}/appAvailabilityV2?${query({
      "fields[appAvailabilities]": "availableInNewTerritories",
    })}`,
    undefined,
    { allowedStatuses: [404], includeStatus: true },
  );
  if (response.status === 404) {
    return summarizeAvailability(null, expectedStorefronts, []);
  }
  const availability = response.payload.data;
  if (
    availability?.type !== "appAvailabilities" ||
    typeof availability.id !== "string" ||
    !availability.id.trim()
  ) {
    fail("The app availability response is invalid.");
  }
  const catalog = await paginatedCollection(
    token,
    `/v1/territories?${query({ limit: 50 })}`,
    "App Store territory",
  );
  const catalogTerritoryIds = catalog.data.map((territory) => {
    if (
      territory?.type !== "territories" ||
      typeof territory.id !== "string" ||
      !territory.id.trim()
    ) {
      fail("An App Store territory response is invalid.");
    }
    return territory.id;
  });
  const territoryAvailability = await paginatedCollection(
    token,
    `/v2/appAvailabilities/${availability.id}` +
      `/territoryAvailabilities?${query({
      "fields[territoryAvailabilities]":
        "available,contentStatuses,territory",
      include: "territory",
      limit: 50,
      })}`,
    "Territory availability",
  );
  return summarizeAvailability(
    {
      data: availability,
      territories: territoryAvailability.data,
      totalCount: territoryAvailability.totalCount,
    },
    expectedStorefronts,
    catalogTerritoryIds,
  );
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
  const ageRating = await ageRatingSummary(token, app.id, metadata);
  const priceSchedule = await priceScheduleSummary(token, app.id);
  const availability = await availabilitySummary(
    token,
    app.id,
    metadata.storefronts,
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
  if (
    app.attributes?.contentRightsDeclaration !==
      metadata.content_rights_declaration
  ) {
    blockers.push("content-rights declaration does not match metadata");
  }
  if (!ageRating.complete) {
    blockers.push(
      `age-rating declaration differs for: ` +
      `${ageRating.mismatchedFields.join(", ")}`,
    );
  }
  if (!priceSchedule.complete) {
    blockers.push("free app price schedule is incomplete");
  }
  if (!availability.complete) {
    blockers.push(
      "storefront availability or its content statuses are incomplete",
    );
  }

  const report = {
    result: "inspected",
    version: {
      versionString: version.attributes.versionString,
      appStoreState: version.attributes.appStoreState,
      appVersionState: version.attributes.appVersionState,
      reviewType: version.attributes.reviewType,
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
    submissionPrerequisites: {
      contentRightsDeclarationMatches: (
        app.attributes?.contentRightsDeclaration ===
        metadata.content_rights_declaration
      ),
      ageRating,
      priceSchedule,
      availability,
    },
    apiVisibleBlockers: blockers,
    manualConfirmationsStillRequired: [
      "App Privacy questionnaire publication state",
      "EU Digital Services Act account declaration",
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

import { createPrivateKey, sign } from "node:crypto";
import { readFile } from "node:fs/promises";
import process from "node:process";
import { pathToFileURL } from "node:url";

const API_ORIGIN = "https://api.appstoreconnect.apple.com";
const METADATA_PATH = new URL(
  "../tools/app-store-metadata.json",
  import.meta.url,
);
const EDITABLE_INFO_STATES = new Set([
  "DEVELOPER_REJECTED",
  "PREPARE_FOR_SUBMISSION",
  "READY_FOR_REVIEW",
  "REJECTED",
]);
const EDITABLE_VERSION_STATES = new Set([
  "DEVELOPER_REJECTED",
  "PREPARE_FOR_SUBMISSION",
  "READY_FOR_REVIEW",
  "REJECTED",
]);
const APP_STORE_VERSION_PATTERN = /^\d+(?:\.\d+){0,2}$/;
const METADATA_RESOURCES = [
  "appInfoCategories",
  "appInfoLocalization",
  "appStoreVersion",
  "appStoreVersionLocalization",
  "ageRatingDeclaration",
];
const appliedResources = [];
const attemptedResources = [];
let currentResource = null;

function fail(message) {
  throw new Error(message);
}

function beginResource(name) {
  currentResource = name;
  if (!attemptedResources.includes(name)) {
    attemptedResources.push(name);
  }
}

function recordResourceApplied(name) {
  if (!appliedResources.includes(name)) {
    appliedResources.push(name);
  }
  currentResource = null;
}

function requiredEnvironment(name) {
  const value = process.env[name]?.trim();
  if (!value) {
    fail(`${name} is required.`);
  }
  return value;
}

function base64Url(value) {
  return Buffer.from(value).toString("base64url");
}

function createToken(keyId, issuerId, privateKeyPem) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({
    alg: "ES256",
    kid: keyId,
    typ: "JWT",
  }));
  const payload = base64Url(JSON.stringify({
    iss: issuerId,
    iat: now,
    exp: now + 1199,
    aud: "appstoreconnect-v1",
  }));
  const signingInput = `${header}.${payload}`;
  const signature = sign(
    null,
    Buffer.from(signingInput),
    {
      key: createPrivateKey(privateKeyPem),
      dsaEncoding: "ieee-p1363",
    },
  );
  return `${signingInput}.${base64Url(signature)}`;
}

function validateMetadata(metadata) {
  const exactValues = {
    schema_version: 2,
    locale: "en-US",
    platform: "IOS",
    version: "0.1.0",
    name: "Frog City Feast",
    primary_category_id: "GAMES",
    primary_subcategory_one_id: "GAMES_CASUAL",
    primary_subcategory_two_id: "GAMES_ADVENTURE",
    release_type: "MANUAL",
    content_rights_declaration: "DOES_NOT_USE_THIRD_PARTY_CONTENT",
    app_privacy: "NO_DATA_COLLECTED",
    pricing: "free",
    storefronts: "all_except_china_mainland",
    eu_dsa_status: "non-trader",
    whats_new: "",
  };
  for (const [field, expected] of Object.entries(exactValues)) {
    if (metadata[field] !== expected) {
      fail(
        `Metadata field ${field} must be ${JSON.stringify(expected)}.`,
      );
    }
  }
  for (const field of [
    "subtitle",
    "promotional_text",
    "description",
    "keywords",
    "support_url",
    "privacy_policy_url",
    "copyright",
  ]) {
    if (typeof metadata[field] !== "string" || !metadata[field].trim()) {
      fail(`Metadata field ${field} must be non-empty.`);
    }
  }
  if (!metadata.support_url.startsWith("https://")) {
    fail("Support URL must use HTTPS.");
  }
  if (!metadata.privacy_policy_url.startsWith("https://")) {
    fail("Privacy policy URL must use HTTPS.");
  }
  if (
    metadata.age_rating?.violenceCartoonOrFantasy !== "FREQUENT"
  ) {
    fail("Cartoon or fantasy violence must remain FREQUENT.");
  }
  return metadata;
}

function publicFieldValues(metadata) {
  return {
    appName: metadata.name,
    bundleId: process.env.IOS_BUNDLE_ID ?? "com.chdafni.frogcityfeast",
    sku: "FROGCITYFEAST-IOS-001",
    primaryLanguage: metadata.locale,
    platform: metadata.platform,
    version: metadata.version,
    subtitle: metadata.subtitle,
    promotionalText: metadata.promotional_text,
    description: metadata.description,
    keywords: metadata.keywords,
    supportUrl: metadata.support_url,
    privacyPolicyUrl: metadata.privacy_policy_url,
    marketingUrl: metadata.marketing_url || "(blank)",
    copyright: metadata.copyright,
    category: metadata.primary_category,
    primarySubcategory: metadata.primary_subcategory,
    secondGamesSubcategory: metadata.secondary_subcategory,
    releaseType: metadata.release_type,
    contentRights: metadata.content_rights_declaration,
    appPrivacy: metadata.app_privacy,
    ageRatingAnswers: metadata.age_rating,
    pricing: metadata.pricing,
    storefronts: metadata.storefronts,
    euDsaStatus: metadata.eu_dsa_status,
    appReviewContact: metadata.app_review_contact_status,
  };
}

function query(parameters) {
  const result = new URLSearchParams();
  for (const [name, value] of Object.entries(parameters)) {
    result.set(name, String(value));
  }
  return result.toString();
}

async function apiRequest(
  token,
  method,
  path,
  body = undefined,
  options = {},
) {
  const timeoutMs = options.timeoutMs ?? 30_000;
  if (!Number.isInteger(timeoutMs) || timeoutMs <= 0) {
    fail("App Store Connect request timeout must be a positive integer.");
  }
  const controller = new AbortController();
  const timeout = setTimeout(() => {
    controller.abort();
  }, timeoutMs);
  let response;
  let text;
  try {
    response = await fetch(`${API_ORIGIN}${path}`, {
      method,
      headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/json",
      ...(body ? { "Content-Type": "application/json" } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
      signal: controller.signal,
    });
    text = await response.text();
  } catch (error) {
    if (controller.signal.aborted) {
      fail(`App Store Connect ${method} ${path} timed out.`);
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }
  let payload = {};
  if (text) {
    try {
      payload = JSON.parse(text);
    } catch {
      fail(
        `App Store Connect returned non-JSON data for ${method} ${path}.`,
      );
    }
  }
  const allowedStatuses = Array.isArray(options.allowedStatuses)
    ? options.allowedStatuses
    : [];
  if (!response.ok && !allowedStatuses.includes(response.status)) {
    const details = Array.isArray(payload.errors)
      ? payload.errors.map((error) => (
        `${error.status ?? response.status} ${error.code ?? "ERROR"}: ` +
        `${error.title ?? ""} ${error.detail ?? ""}`.trim()
      )).join("; ")
      : `HTTP ${response.status}`;
    if (response.status === 403) {
      fail(
        `App Store Connect denied ${method} ${path}. The protected API ` +
        `key must have App Manager or equivalent metadata permission. ` +
        details,
      );
    }
    fail(`App Store Connect ${method} ${path} failed: ${details}`);
  }
  if (options.includeStatus) {
    return { status: response.status, payload };
  }
  return payload;
}

function exactlyOne(payload, label) {
  if (!Array.isArray(payload.data) || payload.data.length !== 1) {
    fail(
      `Expected exactly one ${label}; found ${payload.data?.length ?? 0}.`,
    );
  }
  return payload.data[0];
}

function atMostOne(payload, label) {
  if (!Array.isArray(payload.data) || payload.data.length > 1) {
    fail(`Expected at most one ${label}; found ${payload.data?.length ?? 0}.`);
  }
  return payload.data[0] ?? null;
}

function validateExistingResource(resource, type, label) {
  if (!resource) {
    return null;
  }
  if (
    resource.type !== type ||
    typeof resource.id !== "string" ||
    !resource.id.trim()
  ) {
    fail(`The existing ${label} response is invalid.`);
  }
  return resource;
}

function patchResource(type, id, attributes, relationships = undefined) {
  return {
    data: {
      type,
      id,
      ...(attributes ? { attributes } : {}),
      ...(relationships ? { relationships } : {}),
    },
  };
}

async function findApp(token, bundleId) {
  const payload = await apiRequest(
    token,
    "GET",
    `/v1/apps?${query({
      "filter[bundleId]": bundleId,
      "fields[apps]": [
        "bundleId",
        "name",
        "primaryLocale",
        "sku",
        "contentRightsDeclaration",
      ].join(","),
      limit: 2,
    })}`,
  );
  return exactlyOne(payload, `app with bundle ID ${bundleId}`);
}

async function findEditableAppInfo(token, appId) {
  const payload = await apiRequest(
    token,
    "GET",
    `/v1/apps/${appId}/appInfos?${query({
      "fields[appInfos]": "state",
      limit: 10,
    })}`,
  );
  const editable = payload.data.filter((entry) => (
    EDITABLE_INFO_STATES.has(entry.attributes?.state)
  ));
  if (editable.length !== 1) {
    const states = payload.data.map(
      (entry) => entry.attributes?.state ?? "UNKNOWN",
    );
    fail(
      `Expected one editable app info; found ${editable.length}. ` +
      `Current states: ${states.join(", ") || "none"}.`,
    );
  }
  return editable[0];
}

async function findAppInfoLocalization(
  token,
  appInfoId,
  metadata,
) {
  const payload = await apiRequest(
    token,
    "GET",
    `/v1/appInfos/${appInfoId}/appInfoLocalizations?${query({
      "filter[locale]": metadata.locale,
      limit: 2,
    })}`,
  );
  return validateExistingResource(
    atMostOne(
      payload,
      `${metadata.locale} app info localization`,
    ),
    "appInfoLocalizations",
    `${metadata.locale} app info localization`,
  );
}

async function ensureAppInfoLocalization(
  token,
  appInfoId,
  metadata,
  existing,
) {
  const attributes = {
    name: metadata.name,
    subtitle: metadata.subtitle,
    privacyPolicyUrl: metadata.privacy_policy_url,
  };
  if (existing) {
    beginResource("appInfoLocalization");
    await apiRequest(
      token,
      "PATCH",
      `/v1/appInfoLocalizations/${existing.id}`,
      patchResource("appInfoLocalizations", existing.id, attributes),
    );
    recordResourceApplied("appInfoLocalization");
    return existing.id;
  }
  beginResource("appInfoLocalization");
  const created = await apiRequest(
    token,
    "POST",
    "/v1/appInfoLocalizations",
    {
      data: {
        type: "appInfoLocalizations",
        attributes: {
          locale: metadata.locale,
          ...attributes,
        },
        relationships: {
          appInfo: {
            data: { type: "appInfos", id: appInfoId },
          },
        },
      },
    },
  );
  recordResourceApplied("appInfoLocalization");
  return created.data.id;
}

async function updateCategories(
  token,
  appInfoId,
  metadata,
) {
  const category = (id) => ({
    data: { type: "appCategories", id },
  });
  beginResource("appInfoCategories");
  await apiRequest(
    token,
    "PATCH",
    `/v1/appInfos/${appInfoId}`,
    patchResource(
      "appInfos",
      appInfoId,
      undefined,
      {
        primaryCategory: category(metadata.primary_category_id),
        primarySubcategoryOne: category(
          metadata.primary_subcategory_one_id,
        ),
        primarySubcategoryTwo: category(
          metadata.primary_subcategory_two_id,
        ),
      },
    ),
  );
  recordResourceApplied("appInfoCategories");
}

export function selectVersion(payload, metadata) {
  if (!Array.isArray(payload.data)) {
    fail("App Store version response does not contain a data array.");
  }
  if (payload.data.length > 1) {
    const versions = payload.data.map((entry) => (
      `${entry.attributes?.versionString ?? "UNKNOWN"} ` +
      `(${entry.attributes?.appVersionState ?? "UNKNOWN"})`
    ));
    fail(
      `Expected at most one ${metadata.platform} App Store version before ` +
      `the initial release; found ${payload.data.length}: ` +
      `${versions.join(", ")}.`,
    );
  }
  if (payload.data.length === 0) {
    return null;
  }
  const version = payload.data[0];
  if (
    version?.type !== "appStoreVersions" ||
    typeof version.id !== "string" ||
    !version.id.trim()
  ) {
    fail("The App Store version response contains an invalid resource.");
  }
  if (version.attributes?.platform !== metadata.platform) {
    fail(
      `The App Store version platform is ` +
      `${version.attributes?.platform ?? "UNKNOWN"}; expected ` +
      `${metadata.platform}.`,
    );
  }
  if (
    typeof version.attributes?.versionString !== "string" ||
    !APP_STORE_VERSION_PATTERN.test(version.attributes.versionString)
  ) {
    fail("The App Store version response has no valid version string.");
  }
  const state = version.attributes?.appVersionState;
  if (!EDITABLE_VERSION_STATES.has(state)) {
    fail(
      `The only ${metadata.platform} App Store version, ` +
      `${version.attributes?.versionString ?? "UNKNOWN"}, is not editable ` +
      `(${state ?? "UNKNOWN"}).`,
    );
  }
  return version;
}

async function findVersion(token, appId, metadata) {
  const payload = await apiRequest(
    token,
    "GET",
    `/v1/apps/${appId}/appStoreVersions?${query({
      "filter[platform]": metadata.platform,
      "fields[appStoreVersions]": [
        "platform",
        "versionString",
        "appVersionState",
        "copyright",
        "releaseType",
      ].join(","),
      limit: 200,
    })}`,
  );
  return selectVersion(payload, metadata);
}

async function ensureVersion(token, appId, metadata, existingVersion) {
  let version = existingVersion;
  if (!version) {
    beginResource("appStoreVersion");
    const created = await apiRequest(
      token,
      "POST",
      "/v1/appStoreVersions",
      {
        data: {
          type: "appStoreVersions",
          attributes: {
            platform: metadata.platform,
            versionString: metadata.version,
            copyright: metadata.copyright,
            reviewType: "APP_STORE",
            releaseType: metadata.release_type,
          },
          relationships: {
            app: {
              data: { type: "apps", id: appId },
            },
          },
        },
      },
    );
    version = created.data;
    if (
      version?.type !== "appStoreVersions" ||
      typeof version.id !== "string" ||
      !version.id.trim()
    ) {
      fail("The created App Store version response is invalid.");
    }
    recordResourceApplied("appStoreVersion");
    return version.id;
  }
  const attributes = {
    copyright: metadata.copyright,
    reviewType: "APP_STORE",
    releaseType: metadata.release_type,
  };
  if (version.attributes?.versionString !== metadata.version) {
    attributes.versionString = metadata.version;
  }
  beginResource("appStoreVersion");
  await apiRequest(
    token,
    "PATCH",
    `/v1/appStoreVersions/${version.id}`,
    patchResource(
      "appStoreVersions",
      version.id,
      attributes,
    ),
  );
  recordResourceApplied("appStoreVersion");
  return version.id;
}

async function ensureVersionLocalization(
  token,
  versionId,
  metadata,
  existing,
) {
  const attributes = versionLocalizationAttributes(metadata);
  if (existing) {
    beginResource("appStoreVersionLocalization");
    await apiRequest(
      token,
      "PATCH",
      `/v1/appStoreVersionLocalizations/${existing.id}`,
      patchResource(
        "appStoreVersionLocalizations",
        existing.id,
        attributes,
      ),
    );
    recordResourceApplied("appStoreVersionLocalization");
    return existing.id;
  }
  beginResource("appStoreVersionLocalization");
  const created = await apiRequest(
    token,
    "POST",
    "/v1/appStoreVersionLocalizations",
    {
      data: {
        type: "appStoreVersionLocalizations",
        attributes: {
          locale: metadata.locale,
          ...attributes,
        },
        relationships: {
          appStoreVersion: {
            data: { type: "appStoreVersions", id: versionId },
          },
        },
      },
    },
  );
  recordResourceApplied("appStoreVersionLocalization");
  return created.data.id;
}

async function findVersionLocalization(
  token,
  versionId,
  metadata,
) {
  if (!versionId) {
    return null;
  }
  const payload = await apiRequest(
    token,
    "GET",
    `/v1/appStoreVersions/${versionId}/appStoreVersionLocalizations?${query({
      "filter[locale]": metadata.locale,
      limit: 2,
    })}`,
  );
  return validateExistingResource(
    atMostOne(
      payload,
      `${metadata.locale} version localization`,
    ),
    "appStoreVersionLocalizations",
    `${metadata.locale} version localization`,
  );
}

export function versionLocalizationAttributes(metadata) {
  return {
    description: metadata.description,
    keywords: metadata.keywords,
    marketingUrl: metadata.marketing_url || null,
    promotionalText: metadata.promotional_text,
    supportUrl: metadata.support_url,
  };
}

async function findAgeRatingDeclaration(token, appInfoId) {
  const payload = await apiRequest(
    token,
    "GET",
    `/v1/appInfos/${appInfoId}/ageRatingDeclaration`,
  );
  const declaration = payload.data;
  if (!declaration?.id) {
    fail("The editable app info has no age rating declaration.");
  }
  return declaration;
}

async function updateAgeRating(token, declaration, metadata) {
  beginResource("ageRatingDeclaration");
  await apiRequest(
    token,
    "PATCH",
    `/v1/ageRatingDeclarations/${declaration.id}`,
    patchResource(
      "ageRatingDeclarations",
      declaration.id,
      metadata.age_rating,
    ),
  );
  recordResourceApplied("ageRatingDeclaration");
  return declaration.id;
}

async function main() {
  const metadata = validateMetadata(
    JSON.parse(await readFile(METADATA_PATH, "utf8")),
  );
  if (process.argv.includes("--print-values")) {
    console.log(JSON.stringify(publicFieldValues(metadata), null, 2));
    return;
  }
  if (!process.argv.includes("--apply")) {
    fail("Specify --print-values or --apply.");
  }

  const bundleId = requiredEnvironment("IOS_BUNDLE_ID");
  const keyId = requiredEnvironment("APP_STORE_CONNECT_KEY_ID");
  const issuerId = requiredEnvironment("APP_STORE_CONNECT_ISSUER_ID");
  const privateKeyBase64 = requiredEnvironment(
    "APP_STORE_CONNECT_PRIVATE_KEY_BASE64",
  );
  let privateKeyPem;
  try {
    privateKeyPem = Buffer.from(privateKeyBase64, "base64").toString("utf8");
  } catch {
    fail("APP_STORE_CONNECT_PRIVATE_KEY_BASE64 is not valid base64.");
  }
  const token = createToken(keyId, issuerId, privateKeyPem);

  const app = await findApp(token, bundleId);
  const appInfo = await findEditableAppInfo(token, app.id);
  const existingVersion = await findVersion(token, app.id, metadata);
  const existingAppInfoLocalization = await findAppInfoLocalization(
    token,
    appInfo.id,
    metadata,
  );
  const existingVersionLocalization = await findVersionLocalization(
    token,
    existingVersion?.id ?? null,
    metadata,
  );
  const ageRatingDeclaration = await findAgeRatingDeclaration(
    token,
    appInfo.id,
  );

  await updateCategories(token, appInfo.id, metadata);
  const appInfoLocalizationId = await ensureAppInfoLocalization(
    token,
    appInfo.id,
    metadata,
    existingAppInfoLocalization,
  );
  const versionId = await ensureVersion(
    token,
    app.id,
    metadata,
    existingVersion,
  );
  const versionLocalizationId = await ensureVersionLocalization(
    token,
    versionId,
    metadata,
    existingVersionLocalization,
  );
  const ageRatingDeclarationId = await updateAgeRating(
    token,
    ageRatingDeclaration,
    metadata,
  );

  console.log(JSON.stringify({
    result: "applied",
    appId: app.id,
    appInfoId: appInfo.id,
    appInfoLocalizationId,
    appStoreVersionId: versionId,
    appStoreVersionLocalizationId: versionLocalizationId,
    ageRatingDeclarationId,
    values: publicFieldValues(metadata),
    notAutomated: [
      "App Privacy questionnaire",
      "content-rights declaration",
      "pricing",
      "storefront availability",
      "EU DSA status",
      "App Review contact",
      "screenshots",
      "build selection",
      "submission",
      "release",
    ],
  }, null, 2));
}

if (
  process.argv[1] &&
  pathToFileURL(process.argv[1]).href === import.meta.url
) {
  main().catch((error) => {
    console.error(error.message);
    if (attemptedResources.length > 0) {
      console.error(JSON.stringify({
        result: appliedResources.length > 0
          ? "partial_failure"
          : "failure",
        appliedResources,
        attemptedResources,
        failedResource: currentResource,
        unattemptedResources: METADATA_RESOURCES.filter(
          (name) => !attemptedResources.includes(name),
        ),
      }));
    }
    process.exitCode = 1;
  });
}

export {
  apiRequest,
  createToken,
  exactlyOne,
  findApp,
  findVersion,
  findVersionLocalization,
  query,
  requiredEnvironment,
  validateMetadata,
};

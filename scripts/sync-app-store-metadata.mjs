import { createPrivateKey, sign } from "node:crypto";
import { readFile } from "node:fs/promises";
import process from "node:process";

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
const appliedResources = [];

function fail(message) {
  throw new Error(message);
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

async function apiRequest(token, method, path, body = undefined) {
  const response = await fetch(`${API_ORIGIN}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/json",
      ...(body ? { "Content-Type": "application/json" } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
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
  if (!response.ok) {
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

async function ensureAppInfoLocalization(
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
  const attributes = {
    name: metadata.name,
    subtitle: metadata.subtitle,
    privacyPolicyUrl: metadata.privacy_policy_url,
  };
  const existing = atMostOne(
    payload,
    `${metadata.locale} app info localization`,
  );
  if (existing) {
    await apiRequest(
      token,
      "PATCH",
      `/v1/appInfoLocalizations/${existing.id}`,
      patchResource("appInfoLocalizations", existing.id, attributes),
    );
    appliedResources.push("appInfoLocalization");
    return existing.id;
  }
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
  appliedResources.push("appInfoLocalization");
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
  appliedResources.push("appInfoCategories");
}

async function findVersion(token, appId, metadata) {
  const payload = await apiRequest(
    token,
    "GET",
    `/v1/apps/${appId}/appStoreVersions?${query({
      "filter[platform]": metadata.platform,
      "filter[versionString]": metadata.version,
      "fields[appStoreVersions]": [
        "platform",
        "versionString",
        "appVersionState",
        "copyright",
        "releaseType",
      ].join(","),
      limit: 2,
    })}`,
  );
  let version = atMostOne(
    payload,
    `${metadata.platform} version ${metadata.version}`,
  );
  const state = version?.attributes?.appVersionState;
  if (state && !EDITABLE_VERSION_STATES.has(state)) {
    fail(`App Store version ${metadata.version} is not editable (${state}).`);
  }
  return version;
}

async function ensureVersion(token, appId, metadata, existingVersion) {
  let version = existingVersion;
  if (!version) {
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
    appliedResources.push("appStoreVersion");
  }
  await apiRequest(
    token,
    "PATCH",
    `/v1/appStoreVersions/${version.id}`,
    patchResource(
      "appStoreVersions",
      version.id,
      {
        copyright: metadata.copyright,
        reviewType: "APP_STORE",
        releaseType: metadata.release_type,
      },
    ),
  );
  appliedResources.push("appStoreVersion");
  return version.id;
}

async function ensureVersionLocalization(
  token,
  versionId,
  metadata,
) {
  const payload = await apiRequest(
    token,
    "GET",
    `/v1/appStoreVersions/${versionId}/appStoreVersionLocalizations?${query({
      "filter[locale]": metadata.locale,
      limit: 2,
    })}`,
  );
  const attributes = {
    description: metadata.description,
    keywords: metadata.keywords,
    marketingUrl: metadata.marketing_url || null,
    promotionalText: metadata.promotional_text,
    supportUrl: metadata.support_url,
    whatsNew: metadata.whats_new || null,
  };
  const existing = atMostOne(
    payload,
    `${metadata.locale} version localization`,
  );
  if (existing) {
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
    appliedResources.push("appStoreVersionLocalization");
    return existing.id;
  }
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
  appliedResources.push("appStoreVersionLocalization");
  return created.data.id;
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
  appliedResources.push("ageRatingDeclaration");
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
  const ageRatingDeclaration = await findAgeRatingDeclaration(
    token,
    appInfo.id,
  );

  await updateCategories(token, appInfo.id, metadata);
  const appInfoLocalizationId = await ensureAppInfoLocalization(
    token,
    appInfo.id,
    metadata,
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

main().catch((error) => {
  console.error(error.message);
  if (appliedResources.length > 0) {
    console.error(JSON.stringify({
      result: "partial_failure",
      appliedResources,
    }));
  }
  process.exitCode = 1;
});

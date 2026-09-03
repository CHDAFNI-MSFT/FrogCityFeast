#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import {
  createHash,
  createPrivateKey,
  sign,
  X509Certificate,
} from "node:crypto";
import {
  appendFile,
  chmod,
  lstat,
  readFile,
  realpath,
  writeFile,
} from "node:fs/promises";
import {
  basename,
  dirname,
  isAbsolute,
  join,
  resolve,
} from "node:path";
import process from "node:process";
import { pathToFileURL } from "node:url";

const API_ORIGIN = "https://api.appstoreconnect.apple.com";
const DEVICE_ENV_NAMES = [
  "IOS_AD_HOC_DEVICE_UDID_1",
  "IOS_AD_HOC_DEVICE_UDID_2",
  "IOS_AD_HOC_DEVICE_UDID_3",
];
const UDID_PATTERN = /^(?:[A-Fa-f0-9]{40}|[A-Fa-f0-9]{8}-[A-Fa-f0-9]{16})$/;
const UUID_PATTERN = /^[A-Fa-f0-9]{8}(?:-[A-Fa-f0-9]{4}){3}-[A-Fa-f0-9]{12}$/;
const PROFILE_TYPE = "IOS_APP_ADHOC";
const PRODUCT_PROFILE_IDENTITY = "FrogCityFeast";
export const PROFILE_GENERATION_TOKEN = "adhoc-generation-1";
export const MINIMUM_VALIDITY_MS = 7 * 24 * 60 * 60 * 1000;
export const API_PROFILE_FILENAME =
  "frogcityfeast-api-provisioning.mobileprovision";
const runtimeSensitiveValues = [];

class AppleApiError extends Error {
  constructor(message, status = null, ambiguous = false) {
    super(message);
    this.name = "AppleApiError";
    this.status = status;
    this.ambiguous = ambiguous;
  }
}

function fail(message) {
  throw new Error(message);
}

function requireCondition(condition, message) {
  if (!condition) {
    fail(message);
  }
}

function requiredEnvironment(environment, name) {
  const value = environment[name];
  if (typeof value !== "string" || !value.trim()) {
    fail(`${name} is required.`);
  }
  return value;
}

export function decodeBase64Strict(value, label = "Value") {
  if (typeof value !== "string") {
    fail(`${label} is not valid Base64.`);
  }
  const compact = value.replace(/\s/g, "");
  if (
    !compact ||
    compact.length % 4 !== 0 ||
    !/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(
      compact,
    )
  ) {
    fail(`${label} is not valid Base64.`);
  }
  const decoded = Buffer.from(compact, "base64");
  if (decoded.toString("base64") !== compact) {
    fail(`${label} is not valid Base64.`);
  }
  return decoded;
}

export function normalizeUdid(value, label = "Device UDID") {
  if (
    typeof value !== "string" ||
    value !== value.trim() ||
    !UDID_PATTERN.test(value)
  ) {
    fail(`${label} has an unsupported format.`);
  }
  return value.toUpperCase();
}

export function validateThreeDeviceInputs(environment) {
  const unexpected = Object.keys(environment).filter((name) => (
    /^IOS_AD_HOC_DEVICE_UDID_[0-9]+$/.test(name) &&
    !DEVICE_ENV_NAMES.includes(name) &&
    typeof environment[name] === "string" &&
    environment[name].length > 0
  ));
  if (unexpected.length > 0) {
    fail("Exactly the three numbered Ad Hoc device secrets are permitted.");
  }

  const devices = DEVICE_ENV_NAMES.map((environmentName, offset) => {
    const value = requiredEnvironment(environment, environmentName);
    return {
      environmentName,
      index: offset + 1,
      udid: normalizeUdid(value, environmentName),
    };
  });
  if (new Set(devices.map((device) => device.udid)).size !== devices.length) {
    fail("The protected Ad Hoc device UDIDs must be unique.");
  }
  return devices;
}

function base64Url(value) {
  return Buffer.from(value).toString("base64url");
}

export function createTeamToken(
  keyId,
  issuerId,
  privateKeyPem,
  nowSeconds = Math.floor(Date.now() / 1000),
) {
  const header = base64Url(JSON.stringify({
    alg: "ES256",
    kid: keyId,
    typ: "JWT",
  }));
  const payload = base64Url(JSON.stringify({
    iss: issuerId,
    iat: nowSeconds,
    exp: nowSeconds + 1199,
    aud: "appstoreconnect-v1",
  }));
  const signingInput = `${header}.${payload}`;
  let signature;
  try {
    signature = sign(
      null,
      Buffer.from(signingInput),
      {
        key: createPrivateKey(privateKeyPem),
        dsaEncoding: "ieee-p1363",
      },
    );
  } catch {
    fail("The protected provisioning private key is invalid.");
  }
  return `${signingInput}.${base64Url(signature)}`;
}

function sanitizeText(value, sensitiveValues) {
  let result = String(value ?? "");
  for (const sensitiveValue of [...sensitiveValues]
    .filter((item) => typeof item === "string" && item.length > 0)
    .sort((left, right) => right.length - left.length)) {
    result = result.split(sensitiveValue).join("[REDACTED]");
  }
  return result
    .replace(
      /(?:[A-Fa-f0-9]{40}|[A-Fa-f0-9]{8}-[A-Fa-f0-9]{16})/g,
      "[REDACTED_DEVICE]",
    )
    .replace(/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g, "[REDACTED_TOKEN]")
    .replace(
      /-----BEGIN [^-]+-----[\s\S]*?-----END [^-]+-----/g,
      "[REDACTED_KEY]",
    );
}

function query(parameters) {
  const values = new URLSearchParams();
  for (const [name, value] of Object.entries(parameters)) {
    values.set(name, String(value));
  }
  return values.toString();
}

async function apiRequest({
  token,
  method,
  path,
  operation,
  body,
  sensitiveValues,
  fetchImplementation = fetch,
}) {
  let response;
  try {
    response = await fetchImplementation(`${API_ORIGIN}${path}`, {
      method,
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: "application/json",
        ...(body ? { "Content-Type": "application/json" } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
    });
  } catch {
    if (method === "POST") {
      throw new AppleApiError(
        `Apple API ${operation} completion is ambiguous; reconciliation is required.`,
        null,
        true,
      );
    }
    throw new AppleApiError(`Apple API ${operation} could not be completed.`);
  }

  const text = await response.text();
  let payload = {};
  if (text) {
    try {
      payload = JSON.parse(text);
    } catch {
      throw new AppleApiError(
        `Apple API ${operation} returned an invalid response.`,
        response.status,
        method === "POST",
      );
    }
  }
  if (!response.ok) {
    const details = Array.isArray(payload.errors)
      ? payload.errors.map((error) => (
        `${error.status ?? response.status} ${error.code ?? "ERROR"}`
      )).join("; ")
      : `HTTP ${response.status}`;
    const safeDetails = sanitizeText(details, sensitiveValues);
    throw new AppleApiError(
      `Apple API ${operation} failed: ${safeDetails}`,
      response.status,
      method === "POST" && response.status >= 500,
    );
  }
  return payload;
}

function validateResource(resource, type, label) {
  if (
    !resource ||
    resource.type !== type ||
    typeof resource.id !== "string" ||
    !resource.id.trim() ||
    !resource.attributes ||
    typeof resource.attributes !== "object"
  ) {
    fail(`The ${label} response is invalid.`);
  }
  return resource;
}

function requireCompleteCollection(payload, label) {
  if (payload?.links?.next) {
    fail(`The ${label} query is incomplete and cannot be used safely.`);
  }
}

export function selectExactDevice(payload, expectedUdid) {
  requireCompleteCollection(payload, "device");
  if (!Array.isArray(payload?.data)) {
    fail("The device query response does not contain a data array.");
  }
  if (payload.data.length === 0) {
    return null;
  }
  if (payload.data.length !== 1) {
    fail(`Expected at most one exact registered device; found ${payload.data.length}.`);
  }
  const resource = validateResource(payload.data[0], "devices", "device");
  const attributes = resource.attributes;
  const actualUdid = normalizeUdid(attributes.udid, "The registered device UDID");
  if (actualUdid !== normalizeUdid(expectedUdid)) {
    fail("The device query returned a non-matching registered device.");
  }
  if (
    attributes.platform !== "IOS" ||
    attributes.deviceClass !== "IPAD"
  ) {
    fail("The registered device is not exactly an IOS/IPAD device.");
  }
  if (attributes.status === "DISABLED") {
    fail("A matching registered device is disabled and cannot be reused.");
  }
  if (attributes.status !== "ENABLED") {
    fail("The matching registered device is not enabled.");
  }
  return resource;
}

export function buildDevicePayload(udid, index) {
  normalizeUdid(udid);
  requireCondition(
    Number.isInteger(index) && index >= 1 && index <= 3,
    "The device name index is invalid.",
  );
  return {
    data: {
      type: "devices",
      attributes: {
        name: `Frog City Feast Test iPad ${index}`,
        platform: "IOS",
        udid,
      },
    },
  };
}

export function selectExactBundle(payload, bundleIdentifier) {
  requireCompleteCollection(payload, "bundle ID");
  if (!Array.isArray(payload?.data)) {
    fail("The bundle ID query response does not contain a data array.");
  }
  if (payload.data.length !== 1) {
    fail(`Expected exactly one matching bundle ID; found ${payload.data.length}.`);
  }
  const resource = validateResource(payload.data[0], "bundleIds", "bundle ID");
  if (resource.attributes.identifier !== bundleIdentifier) {
    fail("The bundle ID query returned a non-matching identifier.");
  }
  if (!["IOS", "UNIVERSAL"].includes(resource.attributes.platform)) {
    fail("The matching bundle ID is not available for iOS.");
  }
  return resource;
}

export function normalizeFingerprint(value) {
  if (typeof value !== "string") {
    fail("A certificate fingerprint is invalid.");
  }
  const normalized = value.replace(/[^A-Fa-f0-9]/g, "").toUpperCase();
  if (!/^[A-F0-9]{64}$/.test(normalized)) {
    fail("A certificate fingerprint is invalid.");
  }
  return normalized;
}

export function normalizeSerial(value) {
  if (
    typeof value !== "string" ||
    !/^[A-Fa-f0-9: ]+$/.test(value.trim())
  ) {
    fail("A certificate serial number is invalid.");
  }
  const compact = value.replace(/[: ]/g, "").toUpperCase().replace(/^0+/, "");
  if (!compact || !/^[A-F0-9]+$/.test(compact)) {
    return "0";
  }
  return compact;
}

function subjectValue(subject, field) {
  if (typeof subject !== "string") {
    return null;
  }
  const match = subject.match(
    new RegExp(`(?:^|\\n|,\\s*)${field}\\s*=\\s*([^,\\n]+)`),
  );
  return match?.[1]?.trim() ?? null;
}

export function parseX509Certificate(content) {
  let certificate;
  try {
    certificate = new X509Certificate(content);
  } catch {
    fail("An Apple certificate could not be decoded.");
  }
  const validToMs = Date.parse(certificate.validTo);
  if (!Number.isFinite(validToMs)) {
    fail("An Apple certificate expiration date is invalid.");
  }
  return {
    fingerprint: createHash("sha256").update(certificate.raw).digest("hex")
      .toUpperCase(),
    serial: normalizeSerial(certificate.serialNumber),
    commonName: subjectValue(certificate.subject, "CN"),
    teamId: subjectValue(certificate.subject, "OU"),
    validToMs,
  };
}

function validateDistributionIdentity(identity, teamId, label) {
  if (identity.commonName?.startsWith("Apple Distribution:") !== true) {
    fail(`The ${label} is not a modern Apple Distribution certificate.`);
  }
  if (identity.teamId !== teamId) {
    fail(`The ${label} Team ID does not match APPLE_TEAM_ID.`);
  }
}

function parseRequiredDate(value, label) {
  if (typeof value !== "string") {
    fail(`${label} is missing.`);
  }
  const parsed = Date.parse(value);
  if (!Number.isFinite(parsed)) {
    fail(`${label} is invalid.`);
  }
  return parsed;
}

export function selectMatchingCertificate(
  payload,
  localIdentity,
  {
    teamId,
    nowMs = Date.now(),
    minimumValidityMs = MINIMUM_VALIDITY_MS,
    parseCertificate = parseX509Certificate,
  },
) {
  requireCompleteCollection(payload, "certificate");
  if (!Array.isArray(payload?.data)) {
    fail("The certificate query response does not contain a data array.");
  }
  validateDistributionIdentity(localIdentity, teamId, "protected certificate");
  if (localIdentity.validToMs <= nowMs + minimumValidityMs) {
    fail("The protected Apple Distribution certificate expires too soon.");
  }

  const localFingerprint = normalizeFingerprint(localIdentity.fingerprint);
  const localSerial = normalizeSerial(localIdentity.serial);
  const matches = [];
  for (const item of payload.data) {
    const resource = validateResource(item, "certificates", "certificate");
    const attributes = resource.attributes;
    if (attributes.certificateType !== "DISTRIBUTION") {
      fail("The certificate query returned a non-DISTRIBUTION certificate.");
    }
    const content = decodeBase64Strict(
      attributes.certificateContent,
      "Apple certificate content",
    );
    const identity = parseCertificate(content);
    const apiSerial = normalizeSerial(attributes.serialNumber);
    if (apiSerial !== normalizeSerial(identity.serial)) {
      fail("An Apple certificate serial number is inconsistent.");
    }
    const apiExpiration = parseRequiredDate(
      attributes.expirationDate,
      "An Apple certificate expiration date",
    );
    if (Math.abs(apiExpiration - identity.validToMs) > 5 * 60 * 1000) {
      fail("An Apple certificate expiration date is inconsistent.");
    }
    if (
      normalizeFingerprint(identity.fingerprint) === localFingerprint &&
      apiSerial === localSerial
    ) {
      validateDistributionIdentity(identity, teamId, "matching certificate");
      if (attributes.activated !== true) {
        fail("The matching Apple Distribution certificate is not active.");
      }
      if (
        apiExpiration <= nowMs + minimumValidityMs ||
        identity.validToMs <= nowMs + minimumValidityMs
      ) {
        fail("The matching Apple Distribution certificate expires too soon.");
      }
      matches.push({ resource, identity });
    }
  }
  if (matches.length !== 1) {
    fail(`Expected exactly one matching active certificate; found ${matches.length}.`);
  }
  return matches[0];
}

export function buildDeterministicProfileName({
  productIdentity = PRODUCT_PROFILE_IDENTITY,
  bundleIdentifier,
  normalizedUdids,
  certificateFingerprint,
  generationToken = PROFILE_GENERATION_TOKEN,
}) {
  requireCondition(
    typeof productIdentity === "string" && /^[A-Za-z0-9]+$/.test(productIdentity),
    "The profile product identity is invalid.",
  );
  requireCondition(
    typeof bundleIdentifier === "string" && bundleIdentifier.length > 0,
    "The profile bundle identity is invalid.",
  );
  requireCondition(
    typeof generationToken === "string" &&
      /^[A-Za-z0-9-]+$/.test(generationToken),
    "The profile generation token is invalid.",
  );
  const devices = normalizedUdids.map((value) => normalizeUdid(value)).sort();
  requireCondition(
    devices.length === 3 && new Set(devices).size === 3,
    "Exactly three unique normalized device UDIDs are required.",
  );
  const deviceHash = createHash("sha256")
    .update(devices.join("\n"))
    .digest("hex")
    .slice(0, 16);
  const certificateHash = normalizeFingerprint(certificateFingerprint)
    .toLowerCase()
    .slice(0, 16);
  const bundleHash = createHash("sha256")
    .update(bundleIdentifier)
    .digest("hex")
    .slice(0, 8);
  const name = (
    `${productIdentity}-AdHoc-${generationToken}-` +
    `b${bundleHash}-d${deviceHash}-c${certificateHash}`
  );
  requireCondition(name.length <= 100, "The generated profile name is too long.");
  for (const udid of devices) {
    requireCondition(!name.includes(udid), "The generated profile name exposes a UDID.");
  }
  return name;
}

export function buildProfilePayload({
  name,
  bundleId,
  certificateId,
  deviceIds,
}) {
  requireCondition(
    typeof name === "string" && name.length > 0,
    "The profile name is required.",
  );
  requireCondition(
    typeof bundleId === "string" && bundleId.length > 0,
    "Exactly one bundle relationship is required.",
  );
  requireCondition(
    typeof certificateId === "string" && certificateId.length > 0,
    "Exactly one certificate relationship is required.",
  );
  requireCondition(
    Array.isArray(deviceIds) &&
      deviceIds.length === 3 &&
      new Set(deviceIds).size === 3 &&
      deviceIds.every((id) => typeof id === "string" && id.length > 0),
    "Exactly three unique device relationships are required.",
  );
  return {
    data: {
      type: "profiles",
      attributes: {
        name,
        profileType: PROFILE_TYPE,
      },
      relationships: {
        bundleId: {
          data: { type: "bundleIds", id: bundleId },
        },
        certificates: {
          data: [{ type: "certificates", id: certificateId }],
        },
        devices: {
          data: deviceIds.map((id) => ({ type: "devices", id })),
        },
      },
    },
  };
}

function exactRelationshipIds(relationship, type, count, label) {
  const data = relationship?.data;
  const items = Array.isArray(data) ? data : [data];
  if (
    items.length !== count ||
    items.some((item) => (
      !item ||
      item.type !== type ||
      typeof item.id !== "string" ||
      !item.id.trim()
    ))
  ) {
    fail(`The profile does not have the exact ${label} relationship.`);
  }
  return items.map((item) => item.id);
}

export function validateProfileResource(
  resource,
  {
    name,
    bundleId,
    certificateId,
    deviceIds,
    nowMs = Date.now(),
    minimumValidityMs = MINIMUM_VALIDITY_MS,
    requireContent = true,
  },
) {
  requireCondition(
    typeof bundleId === "string" && bundleId.length > 0,
    "The expected bundle relationship is invalid.",
  );
  requireCondition(
    typeof certificateId === "string" && certificateId.length > 0,
    "The expected certificate relationship is invalid.",
  );
  requireCondition(
    Array.isArray(deviceIds) &&
      deviceIds.length === 3 &&
      new Set(deviceIds).size === 3 &&
      deviceIds.every((id) => typeof id === "string" && id.length > 0),
    "The expected device relationships are invalid.",
  );
  validateResource(resource, "profiles", "profile");
  const attributes = resource.attributes;
  if (attributes.name !== name) {
    fail("A same-name profile response has a mismatched name.");
  }
  if (attributes.profileType !== PROFILE_TYPE) {
    fail("A same-name profile is not IOS_APP_ADHOC.");
  }
  if (attributes.platform !== "IOS") {
    fail("A same-name Ad Hoc profile is not for iOS.");
  }
  if (attributes.profileState !== "ACTIVE") {
    fail("A same-name Ad Hoc profile is not active.");
  }
  if (
    parseRequiredDate(attributes.expirationDate, "The profile expiration date") <=
    nowMs + minimumValidityMs
  ) {
    fail("The same-name Ad Hoc profile expires too soon.");
  }
  if (
    typeof attributes.uuid !== "string" ||
    !UUID_PATTERN.test(attributes.uuid)
  ) {
    fail("The Ad Hoc profile API UUID is invalid.");
  }
  if (requireContent) {
    decodeBase64Strict(attributes.profileContent, "Ad Hoc profile content");
  }

  const actualBundleIds = exactRelationshipIds(
    resource.relationships?.bundleId,
    "bundleIds",
    1,
    "one-bundle",
  );
  const actualCertificateIds = exactRelationshipIds(
    resource.relationships?.certificates,
    "certificates",
    1,
    "one-certificate",
  );
  const actualDeviceIds = exactRelationshipIds(
    resource.relationships?.devices,
    "devices",
    3,
    "three-device",
  );
  if (actualBundleIds[0] !== bundleId) {
    fail("The same-name profile has a mismatched bundle relationship.");
  }
  if (actualCertificateIds[0] !== certificateId) {
    fail("The same-name profile has a mismatched certificate relationship.");
  }
  if (
    actualDeviceIds.length !== deviceIds.length ||
    new Set(actualDeviceIds).size !== actualDeviceIds.length ||
    actualDeviceIds.some((id) => !deviceIds.includes(id))
  ) {
    fail("The same-name profile has a mismatched device relationship.");
  }
  return resource;
}

export function selectExistingProfile(payload, expected) {
  requireCompleteCollection(payload, "profile");
  if (!Array.isArray(payload?.data)) {
    fail("The profile query response does not contain a data array.");
  }
  if (payload.data.length === 0) {
    return null;
  }
  if (payload.data.length !== 1) {
    fail(`Expected at most one exact-name profile; found ${payload.data.length}.`);
  }
  return validateProfileResource(payload.data[0], expected);
}

function sleep(milliseconds) {
  return new Promise((resolvePromise) => setTimeout(resolvePromise, milliseconds));
}

async function boundedReconcile(reader, label) {
  const delays = [0, 1000, 2000, 4000];
  for (const delay of delays) {
    if (delay > 0) {
      await sleep(delay);
    }
    try {
      const result = await reader();
      if (result) {
        return result;
      }
    } catch (error) {
      if (
        !(error instanceof AppleApiError) ||
        (error.status !== null && error.status < 500)
      ) {
        throw error;
      }
    }
  }
  fail(`Apple API ${label} could not be reconciled after bounded re-reads.`);
}

async function requireSafeRunnerTemp(runnerTemp) {
  if (!isAbsolute(runnerTemp) || resolve(runnerTemp) !== runnerTemp) {
    fail("RUNNER_TEMP must be an absolute normalized path.");
  }
  const stat = await lstat(runnerTemp);
  if (!stat.isDirectory() || stat.isSymbolicLink()) {
    fail("RUNNER_TEMP must be a non-symlink directory.");
  }
  if (await realpath(runnerTemp) !== runnerTemp) {
    fail("RUNNER_TEMP must not resolve through a symbolic link.");
  }
}

async function writeRunnerFile(runnerTemp, filename, content) {
  const path = join(runnerTemp, filename);
  if (
    dirname(path) !== runnerTemp ||
    basename(path) !== filename
  ) {
    fail("A temporary signing path is invalid.");
  }
  try {
    const existing = await lstat(path);
    if (!existing.isFile() || existing.isSymbolicLink()) {
      fail("A temporary signing path is not a regular file.");
    }
  } catch (error) {
    if (error?.code !== "ENOENT") {
      throw error;
    }
  }
  await writeFile(path, content, { mode: 0o600 });
  await chmod(path, 0o600);
  return path;
}

async function readLocalCertificate(runnerTemp, certificateBase64, password) {
  const p12Path = await writeRunnerFile(
    runnerTemp,
    "frogcityfeast-api-distribution.p12",
    decodeBase64Strict(certificateBase64, "APPLE_CERTIFICATE_BASE64"),
  );
  const pemPath = join(runnerTemp, "frogcityfeast-api-distribution.pem");
  try {
    const existing = await lstat(pemPath);
    if (!existing.isFile() || existing.isSymbolicLink()) {
      fail("The temporary certificate path is not a regular file.");
    }
  } catch (error) {
    if (error?.code !== "ENOENT") {
      throw error;
    }
  }
  try {
    execFileSync(
      "openssl",
      [
        "pkcs12",
        "-in",
        p12Path,
        "-clcerts",
        "-nokeys",
        "-passin",
        "env:APPLE_CERTIFICATE_PASSWORD",
        "-out",
        pemPath,
      ],
      {
        env: {
          ...process.env,
          APPLE_CERTIFICATE_PASSWORD: password,
        },
        stdio: ["ignore", "ignore", "ignore"],
      },
    );
  } catch {
    fail("The protected Apple Distribution certificate could not be decoded.");
  }
  await chmod(pemPath, 0o600);
  return parseX509Certificate(await readFile(pemPath));
}

async function parseMobileProvision(profilePath, plistPath) {
  try {
    execFileSync(
      "security",
      ["cms", "-D", "-i", profilePath, "-o", plistPath],
      { stdio: ["ignore", "ignore", "ignore"] },
    );
  } catch {
    fail("The API provisioning profile is not a valid CMS document.");
  }
  await chmod(plistPath, 0o600);
  let json;
  try {
    json = execFileSync(
      "plutil",
      ["-convert", "json", "-o", "-", plistPath],
      {
        encoding: "utf8",
        maxBuffer: 16 * 1024 * 1024,
        stdio: ["ignore", "pipe", "ignore"],
      },
    );
    return JSON.parse(json);
  } catch {
    fail("The API provisioning profile does not contain a valid plist.");
  }
}

export function validateDecodedProfile(
  profile,
  {
    apiUuid,
    apiExpirationDate,
    teamId,
    bundleIdentifier,
    normalizedUdids,
    certificateFingerprint,
    nowMs = Date.now(),
    minimumValidityMs = MINIMUM_VALIDITY_MS,
  },
) {
  if (
    typeof apiUuid !== "string" ||
    !UUID_PATTERN.test(apiUuid) ||
    typeof profile?.UUID !== "string" ||
    !UUID_PATTERN.test(profile.UUID) ||
    profile.UUID.toUpperCase() !== apiUuid.toUpperCase()
  ) {
    fail("The profile plist UUID does not agree with the Apple API UUID.");
  }
  const apiExpiration = parseRequiredDate(
    apiExpirationDate,
    "The API profile expiration date",
  );
  const plistExpiration = parseRequiredDate(
    profile.ExpirationDate,
    "The profile plist expiration date",
  );
  if (
    apiExpiration <= nowMs + minimumValidityMs ||
    plistExpiration <= nowMs + minimumValidityMs ||
    Math.abs(apiExpiration - plistExpiration) > 5 * 60 * 1000
  ) {
    fail("The profile expiration is invalid or inconsistent.");
  }
  if (
    !Array.isArray(profile.TeamIdentifier) ||
    profile.TeamIdentifier.length !== 1 ||
    profile.TeamIdentifier[0] !== teamId
  ) {
    fail("The profile plist Team ID does not match APPLE_TEAM_ID.");
  }
  if (!Array.isArray(profile.Platform) || !profile.Platform.includes("iOS")) {
    fail("The profile plist does not support iOS.");
  }
  if (
    !profile.Entitlements ||
    profile.Entitlements["application-identifier"] !==
      `${teamId}.${bundleIdentifier}`
  ) {
    fail("The profile plist has the wrong application identifier.");
  }
  if (profile.Entitlements["get-task-allow"] !== false) {
    fail("The profile plist permits development debugging.");
  }
  if (profile.ProvisionsAllDevices === true) {
    fail("Enterprise provisioning is not permitted.");
  }
  if (!Array.isArray(profile.ProvisionedDevices)) {
    fail("The profile plist has no registered-device list.");
  }
  const expectedDevices = normalizedUdids.map((value) => normalizeUdid(value));
  const actualDevices = profile.ProvisionedDevices.map((value) => (
    normalizeUdid(value, "A profile device UDID")
  ));
  if (
    expectedDevices.length !== 3 ||
    new Set(expectedDevices).size !== 3 ||
    actualDevices.length !== 3 ||
    new Set(actualDevices).size !== 3 ||
    actualDevices.some((value) => !expectedDevices.includes(value))
  ) {
    fail("The profile plist device set is not exactly the approved three devices.");
  }
  if (
    !Array.isArray(profile.DeveloperCertificates) ||
    profile.DeveloperCertificates.length !== 1
  ) {
    fail("The profile plist does not contain exactly one certificate.");
  }
  const profileFingerprint = createHash("sha256")
    .update(decodeBase64Strict(
      profile.DeveloperCertificates[0],
      "Profile certificate content",
    ))
    .digest("hex")
    .toUpperCase();
  if (
    normalizeFingerprint(profileFingerprint) !==
    normalizeFingerprint(certificateFingerprint)
  ) {
    fail("The profile plist does not include the selected certificate.");
  }
  return profile;
}

async function main() {
  if (
    process.argv.length !== 3 ||
    process.argv[2] !== "--apply"
  ) {
    fail("Specify exactly --apply.");
  }

  for (const name of DEVICE_ENV_NAMES) {
    const value = process.env[name];
    if (typeof value === "string" && value.length > 0) {
      console.log(`::add-mask::${value}`);
    }
  }

  const devices = validateThreeDeviceInputs(process.env);
  const keyId = requiredEnvironment(process.env, "APPLE_PROVISIONING_KEY_ID");
  const issuerId = requiredEnvironment(
    process.env,
    "APP_STORE_CONNECT_ISSUER_ID",
  );
  const privateKeyBase64 = requiredEnvironment(
    process.env,
    "APPLE_PROVISIONING_PRIVATE_KEY_BASE64",
  );
  const teamId = requiredEnvironment(process.env, "APPLE_TEAM_ID");
  const bundleIdentifier = requiredEnvironment(process.env, "IOS_BUNDLE_ID");
  const certificateBase64 = requiredEnvironment(
    process.env,
    "APPLE_CERTIFICATE_BASE64",
  );
  const certificatePassword = requiredEnvironment(
    process.env,
    "APPLE_CERTIFICATE_PASSWORD",
  );
  const runnerTemp = requiredEnvironment(process.env, "RUNNER_TEMP");
  const githubEnvironmentPath = requiredEnvironment(process.env, "GITHUB_ENV");
  await requireSafeRunnerTemp(runnerTemp);

  const sensitiveValues = runtimeSensitiveValues;
  sensitiveValues.push(
    keyId,
    issuerId,
    privateKeyBase64,
    certificateBase64,
    certificatePassword,
    ...devices.map((device) => device.udid),
  );
  const privateKeyPem = decodeBase64Strict(
    privateKeyBase64,
    "APPLE_PROVISIONING_PRIVATE_KEY_BASE64",
  ).toString("utf8");
  const token = createTeamToken(keyId, issuerId, privateKeyPem);
  sensitiveValues.push(privateKeyPem, token);

  const request = (method, path, operation, body = undefined) => apiRequest({
    token,
    method,
    path,
    operation,
    body,
    sensitiveValues,
  });
  const findDevice = async (device) => selectExactDevice(
    await request(
      "GET",
      `/v1/devices?${query({
        "filter[udid]": device.udid,
        "fields[devices]":
          "name,platform,udid,status,deviceClass,model,addedDate",
        limit: 2,
      })}`,
      "device lookup",
    ),
    device.udid,
  );

  let createdDeviceCount = 0;
  const registeredDevices = [];
  for (const device of devices) {
    let resource = await findDevice(device);
    if (!resource) {
      try {
        await request(
          "POST",
          "/v1/devices",
          "device registration",
          buildDevicePayload(device.udid, device.index),
        );
      } catch (error) {
        if (
          !(error instanceof AppleApiError) ||
          (error.status !== 409 && !error.ambiguous)
        ) {
          throw error;
        }
      }
      resource = await boundedReconcile(
        () => findDevice(device),
        "device registration",
      );
      createdDeviceCount += 1;
    }
    registeredDevices.push(resource);
  }

  const bundle = selectExactBundle(
    await request(
      "GET",
      `/v1/bundleIds?${query({
        "filter[identifier]": bundleIdentifier,
        "fields[bundleIds]": "name,platform,identifier,seedId",
        limit: 2,
      })}`,
      "bundle ID lookup",
    ),
    bundleIdentifier,
  );

  const localCertificate = await readLocalCertificate(
    runnerTemp,
    certificateBase64,
    certificatePassword,
  );
  const certificatePayload = await request(
    "GET",
    `/v1/certificates?${query({
      "filter[certificateType]": "DISTRIBUTION",
      "fields[certificates]":
        "name,certificateType,displayName,serialNumber,platform," +
        "expirationDate,certificateContent,activated",
      limit: 200,
    })}`,
    "certificate lookup",
  );
  const certificate = selectMatchingCertificate(
    certificatePayload,
    localCertificate,
    { teamId },
  );

  const profileName = buildDeterministicProfileName({
    bundleIdentifier,
    normalizedUdids: devices.map((device) => device.udid),
    certificateFingerprint: certificate.identity.fingerprint,
  });
  const expectedProfile = {
    name: profileName,
    bundleId: bundle.id,
    certificateId: certificate.resource.id,
    deviceIds: registeredDevices.map((device) => device.id),
  };
  const findProfile = async () => selectExistingProfile(
    await request(
      "GET",
      `/v1/profiles?${query({
        "filter[name]": profileName,
        "filter[profileType]": PROFILE_TYPE,
        "fields[profiles]":
          "name,platform,profileType,profileState,uuid,createdDate," +
          "expirationDate,bundleId,devices,certificates",
        "fields[bundleIds]": "name,platform,identifier",
        "fields[devices]": "name,platform,udid,status",
        "fields[certificates]":
          "certificateType,serialNumber,expirationDate,activated",
        include: "bundleId,certificates,devices",
        "limit[devices]": 50,
        "limit[certificates]": 50,
        limit: 3,
      })}`,
      "profile lookup",
    ),
    {
      ...expectedProfile,
      requireContent: false,
    },
  );

  let profile = await findProfile();
  let profileState = "reused";
  if (!profile) {
    try {
      await request(
        "POST",
        "/v1/profiles",
        "profile creation",
        buildProfilePayload(expectedProfile),
      );
    } catch (error) {
      if (
        !(error instanceof AppleApiError) ||
        (error.status !== 409 && !error.ambiguous)
      ) {
        throw error;
      }
    }
    profile = await boundedReconcile(findProfile, "profile creation");
    profileState = "created";
  }

  const profileDetailPayload = await request(
    "GET",
    `/v1/profiles/${encodeURIComponent(profile.id)}?${query({
      "fields[profiles]":
        "name,platform,profileType,profileState,profileContent,uuid," +
        "createdDate,expirationDate,bundleId,devices,certificates",
      "fields[bundleIds]": "name,platform,identifier",
      "fields[devices]": "name,platform,udid,status",
      "fields[certificates]":
        "certificateType,serialNumber,expirationDate,activated",
      include: "bundleId,certificates,devices",
      "limit[devices]": 50,
      "limit[certificates]": 50,
    })}`,
    "profile download",
  );
  profile = validateProfileResource(
    profileDetailPayload?.data,
    expectedProfile,
  );

  const profilePath = await writeRunnerFile(
    runnerTemp,
    API_PROFILE_FILENAME,
    decodeBase64Strict(
      profile.attributes.profileContent,
      "Ad Hoc profile content",
    ),
  );
  const profilePlistPath = join(
    runnerTemp,
    "frogcityfeast-api-profile.plist",
  );
  try {
    const existing = await lstat(profilePlistPath);
    if (!existing.isFile() || existing.isSymbolicLink()) {
      fail("The temporary profile plist path is not a regular file.");
    }
  } catch (error) {
    if (error?.code !== "ENOENT") {
      throw error;
    }
  }
  const decodedProfile = await parseMobileProvision(
    profilePath,
    profilePlistPath,
  );
  validateDecodedProfile(decodedProfile, {
    apiUuid: profile.attributes.uuid,
    apiExpirationDate: profile.attributes.expirationDate,
    teamId,
    bundleIdentifier,
    normalizedUdids: devices.map((device) => device.udid),
    certificateFingerprint: certificate.identity.fingerprint,
  });

  if (
    !isAbsolute(githubEnvironmentPath) ||
    dirname(profilePath) !== runnerTemp
  ) {
    fail("The GitHub environment handoff path is invalid.");
  }
  await appendFile(
    githubEnvironmentPath,
    `APPLE_PROVISIONING_PROFILE_PATH=${profilePath}\n`,
    "utf8",
  );

  console.log(
    "Ad Hoc provisioning ready: " +
    `devices 3 (created ${createdDeviceCount}, reused ${3 - createdDeviceCount}); ` +
    `bundle 1; certificate 1; profile ${profileState}.`,
  );
}

if (
  process.argv[1] &&
  pathToFileURL(process.argv[1]).href === import.meta.url
) {
  main().catch((error) => {
    console.error(sanitizeText(
      error?.message ?? "Provisioning failed.",
      runtimeSensitiveValues,
    ));
    process.exitCode = 1;
  });
}

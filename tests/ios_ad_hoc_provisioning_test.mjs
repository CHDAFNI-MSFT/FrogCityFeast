import assert from "node:assert/strict";
import { createHash, generateKeyPairSync, verify } from "node:crypto";

import {
  buildDevicePayload,
  buildDeterministicProfileName,
  buildProfilePayload,
  createTeamToken,
  decodeBase64Strict,
  normalizeUdid,
  selectExactBundle,
  selectExactDevice,
  selectExistingProfile,
  selectMatchingCertificate,
  validateDecodedProfile,
  validateThreeDeviceInputs,
} from "../scripts/provision-ios-ad-hoc.mjs";

const NOW = Date.parse("2026-09-02T20:00:00Z");
const FUTURE = "2027-09-02T20:00:00Z";
const UDID_1 = "A1B2C3D4-00112233AABBCCDD";
const UDID_2 = "B2C3D4E5-11223344BBCCDDEE";
const UDID_3 = "00112233445566778899AABBCCDDEEFF00112233";
const UUID = "11111111-2222-3333-4444-555555555555";
const CERTIFICATE_BYTES = Buffer.from("synthetic-certificate");
const CERTIFICATE_FINGERPRINT = createHash("sha256")
  .update(CERTIFICATE_BYTES)
  .digest("hex")
  .toUpperCase();

{
  const { privateKey, publicKey } = generateKeyPairSync("ec", {
    namedCurve: "P-256",
  });
  const token = createTeamToken(
    "SYNTHETIC1",
    "11111111-2222-3333-4444-555555555555",
    privateKey.export({ type: "pkcs8", format: "pem" }),
    1000,
  );
  const [headerPart, payloadPart, signaturePart] = token.split(".");
  assert.equal(
    JSON.parse(Buffer.from(headerPart, "base64url")).alg,
    "ES256",
  );
  const tokenPayload = JSON.parse(Buffer.from(payloadPart, "base64url"));
  assert.equal(tokenPayload.exp - tokenPayload.iat, 1199);
  assert.equal(Buffer.from(signaturePart, "base64url").length, 64);
  assert.equal(
    verify(
      null,
      Buffer.from(`${headerPart}.${payloadPart}`),
      { key: publicKey, dsaEncoding: "ieee-p1363" },
      Buffer.from(signaturePart, "base64url"),
    ),
    true,
    "The Team JWT should use a valid P1363 ES256 signature.",
  );
}

function deviceEnvironment(overrides = {}) {
  return {
    IOS_AD_HOC_DEVICE_UDID_1: UDID_1.toLowerCase(),
    IOS_AD_HOC_DEVICE_UDID_2: UDID_2,
    IOS_AD_HOC_DEVICE_UDID_3: UDID_3,
    ...overrides,
  };
}

function device(id, udid, attributes = {}) {
  return {
    type: "devices",
    id,
    attributes: {
      udid,
      platform: "IOS",
      deviceClass: "IPAD",
      status: "ENABLED",
      ...attributes,
    },
  };
}

function bundle(id = "bundle-1", attributes = {}) {
  return {
    type: "bundleIds",
    id,
    attributes: {
      identifier: "com.example.synthetic",
      platform: "UNIVERSAL",
      ...attributes,
    },
  };
}

function profile(overrides = {}) {
  return {
    type: "profiles",
    id: "profile-1",
    attributes: {
      name: "Synthetic-AdHoc",
      platform: "IOS",
      profileType: "IOS_APP_ADHOC",
      profileState: "ACTIVE",
      expirationDate: FUTURE,
      uuid: UUID,
      profileContent: Buffer.from("synthetic-profile").toString("base64"),
      ...(overrides.attributes ?? {}),
    },
    relationships: {
      bundleId: {
        data: { type: "bundleIds", id: "bundle-1" },
      },
      certificates: {
        data: [{ type: "certificates", id: "certificate-1" }],
      },
      devices: {
        data: [
          { type: "devices", id: "device-1" },
          { type: "devices", id: "device-2" },
          { type: "devices", id: "device-3" },
        ],
      },
      ...(overrides.relationships ?? {}),
    },
  };
}

const expectedProfile = {
  name: "Synthetic-AdHoc",
  bundleId: "bundle-1",
  certificateId: "certificate-1",
  deviceIds: ["device-1", "device-2", "device-3"],
  nowMs: NOW,
};

{
  const devices = validateThreeDeviceInputs(deviceEnvironment());
  assert.deepEqual(
    devices.map((entry) => entry.udid),
    [UDID_1, UDID_2, UDID_3],
    "The exact three numbered inputs should be normalized to uppercase.",
  );
  assert.equal(
    normalizeUdid(UDID_1.toLowerCase()),
    UDID_1,
    "UDID normalization should be case-insensitive.",
  );
  assert.throws(
    () => validateThreeDeviceInputs(deviceEnvironment({
      IOS_AD_HOC_DEVICE_UDID_3: "",
    })),
    /IOS_AD_HOC_DEVICE_UDID_3 is required/,
  );
  assert.throws(
    () => validateThreeDeviceInputs(deviceEnvironment({
      IOS_AD_HOC_DEVICE_UDID_4: "C3D4E5F6-22334455CCDDEEFF",
    })),
    /Exactly the three numbered/,
  );
  assert.throws(
    () => validateThreeDeviceInputs(deviceEnvironment({
      IOS_AD_HOC_DEVICE_UDID_3: UDID_1.toLowerCase(),
    })),
    /must be unique/,
  );
  assert.throws(
    () => validateThreeDeviceInputs(deviceEnvironment({
      IOS_AD_HOC_DEVICE_UDID_2: "not-a-device",
    })),
    /unsupported format/,
  );
}

{
  assert.deepEqual(
    buildDevicePayload(UDID_1, 1).data.attributes,
    {
      name: "Frog City Feast Test iPad 1",
      platform: "IOS",
      udid: UDID_1,
    },
    "Device creation should use the fixed generic non-personal name.",
  );
  const exact = device("device-1", UDID_1.toLowerCase());
  assert.equal(
    selectExactDevice({ data: [exact] }, UDID_1),
    exact,
    "One exact enabled IOS/IPAD device should be selected.",
  );
  assert.equal(
    selectExactDevice({ data: [] }, UDID_1),
    null,
    "No exact device should permit registration.",
  );
  assert.throws(
    () => selectExactDevice({
      data: [device("disabled", UDID_1, { status: "DISABLED" })],
    }, UDID_1),
    /disabled/,
  );
  assert.throws(
    () => selectExactDevice({
      data: [device("phone", UDID_1, { deviceClass: "IPHONE" })],
    }, UDID_1),
    /IOS\/IPAD/,
  );
  assert.throws(
    () => selectExactDevice({
      data: [
        device("device-1", UDID_1),
        device("device-2", UDID_1),
      ],
    }, UDID_1),
    /at most one/,
  );
  assert.throws(
    () => selectExactDevice({
      data: [device("wrong", UDID_2)],
    }, UDID_1),
    /non-matching/,
  );
}

{
  const exact = bundle();
  assert.equal(
    selectExactBundle({ data: [exact] }, "com.example.synthetic"),
    exact,
    "One exact IOS/UNIVERSAL bundle should be selected.",
  );
  assert.throws(
    () => selectExactBundle({ data: [] }, "com.example.synthetic"),
    /exactly one/,
  );
  assert.throws(
    () => selectExactBundle({
      data: [bundle("wrong", { platform: "MAC_OS" })],
    }, "com.example.synthetic"),
    /not available for iOS/,
  );
  assert.throws(
    () => selectExactBundle({
      data: [bundle("wrong", { identifier: "com.example.other" })],
    }, "com.example.synthetic"),
    /non-matching/,
  );
}

{
  const localIdentity = {
    fingerprint: CERTIFICATE_FINGERPRINT,
    serial: "00:AB:CD",
    commonName: "Apple Distribution: Synthetic Owner (TEAM123456)",
    teamId: "TEAM123456",
    validToMs: Date.parse(FUTURE),
  };
  const certificateResource = {
    type: "certificates",
    id: "certificate-1",
    attributes: {
      certificateType: "DISTRIBUTION",
      activated: true,
      certificateContent: Buffer.from("fixture-one").toString("base64"),
      serialNumber: "ABCD",
      expirationDate: FUTURE,
    },
  };
  const parseCertificate = () => ({
    fingerprint: CERTIFICATE_FINGERPRINT.toLowerCase(),
    serial: "0000abcd",
    commonName: "Apple Distribution: Synthetic Owner (TEAM123456)",
    teamId: "TEAM123456",
    validToMs: Date.parse(FUTURE),
  });
  assert.equal(
    selectMatchingCertificate(
      { data: [certificateResource] },
      localIdentity,
      {
        teamId: "TEAM123456",
        nowMs: NOW,
        parseCertificate,
      },
    ).resource,
    certificateResource,
    "Fingerprint and normalized serial should select one active certificate.",
  );
  assert.throws(
    () => selectMatchingCertificate(
      { data: [certificateResource, { ...certificateResource, id: "second" }] },
      localIdentity,
      {
        teamId: "TEAM123456",
        nowMs: NOW,
        parseCertificate,
      },
    ),
    /exactly one matching active certificate/,
  );
  assert.throws(
    () => selectMatchingCertificate(
      { data: [certificateResource] },
      localIdentity,
      {
        teamId: "TEAM123456",
        nowMs: NOW,
        parseCertificate: () => ({
          ...parseCertificate(),
          commonName: "iPhone Distribution: Synthetic",
        }),
      },
    ),
    /not a modern Apple Distribution certificate/,
  );
  assert.throws(
    () => selectMatchingCertificate(
      {
        data: [{
          ...certificateResource,
          attributes: {
            ...certificateResource.attributes,
            activated: false,
          },
        }],
      },
      localIdentity,
      {
        teamId: "TEAM123456",
        nowMs: NOW,
        parseCertificate,
      },
    ),
    /not active/,
  );
  assert.equal(
    selectMatchingCertificate(
      {
        data: [
          {
            ...certificateResource,
            id: "unrelated-inactive",
            attributes: {
              ...certificateResource.attributes,
              activated: false,
              certificateContent: Buffer.from("fixture-two").toString("base64"),
              serialNumber: "1234",
            },
          },
          certificateResource,
        ],
      },
      localIdentity,
      {
        teamId: "TEAM123456",
        nowMs: NOW,
        parseCertificate: (content) => {
          if (content.toString("utf8") === "fixture-one") {
            return parseCertificate();
          }
          return {
            ...parseCertificate(),
            fingerprint: createHash("sha256")
              .update(content)
              .digest("hex")
              .toUpperCase(),
            serial: "1234",
          };
        },
      },
    ).resource,
    certificateResource,
    "An unrelated inactive certificate must not block the active exact match.",
  );
  assert.throws(
    () => selectMatchingCertificate(
      {
        data: [{
          ...certificateResource,
          attributes: {
            ...certificateResource.attributes,
            activated: undefined,
          },
        }],
      },
      localIdentity,
      {
        teamId: "TEAM123456",
        nowMs: NOW,
        parseCertificate,
      },
    ),
    /not active/,
  );
  assert.throws(
    () => selectMatchingCertificate(
      { data: [certificateResource] },
      { ...localIdentity, serial: "FFFF" },
      {
        teamId: "TEAM123456",
        nowMs: NOW,
        parseCertificate,
      },
    ),
    /found 0/,
  );
  assert.throws(
    () => selectExactDevice({
      data: [device("device-1", UDID_1)],
      links: { next: "https://example.invalid/next" },
    }, UDID_1),
    /query is incomplete/,
  );
}

{
  const nameOne = buildDeterministicProfileName({
    bundleIdentifier: "com.example.synthetic",
    normalizedUdids: [UDID_1, UDID_2, UDID_3],
    certificateFingerprint: CERTIFICATE_FINGERPRINT,
  });
  const nameTwo = buildDeterministicProfileName({
    bundleIdentifier: "com.example.synthetic",
    normalizedUdids: [UDID_3, UDID_1.toLowerCase(), UDID_2],
    certificateFingerprint: CERTIFICATE_FINGERPRINT.toLowerCase(),
  });
  assert.equal(nameOne, nameTwo, "Profile naming should be order-independent.");
  for (const udid of [UDID_1, UDID_2, UDID_3]) {
    assert.equal(
      nameOne.includes(udid),
      false,
      "The deterministic profile name must not contain a raw UDID.",
    );
  }
  assert.match(nameOne, /^FrogCityFeast-AdHoc-adhoc-generation-1-/);
}

{
  const payload = buildProfilePayload({
    name: "Synthetic-AdHoc",
    bundleId: "bundle-1",
    certificateId: "certificate-1",
    deviceIds: ["device-1", "device-2", "device-3"],
  });
  assert.deepEqual(
    payload.data.relationships.bundleId.data,
    { type: "bundleIds", id: "bundle-1" },
  );
  assert.deepEqual(
    payload.data.relationships.certificates.data,
    [{ type: "certificates", id: "certificate-1" }],
  );
  assert.deepEqual(
    payload.data.relationships.devices.data,
    [
      { type: "devices", id: "device-1" },
      { type: "devices", id: "device-2" },
      { type: "devices", id: "device-3" },
    ],
  );
  assert.throws(
    () => buildProfilePayload({
      name: "Synthetic-AdHoc",
      bundleId: "bundle-1",
      certificateId: "certificate-1",
      deviceIds: ["device-1", "device-2"],
    }),
    /Exactly three/,
  );
  assert.throws(
    () => selectExactBundle({
      data: [bundle()],
      links: { next: "https://example.invalid/next" },
    }, "com.example.synthetic"),
    /query is incomplete/,
  );
}

{
  const exact = profile();
  assert.equal(
    selectExistingProfile({ data: [exact] }, expectedProfile),
    exact,
    "One exact active same-name profile should be reused.",
  );
  assert.equal(
    selectExistingProfile({ data: [] }, expectedProfile),
    null,
    "No same-name profile should permit one creation attempt.",
  );
  assert.throws(
    () => selectExistingProfile(
      { data: [exact, { ...exact, id: "profile-2" }] },
      expectedProfile,
    ),
    /at most one exact-name profile/,
  );
  assert.throws(
    () => selectExistingProfile({
      data: [profile({
        relationships: {
          devices: {
            data: [
              { type: "devices", id: "device-1" },
              { type: "devices", id: "device-2" },
              { type: "devices", id: "wrong-device" },
            ],
          },
        },
      })],
    }, expectedProfile),
    /mismatched device relationship/,
  );
  assert.throws(
    () => selectExistingProfile({
      data: [profile({
        attributes: { profileState: "INVALID" },
      })],
    }, expectedProfile),
    /not active/,
  );
  assert.throws(
    () => selectExistingProfile({
      data: [profile({
        attributes: { profileType: "IOS_APP_STORE" },
      })],
    }, expectedProfile),
    /not IOS_APP_ADHOC/,
  );
  assert.throws(
    () => selectExistingProfile({
      data: [exact],
      links: { next: "https://example.invalid/next" },
    }, expectedProfile),
    /query is incomplete/,
  );
}

{
  assert.deepEqual(
    decodeBase64Strict("c3ludGhldGlj", "Fixture"),
    Buffer.from("synthetic"),
  );
  for (const invalid of ["", "%%%", "c3ludGhldGlj=", "abc"]) {
    assert.throws(
      () => decodeBase64Strict(invalid, "Fixture"),
      /not valid Base64/,
    );
  }
}

{
  const decodedProfile = {
    UUID,
    ExpirationDate: FUTURE,
    TeamIdentifier: ["TEAM123456"],
    Platform: ["iOS"],
    Entitlements: {
      "application-identifier": "TEAM123456.com.example.synthetic",
      "get-task-allow": false,
    },
    ProvisionedDevices: [UDID_3, UDID_1.toLowerCase(), UDID_2],
    ProvisionsAllDevices: false,
    DeveloperCertificates: [CERTIFICATE_BYTES.toString("base64")],
  };
  assert.equal(
    validateDecodedProfile(decodedProfile, {
      apiUuid: UUID.toLowerCase(),
      apiExpirationDate: FUTURE,
      teamId: "TEAM123456",
      bundleIdentifier: "com.example.synthetic",
      normalizedUdids: [UDID_1, UDID_2, UDID_3],
      certificateFingerprint: CERTIFICATE_FINGERPRINT,
      nowMs: NOW,
    }),
    decodedProfile,
  );
  assert.throws(
    () => validateDecodedProfile({
      ...decodedProfile,
      ProvisionedDevices: [UDID_1, UDID_2, UDID_2],
    }, {
      apiUuid: UUID,
      apiExpirationDate: FUTURE,
      teamId: "TEAM123456",
      bundleIdentifier: "com.example.synthetic",
      normalizedUdids: [UDID_1, UDID_2, UDID_3],
      certificateFingerprint: CERTIFICATE_FINGERPRINT,
      nowMs: NOW,
    }),
    /not exactly/,
  );
}

console.log("iOS Ad Hoc API provisioning helper tests passed.");

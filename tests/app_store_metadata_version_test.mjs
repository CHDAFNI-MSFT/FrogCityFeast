import assert from "node:assert/strict";

import {
  selectVersion,
} from "../scripts/sync-app-store-metadata.mjs";

const metadata = {
  platform: "IOS",
  version: "0.1.0",
};

function version(id, versionString, appVersionState) {
  return {
    type: "appStoreVersions",
    id,
    attributes: {
      platform: "IOS",
      versionString,
      appVersionState,
    },
  };
}

assert.equal(
  selectVersion({ data: [] }, metadata),
  null,
  "No App Store version should allow creation of the reviewed version.",
);

const exactVersion = version(
  "exact",
  "0.1.0",
  "PREPARE_FOR_SUBMISSION",
);
assert.equal(
  selectVersion({ data: [exactVersion] }, metadata),
  exactVersion,
  "The single editable reviewed version should be reused idempotently.",
);

const initialVersion = version(
  "initial",
  "1.0",
  "PREPARE_FOR_SUBMISSION",
);
assert.equal(
  selectVersion({ data: [initialVersion] }, metadata),
  initialVersion,
  "The single editable initial version should be reused for renaming.",
);

assert.throws(
  () => selectVersion({
    data: [version("released", "1.0", "READY_FOR_SALE")],
  }, metadata),
  /is not editable/,
  "A released version must never be repurposed.",
);

assert.throws(
  () => selectVersion({
    data: [
      exactVersion,
      version("other", "1.0", "PREPARE_FOR_SUBMISSION"),
    ],
  }, metadata),
  /Expected at most one IOS App Store version/,
  "An exact match must not bypass the multiple-version safety gate.",
);

assert.throws(
  () => selectVersion({
    data: [
      version("released", "1.0", "READY_FOR_SALE"),
      version("draft", "1.1", "PREPARE_FOR_SUBMISSION"),
    ],
  }, metadata),
  /Expected at most one IOS App Store version/,
  "Mixed released and draft versions must fail closed.",
);

assert.throws(
  () => selectVersion({}, metadata),
  /does not contain a data array/,
  "Malformed API responses must fail explicitly.",
);

assert.throws(
  () => selectVersion({
    data: [{
      type: "appStoreVersions",
      attributes: {
        platform: "IOS",
        versionString: "1.0",
        appVersionState: "PREPARE_FOR_SUBMISSION",
      },
    }],
  }, metadata),
  /contains an invalid resource/,
  "A version without an ID must fail before any metadata write.",
);

assert.throws(
  () => selectVersion({
    data: [{
      ...initialVersion,
      attributes: {
        ...initialVersion.attributes,
        platform: "MAC_OS",
      },
    }],
  }, metadata),
  /platform is MAC_OS; expected IOS/,
  "A version for another platform must not be selected.",
);

assert.throws(
  () => selectVersion({
    data: [{
      ...initialVersion,
      attributes: {
        ...initialVersion.attributes,
        versionString: "",
      },
    }],
  }, metadata),
  /has no valid version string/,
  "A malformed version string must fail before any metadata write.",
);

for (const invalidVersionString of [
  "not-a-version",
  "1..0",
  "1.2.3.4",
]) {
  assert.throws(
    () => selectVersion({
      data: [{
        ...initialVersion,
        attributes: {
          ...initialVersion.attributes,
          versionString: invalidVersionString,
        },
      }],
    }, metadata),
    /has no valid version string/,
    `${invalidVersionString} must fail version preflight.`,
  );
}

console.log("App Store metadata version-selection tests passed.");

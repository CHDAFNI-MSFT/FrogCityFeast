import assert from "node:assert/strict";
import { mkdtemp, mkdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";

import {
  loadScreenshotPackage,
  readUploadPart,
  reviewAttributes,
  screenshotVerificationMismatches,
  validateUploadOperations,
} from "../scripts/prepare-app-store-submission.mjs";
import { apiRequest } from "../scripts/sync-app-store-metadata.mjs";

assert.deepEqual(
  validateUploadOperations([
    {
      method: "PUT",
      url: "https://uploads.example.apple.com/part-2",
      offset: 3,
      length: 2,
      requestHeaders: [],
    },
    {
      method: "PUT",
      url: "https://uploads.example.apple.com/part-1",
      offset: 0,
      length: 3,
      requestHeaders: [{ name: "Content-Type", value: "image/png" }],
    },
  ], 5).map((operation) => operation.offset),
  [0, 3],
);
assert.throws(
  () => validateUploadOperations([{
    method: "PUT",
    url: "http://uploads.example.apple.com/insecure",
    offset: 0,
    length: 5,
    requestHeaders: [],
  }], 5),
  /invalid screenshot upload operation/,
);

const sourceBytes = Buffer.from("partial-read-test");
const fakeFile = {
  async read(buffer, bufferOffset, length, position) {
    const bytesRead = Math.min(2, length, sourceBytes.length - position);
    if (bytesRead <= 0) {
      return { bytesRead: 0 };
    }
    sourceBytes.copy(
      buffer,
      bufferOffset,
      position,
      position + bytesRead,
    );
    return { bytesRead };
  },
};
assert.deepEqual(
  await readUploadPart(fakeFile, {
    offset: 3,
    length: 8,
  }),
  sourceBytes.subarray(3, 11),
);

const screenshotImage = {
  filename: "01-city-overview.png",
  size: 1234,
  md5: "0123456789abcdef0123456789abcdef",
};
assert.deepEqual(
  screenshotVerificationMismatches(
    {
      attributes: {
        fileName: screenshotImage.filename,
        fileSize: String(screenshotImage.size),
        sourceFileChecksum: null,
      },
    },
    screenshotImage,
    { allowMissingChecksum: true },
  ),
  [],
);
assert.deepEqual(
  screenshotVerificationMismatches(
    {
      attributes: {
        fileName: screenshotImage.filename,
        fileSize: screenshotImage.size,
        sourceFileChecksum: null,
      },
    },
    screenshotImage,
  ),
  ["source checksum"],
);
assert.deepEqual(
  screenshotVerificationMismatches(
    {
      attributes: {
        fileName: screenshotImage.filename,
        fileSize: screenshotImage.size,
        sourceFileChecksum: "ffffffffffffffffffffffffffffffff",
      },
    },
    screenshotImage,
  ),
  ["source checksum"],
);
await assert.rejects(
  readUploadPart(fakeFile, {
    offset: sourceBytes.length - 1,
    length: 2,
  }),
  /ended before its declared length/,
);

const originalFetch = globalThis.fetch;
try {
  globalThis.fetch = (_url, options) => new Promise((resolve, reject) => {
    options.signal.addEventListener("abort", () => {
      reject(new Error("aborted"));
    });
  });
  await assert.rejects(
    apiRequest("test-token", "GET", "/timeout-test", undefined, {
      timeoutMs: 5,
    }),
    /timed out/,
  );
} finally {
  globalThis.fetch = originalFetch;
}

try {
  globalThis.fetch = (_url, options) => Promise.resolve({
    text: () => new Promise((resolve, reject) => {
      options.signal.addEventListener("abort", () => {
        reject(new Error("aborted"));
      });
    }),
  });
  await assert.rejects(
    apiRequest("test-token", "GET", "/body-timeout-test", undefined, {
      timeoutMs: 5,
    }),
    /timed out/,
  );
} finally {
  globalThis.fetch = originalFetch;
}
assert.throws(
  () => validateUploadOperations([{
    method: "PUT",
    url: "https://uploads.example.apple.com/gap",
    offset: 1,
    length: 4,
    requestHeaders: [],
  }], 5),
  /invalid screenshot upload operation/,
);

const review = reviewAttributes({
  APP_REVIEW_CONTACT_FIRST_NAME: "First",
  APP_REVIEW_CONTACT_LAST_NAME: "Last",
  APP_REVIEW_CONTACT_EMAIL: "review@example.com",
  APP_REVIEW_CONTACT_PHONE: "+15555550100",
}, {
  schema_version: 1,
  version: "0.1.0",
  build: "33770597608.1",
  demo_account_required: false,
  notes_template: "Version {VERSION}, build {BUILD}.",
});
assert.equal(review.notes, "Version 0.1.0, build 33770597608.1.");
assert.equal(review.demoAccountRequired, false);
assert.throws(
  () => reviewAttributes({
    APP_REVIEW_CONTACT_FIRST_NAME: "First",
    APP_REVIEW_CONTACT_LAST_NAME: "Last",
    APP_REVIEW_CONTACT_EMAIL: "not-an-email",
    APP_REVIEW_CONTACT_PHONE: "+15555550100",
  }, {
    schema_version: 1,
    version: "0.1.0",
    build: "33770597608.1",
    demo_account_required: false,
    notes_template: "Version {VERSION}, build {BUILD}.",
  }),
  /email is invalid/i,
);

const temporaryRoot = await mkdtemp(
  path.join(tmpdir(), "frogcityfeast-submission-test-"),
);
try {
  const imageDirectory = path.join(temporaryRoot, "ipad-13-inch");
  await mkdir(imageDirectory);
  const authored = {
    screenshots: Array.from({ length: 7 }, (_, index) => ({
      id: `shot-${index + 1}`,
      filename: `${index + 1}.png`,
    })),
  };
  const files = [];
  for (const entry of authored.screenshots) {
    const bytes = Buffer.from(`image-${entry.id}`);
    await writeFile(path.join(imageDirectory, entry.filename), bytes);
    const { createHash } = await import("node:crypto");
    files.push({
      id: entry.id,
      filename: entry.filename,
      width: 2752,
      height: 2064,
      opaque: true,
      sha256: createHash("sha256").update(bytes).digest("hex"),
    });
  }
  const packagePath = path.join(temporaryRoot, "release-package.json");
  await writeFile(packagePath, JSON.stringify({
    schemaVersion: 1,
    sourceCommit: "cab65511405f5c6b17865d2283d4a636a59da8be",
    cleanTrackedWorktree: true,
    target: {
      width: 2752,
      height: 2064,
      transparent: false,
    },
    files,
  }));
  const images = await loadScreenshotPackage(
    packagePath,
    imageDirectory,
    authored,
  );
  assert.equal(images.length, 7);
  assert.equal(images[0].filename, "1.png");

  files[0].sha256 = "0".repeat(64);
  await writeFile(packagePath, JSON.stringify({
    schemaVersion: 1,
    sourceCommit: "cab65511405f5c6b17865d2283d4a636a59da8be",
    cleanTrackedWorktree: true,
    target: {
      width: 2752,
      height: 2064,
      transparent: false,
    },
    files,
  }));
  await assert.rejects(
    loadScreenshotPackage(packagePath, imageDirectory, authored),
    /failed its SHA-256 check/,
  );
} finally {
  await rm(temporaryRoot, { recursive: true, force: true });
}

console.log("App Store submission preparation tests passed.");

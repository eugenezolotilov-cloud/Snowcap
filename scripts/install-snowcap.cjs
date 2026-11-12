#!/usr/bin/env node
"use strict";

const { execFileSync } = require("node:child_process");
const { createHash } = require("node:crypto");
const { createReadStream, createWriteStream, lstatSync, mkdirSync, mkdtempSync, renameSync, rmSync } = require("node:fs");
const { homedir, tmpdir } = require("node:os");
const { join, resolve } = require("node:path");
const { Readable } = require("node:stream");
const { pipeline } = require("node:stream/promises");
const { parseArgs } = require("node:util");

const diskImage = "https://raw.githubusercontent.com/eugenezolotilov-cloud/Snowcap/fe424970d80dec0b9381810c4bdba1794d2a6c54/downloads/Snowcap.dmg";
const expectedSHA256 = "b5aeae7e89494f725806de74166d608803f7b1130e2640e7d66b392b4752cdf4";

function exists(path) {
  try {
    lstatSync(path);
    return true;
  } catch (error) {
    if (error.code === "ENOENT") return false;
    throw error;
  }
}

async function main() {
  const { values } = parseArgs({
    options: { help: { type: "boolean", short: "h" }, directory: { type: "string" } }
  });
  if (values.help) {
    console.log("Usage: snowcap-install [--directory PATH]\nInstalls Snowcap.app into ~/Applications by default.");
    return;
  }
  if (process.platform !== "darwin") throw new Error("Snowcap requires macOS.");
  const macOS = execFileSync("/usr/bin/sw_vers", ["-productVersion"], { encoding: "utf8" });
  if (Number.parseInt(macOS, 10) < 14) throw new Error("Snowcap requires macOS 14 or later.");

  const directory = resolve(values.directory ?? join(homedir(), "Applications"));
  const destination = join(directory, "Snowcap.app");
  const checkDestination = () => {
    if (exists(destination)) throw new Error(`Snowcap.app already exists at ${destination}. Move it before installing again.`);
  };
  checkDestination();

  const scratch = mkdtempSync(join(tmpdir(), "snowcap-install-"));
  const image = join(scratch, "Snowcap.dmg");
  const mount = join(scratch, "mount");
  let attached = false;
  let staging;
  try {
    const response = await fetch(diskImage, { signal: AbortSignal.timeout(90_000) });
    if (!response.ok || !response.body) throw new Error(`Download failed (HTTP ${response.status}).`);
    await pipeline(Readable.fromWeb(response.body), createWriteStream(image, { flags: "wx" }));

    const hash = createHash("sha256");
    for await (const chunk of createReadStream(image)) hash.update(chunk);
    if (hash.digest("hex") !== expectedSHA256) throw new Error("The downloaded DMG failed SHA-256 verification.");

    mkdirSync(mount);
    execFileSync("/usr/bin/hdiutil", ["attach", image, "-readonly", "-nobrowse", "-mountpoint", mount]);
    attached = true;

    mkdirSync(directory, { recursive: true });
    staging = mkdtempSync(join(directory, ".snowcap-install-"));
    const stagedApp = join(staging, "Snowcap.app");
    execFileSync("/usr/bin/ditto", [join(mount, "Snowcap.app"), stagedApp]);
    execFileSync("/usr/bin/codesign", ["--verify", "--deep", "--strict", stagedApp]);
    checkDestination();
    renameSync(stagedApp, destination);
    console.log(`Installed ${destination}`);
  } finally {
    if (staging) rmSync(staging, { recursive: true, force: true });
    if (attached) {
      try {
        execFileSync("/usr/bin/hdiutil", ["detach", mount]);
        attached = false;
      } catch {
        console.warn(`Could not detach the Snowcap disk image at ${mount}.`);
      }
    }
    if (!attached) rmSync(scratch, { recursive: true, force: true });
  }
}

main().catch((error) => {
  console.error(`Snowcap installation failed: ${error.message}`);
  process.exitCode = 1;
});

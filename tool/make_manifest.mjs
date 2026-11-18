#!/usr/bin/env node
// Builds the update manifest published alongside a GitHub release.
//
//   node tool/make_manifest.mjs \
//     --version 1.2.0 --build 12 --tag v1.2.0 --repo owner/rogue-client \
//     --windows dist/Rogue-1.2.0-win-x64.zip --android dist/Rogue-1.2.0.apk \
//     --notes dist/notes.md --out dist/manifest.json
//
// The app reads it from
//   https://github.com/<owner>/<repo>/releases/latest/download/manifest.json
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';

function arg(name, fallback = '') {
  const index = process.argv.indexOf(`--${name}`);
  if (index === -1 || index + 1 >= process.argv.length) return fallback;
  return process.argv[index + 1];
}

const version = arg('version');
const build = Number(arg('build', '0')) || 0;
const tag = arg('tag');
const repo = arg('repo');
const out = arg('out', 'manifest.json');

if (!version || !tag || !repo) {
  console.error('usage: make_manifest.mjs --version X --tag vX --repo owner/name [--build N] [--windows FILE] [--android FILE] [--notes FILE] [--min-supported X] [--out FILE]');
  process.exit(2);
}

function describe(file, assetName) {
  if (!file) return undefined;
  const bytes = readFileSync(file);
  return {
    url: `https://github.com/${repo}/releases/download/${tag}/${assetName}`,
    sha256: createHash('sha256').update(bytes).digest('hex'),
    size: bytes.length,
  };
}

const windowsAsset = `Rogue-${version}-win-x64.zip`;
const androidAsset = `Rogue-${version}.apk`;

let notes = '';
const notesFile = arg('notes');
if (notesFile) {
  try {
    notes = readFileSync(notesFile, 'utf8').trim();
  } catch {
    notes = '';
  }
}
if (!notes) notes = `Rogue ${version}`;

const manifest = {
  version,
  build,
  notes,
  page: `https://github.com/${repo}/releases/tag/${tag}`,
  generated: new Date().toISOString(),
};

const minSupported = arg('min-supported');
if (minSupported) manifest.minSupported = minSupported;

const windows = describe(arg('windows'), windowsAsset);
const android = describe(arg('android'), androidAsset);
if (windows) manifest.windows = windows;
if (android) manifest.android = android;

if (!windows && !android) {
  console.error('Refusing to write a manifest with no artifacts.');
  process.exit(1);
}

writeFileSync(out, `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`wrote ${out}`);
console.log(JSON.stringify(manifest, null, 2));

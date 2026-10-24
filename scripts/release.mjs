#!/usr/bin/env node
/// Release driver for the cupthread_feedback Flutter SDK.
///
/// Preflight (clean tree, pub get, analyze, test) -> bump pubspec.yaml ->
/// verify the written version -> commit, tag, push -> create the GitHub
/// Release. Publishing to pub.dev is intentionally not part of this script
/// yet; README documents the git-tag install path instead.
import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync, unlinkSync, writeFileSync } from 'node:fs';
import { createInterface } from 'node:readline/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

function fail(message) {
  console.error(`✗ ${message}`);
  process.exit(1);
}

function run(cmd, args) {
  console.log(`  $ ${cmd} ${args.join(' ')}`);
  const res = spawnSync(cmd, args, { cwd: ROOT, stdio: 'inherit' });
  if (res.status !== 0) fail(`Command failed: ${cmd} ${args.join(' ')}`);
}

function capture(cmd, args) {
  return spawnSync(cmd, args, { cwd: ROOT, encoding: 'utf8' });
}

// Byte-for-byte restore map so a dry run can undo whatever `flutter pub get`
// touched (a stale tracked pubspec.lock is the usual case).
function snapshotFiles(names) {
  const map = new Map();
  for (const name of names) {
    const file = path.join(ROOT, name);
    map.set(file, existsSync(file) ? readFileSync(file) : null);
  }
  return map;
}

function restoreFiles(map) {
  for (const [file, bytes] of map) {
    if (bytes === null) {
      if (existsSync(file)) unlinkSync(file);
    } else {
      writeFileSync(file, bytes);
    }
  }
}

// --- CLI arguments ---
const args = process.argv.slice(2);
let version = null;
const flags = new Set();
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--version') {
    version = args[++i];
  } else if (
    args[i] === '--dry-run' ||
    args[i] === '--yes' ||
    args[i] === '--skip-tests'
  ) {
    flags.add(args[i]);
  } else {
    fail(`Unknown argument: ${args[i]}`);
  }
}

if (!version || !/^\d+\.\d+\.\d+$/.test(version)) {
  console.error(
    'Usage: node scripts/release.mjs --version <X.Y.Z> [--dry-run] [--yes] [--skip-tests]',
  );
  process.exit(1);
}

const tag = `v${version}`;
const dryRun = flags.has('--dry-run');
const skipTests = flags.has('--skip-tests');

console.log(`\n💙 Releasing cupthread_feedback ${tag}${dryRun ? ' (dry run)' : ''}`);

// --- Preflight: refuse a dirty worktree ---
const status = capture('git', ['status', '--porcelain']);
if (status.status !== 0) fail('git status failed; is this a git checkout?');
const statusLines = status.stdout.split('\n').filter((l) => l.trim() !== '');
const trackedChanges = statusLines.filter((l) => !l.startsWith('??'));
const untrackedFiles = statusLines.filter((l) => l.startsWith('??'));
if (trackedChanges.length > 0) {
  fail(
    `Worktree has uncommitted changes to tracked files. Commit or stash them first:\n${trackedChanges.join('\n')}`,
  );
}
if (untrackedFiles.length > 0) {
  console.log(`  ⚠ Proceeding with ${untrackedFiles.length} untracked path(s) present:`);
  for (const line of untrackedFiles) console.log(`      ${line}`);
}

// --- Preflight: the tag must not already exist, locally or on origin ---
const tagExists = capture('git', ['rev-parse', '-q', '--verify', `refs/tags/${tag}`]);
if (tagExists.status === 0) fail(`Tag ${tag} already exists; pick a new version.`);
const remoteTag = spawnSync(
  'git',
  ['ls-remote', '--exit-code', '--tags', 'origin', tag],
  { cwd: ROOT, encoding: 'utf8' },
);
if (remoteTag.status === 0) {
  fail(`Tag ${tag} already exists on origin; pick a new version.`);
} else if (remoteTag.status !== 2) {
  fail(
    `Could not query origin for ${tag} (git ls-remote exit ${remoteTag.status}).` +
      (remoteTag.stderr ? `\n${remoteTag.stderr.trim()}` : ''),
  );
}

// --- Preflight: pub get, analyze, test (dry run restores touched files) ---
const dryRunSnapshots = dryRun ? snapshotFiles(['pubspec.yaml', 'pubspec.lock']) : null;
try {
  run('flutter', ['pub', 'get']);
  run('flutter', ['analyze']);
  if (skipTests) {
    console.log('  ⚠ --skip-tests set: `flutter test` was NOT run for this release.');
  } else {
    run('flutter', ['test']);
  }
} finally {
  if (dryRunSnapshots) restoreFiles(dryRunSnapshots);
}

// --- Read the current version before touching anything ---
const pubspecPath = path.join(ROOT, 'pubspec.yaml');
const pubspec = readFileSync(pubspecPath, 'utf8');
const current = /^version:\s*(\S+)$/m.exec(pubspec)?.[1];
if (!current) fail('pubspec.yaml has no top-level `version:` entry.');
if (current === version) {
  fail(`pubspec.yaml is already at ${version}; pick a new version to release.`);
}

if (dryRun) {
  console.log(
    `\n✓ Dry run passed: ${tag} cleared every preflight check (nothing written, nothing pushed).`,
  );
  process.exit(0);
}

// --- Confirmation (interactive only; CI must pass --yes) ---
if (!flags.has('--yes')) {
  if (process.stdin.isTTY !== true) {
    fail('Refusing to release without confirmation; re-run with --yes for non-interactive releases.');
  }
  const rl = createInterface({ input: process.stdin, output: process.stdout });
  const answer = await rl.question(
    `Proceed with ${tag}? This commits the version bump, pushes, tags, and creates a GitHub Release. [y/N] `,
  );
  rl.close();
  if (answer.trim().toLowerCase() !== 'y') {
    fail('Aborted; pubspec.yaml was left untouched.');
  }
}

// --- Bump the version and verify the written value ---
writeFileSync(pubspecPath, pubspec.replace(/^version:\s*.*$/m, `version: ${version}`));
const written = /^version:\s*(\S+)$/m.exec(readFileSync(pubspecPath, 'utf8'))?.[1];
if (written !== version) {
  fail(`pubspec.yaml version is "${written}" after the bump; expected "${version}". Aborting before commit.`);
}
console.log(`  ✓ pubspec.yaml version: ${current} -> ${version}`);

// --- Commit, tag, push (atomic so a tag rejection cannot strand HEAD) ---
run('git', ['add', 'pubspec.yaml', 'pubspec.lock']);
run('git', ['commit', '-m', `release: flutter SDK ${tag}`]);
run('git', ['tag', '-a', tag, '-m', `Release ${tag}`]);
run('git', ['push', '--atomic', 'origin', 'HEAD', tag]);

// --- GitHub Release ---
console.log(`  $ gh release create ${tag} --verify-tag --generate-notes --title ${tag}`);
const release = spawnSync(
  'gh',
  ['release', 'create', tag, '--verify-tag', '--generate-notes', '--title', tag],
  { cwd: ROOT, stdio: 'inherit' },
);
if (release.status !== 0) {
  console.error('✗ The tag is pushed but the GitHub Release could not be created.');
  console.error(`  Create it manually, then investigate the gh failure:`);
  console.error(`    gh release create ${tag} --verify-tag --generate-notes --title "${tag}"`);
  process.exit(1);
}

console.log(`\n✓ Flutter SDK ${tag} released! Install it with the git dependency (ref: ${tag}).`);
console.log('  ℹ pub.dev publishing is not wired up yet; see README "Manual Installation".');

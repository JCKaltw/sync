# Space Safety Sync Plan

**Created**: 2026-08-20
**Author**: Claude Code (SYNC session)
**Status**: Awaiting Review
**Plan Request**: `prompts/space-safety-sync-plan-request.md`
**Branch**: `space-safety-sync` (set by this plan's filename via `opb` / `gitcb`)

---

## Table of Contents

- [Overview](#overview)
- [Problem Statement](#problem-statement)
- [Key Findings](#key-findings-🤖)
- [Design Summary](#design-summary)
- [ ] [Phase 1: Shared Helper Library sync-lib 🤖](#phase-1-shared-helper-library-sync-lib-🤖)
  - [ ] [Step 1.1: Create sync-lib with error and banner helpers 🤖](#step-11-create-sync-lib-with-error-and-banner-helpers-🤖)
  - [ ] [Step 1.2: Space gate function 🤖](#step-12-space-gate-function-🤖)
  - [ ] [Step 1.3: Artifact verification and manifest functions 🤖](#step-13-artifact-verification-and-manifest-functions-🤖)
  - [ ] [Step 1.4: Retention prune function 🤖](#step-14-retention-prune-function-🤖)
  - [ ] [Step 1.5: Last-run size recording 🤖](#step-15-last-run-size-recording-🤖)
- [ ] [Phase 2: Export Script Hardening 🤖](#phase-2-export-script-hardening-🤖)
  - [ ] [Step 2.1: Harden export-eyedro 🤖](#step-21-harden-export-eyedro-🤖)
  - [ ] [Step 2.2: Harden export-pgdb 🤖](#step-22-harden-export-pgdb-🤖)
  - [ ] [Step 2.3: Harden export-purify 🤖](#step-23-harden-export-purify-🤖)
  - [ ] [Step 2.4: export-all orchestration and manifest 🤖](#step-24-export-all-orchestration-and-manifest-🤖)
- [ ] [Phase 3: Import Script Hardening 🤖](#phase-3-import-script-hardening-🤖)
  - [ ] [Step 3.1: Remote pre-flight check of pg2 artifacts 🤖](#step-31-remote-pre-flight-check-of-pg2-artifacts-🤖)
  - [ ] [Step 3.2: import-pgdb verify-then-swap for pgui data 🤖](#step-32-import-pgdb-verify-then-swap-for-pgui-data-🤖)
  - [ ] [Step 3.3: Per-script work directories for dump extraction 🤖](#step-33-per-script-work-directories-for-dump-extraction-🤖)
  - [ ] [Step 3.4: Harden import-eyedro and import-purify 🤖](#step-34-harden-import-eyedro-and-import-purify-🤖)
  - [ ] [Step 3.5: import-all orchestration and manifest 🤖](#step-35-import-all-orchestration-and-manifest-🤖)
  - [ ] [Step 3.6: Harden the transfer-files scripts 🤖](#step-36-harden-the-transfer-files-scripts-🤖)
- [ ] [Phase 4: Retention and Space Ratchet 🤖](#phase-4-retention-and-space-ratchet-🤖)
  - [ ] [Step 4.1: Remove uncompressed intermediates after tar 🤖](#step-41-remove-uncompressed-intermediates-after-tar-🤖)
  - [ ] [Step 4.2: Wire retention pruning into the all-wrappers 🤖](#step-42-wire-retention-pruning-into-the-all-wrappers-🤖)
  - [ ] [Step 4.3: Standalone prune script 🤖](#step-43-standalone-prune-script-🤖)
- [ ] [Phase 5: Failure-Path Testing 🤖](#phase-5-failure-path-testing-🤖)
  - [ ] [Step 5.1: Test sandbox and command shims 🤖](#step-51-test-sandbox-and-command-shims-🤖)
  - [ ] [Step 5.2: Export failure tests 🤖](#step-52-export-failure-tests-🤖)
  - [ ] [Step 5.3: Import failure tests 🤖](#step-53-import-failure-tests-🤖)
  - [ ] [Step 5.4: Happy-path regression 🤖](#step-54-happy-path-regression-🤖)
- [ ] [Phase 6: Deployment and Live Verification 🤖👤](#phase-6-deployment-and-live-verification-🤖👤)
  - [ ] [Step 6.1: Git add and commit on Mac 🤖](#step-61-git-add-and-commit-on-mac-🤖)
  - [ ] [Step 6.2: Push from Mac and pull on pg2 👤](#step-62-push-from-mac-and-pull-on-pg2-👤)
  - [ ] [Step 6.3: Supervised live export on pg2 👤](#step-63-supervised-live-export-on-pg2-👤)
  - [ ] [Step 6.4: Supervised live import on Mac 👤🤖](#step-64-supervised-live-import-on-mac-👤🤖)
- [Acceptance Criteria Mapping](#acceptance-criteria-mapping)

---

## Overview

This plan makes the sync-all ritual (exports on pg2, imports on the Mac) safe
against disk-space exhaustion and silent failure. The core changes are:

1. A single shared helper library, `sync-lib.sh`, sourced by every script on
   both hosts (both hosts run from clones of this same git repo, so one file
   serves both).
2. A **pre-flight space gate** that stops a run before anything is written.
3. **Fail-loud semantics** (`set -euo pipefail` plus explicit checks) with a
   per-member PASS/FAIL manifest from `export-all.sh` / `import-all.sh`.
4. **Verify-then-swap** on the import side: nothing existing is destroyed
   (neither `pgui/data` nor any Postgres schema) until its replacement has
   arrived and verified.
5. **Bounded retention** for `export_data/` and cleanup of uncompressed dump
   intermediates, so baseline disk usage stops growing.

The user surface is unchanged: Chris still runs `./export-all.sh` on pg2 and
`./import-all.sh` on the Mac with no new required arguments.

[Back to TOC](#table-of-contents)

---

## Problem Statement

On 2026-08-19, `export-all.sh` ran on pg2 with the 50GB root disk nearly full
(`export_data/` held ~9.8GB of accumulated tarballs, and the eyedro export's
~5.1GB uncompressed `public_schema_backup.sql` intermediate pushed it over).
The `tar` of `pgui/data` in `export-pgdb.sh` failed, so **no JSON tarball was
created** — but with no error handling the run continued and looked
successful. On the Mac, `import-pgdb.sh` failed to scp the nonexistent
tarball, ignored the failure, and ran `rm -rf data` anyway, destroying the
Mac's `pgui/data` mirror.

Space was the trigger; absent error handling turned a full disk into silent
data loss. The scripts must warn about space **before** failure, stop loudly
on any error, and never destroy existing data before its replacement is
verified.

[Back to TOC](#table-of-contents)

---

## Key Findings 🤖

Gathered 2026-08-20 while preparing this plan:

- **pg2 and the Mac share this git repo.** pg2's `~/sync` is a clone already
  at the latest commit. Deploying pg2-side script changes is the normal
  push (Chris, Mac) + pull (Chris, pg2) — no scp of scripts needed.
- **The wrappers are symlinks, not copies.** Mac: `ip → import-pgdb.sh`,
  `ipr → import-purify.sh`, `ie → import-eyedro.sh`. pg2: `ep → export-pgdb.sh`,
  `ee → export-eyedro.sh`, `epr → export-purify.sh`. All are gitignored.
  There is no duplication to consolidate — hardening the real scripts
  automatically covers the wrappers. The plan request's premise that `ip`
  duplicates `import-pgdb.sh` is happily out of date.
- **Current sizes** (for the space estimator): eyedro public dump ~5.1GB
  uncompressed → 425MB tgz; weather ~15MB → 2.8MB; pgdb pgui/data ~48MB →
  6MB; pgdb pgdump ~95KB. `export_data/` is 9.8GB / 82 files on pg2 (13GB
  free on a 50GB disk) and 16GB / 423 files on the Mac.
- **The failed run's debris is still on pg2**: `public_schema_backup.sql`
  (5.1GB) and `weather_schema_backup.sql` sit uncompressed in `export_data/`,
  and `pg2-pgdb-20260819.tgz` and the purify tarball for that date are
  missing — confirming the incident narrative.
- **Latent wrong-database hazard**: `export-eyedro.sh`, `export-pgdb.sh`, and
  `export-purify.sh` all write a file literally named
  `public_schema_backup.sql` in the same shared directory, and the import
  scripts extract to and read from that same shared name. If an scp or tar
  step fails but a *previous* script's `public_schema_backup.sql` is lying
  around, today's scripts would `DROP SCHEMA public CASCADE` and restore the
  **wrong database's dump** (e.g. pgdb's dump into purify). Phase 3 removes
  this hazard with per-script work directories.

[Back to TOC](#table-of-contents)

---

## Design Summary

- **`sync-lib.sh`** lives in the repo root next to the scripts and is sourced
  by every export/import script. It provides: `die` (red banner + exit),
  `run_step` (echo + execute + abort on failure), `require_space`,
  `verify_tgz`, `manifest_add` / `manifest_report`, `prune_exports`, and
  `record_sizes`.
- **Space estimate**: after every successful run, `record_sizes` writes each
  artifact's tarball bytes and uncompressed-intermediate bytes to
  `export_data/.sync-last-sizes`. The next run's requirement is last-run
  bytes × 1.5 margin; if no state file exists, conservative defaults apply
  (eyedro 9 GiB, pgdb 1 GiB, purify 1 GiB). The gate also enforces an
  absolute floor: the run must leave ≥ 2 GiB free afterward.
- **The warning** (printed and exiting nonzero before anything is written):

  ```
  ******************************************************************
  * SPACE GATE FAILED - nothing has been written
  * Required : 8.3 GiB  (last run 5.5 GiB x 1.5 margin)
  * Available: 4.1 GiB  on /home/chris/sync/export_data
  * Shortfall: 4.2 GiB
  * To free space:
  *   ./prune-export-data.sh          # apply retention now
  *   du -sh ~/sync/export_data       # inspect
  ******************************************************************
  ```

- **Retention rule**: keep the newest **5** dated tarballs per artifact
  family on **pg2**, newest **8** per family on the **Mac**. Families:
  `pg2-eyedro-pgdump-*`, `weather-db-*`, `pg2-pgdb-*` (JSON),
  `pg2-pgdb-pgdump-*`, `pg2-purifi-pgdump-*`. Pruning always reports every
  file it deletes and the bytes freed, and never deletes the newest file of
  a family regardless of age. Host is detected via `uname` (Darwin = Mac
  limits, Linux = pg2 limits).
- **Failed import leaves on disk**: the existing `data/` (or its `data.prev`
  predecessor) untouched, any partial downloads in a clearly named
  `work-YYYYMMDD-<member>/` directory for inspection, and a FAILED manifest
  line naming the member and step. No `DROP SCHEMA` will have run for any
  member whose dump did not verify.

[Back to TOC](#table-of-contents)

---

## Phase 1: Shared Helper Library sync-lib 🤖

### Step 1.1: Create sync-lib with error and banner helpers 🤖

- [ ] Create `sync-lib.sh` in the repo root. Every script will begin with
  `set -euo pipefail` and `source "$(dirname "$0")/sync-lib.sh"`.
- [ ] Implement `die "msg"` (unmissable multi-line banner to stderr, exit 1)
  and `run_step "label" cmd...` (echo the label, run the command, `die` with
  the label on failure).
- [ ] Honor `SYNC_ROOT` (default: the script's own directory) and
  `EXPORT_DATA` (default `$SYNC_ROOT/export_data`) so the test sandbox in
  Phase 5 can redirect everything without touching live paths.

[Back to TOC](#table-of-contents)

### Step 1.2: Space gate function 🤖

- [ ] Implement `require_space <member>`: reads `.sync-last-sizes` for the
  member's last total bytes (tarballs + intermediates), multiplies by 1.5,
  falls back to per-member defaults when no state exists, compares against
  `df -Pk` available space on the `export_data` filesystem, and enforces the
  2 GiB post-run floor.
- [ ] On failure, print the space-gate banner shown in the Design Summary and
  exit nonzero **before any artifact is written**.
- [ ] Support `SYNC_FAKE_AVAIL_KB` env override so tests can force the gate
  to fail without filling a disk.

[Back to TOC](#table-of-contents)

### Step 1.3: Artifact verification and manifest functions 🤖

- [ ] Implement `verify_tgz <path>`: file exists, size above a per-family
  sanity floor, `tar -tzf` succeeds, entry count > 0. `die` on any failure.
- [ ] Implement `manifest_add <member> <artifact> <status> <size>` writing to
  a per-run manifest file, and `manifest_report` printing the final table
  with OK / MISSING / FAILED per expected artifact so a missing artifact can
  never hide again.

[Back to TOC](#table-of-contents)

### Step 1.4: Retention prune function 🤖

- [ ] Implement `prune_exports`: for each artifact family, keep the newest N
  (5 on pg2, 8 on Mac, overridable via `SYNC_KEEP`), delete the rest,
  print every deletion and total bytes freed. Never delete a family's newest
  file. Also delete stray uncompressed `*_schema_backup.sql` files older
  than the current run.

[Back to TOC](#table-of-contents)

### Step 1.5: Last-run size recording 🤖

- [ ] Implement `record_sizes <member>` capturing actual artifact and
  intermediate sizes at the end of each successful member run into
  `export_data/.sync-last-sizes` (one line per member, replaced atomically).

[Back to TOC](#table-of-contents)

---

## Phase 2: Export Script Hardening 🤖

All export scripts run on pg2 but are edited only on the Mac in this repo
(delivered by git push/pull in Phase 6).

### Step 2.1: Harden export-eyedro 🤖

- [ ] `set -euo pipefail`, source sync-lib, `require_space eyedro` first.
- [ ] Run pg_dump into a per-run work file, `run_step` each tar, `verify_tgz`
  both tarballs, delete the uncompressed `.sql` intermediates on success,
  `record_sizes eyedro`, `manifest_add` results.

[Back to TOC](#table-of-contents)

### Step 2.2: Harden export-pgdb 🤖

- [ ] Same treatment. The pgui/data tar (the step that failed silently on
  2026-08-19) becomes `run_step` + `verify_tgz`, so a failure aborts with a
  banner and a FAILED manifest line instead of vanishing.

[Back to TOC](#table-of-contents)

### Step 2.3: Harden export-purify 🤖

- [ ] Same treatment as Step 2.1 for the single purify pgdump artifact.

[Back to TOC](#table-of-contents)

### Step 2.4: export-all orchestration and manifest 🤖

- [ ] `export-all.sh` runs `prune_exports`, then a combined `require_space`
  for all three members, then each member in order, stopping at the first
  failure; it always ends with `manifest_report` listing every expected
  artifact for the date with status and size, plus a loud overall
  SUCCEEDED / FAILED-AT-<member> banner.
- [ ] Invocation surface unchanged: `./export-all.sh`, no arguments.

[Back to TOC](#table-of-contents)

---

## Phase 3: Import Script Hardening 🤖

### Step 3.1: Remote pre-flight check of pg2 artifacts 🤖

- [ ] Before any download or destructive step, `import-all.sh` (and each
  member script when run standalone) checks via `ssh pg2 stat` that every
  expected tarball for today's date exists on pg2 and is nonzero. A missing
  artifact aborts with: which file is missing, and the hint "did
  export-all.sh run and succeed on pg2 today?". This alone would have
  stopped the 2026-08-19 loss before anything was touched.

[Back to TOC](#table-of-contents)

### Step 3.2: import-pgdb verify-then-swap for pgui data 🤖

- [ ] scp the JSON tarball, `verify_tgz` it, extract into `data.incoming/`
  (never over live `data/`), and sanity-check that `dml-ast.json` and
  `ddl-ast.json` exist and are nonzero in the extraction.
- [ ] Only then swap: `mv data data.prev` (removing any older `data.prev`
  first), `mv data.incoming data`. The prior generation survives as
  `data.prev` until the next successful import, so a bad run is recoverable
  with a single `mv` back.
- [ ] On any failure before the swap, live `data/` is untouched and the
  partial material remains in `data.incoming/` for inspection.

[Back to TOC](#table-of-contents)

### Step 3.3: Per-script work directories for dump extraction 🤖

- [ ] Each import member extracts its pgdump tarball into its own
  `work-YYYYMMDD-<member>/` directory and feeds psql from there, eliminating
  the shared `public_schema_backup.sql` filename collision (the
  wrong-database hazard in Key Findings). Work directories are removed on
  success and kept on failure.
- [ ] `DROP SCHEMA ... CASCADE` runs **only after** the member's own tarball
  verified and its dump file extracted nonzero in this run's work directory.

[Back to TOC](#table-of-contents)

### Step 3.4: Harden import-eyedro and import-purify 🤖

- [ ] Apply Steps 3.1 and 3.3 semantics to both: pre-flight remote check,
  verified download, per-member work dir, verified dump before any
  `DROP SCHEMA`, loud abort on psql failure, manifest lines.

[Back to TOC](#table-of-contents)

### Step 3.5: import-all orchestration and manifest 🤖

- [ ] `import-all.sh` runs the full remote pre-flight for all members first
  (all-or-nothing before anything is touched), runs `prune_exports` on the
  Mac's `export_data/`, then each member, stopping at first failure, ending
  with `manifest_report` and a loud overall banner. Invocation unchanged:
  `./import-all.sh`, no arguments.

[Back to TOC](#table-of-contents)

### Step 3.6: Harden the transfer-files scripts 🤖

- [ ] `import-pgdb-transfer-files.sh` and `import-eyedro-transfer-files.sh`
  get the same pre-flight, `run_step` scp, and `verify_tgz` treatment before
  uploading to pg4 (they are non-destructive, so no swap logic is needed).

[Back to TOC](#table-of-contents)

---

## Phase 4: Retention and Space Ratchet 🤖

### Step 4.1: Remove uncompressed intermediates after tar 🤖

- [ ] Every export member deletes its `*_schema_backup.sql` work files after
  a verified tar; every import member removes its work directory after
  success (already specified in 2.x / 3.3 — this step verifies no path
  leaves intermediates behind on success, including the 5.1GB leftover
  pattern from 2026-08-19).

[Back to TOC](#table-of-contents)

### Step 4.2: Wire retention pruning into the all-wrappers 🤖

- [ ] `export-all.sh` (pg2, keep 5 per family) and `import-all.sh` (Mac,
  keep 8 per family) call `prune_exports` at start, before the space gate,
  so retention automatically frees space ahead of the estimate check.

[Back to TOC](#table-of-contents)

### Step 4.3: Standalone prune script 🤖

- [ ] Add `prune-export-data.sh` (repo root, works on either host) so the
  space-gate warning's remediation hint is a single command. Supports
  `--dry-run` to list what would be deleted.

[Back to TOC](#table-of-contents)

---

## Phase 5: Failure-Path Testing 🤖

No test touches live databases, live `pgui/data`, or the real
`export_data/`. Everything runs in a sandbox via env overrides.

### Step 5.1: Test sandbox and command shims 🤖

- [ ] Create `tests/` with a runner (`tests/run-tests.sh`) that builds a
  scratch `SYNC_ROOT` (under the system temp dir), a fake `export_data/`
  with dated dummy tarballs, and a `shims/` directory prepended to PATH
  containing fake `pg_dump`, `psql`, `scp`, `ssh`, and `tar` wrappers whose
  behavior (succeed, fail, produce short output) is driven by env vars.

[Back to TOC](#table-of-contents)

### Step 5.2: Export failure tests 🤖

- [ ] Space gate blocks: with `SYNC_FAKE_AVAIL_KB` set low, `export-all.sh`
  exits nonzero before writing anything, printing the space banner.
- [ ] Tar failure: shim `tar` fails for the pgdb JSON step; the run aborts,
  the manifest shows `pg2-pgdb-<date>.tgz FAILED`, and the failing member is
  named in the final banner (the exact 2026-08-19 scenario, now loud).

[Back to TOC](#table-of-contents)

### Step 5.3: Import failure tests 🤖

- [ ] Missing remote tarball: shim `ssh`/`stat` reports the JSON tarball
  absent; `import-all.sh` aborts in pre-flight; assert the sandbox `data/`
  directory is untouched (the incident's data-loss path, now impossible).
- [ ] Corrupt tarball: `verify_tgz` rejects a truncated tgz; assert `data/`
  and `data.prev` untouched and `data.incoming/` retained.
- [ ] Wrong-dump isolation: leave a stale `public_schema_backup.sql` in the
  shared directory, fail one member's scp, and assert no `psql` shim call
  ever received the stale file (proves the per-member work-dir fix).

[Back to TOC](#table-of-contents)

### Step 5.4: Happy-path regression 🤖

- [ ] Full sandbox export + import with all shims succeeding: assert every
  artifact verifies, manifests show all OK, intermediates and work dirs are
  cleaned, retention deletes the oldest dummies and keeps the newest N, and
  `.sync-last-sizes` is written.

[Back to TOC](#table-of-contents)

---

## Phase 6: Deployment and Live Verification 🤖👤

### Step 6.1: Git add and commit on Mac 🤖

- [ ] Itemized `git add` (each file by name, no wildcards, no `-A`) of the
  changed scripts, `sync-lib.sh`, `prune-export-data.sh`, `tests/`, and this
  plan; commit to the `space-safety-sync` branch (then merge to main per the
  gitm workflow when approved).

[Back to TOC](#table-of-contents)

### Step 6.2: Push from Mac and pull on pg2 👤

- [ ] Chris pushes from the Mac and pulls in `~/sync` on pg2, then replies
  "pull done". No scripts are ever edited directly on pg2.

[Back to TOC](#table-of-contents)

### Step 6.3: Supervised live export on pg2 👤

- [ ] Chris runs `./export-all.sh` on pg2. Expected: retention prune report
  (this will clear the 2026-08-19 leftover 5.1GB `public_schema_backup.sql`
  and old tarballs), space gate PASS, all five artifacts created and
  verified, closing manifest all OK.

[Back to TOC](#table-of-contents)

### Step 6.4: Supervised live import on Mac 👤🤖

- [ ] Chris runs `./import-all.sh` on the Mac. Expected: remote pre-flight
  PASS, verify-then-swap restores `pgui/data` (finally replacing what the
  incident destroyed), all schemas imported, manifest all OK, `data.prev`
  present. Claude verifies `dml-ast.json` / `ddl-ast.json` afterward and
  marks this plan complete.

[Back to TOC](#table-of-contents)

---

## Acceptance Criteria Mapping

- **Both hosts, every script enumerated, wrapper handling** — Scope covers
  `sync-lib.sh` (new), `export-all/eyedro/pgdb/purify.sh`,
  `import-all/eyedro/pgdb/purify.sh`, both `*-transfer-files.sh`,
  `prune-export-data.sh` (new), `tests/` (new). `ip`/`ipr`/`ie` and
  `ep`/`ee`/`epr` are symlinks (Key Findings), so they inherit every fix;
  no consolidation needed.
- **Space estimate + warning** — Step 1.2 and the Design Summary banner.
- **Verification and verify-then-swap, failed-import residue** — Steps 1.3,
  3.2, 3.3; residue defined in the Design Summary.
- **Retention rule per host** — Design Summary and Steps 1.4, 4.2, 4.3.
- **Failure-path tests without live data** — Phase 5 sandbox and shims.
- **Invocation surface unchanged** — Steps 2.4 and 3.5.
- **Plan conventions** — TOC with checkboxes, numbered phases/steps,
  Typora-compatible hotlinks, Back to TOC links throughout.

[Back to TOC](#table-of-contents)

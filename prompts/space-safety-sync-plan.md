# Space Safety Sync Plan

**Created**: 2026-08-20
**Revised**: 2026-09-05 (per `prompts/space-safety-sync-update-plan-request.md`)
**Revised again**: 2026-09-05 (rev 2 — folds in the approved eyedro FDW fix per `prompts/eyedro-sync-missing-assets-research.md`)
**Author**: Claude Code (SYNC session)
**Status**: Awaiting Review (revision)
**Plan Request**: `prompts/space-safety-sync-plan-request.md`
**Revision Request**: `prompts/space-safety-sync-update-plan-request.md`
**Branch**: `space-safety-sync` (set by this plan's filename via `opb` / `gitcb`)

---

## Table of Contents

- [Overview](#overview)
- [Problem Statement](#problem-statement)
- [Key Findings](#key-findings-🤖)
- [Interim Work Reconciliation](#interim-work-reconciliation-🤖)
- [Decision Points for Chris](#decision-points-for-chris-👤)
- [Design Summary](#design-summary)
- [x] [Phase 1: Shared Helper Library sync-lib 🤖](#phase-1-shared-helper-library-sync-lib-🤖)
  - [x] [Step 1.1: Create sync-lib with error and banner helpers 🤖](#step-11-create-sync-lib-with-error-and-banner-helpers-🤖)
  - [x] [Step 1.2: Space gate function 🤖](#step-12-space-gate-function-🤖)
  - [x] [Step 1.3: Artifact verification and manifest functions 🤖](#step-13-artifact-verification-and-manifest-functions-🤖)
  - [x] [Step 1.4: Retention prune function 🤖](#step-14-retention-prune-function-🤖)
  - [x] [Step 1.5: Last-run size recording 🤖](#step-15-last-run-size-recording-🤖)
- [x] [Phase 2: Export Script Hardening 🤖](#phase-2-export-script-hardening-🤖)
  - [x] [Step 2.1: Harden export-eyedro 🤖](#step-21-harden-export-eyedro-🤖)
  - [x] [Step 2.2: Harden export-pgdb 🤖](#step-22-harden-export-pgdb-🤖)
  - [x] [Step 2.3: Harden export-purify 🤖](#step-23-harden-export-purify-🤖)
  - [x] [Step 2.4: export-all orchestration and manifest 🤖](#step-24-export-all-orchestration-and-manifest-🤖)
- [x] [Phase 3: Import Script Hardening 🤖](#phase-3-import-script-hardening-🤖)
  - [x] [Step 3.1: Remote pre-flight check of pg2 artifacts 🤖](#step-31-remote-pre-flight-check-of-pg2-artifacts-🤖)
  - [x] [Step 3.2: import-pgdb verify-then-swap for pgui data 🤖](#step-32-import-pgdb-verify-then-swap-for-pgui-data-🤖)
  - [x] [Step 3.3: Per-script work directories for dump extraction 🤖](#step-33-per-script-work-directories-for-dump-extraction-🤖)
  - [x] [Step 3.4: Harden import-eyedro and import-purify 🤖](#step-34-harden-import-eyedro-and-import-purify-🤖)
  - [x] [Step 3.5: import-all orchestration and manifest 🤖](#step-35-import-all-orchestration-and-manifest-🤖)
  - [x] [Step 3.6: Harden the transfer-files scripts 🤖](#step-36-harden-the-transfer-files-scripts-🤖)
  - [x] [Step 3.7: Eyedro FDW bootstrap and replay error accounting 🤖👤](#step-37-eyedro-fdw-bootstrap-and-replay-error-accounting-🤖👤)
- [x] [Phase 4: Retention and Space Ratchet 🤖](#phase-4-retention-and-space-ratchet-🤖)
  - [x] [Step 4.1: Verify-then-delete for uncompressed intermediates 🤖](#step-41-verify-then-delete-for-uncompressed-intermediates-🤖)
  - [x] [Step 4.2: Replace inline trim with prune_exports in the all-wrappers 🤖](#step-42-replace-inline-trim-with-prune_exports-in-the-all-wrappers-🤖)
  - [x] [Step 4.3: Standalone prune script 🤖](#step-43-standalone-prune-script-🤖)
  - [x] [Step 4.4: sync-trim handoff patch for the bin repo 👤](#step-44-sync-trim-handoff-patch-for-the-bin-repo-👤)
- [x] [Phase 5: Failure-Path Testing 🤖](#phase-5-failure-path-testing-🤖)
  - [x] [Step 5.1: Test sandbox and command shims 🤖](#step-51-test-sandbox-and-command-shims-🤖)
  - [x] [Step 5.2: Export failure tests 🤖](#step-52-export-failure-tests-🤖)
  - [x] [Step 5.3: Import failure tests 🤖](#step-53-import-failure-tests-🤖)
  - [x] [Step 5.4: Happy-path regression 🤖](#step-54-happy-path-regression-🤖)
- [ ] [Phase 6: Deployment and Live Verification 🤖👤](#phase-6-deployment-and-live-verification-🤖👤)
  - [x] [Step 6.1: Git add and commit on Mac including prompts docs 🤖](#step-61-git-add-and-commit-on-mac-including-prompts-docs-🤖)
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

**2026-09-05 revision**: interim commit `e260d35` (raw-dump deletion,
keep-newest-2 trim) has since landed on `main` and is live on both hosts.
This revision reconciles the plan with that commit — see
[Interim Work Reconciliation](#interim-work-reconciliation-🤖) — settles
retention counts, adds Chris's new requirement on how the space-freeing step
is surfaced (see [Decision Points for Chris](#decision-points-for-chris-👤)),
disposes of the bin repo's `sync-trim`, refreshes size figures, and adds the
`prompts/` documents to the commit scope. **Rev 2 (same day)** folds in the
Chris-approved eyedro FDW fix from
`prompts/eyedro-sync-missing-assets-research.md` as Step 3.7: a Mac-only
FDW bootstrap before the dump replay, replay error accounting in place of
blanket ON_ERROR_STOP, and post-import FDW verification.

The user surface is unchanged: Chris still runs `./export-all.sh` on pg2 and
`./import-all.sh` on the Mac with no new required arguments.

[Back to TOC](#table-of-contents)

---

## Problem Statement

On 2026-08-19, `export-all.sh` ran on pg2 with the 50GB root disk nearly full
(`export_data/` held ~9.8GB of accumulated tarballs, and the eyedro export's
uncompressed `public_schema_backup.sql` intermediate pushed it over).
The `tar` of `pgui/data` in `export-pgdb.sh` failed, so **no JSON tarball was
created** — but with no error handling the run continued and looked
successful. On the Mac, `import-pgdb.sh` failed to scp the nonexistent
tarball, ignored the failure, and ran `rm -rf data` anyway, destroying the
Mac's `pgui/data` mirror.

Space was the trigger; absent error handling turned a full disk into silent
data loss. The scripts must warn about space **before** failure, stop loudly
on any error, and never destroy existing data before its replacement is
verified. Interim commit `e260d35` addressed the space ratchet only; the
error-handling, verification, and verify-then-swap requirements remain
entirely unimplemented and the wrong-database hazard below remains live.

[Back to TOC](#table-of-contents)

---

## Key Findings 🤖

Gathered 2026-08-20; sizes and interim-work notes refreshed 2026-09-05:

- **pg2 and the Mac share this git repo.** pg2's `~/sync` is a clone kept
  current by Chris's push (Mac) + pull (pg2) — no scp of scripts needed.
  Commit `e260d35` is live on both hosts.
- **The wrappers are symlinks, not copies.** Mac: `ip → import-pgdb.sh`,
  `ipr → import-purify.sh`, `ie → import-eyedro.sh`. pg2: `ep → export-pgdb.sh`,
  `ee → export-eyedro.sh`, `epr → export-purify.sh`. All are gitignored.
  There is no duplication to consolidate — hardening the real scripts
  automatically covers the wrappers.
- **Current sizes, 2026-09-05** (for the space estimator): **purify is now
  the largest artifact** — 9.7GB in Postgres, 5.2GB raw dump, ~360MB tgz.
  Eyedro: ~1.5GB in Postgres, ~540MB tgz. Weather: ~15MB raw → 2.8MB tgz.
  pgdb: pgui/data ~48MB → 6MB JSON tgz; pgdump tgz ~95KB. One full run
  therefore produces roughly **0.9GB of tarballs** and needs ~5.5GB of
  transient headroom for the purify raw dump. The 2026-08-19 debris and the
  old tarball accumulation were cleared 2026-09-05 by `sync-trim`
  (~4.3GB freed).
- **`$(ggdir bin)/sync-trim` exists** (bin repo, Mac-only): ssh-trims pg2's
  `export_data` to the newest tgz per family and deletes stray raw `.sql`
  files. It duplicates retention logic that this plan moves into the sync
  repo — disposition in Step 4.4.
- **Latent wrong-database hazard (still live)**: `export-eyedro.sh`,
  `export-pgdb.sh`, and `export-purify.sh` all write a file literally named
  `public_schema_backup.sql` in the same shared directory, and the import
  scripts extract to and read from that same shared name. If an scp or tar
  step fails but a *previous* script's `public_schema_backup.sql` is lying
  around, today's scripts would `DROP SCHEMA public CASCADE` and restore the
  **wrong database's dump** (e.g. pgdb's dump into purify). `e260d35`
  narrowed the window (the file is now deleted after each successful
  restore) but did not close it — a failed scp with a leftover from an
  *earlier failed* run still restores the wrong dump. Phase 3 removes this
  hazard with per-script work directories.

[Back to TOC](#table-of-contents)

---

## Interim Work Reconciliation 🤖

Commit `e260d35` (2026-09-05, "Make sync pipeline self-cleaning") landed on
`main` as interim work and is live on both hosts. This plan treats it as the
baseline. Every change it made is explicitly **kept** or **superseded** here
— no double cleanup, no conflicting retention logic:

| `e260d35` change | Disposition in this plan |
|---|---|
| `export-eyedro/pgdb/purify.sh`: `tar czvf ... && rm -f <dump>.sql` after each tar | **Superseded** by Step 2.x + 4.1: the delete moves behind `verify_tgz` (verify-then-delete). The interim form gates the delete on tar's exit code alone; a truncated-but-exit-0 tarball would still destroy the only copy of the dump. |
| `import-*.sh`: `&& rm -f <dump>.sql` after each successful psql restore | **Superseded** by Step 3.3: dumps extract into per-member work directories that are removed whole on success and kept on failure. No shared-name `.sql` ever exists to clean up or to mis-restore. |
| `export-all.sh` / `import-all.sh`: inline keep-newest-2 trim per tgz family **at the end** of the run | **Superseded** by Step 4.2: the inline blocks are removed and replaced by one `prune_exports` call **at the start** of the run, before the space gate — freed space then helps the run that needs it. Retention counts settled in Decision Point 2. |
| The `pg2-pgdb-*.tgz` glob-overlap exclusion (`grep -v pgdump`) | **Kept** — the same family definitions (with that exclusion) move into `prune_exports` in `sync-lib.sh`, the single copy both hosts and the standalone prune script use. |
| `df -h /` printed at end of run | **Kept** — folded into the `manifest_report` footer so the disk picture appears with the artifact table. |

`$(ggdir bin)/sync-trim` (bin repo, not part of `e260d35` but same interim
effort) also duplicates the retention logic; Step 4.4 turns it into a thin
wrapper over the repo's own prune script via a handoff patch.

[Back to TOC](#table-of-contents)

---

## Decision Points for Chris 👤

Two choices are yours to make at plan review; the plan proceeds with the
recommended option unless you say otherwise.

### Decision 1: How the space-free step is surfaced

You asked to be prompted about freeing space when starting a sync rather
than discovering a failure later. Two candidate behaviors, both implemented
entirely inside `export-all.sh` / `import-all.sh` (the SYNC-owned entry
points; no bin-repo change needed for either):

- [ ] **Option A — interactive prompt every run**: at the start,
  `export-all.sh` / `import-all.sh` print current `export_data` usage and
  what pruning would free, then ask `Prune old exports first? [y/N]` and
  wait. **Caveat**: when Chris runs `sync-all`, `export-all.sh` executes
  over ssh without a TTY (`pgs "... ./export-all.sh"`), where a prompt
  cannot be answered — so Option A must detect "stdin is not a TTY" and
  fall back to Option B behavior on that path. Net effect: the prompt only
  ever appears when running `export-all.sh` by hand on pg2.
- [x] **Option B — automatic prune plus loud space gate (recommended)**:
  every run prunes automatically first (reporting every file deleted and
  bytes freed), then the space gate compares required vs. available and
  stops loudly **before anything is written** if space is still short.
  Chris is interrupted only when something is actually wrong, and the
  behavior is identical whether the script runs by hand or via `sync-all`
  over ssh. This is the "warn before failure" guarantee without a
  y/N toll-booth on every healthy run.

**Recommendation: Option B** — it satisfies "tell me at the start, not after
a failure" (the prune report and gate banner are the first output of every
run), and Option A degrades to Option B on the `sync-all` path anyway.

- [x] 👤 Chris selected **Option B** (2026-09-06, rev 2 approval message via
  es2: "automatic prune + gate. No prompt.").

### Decision 2: Retention counts

Interim behavior is keep-2 on both hosts; the original plan said keep-5
(pg2) / keep-8 (Mac). **Recommended: keep-2 on pg2, keep-5 on the Mac**
(overridable via `SYNC_KEEP`). Rationale: at current sizes a full run's
tarballs total ~0.9GB, so pg2 — the space-constrained 50GB host whose
exports are mirrored to the Mac on every import — idles at ~1.8GB with
keep-2 (today's run plus one fallback), while the Mac, the archive of
record with the roomier disk, holds ~4.5GB across five generations of
recovery depth with keep-5.

- [x] 👤 Chris approved **keep-2 (pg2) / keep-5 (Mac)** (2026-09-06, rev 2
  approval message via es2: "as recommended").

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
  bytes × 1.5 margin; if no state file exists, defaults reflecting the
  2026-09-06 measurements apply (eyedro 7 GiB — its 6.7GB raw dump
  dominates — purify 6 GiB, pgdb 1 GiB). Because members run sequentially
  and each deletes its raw dump once its tarball verifies, a combined gate
  requires the **largest** member's bytes, not the sum (refined 2026-09-06
  during the Step 6.3 pre-live check: the sum model demanded 20 GiB on a
  pg2 with 13.2 GiB free for a run whose true peak is ~7.6 GiB). The gate
  also enforces an absolute floor: the run must leave ≥ 2 GiB free
  afterward.
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

- **Retention rule** (pending Decision 2): keep the newest **2** dated
  tarballs per artifact family on **pg2**, newest **5** per family on the
  **Mac**. Families: `pg2-eyedro-pgdump-*`, `weather-db-*`, `pg2-pgdb-*`
  (JSON, excluding pgdump), `pg2-pgdb-pgdump-*`, `pg2-purifi-pgdump-*`.
  Pruning always reports every file it deletes and the bytes freed, and
  never deletes the newest file of a family regardless of age. Host is
  detected via `uname` (Darwin = Mac limits, Linux = pg2 limits).
- **Failed import leaves on disk**: the existing `data/` (or its `data.prev`
  predecessor) untouched, any partial downloads in a clearly named
  `work-YYYYMMDD-<member>/` directory for inspection, and a FAILED manifest
  line naming the member and step. No `DROP SCHEMA` will have run for any
  member whose dump did not verify.

[Back to TOC](#table-of-contents)

---

## Phase 1: Shared Helper Library sync-lib 🤖

**Implemented 2026-09-06**: `sync-lib.sh` created with all planned helpers
(`die`, `run_step`, `require_space`, `verify_tgz`, `manifest_*`,
`prune_exports`, `record_sizes`) plus `psql_replay`, `remote_preflight`,
`fdw_bootstrap_file`, and `pgui_dir` (for Step 3.7 and test sandboxing).
One bug found by the Phase 5 suite and fixed: `last_size_bytes` crashed
under `set -e` when `.sync-last-sizes` did not yet exist (awk exit 2 on a
missing file); it now returns empty so the defaults apply.

### Step 1.1: Create sync-lib with error and banner helpers 🤖

- [x] Create `sync-lib.sh` in the repo root. Every script will begin with
  `set -euo pipefail` and `source "$(dirname "$0")/sync-lib.sh"`.
- [x] Implement `die "msg"` (unmissable multi-line banner to stderr, exit 1)
  and `run_step "label" cmd...` (echo the label, run the command, `die` with
  the label on failure).
- [x] Honor `SYNC_ROOT` (default: the script's own directory) and
  `EXPORT_DATA` (default `$SYNC_ROOT/export_data`) so the test sandbox in
  Phase 5 can redirect everything without touching live paths.

[Back to TOC](#table-of-contents)

### Step 1.2: Space gate function 🤖

- [x] Implement `require_space <member>`: reads `.sync-last-sizes` for the
  member's last total bytes (tarballs + intermediates), takes the largest
  member (sequential self-cleaning pipeline — see Design Summary),
  multiplies by 1.5, falls back to per-member defaults when no state exists
  (eyedro 7 GiB, purify 6 GiB, pgdb 1 GiB — 2026-09-06 figures), compares
  against `df -Pk` available space on the `export_data` filesystem, and
  enforces the 2 GiB post-run floor.
  *(Refined 2026-09-06 pre-live: sum→max model and corrected eyedro
  default; the eyedro raw dump is 6.7GB, not the ~1.5GB the revision
  request reported. Also hardened import-eyedro to check the FDW bootstrap
  file exists during pre-flight, before any schema drop.)*
- [x] On failure, print the space-gate banner shown in the Design Summary and
  exit nonzero **before any artifact is written**.
- [x] Support `SYNC_FAKE_AVAIL_KB` env override so tests can force the gate
  to fail without filling a disk.

[Back to TOC](#table-of-contents)

### Step 1.3: Artifact verification and manifest functions 🤖

- [x] Implement `verify_tgz <path>`: file exists, size above a per-family
  sanity floor, `tar -tzf` succeeds, entry count > 0. `die` on any failure.
- [x] Implement `manifest_add <member> <artifact> <status> <size>` writing to
  a per-run manifest file, and `manifest_report` printing the final table
  with OK / MISSING / FAILED per expected artifact (plus a `df -h` footer,
  preserving `e260d35`'s end-of-run disk report) so a missing artifact can
  never hide again.

[Back to TOC](#table-of-contents)

### Step 1.4: Retention prune function 🤖

- [x] Implement `prune_exports`: for each artifact family, keep the newest N
  (per Decision 2: 2 on pg2, 5 on Mac, overridable via `SYNC_KEEP`), delete
  the rest, print every deletion and total bytes freed. Never delete a
  family's newest file. Preserve `e260d35`'s pgdb glob-overlap exclusion in
  the family definitions. Also delete stray uncompressed
  `*_schema_backup.sql` files older than the current run.

[Back to TOC](#table-of-contents)

### Step 1.5: Last-run size recording 🤖

- [x] Implement `record_sizes <member>` capturing actual artifact and
  intermediate sizes at the end of each successful member run into
  `export_data/.sync-last-sizes` (one line per member, replaced atomically).

[Back to TOC](#table-of-contents)

---

## Phase 2: Export Script Hardening 🤖

All export scripts run on pg2 but are edited only on the Mac in this repo
(delivered by git push/pull in Phase 6). Baseline is the post-`e260d35`
scripts: the `tar ... && rm -f` forms are replaced, not layered on.

**Implemented 2026-09-06**: all three members rewritten with
`set -euo pipefail` + sync-lib; pg_dump now writes into per-run
`work-YYYYMMDD-<member>/` dirs (tar member names inside the tgz are
unchanged, so pg4 consumers are unaffected); every tar is `run_step` +
`verify_tgz`; intermediates delete only after verification;
`record_sizes` + `manifest_add` on success. `export-all.sh` gained the
Option-B prune → combined gate → members → manifest + banner flow, with the
`e260d35` inline trim blocks removed.

### Step 2.1: Harden export-eyedro 🤖

- [x] `set -euo pipefail`, source sync-lib, `require_space eyedro` first.
- [x] Run pg_dump into a per-run work file, `run_step` each tar, `verify_tgz`
  both tarballs, **then** delete the uncompressed `.sql` intermediates
  (replacing `e260d35`'s delete-on-tar-exit-code), `record_sizes eyedro`,
  `manifest_add` results.

[Back to TOC](#table-of-contents)

### Step 2.2: Harden export-pgdb 🤖

- [x] Same treatment. The pgui/data tar (the step that failed silently on
  2026-08-19) becomes `run_step` + `verify_tgz`, so a failure aborts with a
  banner and a FAILED manifest line instead of vanishing.

[Back to TOC](#table-of-contents)

### Step 2.3: Harden export-purify 🤖

- [x] Same treatment as Step 2.1 for the single purify pgdump artifact —
  now the largest member (5.2GB raw dump), so its space gate matters most.

[Back to TOC](#table-of-contents)

### Step 2.4: export-all orchestration and manifest 🤖

- [x] `export-all.sh` runs `prune_exports` (replacing the `e260d35` inline
  trim block — see Step 4.2), then a combined `require_space` for all three
  members, then each member in order, stopping at the first failure; it
  always ends with `manifest_report` listing every expected artifact for the
  date with status and size, plus a loud overall SUCCEEDED /
  FAILED-AT-<member> banner.
- [x] If Decision 1 = Option A: the interactive prune prompt runs here,
  degrading to automatic behavior when stdin is not a TTY.
- [x] Invocation surface unchanged: `./export-all.sh`, no arguments.

[Back to TOC](#table-of-contents)

---

## Phase 3: Import Script Hardening 🤖

**Implemented 2026-09-06**: all member scripts and both transfer-files
scripts rewritten per Steps 3.1–3.7. `import-all.sh` does the all-or-nothing
remote pre-flight before touching anything, then Option-B prune + space
gate, then members with the manifest/banner trap. `import-pgdb.sh` does
verify-then-swap through `data.incoming/` → `data.prev`; the legacy
`rm -rf data` is gone. Every member extracts into its own work dir and
replays via `psql_replay` (error accounting). Step 3.7's Mac-only FDW
bootstrap runs between schema recreation and the public replay, with
post-import FDW verification.

### Step 3.1: Remote pre-flight check of pg2 artifacts 🤖

- [x] Before any download or destructive step, `import-all.sh` (and each
  member script when run standalone) checks via `ssh pg2 stat` that every
  expected tarball for today's date exists on pg2 and is nonzero. A missing
  artifact aborts with: which file is missing, and the hint "did
  export-all.sh run and succeed on pg2 today?". This alone would have
  stopped the 2026-08-19 loss before anything was touched.

[Back to TOC](#table-of-contents)

### Step 3.2: import-pgdb verify-then-swap for pgui data 🤖

- [x] scp the JSON tarball, `verify_tgz` it, extract into `data.incoming/`
  (never over live `data/`), and sanity-check that `dml-ast.json` and
  `ddl-ast.json` exist and are nonzero in the extraction.
- [x] Only then swap: `mv data data.prev` (removing any older `data.prev`
  first), `mv data.incoming data`. The prior generation survives as
  `data.prev` until the next successful import, so a bad run is recoverable
  with a single `mv` back.
- [x] On any failure before the swap, live `data/` is untouched and the
  partial material remains in `data.incoming/` for inspection.

[Back to TOC](#table-of-contents)

### Step 3.3: Per-script work directories for dump extraction 🤖

- [x] Each import member extracts its pgdump tarball into its own
  `work-YYYYMMDD-<member>/` directory and feeds psql from there, eliminating
  the shared `public_schema_backup.sql` filename collision (the
  wrong-database hazard in Key Findings). Work directories are removed on
  success and kept on failure. This **supersedes** `e260d35`'s
  `&& rm -f <dump>.sql` after psql — there is no longer a shared-name file
  to delete.
- [x] `DROP SCHEMA ... CASCADE` runs **only after** the member's own tarball
  verified and its dump file extracted nonzero in this run's work directory.

[Back to TOC](#table-of-contents)

### Step 3.4: Harden import-eyedro and import-purify 🤖

- [x] Apply Steps 3.1 and 3.3 semantics to both: pre-flight remote check,
  verified download, per-member work dir, verified dump before any
  `DROP SCHEMA`, loud abort on psql failure, manifest lines.

[Back to TOC](#table-of-contents)

### Step 3.5: import-all orchestration and manifest 🤖

- [x] `import-all.sh` runs the full remote pre-flight for all members first
  (all-or-nothing before anything is touched), runs `prune_exports` on the
  Mac's `export_data/` (replacing the `e260d35` inline trim block), then
  each member, stopping at first failure, ending with `manifest_report` and
  a loud overall banner. If Decision 1 = Option A, the prompt runs here too
  (import-all always has a TTY, so no fallback needed on this side).
  Invocation unchanged: `./import-all.sh`, no arguments.

[Back to TOC](#table-of-contents)

### Step 3.6: Harden the transfer-files scripts 🤖

- [x] `import-pgdb-transfer-files.sh` and `import-eyedro-transfer-files.sh`
  get the same pre-flight, `run_step` scp, and `verify_tgz` treatment before
  uploading to pg4 (they are non-destructive, so no swap logic is needed).

[Back to TOC](#table-of-contents)

### Step 3.7: Eyedro FDW bootstrap and replay error accounting 🤖👤

Added rev 2 per the approved `prompts/eyedro-sync-missing-assets-research.md`
(§5.1, §5.4): each eyedro import silently destroys the Mac's FDW stack
(`DROP SCHEMA public CASCADE` drops postgres_fdw → server → mappings →
foreign tables), and the dump's `CREATE FOREIGN TABLE public.product ...
SERVER crossdb_pgdb2_server` then fails against the missing server.

- [x] **FDW bootstrap (Mac only)**: in `import-eyedro.sh`, after
  `DROP SCHEMA public CASCADE; CREATE SCHEMA public;` and **before** the
  dump replay, on Darwin only, run
  `psql ... -v ON_ERROR_STOP=1 -f "$(ggdir db)/sql/mac-fdw-bootstrap.sql"`,
  and `die` loudly if that file is absent. pg2 never runs the bootstrap.
- [ ] 👤 **db-team handoff**: the db repo provides
  `sql/mac-fdw-bootstrap.sql` — idempotent, exactly three statements:
  `CREATE EXTENSION IF NOT EXISTS postgres_fdw`; `CREATE SERVER
  crossdb_pgdb2_server` (**production's server name**, Mac-local options:
  host localhost, port 5432, dbname pgdb, sslmode disable); `CREATE USER
  MAPPING FOR chris` with the same Mac-local credentials mac-joins.sql uses
  today. Because the server name matches production, the dump's own foreign
  table restores cleanly and future FDW objects flow down automatically.
  Chris relays this request to the db team; the sync side merely invokes
  the file. (Naming gloss: `crossdb_pgdb2_server` is the postgres_fdw
  foreign-server **object inside the eyedro database**, named for its
  TARGET — the RDS database `pgdb_2` — and has nothing to do with the pg2
  host.)
- [x] **Replay error accounting (all three import members)**: the dump
  replay cannot use blanket `ON_ERROR_STOP` — the eyedro dump alone carries
  ~102 OWNER/GRANT statements for roles absent on the Mac (benign). Instead
  capture psql stderr, whitelist the `role "..." does not exist` class,
  fail the member (with counts in the manifest) if any unexpected error
  remains. The bootstrap above, by contrast, keeps true `ON_ERROR_STOP` —
  it has no benign errors.
- [x] **Post-import FDW verification (eyedro)**: after replay assert
  `postgres_fdw` in `pg_extension`, `crossdb_pgdb2_server` in
  `pg_foreign_server`, and `SELECT count(*) FROM public.product` succeeds;
  failure = FAILED manifest line.

[Back to TOC](#table-of-contents)

---

## Phase 4: Retention and Space Ratchet 🤖

This phase supersedes the interim `e260d35` mechanisms per the
[Interim Work Reconciliation](#interim-work-reconciliation-🤖) table.

**Implemented 2026-09-06**: no `rm` of an intermediate remains outside a
post-`verify_tgz` path; the inline trim blocks are gone from both
all-wrappers in favor of `prune_exports` at run start (keep-2 pg2 / keep-5
Mac per Decision 2, `SYNC_KEEP` override); `prune-export-data.sh` added
with `--dry-run`/`-n`. The Step 4.4 sync-trim patch text below remains a
handoff for Chris to apply in the bin repo after deployment.

### Step 4.1: Verify-then-delete for uncompressed intermediates 🤖

- [x] Every export member deletes its `*_schema_backup.sql` work files only
  after `verify_tgz` passes (replacing the `e260d35` delete-on-tar-exit
  form); every import member removes its work directory after success
  (already specified in 2.x / 3.3 — this step verifies no path leaves
  intermediates behind on success, and that the delete never runs when
  verification failed, so a bad tarball can't orphan the only dump copy).

[Back to TOC](#table-of-contents)

### Step 4.2: Replace inline trim with prune_exports in the all-wrappers 🤖

- [x] **Remove** the `e260d35` inline keep-2 trim blocks (and trailing
  `df -h /`) from `export-all.sh` and `import-all.sh`; call `prune_exports`
  **at the start** of each, before the space gate, so retention frees space
  ahead of the estimate check instead of after the run. Counts per
  Decision 2 (keep-2 pg2, keep-5 Mac). The `df` report moves into
  `manifest_report`. No other retention logic remains anywhere in the repo
  — one implementation, in `sync-lib.sh`.

[Back to TOC](#table-of-contents)

### Step 4.3: Standalone prune script 🤖

- [x] Add `prune-export-data.sh` (repo root, works on either host) so the
  space-gate warning's remediation hint is a single command. Supports
  `--dry-run` to list what would be deleted.

[Back to TOC](#table-of-contents)

### Step 4.4: sync-trim handoff patch for the bin repo 👤

**Recommendation: keep `sync-trim` as a thin wrapper, not retire it.** It
remains useful as the Mac-side one-shot ("free space on pg2 right now,
without running a sync"), but its duplicated retention logic must go —
`prune-export-data.sh` in this repo (versioned, present on both hosts after
pull) becomes the single implementation.

- [x] SYNC delivers the following replacement as **handoff patch text only**
  (the bin repo is outside SYNC's scope; Chris applies and commits it in
  `$(ggdir bin)` himself):

  ```bash
  #!/bin/bash
  # sync-trim — trim pg2:~/sync/export_data using the sync repo's own
  # prune script (single source of retention truth: sync/sync-lib.sh).
  #
  # Usage:
  #   sync-trim          trim old exports on pg2
  #   sync-trim -n       dry run: show what would be removed
  set -uo pipefail
  ARG=""
  if [[ "${1:-}" == "-n" || "${1:-}" == "--dry-run" ]]; then
    ARG="--dry-run"
  fi
  ssh pg2 "source ~/ggmap && gg sync && ./prune-export-data.sh $ARG && df -h / | tail -1"
  ```

- [ ] 👤 Chris applies the patch in the bin repo (after Phase 6's pull puts
  `prune-export-data.sh` on pg2) and confirms `sync-trim -n` works.

[Back to TOC](#table-of-contents)

---

## Phase 5: Failure-Path Testing 🤖

No test touches live databases, live `pgui/data`, or the real
`export_data/`. Everything runs in a sandbox via env overrides.

**Implemented 2026-09-06**: `tests/run-tests.sh` + `tests/shims/`
(pg_dump/psql/scp/ssh/tar) cover eleven scenarios — T1 space gate, T2 the
2026-08-19 silent-tar scenario now loud, T3 corrupt-but-exit-0 tar with
verify-then-delete, T4 missing remote artifact leaves data untouched, T5
corrupt download / no swap, T6 wrong-dump isolation, T7 missing FDW
bootstrap blocks before replay, T8a/b error accounting both ways, T9/T10
happy-path export/import with retention + swap + FDW verification, T11
prune dry-run. **Result: 56/56 assertions PASS** (first run caught the
`last_size_bytes` bug noted in Phase 1, re-run green).

### Step 5.1: Test sandbox and command shims 🤖

- [x] Create `tests/` with a runner (`tests/run-tests.sh`) that builds a
  scratch `SYNC_ROOT` (under the system temp dir), a fake `export_data/`
  with dated dummy tarballs, and a `shims/` directory prepended to PATH
  containing fake `pg_dump`, `psql`, `scp`, `ssh`, and `tar` wrappers whose
  behavior (succeed, fail, produce short output) is driven by env vars.

[Back to TOC](#table-of-contents)

### Step 5.2: Export failure tests 🤖

- [x] Space gate blocks: with `SYNC_FAKE_AVAIL_KB` set low, `export-all.sh`
  exits nonzero before writing anything, printing the space banner.
- [x] Tar failure: shim `tar` fails for the pgdb JSON step; the run aborts,
  the manifest shows `pg2-pgdb-<date>.tgz FAILED`, and the failing member is
  named in the final banner (the exact 2026-08-19 scenario, now loud).
- [x] Verify-then-delete: shim `tar` exits 0 but produces a corrupt tgz;
  assert the run aborts at `verify_tgz` and the `.sql` intermediate was
  **not** deleted (the gap in `e260d35`'s delete-on-exit-code, now closed).

[Back to TOC](#table-of-contents)

### Step 5.3: Import failure tests 🤖

- [x] Missing remote tarball: shim `ssh`/`stat` reports the JSON tarball
  absent; `import-all.sh` aborts in pre-flight; assert the sandbox `data/`
  directory is untouched (the incident's data-loss path, now impossible).
- [x] Corrupt tarball: `verify_tgz` rejects a truncated tgz; assert `data/`
  and `data.prev` untouched and `data.incoming/` retained.
- [x] Wrong-dump isolation: leave a stale `public_schema_backup.sql` in the
  shared directory, fail one member's scp, and assert no `psql` shim call
  ever received the stale file (proves the per-member work-dir fix).
- [x] FDW bootstrap failure: with the bootstrap file absent (or the psql
  shim failing it), assert the eyedro member fails loudly **before** any
  replay psql call (Step 3.7).
- [x] Error accounting: inject a whitelisted `role "eyedro_user" does not
  exist` error → member still OK; inject an unexpected psql error → member
  FAILED with the error counted in the manifest (Step 3.7).

[Back to TOC](#table-of-contents)

### Step 5.4: Happy-path regression 🤖

- [x] Full sandbox export + import with all shims succeeding: assert every
  artifact verifies, manifests show all OK, intermediates and work dirs are
  cleaned, retention deletes the oldest dummies and keeps the newest N
  (2/5 per Decision 2), and `.sync-last-sizes` is written.

[Back to TOC](#table-of-contents)

---

## Phase 6: Deployment and Live Verification 🤖👤

### Step 6.1: Git add and commit on Mac including prompts docs 🤖

- [x] Itemized `git add` (each file by name, no wildcards, no `-A`) of the
  changed scripts, `sync-lib.sh`, `prune-export-data.sh`, `tests/` files,
  **and the prompts documents** — `prompts/space-safety-sync-plan-request.md`,
  `prompts/space-safety-sync-plan.md`,
  `prompts/space-safety-sync-update-plan-request.md`,
  `prompts/eyedro-sync-missing-assets-research-request.md`,
  `prompts/eyedro-sync-missing-assets-research.md` — which are currently
  untracked (revision Requirement 5). Commit to the `space-safety-sync`
  branch (then merge to main per the gitm workflow when approved).

**Implemented 2026-09-06**: 23 files added by name (no wildcards, no `-A`)
and committed to `space-safety-sync` in a single commit; tests were green
(56/56) at commit time.

[Back to TOC](#table-of-contents)

### Step 6.2: Push from Mac and pull on pg2 👤

- [ ] Chris pushes from the Mac and pulls in `~/sync` on pg2, then replies
  "pull done". No scripts are ever edited directly on pg2.

[Back to TOC](#table-of-contents)

### Step 6.3: Supervised live export on pg2 👤

- [ ] Chris runs `./export-all.sh` on pg2. Expected: retention prune report
  first, space gate PASS, all five artifacts created and verified, closing
  manifest all OK with the `df` footer.

[Back to TOC](#table-of-contents)

### Step 6.4: Supervised live import on Mac 👤🤖

- [ ] 👤 Prerequisite: the db team's `sql/mac-fdw-bootstrap.sql` exists in
  `$(ggdir db)` (Step 3.7 handoff) before this run.
- [ ] Chris runs `./import-all.sh` on the Mac. Expected: remote pre-flight
  PASS, verify-then-swap refreshes `pgui/data`, all schemas imported,
  manifest all OK, `data.prev` present. Claude verifies `dml-ast.json` /
  `ddl-ast.json` afterward, plus the eyedro FDW state: `postgres_fdw`
  installed, `crossdb_pgdb2_server` present, `public.product` queryable,
  and `esb_metrics_with_intervals_one_dg` present (it arrives with this
  fresh export, closing the timeline race from the research). Then marks
  this plan complete. Chris then applies the Step 4.4 sync-trim patch in
  the bin repo.

[Back to TOC](#table-of-contents)

---

## Acceptance Criteria Mapping

**Parent request (2026-08-20):**

- **Both hosts, every script enumerated, wrapper handling** — Scope covers
  `sync-lib.sh` (new), `export-all/eyedro/pgdb/purify.sh`,
  `import-all/eyedro/pgdb/purify.sh`, both `*-transfer-files.sh`,
  `prune-export-data.sh` (new), `tests/` (new). `ip`/`ipr`/`ie` and
  `ep`/`ee`/`epr` are symlinks (Key Findings), so they inherit every fix;
  no consolidation needed.
- **Space estimate + warning** — Step 1.2 and the Design Summary banner.
- **Verification and verify-then-swap, failed-import residue** — Steps 1.3,
  3.2, 3.3; residue defined in the Design Summary.
- **Retention rule per host** — Decision 2, Steps 1.4, 4.2, 4.3.
- **Failure-path tests without live data** — Phase 5 sandbox and shims.
- **Invocation surface unchanged** — Steps 2.4 and 3.5.

**Revision request (2026-09-05):**

- **Every `e260d35` change kept or superseded, no double cleanup** — the
  [Interim Work Reconciliation](#interim-work-reconciliation-🤖) table;
  enforced in Steps 2.1, 3.3, 4.1, 4.2.
- **One recommended retention count per host with rationale** — Decision 2:
  keep-2 pg2 / keep-5 Mac.
- **Space-free surfacing as explicit Chris decision, both options
  specified** — Decision 1 (Option A prompt vs. Option B automatic,
  recommendation B, TTY caveat noted); wiring in Steps 2.4 and 3.5; no
  bin-repo change needed for either option.
- **sync-trim disposition, bin changes as handoff patch text** — Step 4.4
  (thin-wrapper recommendation with exact replacement script).
- **Sizes refreshed to 2026-09-05** — Key Findings and Step 1.2 defaults
  (purify now largest).
- **Plan docs committed** — Step 6.1.
- **Plan conventions** — TOC with checkboxes, numbered phases/steps,
  Typora-compatible hotlinks, Back to TOC links throughout.

**Eyedro FDW research (2026-09-05, approved by Chris):**

- **FDW stack survives every import** — Step 3.7 bootstrap (production's
  server name, Mac-local options) + db-team handoff; verified in Step 6.4.
- **Replay errors accounted, not silenced and not over-fatal** — Step 3.7
  error accounting with the role-error whitelist; tested in Step 5.3.
- **Function timeline race** — no script change needed; the next export
  carries `esb_metrics_with_intervals_one_dg` (verified in Step 6.4).

[Back to TOC](#table-of-contents)

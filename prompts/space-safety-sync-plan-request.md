# Sync Space Safety - SYNC Plan Request

**Created**: 2026-08-20
**Author**: Claude Code (PGUI session, on behalf of Chris)
**Status**: Plan Requested
**Origin**: 2026-08-19 sync incident (space exhaustion on pg2 → silent export failure → Mac data-directory loss)
**Deliverable**: `$(ggdir sync)/prompts/space-safety-sync-plan.md`

---

## Overview

This plan request asks the SYNC team to create an implementation plan for
making the sync-all ritual (pg2 exports + Mac imports) safe against disk-space
exhaustion: it must never destroy existing data on a failed run, and it must
warn the invoker about space conditions *before* they cause a failure.

**Deliverable**: the SYNC team will produce
`$(ggdir sync)/prompts/space-safety-sync-plan.md` — a detailed implementation
plan that Chris can review and approve before any script changes.

## Incident Summary (what happened 2026-08-19)

- `export-all.sh` on pg2 ran while `sync/export_data/` (~9.8GB of accumulated
  tarballs) plus the eyedro export's ~5.4GB uncompressed
  `public_schema_backup.sql` intermediate pushed the 50GB root disk to full.
- `export-pgdb.sh`'s first step (`tar` of pgui/data → `pg2-pgdb-20260819.tgz`)
  failed; **no JSON tarball was created**. The scripts have no error handling,
  so the run continued and "completed" — the small pgdump tarball succeeded,
  camouflaging the failure. The purify export for that date is missing too.
- On the Mac, `import-pgdb.sh` scp'd the nonexistent tarball (failed, ignored),
  then ran `rm -rf data` in pgui anyway. The Mac's `pgui/data/` mirror was
  destroyed: `dml-ast.json`, `ddl-ast.json`, change-log, backups, `exports/`,
  and the git-tracked `en-US.json` (the last was restored from git; the rest
  await a fresh sync).

Root cause in one line: **space was the trigger; absent error-handling turned
a full disk into silent data loss.**

## Scope

- **pg2**: `sync/export-all.sh`, `sync/export-eyedro.sh`, `sync/export-pgdb.sh`,
  `sync/export-purify.sh`
- **Mac**: `~/sync/import-all.sh`, `~/sync/import-eyedro.sh`,
  `~/sync/import-pgdb.sh`, `~/sync/import-purify.sh`,
  `~/sync/import-pgdb-transfer-files.sh`, and the wrapper copies
  `~/sync/ip`, `~/sync/ipr`, `~/sync/ie` (note: `ip` currently duplicates
  `import-pgdb.sh` — the plan should say how the duplicates are kept in
  agreement or consolidated)

## Requirements

1. **Pre-flight space gate, both hosts.** Before any artifact is written,
   compare free disk space against a required estimate for the run. If space
   is insufficient, stop *before writing anything* and tell the invoker
   clearly what is needed, what is available, and what to do about it
   (e.g. prune `export_data`, free space) — the warning-first behavior Chris
   asked for.
2. **Fail loudly, stop on error.** A failed step (tar, scp, pg_dump, psql)
   must abort its script with an unmissable message, and `export-all.sh` /
   `import-all.sh` must surface which member failed rather than continuing
   silently.
3. **Verify artifacts after creation.** Every expected tarball is checked
   (exists, nonzero, tar-readable) and the run ends with a manifest listing
   every expected artifact and its status, so a missing artifact can never
   hide again.
4. **Never destroy before verifying the replacement.** Import-side scripts
   must not remove existing data (notably pgui/data on the Mac) until the
   incoming tarball has arrived and verified. Retaining the prior generation
   briefly (verify-then-swap) is desirable so a bad run is recoverable.
5. **Stop the space ratchet.** Uncompressed dump intermediates
   (`public_schema_backup.sql`, `weather_schema_backup.sql`) are removed after
   tarring, and dated tarballs in `export_data/` (both hosts) get a bounded
   retention so baseline usage no longer grows without limit.
6. **The ritual's user surface stays the same.** Chris still runs
   `export-all.sh` on pg2 and `import-all.sh` on the Mac, same invocation, no
   new required arguments.

## Constraints

- Script edits happen on the Mac; pg2-side script updates are delivered for
  Chris to place (or with his explicit approval to scp) — never edited
  directly on pg2.
- The eyedro data-volume question (whether old data is archived or deleted to
  shrink the export itself) is being asked of Christi separately and is NOT
  part of this request; the plan should assume current data volumes.

## Acceptance Criteria for the Plan

- [ ] Covers both hosts and enumerates every script it will touch, including
      how the `ip`/`ipr`/`ie` duplicates are handled
- [ ] Defines how the required-space estimate is computed and what the
      space-condition warning looks like to the invoker
- [ ] Defines the artifact-verification and verify-then-swap behavior,
      including what a failed import leaves on disk
- [ ] Defines the retention rule for `export_data/` on each host
- [ ] Includes a test approach that exercises the failure paths (simulated
      full disk / missing tarball) without touching live data
- [ ] Confirms the invocation surface of `export-all.sh` / `import-all.sh` is
      unchanged
- [ ] TOC with checkboxes, numbered phases/steps, working hotlinks, Back to
      TOC links per plan conventions

Questions back: `$(ggdir pgui)/messages/` via Chris.

# Eyedro Sync Missing Postgres Assets — Sync Research Request

**Created**: 2026-09-05
**Author**: Claude Code (pgui@claude, on Chris's instruction)
**Status**: Research Requested
**Deliverable**: `$(ggdir sync)/prompts/eyedro-sync-missing-assets-research.md`

---

## Overview

This research request asks the sync team to determine why a sync-all run
completed on 2026-09-05 left the Mac eyedro database **missing Postgres
assets that exist and work on the production (RDS) eyedro database**, to
establish the full class of objects affected, and to propose how the sync
should handle them. Research first — no script changes until the findings are
reviewed.

## The observed gap

**Present and working on production eyedro (RDS eyedro_2)** — verified
directly on 2026-09-05 by read-only queries over ssh to pg2
(`psql -h $PGHOST_2 ... -d $PGDATABASE_2`), after the sync-all ran, at
every level from catalog to execution:

- Foreign table `public.product` on server `crossdb_pgdb2_server`
  (`\det` shows it; `pg_foreign_server` shows the server) — and it serves
  live data: `select count(*)` through it returns 12,012 rows, 78 with
  `parent_serial_number` set.
- Function `esb_metrics_with_intervals_one_dg(integer, integer)` in schema
  `public` (installed via the db repo's `sql/updates/upd-030.sql`, applied
  ~23:41 UTC 2026-09-04) — and it executes: a call with
  `(3, 2629)` returned 324 rows across 4 ESB devices, exercising the FDW
  join and the `esb_metrics_hourly` table in one statement.
- The db team's dependent `dpats.py` run left its artifact on pg2:
  `audit-esb-3hour-2629-20260905-234111-vmXUGtWK.xlsx` in the dbimport
  directory, timestamped minutes after upd-030 was applied.
- Drift corroboration: production `esb_metrics_hourly` held 342 hours at
  verification time versus the Mac's 322 immediately after the sync-all —
  the hourly production cron advances while the mirror stands still, so
  the data gap compounds on top of the missing objects.

**Absent on the Mac eyedro database immediately after the 2026-09-05
sync-all** — verified directly by catalog queries (`psql -h $PGHOST_2 ...`):

- `\det` — no foreign tables at all.
- `select * from pg_foreign_server` — zero rows.
- `\df *esb*` — no ESB function.
- The plain tables and data DID arrive (`esb_metrics_hourly` present with
  322 rows), so the sync ran and replaced the schema; it is specifically
  these object types that did not survive.

This is the second observation of the same gap: the identical absence was
recorded on 2026-09-04 (before this sync-all), and the sync-all run on
2026-09-05 — which was expected to bring these objects down, since they were
live in production by then — did not change it.

## Evidence available to the research

- The imported dump itself is retained on the Mac:
  `$(ggdir sync)/export_data/pg2-eyedro-pgdump-20260905.tgz` (21:01, ~541MB)
  — inspecting what it does and does not contain, and what would happen on
  restore, should settle the mechanism definitively.
- The export/import scripts: `$(ggdir sync)/export-eyedro.sh` (runs on pg2)
  and `$(ggdir sync)/import-eyedro.sh` (runs on the Mac). Noted without
  conclusion: the export dumps with `pg_dump -n public` / `-n weather`, and
  the import does `DROP SCHEMA public CASCADE` then replays the SQL file
  through psql without stopping on errors.
- The installing scripts for the missing objects, for reference on what
  production has: `$(ggdir db)/sql/joins-across-db.sql` (production FDW),
  `$(ggdir db)/sql/mac-joins.sql` (Mac-local FDW equivalent — note its
  foreign server points at the LOCAL pgdb, not RDS, so a naive copy of
  production's definitions would be wrong on the Mac even if it survived),
  and `$(ggdir db)/sql/updates/upd-030.sql` (the function).

## Requirements on the research

1. **Establish the mechanism**: exactly why each missing object type
   (function, foreign table, foreign server, user mapping, extension) did
   not arrive, using the retained tgz as primary evidence.
2. **Enumerate the affected class**: what other object types do the current
   export/import flags silently drop (across eyedro, pgdb, and purify
   imports — all three follow the same pattern)? The teams relying on
   mirrors need to know the full list, not just the two we hit.
3. **Recognize the environment-specific wrinkle**: FDW definitions are not
   host-portable (production's server points at RDS pgdb_2; the Mac's must
   point at local pgdb). A correct sync cannot simply copy production's
   definitions; the research should propose how the sync ritual handles
   such objects — carry them, re-create them per-host from the db repo's
   scripts, or explicitly document them as post-import steps.
4. **Propose the fix as a proposal**, with the trade-offs stated; script
   changes come after review.

## Acceptance Criteria

- The mechanism is proven from the retained dump, not theorized.
- A complete list of object types the sync does and does not carry.
- A concrete proposal for making Mac mirrors complete for these objects
  (or a documented, automated post-import step), covering all three
  database families.

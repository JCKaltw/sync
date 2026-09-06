# Eyedro Sync Missing Postgres Assets — Research

**Created**: 2026-09-05
**Author**: Claude Code (SYNC session)
**Status**: Approved by Chris 2026-09-05 — fix folded into `prompts/space-safety-sync-plan.md` Step 3.7 (rev 2)
**Research Request**: `prompts/eyedro-sync-missing-assets-research-request.md`
**Primary Evidence**: `$(ggdir sync)/export_data/pg2-eyedro-pgdump-20260905.tgz` (retained dump, inspected directly)

---

## Table of Contents

- [Overview](#overview)
- [Problem Statement](#problem-statement)
- [1 Timeline Reconstructed from Evidence 🤖](#1-timeline-reconstructed-from-evidence-🤖)
- [2 Mechanism per Missing Object 🤖](#2-mechanism-per-missing-object-🤖)
  - [2.1 The ESB function is a timeline race](#21-the-esb-function-is-a-timeline-race)
  - [2.2 The foreign table is dumped but its restore fails](#22-the-foreign-table-is-dumped-but-its-restore-fails)
  - [2.3 Server and user mapping and extension are never dumped](#23-server-and-user-mapping-and-extension-are-never-dumped)
  - [2.4 The DROP CASCADE ratchet wipes any local FDW install](#24-the-drop-cascade-ratchet-wipes-any-local-fdw-install)
- [3 The Full Affected Class 🤖](#3-the-full-affected-class-🤖)
  - [3.1 What the schema-scoped dumps carry](#31-what-the-schema-scoped-dumps-carry)
  - [3.2 What they silently drop](#32-what-they-silently-drop)
  - [3.3 Ownership and grants fail silently on every import](#33-ownership-and-grants-fail-silently-on-every-import)
  - [3.4 Unsynced schemas exist in all three databases](#34-unsynced-schemas-exist-in-all-three-databases)
- [4 The Environment Wrinkle and the Server Name Insight 🤖](#4-the-environment-wrinkle-and-the-server-name-insight-🤖)
- [5 Proposal 🤖](#5-proposal-🤖)
  - [5.1 Recommended — per-host FDW bootstrap before replay](#51-recommended--per-host-fdw-bootstrap-before-replay)
  - [5.2 Rejected — full-database dumps](#52-rejected--full-database-dumps)
  - [5.3 Rejected — documented manual step](#53-rejected--documented-manual-step)
  - [5.4 Error accounting instead of blanket ON_ERROR_STOP](#54-error-accounting-instead-of-blanket-on_error_stop)
  - [5.5 Coordination with the space-safety plan](#55-coordination-with-the-space-safety-plan)
- [6 Handoffs to Other Teams 👤](#6-handoffs-to-other-teams-👤)
- [7 Security Side Note 👤](#7-security-side-note-👤)
- [8 Open Questions 👤](#8-open-questions-👤)

---

## Overview

The 2026-09-05 sync left the Mac eyedro mirror without the ESB function, the
`product` foreign table, its foreign server, user mapping, and the
`postgres_fdw` extension — all live in production. Inspection of the retained
dump proves there are **two distinct mechanisms**, not one:

1. **The function is a timeline race, not a sync defect.** The export
   snapshot was taken hours *before* `upd-030.sql` was applied to
   production. The function was never in the dump because it did not yet
   exist. It will arrive on the next ordinary sync with no script change.
2. **The FDW stack is a structural gap.** `pg_dump -n <schema>` never dumps
   extensions, foreign servers, or user mappings (they are not schema
   members), so the dump's `CREATE FOREIGN TABLE` fails on restore against a
   server that does not exist — silently, because the import replays without
   stopping on errors. Worse, each import's `DROP SCHEMA public CASCADE`
   destroys any FDW stack previously installed by hand on the Mac, so the
   gap re-opens after every sync no matter what was installed before.

Two further findings surfaced: **~102 ownership/grant statements fail
silently on every eyedro import** (roles `eyedro_user`/`postgres` do not
exist on the Mac), and **all three production databases contain schemas the
sync never carries** (`netsuite` in eyedro, `backups` in purify,
`new_schema` in pgdb).

Section 5 proposes the fix: a per-host FDW bootstrap that runs inside
`import-eyedro.sh` before the dump replay, unified under production's server
name so the dump's own objects restore cleanly. Research only — no script
has been changed.

[Back to TOC](#table-of-contents)

---

## Problem Statement

After the 2026-09-05 sync-all, the Mac eyedro database had the plain tables
and data (`esb_metrics_hourly`, 322 rows) but none of: foreign tables
(`\det` empty), foreign servers (`pg_foreign_server` zero rows), or the ESB
function (`\df *esb*` empty) — all verified present and executing on
production the same day. This is the second observation of the identical
gap. The research request asks for the proven mechanism, the full affected
class across all three database families, and a proposal that respects the
FDW environment wrinkle (production's server points at RDS pgdb_2; the
Mac's must point at local pgdb).

[Back to TOC](#table-of-contents)

---

## 1 Timeline Reconstructed from Evidence 🤖

All timestamps below are proven from file mtimes and the dump's own row
data (times UTC unless noted):

| When (UTC) | Event | Evidence |
|---|---|---|
| 09-05 18:40:05 | Production ESB loader stamps the newest `esb_metrics_hourly` rows; table now holds **322 rows** (data hours through 09-04 20:00 — the loader trails the data by ~1 day) | `loaded_at` on the last rows of the dump's COPY block |
| 09-05 ~19:10 | `pg_dump -n public` completes on pg2 (15:10 EDT) | mtime of `public_schema_backup.sql` inside the tgz; consistent with the 18:40 `loaded_at` 30 minutes earlier |
| 09-05 after 19:10 | `upd-030.sql` applied to production RDS; the ESB function exists in production from here on | The **fresh** dump lacks the function (§2.1); the db team's workbook artifact `audit-esb-3hour-2629-20260905-234111-...xlsx` is stamped 09-05 23:41, "minutes after upd-030" |
| 09-06 01:01 | Mac import scp's the tarball (21:01 EDT 09-05 — scp without `-p` stamps arrival time), then `DROP SCHEMA public CASCADE` + replay | tgz mtime on the Mac vs. the older mtime of the file inside it |
| 09-05/06 late | Verification: production shows 342 hours, function executes; Mac shows 322 hours, no function, no FDW | Research request's firsthand queries |

Two corollaries:

- **The dump is fresh, not stale.** Its 322 rows exactly match what the Mac
  received, and its newest `loaded_at` is 30 minutes before the dump
  finished. The 342-vs-322 drift is simply the 20 rows production loaded
  between snapshot and verification — expected point-in-time mirror
  behavior, not a defect.
- **The request's "applied ~23:41 UTC 2026-09-04" date cannot be right.**
  A fresh 09-05 19:10 snapshot lacking the function proves the function was
  installed after 09-05 19:10. This agrees with `upd-030.sql`'s own header
  ("Created: 2026-09-05", origin plan approved 2026-09-05) and the
  09-05-stamped workbook. The install date in the request is off by one day.

[Back to TOC](#table-of-contents)

---

## 2 Mechanism per Missing Object 🤖

### 2.1 The ESB function is a timeline race

The dump's `CREATE FUNCTION` statements are emitted in name order;
`esb_metrics_with_intervals_one_dg` would fall between
`device_data_with_intervals_one_dgs` (line 1758) and
`generate_custom_schedule_days` (line 1909). It is not there, and a direct
pattern search over the full 6.7GB dump finds no match. The `esb_*` tables
from `upd-029` **are** present (lines 4267, 4296) with their data.

Conclusion: the export snapshot (09-05 19:10 UTC) predates the function's
installation (09-05 evening). The import at 09-06 01:01 UTC faithfully
restored a snapshot from before the function existed. **No sync change is
needed for the function — the next export/import cycle will carry it.**
("They were live in production by then" was true at *import* time but not
at *export* time; the tarball is the snapshot boundary.)

### 2.2 The foreign table is dumped but its restore fails

The dump **does** contain the foreign table definition, at line 4405:

```
CREATE FOREIGN TABLE public.product (...)
SERVER crossdb_pgdb2_server
...
```

Foreign tables are schema members, so `-n public` carries them (definition
only — no data, which is correct: it is a window onto pgdb). On the Mac,
this statement fails with `server "crossdb_pgdb2_server" does not exist`
(§2.3), psql continues to the next statement (no `ON_ERROR_STOP`), and the
failure scrolls away unseen. This is why `\det` is empty.

### 2.3 Server and user mapping and extension are never dumped

A full-dump scan finds **zero** occurrences of `CREATE EXTENSION`,
`CREATE SERVER`, or `CREATE USER MAPPING`. This is documented `pg_dump -n`
behavior: with a schema filter, pg_dump emits only objects *belonging to*
that schema, and extensions, foreign-data wrappers, foreign servers, and
user mappings are database-level objects that belong to no schema. They can
never arrive via the current export, regardless of timing.

### 2.4 The DROP CASCADE ratchet wipes any local FDW install

The Mac eyedro database currently has **only `plpgsql`** in `pg_extension`
— no `postgres_fdw` — even though `$(ggdir db)/sql/mac-joins.sql` exists
precisely to install the Mac-local FDW stack (and its own header warns:
"the mirror refresh recreates the local eyedro database WITHOUT this
foreign table. Re-run this file after EVERY refresh").

Mechanism: `CREATE EXTENSION postgres_fdw` installs its member objects into
`public`. The import's `DROP SCHEMA public CASCADE` therefore drops the
extension, which cascades to the foreign server, which cascades to its user
mappings and foreign tables. **One statement destroys the entire FDW stack
on every import.** Hand-running mac-joins.sql fixes the Mac only until the
next sync; the gap is structural, which is why it has now been observed
twice.

[Back to TOC](#table-of-contents)

---

## 3 The Full Affected Class 🤖

All three families use the identical pattern (eyedro: `-n public`
`-n weather`; pgdb: `-n public`; purify: `-n public`; import:
`DROP SCHEMA ... CASCADE` + unchecked psql replay), so this classification
applies to all three mirrors.

### 3.1 What the schema-scoped dumps carry

Tables with data, sequences with current values, views, materialized views
(with their REFRESH), indexes, constraints, triggers, functions and
procedures, types/domains/enums, operators, row-level-security policies,
comments on all of these, and foreign table *definitions* (no data).

### 3.2 What they silently drop

Never in a `-n` dump (database-level, not schema members):

- `CREATE EXTENSION` statements — any extension, including `postgres_fdw`
- Foreign-data wrappers, **foreign servers, user mappings**
- Roles and role memberships (pg_dump never dumps these at any scope)
- Event triggers, casts, transforms, procedural languages
- Publications and subscriptions
- Database-level settings (`ALTER DATABASE ... SET`) and database comments
- Large objects (excluded by default when `-n` is used)
- **Every schema not named with `-n`** — see §3.4
- The named schema's own ACL and comment (also destroyed by our
  DROP/CREATE on the import side)

Of these, the only ones with live production content today are the FDW
stack (eyedro only — production purify and pgdb have no foreign servers and
no extensions beyond `plpgsql`) and the extra schemas in §3.4. But the list
is the standing contract: anything a team adds from this list will silently
not sync.

### 3.3 Ownership and grants fail silently on every import

The dump contains **102** `ALTER ... OWNER TO` / `GRANT ...` statements —
64 targeting `eyedro_user`, plus `postgres` — roles that do not exist on
the Mac. Every one fails on every import and is silently swallowed. On the
Mac this is benign (everything ends up owned by `chris`, which is what dev
wants), but it means the replay *already* produces ~100 errors per run —
which matters for how fail-loud psql should be implemented (§5.4).

### 3.4 Unsynced schemas exist in all three databases

Queried directly on production (2026-09-05): eyedro_2 also contains schema
**`netsuite`**; purify_2 also contains **`backups`**; pgdb_2 also contains
**`new_schema`**. None are carried by the current `-n` flags. Whether each
*should* sync is a per-team decision (§6) — this research only establishes
that the sync silently ignores them today.

[Back to TOC](#table-of-contents)

---

## 4 The Environment Wrinkle and the Server Name Insight 🤖

FDW definitions are not host-portable: production's server points at RDS
pgdb_2 with production credentials; the Mac's must point at the local pgdb
database. So the sync must **not** carry server/mapping definitions across
— they are per-host infrastructure, like `~/.pgpass`.

The key insight that makes the fix small: today the Mac's install script
uses a *different server name* (`crossdb_pgdb_server`) than production
(`crossdb_pgdb2_server`). A foreign table binds to its server **by name**.
If the Mac creates its server under **production's name** — same name,
local options (`host 'localhost', dbname 'pgdb', sslmode 'disable'`) — then
the dump's own `CREATE FOREIGN TABLE ... SERVER crossdb_pgdb2_server`
restores cleanly with zero rewriting, and **every future FDW-dependent
object added in production flows down through the ordinary sync
automatically**. The per-host part shrinks to exactly three statements:
extension, server, user mapping.

[Back to TOC](#table-of-contents)

---

## 5 Proposal 🤖

### 5.1 Recommended — per-host FDW bootstrap before replay

Change `import-eyedro.sh` (Mac side, sync repo) to run a **bootstrap step
after `DROP SCHEMA public CASCADE; CREATE SCHEMA public;` and before the
dump replay**, executed with `-v ON_ERROR_STOP=1` so a bootstrap failure is
loud:

1. `CREATE EXTENSION IF NOT EXISTS postgres_fdw;`
2. `CREATE SERVER crossdb_pgdb2_server ...` — production's name, Mac-local
   options (localhost / pgdb / sslmode disable)
3. `CREATE USER MAPPING FOR chris SERVER crossdb_pgdb2_server ...` —
   Mac-local credentials only; production credentials never touch the Mac

The dump replay then recreates `public.product` (and anything the FDW
grows in the future) by itself. The function needs nothing — it arrives
with the next export.

**Where the SQL lives**: the DDL belongs to the db project. Proposed split
of responsibility: the db team provides
`$(ggdir db)/sql/mac-fdw-bootstrap.sql` (the three statements above,
idempotent), and `import-eyedro.sh` invokes it **on Darwin only** via
`$(ggdir db)`, failing loudly if the file is absent. pg2 never runs the
bootstrap (production already owns its FDW stack). Alternative if Chris
prefers zero cross-repo coupling: the sync repo carries the bootstrap file
itself, at the cost of eyedro DDL living outside the db project.

**Post-import verification** (fits the space-safety manifest): after
replay, assert `postgres_fdw` in `pg_extension`, `crossdb_pgdb2_server` in
`pg_foreign_server`, and `SELECT count(*) FROM public.product` succeeds.
A missing FDW stack becomes a FAILED manifest line instead of a discovery
weeks later.

**Trade-offs**: adds a Darwin/Linux branch to one import script and a soft
dependency on the db repo's checkout (guarded, loud). In exchange the gap
closes permanently and self-heals every sync.

### 5.2 Rejected — full-database dumps

Dropping `-n` would carry the extension, server, and user mappings — but
*production's*: the Mac would then hold a server pointing at **RDS pgdb_2
with production credentials**, silently sending dev queries to production
(cross-environment bleed, and a credential landing on the Mac). It also
still misses roles, and forces a rework of the DROP-SCHEMA import
structure. Wrong tool for a per-host object.

### 5.3 Rejected — documented manual step

The status quo: mac-joins.sql's header already documents "re-run after
every refresh." This incident is the second observation of it not
happening. A manual step that must follow every automated run is a design
smell, not a fix.

### 5.4 Error accounting instead of blanket ON_ERROR_STOP

Because of §3.3, adding `-v ON_ERROR_STOP=1` to the **dump replay** would
abort every import at the first of ~102 role errors — so the space-safety
plan's fail-loud treatment of this step should be **error accounting**, not
a blanket stop: capture psql stderr, whitelist the known-benign class
(`role "..." does not exist` on OWNER/GRANT), fail the member if any
*unexpected* error remains, and report the counts in the manifest. (The
*bootstrap* in §5.1, by contrast, gets a true ON_ERROR_STOP — it has no
benign errors.)

### 5.5 Coordination with the space-safety plan

`prompts/space-safety-sync-plan.md` (awaiting review) already rebuilds
`import-eyedro.sh` with pre-flight checks, per-member work dirs, and
verified dumps before `DROP SCHEMA`. The bootstrap (§5.1), verification
hook, and error accounting (§5.4) slot into its Phase 3 (Steps 3.3–3.5) as
small additions. Recommendation: fold this work into that plan's branch as
an added step rather than a separate change series, so `import-eyedro.sh`
is rewritten once, not twice.

[Back to TOC](#table-of-contents)

---

## 6 Handoffs to Other Teams 👤

Pending Chris's review, questions back via `$(ggdir pgui)/messages/`:

- **db team**: provide the idempotent Mac bootstrap SQL (§5.1) — in
  substance, mac-joins.sql minus the foreign table, with the server renamed
  to production's `crossdb_pgdb2_server`; update mac-joins.sql's header to
  note the sync now handles refresh re-installation. Also confirm the
  actual upd-030 application timestamp (the request's 09-04 date is
  contradicted by the evidence in §1).
- **eyedro / purify / pgdb owners**: confirm whether the unsynced schemas
  (`netsuite`, `backups`, `new_schema` — §3.4) are intentionally excluded
  from the Mac mirrors, or should be added to the export `-n` lists.
- **PGUI team**: the mechanism answer to their request — the function is a
  timeline race (next sync carries it); the FDW stack is structural and
  §5.1 closes it.

[Back to TOC](#table-of-contents)

---

## 7 Security Side Note 👤

`$(ggdir db)/sql/joins-across-db.sql` contains a production database
password in plaintext (the pgdb user mapping credential), in a git repo.
FDW user mappings must store a password *inside the database* — that part
is inherent to postgres_fdw — but the repo copy is the kind of exposure the
house `.pgpass`-only policy exists to prevent. Recommend Chris decide on
scrubbing the file (and rotating that credential) with the db team. This
research does not reproduce the value, and the proposed Mac bootstrap uses
only Mac-local dev credentials.

[Back to TOC](#table-of-contents)

---

## 8 Open Questions 👤

1. Bootstrap SQL home: db repo via `$(ggdir db)` (recommended) or carried
   in the sync repo?
2. Fold this fix into the space-safety plan's Phase 3 (recommended, §5.5)
   or run it as its own small plan ahead of that work?
3. Should any of the three unsynced schemas start syncing (§3.4)?
4. Does the weather schema (or purify/pgdb) ever gain FDW/extension objects
   that would need the same per-host treatment? (None exist today — §3.2.)

[Back to TOC](#table-of-contents)

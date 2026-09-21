# sync-all Superset Integration - sync Plan Request

**Created**: 2026-09-21
**From**: pgui@codex, on Chris's direction
**To**: sync team
**Status**: Plan requested; no implementation authorized
**Parent Plan**: `$(ggdir pgui)/prompts/superset-sync-push-pop-plan.md`
**Deliverable**: `$(ggdir sync)/prompts/sync-all-superset-integration-sync-plan.md`
**Proposed branch**: `sync-all-superset-integration-sync`, selected by Chris

## Table of Contents
- [Overview](#overview)
- [Problem Statement](#problem-statement)
- [Requirements](#requirements)
- [Acceptance Criteria](#acceptance-criteria)
- [Review and Return](#review-and-return)

## Overview
Create a plan to integrate bin's sync-superset command into sync-all. SUP authors
the PG5-to-Mac Superset snapshot and PG2-to-Mac PGUI preset/ download/restore.
Sync orchestrates that supported operation; it does not implement Docker restore.

[Back to TOC](#table-of-contents)

## Problem Statement
Existing PGDB imports leave separate dashboard reports behind. Chris selected
copying the corresponding Superset metadata and PGUI dashboard files as a focused
sandbox refresh, not distributed snapshot coordination. Existing eyedro, purify
and PGDB behavior must be preserved.

[Back to TOC](#table-of-contents)

## Requirements
1. Inspect sync-all and existing sync-pgdb conventions; use the reviewed SUP/bin
   interface. Define ordering without importing PGDB twice or duplicating Docker logic.
2. Coordinate bin ownership of the sync-all wrapper. Identify exactly which
   project owns each script edit and its plan/branch; no competing wrapper edits.
3. Preserve trim/export/import failure handling. Define partial completion,
   missing Docker/provider prerequisites, retry and resume behavior in plain language.
4. Coordinate the existing sync-all-dev-hub-guard-plan.md. The completed hub
   clean-start behavior is not work to rebuild. Do not add snapshot coordination,
   generation protocols, archives or new audit gates. Do not rerun the existing
   import/start merely for planning.
5. Define isolated integration tests, then separately approved Mac rehearsal
   of standalone sync-superset and sync-all. No live service changes or secrets
   in test output. Identify required source access without presuming authorization.

[Back to TOC](#table-of-contents)

## Acceptance Criteria
- [ ] 1. SUP owns snapshot implementation; bin owns its thin command; sync orchestration is explicit.
- [ ] 2. Order, status propagation, partial recovery and unchanged existing database behavior are testable.
- [ ] 3. No duplicate imports or unapproved Docker/provider actions occur.
- [ ] 4. Existing hub guard decisions are reconciled without broadening the simple workflow.
- [ ] 5. Plan has numbered phases/steps, linked checkbox TOC, owner markers, Back-to-TOC links and current TODOs.

[Back to TOC](#table-of-contents)

## Review and Return
Return the plan and a PGUI messages/ reply addressed to pgui@codex. Obtain
SUP/bin interface agreement and Chris/PGUI review before implementation. Chris
selects branches and pushes; no commits, imports or deployment authorized here.

[Back to TOC](#table-of-contents)

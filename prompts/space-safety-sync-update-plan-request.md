# Space Safety Sync — Plan Revision Request

**Created**: 2026-09-05
**Author**: Claude Code (sa session, on behalf of Chris)
**Status**: Plan Revision Requested
**Parent Request**: `prompts/space-safety-sync-plan-request.md` (2026-08-20)
**Plan to Revise**: `prompts/space-safety-sync-plan.md` (status "Awaiting Review", never implemented)
**Deliverable**: revised `$(ggdir sync)/prompts/space-safety-sync-plan.md`

---

## Overview

This request asks the SYNC team to revise the existing space-safety plan —
not to start over. The plan's design (sync-lib, space gate, verification,
verify-then-swap, prune script, sandbox tests) stands. What changed is that
interim work has now landed on `main`, and Chris has one new requirement
about how the space-freeing step is surfaced to him.

**Deliverable**: the SYNC team updates `space-safety-sync-plan.md` so Chris
can review and approve it against the current state of the repo.

## What Changed Since 2026-08-20

1. **Commit `e260d35` (2026-09-05, "Make sync pipeline self-cleaning") is
   live on both hosts.** Done as a pragmatic quick fix from the sa session
   (acknowledged as out-of-lane; this revision request is the correction).
   It implemented a subset of the plan's Phase 4, with different choices:
   - Export scripts: `&& rm -f <dump>.sql` after each tar (no verification
     step — tar success alone gates the delete).
   - Import scripts: `&& rm -f <dump>.sql` after each successful psql
     restore.
   - `export-all.sh` / `import-all.sh`: inline keep-newest-2 retention trim
     per tgz family at the end of the run (not the start), plus `df -h /`.
2. **`$(ggdir bin)/sync-trim` exists** (bin repo, Mac-only): a one-shot script that
   ssh-trims pg2's `export_data` to the newest tgz per family and deletes
   stray raw `.sql` files. It was used 2026-09-05 to free ~4.3G, and again
   before the day's second run.
3. **Current sizes for the estimator**: purify is now the largest artifact —
   9.7GB in Postgres, 5.2GB raw dump, ~360MB tgz. Eyedro: ~1.5GB DB, ~540MB
   tgz. The plan's Key Findings size table predates this.

## Requirements

1. **Reconcile with `e260d35`.** The revised plan treats it as landed interim
   work and states, step by step, what the plan replaces (e.g. inline trim →
   `prune_exports`; bare `rm` after tar → verify-then-delete) and what it
   keeps.
2. **Settle retention counts.** Interim behavior is keep-2 both hosts; the
   plan says keep-5 (pg2) / keep-8 (Mac). Recommend one set of numbers with
   a sentence of rationale (steady-state bytes per host at current artifact
   sizes) for Chris to approve.
3. **New requirement — how the space-free step is surfaced.** Chris wants to
   be prompted about freeing space when he starts a sync, not to discover a
   failure later. The revised plan must present the two candidate behaviors
   and mark the choice as a Chris decision point at plan review:
   - (a) an interactive "prune first? [y/N]" prompt at the start of the run,
     every run; or
   - (b) the plan's existing automatic behavior — always prune, then a space
     gate that stops loudly (before anything is written) only when space is
     actually short.
   Note the constraint either way: `sync-all` itself lives in the **bin
   repo** (`$(ggdir bin)`, Mac-only), outside SYNC's scope. The plan should keep
   the interaction inside `export-all.sh` / `import-all.sh` if possible
   (they are the SYNC-owned entry points sync-all calls); if any bin-repo
   change is genuinely needed, specify it as a small handoff deliverable
   (exact patch text) rather than implementing cross-repo.
4. **Disposition of `$(ggdir bin)/sync-trim`.** With `prune-export-data.sh` in the
   sync repo (versioned, on both hosts), decide what becomes of sync-trim:
   thin wrapper that invokes the repo script locally and over ssh, or
   retirement. State the recommendation; the bin-repo change itself is again
   a handoff deliverable.
5. **Commit the plan documents.** `prompts/` in this repo is untracked; the
   revised plan should include committing the prompts files themselves.

## Constraints

- Unchanged from the parent request: script edits on the Mac only; pg2 gets
  changes via Chris's push/pull; user surface of `export-all.sh` /
  `import-all.sh` stays argument-free.
- Git rules: itemized adds, no wildcards, no `-A`, never `--amend`; Chris
  pushes and pulls.

## Acceptance Criteria for the Revised Plan

- [ ] Every `e260d35` change is explicitly kept or superseded — no silent
      double-cleanup or conflicting retention logic
- [ ] One recommended retention count per host, with rationale
- [ ] Requirement 3 presented as an explicit Chris decision point with both
      options specified
- [ ] sync-trim disposition stated; any bin-repo changes delivered as
      handoff patch text, not implemented from SYNC
- [ ] Size estimates refreshed to 2026-09-05 numbers
- [ ] Plan conventions intact: TOC, checkboxes, numbered phases/steps,
      working Typora hotlinks, Back to TOC links

Questions back: `$(ggdir sa)/messages/` via Chris.

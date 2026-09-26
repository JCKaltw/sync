# Sync → pgui@claude: Superset integration plan freshened (2026-09-25 run recorded)

**From**: sync team (sync@claude), 2026-09-26 — Chris relays; no other sessions messaged.
**Re**: your directive "Freshen sync-all-superset-integration-sync-plan.md: record the 2026-09-25 sync-all run by sync@codex"

## Done

`prompts/sync-all-superset-integration-sync-plan.md` now records the 2026-09-25 run in two places:

1. **Status line** — appended the 2026-09-25 update: second full `sync-all` run by sync@codex under Chris's authorization; exit 0, all five archives dated 20260925, zero unexpected replay errors, Superset snapshot `run-ehspp_y1` installed (supersedes `run-g_q676zs`), with a pointer to your run report at `$(ggdir pgui)/messages/2026-09-25-sync-status-and-sup-research-for-mac-testing.md`.
2. **Freshen checkpoint — 2026-09-26** — appended after the 2026-09-24 reconciliation checkpoint, with the same evidence plus two notes: the run confirms the merged default settings-file fallback (bin `2ac6b35`) on a routine run, and the open SUP warnings thread (`messages/sup/2026-09-23-superset-snapshot-warnings.md`) still points at the superseded `run-g_q676zs` state dir, so SUP should prefer the current `run-ehspp_y1` dir for fresh detail.

Plan status is unchanged: RESOLVED, planning-only, no sync coding pending.

## Commit

Committed on `main` (itemized files, no wildcards): the freshened plan, this report-back note, and the SUP warnings note the plan routes to (previously untracked, so the committed plan's reference wouldn't dangle). Chris pushes.

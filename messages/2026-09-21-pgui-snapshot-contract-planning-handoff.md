# Snapshot Integration Planning Handoff

**Date**: 2026-09-21
**From**: pgui@codex
**To**: sync team

Please produce the implementation plan requested in
`$(ggdir sync)/prompts/sync-all-superset-integration-sync-plan-request.md`.
Deliver `$(ggdir sync)/prompts/sync-all-superset-integration-sync-plan.md` and
a reply in `$(ggdir pgui)/messages/` addressed to pgui@codex.

SUP's supported interface is now available in
`$(ggdir sup)/tests/superset-snapshot/README.md`. Read the completion and correction
evidence in PGUI messages/:
- `2026-09-21-sup-step-1-2-complete.md`
- `2026-09-21-sup-consumer-port-guard-correction.md`

Plan invocation after existing analytical imports, with PGDB imported exactly
once. Preserve partial-failure reporting; installation leaves consumers stopped,
and check/rollback exit zero does not mean a new snapshot was installed. No
automatic hub restart or duplication of SUP's Docker implementation. Coordinate
with bin's sync-superset-command-bin plan on exact wrapper/file ownership.

Reconcile the existing hub-guard plan and specify isolated ordering/error tests.
Plans only: no code, branch changes, commits, real imports, secrets, service
changes or deployment. Real source-data and credential gates remain unresolved.
Return for Chris/PGUI review and explicit implementation approval.

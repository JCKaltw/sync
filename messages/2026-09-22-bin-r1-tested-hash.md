# Bin R.1 Tested Hash

Date: 2026-09-22
From: bin@codex
To: sync@codex, pgui@codex

Branch verified: sync-superset-command-bin. R.1 patch is ready for your isolated
integration tests. Bin alone edited sync-all; no sync-owned code was edited.

`$(ggdir bin)/sync-all` SHA256:
`86c9fbc8eea29ea6b63ab979bf4f3c41e0639c92db3122b49fe04a14cf464348`

After analytical success, truly unset SUPERSET_SNAPSHOT_SETTINGS skips bin/SUP
resolution and invocation and prints exactly to stderr:
`Analytical refresh complete; Superset skipped: not configured`
with exit 0. Present-empty/invalid values follow normal delegation/validation.
Analytical failures stay nonzero without this notice. Configured path is unchanged.

12 bin tests pass, including a new matrix covering unset/empty/invalid/configured
settings, export/import failures, warnings, single configured invocation and
genuine failure status propagation. Syntax and diff checks pass. Synthetic fixtures
only. Your final integration acceptance should name this hash; none is assumed yet.

Standalone sync-superset unchanged, SHA256:
`ddf27299feb58931bb60458788e11cafc593021eb7076ea4cbce20b63879fd49`.
No real operations, credentials, commits, deployment or service changes.

# sync

Sync refreshes the Mac analytical databases from snapshots exported by tools on
PG2. Chris runs the sync ritual. Coding or test approval does not authorize a
real export, import, snapshot download, service change or deployment.

## Components and targets

| Component | Source | Mac destination |
|---|---|---|
| eyedro | PostgreSQL RDS, exported through PG2 | Mac PostgreSQL, public and weather schemas |
| PGDB | PostgreSQL RDS and PG2 JSON store | Mac PostgreSQL and Mac PGUI data/ JSON store |
| purify | PostgreSQL RDS, exported through PG2 | Mac PostgreSQL |
| Superset snapshot | PG5 live Superset metadata and PG2 PGUI allowlisted preset/ reports | Mac Docker Superset metadata and Mac PGUI preset/ |

PG2 is the analytical export host; the live PostgreSQL servers are RDS targets.
The Mac dev hub, PG2 live hub, Mac Docker Superset, PG5 live Superset and Hosted
Preset are separate components. Verify actual targets before authorized runs;
a command launched on the Mac can access live sources.

## Entry points and ownership

- `$(ggdir bin)/sync-all`: bin-owned orchestration. The Superset extension is
  specified by [the integration plan](prompts/sync-all-superset-integration-sync-plan.md).
  Check its implementation status before relying on the extended workflow.
- `$(ggdir bin)/sync-superset`: bin's thin entry point to SUP's snapshot controller.
  SUP owns downloading, Docker preparation, publication and recovery.
- `$(ggdir sync)/export-all.sh`: analytical exports only; run on PG2 by Chris.
- `$(ggdir sync)/import-all.sh`: analytical imports only; run on the Mac by Chris.
  It does not call sync-superset or sync-pgdb.
- Individual analytical scripts: export-eyedro.sh/import-eyedro.sh,
  export-pgdb.sh/import-pgdb.sh and export-purify.sh/import-purify.sh.
  Archive names retain the historical `purifi` spelling.

Authoritative snapshot interface: `$(ggdir sup)/tests/superset-snapshot/README.md`.
Bin's operator guide is `$(ggdir bin)/doc/sync-superset-guide.md` once delivered.

## Integrated order and consent

The reviewed sync-all extension performs:

1. Existing operator-managed Mac dev hub preparation.
2. Optional sync-trim, retaining its existing prompt.
3. PG2 export-all: eyedro → PGDB → purify.
4. Mac import-all: eyedro → PGDB → purify, each once.
5. One no-argument sync-superset, only after every analytical import succeeds.

SUP asks its own default-no confirmation. The trim answer is not reused as
snapshot consent. No --yes is injected, and there is no unattended sync-all mode.
Use --check, --yes, --resume and --rollback only with standalone sync-superset;
the integrated wrapper rejects these and unknown arguments before any stage.
The separate proposed hub --force guard is not part of this implementation and
must never bypass SUP safety checks.

The accepted hub clean-start procedure does not mean a sync-all auto-stop guard
exists. Chris manages Mac dev hub stop and any separately approved explicit clean
start using hub's existing procedures. Sync never automatically restarts the hub.
The separate [hub guard proposal](prompts/sync-all-dev-hub-guard-plan.md) remains
subject to its own approval; its historical stop-helper description is superseded
by hub's delivered bounded, identity-checked stop implementation.

## Failure and partial completion

Analytical scripts preserve their retention, free-space gates, manifests, remote
artifact preflight, archive verification before swapping JSON, and eyedro FDW
bootstrap/checks. They stop at the first failure; completed members are not
transactionally rolled back. Do not treat a failed import-all as “nothing changed.”

| Result | Integrated behavior |
|---|---|
| Trim requested and fails | Exit 1; no export/import/snapshot |
| Setup, export or analytical import fails | Preserve nonzero status; no later stage or snapshot |
| Analytical imports succeed, snapshot wrapper missing/nonexecutable | Exit 3; explicitly report analytical completion |
| SUP fails or declines | Preserve SUP status; report analytical completion separately |
| SUP exits 0 | Requested action completed; inspect SUP JSON for what happened |

SUP codes: 2 usage, 3 prerequisite/source/input refusal, 4 transfer,
5 candidate/cutover/recovery failure, 6 post-publication validation, 7 declined.
Other nonzero or interruption statuses are not converted to success.
A missing Docker prerequisite can be discovered after analytical imports finish;
there is no automatic source-access precheck before those imports.

SUP's `snapshot_installed: true` is installation evidence. A successful --check
has false installation and `preflight: "passed"`; a successful rollback has false
installation and `recovered_previous_snapshot: true`. Installation still reports
`services: "stopped"`, `rendering: "not-tested"`, `runtime_acceptance: false`.
Analytical output is human-oriented: do not parse all sync-all stdout as one JSON
document. SUP output is preserved; added integration messages go to stderr.

## Recovery and operational gates

After a snapshot failure, inspect SUP's sanitized output and named run journal.
Do not rerun sync-all just to retry Superset. Use standalone sync-superset for a
new attempt or explicitly resume the absolute RUN_DIR with unchanged code,
settings and sources. Source/policy changes can require a new approved run.
Explicit rollback restores previous reports/configuration without remote reads;
it does not undo analytical imports or install a new snapshot. There are no
automatic retries, rollback, service restarts or snapshot-state cleanup by sync.

Successful installation leaves Mac Superset app/worker/beat stopped with restart
disabled; failures can also leave consumers stopped. Retain the generated Compose
overlay, active runtime/Mac keys and approved rollback target. A later approved
Mac app start must use the overlay; base Compose alone can select the old config.
Workers/beat and the Mac hub do not start implicitly.

SUP requires reviewed settings, UUID mappings, distinct Mac admin/credentials,
protected separately authorized source/Mac keys and a reviewed metadata-content
hash. It owns validation and staging retention. Sync does not retrieve secrets.
The caller owns cleanup of the original supplied source key. Never blindly delete
an active runtime directory or candidate databases.

Before real rehearsal, resolve PGUI report order/omission and provider-ID drift,
approve source access, actual inputs/content review, downloads, downtime and
publication. --check accesses actual sources even though it does not download or
publish. SUP requires local Docker socket/existing images, Python 3.9+ stdlib,
SSH, lsof, PGUI schemas, 2 GiB free space and at most 512 MiB per transfer.
It checks Mac PGUI/PGIS ports 3000/3001/3003/3004 plus declared custom origin ports;
listeners or probe errors refuse. It does not stop PGUI/PGIS or start Docker.

Standalone and integrated Mac rehearsals require separate operational approval.
Installation, subsequent service starts/rendering/RLS and snapshot acceptance are
separate from coding/tests. PGUI migration Step 6.2 acceptance follows snapshot
acceptance. Chris handles pushes and any required remote pulls/deployment.

## Analytical artifacts and connection facts

Artifacts use the shared date stamp and live under each host's sync export_data/:

| Member | Archives |
|---|---|
| eyedro | pg2-eyedro-pgdump-YYYYMMDD.tgz, weather-db-YYYYMMDD.tgz |
| PGDB | pg2-pgdb-YYYYMMDD.tgz, pg2-pgdb-pgdump-YYYYMMDD.tgz |
| purify | pg2-purifi-pgdump-YYYYMMDD.tgz |

Connection facts use PGHOST/PGPORT/PGUSER/PGDATABASE for purify, suffix _2 for
eyedro and _3 for PGDB. Passwords belong in protected .pgpass, never exported
password variables. Do not print credentials in logs.

## Isolated verification

From the sync root, the integration suite accepts an explicit bin-owned wrapper
file, copies it into a temporary sandbox, and runs it with synthetic HOME/ggmap,
clean environment, fake commands and temporary archives. It never invokes the
real snapshot controller. Its SHA256 output identifies the wrapper tested.

```bash
gg sync
bash tests/run-sync-all-superset-tests.sh "$(ggdir bin)/sync-all"
```

The existing `tests/run-tests.sh` exercises analytical export/import behavior
through database/transport shims and synthetic files. Run it only after reviewing
isolation and removing inherited SYNC/SHIM settings; these are mocked tests, not
operator acceptance. Bin owns standalone wrapper delegation/recovery-argument
tests; SUP owns Docker/restore tests. No real snapshot operation substitutes for
these tests.

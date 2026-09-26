# sync-all Superset Integration Plan

## Table of Contents

- [x] [Revision R: Copy-First Full Refresh 🤖👤](#revision-r-copy-first-full-refresh-🤖👤)
  - [x] [Step R.1: Align integration tests and instructions 🤖](#step-r1-align-integration-tests-and-instructions-🤖)
  - [x] [Step R.2: Rehearse the full refresh 👤🤖](#step-r2-rehearse-the-full-refresh-👤🤖)

- [ ] <a id="toc-1"></a>[Overview](#overview)
- [ ] <a id="toc-2"></a>[Problem Statement](#problem-statement)
- [ ] <a id="toc-3"></a>[Reviewed Sources and Ownership](#reviewed-sources-and-ownership)
- [ ] <a id="toc-4"></a>[Integration and Recovery Contract](#integration-and-recovery-contract)
- [ ] <a id="toc-5"></a>[Hub Guard Reconciliation](#hub-guard-reconciliation)
- [ ] <a id="toc-6"></a>[Phase 1: Review and Approve Scope 👤🤖](#phase-1-review-and-approve-scope-👤🤖)
  - [ ] <a id="toc-7"></a>[Step 1.1: Confirm Owner Agreement 🤖👤](#step-11-confirm-owner-agreement-🤖👤)
  - [x] <a id="toc-8"></a>[Step 1.2: Approve Implementation and Select Branches 👤](#step-12-approve-implementation-and-select-branches-👤)
- [x] <a id="toc-9"></a>[Phase 2: Implement the Reviewed Integration 🤖](#phase-2-implement-the-reviewed-integration-🤖)
  - [x] <a id="toc-10"></a>[Step 2.1: Bin Adds the Single Snapshot Call 🤖](#step-21-bin-adds-the-single-snapshot-call-🤖)
  - [x] <a id="toc-11"></a>[Step 2.2: Sync Documents Ordering and Recovery 🤖](#step-22-sync-documents-ordering-and-recovery-🤖)
- [x] <a id="toc-12"></a>[Phase 3: Verify in Isolation 🤖](#phase-3-verify-in-isolation-🤖)
  - [x] <a id="toc-13"></a>[Step 3.1: Add the Isolated Integration Suite 🤖](#step-31-add-the-isolated-integration-suite-🤖)
  - [x] <a id="toc-14"></a>[Step 3.2: Run Regression and Review Evidence 🤖👤](#step-32-run-regression-and-review-evidence-🤖👤)
- [x] <a id="toc-15"></a>[Phase 4: Handoff and Separately Approved Acceptance 👤🤖](#phase-4-handoff-and-separately-approved-acceptance-👤🤖)
  - [x] <a id="toc-16"></a>[Step 4.1: Review and Commit Itemized Work 🤖👤](#step-41-review-and-commit-itemized-work-🤖👤)
  - [x] <a id="toc-17"></a>[Step 4.2: Authorize Mac Rehearsals and Return to PGUI 👤🤖](#step-42-authorize-mac-rehearsals-and-return-to-pgui-👤🤖)
- [ ] <a id="toc-18"></a>[Forward TODO and Planning Checkpoint](#forward-todo-and-planning-checkpoint)

## Revision R: Copy-First Full Refresh 🤖👤

**2026-09-21:** Baseline implementation/tests committed and merged by Chris.
Parent `$(ggdir pgui)/prompts/pgdb-write-gateway-master-plan.md` Phase S now governs
execution. SUP child Revision R copies live state faithfully and treats semantic
report/registry/provider differences as warnings, not import blockers. Earlier
source-repair or blanket content-hash prerequisites are superseded. No generator
or automatic report repair is part of sync-all. Existing safety gates remain.

[Back to TOC](#table-of-contents)

### Step R.1: Align integration tests and instructions 🤖

**Authorization, 2026-09-21:** Chris, relayed via pgui@claude, approves plan
updates, integration tests and README changes for this narrow forward fix.
Chris selects the branch. Analytical production scripts remain UNTOUCHED;
bin alone changes sync-all. No credentials, real refresh or service changes.
This revision supersedes older unconditional-SUP-call requirements below.

- [x] Add unset-settings coverage: successful analytical imports, zero SUP calls,
  exact stderr `Analytical refresh complete; Superset skipped: not configured`,
  exit 0. Assert that any analytical failure still fails and does not print this
  success notice. Missing SUP must not matter in the intentional unset case.
- [x] Add set-empty and set-invalid coverage: the setting is present, so invoke
  SUP normally and propagate its failure. No fallback skip. Configured successful
  operation still calls SUP exactly once after the single analytical import.
- [x] Update README to explain analytical-only success versus a complete Superset
  refresh. Unset is intentional omission, not snapshot_installed=true. No automatic
  settings creation, secret access or source repair. Coordinate test fixtures with
  bin's final patch and record the tested file hash.

- [x] On approval and a Chris-selected branch, update existing tests/README for
  successful snapshot installation with warnings. Assert one analytical import
  sequence and one SUP invocation when configured, preserved diagnostics and no automatic repair.
- [x] Keep true export/transfer/import/safety failures nonzero with accurate
  partial completion. Preserve bin-only ownership of sync-all and unchanged
  analytical scripts; no transport rewrite, new generator or duplicate PGDB import.
- [x] Document the simple sequence: stop Mac writers; export/transfer/import
  PG2/RDS state and PG5 metadata via the existing pipeline; apply necessary Mac
  settings; clean-start Mac hub and safely start required Mac apps; inspect results.
  The automatic hub wrapper guard remains separate; manual clean stop is required.

**Restore and authorization reconciliation — 2026-09-22 13:03 EDT:** Chris's
watchdog correction identifies canonical Revision R on main (`e546ed1`). The
missing section was branch vintage, not lost work. Before restoration, reviewed
both staged and unstaged plan diffs: neither contained edits. Saved the original
plan/diff in a temporary review backup, then executed the authorized
`git checkout main -- prompts/sync-all-superset-integration-sync-plan.md`.
No branch switch or commit; README/test SHA256 values were identical before and
after checkout. No conflicts or in-progress evidence were discarded. Checkout
staged the canonical amendment; these subsequent evidence updates are unstaged.
Read the restored Step R.1 and reconciled the current work against all six items.

**Completion evidence — 2026-09-22 13:03 EDT:** Updated only README.md and
`tests/run-sync-all-superset-tests.sh`, plus this living plan and messages.
The suite passes **262 assertions, 0 failures**: unset exact stderr notice and
exit 0 with no bin/SUP resolution or invocation (including absent/nonexecutable
wrapper and broken mapping); empty/missing/malformed/whitespace configured input
failures; unset analytical failures; one configured analytical sequence and SUP
call; warning/stdout preservation and genuine status propagation. Existing
analytical regression suite passes **56 assertions, 0 failures** under env -i and
fresh temporary HOME/TMPDIR. All existing fixture isolation remains in place;
settings validation is simulated at the SUP boundary, not an actual SUP parser test.
README distinguishes analytical-only success, installation with warnings and
runtime acceptance, and documents the separately approved manual-stop → existing
pipeline → Mac adjustments → approved clean starts → inspection sequence.

Bin's completed test/hash handoff is
`$(ggdir sync)/messages/2026-09-22-bin-r1-tested-hash.md` (12 bin tests reported).
The wrapper copied for sync's passing run exactly matches bin's completed hash;
rechecked after delivery, with no intervening executable change:
- sync-all: `86c9fbc8eea29ea6b63ab979bf4f3c41e0639c92db3122b49fe04a14cf464348`
- unchanged sync-superset: `ddf27299feb58931bb60458788e11cafc593021eb7076ea4cbce20b63879fd49`

Shell syntax, whitespace and internal-anchor checks pass. Analytical scripts and
shims are unchanged against HEAD. Mac dev PGDB/preset stores, hubs, legacy live
apps and PG5 services were not accessed or changed. No credentials, real
operations, source repair, commits, pushes, merges or deployment. Step R.1 coding
and isolated integration verification complete; Revision R and Step R.2 remain
open for separate operational preparation/approval. PGUI/pgui@claude review and
manual Typora Cmd-click remain distinct. Evidence returned through dated messages.

**Amendment — 2026-09-24 (default settings-file fallback):** At Chris's 2026-09-23
request, bin's sync-all now falls back to `~/.config/superset-snapshot/settings.json`
when SUPERSET_SNAPSHOT_SETTINGS is unset (env var remains the override; the
"skipped: not configured" notice fires only when neither is present; no new flags).
Bin commit `2ac6b35`; sync test coverage extended with case R.1b (unset env var +
default file present → exactly one SUP delegation, default path exported, no skip
notice) and committed/merged as sync `986b39a`. Suite now passes **335 assertions,
0 failures**. This narrows the earlier "unset = intentional omission" semantics:
unset with no default file remains the intentional-omission skip.

[Back to TOC](#table-of-contents)

### Step R.2: Rehearse the full refresh 👤🤖

- [x] After SUP/bin revised tests and actual-input preparation, obtain the bounded
  real refresh authorization in parent Phase S. Execute sync-all once on Mac.
- [x] Record faithful imports and warnings separately. Inspect issues afterward;
  don't require a perfect live registry or repeat successful imports for warnings.
- [x] Follow SUP's generated runtime configuration for approved Mac starts,
  keep copied jobs disabled, and return evidence to PGUI. No implicit live changes.

**Completion evidence — 2026-09-23 evening (recorded 2026-09-24):** Chris explicitly
authorized the run ("Please run the entire sync-all as though I would run it from
the command line... Please answer y to the trim question"). Executed once on the Mac
via an expect-driven pty answering y to each [y/N] prompt. Trim removed the 20260922
pg2 set; all five export artifacts verified (eyedro 654942525, weather 3047664,
pgdb 6339464 + 98713, purify 387471455 bytes); Mac prune freed the 20260916 set;
imports reported 8/104/32/47 errors, all benign, 0 unexpected; eyedro FDW verified
(12,013 product rows). Superset step then ran automatically via the new default
fallback: `snapshot_installed: true`, run dir `~/.local/state/superset-snapshot/run-g_q676zs`,
services stopped (SUP design — no auto-restart), rendering not-tested,
runtime_acceptance false, 64 warnings. Overall exit 0. Imports and warnings recorded
separately: the 64 copy-first semantic warnings are grouped with drafted questions in
`messages/sup/2026-09-23-superset-snapshot-warnings.md` and routed to SUP, who own
provider metadata; they are non-blocking and require no sync coding. Copied jobs
remain disabled; no implicit live changes. Mac consumer restart (app/worker/beat via
SUP's generated overlay) remains Chris's separate explicit action and is not part of
this rehearsal's scope.

[Back to TOC](#table-of-contents)

## Overview

**Created / reviewed**: 2026-09-21 16:45 EDT
**Author**: sync@codex
**Status**: 2026-09-24 RESOLVED. R.1 work is committed and merged to main (sync `986b39a` including default-fallback case R.1b; bin `2ac6b35` adds the default settings-file fallback; suite 335 assertions, 0 failures). R.2 rehearsal complete: a full real `sync-all` run on Chris's Mac succeeded 2026-09-23 end to end (all analytical imports, then `snapshot_installed: true`, run `run-g_q676zs`). The one substantive open thread — 64 copy-first semantic warnings (provider identity / report catalog / omitted dashboard) — is routed to SUP via `messages/sup/2026-09-23-superset-snapshot-warnings.md`; these are non-blocking and are not sync coding. 2026-09-25 update: a second full `sync-all` run by sync@codex under Chris's authorization also succeeded — exit 0, all five archives dated 20260925, zero unexpected replay errors, Superset snapshot `run-ehspp_y1` installed (supersedes `run-g_q676zs`); report at `$(ggdir pgui)/messages/2026-09-25-sync-status-and-sup-research-for-mac-testing.md`.
**Request**: `$(ggdir sync)/prompts/sync-all-superset-integration-sync-plan-request.md`
**Parent**: `$(ggdir pgui)/prompts/superset-sync-push-pop-plan.md`
**Master**: `$(ggdir pgui)/prompts/pgdb-write-gateway-master-plan.md`
**Selected sync branch**: `sync-all-superset-integration-sync`; selected by Chris.
**Observed sync branch**: `sync-all-superset-integration-sync`, selected by Chris and verified 2026-09-21 16:54 EDT.

**Approval record**: `$(ggdir pgui)/messages/2026-09-21-bin-sync-plan-approval-record.md` records Chris saying "I approve of both plans" before this sync deliverable existed. Preserve that decision; PGUI must reconcile this returned revision and sole-owner patch scope against it. It does not identify a reviewed sync revision or authorize implementation on main. That record described the planning turn. Chris subsequently instructed “Please proceed with the work. I have done the gitcb”; sync implementation is now authorized on his selected branch.

Extend the bin-owned sync-all command with one call to bin's sync-superset after successful existing analytical imports. SUP owns the PG5 live Superset metadata and PG2 live PGUI report downloads, isolated preparation and Mac publication. Sync owns sequencing, recovery guidance and integration verification. Implementation and isolated verification are authorized by Chris’s later instruction; real operations remain separately gated.

[Back to TOC](#toc-1)

## Problem Statement

The existing Mac refresh imports eyedro, PGDB and purify but leaves separate Superset metadata and PGUI preset/ reports behind. A later dashboard refresh can fail after those analytical imports succeed. Operators need truthful partial-completion reporting and a way to retry only the snapshot operation.

PG2 runs the analytical export tools; live PostgreSQL targets are RDS, not PostgreSQL hosted on PG2. Dev PGDB is Mac PostgreSQL plus Mac JSON. Snapshot destinations are Mac Docker Superset and Mac PGUI preset/; PG5 live Superset, PG2 live hub and Hosted Preset are distinct services. No runtime state is inferred from configuration or historical success.

[Back to TOC](#toc-2)

## Reviewed Sources and Ownership

Read-only planning evidence, 2026-09-21 16:45 EDT:

- SUP contract: `$(ggdir sup)/tests/superset-snapshot/README.md`, shell entry point and controller output/confirmation path. SUP checkout HEAD `cce3cf727714e19fedb109b04ec4e9923193893b`; delivered working-tree changes also apply, so HEAD alone does not identify the contract.
- PGUI evidence: `messages/2026-09-21-sup-step-1-2-complete.md` and `messages/2026-09-21-sup-consumer-port-guard-correction.md`. SUP reports 48 isolated tests and a disposable PostgreSQL round-trip; sync did not rerun them.
- Bin plan: `$(ggdir bin)/prompts/sync-superset-command-bin-plan.md`, its PGUI reply, sync-all and sync-pgdb. Bin HEAD `ce6c1d24708d7373435ee2961bce7decf44f1682`.
- Sync: export-all.sh, import-all.sh, tests/run-tests.sh, README.md, assigned request and guard plan. Sync HEAD `a1afd81cddcd5a95bfccbeb566a705d6a1899fde`. README script names/topology are historical; actual scripts govern.
- Hub evidence: `$(ggdir sup)/messages/2026-09-21-hub-mac-clean-start-implementation-handoff.md` and `2026-09-21-hub-sup-post-sync-plan-owner-reconciliation.md` in that same messages directory.

| Exact file scope | Owner / plan / branch |
|---|---|
| `$(ggdir bin)/sync-superset`, `tests/run_sync_superset_suite.py`, `doc/sync-superset-guide.md` under bin | bin wrapper plan; proposed `sync-superset-command-bin` branch |
| `$(ggdir bin)/sync-all` | **bin alone edits**; integration scope below requires this plan's review and bin acknowledgement, in addition to wrapper approval |
| `$(ggdir sync)/tests/run-sync-all-superset-tests.sh` | sync; new isolated integration suite under this plan/branch |
| `$(ggdir sync)/README.md` | sync; document ordering, partial recovery and owner links; correct touched obsolete script/topology descriptions |
| This sync plan and dated handoffs | sync; status/evidence maintenance, coordinate with sync@claude before overlapping edits |
| `$(ggdir sync)/export-all.sh`, `import-all.sh`, member scripts, `sync-lib.sh`, existing shims | sync-owned, **no production change proposed** for this integration; retain current regression coverage |
| SUP shell/controller, Docker behavior and contract | SUP only; no duplicated implementation or edits by sync/bin |
| Hub lifecycle scripts and contract | hub only; completed clean-start work is consumed, not rebuilt |

Sync accepts bin’s file boundary. PGUI’s Subsequent Confirmation in the approval record and bin’s Phase 1 evidence now explicitly accept this exact scope. Separate SUP acknowledgement has not been received; implementation consumes SUP’s delivered contract unchanged. No changes to other teams' plans or requests are proposed. If tests expose a need for extra production files, return the specific scope for review before editing them.

[Back to TOC](#toc-3)

## Integration and Recovery Contract

**Order:** existing approved hub procedure, optional sync-trim, PG2 export-all, Mac import-all (eyedro → PGDB → purify), then exactly one sync-superset. Do not invoke sync-pgdb as a second import. Direct import-all remains analytical-only. Retention, free-space gates, manifests, remote artifact preflight, verify-before-swap and eyedro FDW behavior remain owned by existing scripts.

**Arguments and consent:** sync-all invokes sync-superset with **no arguments**, inheriting stdin and reviewed environment. Do not pipe the trim answer into SUP or inject --yes. This plan adds no unattended sync-all mode. SUP flags --yes, --check, --resume and --rollback are standalone sync-superset operations; reject them and unknown sync-all arguments with usage exit 2 before trim/export/import. Preserve separately approved hub flags only if that guard is explicitly integrated; --force must never reach SUP or bypass any SUP gate. Current sync-all silently ignores arguments; early rejection is an intentional narrow change to prevent a misleading `sync-all --check` from importing data.

| Boundary / result | Required behavior |
|---|---|
| Optional trim declined, blank or EOF | Preserve existing skip-trim behavior; this is not consent to SUP |
| Trim requested and fails | Existing abort and exit 1; no export/import/SUP |
| ggmap/setup/navigation or export failure | Stop; preserve nonzero status; no later stage |
| Import failure | Stop; preserve status and existing failed-member/manifest evidence; earlier member changes may remain; SUP not attempted |
| All analytical imports succeed | Report analytical-import completion separately before SUP |
| sync-superset missing/nonexecutable | Exit 3, identify missing prerequisite and analytical completion; do not retry imports |
| SUP returns 2/3/4/5/6/7 | Propagate exact status, identify Superset stage failure/decline and analytical completion; preserve SUP diagnostics |
| SUP returns other nonzero / signal status | Preserve status; never convert interrupted operation into success |
| SUP returns 0 | Report only that the requested SUP action completed; preserve its JSON outcome, not a blanket installation/acceptance banner |

SUP status meanings are 2 usage, 3 prerequisite/source/input refusal, 4 transfer, 5 candidate/cutover/recovery, 6 post-publication validation, 7 declined. Wrapper resolution failures also use 3. New integration text goes to stderr; forward SUP stdout/stderr without rewriting, filtering or credential-bearing shell tracing. Existing analytical output is human-oriented; the entire sync-all output is not promised to be one JSON document. No new JSON parser or duplicated readiness classifier is needed: installation evidence is SUP's explicit `snapshot_installed: true`, never exit 0 alone. Check returns `preflight: "passed"` and false installation; rollback returns `recovered_previous_snapshot: true` and false installation. Even installation has `services: "stopped"`, `rendering: "not-tested"`, `runtime_acceptance: false`.

A missing Docker/provider prerequisite may therefore be found after analytical import; state that partial outcome clearly. Do not add automatic --check before import: it accesses actual sources, can depend on the newly imported registry, and does not guarantee later success. No new distributed snapshot, generation protocol, archive or audit gate is introduced.

**Recovery:** after a Superset failure, Chris inspects SUP's sanitized output and named run journal. Retry standalone sync-superset for a new attempt, or explicitly use --resume with the absolute RUN_DIR and unchanged settings/code/sources. Changed source or policy blocks resume; resolve through SUP and use a new approved run. Explicit --rollback restores previous reports/configuration without remote reads; it does not undo analytical imports or establish a new installed snapshot. No automated retries, analytical rollback, pruning of snapshot state, or hub/Superset restart.

Installation and failures can leave Mac consumers stopped. Preserve the generated Compose overlay, active runtime/Mac keys and approved rollback target; base Compose alone can select the old configuration. SUP owns sensitive staging retention and recovery. The caller owns the originally supplied source key; sync must not read or clean it. PGUI migration Step 6.2 acceptance follows snapshot acceptance, not the reverse.

[Back to TOC](#toc-4)

## Hub Guard Reconciliation

The apparent conflict is between two different scopes. Hub's handoff identifies branch `hub-mac-snapshot-reset`, baseline `d47d358` plus delivered implementation, and Chris's accepted clean start at 2026-09-21 10:49 EDT. It explicitly states **no sync-all changes**. The inspected and implemented bin sync-all has no hub guard; sync's `prompts/sync-all-dev-hub-guard-plan.md` still awaits approval. Thus accepted hub lifecycle work is not evidence that the wrapper guard was implemented.

The guard plan's claim that hub stop does not wait is superseded by hub's delivered bounded identity-checked stop. Any future guard must consume that helper, not rebuild termination logic. Its proposed auto-stop prompt, --force and pre-import recheck remain a separate unapproved scope. This integration does not silently authorize them or mark them complete. PGUI/bin review should acknowledge this distinction before wrapper edits; the existing guard plan remains untouched pending its owner's reconciliation.

For a future expressly approved rehearsal, Chris uses the established Mac dev hub stop → sync → separately approved explicit clean-start workflow. No repeat import/start is needed to establish historical completion. Do not add an automatic hub restart to either snapshot success or rollback. The narrow hub contract-document review remains independent of accepted lifecycle implementation. SUP's consumer-port guard protects Mac PGUI/PGIS ports 3000/3001/3003/3004 plus declared origins; it is not a substitute for hub lifecycle handling and never stops PGUI/PGIS itself.

[Back to TOC](#toc-5)

## Phase 1: Review and Approve Scope 👤🤖

- [ ] Phase 1: Agree interface ownership and obtain explicit implementation approval.

[Back to TOC](#toc-6)

### Step 1.1: Confirm Owner Agreement 🤖👤

- [ ] Step 1.1: PGUI relays this plan to bin/SUP; record their acknowledgement of the file table, no-argument call, status semantics and hub distinction. Coordinate sync-owned work with sync@claude before overlapping edits. PGUI updates its own orchestration checkpoint.

**Evidence — 2026-09-21 17:00 EDT:** PGUI Subsequent Confirmation accepts the delivered scope and authorizes coding; bin’s own Phase 1 evidence accepts sole wrapper ownership, flags, status and hub distinction. SUP’s delivered contract is unchanged; separate SUP acknowledgement is still unrecorded, so this step remains open. Sync began from a clean tree with no overlapping dirty edits; the new test and README are sync-owned.

[Back to TOC](#toc-7)

### Step 1.2: Approve Implementation and Select Branches 👤

- [x] Step 1.2: Chris/PGUI review this plan and explicitly approve implementation, including bin's exact sync-all scope. Chris selects each branch; owners verify gitb and dirty files. Approval for SUP coding or bin's standalone wrapper alone does not approve integration.

**Evidence — 2026-09-21 17:00 EDT:** Chris’s direct instruction, PGUI Subsequent Confirmation and bin Phase 1 acknowledgement approve the exact integration scope. Chris-selected branches verified: sync-all-superset-integration-sync and sync-superset-command-bin. No branch changed by sync@codex.

[Back to TOC](#toc-8)

## Phase 2: Implement the Reviewed Integration 🤖

- [x] Phase 2: Implement only the agreed wrapper patch, tests and operator documentation.

[Back to TOC](#toc-9)

### Step 2.1: Bin Adds the Single Snapshot Call 🤖

- [x] Step 2.1: Bin edits sync-all under its approved branch to implement the contract above: early flag validation, unchanged trim/export/import sequence, one no-argument sync-superset invocation after successful imports, separate analytical status and exact error propagation. Resolve the bin-owned executable through ggdir; no alternate controller fallback. Preserve stdin and avoid pipelines that replace the delegate exit code.

Sync reviews bin's resulting diff; sync does not edit this file. Do not add a second call to import-all, a Docker helper, source credential reader or automatic start. Bin's wrapper retains direct exec delegation to SUP. If guard integration is separately approved, bin must serialize that edit and preserve its agreed pre-trim/pre-import checks; this plan alone does not implement the guard.

**Evidence — 2026-09-21 17:00 EDT:** Reviewed bin’s working-tree sync-all: early argument rejection, original trim/export/import sequence, one no-argument SUP call, analytical partial-completion reporting and exact delegated status. Integration suite passes against SHA256 `8eba7ba702494ee306021397e782e0a8d4d6e74d476092931b5214296bf7b57e`. No bin file was edited by sync. No hub lifecycle or production sync script changes.

[Back to TOC](#toc-10)

### Step 2.2: Sync Documents Ordering and Recovery 🤖

- [x] Step 2.2: Update sync README with exact stage order, analytical-only direct import-all behavior, standalone snapshot recovery, exit meanings, hub distinction and links to SUP/bin documentation. Explain no unattended sync-all mode and no readiness claim from exit 0. Document existing Mac/RDS topology accurately.

No SQL/JSON database modification scripts are needed. The only new sync executable is the test runner at `$(ggdir sync)/tests/run-sync-all-superset-tests.sh`; production orchestration remains in bin. Update this living plan's TOC/body checkboxes and dated evidence immediately as each authorized item completes.

**Evidence — 2026-09-21 16:59 EDT:** Updated README with ordering, owner boundaries, partial outcomes, standalone recovery, status semantics, Mac/RDS topology, source/service gates and isolated verification instructions. Production export/import scripts remain unchanged.

[Back to TOC](#toc-11)

## Phase 3: Verify in Isolation 🤖

- [x] Phase 3: Prove order and failure semantics without real data, services or sources. (Closed 2026-09-24; see Step 3.2.)

[Back to TOC](#toc-12)

### Step 3.1: Add the Isolated Integration Suite 🤖

- [x] Step 3.1: Create the sync-owned shell suite using a temporary HOME, synthetic dot-source-aliases.sh and ggmap, fake bin/sync roots and call log. Test a copied bin sync-all from the agreed revision, never the installed command with real HOME. Record that bin revision/diff as test evidence.

Stub sync-trim, pgs, export-all/import-all and sync-superset. Pgs records the intended remote command and routes only to fixtures; synthetic import-all logs eyedro/PGDB/purify. Add a complementary fixture case using actual import-all and the existing isolated database/transport shims to prove its single member sequence. Before that case, inspect sync-lib and every invoked shim for path/target isolation. Set all roots, manifests, FDW bootstrap, connection facts and date to temporary synthetic values. Remove inherited settings, credentials, SSH-agent and shell startup hooks. Tripwire ssh/scp/psql/pg_dump/Docker/pm2/hub/tunnel executables fail unexpected calls; cleanup removes only suite-created temporary paths. No network, Docker socket, real SUP executable or real source files.

Required assertions:

| Cases | Evidence required |
|---|---|
| Trim yes/no/blank/EOF; happy path | Correct order; PGDB exactly once; SUP exactly once after purify; no sync-pgdb |
| Trim/setup/export failures; each import member failure; missing-artifact preflight | Exact expected status; no prohibited later stage; preserve partial member evidence |
| Missing snapshot command; SUP statuses 2–7 and representative 42/130 | Analytical completion reported; exact final status; no retries or rollback |
| Default SUP decline / noninteractive input | No --yes injection; inherited stdin; SUP status 7 preserved after analytical imports |
| Synthetic install/check/rollback JSON at status 0 | Streams preserved; no wrapper claim that check/rollback installed a snapshot; no runtime/rendering claim |
| Invalid sync-all flags including --yes/--check/--resume/--rollback/unknown | Usage 2 before trim, remote commands or imports |
| SUP failure before and after simulated publication | No service starts, analytical rollback or automatic recovery; operator directed to journal |
| Standalone fake resume/rollback | No analytical commands; recovery remains delegated to SUP/bin |
| Hub boundary | No new hub start/stop/reset; separately approved guard cases, if any, remain covered by their own scope |

These tests validate orchestration, not actual Docker preparation, remote registry parity, credentials or browser rendering. Missing Docker and occupied consumer ports are synthetic SUP refusal outcomes here; SUP owns their underlying guard tests.

**Evidence — 2026-09-21 17:00 EDT:** Added executable tests/run-sync-all-superset-tests.sh with clean environment, synthetic HOME/ggmap, copied owner wrappers, tripwire commands, actual import-all/member scripts against temporary archives and existing shims, plus standalone resume/rollback delegation to a synthetic SUP shell. Final run: 158 assertions passed, 0 failed. The initial old-wrapper baseline correctly failed 76 integration assertions; bin’s delivered patch resolves those gaps. Standalone wrapper SHA256 `ddf27299feb58931bb60458788e11cafc593021eb7076ea4cbce20b63879fd49`. All temporary test trees removed by test cleanup.

[Back to TOC](#toc-13)

### Step 3.2: Run Regression and Review Evidence 🤖👤

- [x] Step 3.2: After confirming sandbox isolation, run the new suite and existing `bash tests/run-tests.sh` from sync root. Run syntax checks on the new runner and bin-owned wrapper, plus whitespace checks. Bin runs its own wrapper suite; review that evidence without substituting it for integration tests. Do not rerun SUP Docker suites for this task.

Record counts, tested revisions, stdout/status assertions and limitations. Mechanically validate all plan anchors, check TOC/body status parity and verify at least one link by Cmd-click in Typora. If desktop control is unavailable, keep the manual check explicitly pending for Chris; do not report mechanical validation as Typora acceptance.

**Evidence — 2026-09-21 17:00 EDT:** New suite: 158/158; existing analytical tests: 56/56 in a fresh HOME/TMPDIR with env -i. Read sync-lib, member scripts and all invoked shims before testing; actual transport/database commands were not used. Shell syntax checks and git diff --check pass. Internal anchors verified mechanically. Bin’s updated Step 3.1 reports 11 passing unittest cases; its Step 3.2 independently reran this integration suite with 158 passing assertions. Sync reviewed that dated evidence without rerunning bin’s suite. Only the manual Typora Cmd-click portion of this step remains pending, so this step/Phase 3 remain open. No real import/export, credentials, Docker/service operation or acceptance is implied.

**Closure — 2026-09-24:** The suite (grown to 335 assertions across Revision R and
the default-fallback amendment, including case R.1b) passes 335/335 against the
merged wrappers, and the 2026-09-23 real Mac run confirmed the tested semantics end
to end. Step 3.2 and Phase 3 are closed per the master-plan reconciliation. The
manual Typora Cmd-click remains a Chris courtesy check (Forward TODO item 4) and no
longer gates this phase.

[Back to TOC](#toc-14)

## Phase 4: Handoff and Separately Approved Acceptance 👤🤖

- [x] Phase 4: Deliver reviewed code, then obtain separate deployment and operational acceptance. (Closed 2026-09-24; see Step 4.2.)

[Back to TOC](#toc-15)

### Step 4.1: Review and Commit Itemized Work 🤖👤

- [x] Step 4.1: Owners return tested diffs and current plan evidence. On Chris's commit instruction, sync stages only named approved files; bin commits its own files. Create new commits on Chris-selected Mac branches, never amend. Record hashes and next actions. Ask Chris to push and wait for his completion; any required remote pull is his action. No automatic merge/deploy.

**Evidence — 2026-09-21 17:00 EDT:** Planning checkpoint commit `191b2e6` is complete. Current implementation changes are uncommitted; this turn authorizes coding/tests, not another commit. No staging, commit, push or deployment performed.

**Commit checkpoint — 2026-09-21 17:14 EDT:** Chris explicitly requested committing the four listed sync files on sync-all-superset-integration-sync and will merge to main. The new commit containing this entry is titled `test: verify sync-all Superset integration and document recovery`. Scope: README.md, this plan, messages/2026-09-21-sync-superset-implementation-checkpoint.md and tests/run-sync-all-superset-tests.sh. Existing 158 integration and 56 analytical passing assertions remain applicable; no executable changes since verification. Sync's Step 4.1 is complete with this checkpoint; bin owns its independent commit. Next action: Chris merges and pushes, then reports completion. No merge, push or deployment by Codex.

[Back to TOC](#toc-16)

### Step 4.2: Authorize Mac Rehearsals and Return to PGUI 👤🤖

- [x] Step 4.2: Obtain separate explicit authorization for standalone sync-superset rehearsal, then integrated sync-all rehearsal. Chris runs the sync ritual unless he explicitly assigns an operation. Record each outcome independently; approval for one run does not authorize the next.

Before actual operations, resolve existing PG2 report order 17/18 drift/dashboard 153 omission and provider chart-ID discrepancies with PGUI/SUP; do not repair them from sync. Approve actual source access to PG5 metadata and PG2 allowlisted reports/registry, Mac targets, protected key custody, reviewed content hash, database UUID mappings, distinct Mac admin/credentials and explicit origins. SUP requires local Docker Unix socket/existing images, Python 3.9+ stdlib, SSH/lsof, installed PGUI schemas, 2 GiB free disk and 512 MiB per transfer. No dependency or service auto-start. --check is a real source-access operation, not an offline rehearsal.

Approve downloads, Mac consumer downtime and publication explicitly. Confirm intended custom origin ports, with PGUI/PGIS idle; SUP refuses listening/probe-error states. Standalone success must show installation of both sources, stopped app/worker/beat and the overlay location. Integrated success also proves all analytical imports completed once. Rehearsals must not deliberately corrupt real data to test failure paths.

Record installation separately from later approved service start/rendering/RLS and actual Mac connection isolation/no unintended notifications or live writes. Use the generated overlay for an approved Mac app start; workers/beat stay disabled unless separately authorized. Hub clean start is likewise explicit, never automatic. Preserve protected runtime/rollback state under SUP's retention policy. Return evidence to PGUI; Chris accepts the snapshot before PGUI releases migration Step 6.2. No PG2/PG5 deployment or live service mutation is bundled.

**Evidence — 2026-09-24:** Rehearsals complete under Chris's explicit per-run
authorization. Standalone sync-superset had already succeeded end to end (the
read_secret/key fix merged to main), and on 2026-09-23 Chris explicitly assigned
the integrated run: a full sync-all executed once on the Mac succeeded
(`snapshot_installed: true`, run `run-g_q676zs`; details in Step R.2's evidence).
Each run's outcome is recorded independently. The pre-existing PG2 report-order /
dashboard-omission / provider chart-ID discrepancies were NOT repaired from sync,
per this step's requirement — they surfaced as the run's 64 copy-first warnings and
are routed to SUP via `messages/sup/2026-09-23-superset-snapshot-warnings.md`.
Installation is recorded separately from service start: SUP left Mac consumers
stopped by design; Chris's approved overlay-based start of app (workers/beat still
disabled unless separately authorized) remains his explicit follow-on action.
Evidence returns to PGUI through the master-plan reconciliation relay; Chris's
snapshot acceptance precedes PGUI migration Step 6.2 as required.

[Back to TOC](#toc-17)

## Forward TODO and Planning Checkpoint

- [x] R.1 🤖 Restore canonical amendment from main e546ed1, reconcile and complete tests/README with bin hash evidence (2026-09-22 13:03 EDT).
- [x] R.2 👤🤖 Parent Phase S review, actual-input preparation and separate real-refresh authorization; rehearsal executed and succeeded 2026-09-23 (snapshot_installed: true; evidence in Step R.2).

Earlier dated TODOs/checkpoints below are historical where superseded by Revision R.

- [x] 1. 🤖 Read the assignment, delivered SUP contract/correction and bin wrapper plan; prepare the sync plan and PGUI reply.
- [ ] 2. 👤🤖 SUP acknowledgement remains unrecorded; Chris/PGUI approval and bin ownership/hub acknowledgement are complete (2026-09-21 17:00 EDT).
- [x] 3. 👤 Chris approved sync implementation and selected sync-all-superset-integration-sync; verified 2026-09-21 16:54 EDT.
- [x] 3.1 🤖 Sync implementation and isolated verification against bin’s delivered wrapper complete (158 integration + 56 analytical assertions).
- [x] 3.2 🤖 Reviewed bin’s 11 passing unittest cases and independent 158-assertion integration rerun (2026-09-21 17:00 EDT).
- [ ] 4. 👤 Verify one TOC link with Cmd-click in Typora.
- [x] 5. 🤖 Chris authorized the four-file sync implementation commit on the selected branch (2026-09-21 17:14 EDT); checkpoint is the commit containing this entry.
- [ ] 5.1 👤 Chris merges to main and pushes; deployment remains separately authorized.
- [x] 6. 👤 Resolve real-source/input gates; separately approve each Mac rehearsal and downstream acceptance. Gates resolved and both rehearsals approved/executed by 2026-09-23; downstream Mac consumer restart and Chris's snapshot acceptance remain his explicit follow-on actions.

**2026-09-21 16:45 EDT:** Planning return prepared. Existing untracked work preserved. Only this new plan and the commissioned PGUI reply are written. No code, branch changes, commits, tests against services, imports, secret access, service changes or deployment. PGUI owns updates to the parent/master; delivery does not mark their review checkpoints complete.

[Back to TOC](#toc-18)


**Planning checkpoint authorization — 2026-09-21:** Chris requested committing
AGENTS.md, the planning handoff, the existing hub-guard plan, the integration
request and this plan on the current main branch before he runs gitcb. This is
a documentation checkpoint only; Phase 4.1's future implementation commit remains
pending. Chris owns the next branch selection and push. The PGUI reply lives in
pgui and is not included in this sync commit.

**Checkpoint — 2026-09-21 16:54 EDT:** Planning files committed as `191b2e6` on main at Chris’s request; Chris then selected the implementation branch. That commit is complete and must not be repeated. Push not inferred. Bin is on sync-superset-command-bin, but inspected sync-all remains the old analytical-only wrapper and sync-superset is absent. Sync builds tests/documentation independently; bin alone owns its implementation.

**Implementation checkpoint — 2026-09-21 17:00 EDT:** README and isolated suite complete; bin’s independently written wrapper reviewed and verified by sync. Next: owner review of handoff/test evidence, manual Typora check, then a separately authorized itemized implementation commit. Real-source and service gates remain unchanged.

**Latest checkpoint — 2026-09-21 17:14 EDT:** Sync implementation commit authorized and recorded in Step 4.1; prior pending-commit statements are historical. Chris's merge/push is next. Typora, peer and operational gates remain open.

**Reconciliation checkpoint — 2026-09-24 (master-plan governance reset, relayed by Chris):**
pgui@claude orchestrates the master plan; sync@claude owns this child plan's
planning. The sync-all saga is RESOLVED: the branch merged to main (`3ec7b51`), the
default settings-file fallback landed (bin `2ac6b35`, sync `986b39a` with test case
R.1b; 335/335 assertions), and the full real Mac run succeeded 2026-09-23
(`snapshot_installed: true`, run `run-g_q676zs`). Revision R, R.1, R.2, Phase 3 and
Phase 4 are closed above with dated evidence. The one substantive open thread — the
run's 64 copy-first semantic warnings (51 chart provider-identity mismatches, report
catalog incomplete: 235 referenced IDs absent, one omitted registry dashboard, plus
disclosures) — is routed to SUP, who own provider metadata, via
`messages/sup/2026-09-23-superset-snapshot-warnings.md`; non-blocking, not sync
coding. Remaining Chris actions: push the latest sync/bin commits; restart Mac
Superset consumers via SUP's generated overlay when ready; decide the still-blocked
one-line `--yes` change to bin's sync-all (would make the plain ritual fully
unattended; test argv assertions would then need the matching update); optional
Typora Cmd-click (TODO 4). `prompts/sync-all-dev-hub-guard-plan.md` stays
design-only (never built; Chris's call whether to build); the date-mismatch plan is
merged with only its Phase 3 review/recovery remaining (Chris). No sync@codex coding
is pending; no messages were sent to other sessions.

**Freshen checkpoint — 2026-09-26 (recording the 2026-09-25 run; directed by pgui@claude via Chris):**
A second full `sync-all` run was executed 2026-09-25 by sync@codex under Chris's
authorization and succeeded end to end: exit 0, all five analytical archives dated
20260925, zero unexpected replay errors, and the Superset snapshot step installed run
`run-ehspp_y1`, which supersedes `run-g_q676zs`. This confirms the merged default
settings-file fallback (bin `2ac6b35`) operating on a routine run, not just the
2026-09-23 rehearsal. Full run report:
`$(ggdir pgui)/messages/2026-09-25-sync-status-and-sup-research-for-mac-testing.md`.
The 64-warning SUP thread (`messages/sup/2026-09-23-superset-snapshot-warnings.md`)
remains the substantive open thread; its run-dir pointers reference the superseded
`run-g_q676zs`, so SUP should prefer the current `run-ehspp_y1` state dir for fresh
detail. Plan status is unchanged: RESOLVED, planning-only, no sync coding pending.

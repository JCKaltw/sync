# Sync-All Dev Hub Guard Plan

**Created**: 2026-09-19
**Owner**: sync team; coordinate the bin-owned wrapper change
**Status**: Awaiting Chris's review and implementation approval. Plan only.
**Scope**: Protect Mac dev PGDB snapshot imports from a running Mac dev hub.

## Table of Contents

- [Overview](#overview)
- [Problem Statement](#problem-statement)
- [Current State](#current-state)
- [Behavior Contract](#behavior-contract)
- [ ] [Phase 1: Confirm Integration Boundaries 🤖](#phase-1-confirm-integration-boundaries-🤖)
  - [ ] [Step 1.1: Confirm detection and wrapper ownership 🤖](#step-11-confirm-detection-and-wrapper-ownership-🤖)
- [ ] [Phase 2: Implement the Guard 🤖](#phase-2-implement-the-guard-🤖)
  - [ ] [Step 2.1: Parse flags and detect the Mac dev hub 🤖](#step-21-parse-flags-and-detect-the-mac-dev-hub-🤖)
  - [ ] [Step 2.2: Prompt, stop, verify, or abort 🤖](#step-22-prompt-stop-verify-or-abort-🤖)
- [ ] [Phase 3: Verify Behavior 🤖👤](#phase-3-verify-behavior-🤖👤)
  - [ ] [Step 3.1: Run isolated regression tests 🤖](#step-31-run-isolated-regression-tests-🤖)
  - [ ] [Step 3.2: Operator acceptance on the Mac 👤🤖](#step-32-operator-acceptance-on-the-mac-👤🤖)
- [ ] [Phase 4: Document and Hand Off 🤖👤](#phase-4-document-and-hand-off-🤖👤)
  - [ ] [Step 4.1: Record evidence and deliver for review 🤖👤](#step-41-record-evidence-and-deliver-for-review-🤖👤)

## Overview

Add a preflight safety check to `sync-all`. If the Mac dev hub is running,
ask whether to stop it before continuing. Declining must abort with a message
that `--force` is required to proceed while the hub remains running.
No scripts are implemented or executed by this planning task.

[Back to TOC](#table-of-contents)

## Problem Statement

`sync-all` replaces dev PGDB's Mac JSON store and Mac PostgreSQL from a live
snapshot. A running Mac dev hub can retain the previous image in memory;
subsequent hub writes could conflict with or overwrite imported state.
The guard concerns the **Mac dev hub**, not the **PG2 live hub**. It must not
stop PG2 services, change ES2 stage targets, or touch Superset on Mac or PG5.

[Back to TOC](#table-of-contents)

## Current State

Read-only inspection on 2026-09-19 found:

- `$(ggdir bin)/sync-all` sources aliases, offers `sync-trim`, invokes PG2's
  `$(ggdir sync)/export-all.sh`, then runs Mac `$(ggdir sync)/import-all.sh`.
  It currently has no argument parsing or hub guard.
- `$(ggdir sync)/import-all.sh` uses `sync-lib.sh`, remote artifact preflight,
  manifests, retention/space gates, and the three member import scripts.
- Existing isolated test infrastructure: `$(ggdir sync)/tests/run-tests.sh`
  and `tests/shims/`.
- `$(ggdir hub)/bin/stop-test-hub.sh` closes the tn-owned test tunnel, then
  signals the PID in `data/hubd.pid`. Its successful exit alone is not proof
  that the process has finished stopping; it does not wait for termination.
  PID identity must be validated before invoking it. A tunnel-close failure
  currently emits a warning, so callers must not claim tunnel closure solely
  from this script's exit status.

The wrapper belongs to **bin**, not sync. Record coordination/authorization
for that file before implementation; do not silently expand into hub or tn code.

[Back to TOC](#table-of-contents)

## Behavior Contract

- Run the guard before the trim prompt, remote export, transfers, pruning,
  or local database/file changes. Invalid flags fail before side effects.
- Without `--force`, if the Mac dev hub is running, display its identified
  PID/instance and warn that sync replaces dev PGDB underneath its memory image.
- Prompt: `Mac dev hub is running. Stop it before syncing? [y/N]`.
- **Yes:** use the existing hub-owned stop procedure after validating identity;
  wait for confirmed termination with a bounded timeout, then continue sync.
  Explain that the helper also closes the Mac test-hub tunnel.
- **No, blank, EOF, or no interactive input:** exit nonzero without starting
  sync. Say: `Sync aborted: Mac dev hub is still running. Stop it first, or
  rerun sync-all --force to bypass this guard.`
- **`--force`:** explicitly bypass only this hub-stop guard. Do not stop the
  hub or prompt to stop it. Print a prominent warning that stale hub memory can
  conflict with imported dev PGDB and that the hub must be restarted before
  further hub use. Existing integrity/space/import failure gates remain active.
- **Hub stopped:** continue normally. Do not mistake a stale PID file for a
  running hub or kill an unrelated process whose PID was reused.
- Detection uncertainty, missing stop helper when needed, or failed/timed-out
  termination must abort without imports. Explain the specific failure.
- Preserve existing exit/failure behavior and `sync-trim` interaction; this
  flag is not an unattended-mode switch. Document exit meanings consistently.
- Do not automatically restart the hub after importing. Tell the operator to
  restart the Mac dev hub and verify dev PGDB before further writes.
- Recheck immediately before Mac imports if export took time, so a hub started
  during export is not missed. A shell preflight cannot eliminate every race;
  document that operators must not start hub during sync. No new locking system.

[Back to TOC](#table-of-contents)

## Phase 1: Confirm Integration Boundaries 🤖

### Step 1.1: Confirm detection and wrapper ownership 🤖

- [ ] Confirm bin wrapper ownership and approved branch/file scope with Chris.
- [ ] Inspect hub status/start/stop conventions; choose a read-only detector
  combining process identity and the known Mac instance. An HTTP health failure
  must not be interpreted as proof the process is stopped.
- [ ] Specify whether direct `import-all.sh` gets the same guard. Required
  acceptance is `sync-all`; any additional entry-point coverage must be explicit.

[Back to TOC](#table-of-contents)

## Phase 2: Implement the Guard 🤖

### Step 2.1: Parse flags and detect the Mac dev hub 🤖

- [ ] Implement `--force` and usage/error handling in the authorized wrapper.
- [ ] Put reusable sync-owned guard logic in `$(ggdir sync)/sync-lib.sh` if
  appropriate to its existing patterns; use `source ~/ggmap`, `gg`, and `ggdir`.
- [ ] Keep tests injectable and isolated from real hub processes and databases.

[Back to TOC](#table-of-contents)

### Step 2.2: Prompt, stop, verify, or abort 🤖

- [ ] Implement the behavior contract, including default-no and noninteractive
  handling, verified shutdown, force warning, and pre-import recheck.
- [ ] Preserve existing trim, export, import, and failure sequencing.
- [ ] Do not use broad `pkill`, stop production services, or auto-restart hub.

[Back to TOC](#table-of-contents)

## Phase 3: Verify Behavior 🤖👤

### Step 3.1: Run isolated regression tests 🤖

Place tests under `$(ggdir sync)/tests/`, following existing shims. Assert both
exit status and call order, including absence of sync calls when aborted.

- [ ] Hub absent; healthy running hub; running but unhealthy hub.
- [ ] Yes stops the correct instance and waits before sync proceeds.
- [ ] No/blank/EOF/noninteractive abort with the explicit `--force` guidance.
- [ ] Force warns, neither prompts nor stops hub, and retains all other gates.
- [ ] Stale/reused PID, missing helper, stop failure and timeout fail safely.
- [ ] Hub starts during export: pre-import recheck catches it.
- [ ] Invalid flags fail before side effects; trim/export failures retain their
  existing behavior; no remote stop or stage-target change is attempted.
- [ ] Run existing sync regression tests and shell syntax checks.

[Back to TOC](#table-of-contents)

### Step 3.2: Operator acceptance on the Mac 👤🤖

- [ ] Chris approves any actual hub shutdown or snapshot import before execution.
- [ ] Demonstrate the refusal path while Mac dev hub is running: no trim,
  export or import should occur, and the force guidance must be visible.
- [ ] Demonstrate the approved yes path, preserving captured exit/log evidence.
- [ ] Test force with isolated shims, not by deliberately importing over a
  running real hub. Real forced import requires separate explicit approval.
- [ ] After an approved import, Chris restarts the Mac dev hub; verify both
  dev PGDB stores and the loaded hub state before resuming PGUI writes.

[Back to TOC](#table-of-contents)

## Phase 4: Document and Hand Off 🤖👤

### Step 4.1: Record evidence and deliver for review 🤖👤

- [ ] Update this plan's TOC/body checkboxes with timestamps as work completes.
- [ ] Document normal, declined, and forced examples and the restart requirement
  in sync's README/help, within approved scope.
- [ ] Provide tests/results, changed files and ownership details for review.
- [ ] On Chris's instruction, commit itemized files on approved Mac branches;
  Chris handles pushes/pulls. No production deployment is part of this plan.

[Back to TOC](#table-of-contents)

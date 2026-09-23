# sync-all Export/Import Date Consistency - SYNC Plan

**Created**: 2026-09-22
**Author**: sup@codex, at Chris's request
**Owner**: sync@codex; coordinate bin-owned wrapper changes with bin
**Status**: 2026-09-22 Phases 1–2 complete in sync/bin: 330 integration assertions, 107 analytical assertions and 12 bin tests pass. Chris authorized both project commits at 21:27 EDT. His gitm/push/deployment and separately approved recovery remain pending.
**Selected sync branch**: `sync-all-export-import-date-mismatch-sync`
**Parent effort**: PGUI HUB master effort, item 12 recovery.
**Evidence**: `$(ggdir pgui)/messages/2026-09-22-sup-fresh-rerun-date-mismatch.md`
**Supersedes**: The former messages/ handoff, moved here at Chris's request.
This plan replaced that handoff's immediate implementation instruction. Chris subsequently
requested execution and selected the sync branch; bin changes remain owner-coordinated.

## Table of Contents

- [ ] [Overview](#overview)
- [ ] [Problem Statement](#problem-statement)
- [x] [Phase 1: Confirm Scope and Approval 👤🤖](#phase-1-confirm-scope-and-approval-👤🤖)
  - [x] [Step 1.1: Confirm Date Selection and Ownership 🤖](#step-11-confirm-date-selection-and-ownership-🤖)
  - [x] [Step 1.2: Review Plan and Select Branch 👤](#step-12-review-plan-and-select-branch-👤)
- [x] [Phase 2: Implement and Test 🤖](#phase-2-implement-and-test-🤖)
  - [x] [Step 2.1: Bind Export and Import to One Date 🤖](#step-21-bind-export-and-import-to-one-date-🤖)
  - [x] [Step 2.2: Verify Isolated Regressions 🤖](#step-22-verify-isolated-regressions-🤖)
- [ ] [Phase 3: Review and Recover 👤🤖](#phase-3-review-and-recover-👤🤖)
  - [ ] [Step 3.1: Return Evidence and Checkpoint 👤🤖](#step-31-return-evidence-and-checkpoint-👤🤖)
  - [ ] [Step 3.2: Approve Recovery Separately 👤🤖](#step-32-approve-recovery-separately-👤🤖)

## Overview

Make one full sync-all export and import the same explicitly selected archive
date across PG2 and the Mac, even when their calendar dates differ or midnight
passes during execution. Keep the fix bounded to existing scripts and tests,
not a new snapshot protocol. No source code is changed by creating this plan.

[Back to TOC](#table-of-contents)

## Problem Statement

The approved run exported all five PG2 archives dated 20260923, then the Mac
importer requested existing older archives dated 20260922:

```text
Export verified:  pg2-eyedro-pgdump-20260923.tgz (648576579 bytes)
Import requested: pg2-eyedro-pgdump-20260922.tgz
```

SUP interrupted the first download, producing exit 1 before extraction,
schema drops or database replay. No SUP snapshot ran. Destructive replacement
of Mac targets is intended; selecting a different export is the defect.
The filenames were visible, but no automated mismatch error occurred.

`$(ggdir sync)/sync-lib.sh:24` independently defaults DATE_VAR to
`date +%Y%m%d`. The observed dates differ; timezone divergence is likely,
not a remotely verified finding. Existing preflight checks file presence and
nonzero size, not whether the file belongs to the export just completed.

[Back to TOC](#table-of-contents)

## Phase 1: Confirm Scope and Approval 👤🤖

- [x] Phase 1 complete: ownership and implementation authorization established.
No automated branch creation or switching.

[Back to TOC](#table-of-contents)

### Step 1.1: Confirm Date Selection and Ownership 🤖

- [x] Inspect DATE_VAR initialization, overrides and propagation in
  `$(ggdir sync)/sync-lib.sh`, export-all.sh, import-all.sh and member scripts.
- [x] Inspect the calling boundary in `$(ggdir bin)/sync-all`.
- [x] Confirm the minimal change and coordinate bin-owned edits with bin.
  Do not treat the wrapper as sync-owned or edit remote deployed scripts directly.
  Follow each project's local instructions and implementation-branch rules.

**Evidence — 2026-09-22 21:13 EDT:** Current sync branch matches the plan; initial
tree clean. Read all eight orchestrator/member callers: sync-lib selects and exports
DATE_VAR independently on each host. Existing bin sync-all passes no date to pgs.
Bin observed on main; sent exact proposed boundary to bin's messages and requested
Chris's owner/branch coordination. No bin code or branch changed by sync.

**Owner-boundary update — 2026-09-22 21:22 EDT:** Chris confirmed gitcb in bin
and explicitly authorized sync@codex to work in the bin tree. Verified bin branch
`sync-all-export-import-date-mismatch-sync`; only the existing coordination message
and copied plan were untracked. Read bin instructions/plan and edited from its
root. No branch switch, unrelated edits or duplicate agent work. Both roots now
use the Chris-selected branch of the same name.

Same-day concurrent snapshot generations and a global manifest architecture are
outside this bounded fix. Return a blocker if broader work proves necessary.

[Back to TOC](#table-of-contents)

### Step 1.2: Review Plan and Select Branch 👤

- [x] Chris reviews this plan, selects the branch via his gitcb workflow and
  explicitly authorizes implementation.
- [x] sync@codex verifies the actual branch and existing work before editing.
- [x] Confirm the bin branch/permission boundary for its wrapper change.

Plan creation does not authorize implementation, deployment or operations.

[Back to TOC](#table-of-contents)

## Phase 2: Implement and Test 🤖

- [x] Phase 2 complete: bounded implementation and isolated regressions pass.
Use existing script locations; no new one-off operational tool is required.

[Back to TOC](#table-of-contents)

### Step 2.1: Bind Export and Import to One Date 🤖

- [x] Capture one validated date once per full run and explicitly pass it to
  remote export and Mac import, including child scripts.
- [x] Preserve supported overrides with safe validation/quoting before remote
  commands. Do not rely on implicit SSH environment forwarding, recompute the
  date after export, change machine timezones or fall back to previous files.
- [x] Preserve standalone export/import callers, trim selection, failure
  short-circuiting, configured SUP-once behavior and exit propagation.

**Implementation evidence — 2026-09-22 21:13 EDT:** sync-lib.sh now defaults only
when DATE_VAR is unset, validates an eight-digit Gregorian calendar date using
portable Bash arithmetic, rejects empty/impossible/injection-shaped overrides with
status 2, propagates date-command failure, and exports the valid date for children.
No member/transport rewrite. README documents selection, overrides and recovery
limits. Bin must source the library before trim, explicitly pass the validated
date to PG2 export and inherit it for Mac import; that owner patch is pending.

**Completed — 2026-09-22 21:22 EDT:** Bin sync-all resolves/sources the sync
library before trim, refuses missing/legacy validation support, captures the valid
value once, and explicitly supplies it in both PG2 export and Mac import command
environments. This preserves configured SUP-once, unset skip, prompt and failure
contracts. Updated bin's isolated fixture and operator guide; no standalone
sync-superset or analytical member script change.

Prefer the existing DATE_VAR mechanism. A comparably small existing manifest
mechanism is acceptable if the owner explains why it is a better fit.

[Back to TOC](#table-of-contents)

### Step 2.2: Verify Isolated Regressions 🤖

- [x] Different simulated PG2/Mac dates produce identical export/import filenames.
- [x] Midnight crossing cannot change the selected import date.
- [x] An older complete set cannot satisfy selection for the newly exported date.
- [x] Invalid explicit overrides fail before transport; supported overrides
  reach both sides and children unchanged.
- [x] Standalone behavior, trim choice, export/import failure handling and
  configured SUP-once execution retain their existing contracts.

**Test preparation — 2026-09-22 21:13 EDT:** Extended existing analytical suite
with real-calendar/invalid-date tests across all entry points and parent/child
clock divergence. Extended integration suite with a fresh fake remote environment
(no inherited DATE_VAR), explicit remote assignment, simulated midnight, real
export/import member scripts on synthetic archives, older complete-set refusal,
and preserved SUP/failure cases. Final wrapper run awaits bin's tested patch/hash.
No passing integration result is claimed for these new cases yet.

**Verification — 2026-09-22 21:15 EDT:** Analytical suite passes 107 assertions,
0 failures under env -i with temporary HOME/TMPDIR. This includes all prior
56 regressions, valid/invalid Gregorian overrides, every standalone entry point
refusing bad dates before transport, inherited date across midnight and default
clock failure. An initial nested-quote error in the new test fixture was fixed;
no production correction was required. Bash syntax and whitespace checks pass.
New wrapper integration cases remain unexecuted pending bin's authorized patch;
existing main still passes no date and cannot satisfy the new transport contract.

**Final verification — 2026-09-22 21:22 EDT:** Full isolated integration suite:
**330 assertions passed, 0 failed**. Actual analytical export/import children run
only against synthetic archives and transport/database shims. Different host
clocks, midnight after export, valid override, selected-date missing artifact
while a full older set exists, and original trim/error/SUP contracts all pass.
Missing/legacy date library and clock-command failure refuse before any stage.
Analytical regression result remains **107 passed, 0 failed** (unchanged since
its passing run). Bin wrapper suite: **12 tests passed**, with expanded date-boundary
cases; bin fixtures mock only the library interface while sync tests real validation.
Shell syntax and whitespace checks pass. Internal TOC links checked mechanically;
manual Typora Cmd-click remains pending, not claimed as performed.

Tested file SHA256:
- bin sync-all: `c8b7d63b84aefb4b1394301c8e70d25017bdfadc9eb855626075730b6fc97227`
- sync sync-lib.sh: `0e679aa3e0eedd52d8fbd0b9b1c1898bc878062c4fd08f7e1964e50a3c5bbe4b`

No bin/sync production command was run outside fixtures. No actual archive,
credential, remote host or service was accessed. No staging or commits. The earlier
bin-authorization blocker is resolved by Chris's direct cross-project instruction.

Use fake dates/transports and synthetic archives in existing sync/bin test
locations. No real credentials, export/import, function execution or services.

[Back to TOC](#table-of-contents)

## Phase 3: Review and Recover 👤🤖

- [ ] Phase 3 complete: review/checkpoint and separately authorized recovery
  are evidenced. Do not infer either from passing tests.

[Back to TOC](#table-of-contents)

### Step 3.1: Return Evidence and Checkpoint 👤🤖

- [x] Send changed paths, tests, remaining decisions and a minimal recovery
  proposal through PGUI messages/ to pgui@codex and sup@codex, copying pgui@claude.
- [x] Chris reviews the delta and explicitly authorizes the commit checkpoint.
  Use individual filenames for staging; no wildcard, -A or amend.
- [ ] Chris handles push/merge/deployment as applicable. No direct remote edits.

**Handoff — 2026-09-22 21:15 EDT:** Returned sync-side completion and bin dependency
in `$(ggdir pgui)/messages/2026-09-22-sync-date-consistency-coding-checkpoint.md`,
addressed to pgui@codex and sup@codex, copying pgui@claude. Coding is incomplete
until bin's wrapper is authorized/delivered and integration tests pass. No commit
requested/performed and no operations. File creation is not delivery/acceptance.

**Final return — 2026-09-22 21:22 EDT:** Completion evidence and exact changed
paths are in `$(ggdir pgui)/messages/2026-09-22-sync-date-consistency-complete.md`,
addressed to pgui@codex and sup@codex, copying pgui@claude. Phase 3.1 remains open
for Chris's review/commit instruction; no push/merge/deployment inferred. Phase
3.2 remains open: verification of the real fresh export set and exact recovery
authorization have not occurred.

**Commit authorization — 2026-09-22 21:27 EDT:** Chris explicitly requested
committing the reviewed files in both projects before his gitm workflow. This
plan is included in sync's five-file checkpoint: README.md, sync-lib.sh,
tests/run-tests.sh, tests/run-sync-all-superset-tests.sh and this plan. Bin has
a separate five-file checkpoint on the same named branch. No executable changes
since passing verification; no test rerun needed. Step 3.1 stays open for Chris's
merge/push and any separately approved deployment. Recovery remains unapproved.

Update this living plan's checkboxes and dated evidence as each task completes.

[Back to TOC](#table-of-contents)

### Step 3.2: Approve Recovery Separately 👤🤖

- [ ] Reverify the fresh PG2 20260923 export set before proposing its use.
  Do not assume another export/full sync-all is necessary.
- [x] Account for the interrupted Mac 20260922 eyedro download, which may be
  partial. Do not trust, delete or repair it without operational approval.
- [ ] Chris separately approves the exact recovery sequence; PGUI coordinates it.
  No automatic rerun after coding and no blind retry.

**Recovery proposal — 2026-09-22 21:15 EDT (not executed):** PGUI should commission
a read-only verification of all five PG2 20260923 archives, comparing current
names/sizes to the recorded export evidence and verifying archive integrity.
Verify current target/writer quiescence and space, plus unchanged SUP failed-run
provenance; do not infer these from yesterday's or earlier checks. If the fresh
set remains acceptable, obtain Chris's explicit approval for Mac analytical-only
`DATE_VAR=20260923 ./import-all.sh` from sync, then the separately approved
standalone SUP action if analytical import succeeds. This avoids another export
and a redundant second PGDB import. Preserve the possibly partial 20260922 file;
the explicitly selected import must fetch 20260923, never fall back or reuse the
partial file. Any cleanup and exact SUP new-run/resume decision belong to the
operator approval. No fresh-set read or data/service operation occurred here.

Preserve SUP run-vbrwugy4 unchanged. Last observed Mac hub/PGUI/PGIS and Superset
app/worker/beat were stopped, with Superset restart=no; reverify before approved
operations rather than assuming that state persists. Item 13 service starts
remain gated. This plan authorizes no live repair or operational run.

[Back to TOC](#table-of-contents)

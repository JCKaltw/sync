# sync-all Export/Import Date Consistency - SYNC Plan

**Created**: 2026-09-22
**Author**: sup@codex, at Chris's request
**Owner**: sync@codex; coordinate bin-owned wrapper changes with bin
**Status**: Awaiting Chris's review, branch selection and explicit implementation approval.
**Proposed branch**: `sync-all-export-import-date-mismatch-sync`
**Parent effort**: PGUI HUB master effort, item 12 recovery.
**Evidence**: `$(ggdir pgui)/messages/2026-09-22-sup-fresh-rerun-date-mismatch.md`
**Supersedes**: The former messages/ handoff, moved here at Chris's request.
This plan replaces that handoff's immediate implementation instruction. Do not
implement until Chris reviews this plan and explicitly approves implementation.

## Table of Contents

- [ ] [Overview](#overview)
- [ ] [Problem Statement](#problem-statement)
- [ ] [Phase 1: Confirm Scope and Approval 👤🤖](#phase-1-confirm-scope-and-approval-👤🤖)
  - [ ] [Step 1.1: Confirm Date Selection and Ownership 🤖](#step-11-confirm-date-selection-and-ownership-🤖)
  - [ ] [Step 1.2: Review Plan and Select Branch 👤](#step-12-review-plan-and-select-branch-👤)
- [ ] [Phase 2: Implement and Test 🤖](#phase-2-implement-and-test-🤖)
  - [ ] [Step 2.1: Bind Export and Import to One Date 🤖](#step-21-bind-export-and-import-to-one-date-🤖)
  - [ ] [Step 2.2: Verify Isolated Regressions 🤖](#step-22-verify-isolated-regressions-🤖)
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

- [ ] Phase 1 complete: ownership and implementation authorization established.
No automated branch creation or switching.

[Back to TOC](#table-of-contents)

### Step 1.1: Confirm Date Selection and Ownership 🤖

- [ ] Inspect DATE_VAR initialization, overrides and propagation in
  `$(ggdir sync)/sync-lib.sh`, export-all.sh, import-all.sh and member scripts.
- [ ] Inspect the calling boundary in `$(ggdir bin)/sync-all`.
- [ ] Confirm the minimal change and coordinate bin-owned edits with bin.
  Do not treat the wrapper as sync-owned or edit remote deployed scripts directly.
  Follow each project's local instructions and implementation-branch rules.

Same-day concurrent snapshot generations and a global manifest architecture are
outside this bounded fix. Return a blocker if broader work proves necessary.

[Back to TOC](#table-of-contents)

### Step 1.2: Review Plan and Select Branch 👤

- [ ] Chris reviews this plan, selects the branch via his gitcb workflow and
  explicitly authorizes implementation.
- [ ] sync@codex verifies the actual branch and existing work before editing.
  Confirm the bin branch/permission boundary if the fix touches its wrapper.

Plan creation does not authorize implementation, deployment or operations.

[Back to TOC](#table-of-contents)

## Phase 2: Implement and Test 🤖

- [ ] Phase 2 complete: bounded implementation and isolated regressions pass.
Use existing script locations; no new one-off operational tool is required.

[Back to TOC](#table-of-contents)

### Step 2.1: Bind Export and Import to One Date 🤖

- [ ] Capture one validated date once per full run and explicitly pass it to
  remote export and Mac import, including child scripts.
- [ ] Preserve supported overrides with safe validation/quoting before remote
  commands. Do not rely on implicit SSH environment forwarding, recompute the
  date after export, change machine timezones or fall back to previous files.
- [ ] Preserve standalone export/import callers, trim selection, failure
  short-circuiting, configured SUP-once behavior and exit propagation.

Prefer the existing DATE_VAR mechanism. A comparably small existing manifest
mechanism is acceptable if the owner explains why it is a better fit.

[Back to TOC](#table-of-contents)

### Step 2.2: Verify Isolated Regressions 🤖

- [ ] Different simulated PG2/Mac dates produce identical export/import filenames.
- [ ] Midnight crossing cannot change the selected import date.
- [ ] An older complete set cannot satisfy selection for the newly exported date.
- [ ] Invalid explicit overrides fail before transport; supported overrides
  reach both sides and children unchanged.
- [ ] Standalone behavior, trim choice, export/import failure handling and
  configured SUP-once execution retain their existing contracts.

Use fake dates/transports and synthetic archives in existing sync/bin test
locations. No real credentials, export/import, function execution or services.

[Back to TOC](#table-of-contents)

## Phase 3: Review and Recover 👤🤖

- [ ] Phase 3 complete: review/checkpoint and separately authorized recovery
  are evidenced. Do not infer either from passing tests.

[Back to TOC](#table-of-contents)

### Step 3.1: Return Evidence and Checkpoint 👤🤖

- [ ] Send changed paths, tests, remaining decisions and a minimal recovery
  proposal through PGUI messages/ to pgui@codex and sup@codex, copying pgui@claude.
- [ ] Chris reviews the delta and explicitly authorizes the commit checkpoint.
  Use individual filenames for staging; no wildcard, -A or amend.
- [ ] Chris handles push/merge/deployment as applicable. No direct remote edits.

Update this living plan's checkboxes and dated evidence as each task completes.

[Back to TOC](#table-of-contents)

### Step 3.2: Approve Recovery Separately 👤🤖

- [ ] Reverify the fresh PG2 20260923 export set before proposing its use.
  Do not assume another export/full sync-all is necessary.
- [ ] Account for the interrupted Mac 20260922 eyedro download, which may be
  partial. Do not trust, delete or repair it without operational approval.
- [ ] Chris separately approves the exact recovery sequence; PGUI coordinates it.
  No automatic rerun after coding and no blind retry.

Preserve SUP run-vbrwugy4 unchanged. Last observed Mac hub/PGUI/PGIS and Superset
app/worker/beat were stopped, with Superset restart=no; reverify before approved
operations rather than assuming that state persists. Item 13 service starts
remain gated. This plan authorizes no live repair or operational run.

[Back to TOC](#table-of-contents)

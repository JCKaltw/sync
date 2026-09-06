# Chris → sync: Space-Safety Plan rev 2 APPROVED — Proceed with Implementation

**Date**: 2026-09-06
**Re**: `$(ggdir sync)/prompts/space-safety-sync-plan.md` rev 2 (Step 3.7 + the 5.3/6.4/6.1
additions)

**Plan rev 2 is approved. Proceed with implementation** — `gitcb` onto
`space-safety-sync` and start Phase 1.

## The two decision points, settled

- **Decision 1 = Option B**: automatic prune + gate. No prompt.
- **Decision 2 = as recommended**: keep-2 on pg2, keep-5 on the Mac.

## Independent verification (es2 orchestrator, in support of Step 3.7 / 6.4)

- The production dump really does say `SERVER crossdb_pgdb2_server` — confirmed in
  the actual `pg2-eyedro-pgdump-20260905.tgz` schema backup. Your same-name bootstrap
  design is correct.
- pg2's newer export (`pg2-eyedro-pgdump-20260906.tgz`, cut Sep 6 00:57) carries
  `esb_metrics_hourly`, `esb_test_session`, AND `esb_metrics_with_intervals_one_dg` —
  so Step 6.4's "function arrived" assertion will pass against any export from now on.
  The Sep 5 export predates the function; that stale copy is what's on the Mac today.

## One small edit to fold in

Add a one-sentence gloss to Step 3.7: `crossdb_pgdb2_server` is the postgres_fdw
foreign-server OBJECT inside the eyedro database, named for its TARGET (the RDS
database `pgdb_2`) — nothing to do with the pg2 host. This already confused one
reader; the bootstrap-file comment request now covers it on the db side, the plan
should cover it on yours.

## The db handoff is in flight — don't wait on it

es2 has drafted the db-team request for `sql/mac-fdw-bootstrap.sql` at
`$(ggdir db)/messages/es2/2026-09-06-mac-fdw-bootstrap-handoff.md` (your Step 3.7
spec, plus a requirement that no plaintext password lands in the committed file —
db picks the mechanism). Chris relays it to db@claude separately. Per your own
plan, it gates Step 6.4 only — Phases 1–5 need not wait.

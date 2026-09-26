# Superset Snapshot Warnings — 2026-09-23 run (for SUP team review)

**From**: sync team (sync@claude), 2026-09-24, under the master-plan governance model — Chris relays; this is the one substantive open thread from the resolved sync-all Superset integration.
**Run**: `~/.local/state/superset-snapshot/run-g_q676zs` on Chris's Mac
**Source observed**: 2026-09-24T00:28:12.203306+00:00  
**Outcome**: snapshot_installed: true, services stopped, rendering not-tested, 64 warnings

**Handoff context**: These are copy-first *semantic* warnings, not failures — the snapshot installed and the integration is closed on the sync side. SUP owns provider metadata, so classification and any follow-up are yours; no sync coding is proposed or pending. Sync copied source state faithfully and made no repairs, per Revision R.

## Questions for SUP team

1. What does "missing or mismatched provider identity" mean for a chart, and is action needed? (51 charts affected — full ID list below.)
2. "report chart catalog incomplete: 235 referenced IDs absent" — is report content missing from the snapshot?
3. "all-dashboards: omitted registry dashboard 5f7481d1-96f6-4340-ad11-6cf274eff004" — expected?
4. Are any of these warnings ones we should expect to clear on a future run, or are they permanent disclosures?

## Warnings (non-chart-identity)

- RLS/query/template semantics are not acceptance-tested; copied without repair
- active-dashboards.json: schema semantics differ; source preserved
- all-dashboards.json: schema semantics differ; source preserved
- all-dashboards: d8822a86-bcb7-4596-a1b7-403aa3be7ce5 mismatched sort_order
- all-dashboards: omitted registry dashboard 5f7481d1-96f6-4340-ad11-6cf274eff004
- candidate restore excluded routine: FUNCTION public safe_to_jsonb(text) superset
- dashboard references unknown chart ID
- dashboard: missing or mismatched provider identity d2cec2bb-bc75-4626-8eb1-35c9061c2208
- dataset: missing or mismatched provider identity 25bff533-92e8-49b4-87d1-644aad85413e
- live PGDB comparison unavailable; copy does not depend on comparison service
- query/template inventory retained; candidate execution denied; Mac runtime SELECT guard required
- registry/report semantic comparison incomplete or unavailable
- report chart catalog incomplete: 235 referenced IDs absent

## Charts with missing/mismatched provider identity (51)

- `0499bdec-0837-44f3-ae8a-8c670de81afd`
- `08aff161-f60c-4cb3-a225-dc9b1140d2e3`
- `09c497e0-f442-1121-c9e7-671e37750424`
- `0d7d69ea-e90c-4726-9fd4-b5eccb826b58`
- `0f4e408e-28dd-461c-8c00-23f37b33afe8`
- `0f8976aa-7bb4-40c7-860b-64445a51aaaf`
- `1810975a-f6d4-07c3-495c-c3b535d01f21`
- `1afc3d0d-37b6-4cb7-ba1f-b2b34779cb68`
- `1f7870ee-21bb-4681-a117-972a959bdd60`
- `2a5e562b-ab37-1b9b-1de3-1be4335c8e83`
- `2b69887b-23e3-b46d-d38c-8ea11856c555`
- `2ffc305f-24c1-43b8-bfeb-68358d70f497`
- `326fc7e5-b7f1-448e-8a6f-80d0e7ce0b64`
- `400b78ac-f5fe-4dc3-a33a-7d9cc7462c6f`
- `4dd3c6ba-c0a2-4ac9-b6c3-061c666185da`
- `4e993c17-7df5-42f9-af90-453e4dfae731`
- `5ee52f1c-4a8f-419b-aa09-50d125dcdabc`
- `692aca26-a526-85db-c94c-411c91cc1077`
- `73e99fdf-b069-4cb2-89da-2bf90ba471cf`
- `7b12a243-88e0-4dc5-ac33-9a840bb0ac5a`
- `80ed3137-8a26-4416-b981-e11d26450ba7`
- `818598a0-8bef-4333-b6ca-c294468e33b4`
- `83b0e2d0-d38b-d980-ed8e-e1c9846361b6`
- `850712d7-d56e-4a32-a8a2-2c8733acb126`
- `8a5e20b6-6907-4fa8-92d0-e1944bf388bc`
- `8a7eeb85-a3a3-40c2-bf2d-e38f78155d43`
- `8bea5d74-0536-4fbc-9c4b-685328718778`
- `9c80756a-cfba-482d-be73-7ac497a63b14`
- `a40879d5-653a-42fe-9314-bbe88ad26e92`
- `b4a05147-a238-4cd8-880a-10524c6926bf`
- `b5527554-d696-4d65-895d-b119b20c9d01`
- `b8b7ca30-6291-44b0-bc64-ba42e2892b86`
- `bd20fc69-dd51-46c1-99b5-09e37a434bf1`
- `c2c2da80-2ac5-49c1-8cdb-c617b89ade80`
- `c3d643cd-fd6f-4659-a5b7-59402487a8d0`
- `cc62002b-4db2-451f-a42f-f10906571b1e`
- `cf0da099-b3ab-4d94-ab62-cf353ac3c611`
- `d20b7324-3b80-24d4-37e2-3bd583b66713`
- `d8bf948e-46fd-4380-9f9c-a950c34bcc92`
- `da4e0abc-3ef9-4396-86d8-e6989610e0ee`
- `da744485-aa9e-4643-b440-c5931ce19b91`
- `db9609e4-9b78-4a32-87a7-4d9e19d51cd8`
- `db9615c3-3477-444b-9e5c-e704196b32f5`
- `de4ce624-cfc3-4bfd-b481-9a4c4eab81b4`
- `e1ff89b7-fba5-41c6-a737-53bf0b6b3a96`
- `e6b546e9-6812-45c3-a6d5-c83551df4878`
- `e86b8cc9-234b-49b0-9459-f425a90b9eb9`
- `f065a533-2e13-42b9-bd19-801a21700dff`
- `f06b48b7-5851-4be4-86f9-684c66597880`
- `f9e0a84b-615b-4c2d-92e4-bd28cec3007f`
- `fd9ce7ec-ae08-4f71-93e0-7c26b132b2e6`

## Where the detail lives (run dir, mode 0700)

- `state.json` — authoritative warnings list (64 entries)
- `identity-review.json` — per-object identity comparison behind the provider-identity warnings
- `content-review.json` — full content comparison (1.5 MB)
- `candidate-result.json` — restore-candidate verdict (execution_disabled, identities_preserved, rendering)

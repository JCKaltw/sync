#!/bin/bash
# run-tests.sh — sandboxed failure-path and happy-path tests for the sync
# scripts. No live database, live pgui/data, or real export_data is touched:
# everything runs under a mktemp sandbox with PATH shims for
# pg_dump/psql/scp/ssh/tar (see tests/shims/).
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
export PATH="$HERE/shims:$PATH"

# dummy connection facts so `set -u` scripts resolve them; the psql/pg_dump
# shims never contact anything
export PGHOST=shim PGPORT=5432 PGUSER=shim PGDATABASE=shim
export PGHOST_2=shim PGPORT_2=5432 PGUSER_2=shim PGDATABASE_2=shim
export PGHOST_3=shim PGPORT_3=5432 PGUSER_3=shim PGDATABASE_3=shim

PASS=0
FAIL=0
ok()  { echo "  PASS: $1"; PASS=$((PASS + 1)); }
bad() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
assert() { local d="$1"; shift; if "$@" > /dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }
assert_contains() { local d="$1" hay="$2" needle="$3"
    if echo "$hay" | grep -qF "$needle"; then ok "$d"; else bad "$d (missing: $needle)"; fi; }

SANDBOXES=()
cleanup() { for s in "${SANDBOXES[@]:-}"; do [ -n "$s" ] && rm -rf "$s"; done; }
trap cleanup EXIT

new_sandbox() {
    SB="$(mktemp -d "${TMPDIR:-/tmp}/synctest.XXXXXX")"
    SANDBOXES+=("$SB")
    export EXPORT_DATA="$SB/export_data"
    export SYNC_REMOTE_EXPORT_DATA="$SB/remote_export_data"
    export SYNC_PGUI_DIR="$SB/pgui"
    export SHIM_LOG_DIR="$SB/logs"
    export SYNC_MANIFEST="$EXPORT_DATA/.sync-manifest"
    export DATE_VAR=20260906
    export SYNC_FDW_BOOTSTRAP="$SB/mac-fdw-bootstrap.sql"
    # deterministic space gate: plenty available unless a test says otherwise
    export SYNC_FAKE_AVAIL_KB=$((100 * 1024 * 1024))
    mkdir -p "$EXPORT_DATA" "$SYNC_REMOTE_EXPORT_DATA" "$SYNC_PGUI_DIR" "$SHIM_LOG_DIR"
    echo "-- fake FDW bootstrap" > "$SYNC_FDW_BOOTSTRAP"
    unset SHIM_TAR_FAIL_PATTERN SHIM_TAR_CORRUPT_PATTERN SHIM_SCP_FAIL_PATTERN \
          SHIM_SCP_TRUNCATE_PATTERN SHIM_PSQL_STDERR_FILE SHIM_PSQL_FAIL_PATTERN \
          SHIM_PGDUMP_FAIL SYNC_PRUNE_DRY_RUN SYNC_KEEP 2>/dev/null || true
}

make_remote_artifacts() {
    local r="$SYNC_REMOTE_EXPORT_DATA" t="$SB/mk"
    mkdir -p "$t/data"
    seq -f "filler line %.0f abcdefghijklmnopqrstuvwxyz0123456789" 1 2000 > "$t/public_schema_backup.sql"
    cp "$t/public_schema_backup.sql" "$t/weather_schema_backup.sql"
    seq -f "dml %.0f" 1 3000 > "$t/data/dml-ast.json"
    seq -f "ddl %.0f" 1 3000 > "$t/data/ddl-ast.json"
    ( cd "$t" \
      && /usr/bin/tar czf "$r/pg2-eyedro-pgdump-$DATE_VAR.tgz" public_schema_backup.sql \
      && /usr/bin/tar czf "$r/weather-db-$DATE_VAR.tgz" weather_schema_backup.sql \
      && /usr/bin/tar czf "$r/pg2-pgdb-pgdump-$DATE_VAR.tgz" public_schema_backup.sql \
      && /usr/bin/tar czf "$r/pg2-purifi-pgdump-$DATE_VAR.tgz" public_schema_backup.sql \
      && /usr/bin/tar czf "$r/pg2-pgdb-$DATE_VAR.tgz" data )
}

live_pgui_data() {
    mkdir -p "$SYNC_PGUI_DIR/data"
    echo "LIVE-BEFORE-TEST" > "$SYNC_PGUI_DIR/data/dml-ast.json"
    echo "LIVE-BEFORE-TEST" > "$SYNC_PGUI_DIR/data/ddl-ast.json"
}

# ---------------------------------------------------------------------------
echo "== T1: export space gate blocks before anything is written =="
new_sandbox
out="$(SYNC_FAKE_AVAIL_KB=1000 "$REPO/export-all.sh" 2>&1)"; rc=$?
assert "export-all exits nonzero" test "$rc" -ne 0
assert_contains "space banner printed" "$out" "SPACE GATE FAILED - nothing has been written"
assert "no tarball written" test -z "$(find "$EXPORT_DATA" -name '*.tgz' 2>/dev/null)"
assert "no dump written" test -z "$(find "$EXPORT_DATA" -name '*.sql' 2>/dev/null)"

echo "== T2: silent tar failure of 2026-08-19 is now loud =="
new_sandbox
mkdir -p "$SYNC_PGUI_DIR/data"; echo x > "$SYNC_PGUI_DIR/data/f.json"
export SHIM_TAR_FAIL_PATTERN="pg2-pgdb-$DATE_VAR\\.tgz"
out="$("$REPO/export-all.sh" 2>&1)"; rc=$?
assert "export-all exits nonzero" test "$rc" -ne 0
assert_contains "failing member named" "$out" "FAILED at member: pgdb"
assert_contains "manifest shows JSON tarball MISSING" "$out" "pg2-pgdb-$DATE_VAR.tgz"
assert "eyedro artifacts still created first" test -s "$EXPORT_DATA/pg2-eyedro-pgdump-$DATE_VAR.tgz"
assert "purify never ran (stop at first failure)" test ! -e "$EXPORT_DATA/pg2-purifi-pgdump-$DATE_VAR.tgz"
unset SHIM_TAR_FAIL_PATTERN

echo "== T3: corrupt-but-exit-0 tar caught by verify, intermediate kept =="
new_sandbox
export SHIM_TAR_CORRUPT_PATTERN="pg2-purifi-pgdump-$DATE_VAR\\.tgz"
out="$("$REPO/export-purify.sh" 2>&1)"; rc=$?
assert "export-purify exits nonzero" test "$rc" -ne 0
assert_contains "verify_tgz rejected it" "$out" "verify_tgz"
assert "raw dump NOT deleted (verify-then-delete)" test -s "$EXPORT_DATA/work-$DATE_VAR-purify/public_schema_backup.sql"
unset SHIM_TAR_CORRUPT_PATTERN

echo "== T4: missing remote tarball aborts import-all pre-flight, data untouched =="
new_sandbox
make_remote_artifacts
rm "$SYNC_REMOTE_EXPORT_DATA/pg2-pgdb-$DATE_VAR.tgz"
live_pgui_data
out="$("$REPO/import-all.sh" 2>&1)"; rc=$?
assert "import-all exits nonzero" test "$rc" -ne 0
assert_contains "pre-flight names the failure" "$out" "remote pre-flight failed"
assert_contains "missing artifact listed" "$out" "MISSING pg2-pgdb-$DATE_VAR.tgz"
assert "live pgui data untouched" grep -q "LIVE-BEFORE-TEST" "$SYNC_PGUI_DIR/data/dml-ast.json"
assert "nothing downloaded" test -z "$(find "$EXPORT_DATA" -name '*.tgz' 2>/dev/null)"

echo "== T5: corrupt downloaded tarball leaves live data and no swap =="
new_sandbox
make_remote_artifacts
live_pgui_data
export SHIM_SCP_TRUNCATE_PATTERN="pg2-pgdb-$DATE_VAR\\.tgz"
out="$("$REPO/import-pgdb.sh" 2>&1)"; rc=$?
assert "import-pgdb exits nonzero" test "$rc" -ne 0
assert_contains "verify_tgz rejected download" "$out" "verify_tgz"
assert "live pgui data untouched" grep -q "LIVE-BEFORE-TEST" "$SYNC_PGUI_DIR/data/dml-ast.json"
assert "no data.prev created" test ! -e "$SYNC_PGUI_DIR/data.prev"
unset SHIM_SCP_TRUNCATE_PATTERN

echo "== T6: stale shared-name dump can never reach psql (wrong-db isolation) =="
new_sandbox
make_remote_artifacts
echo "STALE DUMP FROM WRONG DATABASE" > "$EXPORT_DATA/public_schema_backup.sql"
export SHIM_SCP_FAIL_PATTERN="purifi"
out="$("$REPO/import-purify.sh" 2>&1)"; rc=$?
assert "import-purify exits nonzero on scp failure" test "$rc" -ne 0
assert "psql never saw the stale shared-name file" \
    bash -c "! grep -q -- '$EXPORT_DATA/public_schema_backup.sql' '$SHIM_LOG_DIR/psql.log' 2>/dev/null"
unset SHIM_SCP_FAIL_PATTERN

if [ "$(uname)" = "Darwin" ]; then
echo "== T7: missing FDW bootstrap fails eyedro import before public replay =="
new_sandbox
make_remote_artifacts
rm "$SYNC_FDW_BOOTSTRAP"
out="$("$REPO/import-eyedro.sh" 2>&1)"; rc=$?
assert "import-eyedro exits nonzero" test "$rc" -ne 0
assert_contains "bootstrap named as the blocker" "$out" "FDW bootstrap file missing"
assert "public dump never replayed" \
    bash -c "! grep -q 'work-$DATE_VAR-eyedro/public_schema_backup.sql' '$SHIM_LOG_DIR/psql.log' 2>/dev/null"
fi

echo "== T8a: benign role-grant replay errors are tolerated =="
new_sandbox
make_remote_artifacts
cat > "$SB/benign.err" <<'EOF'
psql:dump.sql:120: ERROR:  role "eyedro_user" does not exist
psql:dump.sql:121: ERROR:  role "postgres" does not exist
EOF
export SHIM_PSQL_STDERR_FILE="$SB/benign.err"
out="$("$REPO/import-purify.sh" 2>&1)"; rc=$?
assert "import-purify succeeds despite role errors" test "$rc" -eq 0
assert_contains "errors were counted as benign" "$out" "2 benign role-grant, 0 unexpected"

echo "== T8b: unexpected replay error fails the member =="
new_sandbox
make_remote_artifacts
cat > "$SB/mixed.err" <<'EOF'
psql:dump.sql:120: ERROR:  role "eyedro_user" does not exist
psql:dump.sql:500: ERROR:  relation "foo" already exists
EOF
export SHIM_PSQL_STDERR_FILE="$SB/mixed.err"
out="$("$REPO/import-purify.sh" 2>&1)"; rc=$?
assert "import-purify exits nonzero" test "$rc" -ne 0
assert_contains "unexpected error reported" "$out" "1 unexpected"
unset SHIM_PSQL_STDERR_FILE

echo "== T9: happy-path export with retention and size recording =="
new_sandbox
mkdir -p "$SYNC_PGUI_DIR/data"
seq -f "dml %.0f" 1 3000 > "$SYNC_PGUI_DIR/data/dml-ast.json"
seq -f "ddl %.0f" 1 3000 > "$SYNC_PGUI_DIR/data/ddl-ast.json"
i=1
for d in 20250101 20250102 20250103 20250104 20250105 20250106; do
    echo dummy > "$EXPORT_DATA/pg2-purifi-pgdump-$d.tgz"
    touch -t "2501${i}0000" "$EXPORT_DATA/pg2-purifi-pgdump-$d.tgz" 2>/dev/null \
        || touch -t "25010${i}0000" "$EXPORT_DATA/pg2-purifi-pgdump-$d.tgz"
    i=$((i + 1))
done
export SYNC_KEEP=5
out="$("$REPO/export-all.sh" 2>&1)"; rc=$?
assert "export-all succeeds" test "$rc" -eq 0
assert_contains "success banner" "$out" "EXPORT-ALL SUCCEEDED"
for f in "pg2-eyedro-pgdump-$DATE_VAR.tgz" "weather-db-$DATE_VAR.tgz" \
         "pg2-pgdb-$DATE_VAR.tgz" "pg2-pgdb-pgdump-$DATE_VAR.tgz" \
         "pg2-purifi-pgdump-$DATE_VAR.tgz"; do
    assert "artifact exists: $f" test -s "$EXPORT_DATA/$f"
done
assert "oldest dummy pruned" test ! -e "$EXPORT_DATA/pg2-purifi-pgdump-20250101.tgz"
assert "newer dummy kept" test -e "$EXPORT_DATA/pg2-purifi-pgdump-20250102.tgz"
assert "work dirs cleaned" test -z "$(find "$EXPORT_DATA" -maxdepth 1 -name 'work-*' 2>/dev/null)"
assert "no raw dumps left" test -z "$(find "$EXPORT_DATA" -maxdepth 1 -name '*_schema_backup.sql' 2>/dev/null)"
for m in eyedro pgdb purify; do
    assert "sizes recorded: $m" grep -q "^$m " "$EXPORT_DATA/.sync-last-sizes"
done
unset SYNC_KEEP

echo "== T10: happy-path import with verify-then-swap =="
new_sandbox
make_remote_artifacts
live_pgui_data
out="$("$REPO/import-all.sh" 2>&1)"; rc=$?
assert "import-all succeeds" test "$rc" -eq 0
assert_contains "success banner" "$out" "IMPORT-ALL SUCCEEDED"
assert "new data swapped in" grep -q "dml 1" "$SYNC_PGUI_DIR/data/dml-ast.json"
assert "previous generation kept as data.prev" grep -q "LIVE-BEFORE-TEST" "$SYNC_PGUI_DIR/data.prev/dml-ast.json"
assert "data.incoming cleaned" test ! -e "$SYNC_PGUI_DIR/data.incoming"
assert "work dirs cleaned" test -z "$(find "$EXPORT_DATA" -maxdepth 1 -name 'work-*' 2>/dev/null)"
if [ "$(uname)" = "Darwin" ]; then
    assert "FDW bootstrap ran before public replay" grep -q "mac-fdw-bootstrap.sql" "$SHIM_LOG_DIR/psql.log"
    assert_contains "FDW verified after import" "$out" "FDW verified"
fi

echo "== T11: prune dry-run deletes nothing =="
new_sandbox
echo dummy > "$EXPORT_DATA/pg2-purifi-pgdump-20250101.tgz"
echo dummy > "$EXPORT_DATA/public_schema_backup.sql"
out="$(SYNC_KEEP=0 SYNC_PRUNE_DRY_RUN=1 "$REPO/prune-export-data.sh" --dry-run 2>&1)"; rc=$?
assert "dry run succeeds" test "$rc" -eq 0
assert_contains "reports would-delete" "$out" "would delete"
assert "tarball still present" test -e "$EXPORT_DATA/pg2-purifi-pgdump-20250101.tgz"
assert "stray sql still present" test -e "$EXPORT_DATA/public_schema_backup.sql"

# ---------------------------------------------------------------------------
echo
echo "======================================"
echo "  $PASS passed, $FAIL failed"
echo "======================================"
[ "$FAIL" -eq 0 ]

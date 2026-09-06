#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/sync-lib.sh"

JSON_TGZ="pg2-pgdb-${DATE_VAR}.tgz"
DUMP_TGZ="pg2-pgdb-pgdump-${DATE_VAR}.tgz"

# nothing local is touched until today's artifacts are confirmed on pg2
remote_preflight "$JSON_TGZ" "$DUMP_TGZ"

PGUI_DIR="$(pgui_dir)"
cd "$EXPORT_DATA"
echo "Downloading from pg2..."
run_step "scp pgdb JSON tarball" scp "pg2:${REMOTE_EXPORT_DATA}/$JSON_TGZ" .
verify_tgz "$EXPORT_DATA/$JSON_TGZ"

# verify-then-swap: never touch live data/ until the replacement is proven
INCOMING="$PGUI_DIR/data.incoming"
rm -rf "$INCOMING"
mkdir -p "$INCOMING"
run_step "extract pgui data into data.incoming" \
    tar xzf "$EXPORT_DATA/$JSON_TGZ" -C "$INCOMING"
[ -s "$INCOMING/data/dml-ast.json" ] || die "incoming data has no dml-ast.json - live data/ untouched"
[ -s "$INCOMING/data/ddl-ast.json" ] || die "incoming data has no ddl-ast.json - live data/ untouched"

rm -rf "$PGUI_DIR/data.prev"
if [ -d "$PGUI_DIR/data" ]; then
    mv "$PGUI_DIR/data" "$PGUI_DIR/data.prev"
fi
mv "$INCOMING/data" "$PGUI_DIR/data"
rm -rf "$INCOMING"
echo "==> pgui data swapped in (previous generation kept as data.prev)"

echo "Updating ${PGUSER_3}@${PGDATABASE_3}"
run_step "scp pgdb pgdump tarball" scp "pg2:${REMOTE_EXPORT_DATA}/$DUMP_TGZ" .
verify_tgz "$EXPORT_DATA/$DUMP_TGZ"

# per-member work dir: no shared dump filename, no wrong-database restores
WD="$EXPORT_DATA/work-${DATE_VAR}-pgdb"
rm -rf "$WD"
mkdir -p "$WD"
run_step "extract pgdb dump" tar xzf "$EXPORT_DATA/$DUMP_TGZ" -C "$WD"
[ -s "$WD/public_schema_backup.sql" ] || die "extracted public_schema_backup.sql missing/empty in $WD"

run_step "drop+recreate public schema" \
    psql -h "${PGHOST_3}" -p "${PGPORT_3}" -U "${PGUSER_3}" -d "${PGDATABASE_3}" \
    -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
psql_replay "replay pgdb public dump" pgdb "$WD/public_schema_backup.sql" \
    -h "${PGHOST_3}" -p "${PGPORT_3}" -U "${PGUSER_3}" -d "${PGDATABASE_3}"

rm -rf "$WD"
manifest_add pgdb "$JSON_TGZ" OK "$(file_size "$EXPORT_DATA/$JSON_TGZ")"
manifest_add pgdb "$DUMP_TGZ" OK "$(file_size "$EXPORT_DATA/$DUMP_TGZ")"

echo "***********************************"
echo "Updated JSON DB at $PGUI_DIR/data/"
echo "Updated postgres: ${PGUSER_3}@${PGDATABASE_3}"
echo "***********************************"

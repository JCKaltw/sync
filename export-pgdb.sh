#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/sync-lib.sh"

require_space pgdb

PGUI_DIR="$(pgui_dir)"
JSON_TGZ="$EXPORT_DATA/pg2-pgdb-${DATE_VAR}.tgz"
DUMP_TGZ="$EXPORT_DATA/pg2-pgdb-pgdump-${DATE_VAR}.tgz"

# the pgui/data tar is the step that failed silently on 2026-08-19
run_step "tar pgui data ($PGUI_DIR/data)" \
    tar czf "$JSON_TGZ" -C "$PGUI_DIR" data
verify_tgz "$JSON_TGZ"

WD="$EXPORT_DATA/work-${DATE_VAR}-pgdb"
rm -rf "$WD"
mkdir -p "$WD"

run_step "pg_dump pgdb public schema (pgs3)" \
    pg_dump -h "${PGHOST_3}" -p "${PGPORT_3}" -U "${PGUSER_3}" -d "${PGDATABASE_3}" \
    -n public -f "$WD/public_schema_backup.sql"
run_step "tar pgdb dump" \
    tar czf "$DUMP_TGZ" -C "$WD" public_schema_backup.sql
verify_tgz "$DUMP_TGZ"

TOTAL=$(( $(file_size "$WD/public_schema_backup.sql") \
        + $(file_size "$JSON_TGZ") + $(file_size "$DUMP_TGZ") ))
record_sizes pgdb "$TOTAL"

# intermediate deleted only after the tarball verified above
rm -rf "$WD"

manifest_add pgdb "pg2-pgdb-${DATE_VAR}.tgz" OK "$(file_size "$JSON_TGZ")"
manifest_add pgdb "pg2-pgdb-pgdump-${DATE_VAR}.tgz" OK "$(file_size "$DUMP_TGZ")"

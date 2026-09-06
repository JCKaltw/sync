#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/sync-lib.sh"

require_space eyedro

WD="$EXPORT_DATA/work-${DATE_VAR}-eyedro"
rm -rf "$WD"
mkdir -p "$WD"

PUB_TGZ="$EXPORT_DATA/pg2-eyedro-pgdump-${DATE_VAR}.tgz"
WEA_TGZ="$EXPORT_DATA/weather-db-${DATE_VAR}.tgz"

run_step "pg_dump eyedro public schema (pgs2)" \
    pg_dump -h "${PGHOST_2}" -p "${PGPORT_2}" -U "${PGUSER_2}" -d "${PGDATABASE_2}" \
    -n public -f "$WD/public_schema_backup.sql"
run_step "tar eyedro public dump" \
    tar czf "$PUB_TGZ" -C "$WD" public_schema_backup.sql
verify_tgz "$PUB_TGZ"

run_step "pg_dump eyedro weather schema (pgs2)" \
    pg_dump -h "${PGHOST_2}" -p "${PGPORT_2}" -U "${PGUSER_2}" -d "${PGDATABASE_2}" \
    -n weather -f "$WD/weather_schema_backup.sql"
run_step "tar weather dump" \
    tar czf "$WEA_TGZ" -C "$WD" weather_schema_backup.sql
verify_tgz "$WEA_TGZ"

TOTAL=$(( $(file_size "$WD/public_schema_backup.sql") \
        + $(file_size "$WD/weather_schema_backup.sql") \
        + $(file_size "$PUB_TGZ") + $(file_size "$WEA_TGZ") ))
record_sizes eyedro "$TOTAL"

# intermediates are deleted only after both tarballs verified above
rm -rf "$WD"

manifest_add eyedro "pg2-eyedro-pgdump-${DATE_VAR}.tgz" OK "$(file_size "$PUB_TGZ")"
manifest_add eyedro "weather-db-${DATE_VAR}.tgz" OK "$(file_size "$WEA_TGZ")"

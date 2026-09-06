#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/sync-lib.sh"

require_space purify

WD="$EXPORT_DATA/work-${DATE_VAR}-purify"
rm -rf "$WD"
mkdir -p "$WD"

TGZ="$EXPORT_DATA/pg2-purifi-pgdump-${DATE_VAR}.tgz"

run_step "pg_dump purifi public schema (pgs1)" \
    pg_dump -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${PGDATABASE}" \
    -n public -f "$WD/public_schema_backup.sql"
run_step "tar purifi dump" \
    tar czf "$TGZ" -C "$WD" public_schema_backup.sql
verify_tgz "$TGZ"

TOTAL=$(( $(file_size "$WD/public_schema_backup.sql") + $(file_size "$TGZ") ))
record_sizes purify "$TOTAL"

# intermediate deleted only after the tarball verified above
rm -rf "$WD"

manifest_add purify "pg2-purifi-pgdump-${DATE_VAR}.tgz" OK "$(file_size "$TGZ")"

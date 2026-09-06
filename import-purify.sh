#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/sync-lib.sh"

TGZ="pg2-purifi-pgdump-${DATE_VAR}.tgz"

# nothing local is touched until today's artifact is confirmed on pg2
remote_preflight "$TGZ"

cd "$EXPORT_DATA"
echo "Downloading from pg2..."
run_step "scp purifi tarball" scp "pg2:${REMOTE_EXPORT_DATA}/$TGZ" .
verify_tgz "$EXPORT_DATA/$TGZ"

# per-member work dir: no shared dump filename, no wrong-database restores
WD="$EXPORT_DATA/work-${DATE_VAR}-purify"
rm -rf "$WD"
mkdir -p "$WD"
run_step "extract purifi dump" tar xzf "$EXPORT_DATA/$TGZ" -C "$WD"
[ -s "$WD/public_schema_backup.sql" ] || die "extracted public_schema_backup.sql missing/empty in $WD"

echo "Importing purifi (pgs1) database public schema..."
run_step "drop+recreate public schema" \
    psql -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${PGDATABASE}" \
    -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
psql_replay "replay purifi public dump" purify "$WD/public_schema_backup.sql" \
    -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${PGDATABASE}"

rm -rf "$WD"
manifest_add purify "$TGZ" OK "$(file_size "$EXPORT_DATA/$TGZ")"

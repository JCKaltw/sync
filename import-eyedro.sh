#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/sync-lib.sh"

PUB_TGZ="pg2-eyedro-pgdump-${DATE_VAR}.tgz"
WEA_TGZ="weather-db-${DATE_VAR}.tgz"

# nothing local is touched until today's artifacts are confirmed on pg2
remote_preflight "$PUB_TGZ" "$WEA_TGZ"

# fail fast on the Mac: the FDW bootstrap must exist BEFORE any schema is
# dropped, not discovered missing mid-import (plan Step 3.7)
BOOTSTRAP=""
if is_mac; then
    BOOTSTRAP="$(fdw_bootstrap_file)"
    [ -f "$BOOTSTRAP" ] || die "FDW bootstrap file missing: $BOOTSTRAP (db-team deliverable, see plan Step 3.7)"
fi

cd "$EXPORT_DATA"
echo "Downloading from pg2..."
run_step "scp eyedro tarballs" \
    scp "pg2:${REMOTE_EXPORT_DATA}/$PUB_TGZ" "pg2:${REMOTE_EXPORT_DATA}/$WEA_TGZ" .
verify_tgz "$EXPORT_DATA/$PUB_TGZ"
verify_tgz "$EXPORT_DATA/$WEA_TGZ"

# per-member work dir: no shared dump filename, no wrong-database restores
WD="$EXPORT_DATA/work-${DATE_VAR}-eyedro"
rm -rf "$WD"
mkdir -p "$WD"
run_step "extract eyedro public dump" tar xzf "$EXPORT_DATA/$PUB_TGZ" -C "$WD"
run_step "extract weather dump" tar xzf "$EXPORT_DATA/$WEA_TGZ" -C "$WD"
[ -s "$WD/public_schema_backup.sql" ] || die "extracted public_schema_backup.sql missing/empty in $WD"
[ -s "$WD/weather_schema_backup.sql" ] || die "extracted weather_schema_backup.sql missing/empty in $WD"

PSQL2=(psql -h "${PGHOST_2}" -p "${PGPORT_2}" -U "${PGUSER_2}" -d "${PGDATABASE_2}")

echo "Importing eyedro (pgs2) database weather schema..."
run_step "drop+recreate weather schema" \
    "${PSQL2[@]}" -c "DROP SCHEMA weather CASCADE; CREATE SCHEMA weather;"
psql_replay "replay weather dump" eyedro "$WD/weather_schema_backup.sql" \
    -h "${PGHOST_2}" -p "${PGPORT_2}" -U "${PGUSER_2}" -d "${PGDATABASE_2}"

echo "Importing eyedro (pgs2) database public schema..."
run_step "drop+recreate public schema" \
    "${PSQL2[@]}" -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"

# Step 3.7: Mac-only FDW bootstrap BEFORE the replay, so the dump's own
# CREATE FOREIGN TABLE ... SERVER crossdb_pgdb2_server restores cleanly.
# (crossdb_pgdb2_server is the postgres_fdw server object inside eyedro,
# named for its TARGET database pgdb_2 — nothing to do with the pg2 host.)
if is_mac; then
    run_step "FDW bootstrap ($BOOTSTRAP)" \
        "${PSQL2[@]}" -v ON_ERROR_STOP=1 -q -f "$BOOTSTRAP"
fi

psql_replay "replay eyedro public dump" eyedro "$WD/public_schema_backup.sql" \
    -h "${PGHOST_2}" -p "${PGPORT_2}" -U "${PGUSER_2}" -d "${PGDATABASE_2}"

# Step 3.7: post-import FDW verification (Mac only)
if is_mac; then
    EXT="$("${PSQL2[@]}" -tAc "select count(*) from pg_extension where extname='postgres_fdw'")"
    SRV="$("${PSQL2[@]}" -tAc "select count(*) from pg_foreign_server where srvname='crossdb_pgdb2_server'")"
    { [ "$EXT" = "1" ] && [ "$SRV" = "1" ]; } \
        || die "FDW verification failed after import (extension=$EXT server=$SRV)"
    CNT="$("${PSQL2[@]}" -tAc "select count(*) from public.product")" \
        || die "FDW verification failed: public.product not queryable"
    echo "==> FDW verified: postgres_fdw + crossdb_pgdb2_server present, product rows: $CNT"
fi

rm -rf "$WD"
manifest_add eyedro "$PUB_TGZ" OK "$(file_size "$EXPORT_DATA/$PUB_TGZ")"
manifest_add eyedro "$WEA_TGZ" OK "$(file_size "$EXPORT_DATA/$WEA_TGZ")"

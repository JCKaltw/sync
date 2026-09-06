#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/sync-lib.sh"

PUB_TGZ="pg2-eyedro-pgdump-${DATE_VAR}.tgz"
WEA_TGZ="weather-db-${DATE_VAR}.tgz"

remote_preflight "$PUB_TGZ" "$WEA_TGZ"

cd "$EXPORT_DATA"
echo "Downloading from pg2..."
run_step "scp eyedro tarballs from pg2" \
    scp "pg2:${REMOTE_EXPORT_DATA}/$PUB_TGZ" "pg2:${REMOTE_EXPORT_DATA}/$WEA_TGZ" .
verify_tgz "$EXPORT_DATA/$PUB_TGZ"
verify_tgz "$EXPORT_DATA/$WEA_TGZ"

echo "Uploading to pg4..."
run_step "scp eyedro tarballs to pg4" \
    scp "$PUB_TGZ" "$WEA_TGZ" "pg4:${REMOTE_EXPORT_DATA}"

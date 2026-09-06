#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/sync-lib.sh"

JSON_TGZ="pg2-pgdb-${DATE_VAR}.tgz"
DUMP_TGZ="pg2-pgdb-pgdump-${DATE_VAR}.tgz"

remote_preflight "$JSON_TGZ" "$DUMP_TGZ"

cd "$EXPORT_DATA"
echo "Downloading from pg2..."
run_step "scp pgdb tarballs from pg2" \
    scp "pg2:${REMOTE_EXPORT_DATA}/$JSON_TGZ" "pg2:${REMOTE_EXPORT_DATA}/$DUMP_TGZ" .
verify_tgz "$EXPORT_DATA/$JSON_TGZ"
verify_tgz "$EXPORT_DATA/$DUMP_TGZ"

echo "Uploading to pg4..."
run_step "scp pgdb tarballs to pg4" \
    scp "$JSON_TGZ" "$DUMP_TGZ" "pg4:${REMOTE_EXPORT_DATA}"

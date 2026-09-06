#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/sync-lib.sh"
cd "$SYNC_ROOT"

# all-or-nothing pre-flight: every expected artifact must exist on pg2
# before any member touches anything local
remote_preflight \
    "pg2-eyedro-pgdump-${DATE_VAR}.tgz" \
    "weather-db-${DATE_VAR}.tgz" \
    "pg2-pgdb-${DATE_VAR}.tgz" \
    "pg2-pgdb-pgdump-${DATE_VAR}.tgz" \
    "pg2-purifi-pgdump-${DATE_VAR}.tgz"

export SYNC_MANIFEST
manifest_init
manifest_expect eyedro "pg2-eyedro-pgdump-${DATE_VAR}.tgz"
manifest_expect eyedro "weather-db-${DATE_VAR}.tgz"
manifest_expect pgdb   "pg2-pgdb-${DATE_VAR}.tgz"
manifest_expect pgdb   "pg2-pgdb-pgdump-${DATE_VAR}.tgz"
manifest_expect purify "pg2-purifi-pgdump-${DATE_VAR}.tgz"

FAILED_MEMBER=""
trap 'st=$?; manifest_report; overall_banner "$st" IMPORT-ALL' EXIT

# retention first, so freed space counts toward the gate (Decision 1 = Option B)
prune_exports
require_space eyedro pgdb purify

FAILED_MEMBER=eyedro; ./import-eyedro.sh
FAILED_MEMBER=pgdb;   ./import-pgdb.sh
FAILED_MEMBER=purify; ./import-purify.sh
FAILED_MEMBER=""

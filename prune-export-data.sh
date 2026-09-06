#!/bin/bash
# prune-export-data.sh [--dry-run|-n] — apply the retention rule to
# export_data/ on this host (keep newest N per family: 2 on pg2, 5 on Mac,
# override with SYNC_KEEP) and remove stray raw *_schema_backup.sql dumps.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/sync-lib.sh"

if [ "${1:-}" = "--dry-run" ] || [ "${1:-}" = "-n" ]; then
    export SYNC_PRUNE_DRY_RUN=1
    echo "(dry run - nothing will be deleted)"
fi

prune_exports

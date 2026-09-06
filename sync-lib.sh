# sync-lib.sh — shared helpers for the sync export/import scripts (both hosts).
#
# Sourced by every export/import script; scripts start with:
#   set -euo pipefail
#   source "$(cd "$(dirname "$0")" && pwd)/sync-lib.sh"
#
# Env overrides (all optional; used by tests/ to sandbox everything):
#   SYNC_ROOT              root of the sync checkout (default: this file's dir)
#   EXPORT_DATA            local artifact dir (default: $SYNC_ROOT/export_data)
#   SYNC_REMOTE_EXPORT_DATA  path of export_data on pg2 as seen by ssh/scp
#   SYNC_MANIFEST          per-run manifest file
#   SYNC_KEEP              retention count override (default: Darwin 5, Linux 2)
#   SYNC_FAKE_AVAIL_KB     fake free-space figure for the space gate
#   SYNC_PRUNE_DRY_RUN     nonempty = prune only reports, deletes nothing
#   SYNC_PGUI_DIR          pgui checkout override (default: ggdir pgui)
#   SYNC_FDW_BOOTSTRAP     eyedro FDW bootstrap SQL override
#                          (default: $(ggdir db)/sql/mac-fdw-bootstrap.sql)
#   DATE_VAR               artifact date stamp (default: today, %Y%m%d)

SYNC_ROOT="${SYNC_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
EXPORT_DATA="${EXPORT_DATA:-$SYNC_ROOT/export_data}"
REMOTE_EXPORT_DATA="${SYNC_REMOTE_EXPORT_DATA:-sync/export_data}"
SYNC_MANIFEST="${SYNC_MANIFEST:-$EXPORT_DATA/.sync-manifest}"
DATE_VAR="${DATE_VAR:-$(date +%Y%m%d)}"
export SYNC_ROOT EXPORT_DATA SYNC_MANIFEST DATE_VAR

is_mac() { [ "$(uname)" = "Darwin" ]; }

file_size() {
    if is_mac; then stat -f%z "$1"; else stat -c%s "$1"; fi
}

fmt_gib() {
    awk -v b="$1" 'BEGIN{printf "%.1f GiB", b/1073741824}'
}

die() {
    {
        echo "******************************************************************"
        echo "* SYNC FAILED: $*"
        echo "******************************************************************"
    } >&2
    exit 1
}

run_step() {
    local label="$1"
    shift
    echo "==> $label"
    "$@" || die "step failed: $label"
}

# ---------------------------------------------------------------- space gate

member_default_bytes() {
    # First-run estimates (2026-09-06 measurements: eyedro raw dump 6.7GB
    # + 0.54GB tgz dominates; purify raw 5.2GB + 0.36GB tgz; pgdb small).
    case "$1" in
        eyedro) echo $((7 * 1024 * 1024 * 1024)) ;;
        purify) echo $((6 * 1024 * 1024 * 1024)) ;;
        pgdb)   echo $((1 * 1024 * 1024 * 1024)) ;;
        *)      echo $((1 * 1024 * 1024 * 1024)) ;;
    esac
}

last_size_bytes() {
    [ -f "$EXPORT_DATA/.sync-last-sizes" ] || return 0
    awk -v m="$1" '$1 == m {print $2}' "$EXPORT_DATA/.sync-last-sizes" | tail -1
}

require_space() {
    # require_space <member>... — abort before anything is written if the
    # estimated requirement (x1.5, plus a 2 GiB post-run floor) exceeds
    # available space on the export_data filesystem. Members run
    # SEQUENTIALLY and each deletes its raw dump once its tarball verifies,
    # so the peak need is the LARGEST member's last-run bytes (or default),
    # not the sum — the x1.5 margin covers the ~1GB of tarballs that
    # accumulate across the run.
    local need=0 basis="last run" m b
    for m in "$@"; do
        b="$(last_size_bytes "$m")"
        if [ -z "$b" ]; then
            b="$(member_default_bytes "$m")"
            basis="defaults"
        fi
        if [ "$b" -gt "$need" ]; then need=$b; fi
    done
    local scaled=$((need * 3 / 2))
    local floor=$((2 * 1024 * 1024 * 1024))
    local avail_kb
    if [ -n "${SYNC_FAKE_AVAIL_KB:-}" ]; then
        avail_kb="$SYNC_FAKE_AVAIL_KB"
    else
        avail_kb="$(df -Pk "$EXPORT_DATA" | awk 'NR==2 {print $4}')"
    fi
    local avail=$((avail_kb * 1024))
    if [ "$avail" -lt $((scaled + floor)) ]; then
        {
            echo "******************************************************************"
            echo "* SPACE GATE FAILED - nothing has been written"
            echo "* Required : $(fmt_gib $((scaled + floor)))  (largest member $(fmt_gib "$need") from $basis x 1.5 margin + 2 GiB floor)"
            echo "* Available: $(fmt_gib "$avail")  on $EXPORT_DATA"
            echo "* Shortfall: $(fmt_gib $((scaled + floor - avail)))"
            echo "* To free space:"
            echo "*   ./prune-export-data.sh          # apply retention now"
            echo "*   du -sh $EXPORT_DATA             # inspect"
            echo "******************************************************************"
        } >&2
        exit 1
    fi
    echo "==> space gate PASS: need $(fmt_gib $((scaled + floor))), available $(fmt_gib "$avail")"
}

record_sizes() {
    # record_sizes <member> <total-bytes> — atomically replace the member's
    # line in .sync-last-sizes (feeds the next run's space gate).
    local m="$1" bytes="$2"
    local f="$EXPORT_DATA/.sync-last-sizes" tmp
    tmp="$f.tmp.$$"
    {
        if [ -f "$f" ]; then grep -v "^$m " "$f" || true; fi
        echo "$m $bytes"
    } > "$tmp"
    mv "$tmp" "$f"
}

# ------------------------------------------------------ verification/manifest

verify_tgz() {
    # verify_tgz <path> — exists, above sanity floor, tar-readable, nonempty.
    local path="$1" floor="${SYNC_MIN_TGZ_BYTES:-1024}" sz n
    [ -f "$path" ] || die "verify_tgz: artifact missing: $path"
    sz="$(file_size "$path")"
    [ "$sz" -ge "$floor" ] || die "verify_tgz: $path is only $sz bytes (floor $floor)"
    if ! n="$(tar -tzf "$path" 2>/dev/null | wc -l | tr -d ' ')"; then
        die "verify_tgz: tar cannot read $path"
    fi
    [ "$n" -gt 0 ] || die "verify_tgz: $path lists no entries"
    echo "==> verified $path ($sz bytes, $n entries)"
}

manifest_init() { : > "$SYNC_MANIFEST"; }

manifest_add() {
    # manifest_add <member> <artifact> <status> <size>
    printf '%s|%s|%s|%s\n' "$1" "$2" "$3" "$4" >> "$SYNC_MANIFEST"
}

manifest_expect() { manifest_add "$1" "$2" MISSING 0; }

manifest_report() {
    echo "==================== SYNC MANIFEST ($DATE_VAR) ===================="
    if [ -s "$SYNC_MANIFEST" ]; then
        # last status recorded per member|artifact wins
        awk -F'|' '
            { key = $1 "|" $2
              if (!(key in seen)) { order[++n] = key; seen[key] = 1 }
              st[key] = $3; sz[key] = $4 }
            END { for (i = 1; i <= n; i++) {
                      split(order[i], p, "|")
                      printf "  %-8s %-42s %-8s %s\n", p[1], p[2], st[order[i]], sz[order[i]] } }
        ' "$SYNC_MANIFEST"
    else
        echo "  (no manifest entries)"
    fi
    echo "-------------------------------------------------------------------"
    df -h "$EXPORT_DATA" | tail -1
    echo "==================================================================="
}

overall_banner() {
    # overall_banner <exit-status> <ritual-name>; names $FAILED_MEMBER on failure
    local st="$1" name="$2"
    if [ "$st" -eq 0 ]; then
        echo "*******************************************"
        echo "*** $name SUCCEEDED - all members OK    ***"
        echo "*******************************************"
    else
        {
            echo "*******************************************"
            echo "*** $name FAILED at member: ${FAILED_MEMBER:-startup}"
            echo "*** see manifest above for artifact status"
            echo "*******************************************"
        } >&2
    fi
}

# ---------------------------------------------------------------- retention

sync_keep() {
    if [ -n "${SYNC_KEEP:-}" ]; then
        echo "$SYNC_KEEP"
    elif is_mac; then
        echo 5
    else
        echo 2
    fi
}

_prune_files() {
    # deletes (or dry-run reports) filenames fed on stdin; adds to PRUNE_FREED
    local f sz
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        [ -e "$f" ] || continue
        sz="$(file_size "$f")"
        if [ -n "${SYNC_PRUNE_DRY_RUN:-}" ]; then
            echo "    would delete: $f ($sz bytes)"
        else
            rm -f -- "$f"
            echo "    deleted: $f ($sz bytes)"
        fi
        PRUNE_FREED=$((PRUNE_FREED + sz))
    done
}

prune_exports() {
    # Keep the newest N dated tarballs per family (never fewer than the
    # newest one), and remove stray uncompressed *_schema_backup.sql dumps.
    local keep pat
    keep="$(sync_keep)"
    PRUNE_FREED=0
    echo "==> prune_exports: keep newest $keep per family in $EXPORT_DATA"
    cd "$EXPORT_DATA" || die "prune_exports: cannot cd $EXPORT_DATA"
    for pat in 'pg2-eyedro-pgdump-*.tgz' 'pg2-purifi-pgdump-*.tgz' \
               'pg2-pgdb-pgdump-*.tgz' 'weather-db-*.tgz'; do
        _prune_files < <(ls -t $pat 2>/dev/null | tail -n +$((keep + 1)))
    done
    # pg2-pgdb-*.tgz (JSON family) also matches the pgdump glob; exclude it
    _prune_files < <(ls -t pg2-pgdb-*.tgz 2>/dev/null | grep -v pgdump | tail -n +$((keep + 1)) || true)
    # stray raw dumps (prune runs before any dump is written this run)
    _prune_files < <(ls -- *_schema_backup.sql 2>/dev/null || true)
    echo "==> prune_exports: freed $PRUNE_FREED bytes"
    cd - > /dev/null
}

# ---------------------------------------------------------------- import side

remote_preflight() {
    # remote_preflight <artifact>... — all-or-nothing check that today's
    # tarballs exist nonzero on pg2 BEFORE anything is downloaded or touched.
    local out
    echo "==> remote pre-flight on pg2: $*"
    out="$(ssh pg2 "cd ${REMOTE_EXPORT_DATA} 2>/dev/null || { echo NODIR; exit 0; }; for f in $*; do if test -s \"\$f\"; then echo \"OK \$f\"; else echo \"MISSING \$f\"; fi; done")" \
        || die "remote pre-flight: ssh to pg2 failed"
    echo "$out" | sed 's/^/    /'
    if echo "$out" | grep -qE '^(MISSING|NODIR)'; then
        die "remote pre-flight failed - did export-all.sh run and succeed on pg2 today?"
    fi
}

psql_replay() {
    # psql_replay <label> <member> <dumpfile> <psql-conn-args>... — replay a
    # dump with error accounting: benign role-grant errors (roles absent on
    # this host) are tolerated; any other ERROR fails the member loudly.
    local label="$1" member="$2" dump="$3"
    shift 3
    local errfile="$dump.errors" total benign unexpected
    echo "==> $label"
    if ! psql "$@" -f "$dump" > /dev/null 2> "$errfile"; then
        die "psql replay failed hard (connection/fatal): $label (stderr: $errfile)"
    fi
    # benign by construction: role-grant errors (production roles absent on
    # this host) and schema-already-exists (we pre-create the schema the
    # dump also creates — pg_dump 15 emits CREATE SCHEMA even for public)
    local benign_re='ERROR: +(role "[^"]*" does not exist|schema "[^"]*" already exists)'
    total="$(grep -c 'ERROR:' "$errfile" || true)"
    benign="$(grep -cE "$benign_re" "$errfile" || true)"
    unexpected=$((total - benign))
    echo "    replay errors: $total total, $benign benign (role-grant/schema-exists), $unexpected unexpected"
    if [ "$unexpected" -gt 0 ]; then
        grep 'ERROR:' "$errfile" | grep -vE "$benign_re" | head -20 >&2
        die "psql replay: $unexpected unexpected errors in $label (full list: $errfile)"
    fi
    rm -f "$errfile"
}

fdw_bootstrap_file() {
    if [ -n "${SYNC_FDW_BOOTSTRAP:-}" ]; then
        echo "$SYNC_FDW_BOOTSTRAP"
    else
        # shellcheck disable=SC1090
        source ~/ggmap
        echo "$(ggdir db)/sql/mac-fdw-bootstrap.sql"
    fi
}

pgui_dir() {
    if [ -n "${SYNC_PGUI_DIR:-}" ]; then
        echo "$SYNC_PGUI_DIR"
    else
        # shellcheck disable=SC1090
        source ~/ggmap
        ggdir pgui
    fi
}

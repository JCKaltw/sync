#!/bin/bash
# Run from gg sync with an explicit bin-owned sync-all file. The controller is
# copied; every operation runs with synthetic HOME, ggmap, roots and commands.
set -euo pipefail

if [[ ${1:-} != --isolated ]]; then
    if [[ $# != 1 || $1 != /* || ! -f $1 || ! -f ./sync-lib.sh ]]; then
        echo 'Usage from sync root: bash tests/run-sync-all-superset-tests.sh "$(ggdir bin)/sync-all"' >&2
        exit 2
    fi
    suite_sandbox=$(mktemp -d /tmp/sync-superset-test.XXXXXX)
    mkdir -p "$suite_sandbox/home"
    # No inherited startup hooks, credentials, SSH agent or snapshot settings.
    exec /usr/bin/env -i HOME="$suite_sandbox/home" PATH=/usr/bin:/bin:/usr/sbin:/sbin \
        /bin/bash "$PWD/tests/run-sync-all-superset-tests.sh" --isolated \
        "$suite_sandbox" "$PWD" "$1"
fi

SB=$2
REPO=$3
CANDIDATE=$4
[[ $SB == /tmp/sync-superset-test.* && -d $SB/home ]] || exit 2
trap 'rm -rf -- "$SB"' EXIT
cp "$CANDIDATE" "$SB/sync-all-under-test"
echo "sync-all SHA256: $(shasum -a 256 "$SB/sync-all-under-test" | awk '{print $1}')"
PASS=0
FAIL=0
check() {
    local label=$1
    shift
    if "$@"; then PASS=$((PASS + 1)); else
        echo "FAIL: $CASE: $label" >&2
        FAIL=$((FAIL + 1))
    fi
}
contains() { grep -qE -- "$2" "$1"; }
absent() { ! grep -qE -- "$2" "$1"; }
order() { [[ $(cat "$CALL_LOG") == "$1" ]]; }

new_case() {
    CASE=$1
    CASE_ROOT="$SB/case"
    rm -rf -- "$CASE_ROOT"
    mkdir -p "$CASE_ROOT/bin" "$CASE_ROOT/sync" "$CASE_ROOT/tools" "$CASE_ROOT/logs"
    export CASE_ROOT CALL_LOG="$CASE_ROOT/logs/calls"
    : > "$CALL_LOG"
    : > "$CASE_ROOT/logs/tripwire"
    cp "$SB/sync-all-under-test" "$CASE_ROOT/bin/sync-all"
    chmod +x "$CASE_ROOT/bin/sync-all"
    export PATH="$CASE_ROOT/tools:$CASE_ROOT/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    export TRIM_RC=0 EXPORT_RC=0 IMPORT_RC=0 SUP_RC=0 ALIAS_RC=0 GGMAP_RC=0 GG_RC=0
    export FAIL_MEMBER= SUP_READ_INPUT=0 SUP_MODE=install SUP_PHASE=before
    export SUPERSET_SNAPSHOT_SETTINGS="$CASE_ROOT/synthetic-settings.json"
    export SUPERSET_SNAPSHOT_STATE_ROOT="$CASE_ROOT/synthetic-state"
    unset SHIM_PSQL_FAIL_PATTERN SHIM_SCP_FAIL_PATTERN SYNC_ROOT EXPORT_DATA \
        SYNC_REMOTE_EXPORT_DATA SYNC_PGUI_DIR SYNC_MANIFEST SYNC_FDW_BOOTSTRAP || true
    cat > "$HOME/dot-source-aliases.sh" <<'SH'
[[ $ALIAS_RC == 0 ]] || return "$ALIAS_RC"
pgs() {
    [[ $# == 1 && $1 == 'source ~/ggmap && gg sync && ./export-all.sh' ]] || return 96
    /bin/bash "$CASE_ROOT/sync/export-all.sh"
}
SH
    cat > "$HOME/ggmap" <<'SH'
[[ $GGMAP_RC == 0 ]] || return "$GGMAP_RC"
ggdir() {
    case "$1" in
        bin|sync|sup) printf '%s/%s\n' "$CASE_ROOT" "$1" ;;
        *) return 97 ;;
    esac
}
gg() {
    [[ $GG_RC == 0 ]] || return "$GG_RC"
    builtin pushd "$(ggdir "$1")" >/dev/null
}
SH
    cat > "$CASE_ROOT/bin/sync-trim" <<'SH'
#!/bin/bash
printf 'trim\n' >> "$CALL_LOG"
exit "$TRIM_RC"
SH
    cat > "$CASE_ROOT/sync/export-all.sh" <<'SH'
#!/bin/bash
printf 'export\n' >> "$CALL_LOG"
exit "$EXPORT_RC"
SH
    cat > "$CASE_ROOT/sync/import-all.sh" <<'SH'
#!/bin/bash
for member in eyedro pgdb purify; do
    printf 'import:%s\n' "$member" >> "$CALL_LOG"
    if [[ $FAIL_MEMBER == "$member" ]]; then
        printf 'IMPORT-ALL FAILED at member: %s\n' "$member" >&2
        exit "$IMPORT_RC"
    fi
done
exit "$IMPORT_RC"
SH
    cat > "$CASE_ROOT/bin/sync-superset" <<'SH'
#!/bin/bash
printf 'sup\n' >> "$CALL_LOG"
printf '%s\n' "$#" > "$CASE_ROOT/logs/sup-argc"
[[ $# == 0 ]] || exit 98
[[ $SUPERSET_SNAPSHOT_SETTINGS == "$CASE_ROOT/synthetic-settings.json" &&
   $SUPERSET_SNAPSHOT_STATE_ROOT == "$CASE_ROOT/synthetic-state" ]] || exit 99
if [[ $SUP_READ_INPUT == 1 ]]; then
    IFS= read -r answer || answer=EOF
    printf '%s\n' "$answer" > "$CASE_ROOT/logs/sup-input"
fi
printf 'SUP diagnostic: synthetic %s publication\n' "$SUP_PHASE" >&2
if [[ $SUP_PHASE == after ]]; then : > "$CASE_ROOT/published"; fi
case "$SUP_MODE" in
    install) printf '%s\n' '{"snapshot_installed":true,"services":"stopped","rendering":"not-tested","runtime_acceptance":false}' ;;
    check) printf '%s\n' '{"preflight":"passed","snapshot_installed":false}' ;;
    rollback) printf '%s\n' '{"recovered_previous_snapshot":true,"snapshot_installed":false}' ;;
esac
exit "$SUP_RC"
SH
    cat > "$CASE_ROOT/tools/tripwire" <<'SH'
#!/bin/bash
printf '%s\n' "${0##*/}" >> "$CASE_ROOT/logs/tripwire"
exit 95
SH
    for tool in ssh scp psql pg_dump docker pm2 curl wget tn hub sync-pgdb \
        start-test-hub.sh stop-test-hub.sh; do
        cp "$CASE_ROOT/tools/tripwire" "$CASE_ROOT/tools/$tool"
        chmod +x "$CASE_ROOT/tools/$tool"
    done
    chmod +x "$CASE_ROOT/bin/sync-trim" "$CASE_ROOT/bin/sync-superset" \
        "$CASE_ROOT/sync/export-all.sh" "$CASE_ROOT/sync/import-all.sh"
}
run_case() {
    local input=$1
    shift
    printf '%s' "$input" > "$CASE_ROOT/input"
    RC=0
    /bin/bash "$CASE_ROOT/bin/sync-all" "$@" < "$CASE_ROOT/input" \
        > "$CASE_ROOT/stdout" 2> "$CASE_ROOT/stderr" || RC=$?
    check 'no unexpected service/transport command' test ! -s "$CASE_ROOT/logs/tripwire"
}
FULL=$'export\nimport:eyedro\nimport:pgdb\nimport:purify\nsup'
ANALYTICAL=$'export\nimport:eyedro\nimport:pgdb\nimport:purify'
for answer in $'n\n' $'\n' '' $'y\n'; do
    new_case "trim answer ${answer:-EOF}"
    run_case "$answer"
    check 'status zero' test "$RC" -eq 0
    if [[ $answer == y* ]]; then expected=$'trim\n'"$FULL"; else expected=$FULL; fi
    check 'one ordered import of each member, then one SUP call' order "$expected"
    check 'zero SUP arguments' contains "$CASE_ROOT/logs/sup-argc" '^0$'
    check 'analytical completion on stderr' contains "$CASE_ROOT/stderr" '[Aa]nalytical.*(complet|succeed)'
done

new_case 'trim failure'
TRIM_RC=19
run_case $'y\n'
check 'existing trim exit 1' test "$RC" -eq 1
check 'no export after trim failure' order trim
for stage in ALIAS GGMAP GG EXPORT; do
    new_case "$stage failure"
    export "${stage}_RC=21"
    run_case $'n\n'
    check 'setup/export status preserved' test "$RC" -eq 21
    check 'no imports or snapshot' absent "$CALL_LOG" '^(import:|sup)'
done
for member in eyedro pgdb purify; do
    new_case "$member import failure"
    FAIL_MEMBER=$member IMPORT_RC=23
    run_case $'n\n'
    check 'import status preserved' test "$RC" -eq 23
    expected=export
    for prior in eyedro pgdb purify; do
        expected="$expected"$'\n'"import:$prior"
        [[ $prior == "$member" ]] && break
    done
    check 'stop at failed member' order "$expected"
    check 'member evidence preserved' contains "$CASE_ROOT/stderr" "FAILED at member: $member"
done
for state in missing nonexecutable; do
    new_case "$state snapshot command"
    if [[ $state == missing ]]; then rm "$CASE_ROOT/bin/sync-superset";
    else chmod -x "$CASE_ROOT/bin/sync-superset"; fi
    run_case $'n\n'
    check 'prerequisite status 3' test "$RC" -eq 3
    check 'analytical work completed once' order "$ANALYTICAL"
    check 'partial completion on stderr' contains "$CASE_ROOT/stderr" '[Aa]nalytical.*(complet|succeed)'
done
for code in 2 3 4 5 6 7 42 130; do
    new_case "SUP status $code"
    SUP_RC=$code
    run_case $'n\n'
    check 'SUP status preserved' test "$RC" -eq "$code"
    check 'no retry or duplicate analytical import' order "$FULL"
    check 'partial completion reported' contains "$CASE_ROOT/stderr" '[Aa]nalytical.*(complet|succeed)'
    check 'SUP diagnostic preserved' contains "$CASE_ROOT/stderr" '^SUP diagnostic: synthetic before publication$'
done
for mode in install check rollback; do
    new_case "$mode JSON"
    SUP_MODE=$mode
    "$CASE_ROOT/bin/sync-superset" > "$CASE_ROOT/expected-json" 2>/dev/null
    : > "$CALL_LOG"
    run_case $'n\n'
    check 'JSON stdout byte preservation' cmp -s "$CASE_ROOT/expected-json" "$CASE_ROOT/stdout"
    check 'no unconditional installation/acceptance banner' absent "$CASE_ROOT/stderr" '(snapshot installed|Snapshot installed|runtime accepted|rendering passed|SYNC-ALL SUCCEEDED)'
done
for input in $'n\nkeep-this-input\n' ''; do
    new_case 'SUP input and default decline'
    SUP_READ_INPUT=1 SUP_RC=7
    run_case "$input"
    check 'decline remains nonzero' test "$RC" -eq 7
    if [[ -n $input ]]; then expected=keep-this-input; else expected=EOF; fi
    check 'trim does not supply consent to SUP' contains "$CASE_ROOT/logs/sup-input" "^$expected$"
done
for flag in --yes --check --resume --rollback --force --unknown; do
    new_case "invalid sync-all argument $flag"
    run_case $'y\n' "$flag"
    check 'usage status 2' test "$RC" -eq 2
    check 'no stages for invalid arguments' test ! -s "$CALL_LOG"
done
for phase in before after; do
    new_case "failure $phase publication"
    SUP_RC=5 SUP_PHASE=$phase
    run_case $'n\n'
    check 'publication failure status' test "$RC" -eq 5
    check 'no recovery/restart/reimport' order "$FULL"
    if [[ $phase == after ]]; then check 'no automatic publication rollback' test -f "$CASE_ROOT/published"; fi
    check 'recovery guidance' contains "$CASE_ROOT/stderr" '(journal|resume|[Ii]nspect)'
done

# Complement the fake-member cases with the unchanged production import-all,
# member scripts and existing shims. Only synthetic archives/PGUI trees are used.
real_import_fixture() {
    for script in import-all.sh import-eyedro.sh import-pgdb.sh import-purify.sh sync-lib.sh; do
        cp "$REPO/$script" "$CASE_ROOT/sync/$script"
    done
    for tool in ssh scp psql tar; do cp "$REPO/tests/shims/$tool" "$CASE_ROOT/tools/$tool"; done
    export SYNC_ROOT="$CASE_ROOT/sync" EXPORT_DATA="$CASE_ROOT/export_data"
    export SYNC_REMOTE_EXPORT_DATA="$CASE_ROOT/remote" SYNC_PGUI_DIR="$CASE_ROOT/pgui"
    export SYNC_MANIFEST="$EXPORT_DATA/.sync-manifest" SHIM_LOG_DIR="$CASE_ROOT/logs"
    export SYNC_FDW_BOOTSTRAP="$CASE_ROOT/fdw.sql" SYNC_FAKE_AVAIL_KB=104857600 DATE_VAR=20260921
    export PGHOST=shim PGPORT=5432 PGUSER=shim PGDATABASE=purify
    export PGHOST_2=shim PGPORT_2=5432 PGUSER_2=shim PGDATABASE_2=eyedro
    export PGHOST_3=shim PGPORT_3=5432 PGUSER_3=shim PGDATABASE_3=pgdb
    mkdir -p "$EXPORT_DATA" "$SYNC_REMOTE_EXPORT_DATA" "$SYNC_PGUI_DIR/data" "$CASE_ROOT/make/data"
    printf 'before\n' > "$SYNC_PGUI_DIR/data/dml-ast.json"
    printf '%s\n' '-- synthetic bootstrap' > "$SYNC_FDW_BOOTSTRAP"
    seq -f 'synthetic sql row %.0f' 1 3000 > "$CASE_ROOT/make/public_schema_backup.sql"
    cp "$CASE_ROOT/make/public_schema_backup.sql" "$CASE_ROOT/make/weather_schema_backup.sql"
    seq -f 'synthetic dml %.0f' 1 3000 > "$CASE_ROOT/make/data/dml-ast.json"
    seq -f 'synthetic ddl %.0f' 1 3000 > "$CASE_ROOT/make/data/ddl-ast.json"
    for name in eyedro pgdb purifi; do
        /usr/bin/tar czf "$SYNC_REMOTE_EXPORT_DATA/pg2-$name-pgdump-$DATE_VAR.tgz" \
            -C "$CASE_ROOT/make" public_schema_backup.sql
    done
    /usr/bin/tar czf "$SYNC_REMOTE_EXPORT_DATA/weather-db-$DATE_VAR.tgz" -C "$CASE_ROOT/make" weather_schema_backup.sql
    /usr/bin/tar czf "$SYNC_REMOTE_EXPORT_DATA/pg2-pgdb-$DATE_VAR.tgz" -C "$CASE_ROOT/make" data
}
new_case 'actual import-all with isolated shims'
real_import_fixture
run_case $'n\n'
check 'actual analytical scripts and integration succeed' test "$RC" -eq 0
check 'one snapshot after actual imports' order $'export\nsup'
replays=$(awk '/-f .*work-.*\/public_schema_backup.sql/ {for(i=1;i<=NF;i++) if($i=="-d") print $(i+1)}' "$SHIM_LOG_DIR/psql.log")
check 'actual member public replays each once in order' test "$replays" = $'eyedro\npgdb\npurify'
check 'fixture PGDB JSON replaced' contains "$SYNC_PGUI_DIR/data/dml-ast.json" '^synthetic dml 1$'
check 'prior JSON preserved' contains "$SYNC_PGUI_DIR/data.prev/dml-ast.json" '^before$'
check 'analytical manifest completed' contains "$CASE_ROOT/stdout" 'IMPORT-ALL SUCCEEDED'

new_case 'actual import-all missing remote artifact'
real_import_fixture
rm "$SYNC_REMOTE_EXPORT_DATA/pg2-pgdb-$DATE_VAR.tgz"
run_case $'n\n'
check 'preflight failure preserved' test "$RC" -eq 1
check 'no snapshot after missing artifact' order export
check 'PGDB fixture untouched' contains "$SYNC_PGUI_DIR/data/dml-ast.json" '^before$'
check 'no database commands before artifact gate' test ! -e "$SHIM_LOG_DIR/psql.log"
check 'missing-artifact diagnostic preserved' contains "$CASE_ROOT/stderr" 'remote pre-flight failed'

# Exercise the bin-owned standalone delegate only against a synthetic SUP shell.
# This verifies recovery does not route back through analytical imports; bin's
# dedicated suite remains responsible for comprehensive argv/exec coverage.
standalone="${CANDIDATE%/*}/sync-superset"
if [[ -f $standalone ]]; then
    cp "$standalone" "$SB/sync-superset-under-test"
    echo "sync-superset SHA256: $(shasum -a 256 "$SB/sync-superset-under-test" | awk '{print $1}')"
    for mode in --resume --rollback; do
        new_case "standalone $mode"
        cp "$SB/sync-superset-under-test" "$CASE_ROOT/bin/sync-superset"
        mkdir -p "$CASE_ROOT/sup/bin"
        cat > "$CASE_ROOT/sup/bin/sync-superset-snapshot.sh" <<'SHIM'
#!/bin/bash
printf 'recovery\n' >> "$CALL_LOG"
printf '%s\n' "$@" > "$CASE_ROOT/logs/recovery-argv"
printf '%s\n' '{"snapshot_installed":false,"services":"stopped"}'
exit 0
SHIM
        chmod +x "$CASE_ROOT/sup/bin/sync-superset-snapshot.sh"
        printf '%s\n' "$mode" "$CASE_ROOT/run with spaces" > "$CASE_ROOT/expected-argv"
        RC=0
        /bin/bash "$CASE_ROOT/bin/sync-superset" "$mode" "$CASE_ROOT/run with spaces" \
            > "$CASE_ROOT/stdout" 2> "$CASE_ROOT/stderr" || RC=$?
        check 'standalone delegation succeeds' test "$RC" -eq 0
        check 'exact recovery arguments' cmp -s "$CASE_ROOT/expected-argv" "$CASE_ROOT/logs/recovery-argv"
        check 'recovery does not import' order recovery
        check 'no service/transport call' test ! -s "$CASE_ROOT/logs/tripwire"
    done
else
    CASE='standalone delegate dependency'
    check 'adjacent bin sync-superset must be delivered' false
fi

echo "$PASS passed, $FAIL failed (isolated integration assertions)"
[[ $FAIL == 0 ]]

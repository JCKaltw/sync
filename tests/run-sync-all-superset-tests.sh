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
    : > "$CASE_ROOT/logs/resolutions"
    cp "$SB/sync-all-under-test" "$CASE_ROOT/bin/sync-all"
    chmod +x "$CASE_ROOT/bin/sync-all"
    export PATH="$CASE_ROOT/tools:$CASE_ROOT/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    export TRIM_RC=0 EXPORT_RC=0 IMPORT_RC=0 SUP_RC=0 ALIAS_RC=0 GGMAP_RC=0 GG_RC=0
    export FAIL_MEMBER= SUP_READ_INPUT=0 SUP_MODE=install SUP_PHASE=before BIN_RESOLVE_RC=0
    export FAKE_MAC_DATE=20260921 FAKE_REMOTE_DATE=20260922 FAKE_AFTER_EXPORT_DATE=20260921
    export DATE_EXPORT_ACTUAL=0 DROP_FRESH=0 FAKE_DATE_RC=0
    unset DATE_VAR
    cp "$REPO/sync-lib.sh" "$CASE_ROOT/sync/sync-lib.sh"
    export SUPERSET_SNAPSHOT_SETTINGS="$CASE_ROOT/synthetic-settings.json"
    export SUPERSET_SNAPSHOT_STATE_ROOT="$CASE_ROOT/synthetic-state"
    unset SHIM_PSQL_FAIL_PATTERN SHIM_SCP_FAIL_PATTERN SYNC_ROOT EXPORT_DATA \
        SYNC_REMOTE_EXPORT_DATA SYNC_PGUI_DIR SYNC_MANIFEST SYNC_FDW_BOOTSTRAP || true
    cat > "$HOME/dot-source-aliases.sh" <<'SH'
[[ $ALIAS_RC == 0 ]] || return "$ALIAS_RC"
pgs() {
    # Only the agreed digits-only explicit assignment crosses this fake SSH
    # boundary. Never inherit DATE_VAR as though SendEnv were configured.
    local grammar="^source ~/ggmap && gg sync && DATE_VAR='([0-9]{8})' ./export-all[.]sh$"
    [[ $# == 1 && $1 =~ $grammar ]] || return 96
    local selected=${BASH_REMATCH[1]} rc=0
    printf '%s\n' "$selected" > "$CASE_ROOT/logs/remote-date"
    if [[ $DATE_EXPORT_ACTUAL == 1 ]]; then
        printf 'export\n' >> "$CALL_LOG"
        env -u DATE_VAR DATE_VAR="$selected" FAKE_MAC_DATE="$FAKE_REMOTE_DATE" \
            EXPORT_DATA="$SYNC_REMOTE_EXPORT_DATA" \
            SYNC_MANIFEST="$SYNC_REMOTE_EXPORT_DATA/.sync-manifest" \
            SYNC_PGUI_DIR="$CASE_ROOT/source-pgui" \
            /bin/bash "$CASE_ROOT/sync/export-all.sh" || rc=$?
        if [[ $DROP_FRESH == 1 ]]; then
            rm "$SYNC_REMOTE_EXPORT_DATA/pg2-pgdb-$selected.tgz"
        fi
    else
        env -u DATE_VAR DATE_VAR="$selected" FAKE_MAC_DATE="$FAKE_REMOTE_DATE" \
            /bin/bash "$CASE_ROOT/sync/export-all.sh" || rc=$?
    fi
    # Subsequent local date calls see the new day, but the pinned value must win.
    printf '%s\n' "$FAKE_AFTER_EXPORT_DATE" > "$CASE_ROOT/clock-after-export"
    return "$rc"
}
SH
    cat > "$HOME/ggmap" <<'SH'
[[ $GGMAP_RC == 0 ]] || return "$GGMAP_RC"
ggdir() {
    printf '%s\n' "$1" >> "$CASE_ROOT/logs/resolutions"
    [[ $1 != bin || $BIN_RESOLVE_RC == 0 ]] || return "$BIN_RESOLVE_RC"
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
source "$CASE_ROOT/sync/sync-lib.sh" || exit $?
printf 'export\n' >> "$CALL_LOG"
printf '%s\n' "$DATE_VAR" > "$CASE_ROOT/logs/export-date"
exit "$EXPORT_RC"
SH
    cat > "$CASE_ROOT/sync/import-all.sh" <<'SH'
#!/bin/bash
source "$CASE_ROOT/sync/sync-lib.sh" || exit $?
printf '%s\n' "$DATE_VAR" > "$CASE_ROOT/logs/import-date"
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
# Simulate SUP's validation boundary, not its settings parser. These paths are
# synthetic and no real settings/key file is ever opened. The synthetic HOME
# default path is accepted so the fallback case can prove delegation.
printf '%s\n' "${SUPERSET_SNAPSHOT_SETTINGS-}" > "$CASE_ROOT/logs/sup-settings"
if [[ ${SUPERSET_SNAPSHOT_SETTINGS-} != "$CASE_ROOT/synthetic-settings.json" \
   && ${SUPERSET_SNAPSHOT_SETTINGS-} != "$HOME/.config/superset-snapshot/settings.json" ]]; then
    printf 'SUP refusal: synthetic settings input invalid\n' >&2
    exit 3
fi
[[ $SUPERSET_SNAPSHOT_STATE_ROOT == "$CASE_ROOT/synthetic-state" ]] || exit 99
if [[ $SUP_READ_INPUT == 1 ]]; then
    IFS= read -r answer || answer=EOF
    printf '%s\n' "$answer" > "$CASE_ROOT/logs/sup-input"
fi
printf 'SUP diagnostic: synthetic %s publication\n' "$SUP_PHASE" >&2
if [[ $SUP_PHASE == after ]]; then : > "$CASE_ROOT/published"; fi
case "$SUP_MODE" in
    install) printf '%s\n' '{"snapshot_installed":true,"services":"stopped","rendering":"not-tested","runtime_acceptance":false}' ;;
    warnings)
        printf '%s\n' 'WARNING: synthetic source report order differs; values copied faithfully' >&2
        printf '%s\n' '{"snapshot_installed":true,"warnings":["synthetic semantic difference"],"services":"stopped","rendering":"not-tested","runtime_acceptance":false}' ;;
    check) printf '%s\n' '{"preflight":"passed","snapshot_installed":false}' ;;
    rollback) printf '%s\n' '{"recovered_previous_snapshot":true,"snapshot_installed":false}' ;;
esac
exit "$SUP_RC"
SH
    cat > "$CASE_ROOT/tools/date" <<'SHIM'
#!/bin/bash
[[ $# == 1 && $1 == +%Y%m%d ]] || exit 94
[[ $FAKE_DATE_RC == 0 ]] || exit "$FAKE_DATE_RC"
printf 'date\n' >> "$CASE_ROOT/logs/date-calls"
if [[ -f "$CASE_ROOT/clock-after-export" ]]; then
    cat "$CASE_ROOT/clock-after-export"
else
    printf '%s\n' "$FAKE_MAC_DATE"
fi
SHIM
    chmod +x "$CASE_ROOT/tools/date"
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
SKIP_NOTICE='Analytical refresh complete; Superset skipped: not configured'
for answer in $'n\n' $'\n' '' $'y\n'; do
    new_case "trim answer ${answer:-EOF}"
    run_case "$answer"
    check 'status zero' test "$RC" -eq 0
    if [[ $answer == y* ]]; then expected=$'trim\n'"$FULL"; else expected=$FULL; fi
    check 'one ordered import of each member, then one SUP call' order "$expected"
    check 'zero SUP arguments' contains "$CASE_ROOT/logs/sup-argc" '^0$'
    check 'analytical completion on stderr' contains "$CASE_ROOT/stderr" '[Aa]nalytical.*(complet|succeed)'
done

# R.1: truly unset configuration is analytical-only success. Missing executable
# and broken mapping cases prove the wrapper does not even resolve SUP/bin.
for availability in present missing nonexecutable unresolvable; do
    new_case "unset settings with $availability delegate"
    unset SUPERSET_SNAPSHOT_SETTINGS
    case "$availability" in
        missing) rm "$CASE_ROOT/bin/sync-superset" ;;
        nonexecutable) chmod -x "$CASE_ROOT/bin/sync-superset" ;;
        unresolvable) BIN_RESOLVE_RC=88 ;;
    esac
    run_case $'n\n'
    check 'analytical-only status zero' test "$RC" -eq 0
    check 'each analytical member once and no SUP call' order "$ANALYTICAL"
    check 'no bin/SUP resolution' absent "$CASE_ROOT/logs/resolutions" '^(bin|sup)$'
    printf '%s\n' "$SKIP_NOTICE" > "$CASE_ROOT/expected-notice"
    check 'exact notice on stderr only' cmp -s "$CASE_ROOT/expected-notice" "$CASE_ROOT/stderr"
    check 'no synthetic installation stdout' test ! -s "$CASE_ROOT/stdout"
    check 'no snapshot invocation evidence' test ! -e "$CASE_ROOT/logs/sup-argc"
done

# R.1b: unset env var with the standard default settings file present must
# delegate with the default path exported — the env var is an override, not a
# requirement. The file is removed afterwards so later unset cases still skip.
DEFAULT_SETTINGS="$HOME/.config/superset-snapshot/settings.json"
new_case 'unset settings with default file present'
unset SUPERSET_SNAPSHOT_SETTINGS
mkdir -p "${DEFAULT_SETTINGS%/*}"
printf '{}\n' > "$DEFAULT_SETTINGS"
run_case $'n\n'
check 'default-file run succeeds' test "$RC" -eq 0
check 'delegates exactly once after imports' order "$FULL"
check 'no skip notice with default file' absent "$CASE_ROOT/stderr" "^$SKIP_NOTICE\$"
check 'default path exported to SUP' contains "$CASE_ROOT/logs/sup-settings" "^$DEFAULT_SETTINGS\$"
rm -f "$DEFAULT_SETTINGS"

for settings in empty missing malformed whitespace; do
    new_case "present $settings settings"
    case "$settings" in
        empty) export SUPERSET_SNAPSHOT_SETTINGS='' ;;
        missing) export SUPERSET_SNAPSHOT_SETTINGS="$CASE_ROOT/does-not-exist.json" ;;
        malformed)
            export SUPERSET_SNAPSHOT_SETTINGS="$CASE_ROOT/malformed.json"
            printf '{broken synthetic json' > "$SUPERSET_SNAPSHOT_SETTINGS" ;;
        whitespace) export SUPERSET_SNAPSHOT_SETTINGS=' ' ;;
    esac
    run_case $'n\n'
    check 'invalid present setting fails validation' test "$RC" -eq 3
    check 'present setting delegates once after imports' order "$FULL"
    check 'validation diagnostic preserved' contains "$CASE_ROOT/stderr" '^SUP refusal: synthetic settings input invalid$'
    check 'invalid settings never silently skipped' absent "$CASE_ROOT/stderr" '^Analytical refresh complete; Superset skipped: not configured$'
done

# An unset optional stage must never convert an earlier error to success.
for stage in TRIM ALIAS GGMAP GG EXPORT eyedro pgdb purify; do
    new_case "unset settings and $stage failure"
    unset SUPERSET_SNAPSHOT_SETTINGS
    expected_rc=21
    input=$'n\n'
    case "$stage" in
        TRIM) TRIM_RC=21; input=$'y\n'; expected_rc=1 ;;
        ALIAS|GGMAP|GG|EXPORT) export "${stage}_RC=21" ;;
        *) FAIL_MEMBER=$stage; IMPORT_RC=21 ;;
    esac
    run_case "$input"
    check 'analytical failure remains nonzero with original status' test "$RC" -eq "$expected_rc"
    check 'no successful skip notice on failure' absent "$CASE_ROOT/stderr" '^Analytical refresh complete; Superset skipped: not configured$'
    check 'no SUP call after analytical failure' absent "$CALL_LOG" '^sup$'
    check 'no SUP resolution after analytical failure' absent "$CASE_ROOT/logs/resolutions" '^(bin|sup)$'
done

# Full-run date selection happens before trim/transport, once per invocation.
for prerequisite in missing-library legacy-library clock-failure; do
    new_case "$prerequisite before trim"
    expected_rc=3
    case "$prerequisite" in
        missing-library) rm "$CASE_ROOT/sync/sync-lib.sh" ;;
        legacy-library) printf 'DATE_VAR=20260922; export DATE_VAR\n' > "$CASE_ROOT/sync/sync-lib.sh" ;;
        clock-failure) FAKE_DATE_RC=37; expected_rc=37 ;;
    esac
    run_case $'y\n'
    check 'date prerequisite status preserved' test "$RC" -eq "$expected_rc"
    check 'date prerequisite fails before any stage' test ! -s "$CALL_LOG"
    check 'date prerequisite never reaches remote' test ! -e "$CASE_ROOT/logs/remote-date"
done
for selected in default 20240229; do
    new_case "date pinning $selected"
    FAKE_MAC_DATE=20260922 FAKE_REMOTE_DATE=20260923 FAKE_AFTER_EXPORT_DATE=20260924
    if [[ $selected == default ]]; then expected_date=20260922;
    else export DATE_VAR=$selected; expected_date=$selected; fi
    run_case $'n\n'
    check 'pinned full run succeeds' test "$RC" -eq 0
    check 'remote assignment is selected date' contains "$CASE_ROOT/logs/remote-date" "^$expected_date$"
    check 'export uses selected date' contains "$CASE_ROOT/logs/export-date" "^$expected_date$"
    check 'import retains date after midnight' contains "$CASE_ROOT/logs/import-date" "^$expected_date$"
    check 'SUP still exactly once' order "$FULL"
    if [[ $selected == default ]]; then
        check 'default clock read exactly once' test "$(wc -l < "$CASE_ROOT/logs/date-calls" | tr -d ' ')" = 1
    else
        check 'override never reads clock' test ! -e "$CASE_ROOT/logs/date-calls"
    fi
done
for invalid in '' 20260229 20260431 '20260923;false' '$(false)' $'20260923\n'; do
    new_case 'invalid full-run date'
    export DATE_VAR=$invalid
    run_case $'y\n'
    check 'bad override exits 2 before trim/transport' test "$RC" -eq 2
    check 'bad override triggers no stage' test ! -s "$CALL_LOG"
    check 'bad override never reaches remote' test ! -e "$CASE_ROOT/logs/remote-date"
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
for mode in install check rollback warnings; do
    new_case "$mode JSON"
    SUP_MODE=$mode
    "$CASE_ROOT/bin/sync-superset" > "$CASE_ROOT/expected-json" 2>/dev/null
    : > "$CALL_LOG"
    run_case $'n\n'
    check 'requested action status preserved' test "$RC" -eq 0
    check 'configured action exactly once after analytical imports' order "$FULL"
    check 'no skip notice for configured action' absent "$CASE_ROOT/stderr" '^Analytical refresh complete; Superset skipped: not configured$'
    if [[ $mode == warnings ]]; then
        check 'semantic warning survives on stderr' contains "$CASE_ROOT/stderr" '^WARNING: synthetic source report order differs; values copied faithfully$'
    fi
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

for missing in 0 1; do
    new_case "actual export/import selected date with missing=$missing"
    real_import_fixture
    # Fixture already has a full old set (20260921). New export selection differs
    # from both simulated clocks, so falling back to either date is detectable.
    export DATE_VAR=20260923
    FAKE_MAC_DATE=20260922 FAKE_REMOTE_DATE=20260924 FAKE_AFTER_EXPORT_DATE=20260925
    DATE_EXPORT_ACTUAL=1 DROP_FRESH=$missing
    mkdir -p "$CASE_ROOT/source-pgui/data"
    cp "$CASE_ROOT/make/data/dml-ast.json" "$CASE_ROOT/source-pgui/data/dml-ast.json"
    cp "$CASE_ROOT/make/data/ddl-ast.json" "$CASE_ROOT/source-pgui/data/ddl-ast.json"
    for script in export-all.sh export-eyedro.sh export-pgdb.sh export-purify.sh; do
        cp "$REPO/$script" "$CASE_ROOT/sync/$script"
    done
    cp "$REPO/tests/shims/pg_dump" "$CASE_ROOT/tools/pg_dump"
    run_case $'n\n'
    check 'old complete set remains present' test -s "$SYNC_REMOTE_EXPORT_DATA/pg2-pgdb-20260921.tgz"
    check 'fresh export child archive exists' test -s "$SYNC_REMOTE_EXPORT_DATA/pg2-eyedro-pgdump-20260923.tgz"
    check 'no remote-clock archive chosen' test ! -e "$SYNC_REMOTE_EXPORT_DATA/pg2-eyedro-pgdump-20260924.tgz"
    check 'remote export passed explicit override' contains "$CASE_ROOT/logs/remote-date" '^20260923$'
    if [[ $missing == 0 ]]; then
        check 'actual round trip succeeds' test "$RC" -eq 0
        check 'fresh date in Mac import manifest' contains "$SYNC_MANIFEST" 'pg2-pgdb-20260923.tgz[|]OK'
        check 'no older date downloads' absent "$SHIM_LOG_DIR/scp.log" '20260921'
        check 'single export followed by single SUP call' order $'export\nsup'
    else
        check 'old complete set cannot satisfy missing fresh artifact' test "$RC" -eq 1
        check 'no download on mismatched generation' test ! -e "$SHIM_LOG_DIR/scp.log"
        check 'no replay or SUP on missing fresh date' order export
        check 'no database replay' test ! -e "$SHIM_LOG_DIR/psql.log"
    fi
done

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

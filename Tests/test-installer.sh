#!/bin/bash
# End-to-end installer tests.
#
# The installer rewrites Claude Code's settings.json, which is the one thing
# Ration does that can break someone else's setup. These run against throwaway
# directories via RATION_CLAUDE_DIR — never a real ~/.claude.
#
#   ./Tests/test-installer.sh

cd "$(dirname "$0")/.." || exit 1
BIN=build/Ration.app/Contents/MacOS/Ration
[ -x "$BIN" ] || { echo "build first: ./build.sh"; exit 1; }

pass=0; fail=0
ok() { printf '  \033[32mPASS\033[0m  %s\n' "$1"; pass=$((pass+1)); }
no() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; fail=$((fail+1)); }
check() { if [ "$2" = "$3" ]; then ok "$1"; else no "$1"; printf '        expected [%s]\n        actual   [%s]\n' "$3" "$2"; fi; }

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

# Runs the app against a fresh copy of one settings fixture.
setup_case() {
    CASE="$WORK/$1"; rm -rf "$CASE"; mkdir -p "$CASE"
    [ -n "$2" ] && cp "Tests/Fixtures/settings/$2.json" "$CASE/settings.json"
    export RATION_CLAUDE_DIR="$CASE"
}
cmd() { python3 -c "
import json,sys
try: d=json.load(open('$CASE/settings.json'))
except Exception: print('<unparseable>'); sys.exit()
print((d.get('statusLine') or {}).get('command','<none>'))"; }

echo "TEST 1 — a user with their own status line"
setup_case custom custom
check "detected as theirs" "$($BIN --status)" "unwrapped: bash ~/.claude/statusline.sh"
$BIN --install > /dev/null
check "now wrapped" "$($BIN --status)" "wrapped"
check "their command preserved, shell-quoted" "$(cmd)" "bash $CASE/claude-usage-tap.sh 'bash ~/.claude/statusline.sh'"
check "tap script installed" "$([ -x "$CASE/claude-usage-tap.sh" ] && echo yes)" "yes"
check "settings backed up" "$(ls "$CASE" | grep -c ration-backup)" "1"
echo

echo "TEST 2 — installing twice is harmless"
BEFORE=$(cmd); $BIN --install > /dev/null
check "no double wrap" "$(cmd)" "$BEFORE"
echo

echo "TEST 3 — uninstall restores exactly what was there"
$BIN --uninstall > /dev/null
check "their command is back" "$(cmd)" "bash ~/.claude/statusline.sh"
check "tap script removed" "$([ -e "$CASE/claude-usage-tap.sh" ] || echo gone)" "gone"
check "state is theirs again" "$($BIN --status)" "unwrapped: bash ~/.claude/statusline.sh"
echo

echo "TEST 4 — round trip preserves unrelated settings"
setup_case roundtrip custom
ORIG=$(python3 -c "import json;print(json.dumps(json.load(open('$CASE/settings.json')),sort_keys=True))")
$BIN --install > /dev/null; $BIN --uninstall > /dev/null
AFTER=$(python3 -c "import json;print(json.dumps(json.load(open('$CASE/settings.json')),sort_keys=True))")
check "settings are semantically identical" "$AFTER" "$ORIG"
echo

echo "TEST 5 — a user with no status line at all"
setup_case none none
check "detected as unconfigured" "$($BIN --status)" "not configured"
$BIN --install > /dev/null
check "the tap runs alone" "$(cmd)" "bash $CASE/claude-usage-tap.sh"
$BIN --uninstall > /dev/null
check "no orphan status line left behind" "$($BIN --status)" "not configured"
echo

echo "TEST 6 — a settings file we cannot parse is never written"
setup_case malformed malformed
BEFORE=$(cat "$CASE/settings.json")
check "detected as unreadable" "$($BIN --status)" "unreadable"
if $BIN --install > /dev/null 2>&1; then RC=0; else RC=1; fi
check "install exits non-zero" "$RC" "1"
AFTER=$(cat "$CASE/settings.json")
check "the file is untouched, byte for byte" "$AFTER" "$BEFORE"
check "no tap was installed" "$([ -e "$CASE/claude-usage-tap.sh" ] || echo none)" "none"
echo

echo "TEST 7 — the installed tap matches the one in the repo"
# The script is compiled into the binary, so it can silently drift from the
# file the shell tests exercise.
setup_case tapcopy custom
$BIN --install > /dev/null
if cmp -s "$CASE/claude-usage-tap.sh" tap/claude-usage-tap.sh; then
    ok "byte-identical to tap/claude-usage-tap.sh"
else
    no "installed tap differs from tap/claude-usage-tap.sh"
fi
check "and is executable" "$([ -x "$CASE/claude-usage-tap.sh" ] && echo yes)" "yes"
echo

echo "TEST 8 — the backup inherits the original's permissions"
# settings.json may hold environment variables and permission rules; a user who
# restricted it has not consented to a world-readable copy.
setup_case perms custom
chmod 600 "$CASE/settings.json"
$BIN --install > /dev/null
BACKUP=$(ls "$CASE"/*ration-backup* 2>/dev/null | head -1)
check "backup is 0600 like the original" "$(stat -f '%Lp' "$BACKUP")" "600"
echo

echo "TEST 9 — a refresh interval the user chose is not slowed down"
setup_case fast fast-refresh
$BIN --install > /dev/null
INTERVAL=$(python3 -c "
import json;print(json.load(open('$CASE/settings.json'))['statusLine']['refreshInterval'])")
check "their 2s survives" "$INTERVAL" "2"
echo

echo "TEST 10 — the wrapped status line still renders identically"
setup_case render custom
printf '#!/bin/bash\nexec /usr/bin/wc -c\n' > "$CASE/inner.sh"; chmod +x "$CASE/inner.sh"
cp tap/claude-usage-tap.sh "$CASE/claude-usage-tap.sh"; chmod +x "$CASE/claude-usage-tap.sh"
FIX=Tests/Fixtures/healthy.json
BARE=$(bash "$CASE/inner.sh" < "$FIX")
WRAPPED=$(CLAUDE_USAGE_SNAPSHOT="$CASE/snap.json" bash "$CASE/claude-usage-tap.sh" "bash $CASE/inner.sh" < "$FIX")
check "byte-identical output" "$WRAPPED" "$BARE"
echo

echo "TEST 11 — the login item is a path-keyed LaunchAgent"
# Ad-hoc signed apps are identified by binary hash, so an SMAppService
# registration stops matching the app on every rebuild. A plist is keyed on the
# path, which Homebrew's opt symlink keeps stable across upgrades.
setup_case login custom
export RATION_LAUNCH_AGENTS_DIR="$CASE/LaunchAgents"
$BIN --install > /dev/null
PLIST="$RATION_LAUNCH_AGENTS_DIR/com.polgarp.ration.plist"
check "not enabled by default" "$([ -e "$PLIST" ] || echo absent)" "absent"

$BIN --login-on > /dev/null
check "written on request" "$([ -f "$PLIST" ] && echo yes)" "yes"
check "is a valid plist" "$(plutil -lint "$PLIST" >/dev/null 2>&1 && echo ok)" "ok"
check "label matches" "$(/usr/libexec/PlistBuddy -c 'Print :Label' "$PLIST")" "com.polgarp.ration"
check "runs at load" "$(/usr/libexec/PlistBuddy -c 'Print :RunAtLoad' "$PLIST")" "true"
# Keyed on the path, which is the whole point: a rebuild changes the binary's
# hash but not where it lives.
TARGET=$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:0' "$PLIST")
check "points at an executable that exists" "$([ -x "$TARGET" ] && echo yes)" "yes"

# Undo Setup must take it with it, so nothing of ours survives a removal.
$BIN --uninstall > /dev/null
check "removed by uninstall" "$([ -e "$PLIST" ] || echo gone)" "gone"
unset RATION_LAUNCH_AGENTS_DIR
echo

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

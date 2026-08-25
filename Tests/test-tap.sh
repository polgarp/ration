#!/bin/bash
# Tests for tap/claude-usage-tap.sh
#
# The headline test is transparency: whatever status line you already had must
# produce byte-identical output when wrapped. This suite runs against the real
# ~/.claude/statusline.sh when present, falling back to a stub.
#
#   ./Tests/test-tap.sh

cd "$(dirname "$0")/.." || exit 1

TAP=tap/claude-usage-tap.sh
WORK=$(mktemp -d)
export CLAUDE_USAGE_SNAPSHOT="$WORK/usage-snapshot.json"
trap 'rm -rf "$WORK"' EXIT

pass=0
fail=0
ok()   { printf '  \033[32mPASS\033[0m  %s\n' "$1"; pass=$((pass+1)); }
no()   { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; fail=$((fail+1)); }
check() { if [ "$2" = "$3" ]; then ok "$1"; else no "$1"; printf '        expected [%s]\n        actual   [%s]\n' "$3" "$2"; fi; }

# The status line under test. Real one if it exists, else a stub that proves
# the payload arrived intact.
if [ -x "$HOME/.claude/statusline.sh" ] || [ -f "$HOME/.claude/statusline.sh" ]; then
    INNER="bash $HOME/.claude/statusline.sh"
    echo "inner status line: ~/.claude/statusline.sh"
else
    printf '#!/bin/bash\nwc -c\n' > "$WORK/stub.sh"
    INNER="bash $WORK/stub.sh"
    echo "inner status line: stub (wc -c)"
fi
echo

echo "TEST 1 — transparency: wrapped output == bare output"
for f in Tests/Fixtures/*.json; do
    bare=$(sh -c "$INNER" < "$f" 2>/dev/null; printf 'rc=%s' "$?")
    wrapped=$(bash "$TAP" "$INNER" < "$f" 2>/dev/null; printf 'rc=%s' "$?")
    check "$(basename "$f")" "$wrapped" "$bare"
done
echo

echo "TEST 2 — snapshot is byte-identical to the payload"
rm -f "$CLAUDE_USAGE_SNAPSHOT"
bash "$TAP" "$INNER" < Tests/Fixtures/healthy.json > /dev/null 2>&1
if cmp -s "$CLAUDE_USAGE_SNAPSHOT" Tests/Fixtures/healthy.json; then
    ok "snapshot matches fixture byte for byte"
else
    no "snapshot differs from fixture"
fi
echo

echo "TEST 3 — snapshot is created 0600"
mode=$(stat -f '%Lp' "$CLAUDE_USAGE_SNAPSHOT" 2>/dev/null)
check "file mode" "$mode" "600"
echo

echo "TEST 4 — no temp files left behind"
count=$(find "$WORK" -name '*.tmp' | wc -l | tr -d ' ')
check "temp file count" "$count" "0"
echo

echo "TEST 5 — survives an unwritable snapshot path"
# The wrapped status line must still run even when saving is impossible.
out=$(CLAUDE_USAGE_SNAPSHOT=/nonexistent-root-dir/nope.json \
      bash "$TAP" "$INNER" < Tests/Fixtures/healthy.json 2>/dev/null)
expected=$(sh -c "$INNER" < Tests/Fixtures/healthy.json 2>/dev/null)
check "status line still renders" "$out" "$expected"
echo

echo "TEST 6 — exit code of the wrapped command passes through"
rc=$(bash "$TAP" 'exit 42' < Tests/Fixtures/healthy.json 2>/dev/null; echo $?)
check "exit code" "$rc" "42"
echo

echo "TEST 7 — no wrapped command: saves payload, prints nothing"
rm -f "$CLAUDE_USAGE_SNAPSHOT"
out=$(bash "$TAP" < Tests/Fixtures/healthy.json 2>/dev/null)
check "stdout is empty" "$out" ""
if cmp -s "$CLAUDE_USAGE_SNAPSHOT" Tests/Fixtures/healthy.json; then
    ok "payload still saved"
else
    no "payload not saved"
fi
echo

echo "TEST 8 — shell operators survive wrapping"
# statusLine.command runs in a shell, so the wrapped string may contain
# pipelines, && and $(). Exec'ing its first word would restructure them.
for CMD in 'printf hello | tr a-z A-Z' \
           'true && printf chained' \
           'printf "%s" "$(printf substituted)"' \
           "printf 'quoted arg'"; do
    bare=$(sh -c "$CMD" < Tests/Fixtures/healthy.json 2>/dev/null)
    wrapped=$(bash "$TAP" "$CMD" < Tests/Fixtures/healthy.json 2>/dev/null)
    check "$CMD" "$wrapped" "$bare"
done
echo

printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

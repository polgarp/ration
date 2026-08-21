#!/bin/bash
#
# claude-usage-tap — saves Claude Code's status line payload for the menu bar
# app, then hands the payload on to whatever status line you already had.
#
#   Usage:  claude-usage-tap.sh [your original status line command ...]
#
# Wrapping is transparent: the wrapped command receives the exact same bytes on
# stdin that Claude Code sent, and its stdout/stderr/exit code pass through
# untouched. If anything here fails, the wrapped command still runs. Breaking
# your status line is never an acceptable outcome for this script.
#
# Deliberately does no JSON parsing: it runs on Claude Code's 300ms status line
# debounce, so it avoids jq (absent on stock macOS) and any interpreter spawn.
# The menu bar app parses the payload, and uses the file's mtime as the
# capture time — so there is no timestamp to write here either.
#
# NOTE: the saved payload is the full status line JSON, which includes your
# current working directory, session id, and model. It is the same data Claude
# Code already stores in ~/.claude. The file is created 0600.

SNAPSHOT="${CLAUDE_USAGE_SNAPSHOT:-$HOME/.claude/usage-snapshot.json}"

# Read all of stdin, newlines intact, without forking `cat`. Returns non-zero
# at EOF while still populating the variable, hence the `|| :`.
IFS= read -r -d '' payload || :

# Save it. Every failure here is swallowed on purpose.
{
    dir=${SNAPSHOT%/*}
    [ -d "$dir" ] || mkdir -p "$dir"
    tmp="$SNAPSHOT.$$.tmp"
    # umask in a subshell so the temp file is born 0600 and the wrapped
    # command never inherits a modified umask.
    ( umask 077; printf '%s' "$payload" > "$tmp" ) && mv -f "$tmp" "$SNAPSHOT"
} 2>/dev/null || :

# Hand off to the original status line, if there was one.
[ $# -eq 0 ] && exit 0
printf '%s' "$payload" | "$@"

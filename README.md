# Ration

A macOS menu bar meter for Claude Code usage — and the only one that tells you
whether you're burning the week faster than the week is passing.

![Ration in the menu bar](docs/menubar.png)

```
Week runs out Sat 10:27
──────────────────────────────
Week      12% used · +3 ahead of pace
          resets Mon 01:00
Session   81% used
          resets today 17:50
──────────────────────────────
● Claude Code operational
Updated just now
```

Claude Code's status line already shows your session usage. Ration adds the two
things it can't: whether you're ahead of the week's pace, and — when a session
runs dry — the time you can start again.

## Install

Needs macOS 13+, Claude Code, and a Claude Pro or Max subscription.

1. Download `Ration.app` from [Releases](../../releases), drag to `/Applications`.
2. Ration isn't notarised yet, so Gatekeeper blocks the first launch. Open it,
   then go to **System Settings → Privacy & Security**, find Ration under
   *Security* near the bottom, and click **Open Anyway**. Once only.
   *(On macOS 13–14 you can Control-click the app and choose Open instead;
   [Sequoia removed that shortcut](https://mjtsai.com/blog/2024/07/05/sequoia-removes-gatekeeper-contextual-menu-override/).)*
3. Menu bar item → **Set up Ration…** It shows the exact change it will make to
   `settings.json` before touching anything.
4. Optional: menu bar item → **Open at Login**, so it comes back after a reboot.

## How it works

Ration reads the documented
[`rate_limits`](https://code.claude.com/docs/en/statusline) from Claude Code's
status line. No API calls, no cookie, no token.

Setup wraps whatever status line command you already have:

```jsonc
// before
"command": "bash ~/.claude/statusline.sh"
// after
"command": "bash ~/.claude/claude-usage-tap.sh bash ~/.claude/statusline.sh"
```

The tap saves the payload and passes the same bytes to your original command,
which keeps rendering byte-identically. It installs to `~/.claude/`, not inside
the app bundle, so deleting Ration can't break your status line.

## Privacy

- **`~/.claude/usage-snapshot.json`** holds the status line payload, which
  includes your working directory, session id and model — the same data Claude
  Code already keeps in the same folder. Created `0600`, never leaves the
  machine.
- **One network call**: `status.claude.com/api/v2/summary.json` every 5 minutes,
  for the service health row. Public and unauthenticated — nothing about you in
  the request.
- Nothing else. No analytics, no telemetry, no update pings.

## Uninstall

Menu bar item → **Remove Ration's status line hook…** Your command is restored
exactly as it was; the tap and saved usage data are deleted. `settings.json` is
backed up before either change.

## Limitations

- Only sees Claude Code. Usage from the desktop app and claude.ai counts against
  the same budgets but is invisible here.
- Per-model buckets (Opus, Fable, overage) are rendered from undocumented fields
  that could change.
- `rate_limits` refreshes only after an API response, so a window can outlive
  its payload. Ration says "waiting for a fresh reading" rather than guessing.

## Building

Needs only Xcode Command Line Tools.

```bash
./build.sh                  # -> build/Ration.app, universal
./run-tests.sh              # unit tests
./Tests/test-tap.sh         # status line transparency
./Tests/test-installer.sh   # settings.json rewriting
```

`Ration --dump` prints what the menu would say. There's no `swift test` —
XCTest needs a full Xcode install, so the harness is 40 lines instead.

## License

MIT. Unofficial and unaffiliated; see [NOTICE.md](NOTICE.md) — this project
ships no Anthropic branding and none may be added.

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

## Why

Claude Code's own status line already shows your session usage while you work.
What it can't tell you is the two things that actually change what you do next:

- **Are you ahead of pace?** 84% of your week gone sounds alarming on a Tuesday
  and unremarkable on a Sunday. Ration divides usage by *elapsed* time and, when
  you're on course to hit the cap, names the day: *"Week runs out Sat 10:27."*
- **When are you back?** When a session runs dry, the one thing you want is the
  time you can start again — and that's exactly when Claude Code isn't open to
  tell you.

## Install

Requires macOS 13+, Claude Code, and a Claude Pro or Max subscription (rate
limit data isn't served for API-key auth).

1. Download `Ration.app` from [Releases](../../releases) and drag it to
   `/Applications`.
2. **Right-click → Open** the first time. Ration is not notarised yet, so
   double-clicking gets you Gatekeeper's "unidentified developer" refusal.
   Signing is on the roadmap; it needs a paid Apple Developer account.
3. Click the menu bar item → **Set up Ration…** It shows you the exact change it
   will make to `~/.claude/settings.json` before touching anything.

Usage appears within a few seconds. Existing Claude Code sessions pick it up on
their next status line refresh.

## How it works

Ration reads the same data Claude Code's status line does — the documented
[`rate_limits`](https://code.claude.com/docs/en/statusline) object. It makes no
API calls to Anthropic and needs no cookie or token.

```
Claude Code ──stdin JSON──▶ claude-usage-tap.sh ──┬──▶ usage-snapshot.json
                                                  │
                                                  └──▶ your original status line
                                                       (renders unchanged)
```

Setup wraps whatever status line command you already have:

```jsonc
// before
"command": "bash ~/.claude/statusline.sh"

// after
"command": "bash ~/.claude/claude-usage-tap.sh bash ~/.claude/statusline.sh"
```

The tap reads stdin once, saves the payload, and passes the same bytes to your
original command. Your status line renders **byte-identically** — there's a test
for that. It parses nothing, so it needs no `jq` and spawns no interpreter
inside Claude Code's 300 ms status line debounce; it costs about 7 ms.

It installs to `~/.claude/`, deliberately not inside the app bundle: if it lived
in the bundle, deleting Ration would break your status line.

## Privacy

- **The usage snapshot** at `~/.claude/usage-snapshot.json` is the full status
  line payload, which includes your working directory, session id and model.
  That's the same data Claude Code already keeps in the same folder. It's
  created `0600` and never leaves your machine.
- **One network call**: `status.claude.com/api/v2/summary.json`, every 5
  minutes, for the service health row. It's public and unauthenticated — no
  cookie, no token, nothing about you in the request.
- Nothing else. No analytics, no telemetry, no update pings.

## Uninstall

Menu bar item → **Remove Ration's status line hook…**

Your own command is restored exactly as it was, and the tap script and saved
usage data are deleted. `settings.json` is backed up before either change.

## Building from source

Needs only Xcode **Command Line Tools** — no Xcode.

```bash
git clone https://github.com/polgarp/ration.git
cd ration
./build.sh          # -> build/Ration.app, universal (arm64 + x86_64)
./run-tests.sh      # Swift unit tests
./Tests/test-tap.sh         # status line transparency
./Tests/test-installer.sh   # settings.json rewriting, against fixtures
```

There's no `swift test`: XCTest requires a full Xcode install, and asking
contributors for 10 GB to run a few assertions is a poor trade. The harness is
40 lines in `Tests/Harness.swift`.

`Ration --dump` prints what the menu would say, which is how states get checked
without clicking anything.

## Known limitations

- **Only sees Claude Code.** Your 5-hour and weekly budgets are shared with the
  desktop app and claude.ai, but the status line only runs while Claude Code
  does. Usage from elsewhere is invisible, and the reading dims and says
  "Claude Code not running" rather than pretending to be current.
- **Per-model buckets are undocumented.** Ration renders `seven_day_opus`,
  `seven_day_sonnet` and `model_scoped` buckets under whatever label the server
  supplies, so a new bucket (Fable, overage) needs no release — but these fields
  aren't in the docs and could change.
- **`resets_at` can be in the past.** Claude Code refreshes `rate_limits` only
  after an API response, so a window can outlive its payload. Ration says
  "waiting for a fresh reading" rather than doing arithmetic over a window that
  no longer exists.
- **Every Claude Code session writes the same snapshot file.** A session idle for
  days rebroadcasts expired windows on its own timer. Ration treats `resets_at`
  as a version number and keeps whichever reading is genuinely newest.

## License

MIT — see [LICENSE](LICENSE).

Unofficial and unaffiliated. See [NOTICE.md](NOTICE.md) for the trademark
position: this project ships no Anthropic branding, and none may be added.

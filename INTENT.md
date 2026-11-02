# Ration — open intent

A description of Ration you can hand to a coding agent to build your own, on
whatever platform you use. The [source](README.md) is one way of doing it, as a
macOS menu bar app. This page is the part worth keeping if you'd rather build
your own.

| | |
|---|---|
| Reference build | macOS, Swift, ~1,800 lines + ~1,100 lines of tests |
| Built in | 6 days with Claude Code (21–26 August 2026) |
| Needs | Claude Code with a Pro or Max subscription |
| Estimated agent cost | ~$30 at Opus 5.5 API prices (~25M tokens, mostly cache reads). Original build was ~15% of a Claude Pro week, August 2026 |

## The problem

A Claude subscription has two usage windows: a 5-hour **session** and a 7-day
**week**. Claude Code's status line already shows the session. Nothing tells you
the two things you actually plan around:

1. **Am I ahead of the week's pace?** 40% used is fine on Saturday and alarming
   on Tuesday.
2. **When do I get the session back** once it has run dry?

## The outcome

An ambient indicator you can read at a glance, without switching windows,
showing how much of the week is used. When the session is spent, the time until
it resets appears next to it. A detail view gives the conclusion in words, then
every window as *used / when it resets*.

## Where the data comes from

Claude Code pipes a JSON payload to the status line command on every refresh.
The documented
[`rate_limits`](https://code.claude.com/docs/en/statusline) field holds
`five_hour` and `seven_day`, each with `used_percentage` (0–100) and
`resets_at` (epoch seconds). It only appears for Pro/Max, only after the first
API response, and either window can be missing.

There are also undocumented per-model buckets (`seven_day_opus`,
`seven_day_sonnet`, and `model_scoped`, which has a server-supplied
`display_name`, `utilization` as a 0–1 fraction, and `resets_at` as an ISO
string). Show whatever buckets turn up, labelled as the server labels them, and
depend on none of them.

## Approach

Two pieces:

- **A tap.** A tiny script that wraps the user's existing status line command.
  It saves the payload to a file, then passes the identical bytes on to the
  original command.
- **A reader.** The indicator. It watches that file, parses it, and renders.

## Decisions that took the longest

These are the parts an agent won't arrive at on its own. Keep them.

**The tap must never break the status line.** The original command is a shell
string, possibly with pipes and `&&`. Store it as one quoted argument and run
it with a shell; never split it. Swallow every failure in the save step. Write
atomically (temp file, then rename), owner-only permissions. Don't parse JSON in
the tap: it runs on a ~300 ms debounce, so avoid spawning interpreters. Use the
file's modification time as the capture time.

**You are editing a stranger's `settings.json`.** Three rules, each worth a
test: never write what you couldn't parse; never lose their command (wrapping
prefixes it, unwrapping restores it exactly); never undo a choice they made
(add `refreshInterval` only if unset, and remember that *you* added it, so
uninstall removes only what it added). Back the file up first, and show the
exact change before applying it. Install the tap outside the app, so deleting
the app can't break anyone's status line.

**Newest beats last.** Every Claude Code session writes the same file, and idle
sessions keep rebroadcasting windows that have already expired. Judge each
window on its own: a later `resets_at` wins; on a tie, the higher usage wins,
because usage only climbs. Last-write-wins lets an idle session drag the week
backwards.

**Freshness is two questions.** *Is Claude Code running?* turns on any write.
*How old are these numbers?* turns on writes you accepted. Treat silence of
around 90 seconds as "not running".

**Windows outlive their payloads.** `rate_limits` only refreshes after an API
call. Once `resets_at` has passed, say the window has reset and you're waiting
for a fresh reading. Never guess the new value. Data that can't be read becomes
*absent*, never zero.

**Pace.** Elapsed share of the week = (now − (`resets_at` − 7 days)) / 7 days.
Pace = used − elapsed. Say nothing in the first ~1% of the week (you'd be
dividing by almost zero), and allow ±1 point before calling it ahead or behind.
Only project a run-out date when over pace, by extending the current rate
linearly.

## Interface concepts

- **Count used, not remaining**, so that a fill and its number move the same way.
- **The week owns the main slot.** The session countdown is *added* when the
  session is spent (≥99%), never swapped in: a slot that changes units can't be
  read at a glance. Show the countdown as a duration; a bare time next to the
  system clock reads as a second clock.
- **The headline names its window.** "Week on pace", "Week runs out Thursday",
  "Session resumes 14:20", not a bare "Comfortable". If Claude itself is down
  (optional: the public `status.claude.com/api/v2/summary.json`), that headline
  goes first.
- **Give screen readers a sentence.** "Week 42 percent used, 8 ahead of pace",
  not "42%".

## Yours to decide

Where the indicator lives (menu bar, tray, desktop widget, terminal prompt
segment), starting at login, packaging, clock format, and how it draws.

## Privacy

The payload includes the working directory, session id and model. Keep it
local and owner-only. The only network call worth making is the optional,
unauthenticated status page. No telemetry.

## Known limits

It only sees Claude Code. Usage from the desktop app and claude.ai counts
against the same budgets but is invisible here. The per-model buckets are
undocumented and may change.

## Tests worth writing

- The installer, against fixture files: unparseable settings, a status line
  given as a bare string, already wrapped, wrapped under an equivalent spelling
  (`/bin/bash` vs `bash`).
- The tap passes stdin through byte-for-byte, including to pipelines.
- An idle session's expired payload can't drag the week backwards.
- Pace at the very start of the week, exactly on pace, and one point over.

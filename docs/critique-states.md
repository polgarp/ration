# Critique — states and information hierarchy

Phase 4 design pass, run against the three use cases as stated:

1. **Weekly pace** — how am I doing relative to elapsed time
2. **Session reset** — when am I back, so I don't have to keep opening Claude Code
3. **Session usage** — how much of this window is left

The critical piece of context is that **use case 3 is already solved elsewhere.**
The Claude Code status line shows `5h:17%` and `ctx:12%` on screen the entire
time you are working. Anything the menu bar says about the session while Claude
Code is open is a second copy of a number you are already looking at.

---

## Anti-patterns verdict

Not applicable in the usual sense — this is native AppKit with system fonts,
semantic colours and a drawn template image. There is no palette to be generic
with. The one adjacent risk is **generic-utility syndrome**: a menu bar app that
lists every number it has access to, in the order the API returns them, and
calls that a design. The current dropdown is close to that. It reports Session,
then Week, then freshness, because that is the order the payload arrives in —
not because that is the order you need them.

## Overall impression

The plumbing is honest and the mark works. The **information hierarchy is
inverted**: the app leads with the number you already have and buries the two it
uniquely provides.

Worse, it currently contradicts itself.

---

## Priority issues

### 1. The glyph and the number describe different windows — CRITICAL

**What.** `MenuBarController` draws the disc from `sevenDay.usedPercentage`
(`Sources/App/MenuBarController.swift:65`) while `MenuModel.barTitle` reads
`fiveHour.usedPercentage` (`Sources/Core/MenuModel.swift:18`). A disc filled 4/5
sits next to "92%".

**Why it matters.** The two halves of a single menu bar item are making opposite
claims. A user reading the mark as a picture of the number is being actively
misinformed. This is not a polish issue; it is wrong.

**Fix.** Pick one window and make both halves report it. Given issues 2 and 3
below, that window should be **the week**.

### 2. The bar spends its one slot on the redundant number

**What.** The bar shows session remaining — the number already on screen in the
status line whenever Claude Code is running.

**Why it matters.** The menu bar item has room for roughly one number. Spending
it on a duplicate means the two things the menu bar uniquely knows — weekly pace
and time-to-reset — are both a click away, behind a menu you have to remember to
open.

**Fix.** Default the bar to **week remaining**, with the disc showing week spend
and the over-pace dot as the one-bit pace signal. That makes the mark and the
number agree, and puts the non-redundant number in the visible slot.

### 3. The asleep state dims the one thing that stays true

**What.** When Claude Code closes, the whole item greys out and the menu says
"Claude Code not running · 40m ago".

**Why it matters.** This is exactly backwards for use case 2. Consider the moment
that matters most: **you are rate-limited.** You cannot use Claude Code, so the
tap is not running, so the snapshot is stale — and Ration responds by dimming
everything and apologising.

But staleness does not affect all the data equally:

| value | when stale |
|---|---|
| `used_percentage` | degrades — genuinely unknown |
| `resets_at` | **still exact** — it is an absolute timestamp |

The countdown is the one number that survives being stale, and it is the number
you actually want at that moment. Ration currently treats it as equally suspect.

**Fix.** Split the treatment. Dim the percentages, because those really are
stale. **Promote the countdown**, because it is not. When the session is spent
and the app is asleep, the bar should read the time until you are back — not a
greyed-out percentage from an hour ago.

### 4. The dropdown reports rather than concludes

**What.** Six rows of numbers, no ranking. "99% left / 5 under pace / resets Mon
01:00" states three facts and draws no conclusion.

**Why it matters.** The whole premise of the pace metric is that it answers
"what should I do next?". A row that says `+15 ahead of pace` still leaves the
arithmetic to you.

**Fix.** Lead the dropdown with the conclusion in plain language — *"On track to
cap out Saturday evening"* or *"Comfortable — 2 days of headroom"* — and keep the
raw numbers beneath it for people who want to check the working.

### 5. The over-pace treatment resizes the item

**What.** The disc's halo sits outside the existing form, so the mark's bounding
box grows when pace flips.

**Why it matters.** The status item jumps sideways at the exact moment it is
trying to tell you something, and every icon to its left shifts with it. Motion
in the menu bar reads as a glitch.

**Fix.** Move the signal inside the footprint — a counter-punched centre, a
notch, or a weight change. Constant bounding box regardless of state.

---

## Minor observations

- **`Format.duration` loses resolution where it is needed most.** Past 24h it
  drops minutes, which is right — but under an hour it shows only minutes, so a
  session resetting in 40 seconds reads "0m". Add a seconds case near zero.
- **Three-window ambiguity.** "Session" and "Week" are Ration's words; Claude
  Code calls them the 5-hour and 7-day limits. Worth matching their vocabulary
  so the numbers are obviously the same numbers.
- **"Waiting for Claude Code…" is not actionable** for someone who has not
  installed the tap. That is the unconfigured state and it needs a different
  message — a setup instruction, not a progress note.

## Questions worth sitting with

- **If the status line already covers the session while you work, is Ration
  fundamentally a "when am I back" tool rather than a "how am I doing" tool?**
  The two framings produce different products. The current build hedges.
- **Should the bar change what it shows by state at all**, or is a stable
  meaning worth more than a contextually optimal one? A menu bar item that
  changes its unit is harder to read at a glance, even when each individual
  reading is better chosen.
- **What is the quietest useful version?** When you have plenty of headroom and
  are on pace, the honest answer is that Ration has nothing to say. Should it
  nearly disappear?

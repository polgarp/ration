#!/usr/bin/env python3
"""Generates the mark review page, with specimens embedded so it stands alone."""

import base64
import pathlib

HERE = pathlib.Path(__file__).parent


def uri(name):
    data = base64.b64encode((HERE / name).read_bytes()).decode()
    return f"data:image/png;base64,{data}"


HTML = """<title>Ration's Menu Bar Mark</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Archivo:wght@500;600;700&family=Source+Serif+4:ital,opsz,wght@0,8..60,400;0,8..60,600;1,8..60,400&family=JetBrains+Mono:wght@400;600&display=swap">
<style>
  /* Light palette is the base. Graphite with a cool bias, ration-book ochre
     as the single accent — the ground stays neutral so the specimens, which
     are pure black or pure white silhouettes, are never fighting a tint. */
  :root {
    --ground:      #FBFBFC;
    --surface:     #F1F2F4;
    --surface-2:   #E7E8EC;
    --ink:         #17181C;
    --ink-muted:   #6A6D76;
    --rule:        #DCDEE3;
    --accent:      #9A6A16;
    --accent-soft: #F2E7D0;
    --bad:         #9B3B2E;
    --light-display: block;
    --dark-display:  none;

    --measure: 66ch;
    --step--1: 0.83rem;
    --step-0:  1.0625rem;
    --step-1:  1.35rem;
    --step-2:  1.85rem;
    --step-3:  2.6rem;
  }
  @media (prefers-color-scheme: dark) {
    :root:not([data-theme="light"]) {
      --ground:      #131417;
      --surface:     #1C1E22;
      --surface-2:   #26282E;
      --ink:         #EDEEF1;
      --ink-muted:   #93969F;
      --rule:        #2E3138;
      --accent:      #D9A441;
      --accent-soft: #33291628;
      --bad:         #D9705E;
      --light-display: none;
      --dark-display:  block;
    }
  }
  :root[data-theme="dark"] {
    --ground:      #131417;
    --surface:     #1C1E22;
    --surface-2:   #26282E;
    --ink:         #EDEEF1;
    --ink-muted:   #93969F;
    --rule:        #2E3138;
    --accent:      #D9A441;
    --accent-soft: #33291628;
    --bad:         #D9705E;
    --light-display: none;
    --dark-display:  block;
  }

  *, *::before, *::after { box-sizing: border-box; }

  body {
    margin: 0;
    background: var(--ground);
    color: var(--ink);
    font-family: "Source Serif 4", Georgia, serif;
    font-size: var(--step-0);
    line-height: 1.65;
    -webkit-font-smoothing: antialiased;
  }

  .wrap {
    max-width: 74rem;
    margin: 0 auto;
    padding: clamp(2rem, 5vw, 4.5rem) clamp(1.1rem, 4vw, 3rem) 6rem;
    display: flex;
    flex-direction: column;
    gap: clamp(3rem, 6vw, 5rem);
  }

  h1, h2, h3, .label {
    font-family: Archivo, "Helvetica Neue", Arial, sans-serif;
    text-wrap: balance;
  }

  .label {
    font-size: var(--step--1);
    font-weight: 600;
    letter-spacing: 0.09em;
    text-transform: uppercase;
    color: var(--ink-muted);
  }

  header { display: flex; flex-direction: column; gap: 0.9rem; }
  h1 {
    font-size: var(--step-3);
    font-weight: 700;
    letter-spacing: -0.022em;
    line-height: 1.08;
    margin: 0;
  }
  .standfirst {
    max-width: var(--measure);
    font-size: var(--step-1);
    line-height: 1.5;
    color: var(--ink-muted);
    margin: 0;
  }

  section { display: flex; flex-direction: column; gap: 1.4rem; }
  h2 {
    font-size: var(--step-2);
    font-weight: 600;
    letter-spacing: -0.018em;
    margin: 0;
    display: flex;
    align-items: baseline;
    gap: 0.7rem;
  }
  /* Round numbers are a real sequence — round two exists because round one
     failed — so the numbering carries information rather than decorating. */
  h2 .n {
    font-family: "JetBrains Mono", ui-monospace, monospace;
    font-size: var(--step-0);
    font-weight: 600;
    color: var(--accent);
  }
  h3 {
    font-size: var(--step-0);
    font-weight: 600;
    letter-spacing: 0.005em;
    margin: 0;
  }
  p { margin: 0; max-width: var(--measure); }
  p + p { margin-top: 0.85rem; }

  .plate {
    background: var(--surface);
    border: 1px solid var(--rule);
    border-radius: 10px;
    padding: 0.75rem;
    overflow-x: auto;
  }
  .plate img { display: block; width: 100%; height: auto; border-radius: 5px; }
  .only-light { display: var(--light-display); }
  .only-dark  { display: var(--dark-display); }

  figcaption {
    font-size: var(--step--1);
    color: var(--ink-muted);
    margin-top: 0.6rem;
    max-width: var(--measure);
  }
  figure { margin: 0; }

  .findings { display: grid; gap: 0.9rem; padding: 0; margin: 0; list-style: none; }
  .findings li {
    display: grid;
    grid-template-columns: auto 1fr;
    gap: 0.85rem;
    align-items: start;
    max-width: var(--measure);
  }
  .findings .mk {
    font-family: "JetBrains Mono", ui-monospace, monospace;
    font-size: var(--step--1);
    font-weight: 600;
    color: var(--bad);
    line-height: 1.9;
  }

  table { border-collapse: collapse; width: 100%; font-size: var(--step--1); }
  .tablewrap { overflow-x: auto; }
  th, td {
    text-align: left;
    padding: 0.62rem 0.9rem 0.62rem 0;
    border-bottom: 1px solid var(--rule);
  }
  th {
    font-family: Archivo, sans-serif;
    font-weight: 600;
    font-size: 0.78rem;
    letter-spacing: 0.07em;
    text-transform: uppercase;
    color: var(--ink-muted);
  }
  td.num, th.num {
    font-family: "JetBrains Mono", ui-monospace, monospace;
    font-variant-numeric: tabular-nums;
    text-align: right;
    padding-right: 1.4rem;
  }
  tr.pick td { background: var(--accent-soft); }
  tr.pick td:first-child { box-shadow: inset 3px 0 0 var(--accent); padding-left: 0.8rem; }
  td strong { font-family: Archivo, sans-serif; font-weight: 600; }

  .verdicts { display: grid; gap: 1.1rem; grid-template-columns: repeat(auto-fit, minmax(17rem, 1fr)); }
  .verdict {
    border: 1px solid var(--rule);
    border-radius: 10px;
    padding: 1.1rem 1.15rem;
    background: var(--surface);
    display: flex;
    flex-direction: column;
    gap: 0.45rem;
  }
  .verdict.rec { border-color: var(--accent); background: var(--accent-soft); }
  .verdict p { font-size: var(--step--1); line-height: 1.55; }
  .tag {
    font-family: "JetBrains Mono", ui-monospace, monospace;
    font-size: 0.7rem;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: var(--accent);
    font-weight: 600;
  }

  hr { border: 0; border-top: 1px solid var(--rule); margin: 0; }

  @media (prefers-reduced-motion: no-preference) {
    .plate img { transition: none; }
  }
</style>

<div class="wrap">

  <header>
    <span class="label">Ration · Phase 4 · design review</span>
    <h1>The mark has 18 points to work with</h1>
    <p class="standfirst">Two rounds of menu bar marks, rendered at true size and photographed in the actual menu bar. One of them needs to be picked.</p>
  </header>

  <section>
    <h2><span class="n">00</span> The brief</h2>
    <p>The mark sits at 18&nbsp;points beside a percentage, as a <em>template image</em> — pure silhouette, tinted by the system, so it must work with no colour at all. It has to survive a light menu bar and a dark one, and it has to be readable next to a number that is already carrying the precision.</p>
    <p>The tempting ambition was to make the glyph encode Ration's whole idea: how much you have spent <em>and</em> whether you are ahead of the week's pace. Round one tested that.</p>
  </section>

  <hr>

  <section>
    <h2><span class="n">01</span> Two values in one glyph</h2>
    <p>Five marks, each carrying usage as a fill and pace as a positional marker — a tick, a hairline, a notch.</p>
    <figure>
      <div class="plate">
        <img class="only-light" src="__SHEET_LIGHT__" alt="Round one mark candidates on a light menu bar: ring, capsule, gauge, tally and wedge, each shown at four usage states, enlarged and at true size.">
        <img class="only-dark" src="__SHEET_DARK__" alt="Round one mark candidates on a dark menu bar: ring, capsule, gauge, tally and wedge, each shown at four usage states, enlarged and at true size.">
      </div>
      <figcaption>Each row is one candidate; each column a state. The grey chip under every mark is true menu bar size — the only size that counts.</figcaption>
    </figure>

    <h3>What it proved</h3>
    <ul class="findings">
      <li><span class="mk">01</span><span><strong>Two numbers don't fit in 18 points.</strong> Every pace marker collapses to two or three pixels. Worse, it stops reading as neutral — in the ring and the gauge it looks like a chip or a scratch, damage to the form rather than a target.</span></li>
      <li><span class="mk">02</span><span><strong>The wedge has its ink backwards.</strong> Monday — 98% left, the least urgent state there is — renders as a solid black disc, the heaviest mark possible. Nearly-out is a thin outline. It shouts when nothing is wrong.</span></li>
      <li><span class="mk">03</span><span><strong>The capsule borrowed a meaning I didn't choose.</strong> A pill with a line through it reads as a toggle, or as <em>disabled</em>. Connotation you don't pick works against you.</span></li>
    </ul>
    <p>So the rule for round two: <strong>fill grows as you spend</strong>, so ink tracks alarm — and pace becomes a single bit, because a state change survives at 18&nbsp;points where a position does not.</p>
  </section>

  <hr>

  <section>
    <h2><span class="n">02</span> One value, one bit</h2>
    <p>Four marks. Fill is how much of the week is gone; the extra element — dot, halo, lid — appears only when you are burning faster than the week is elapsing.</p>
    <figure>
      <div class="plate">
        <img class="only-light" src="__SHEET2_LIGHT__" alt="Round two mark candidates on a light menu bar: ring, disc, jar and bars, each at four states with the over-pace treatment visible in the last two.">
        <img class="only-dark" src="__SHEET2_DARK__" alt="Round two mark candidates on a dark menu bar: ring, disc, jar and bars, each at four states with the over-pace treatment visible in the last two.">
      </div>
      <figcaption>Columns three and four are over pace, so the dot, halo and lid appear there.</figcaption>
    </figure>

    <h3>Ink coverage</h3>
    <p>Measured, not eyeballed — what share of the canvas is opaque at each state. A big swing means the mark disappears when you have headroom and asserts itself when you don't, which is the behaviour a menu bar wants.</p>
    <div class="tablewrap">
      <table>
        <thead>
          <tr><th>Mark</th><th class="num">At 3% spent</th><th class="num">At 92% spent</th><th class="num">Swing</th></tr>
        </thead>
        <tbody>
          <tr><td><strong>Ring</strong></td><td class="num">0.8%</td><td class="num">26.9%</td><td class="num">34×</td></tr>
          <tr><td><strong>Disc</strong></td><td class="num">11.4%</td><td class="num">49.2%</td><td class="num">4.3×</td></tr>
          <tr><td><strong>Bars</strong></td><td class="num">8.7%</td><td class="num">28.1%</td><td class="num">3.2×</td></tr>
          <tr><td><strong>Jar</strong></td><td class="num">14.6%</td><td class="num">31.6%</td><td class="num">2.2×</td></tr>
        </tbody>
      </table>
    </div>
    <p>On this evidence the ring wins comfortably. It did not survive contact with the menu bar.</p>
  </section>

  <hr>

  <section>
    <h2><span class="n">03</span> In the actual menu bar</h2>
    <p>All four running at once as separate status items, so this is one photograph rather than four — same screen, same wallpaper, same moment. Each is showing roughly the same usage; the differing percentages are only there to identify which is which.</p>
    <figure>
      <div class="plate"><img src="__LIVE__" alt="A real macOS menu bar screenshot showing four Ration status items side by side: ring at 35%, bars at 32%, jar at 33%, disc at 34%."></div>
      <figcaption>Left to right: ring, bars, jar, disc. Shot at 2×, enlarged here; the marks are 18&nbsp;points on screen.</figcaption>
    </figure>
    <p>This is where the ranking changed. The ring's fill — a faint track against a solid arc — <strong>does not separate</strong> at this size against a mid-tone bar. It reads as a small circle with a dot in it, which is to say it reads as a record, or a shutter. The measurement was right about its ink range and wrong about whether that ink is <em>legible as a proportion</em>.</p>
  </section>

  <hr>

  <section>
    <h2><span class="n">04</span> The call</h2>
    <div class="verdicts">
      <div class="verdict rec">
        <span class="tag">Recommended</span>
        <h3>Disc</h3>
        <p>The only one that reads unmistakably as <em>a proportion</em> at true size — the pie is a shape everyone already knows how to decode. Heaviest at rest, which is the honest cost. The halo needs replacing with something that doesn't change the mark's optical size.</p>
      </div>
      <div class="verdict">
        <span class="tag">Close second</span>
        <h3>Jar</h3>
        <p>Crisp at size, and the most literal fit for the name — a vessel with a portion in it. Reads a little like a battery or a save icon, which is either grounding or generic depending on your taste.</p>
      </div>
      <div class="verdict">
        <span class="tag">Distinctive</span>
        <h3>Bars</h3>
        <p>The most unusual silhouette in a menu bar full of circles, and it holds up small. But three steps is all the resolution it has, so it can only ever say low, middling, or nearly gone.</p>
      </div>
      <div class="verdict">
        <span class="tag">Best on paper</span>
        <h3>Ring</h3>
        <p>Wins the ink measurement by a distance and loses the screenshot. Keep it only if you want the quietest possible menu bar and are content that the number carries the meaning alone.</p>
      </div>
    </div>
    <p>Whichever you pick, the over-pace treatment wants one more pass — the halo and the lid both change the mark's bounding box, which makes the item jump sideways when the state flips.</p>
  </section>

</div>
"""


def main():
    html = (HTML
            .replace("__SHEET_LIGHT__", uri("marks-light.png"))
            .replace("__SHEET_DARK__", uri("marks-dark.png"))
            .replace("__SHEET2_LIGHT__", uri("marks2-light.png"))
            .replace("__SHEET2_DARK__", uri("marks2-dark.png"))
            .replace("__LIVE__", uri("menubar-live.png")))
    out = HERE / "review.html"
    out.write_text(html)
    print(f"wrote {out} ({len(html)/1024:.0f} KB)")


if __name__ == "__main__":
    main()

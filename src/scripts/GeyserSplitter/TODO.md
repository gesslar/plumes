# src/resources — durable TODOs

Design-level items worth keeping past any one work session. (Transient,
in-progress checklists live in per-file `*.TODO.md` files and get cleaned up;
this file is for decisions that should outlast them.)

## GeyserSplitter — redesign the `margins` API

The `margins` constructor option currently takes a `{min, max}` pixel pair per
pane side, e.g.:

```lua
margins = {
  top    = { 30, 0 },   -- vertical splitter
  bottom = { 0, 55 },
}
```

The four values are asymmetric and only two of them are useful:

- `first[1]` → **minimum size of the first pane** (clean, absolute).
- `last[2]`  → **minimum size of the last pane** (clean, absolute) — but note it
  lives in slot **2**, while the first pane's identical "minimum size" knob is in
  slot **1**. Same concept, different slot depending on side. There is no
  consistent "slot 1 = min / slot 2 = max" meaning.
- `first[2]` and `last[1]` → do **not** map to an absolute pane size. They clamp
  against the bar's *current* position (`bar_start` / `bar_end`), which is
  recomputed on every drag step, so they behave like a "can't move within N px of
  where the bar already is" dead-zone rather than a margin. Effectively
  vestigial; real usage sets them to 0.

So today's real-world use is just "reserve a minimum size per pane," expressed
through two slots that sit in mismatched positions. The user-facing docs
deliberately describe only that clean use and don't document the two vestigial
values.

**Proposed redesign:** replace the four-value form with a single minimum per
pane, e.g.

```lua
margins = { first = 30, last = 55 }   -- or keyed by side: { top = 30, bottom = 55 }
```

Drop the second value entirely. This removes the slot asymmetry and the
confusing relative-to-current-bar clamps, and lets the docs match the design
exactly. It is a behavior/API change, so it needs a deliberate pass (and a
migration note for any existing `{min, max}` callers), not a silent reshape.

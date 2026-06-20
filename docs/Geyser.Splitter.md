# Module `Geyser.Splitter`

A splitter joins two panes with a draggable bar between them.

Dragging the bar grows one pane and shrinks the other, keeping their combined
size along the splitter's axis constant. A horizontal splitter has left / middle
/ right widgets; a vertical splitter has top / middle / bottom.

You create the three widgets yourself, and they must already be siblings in one
parent container (usually an HBox or VBox). The splitter coordinates their sizes
but does not own them, so deleting the splitter leaves the widgets intact — see
[`:delete()`](#geysersplitterdelete) versus
[`:disconnect()`](#geysersplitterdisconnect).

The chosen split survives container resizes: set it to 30% and it stays at 30%
as the window grows or shrinks. Set `anchor` to instead keep one pane's pixel
size fixed and let the other absorb the change.

Positions are measured in pixels from the start of the first pane, `0` to
[`getMax()`](#geysersplittergetmax);
[`setPositionRatio()`](#geysersplittersetpositionratio-position) /
[`getPositionRatio()`](#geysersplittergetpositionratio) express the same thing
as a 0–100 percentage.

Give the bar a fixed size along the splitter's axis (width for horizontal,
height for vertical). Inside an auto-laying Box (HBox/VBox) create the bar with
its axis policy already Fixed — `h_policy = Geyser.Fixed` for a horizontal
splitter, `v_policy = Geyser.Fixed` for a vertical one — so the Box treats it as
a divider rather than stretching it. A Box bakes a child's fixed-ness in at add
time and never resizes it back afterward, so pinning the policy later (on the
splitter) would be too late; the splitter checks for this and **errors** if it
was forgotten. In a plain `Geyser.Container`, which never redistributes, the
splitter pins the policy for you.

<br/>See also: [Mudlet Manual: Geyser](https://wiki.mudlet.org/w/Manual:Geyser)

### Info:

- **Author**: gesslar

### Usage:

```lua
local box = Geyser.HBox:new({
  name = "Box",
  x = 0,
  y = 0,
  width = "40%",
  height = "30%",
})

local left  = Geyser.Label:new({name = "Left"}, box)
local bar   = Geyser.Label:new({
  name = "Bar",
  width = 6,
  h_policy = Geyser.Fixed,
}, box)
local right = Geyser.Label:new({name = "Right"}, box)

local splitter = Geyser.Splitter:new({
  orientation = "horizontal",
  left = left,
  middle = bar,
  right = right,
})

splitter:setPositionRatio(30)  -- move the bar 30% across
```

## Functions

| Function | Summary |
|---|---|
| [Geyser.Splitter:adjustPosition (position)](#geysersplitteradjustposition-position) | Move the split by a pixel delta relative to its current position. |
| [Geyser.Splitter:delete ()](#geysersplitterdelete) | Tear down the splitter's own footprint (identical to `:disconnect()`). |
| [Geyser.Splitter:disconnect ()](#geysersplitterdisconnect) | Detach the splitter: stop responding to drags and to the parent's relayout. |
| [Geyser.Splitter:getAbsoluteMax ()](#geysersplittergetabsolutemax) | The end of the splitter's track as an absolute coordinate. |
| [Geyser.Splitter:getAbsoluteMin ()](#geysersplittergetabsolutemin) | The start of the splitter's track as an absolute coordinate. |
| [Geyser.Splitter:getAbsolutePosition ()](#geysersplittergetabsoluteposition) | The bar's current start as an absolute coordinate. |
| [Geyser.Splitter:getConstraints (widget)](#geysersplittergetconstraints-widget) | Get the drag-limit constraints for one of the bounded panes. |
| [Geyser.Splitter:getMax ()](#geysersplittergetmax) | The largest position `setPosition()` accepts: the length of the track. |
| [Geyser.Splitter:getMin ()](#geysersplittergetmin) | The smallest position `setPosition()` accepts: `0`. |
| [Geyser.Splitter:getOrientation ()](#geysersplittergetorientation) | The splitter's orientation as a readable string. |
| [Geyser.Splitter:getPosition ()](#geysersplittergetposition) | The current split position, in pixels from the start of the first pane. |
| [Geyser.Splitter:getPositionRatio ()](#geysersplittergetpositionratio) | The current split position as a percentage (0–100) of the track. |
| [Geyser.Splitter:new (cons)](#geysersplitternew-cons) | Construct a splitter. |
| [Geyser.Splitter:setPosition (position)](#geysersplittersetposition-position) | Move the split to an absolute position, in pixels from the first pane. |
| [Geyser.Splitter:setPositionRatio (position)](#geysersplittersetpositionratio-position) | Move the split to a percentage (0–100) of the track's total size. |

## Fields

| Field | Summary |
|---|---|
| [Geyser.Splitter](#geysersplitter) | Construction options accepted by `Geyser.Splitter:new`. |

<br/>

## Functions

### Geyser.Splitter:adjustPosition (position)

Move the split by a pixel delta relative to its current position. Positive grows
the first pane, negative shrinks it. The resulting position is clamped against
each pane's margin bounds.

**Parameters:**

- `position` — *number*. The pixel delta to apply.

### Geyser.Splitter:delete ()

Tear down the splitter's own footprint (identical to
[`:disconnect()`](#geysersplitterdisconnect)). Does **not** delete the managed
widgets: unlike `Geyser.Container:delete()`, which cascades because a container
owns its `windowList`, a Splitter owns nothing it coordinates. If a parent later
deletes those widgets the splitter is left stranded, which is the caller's
concern.

### Geyser.Splitter:disconnect ()

Detach the splitter: stop responding to drags and to the parent's relayout,
removing it from the parent's registry and unwrapping the parent's
`reposition()` once the last splitter on it is gone. Does **not** delete the
managed widgets — they belong to the caller. Safe to call more than once.

### Geyser.Splitter:getAbsoluteMax ()

The end of the splitter's track as an absolute coordinate (pixels from the main
window origin), i.e. the last pane's end.

**Returns:**

- *number*

### Geyser.Splitter:getAbsoluteMin ()

The start of the splitter's track as an absolute coordinate (pixels from the
main window origin), i.e. the first pane's start.

**Returns:**

- *number*

### Geyser.Splitter:getAbsolutePosition ()

The bar's current start as an absolute coordinate (pixels from the main window
origin).

**Returns:**

- *number*

### Geyser.Splitter:getConstraints (widget)

Get the drag-limit constraints for one of the bounded panes (the first or last
pane only — the bar is not a bounded pane).

**Parameters:**

- `widget` — *table*. The first or last pane of this splitter.

**Returns:**

1. *table* — `{min_bound = number, max_bound = number}`, or `nil` if `widget` is
   not a bounded pane.
2. *string* — error message, present only when the first return is `nil`.

### Geyser.Splitter:getMax ()

The largest position [`setPosition()`](#geysersplittersetposition-position)
accepts: the length of the track, i.e. the end of the last pane.

**Returns:**

- *number*

### Geyser.Splitter:getMin ()

The smallest position [`setPosition()`](#geysersplittersetposition-position)
accepts: `0`, the start of the first pane.

**Returns:**

- *number* — always `0`.

### Geyser.Splitter:getOrientation ()

The splitter's orientation as a readable string, `"horizontal"` or `"vertical"`
(the `orientation` field itself is the normalised integer `1` or `2`).

**Returns:**

- *string*

### Geyser.Splitter:getPosition ()

The current split position, in pixels from the start of the first pane.

**Returns:**

- *number*

### Geyser.Splitter:getPositionRatio ()

The current split position as a percentage (0–100) of the track's total size.

**Returns:**

- *number*

### Geyser.Splitter:new (cons)

Construct a splitter. See [Fields](#geysersplitter) for the full list of
construction options; at minimum the orientation's three widgets (including
`middle`) are required.

**Parameters:**

- `cons` — *table*. Construction options (see [Fields](#geysersplitter)).

**Returns:**

- *Geyser.Splitter*

**Raises:** an error if a required widget is missing, the widgets do not share
one parent container, the bar is not Fixed along the axis inside an HBox/VBox,
`anchor` and `sticky` are combined, or an option is otherwise invalid.

**Usage:**

```lua
local splitter = Geyser.Splitter:new({
  orientation = "vertical",
  top = top,
  middle = bar,
  bottom = bottom,
  anchor = "top",
  margins = {
    top = {30, 0},
    bottom = {0, 55},
  },
})
```

### Geyser.Splitter:setPosition (position)

Move the split to an absolute position, in pixels from the start of the first
pane (`0` to [`getMax()`](#geysersplittergetmax)). Positions that would violate a
pane's margins are clamped.

**Parameters:**

- `position` — *number*. The target split position in pixels.

### Geyser.Splitter:setPositionRatio (position)

Move the split to a percentage (0–100) of the track's total size, e.g. `30` puts
the bar about 30% of the way along.

**Parameters:**

- `position` — *number*. The target split position as a 0–100 percentage.

<br/>

## Fields

### Geyser.Splitter

Construction options accepted by [`Geyser.Splitter:new`](#geysersplitternew-cons).

- `orientation` — `"horizontal"` (default) or `"vertical"`.
- `middle` — The draggable bar widget. Always required. Give it a fixed size
  along the axis. In an HBox/VBox, create it with its axis policy already Fixed
  (`h_policy` / `v_policy` = `Geyser.Fixed`); the splitter errors if it isn't. In
  a plain `Container` the policy is pinned for you.
- `left`, `right` — The two panes of a horizontal splitter. Required when
  horizontal.
- `top`, `bottom` — The two panes of a vertical splitter. Required when vertical.
- `name` — Optional; auto-generated if omitted.
- `cursor` — Optional Mudlet cursor shown over the bar; defaults to
  `ResizeHorizontal` / `ResizeVertical` to match the orientation.
- `anchor` — Optional. On resize, the pane that keeps its pixel size while the
  other absorbs the change. Use the side matching the orientation: `"left"` or
  `"right"` for horizontal, `"top"` or `"bottom"` for vertical. Omit for
  proportional resizing. Mutually exclusive with `sticky`.
- `sticky` — Optional boolean. Resize proportionally while the split is
  mid-range, but if a pane has been dragged to its margin minimum, keep it
  pinned there across resizes instead of letting it grow back
  (collapse-and-stay-collapsed). Mutually exclusive with `anchor`.
- `margins` — Optional drag limits that reserve a minimum pixel size for a pane
  so the bar can't crush it, as `{min, max}` pairs keyed by pane side, e.g. for a
  vertical splitter: `margins = { top = {30, 0}, bottom = {0, 55} }` keeps the
  top pane at least 30px and the bottom at least 55px.

---

*Generated for plumes — `src/scripts/GeyserSplitter/GeyserSplitter.lua`.*

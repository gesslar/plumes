# plumes

_Pluggable Geyser objects for your Mudlet UI making pleasure._

**plumes** is a collection of drop-in [Geyser](https://wiki.mudlet.org/w/Manual:Geyser)
components for Mudlet. Right now it ships one:

- **`Geyser.Splitter`** — joins two panes with a draggable bar between them.
  Dragging the bar grows one pane and shrinks the other, the split survives
  window resizes, and panes can be given minimum sizes so the bar can't crush
  them. Full API: [`docs/Geyser.Splitter.md`](docs/Geyser.Splitter.md).

Each component is a single self-contained Lua file that registers itself onto
the global `Geyser` table. There's nothing to instantiate to "boot" plumes —
load the file and the class is there.

## Loading it

### 1. As a drop-in script (simplest)

This is the most basic option: Mudlet runs Script items for you, so you don't
even need to `require` anything.

1. In Mudlet open the **Script editor** (Scripts).
2. Add a new script and paste in the contents of
   [`src/scripts/GeyserSplitter/GeyserSplitter.lua`](src/scripts/GeyserSplitter/GeyserSplitter.lua).
3. Save. The script runs immediately and on every Mudlet start, registering
   `Geyser.Splitter`.

From then on `Geyser.Splitter` is available to any alias, trigger, or script.

### 2. As a bundled resource (muddler / muddy)

If you build your own package with [muddy](https://www.npmjs.com/package/@gesslar/muddy)
or [muddler](https://github.com/demonnic/muddler), drop the component file into
your package's `src/resources/` directory, then load it from one of your own
scripts:

```lua
require("__PKGNAME__/GeyserSplitter")
```

`__PKGNAME__` is substituted with your package's name at build time. The file
defines the object, in this case `Geyser.Splitter`, as a side effect (it returns
nothing), so a bare `require` is all you need — call it once, early, before you
build any splitters.

## Quick start

A horizontal splitter with a left pane, a draggable bar, and a right pane:

```lua
local box = Geyser.HBox:new({
  name = "MyBox",
  x = 0,
  y = 0,
  width = "40%",
  height = "30%",
})

local left = Geyser.Label:new({name = "MyLeft"}, box)

-- The bar must be Fixed along the split axis inside an HBox/VBox.
local bar = Geyser.Label:new({
  name = "MyBar",
  width = 6,
  h_policy = Geyser.Fixed,
}, box)

local right = Geyser.Label:new({name = "MyRight"}, box)

local splitter = Geyser.Splitter:new({
  orientation = "horizontal",
  left = left,
  middle = bar,
  right = right,
})

splitter:setPositionRatio(30)  -- move the bar 30% across
```

Each component has its own constructor options, behaviours, and caveats — those
live in the component's own API doc, not here. For the splitter, see
[`docs/Geyser.Splitter.md`](docs/Geyser.Splitter.md).

## Development

```bash
npm run build      # build → build/plumes.mpackage
npm test           # run the Busted specs in headless Mudlet (Docker)
npm run test:tree  # same, with nested describe/it output
```

Tests live in `src/resources/test/*_spec.lua` and run inside the
[`gesslardev/mudlet-busted`](https://hub.docker.com/r/gesslardev/mudlet-busted)
image, so the real Geyser stack is available to them.

## License

[0BSD](LICENSE.txt)

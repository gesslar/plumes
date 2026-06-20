-- Busted spec for Geyser.Splitter (src/scripts/GeyserSplitter/GeyserSplitter.lua).
--
-- Runs inside a headless real Mudlet via gesslardev/mudlet-busted, so the whole
-- Geyser stack is available natively: we build genuine HBox/VBox + Label widgets
-- and drive the splitter against them rather than mocking geometry.
--
-- The package itself only defines the global Geyser.Splitter when the prebuilt
-- mpackage is installed, so there is nothing to instantiate in setup() -- the
-- class is simply present.

describe("Geyser.Splitter", function()
  -- Unique-suffix generator so widgets created in different `it` blocks never
  -- collide on a Geyser name (which would clobber callbacks from a prior test).
  local seq = 0
  local function uid()
    seq = seq + 1
    return tostring(seq)
  end

  -- Build a horizontal track: an HBox with left / bar / right Label children.
  -- Returns box, left, bar, right. The bar is given a fixed pixel width; the
  -- splitter pins its h_policy so the Box treats it as a divider.
  local function build_h(opts)
    opts = opts or {}
    local id = uid()
    local box = Geyser.HBox:new({
      name = "SpHBox" .. id, x = 0, y = 0,
      width = opts.width or 400, height = opts.height or 100,
    })
    local left = Geyser.Label:new({name = "SpL" .. id}, box)
    -- The bar is created Fixed up front: an HBox bakes a child's fixed-ness in at
    -- add time, so this is the only point at which it sticks.
    local bar = Geyser.Label:new({name = "SpBar" .. id, width = opts.bar or 10, h_policy = Geyser.Fixed}, box)
    local right = Geyser.Label:new({name = "SpR" .. id}, box)

    return box, left, bar, right
  end

  -- Build a horizontal track inside a *plain* Geyser.Container. Unlike an HBox,
  -- a Container does not redistribute its children, so the bar stays the exact
  -- pixel width we give it and the geometry is fully deterministic -- which is
  -- what the position/size assertions below depend on. Panes are laid left /
  -- bar / right across the full container width.
  local function build_track_h(opts)
    opts = opts or {}
    local id = uid()
    local w = opts.width or 400
    local barw = opts.bar or 10
    local pane = (w - barw) / 2
    local box = Geyser.Container:new({name = "TrkH" .. id, x = 0, y = 0, width = w, height = 100})
    local l = Geyser.Label:new({name = "TrkL" .. id, x = 0, y = 0, width = pane, height = 100}, box)
    local bar = Geyser.Label:new({name = "TrkBar" .. id, x = pane, y = 0, width = barw, height = 100}, box)
    local r = Geyser.Label:new({name = "TrkR" .. id, x = pane + barw, y = 0, width = pane, height = 100}, box)

    return box, l, bar, r
  end

  -- Build a vertical track: a VBox with top / bar / bottom Label children.
  local function build_v(opts)
    opts = opts or {}
    local id = uid()
    local box = Geyser.VBox:new({
      name = "SpVBox" .. id, x = 0, y = 0,
      width = opts.width or 100, height = opts.height or 400,
    })
    local top = Geyser.Label:new({name = "SpT" .. id}, box)
    local bar = Geyser.Label:new({name = "SpVBar" .. id, height = opts.bar or 10, v_policy = Geyser.Fixed}, box)
    local bottom = Geyser.Label:new({name = "SpB" .. id}, box)

    return box, top, bar, bottom
  end

  -- Force the Box to relay its children. After this the splitter's bar is a
  -- fixed-size divider and geometry reads are stable.
  local function settle(box)
    box:reposition()
  end

  -- Tolerant numeric compare -- integer pixel layout rounds, so exact equality
  -- is too brittle for derived geometry.
  local function near(actual, expected, tol)
    tol = tol or 2
    assert.is_true(math.abs(actual - expected) <= tol,
      string.format("expected ~%s (+/-%s), got %s", tostring(expected), tostring(tol), tostring(actual)))
  end

  -- ========================================================================
  -- Construction defaults
  -- ========================================================================

  describe("construction defaults", function()
    it("defaults orientation to horizontal", function()
      local box, l, bar, r = build_h()
      local sp = Geyser.Splitter:new({left = l, middle = bar, right = r})
      assert.are.equal("horizontal", sp:getOrientation())
      assert.are.equal(1, sp.orientation)
    end)

    it("tags the type as splitter", function()
      local box, l, bar, r = build_h()
      local sp = Geyser.Splitter:new({left = l, middle = bar, right = r})
      assert.are.equal("splitter", sp.type)
    end)

    it("auto-generates a name when none is given", function()
      local box, l, bar, r = build_h()
      local sp = Geyser.Splitter:new({left = l, middle = bar, right = r})
      assert.is_truthy(sp.name)
      assert.are.equal("string", type(sp.name))
    end)

    it("keeps an explicit name", function()
      local box, l, bar, r = build_h()
      local sp = Geyser.Splitter:new({name = "MySplit" .. uid(), left = l, middle = bar, right = r})
      assert.is_truthy(sp.name:match("^MySplit"))
    end)

    it("orders widgets as first/middle/last", function()
      local box, l, bar, r = build_h()
      local sp = Geyser.Splitter:new({left = l, middle = bar, right = r})
      assert.are.equal(l, sp.widgets[1])
      assert.are.equal(bar, sp.widgets[2])
      assert.are.equal(r, sp.widgets[3])
    end)

    it("starts not moving and connected", function()
      local box, l, bar, r = build_h()
      local sp = Geyser.Splitter:new({left = l, middle = bar, right = r})
      assert.is_false(sp.moving)
      assert.is_true(sp.connected)
    end)

    it("defaults the horizontal cursor and drag axis", function()
      local box, l, bar, r = build_h()
      local sp = Geyser.Splitter:new({left = l, middle = bar, right = r})
      assert.are.equal("ResizeHorizontal", sp.cursor)
      assert.are.equal("x", sp.mouse_property)
    end)
  end)

  -- ========================================================================
  -- Vertical orientation
  -- ========================================================================

  describe("vertical orientation", function()
    it("normalises orientation to vertical", function()
      local box, t, bar, b = build_v()
      local sp = Geyser.Splitter:new({orientation = "vertical", top = t, middle = bar, bottom = b})
      assert.are.equal("vertical", sp:getOrientation())
      assert.are.equal(2, sp.orientation)
    end)

    it("defaults the vertical cursor and drag axis", function()
      local box, t, bar, b = build_v()
      local sp = Geyser.Splitter:new({orientation = "vertical", top = t, middle = bar, bottom = b})
      assert.are.equal("ResizeVertical", sp.cursor)
      assert.are.equal("y", sp.mouse_property)
    end)

    it("accepts shorthand orientation aliases", function()
      local box, t, bar, b = build_v()
      local sp = Geyser.Splitter:new({orientation = "v", top = t, middle = bar, bottom = b})
      assert.are.equal(2, sp.orientation)
    end)
  end)

  -- ========================================================================
  -- Construction validation
  -- ========================================================================

  describe("construction validation", function()
    it("errors on an unknown orientation", function()
      local box, l, bar, r = build_h()
      assert.has_error(function()
        Geyser.Splitter:new({orientation = "diagonal", left = l, middle = bar, right = r})
      end)
    end)

    it("errors on an unknown cursor", function()
      local box, l, bar, r = build_h()
      assert.has_error(function()
        Geyser.Splitter:new({left = l, middle = bar, right = r, cursor = "NopeCursor"})
      end)
    end)

    it("errors when sticky is not a boolean", function()
      local box, l, bar, r = build_h()
      assert.has_error(function()
        Geyser.Splitter:new({left = l, middle = bar, right = r, sticky = "yes"})
      end)
    end)

    it("errors when anchor and sticky are combined", function()
      local box, l, bar, r = build_h()
      assert.has_error(function()
        Geyser.Splitter:new({left = l, middle = bar, right = r, anchor = "left", sticky = true})
      end)
    end)

    it("errors when a required horizontal widget is missing", function()
      local box, l, bar, r = build_h()
      assert.has_error(function()
        Geyser.Splitter:new({left = l, middle = bar})
      end)
    end)

    it("hints at the orientation when the wrong side-words are used", function()
      local box, t, bar, b = build_v()
      -- top/bottom on a (defaulted) horizontal splitter -> missing left/right,
      -- and the error should suggest orientation = "vertical".
      local ok, err = pcall(function()
        Geyser.Splitter:new({top = t, middle = bar, bottom = b})
      end)
      assert.is_false(ok)
      assert.is_truthy(tostring(err):match("did you mean orientation"))
    end)

    it("errors when widgets do not share one container", function()
      local _, l, bar = build_h()
      local _, _, _, r = build_h() -- right comes from a different box
      assert.has_error(function()
        Geyser.Splitter:new({left = l, middle = bar, right = r})
      end)
    end)

    it("errors on an anchor word from the wrong orientation", function()
      local box, l, bar, r = build_h()
      assert.has_error(function()
        Geyser.Splitter:new({left = l, middle = bar, right = r, anchor = "top"})
      end)
    end)

    it("errors when a margin side has more than two values", function()
      local box, l, bar, r = build_h()
      assert.has_error(function()
        Geyser.Splitter:new({left = l, middle = bar, right = r, margins = {left = {10, 20, 30}}})
      end)
    end)
  end)

  -- ========================================================================
  -- Anchor normalisation
  -- ========================================================================

  describe("anchor", function()
    it("normalises 'left' to the first slot", function()
      local box, l, bar, r = build_h()
      local sp = Geyser.Splitter:new({left = l, middle = bar, right = r, anchor = "left"})
      assert.are.equal(1, sp.anchor)
    end)

    it("normalises 'right' to the last slot", function()
      local box, l, bar, r = build_h()
      local sp = Geyser.Splitter:new({left = l, middle = bar, right = r, anchor = "right"})
      assert.are.equal(3, sp.anchor)
    end)

    it("seeds anchor_size from the anchored pane", function()
      local box, l, bar, r = build_h()
      settle(box)
      local sp = Geyser.Splitter:new({left = l, middle = bar, right = r, anchor = "left"})
      assert.are.equal("number", type(sp.anchor_size))
    end)

    it("leaves anchor nil when unset", function()
      local box, l, bar, r = build_h()
      local sp = Geyser.Splitter:new({left = l, middle = bar, right = r})
      assert.is_nil(sp.anchor)
    end)
  end)

  -- ========================================================================
  -- Margins parsing
  -- ========================================================================

  describe("margins", function()
    it("defaults both panes to {0, 0} when omitted", function()
      local box, l, bar, r = build_h()
      local sp = Geyser.Splitter:new({left = l, middle = bar, right = r})
      assert.are.same({0, 0}, sp.margins.first)
      assert.are.same({0, 0}, sp.margins.last)
    end)

    it("fills a one-value margin's max with 0", function()
      local box, l, bar, r = build_h()
      local sp = Geyser.Splitter:new({left = l, middle = bar, right = r, margins = {left = {30}}})
      assert.are.same({30, 0}, sp.margins.first)
      assert.are.same({0, 0}, sp.margins.last)
    end)

    it("keeps both values of a two-value margin", function()
      local box, l, bar, r = build_h()
      local sp = Geyser.Splitter:new({left = l, middle = bar, right = r, margins = {left = {30, 40}, right = {5, 55}}})
      assert.are.same({30, 40}, sp.margins.first)
      assert.are.same({5, 55}, sp.margins.last)
    end)

    it("maps vertical side-words onto first/last", function()
      local box, t, bar, b = build_v()
      local sp = Geyser.Splitter:new({
        orientation = "vertical", top = t, middle = bar, bottom = b,
        margins = {top = {30, 0}, bottom = {0, 55}},
      })
      assert.are.same({30, 0}, sp.margins.first)
      assert.are.same({0, 55}, sp.margins.last)
    end)
  end)

  -- ========================================================================
  -- Parent wiring (reposition wrap + registry)
  -- ========================================================================

  describe("parent wiring", function()
    it("registers itself on the shared container", function()
      local box, l, bar, r = build_h()
      local sp = Geyser.Splitter:new({left = l, middle = bar, right = r})
      assert.are.equal(sp, box.splitters[sp.name])
      assert.are.equal(box, sp.parent_container)
    end)

    it("wraps the container's reposition once for multiple splitters", function()
      local box, l, bar, r = build_h()
      Geyser.Splitter:new({left = l, middle = bar, right = r})
      local wrapped = box.reposition
      -- A second splitter on the same container must not re-wrap.
      Geyser.Splitter:new({left = l, middle = bar, right = r, name = "Second" .. uid()})
      assert.are.equal(wrapped, box.reposition)
    end)
  end)

  -- ========================================================================
  -- disconnect / delete
  -- ========================================================================

  describe("disconnect", function()
    it("marks the splitter disconnected", function()
      local box, l, bar, r = build_h()
      local sp = Geyser.Splitter:new({left = l, middle = bar, right = r})
      sp:disconnect()
      assert.is_false(sp.connected)
    end)

    it("removes itself from the registry", function()
      local box, l, bar, r = build_h()
      local sp = Geyser.Splitter:new({left = l, middle = bar, right = r})
      sp:disconnect()
      assert.is_nil(box.splitters)
    end)

    it("restores the original reposition once the last splitter leaves", function()
      local box, l, bar, r = build_h()
      local original = box.reposition
      local sp = Geyser.Splitter:new({left = l, middle = bar, right = r})
      assert.are_not.equal(original, box.reposition)
      sp:disconnect()
      assert.are.equal(original, box.reposition)
    end)

    it("is safe to call more than once", function()
      local box, l, bar, r = build_h()
      local sp = Geyser.Splitter:new({left = l, middle = bar, right = r})
      sp:disconnect()
      assert.has_no.errors(function() sp:disconnect() end)
    end)

    it("delete behaves like disconnect (leaving widgets intact)", function()
      local box, l, bar, r = build_h()
      local sp = Geyser.Splitter:new({left = l, middle = bar, right = r})
      sp:delete()
      assert.is_false(sp.connected)
      -- The managed widgets are NOT destroyed.
      assert.is_truthy(l.name)
      assert.is_truthy(r.name)
    end)
  end)

  -- ========================================================================
  -- getConstraints
  -- ========================================================================

  describe("getConstraints", function()
    it("returns the bounds for the first pane", function()
      local box, l, bar, r = build_h()
      local sp = Geyser.Splitter:new({left = l, middle = bar, right = r, margins = {left = {30, 40}}})
      local c = sp:getConstraints(l)
      assert.are.equal(30, c.min_bound)
      assert.are.equal(40, c.max_bound)
    end)

    it("returns the bounds for the last pane", function()
      local box, l, bar, r = build_h()
      local sp = Geyser.Splitter:new({left = l, middle = bar, right = r, margins = {right = {5, 55}}})
      local c = sp:getConstraints(r)
      assert.are.equal(5, c.min_bound)
      assert.are.equal(55, c.max_bound)
    end)

    it("returns nil + message for a non-pane widget", function()
      local box, l, bar, r = build_h()
      local sp = Geyser.Splitter:new({left = l, middle = bar, right = r})
      local c, err = sp:getConstraints(bar) -- the bar is not a bounded pane
      assert.is_nil(c)
      assert.is_truthy(err)
    end)
  end)

  -- ========================================================================
  -- Fixed-bar contract (the bar must be a real divider, not a stretched pane)
  --
  -- An HBox/VBox bakes a child's fixed-ness in at add() time and never resizes
  -- it back, so the splitter can only pin the bar's policy itself when the
  -- parent is a plain Container. For a Box, the caller must create the bar Fixed
  -- up front; the splitter rejects a non-Fixed bar rather than silently shipping
  -- a divider that renders a full pane wide.
  -- ========================================================================

  describe("fixed-bar contract", function()
    it("keeps a Fixed bar at its given width through a reposition (HBox)", function()
      local box, l, bar, r = build_h({width = 400, bar = 10})
      local sp = Geyser.Splitter:new({left = l, middle = bar, right = r})
      box:reposition()
      -- The documented usage must produce a thin divider, not a ~133px third.
      near(bar.get_width(), 10, 2)
      near(sp:getPosition(), 195, 3) -- (400 - 10) / 2
    end)

    it("keeps a Fixed bar at its given height through a reposition (VBox)", function()
      local box, t, bar, b = build_v({height = 400, bar = 10})
      local sp = Geyser.Splitter:new({orientation = "vertical", top = t, middle = bar, bottom = b})
      box:reposition()
      near(bar.get_height(), 10, 2)
      near(sp:getPosition(), 195, 3)
    end)

    it("rejects a non-Fixed bar in an HBox", function()
      local id = uid()
      local box = Geyser.HBox:new({name = "NfH" .. id, x = 0, y = 0, width = 400, height = 100})
      local l = Geyser.Label:new({name = "NfHL" .. id}, box)
      local bar = Geyser.Label:new({name = "NfHBar" .. id, width = 10}, box) -- not Fixed
      local r = Geyser.Label:new({name = "NfHR" .. id}, box)
      assert.has_error(function()
        Geyser.Splitter:new({left = l, middle = bar, right = r})
      end)
    end)

    it("rejects a non-Fixed bar in a VBox", function()
      local id = uid()
      local box = Geyser.VBox:new({name = "NfV" .. id, x = 0, y = 0, width = 100, height = 400})
      local t = Geyser.Label:new({name = "NfVT" .. id}, box)
      local bar = Geyser.Label:new({name = "NfVBar" .. id, height = 10}, box) -- not Fixed
      local b = Geyser.Label:new({name = "NfVB" .. id}, box)
      assert.has_error(function()
        Geyser.Splitter:new({orientation = "vertical", top = t, middle = bar, bottom = b})
      end)
    end)

    it("pins the policy itself for a plain Container bar", function()
      -- build_track_h parents the panes in a plain Container and does NOT set a
      -- policy on the bar -- the splitter should pin it without complaint.
      local box, l, bar, r = build_track_h({width = 400, bar = 10})
      assert.has_no.errors(function()
        Geyser.Splitter:new({left = l, middle = bar, right = r})
      end)
      assert.are.equal(Geyser.Fixed, bar.h_policy)
    end)
  end)

  -- ========================================================================
  -- Position geometry (horizontal)
  -- ========================================================================

  describe("position geometry", function()
    it("reports getMin as 0 and getMax as the track length", function()
      local box, l, bar, r = build_track_h({width = 400, bar = 10})
      local sp = Geyser.Splitter:new({left = l, middle = bar, right = r})
      assert.are.equal(0, sp:getMin())
      near(sp:getMax(), 400, 2)
    end)

    it("reads the initial split from the laid-out widgets", function()
      local box, l, bar, r = build_track_h({width = 400, bar = 10})
      local sp = Geyser.Splitter:new({left = l, middle = bar, right = r})
      -- left pane is (400 - 10) / 2 = 195 wide, so the bar starts at 195.
      near(sp:getPosition(), 195, 2)
    end)

    it("moves the split to an absolute position", function()
      local box, l, bar, r = build_track_h({width = 400, bar = 10})
      local sp = Geyser.Splitter:new({left = l, middle = bar, right = r})
      sp:setPosition(120)
      near(sp:getPosition(), 120, 2)
    end)

    it("keeps the three widths summing to the track", function()
      local box, l, bar, r = build_track_h({width = 400, bar = 10})
      local sp = Geyser.Splitter:new({left = l, middle = bar, right = r})
      sp:setPosition(150)
      near(l.get_width() + bar.get_width() + r.get_width(), 400, 3)
    end)

    it("adjusts the split by a relative delta", function()
      local box, l, bar, r = build_track_h({width = 400, bar = 10})
      local sp = Geyser.Splitter:new({left = l, middle = bar, right = r})
      sp:setPosition(100)
      sp:adjustPosition(50)
      near(sp:getPosition(), 150, 2)
    end)

    it("round-trips a position ratio", function()
      local box, l, bar, r = build_track_h({width = 400, bar = 10})
      local sp = Geyser.Splitter:new({left = l, middle = bar, right = r})
      sp:setPositionRatio(25)
      near(sp:getPositionRatio(), 25, 2)
    end)

    it("clamps a position below the first pane's min margin", function()
      local box, l, bar, r = build_track_h({width = 400, bar = 10})
      local sp = Geyser.Splitter:new({left = l, middle = bar, right = r, margins = {left = {80, 0}}})
      sp:setPosition(10) -- below the 80px floor
      assert.is_true(sp:getPosition() >= 80 - 2)
    end)

    it("errors when setPosition gets a non-number", function()
      local box, l, bar, r = build_track_h()
      local sp = Geyser.Splitter:new({left = l, middle = bar, right = r})
      assert.has_error(function() sp:setPosition("nope") end)
    end)

    it("errors when setPosition gets nil", function()
      local box, l, bar, r = build_track_h()
      local sp = Geyser.Splitter:new({left = l, middle = bar, right = r})
      assert.has_error(function() sp:setPosition(nil) end)
    end)
  end)
end)

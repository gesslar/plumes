--- A splitter joins two panes with a draggable bar between them. Dragging the
--- bar grows one pane and shrinks the other, keeping their combined size along
--- the splitter's axis constant. A horizontal splitter has left / middle /
--- right widgets; a vertical splitter has top / middle / bottom.
---
--- You create the three widgets yourself, and they must already be siblings in
--- one parent container (usually an HBox or VBox). The splitter coordinates
--- their sizes but does not own them, so deleting the splitter leaves the
--- widgets intact -- see :delete() versus :disconnect().
---
--- The chosen split survives container resizes: set it to 30% and it stays at
--- 30% as the window grows or shrinks. Set `anchor` to instead keep one pane's
--- pixel size fixed and let the other absorb the change.
---
--- Positions are measured in pixels from the start of the first pane, 0 to
--- getMax(); setPositionRatio()/getPositionRatio() express the same thing as a
--- 0-100 percentage.
---
--- Give the bar a fixed size along the splitter's axis (width for horizontal,
--- height for vertical). Inside an auto-laying Box (HBox/VBox) create the bar
--- with its axis policy already Fixed -- h_policy = Geyser.Fixed for a horizontal
--- splitter, v_policy = Geyser.Fixed for a vertical one -- so the Box treats it as
--- a divider rather than stretching it. A Box bakes a child's fixed-ness in at
--- add time and never resizes it back afterward, so pinning the policy later (on
--- the splitter) would be too late; the splitter checks for this and errors if it
--- was forgotten. In a plain Geyser.Container, which never redistributes, the
--- splitter pins the policy for you.
---
--- Usage:
---   local box   = Geyser.HBox:new({name = "Box", x = 0, y = 0, width = "40%", height = "30%"})
---   local left  = Geyser.Label:new({name = "Left"}, box)
---   local bar   = Geyser.Label:new({name = "Bar", width = 6, h_policy = Geyser.Fixed}, box)
---   local right = Geyser.Label:new({name = "Right"}, box)
---   local splitter = Geyser.Splitter:new({
---     orientation = "horizontal",
---     left = left, middle = bar, right = right,
---   })
---   splitter:setPositionRatio(30)   -- move the bar 30% of the way across
---
--- Construction options -- Geyser.Splitter:new{ ... }
---   orientation - "horizontal" (default) or "vertical".
---   middle      - The draggable bar widget. Always required. Give it a fixed
---                 size along the axis. In an HBox/VBox, create it with its axis
---                 policy already Fixed (h_policy / v_policy = Geyser.Fixed); the
---                 splitter errors if it isn't. In a plain Container the policy is
---                 pinned for you.
---   left, right - The two panes of a horizontal splitter. Required when horizontal.
---   top, bottom - The two panes of a vertical splitter. Required when vertical.
---   name        - Optional; auto-generated if omitted.
---   cursor      - Optional Mudlet cursor shown over the bar; defaults to
---                 ResizeHorizontal / ResizeVertical to match the orientation.
---   anchor      - Optional. On resize, the pane that keeps its pixel size while
---                 the other absorbs the change. Use the side matching the
---                 orientation: "left" or "right" for horizontal, "top" or
---                 "bottom" for vertical. Omit for proportional resizing.
---   sticky      - Optional boolean. Resize proportionally while the split is
---                 mid-range, but if a pane has been dragged to its margin
---                 minimum, keep it pinned there across resizes instead of
---                 letting it grow back (i.e. collapse-and-stay-collapsed).
---                 Mutually exclusive with `anchor`.
---   margins     - Optional drag limits that reserve a minimum pixel size for a
---                 pane so the bar can't crush it, as {min, max} pairs keyed by
---                 pane side, e.g. for a vertical splitter:
---                   margins = { top = {30, 0}, bottom = {0, 55} }
---                 keeps the top pane at least 30px and the bottom at least 55px.
---
---@class Geyser.Splitter
---@field name string Auto-generated if not supplied.
---@field orientation integer Normalised orientation (1 = horizontal, 2 = vertical).
---@field cursor string Mouse cursor shown while over the bar.
---@field anchor integer|nil Which pane holds its pixel size on resize, or nil for proportional.
---@field sticky boolean? Keep a margin-pinned pane pinned across resizes (vs. proportional).
---@field widgets table The ordered { first, middle, last } widgets it manages.
---@field type string Internal: Geyser type tag, "splitter".
---@field margins table Internal: { first = {min, max}, last = {min, max} } drag bounds in px.
---@field mouse_property string Internal: drag axis, "x" (horizontal) or "y" (vertical).
---@field moving boolean Internal: true while a drag is in progress.
---@field position_ratio number? Internal: last split as a 0-100 ratio, replayed by restore().
---@field anchor_size number? Internal: last anchored pane's pixel size, replayed by restore().
---@field restoring boolean Internal: true while restore() re-applies (suppresses re-capture).
---@field connected boolean Internal: false once disconnect()/delete() has detached it.
---@field parent_container table Internal: shared parent container whose reposition() is wrapped.
---@field sticky_pin integer? Internal: pane (first/last) jammed at its min, replayed by sticky restore().
Geyser.Splitter = Geyser.Splitter or {
  name = "SplitterClass",
  widgets = {},
}

--- Forward declarations of local functions
local _percent, _percent_of
local get_start, get_size, get_track_size
local update_widgets, mouse_event
local get_min_bound, get_max_bound

--- Orientation constants
local orientations = {
  horizontal = 1, h = 1, ["1"] = 1, [1] = 1,
  vertical   = 2, v = 2, ["2"] = 2, [2] = 2,
}
local orientations_reverse = { "horizontal", "vertical" }

--- Relational descriptors constants
local descriptors = {
  { "left", "middle", "right" },
  { "top", "middle", "bottom" },
}
local coords = { "x", "y" }

--- Widget element constants. Keys are only the canonical slot names (first /
--- middle / last), the real construction side-words (left/right, top/bottom),
--- and numeric forms -- nothing that looks like a construction key but isn't
--- accepted by :new (which reads exactly left/middle/right or top/middle/bottom).
local widget_elements = {
  first = 1,  left = 1,  top = 1,    ["1"] = 1, [1] = 1,
  middle = 2,                        ["2"] = 2, [2] = 2,
  last = 3,   right = 3, bottom = 3, ["3"] = 3, [3] = 3,
}

--- Move the bar and panes so the split sits at `position`.
---@param splitter Geyser.Splitter
---@param position number Split point in TRACK-LOCAL coords: distance from the first widget's start (0 = start, getMax() = end of the last widget).
function update_widgets(splitter, position)
  local orientation = splitter.orientation
  local widgets = splitter.widgets
  local first, bar, last = widgets[1], widgets[2], widgets[3]

  -- All math here is TRACK-LOCAL: distances measured from the start of the
  -- first widget (0 = first's start, total_size = the last widget's end).
  -- get_start() and move() speak other spaces, so convert at the edges:
  --   * get_start() returns ABSOLUTE coords -> subtract first_start to enter
  --     track-local.
  --   * move() expects coords relative to the widget's CONTAINER -> add
  --     parent_offset (where the first widget sits inside that container, e.g.
  --     pushed off the origin by a header) to leave track-local.
  local first_start = get_start(orientation, first)
  local bar_size = get_size(orientation, bar)
  local parent_offset = first_start - get_start(orientation, first.container)
  -- Track length is anchored to the container (see get_track_size), not the sum
  -- of the three child sizes -- those were last set via "%dpx", which floors, so
  -- re-summing would ratchet the track smaller every move and creep the last
  -- pane shut.
  local total_size = get_track_size(splitter)

  -- Current bar span, track-local.
  local bar_start = get_start(orientation, bar) - first_start
  local bar_end = bar_start + bar_size

  -- If the requested split lands on the bar, don't move anything.
  if position >= bar_start and position <= bar_end then
    return
  end

  -- Clamp the requested split against each pane's margin bounds (track-local).
  local first_min = get_min_bound(splitter, first)
  local first_max = bar_start - get_max_bound(splitter, first)
  local last_min = bar_end + get_min_bound(splitter, last)
  local last_max = total_size - get_max_bound(splitter, last) - bar_size

  local new_position = position
  if new_position < bar_start then
    if new_position < first_min then
      new_position = first_min
    elseif new_position > first_max then
      new_position = first_max
    end
  elseif new_position > bar_end then
    if new_position < last_min then
      new_position = last_min
    elseif new_position > last_max then
      new_position = last_max
    end
  end

  -- Sizes are space-independent; positions convert track-local -> container.
  local new_first_size = new_position
  local new_last_start = new_position + bar_size
  local new_last_size = total_size - new_first_size - bar_size

  if orientation == orientations.horizontal then
    bar:move(new_position + parent_offset, nil)
    first:resize(string.format("%dpx", new_first_size), nil)
    last:move(string.format("%dpx", new_last_start + parent_offset), nil)
    last:resize(string.format("%dpx", new_last_size), nil)
  else
    bar:move(nil, new_position + parent_offset)
    first:resize(nil, string.format("%dpx", new_first_size))
    last:move(nil, string.format("%dpx", new_last_start + parent_offset))
    last:resize(nil, string.format("%dpx", new_last_size))
  end

  -- Remember our split so a window resize (which lets the parent Box re-impose
  -- its own distribution) can restore it afterwards: the proportional ratio
  -- always, plus the anchored pane's pixel size when an anchor is set. Skip
  -- this mid-restore so a too-small container can't overwrite the user's
  -- intended split with a clamped value.
  if not splitter.restoring then
    splitter.position_ratio = splitter:getPositionRatio()
    if splitter.anchor then
      splitter.anchor_size = get_size(orientation, widgets[splitter.anchor])
    elseif splitter.sticky then
      -- Record which pane, if any, is currently jammed against its min so a
      -- later resize can keep it pinned there instead of replaying the ratio.
      if new_position <= first_min then
        splitter.sticky_pin = widget_elements.first
      elseif new_position >= last_max then
        splitter.sticky_pin = widget_elements.last
      else
        splitter.sticky_pin = nil
      end
    end
  end
end

-- Mouse event types
local types = { "click", "move", "release" }
--- Label click/move/release callback that drives bar dragging.
---@param self Geyser.Splitter
---@param event_type string "click", "move", or "release"
---@param mouse table Mudlet mouse-event info
function mouse_event(self, event_type, mouse)
  if not self.connected then return end
  if not table.index_of(types, event_type) then return end

  -- If this was a regular click event, check if it was a left button click,
  -- and if so, set the moving flag to true.
  if event_type == "click" then
    if mouse.button ~= "LeftButton" then return end
    self.moving = true
    return
  end

  -- If we aren't moving, then don't do anything.
  if not self.moving then return end

  -- Convert the mouse position (which is relative to the bar) into the
  -- track-local coordinate update_widgets expects: bar's track-local position
  -- plus the offset of the cursor within the bar.
  update_widgets(self, self:getPosition() + mouse[self.mouse_property])

  -- If this was a release event, stop moving.
  if event_type == "release" then
    self.moving = false
    return
  end

  -- Since we can only get 3 event types and we've handled click and release,
  -- this must be a move event. But we've already moved everything.
  -- So, we don't need to do anything here. Cya.
end

--- The splitter's orientation as a readable string, "horizontal" or "vertical"
--- (the `orientation` field itself is the normalised integer 1 or 2).
---@return string
function Geyser.Splitter:getOrientation()
  return orientations_reverse[self.orientation]
end

--- The smallest position setPosition() accepts: 0, the start of the first pane.
---@return number
function Geyser.Splitter:getMin() return 0 end

--- The largest position setPosition() accepts: the length of the track, i.e. the
--- end of the last pane.
---@return number
function Geyser.Splitter:getMax()
  return self:getMin() + get_track_size(self)
end

--- The start of the splitter's track as an absolute coordinate (pixels from the
--- main window origin), i.e. the first pane's start.
---@return number
function Geyser.Splitter:getAbsoluteMin()
  return get_start(self.orientation, self.widgets[1])
end

--- The end of the splitter's track as an absolute coordinate (pixels from the
--- main window origin), i.e. the last pane's end.
---@return number
function Geyser.Splitter:getAbsoluteMax()
  return self:getAbsoluteMin() + get_track_size(self)
end

--- Move the split to an absolute position, in pixels from the start of the first
--- pane (0 to getMax()). Positions that would violate a pane's margins are
--- clamped.
---@param position number
function Geyser.Splitter:setPosition(position)
  assert(position ~= nil, "position is a required argument")
  assert(type(position) == "number", "position must be a number")

  update_widgets(self, position)
end

--- Move the split by a pixel delta relative to its current position. Positive
--- grows the first pane, negative shrinks it.
---@param position number
function Geyser.Splitter:adjustPosition(position)
  assert(position ~= nil, "position is a required argument")
  assert(type(position) == "number", "position must be a number")

  update_widgets(self, self:getPosition() + position)
end

--- The current split position, in pixels from the start of the first pane.
---@return number
function Geyser.Splitter:getPosition()
  return get_start(self.orientation, self.widgets[2]) -
      get_start(self.orientation, self.widgets[1])
end

--- Move the split to a percentage (0-100) of the track's total size, e.g. 30
--- puts the bar about 30% of the way along.
---@param position number
function Geyser.Splitter:setPositionRatio(position)
  assert(position ~= nil, "position is a required argument")
  assert(type(position) == "number", "position must be a number")

  local max = self:getMax()
  local ratio = _percent_of(position, max)
  self:setPosition(ratio)
end

--- The current split position as a percentage (0-100) of the track's total size.
---@return number
function Geyser.Splitter:getPositionRatio()
  return _percent(self:getPosition(), get_track_size(self))
end

--- The bar's current start as an absolute coordinate (pixels from the main
--- window origin).
---@return number
function Geyser.Splitter:getAbsolutePosition()
  return get_start(self.orientation, self.widgets[2])
end

--- Reposition work for restore(), split out so restore() can pcall it (as an
--- upvalue, so no per-call closure) while still clearing the restoring flag.
---@param splitter Geyser.Splitter
local function apply_restore(splitter)
  if splitter.anchor then
    if splitter.anchor_size then
      local bar_size = get_size(splitter.orientation, splitter.widgets[2])
      if splitter.anchor == widget_elements.first then
        splitter:setPosition(splitter.anchor_size)
      else
        splitter:setPosition(splitter:getMax() - splitter.anchor_size - bar_size)
      end
    end
  elseif splitter.sticky and splitter.sticky_pin then
    -- A pane was jammed at its min: pin it to that min (in pixels, against the
    -- new container size) rather than replaying the proportional ratio.
    local bar_size = get_size(splitter.orientation, splitter.widgets[2])
    if splitter.sticky_pin == widget_elements.first then
      splitter:setPosition(get_min_bound(splitter, splitter.widgets[1]))
    else
      splitter:setPosition(splitter:getMax() - get_max_bound(splitter, splitter.widgets[3]) - bar_size)
    end
  else
    if splitter.position_ratio then
      splitter:setPositionRatio(splitter.position_ratio)
    end
  end
end

--- Re-apply the splitter's remembered split. Internal: the parent's reposition
--- wrapper calls this after the container relays its children (which would
--- otherwise impose its own distribution). With an anchor set, the anchored pane
--- keeps its pixel size and the other absorbs the delta; otherwise the split is
--- restored proportionally. Not part of the public API -- nothing outside this
--- file should need to call it.
---@param splitter Geyser.Splitter
local function restore(splitter)
  if not splitter.connected then return end

  -- Mark this as a restore so update_widgets doesn't overwrite the remembered
  -- (user-intended) split with the clamped value we get when the container is
  -- too small to honor it. Otherwise shrinking to nothing would re-capture the
  -- squashed size and "pin" the pane there, never recovering on regrow.
  --
  -- pcall so the flag is cleared even if apply_restore throws (e.g. reading
  -- geometry off a widget a parent has deleted); rethrow so the failure still
  -- surfaces instead of being silently swallowed.
  splitter.restoring = true
  local ok, err = pcall(apply_restore, splitter)
  splitter.restoring = false
  if not ok then error(err, 0) end
end

--- Detach the splitter: stop responding to drags and to the parent's relayout,
--- removing it from the parent's registry and unwrapping the parent's
--- reposition() once the last splitter on it is gone. Does NOT delete the
--- managed widgets -- they belong to the caller. Safe to call more than once.
function Geyser.Splitter:disconnect()
  self.connected = false

  local parent = self.parent_container
  if not parent or not parent.splitters then return end

  parent.splitters[self.name] = nil
  if not next(parent.splitters) then
    parent.reposition = parent.splitter_reposition
    parent.splitter_reposition = nil
    parent.splitters = nil
  end
end

--- Tear down the splitter's own footprint (identical to :disconnect()). Does
--- NOT delete the managed widgets: unlike Geyser.Container:delete(), which
--- cascades because a container OWNS its windowList, a Splitter owns nothing it
--- coordinates. If a parent later deletes those widgets the splitter is left
--- stranded, which is the caller's concern.
function Geyser.Splitter:delete()
  self:disconnect()
end

--- Construct a splitter. See the class description for the full list of options;
--- at minimum the orientation's three widgets (and `middle`) are required.
---@param cons table Construction options.
---@return Geyser.Splitter
function Geyser.Splitter:new(cons)
  local me = Geyser.copyTable(cons)

  assert(me.orientation == nil or orientations[me.orientation],
    "invalid orientation '" .. tostring(me.orientation) .. "' (expected \"horizontal\" or \"vertical\")")
  assert(me.cursor == nil or mudlet.cursor[me.cursor],
    "invalid cursor '" .. tostring(me.cursor) .. "' (must be a key of mudlet.cursor)")
  assert(me.sticky == nil or type(me.sticky) == "boolean",
    "sticky must be a boolean")
  assert(not (me.anchor and me.sticky),
    "anchor and sticky are mutually exclusive")
  -- anchor is validated below, once the orientation (and thus its valid side
  -- words) is resolved.

  me.type = me.type or "splitter"
  me.name = me.name or Geyser.nameGen()

  me.orientation = orientations[cons.orientation] or orientations.horizontal

  local orientation = me.orientation
  local orientation_string = orientations_reverse[orientation]
  local coord, descriptor = coords[orientation], descriptors[orientation]

  for _, v in ipairs(descriptor) do
    if not me[v] then
      local msg = "[" .. me.name .. "] " .. table.concat(descriptor, ", ") .. " are required for " .. orientation_string .. " splitters"
      -- If the caller supplied the OTHER orientation's side words, they most
      -- likely just forgot to set the orientation (which defaults to horizontal).
      local other = descriptors[3 - orientation]
      if me[other[1]] or me[other[3]] then
        msg = msg .. " (did you mean orientation = \"" .. orientations_reverse[3 - orientation] .. "\"?)"
      end

      error(msg)
    end
  end

  me.widgets = {}
  for _, v in ipairs(descriptor) do
    table.insert(me.widgets, me[v])
  end
  local first, bar, last = me.widgets[1], me.widgets[2], me.widgets[3]

  -- The panes must be siblings in one container: the geometry is computed in a
  -- single track-local space (parent_offset is derived from first.container),
  -- and only that container's reposition is hooked for restore(). Widgets in
  -- different containers can't be coordinated coherently, so reject it up front.
  assert(first.container == bar.container and first.container == last.container,
    "[" .. me.name .. "] splitter widgets must all share one parent container")

  me.cursor = me.cursor or ("Resize" .. orientation_string:gsub("^%l", string.upper))
  me.mouse_property = coord

  -- Normalize the anchor to a widget slot, seeding its size from the anchored
  -- pane. Only this orientation's own side words are accepted: "top" on a
  -- horizontal splitter is rejected rather than silently meaning "left", since
  -- the two map to the same slot and accepting both would be muddy.
  if me.anchor ~= nil then
    local valid = {
      [descriptor[1]] = widget_elements[descriptor[1]],
      [descriptor[3]] = widget_elements[descriptor[3]],
    }
    me.anchor = valid[me.anchor]
    assert(me.anchor,
      "[" .. me.name .. "] anchor must be '" .. descriptor[1] .. "' or '" .. descriptor[3] .. "' for " .. orientation_string .. " splitters")
    me.anchor_size = get_size(me.orientation, me.widgets[me.anchor])
  end

  -- Setup the margins
  local temp_margins = {}
  if me.margins then
    local margins_to_check = { descriptor[1], descriptor[3] }
    for _, v in ipairs(margins_to_check) do
      if not me.margins[v] then
        temp_margins[v] = { 0, 0 }
      else
        local num_margins = #me.margins[v]
        if num_margins > 2 then
          error("Invalid number of margins for " .. v .. ". Expected 1 or 2, got " .. num_margins)
        elseif num_margins == 0 then
          temp_margins[v] = { 0, 0 }
        elseif num_margins == 1 then
          temp_margins[v] = { me.margins[v][1], 0 }
        else
          temp_margins[v] = { me.margins[v][1], me.margins[v][2] }
        end
      end
    end
  else
    temp_margins = {
      [descriptor[1]] = { 0, 0 },
      [descriptor[3]] = { 0, 0 },
    }
  end
  me.margins = {
    first = temp_margins[descriptor[1]],
    last = temp_margins[descriptor[3]],
  }

  bar:setCursor(mudlet.cursor[me.cursor])

  -- The bar must be fixed-size along the splitter's axis so the parent treats it
  -- as a divider rather than stretching it. An auto-distributing Box (HBox/VBox)
  -- decides a child's fixed-ness at add() time -- organize() bakes Geyser.Fixed
  -- children into contains_fixed and only ever resizes Dynamic children, never
  -- resizing one back once it has squashed it to a dynamic share. So pinning the
  -- policy *here*, after the bar is already a child, is too late: it leaves the
  -- bar at its stretched width and the "divider" renders as a full pane. Require
  -- the caller to have created the bar Fixed up front in that case. A plain
  -- Geyser.Container never redistributes, so there we can still pin it ourselves.
  local bar_policy = orientation == orientations.horizontal and "h_policy" or "v_policy"
  if first.container and first.container.organize then
    assert(bar[bar_policy] == Geyser.Fixed,
      "[" .. me.name .. "] the middle bar must be created with " .. bar_policy ..
      " = Geyser.Fixed (and a fixed size along the axis) before it is added to a " ..
      tostring(first.container.type or "box") ..
      "; pinning it on the splitter is too late to take effect")
  else
    bar[bar_policy] = Geyser.Fixed
  end

  me.moving = false

  ---@diagnostic disable-next-line: redundant-parameter
  setLabelClickCallback(bar.name, mouse_event, me, "click")
  ---@diagnostic disable-next-line: redundant-parameter
  setLabelMoveCallback(bar.name, mouse_event, me, "move")
  ---@diagnostic disable-next-line: redundant-parameter
  setLabelReleaseCallback(bar.name, mouse_event, me, "release")

  -- A Splitter parents nothing, so it never receives a reposition() of its own,
  -- and the Box holding its widgets re-imposes its own distribution on every
  -- layout pass. We re-apply the stored split by wrapping the shared parent's
  -- reposition() and running restore() synchronously right after it -- not via a
  -- sysWindowResizeEvent handler, which fires asynchronously and races the
  -- relayout (the split visibly jitters).
  --
  -- The registry is name-keyed (not an array) so re-creating a splitter replaces
  -- its entry rather than duplicating it, and :disconnect() can drop an entry and
  -- unwrap the parent once the last splitter is gone.
  local parent = first.container
  me.parent_container = parent
  me.connected = true
  if parent then
    if not parent.splitter_reposition then
      parent.splitters = {}
      parent.splitter_reposition = parent.reposition
      parent.reposition = function(container, ...)
        container.splitter_reposition(container, ...)
        for _, sp in pairs(container.splitters) do
          restore(sp)
        end
      end
    end
    parent.splitters[me.name] = me
  end

  setmetatable(me, self)
  self.__index = self

  return me
end

--- Get the drag-limit constraints for one of the bounded panes.
---@param widget table The first or last pane of this splitter.
---@return table? # `{min_bound, max_bound}`, or nil if `widget` is not a bounded pane.
---@return string? # error message, present when the first return is nil.
function Geyser.Splitter:getConstraints(widget)
  local name = widget and widget.name
  if name ~= self.widgets[1].name and name ~= self.widgets[3].name then
    return nil, "[" .. self.name .. "] getConstraints: widget is not a bounded pane (first or last) of this splitter"
  end

  return {
    min_bound = get_min_bound(self, widget),
    max_bound = get_max_bound(self, widget),
  }
end

--- Minimum bound (margin) of a pane -- the first or last pane only.
--- getConstraints() validates the widget before calling, and update_widgets only
--- ever passes the panes, so the final error is an unreachable invariant guard.
---@param splitter Geyser.Splitter
---@param widget table
---@return number
function get_min_bound(splitter, widget)
  local name = widget and widget.name
  if name == splitter.widgets[1].name then
    return splitter.margins.first[1]
  elseif name == splitter.widgets[3].name then
    return splitter.margins.last[1]
  end
  error("[" .. splitter.name .. "] widget is not a bounded pane (first or last) of this splitter")
end

--- Maximum bound (margin) of a pane; see get_min_bound for the contract.
---@param splitter Geyser.Splitter
---@param widget table
---@return number
function get_max_bound(splitter, widget)
  local name = widget and widget.name
  if name == splitter.widgets[1].name then
    return splitter.margins.first[2]
  elseif name == splitter.widgets[3].name then
    return splitter.margins.last[2]
  end
  error("[" .. splitter.name .. "] widget is not a bounded pane (first or last) of this splitter")
end

--- Start coordinate of a widget along the splitter's axis (x for horizontal, y
--- for vertical), absolute from the main window origin.
---@param orientation integer
---@param widget table
---@return number
function get_start(orientation, widget)
  if orientation == orientations.horizontal then
    return widget.get_x()
  elseif orientation == orientations.vertical then
    return widget.get_y()
  else
    error("Invalid orientation")
  end
end

--- Size of a widget along the splitter's axis (width for horizontal, height for
--- vertical).
---@param orientation integer
---@param widget table
---@return number
function get_size(orientation, widget)
  if orientation == orientations.horizontal then
    return widget.get_width()
  elseif orientation == orientations.vertical then
    return widget.get_height()
  else
    error("Invalid orientation")
  end
end

--- The splitter's track length along its axis: from the first pane's start to the
--- end of the shared container. Single source of truth for "how long is the
--- track" -- measured from the container, never by re-summing the three child
--- sizes (those were last set via "%dpx", which floors, so re-summing would
--- ratchet the track a hair smaller every drag).
---@param splitter Geyser.Splitter
---@return number
function get_track_size(splitter)
  local orientation = splitter.orientation
  local first = splitter.widgets[1]
  local parent_offset = get_start(orientation, first) - get_start(orientation, first.container)

  return get_size(orientation, first.container) - parent_offset
end

--- What percentage `num` is of `den`. A zero denominator (fully collapsed track)
--- yields 0 rather than inf/nan, so a collapsed splitter can't poison the
--- remembered position_ratio.
---@param num number
---@param den number
---@return number
function _percent(num, den) return den == 0 and 0 or num * 100 / den end

--- `num` percent of `den`.
---@param num number
---@param den number
---@return number
function _percent_of(num, den) return num * den / 100 end

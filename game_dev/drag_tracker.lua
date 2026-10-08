--[[
    drag_tracker.lua - pure logic for a floating button that can be dragged, tapped and locked.
    No Roblox APIs, so it is unit-tested outside the engine (tests/run_tests.lua).

      local t = DragTracker.new(8)            -- pixels of movement before a press counts as a drag
      t:begin(px, py, originX, originY)       -- pointer went down
      local x, y = t:move(px, py)             -- pointer moved: new origin once it is really a drag, else nil
      t:finish(now)                           -- pointer released
      t:suppressClick(now)                    -- true if a Click event right now is just the end of a drag
      t:setLocked(true)                       -- locked: never drags, taps always work
      DragTracker.clamp(x, y, w, h, vw, vh, margin)  -- keep a w*h box inside the screen
]]

local M = {}

function M.new(threshold)
    local self = {threshold = threshold or 8, locked = false, active = false, moved = false, lastDragEnd = nil}
    local sx, sy, ox, oy = 0, 0, 0, 0

    function self:setLocked(v)
        self.locked = v and true or false
        if self.locked then self.moved = false end
    end

    function self:begin(px, py, originX, originY)
        self.active, self.moved = true, false
        sx, sy, ox, oy = px, py, originX, originY
    end

    function self:move(px, py)
        if not self.active or self.locked then return nil end
        local dx, dy = px - sx, py - sy
        if not self.moved then
            if dx * dx + dy * dy < self.threshold * self.threshold then return nil end
            self.moved = true
        end
        return ox + dx, oy + dy
    end

    function self:finish(now)
        if self.active and self.moved then self.lastDragEnd = now end
        self.active, self.moved = false, false
    end

    -- The Click event of a released drag can arrive before OR after the pointer-up event, so both
    -- orders are handled: still dragging now, or a drag ended a moment ago.
    function self:suppressClick(now)
        if self.active and self.moved then return true end
        return self.lastDragEnd ~= nil and (now - self.lastDragEnd) < 0.25
    end

    return self
end

function M.clamp(x, y, w, h, vw, vh, margin)
    margin = margin or 0
    local maxX = math.max(margin, vw - w - margin)
    local maxY = math.max(margin, vh - h - margin)
    return math.min(math.max(x, margin), maxX), math.min(math.max(y, margin), maxY)
end

return M

-- Layout engine for the fake Roblox world: computes AbsolutePosition / AbsoluteSize the way Roblox does for the things the hub's UI uses
-- (UDim2 size/position + AnchorPoint, UIPadding, UIListLayout, AutomaticSize, ScrollingFrame canvas, wrapped text) and turns the result into
-- a draw list that tools/render_preview.py paints into a PNG. Also reports layout PROBLEMS (text that does not fit, controls that overlap,
-- objects outside the window, default "Label"/"Button" text, visible borders, tiny touch targets).
-- Text widths come from a table of per-character advance widths modelled on Gotham (slightly generous), not from a real font.
local World = MM2_WORLD

local GUI = {Frame = true, TextLabel = true, TextButton = true, TextBox = true, ImageLabel = true, ImageButton = true, ScrollingFrame = true, CanvasGroup = true}
local TEXTY = {TextLabel = true, TextButton = true, TextBox = true}
local max, min, floor = math.max, math.min, math.floor

local function D(inst) return rawget(inst, "__d") end
local function P(d, k, default) local v = d.props[k]; if v == nil then return default end return v end

-- Gotham-like advance widths (fraction of the font size)
local NARROW = {i = .26, l = .26, j = .26, ["."] = .27, [","] = .27, [":"] = .27, [";"] = .27, ["'"] = .2, ["|"] = .26, ["!"] = .28, I = .3, f = .34, t = .37, r = .39, [" "] = .29}
local WIDE = {m = .92, w = .8, M = .9, W = 1.0, O = .82, Q = .82, G = .78, D = .78, H = .78, N = .78, U = .76, C = .74, B = .72, R = .72, A = .74, K = .72, V = .72, X = .7, Y = .68}
local function charWidth(c)
    if NARROW[c] then return NARROW[c] end
    if WIDE[c] then return WIDE[c] end
    if c:match("%u") then return .68 end
    if c:match("%d") then return .62 end
    if c:match("%l") then return .58 end
    if c == "(" or c == ")" or c == "[" or c == "]" then return .36 end
    if c == "-" then return .4 end
    if c == "/" then return .42 end
    return .62
end
local function textWidth(text, size, factor)
    local w = 0
    for i = 1, #text do w = w + charWidth(text:sub(i, i)) end
    return w * size * (factor or 1)
end
local function fontFactor(font)
    local n = font and font.Name or ""
    if n:find("Bold") or n:find("Black") then return 1.1 end
    if n:find("Medium") or n:find("SemiBold") then return 1.04 end
    return 1.0
end
local function wrap(text, size, factor, maxW)
    local lines, cur = {}, ""
    for line in (text .. "\n"):gmatch("(.-)\n") do
        cur = ""
        for word in line:gmatch("%S+") do
            local try = cur == "" and word or (cur .. " " .. word)
            if cur ~= "" and textWidth(try, size, factor) > maxW then lines[#lines + 1] = cur; cur = word else cur = try end
        end
        lines[#lines + 1] = cur
    end
    return lines
end
local LINE = 1.16

function World:layout(gui, vp)
    local W = self
    local cache = {}
    vp = vp or rawget(W.camera, "__d").props.ViewportSize
    W.layoutProblems = {}
    local function problem(inst, msg) W.layoutProblems[#W.layoutProblems + 1] = W.M.GetFullName(inst) .. ": " .. msg end

    local function kidsOf(d, onlyGui)
        local out = {}
        for _, c in ipairs(d.children) do
            local cd = D(c)
            if not onlyGui or GUI[cd.class] then out[#out + 1] = c end
        end
        return out
    end
    local function childOfClass(d, class)
        for _, c in ipairs(d.children) do if D(c).class == class then return c end end
    end
    local function visible(d) return P(d, "Visible", true) ~= false end
    local function paddingOf(d, w, h)
        local pad = childOfClass(d, "UIPadding")
        if not pad then return 0, 0, 0, 0 end
        local pd = D(pad).props
        local function r(u, base) return u and (u.Scale * base + u.Offset) or 0 end
        return r(pd.PaddingLeft, w), r(pd.PaddingTop, h), r(pd.PaddingRight, w), r(pd.PaddingBottom, h)
    end
    local function listOf(d)
        local l = childOfClass(d, "UIListLayout")
        return l and D(l).props
    end
    local function textOf(d)
        local t = d.props.Text
        if t == nil then t = d.class == "TextLabel" and "Label" or d.class == "TextButton" and "Button" or "" end
        return t
    end
    local function autoOf(d)
        local a = d.props.AutomaticSize
        local n = a and a.Name or "None"
        return n:find("X") ~= nil, n:find("Y") ~= nil
    end

    local measure, layoutNode

    -- the extent of a node's children (and, when `place`, put them where they belong)
    local function layoutChildren(inst, d, cx, cy, cw, ch, place, canvasOffsetY)
        local kids = {}
        for _, c in ipairs(kidsOf(d, true)) do if visible(D(c)) then kids[#kids + 1] = c end end
        local list = listOf(d)
        local extentW, extentH = 0, 0
        if list then
            local order = {}
            for i, c in ipairs(kids) do order[i] = {c = c, i = i, lo = P(D(c), "LayoutOrder", 0)} end
            if list.SortOrder and list.SortOrder.Name == "LayoutOrder" then
                table.sort(order, function(a, b) if a.lo ~= b.lo then return a.lo < b.lo end return a.i < b.i end)
            end
            local vertical = not (list.FillDirection and list.FillDirection.Name == "Horizontal")
            local pad = list.Padding and (list.Padding.Scale * (vertical and ch or cw) + list.Padding.Offset) or 0
            local sizes, total = {}, 0
            for i, o in ipairs(order) do
                local kw, kh = measure(o.c, cw, ch)
                sizes[i] = {kw, kh}
                total = total + (vertical and kh or kw) + (i > 1 and pad or 0)
            end
            local cross = 0
            for i = 1, #order do cross = max(cross, vertical and sizes[i][1] or sizes[i][2]) end
            extentW, extentH = vertical and cross or total, vertical and total or cross
            if place then
                local ha = list.HorizontalAlignment and list.HorizontalAlignment.Name or "Left"
                local va = list.VerticalAlignment and list.VerticalAlignment.Name or "Top"
                local pos = 0
                if vertical then pos = va == "Bottom" and (ch - total) or va == "Center" and (ch - total) / 2 or 0
                else pos = ha == "Right" and (cw - total) or ha == "Center" and (cw - total) / 2 or 0 end
                for i, o in ipairs(order) do
                    local kw, kh = sizes[i][1], sizes[i][2]
                    local px, py
                    if vertical then
                        px = ha == "Right" and (cw - kw) or ha == "Center" and (cw - kw) / 2 or 0
                        py = pos; pos = pos + kh + pad
                    else
                        py = va == "Bottom" and (ch - kh) or va == "Center" and (ch - kh) / 2 or 0
                        px = pos; pos = pos + kw + pad
                    end
                    layoutNode(o.c, cx + px, cy + py - (canvasOffsetY or 0), kw, kh)
                end
            end
        else
            for _, c in ipairs(kids) do
                local cd = D(c)
                local kw, kh = measure(c, cw, ch)
                local pos = P(cd, "Position", nil)
                local anchor = P(cd, "AnchorPoint", nil)
                local px = pos and (pos.X.Scale * cw + pos.X.Offset) or 0
                local py = pos and (pos.Y.Scale * ch + pos.Y.Offset) or 0
                px = px - (anchor and anchor.X or 0) * kw
                py = py - (anchor and anchor.Y or 0) * kh
                extentW, extentH = max(extentW, px + kw), max(extentH, py + kh)
                if place then layoutNode(c, cx + px, cy + py - (canvasOffsetY or 0), kw, kh) end
            end
        end
        return extentW, extentH
    end

    function measure(inst, pw, ph)
        local c = cache[inst]
        if c and c.pw == pw and c.ph == ph then return c.w, c.h end
        local d = D(inst)
        local sz = P(d, "Size", nil)
        local w = sz and (sz.X.Scale * pw + sz.X.Offset) or 0
        local h = sz and (sz.Y.Scale * ph + sz.Y.Offset) or 0
        local ax, ay = autoOf(d)
        if ax or ay then
            local pl, pt, pr, pb = paddingOf(d, w, h)
            if TEXTY[d.class] then
                local size = P(d, "TextSize", 14)
                local factor = fontFactor(P(d, "Font", nil))
                local text = textOf(d)
                local lines
                if P(d, "TextWrapped", false) and not ax then lines = wrap(text, size, factor, max(1, w - pl - pr)) else lines = {text} end
                local tw = 0
                for _, l in ipairs(lines) do tw = max(tw, textWidth(l, size, factor)) end
                if ax then w = max(w, tw + pl + pr) end
                if ay then h = max(h, #lines * size * LINE + pt + pb) end
            else
                local cw, ch = max(0, w - pl - pr), max(0, h - pt - pb)
                local ew, eh = layoutChildren(inst, d, 0, 0, ax and 0 or cw, ay and 0 or ch, false)
                if ax then w = max(w, ew + pl + pr) end
                if ay then h = max(h, eh + pt + pb) end
            end
        end
        cache[inst] = {pw = pw, ph = ph, w = w, h = h}
        return w, h
    end

    function layoutNode(inst, x, y, w, h)
        local d = D(inst)
        d.lay = {x = x, y = y, w = w, h = h}
        d.props.AbsolutePosition = self.env.Vector2.new(x, y)
        d.props.AbsoluteSize = self.env.Vector2.new(w, h)
        local pl, pt, pr, pb = paddingOf(d, w, h)
        local cx, cy, cw, ch = x + pl, y + pt, max(0, w - pl - pr), max(0, h - pt - pb)
        if d.class == "ScrollingFrame" then
            local auto = d.props.AutomaticCanvasSize and d.props.AutomaticCanvasSize.Name or "None"
            local cpos = d.props.CanvasPosition
            local scroll = cpos and cpos.Y or 0
            local ew, eh = layoutChildren(inst, d, cx, cy, cw, ch, false)
            local canvasH = auto:find("Y") and eh + pt + pb or ((d.props.CanvasSize and (d.props.CanvasSize.Y.Scale * h + d.props.CanvasSize.Y.Offset)) or h)
            d.lay.canvasH = canvasH
            d.lay.contentW = ew
            layoutChildren(inst, d, cx, cy, cw, max(ch, canvasH), true, scroll)
        else
            layoutChildren(inst, d, cx, cy, cw, ch, true)
        end
    end

    -- screen gui roots
    local d = D(gui)
    local inset = (P(d, "IgnoreGuiInset", false)) and 0 or 36
    d.lay = {x = 0, y = 0, w = vp.X, h = vp.Y}
    local cw, ch = vp.X, vp.Y - inset
    cache = {}
    for _, c in ipairs(kidsOf(d, true)) do
        if visible(D(c)) then
            local kw, kh = measure(c, cw, ch)
            local pos, anchor = P(D(c), "Position", nil), P(D(c), "AnchorPoint", nil)
            local px = pos and (pos.X.Scale * cw + pos.X.Offset) or 0
            local py = pos and (pos.Y.Scale * ch + pos.Y.Offset) or 0
            layoutNode(c, px - (anchor and anchor.X or 0) * kw, inset + py - (anchor and anchor.Y or 0) * kh, kw, kh)
        end
    end
    return W
end

-- draw list (z order) + problem report -------------------------------------------------------
local function col(c) return c and {floor(c.R * 255 + 0.5), floor(c.G * 255 + 0.5), floor(c.B * 255 + 0.5)} or nil end

function World:drawList(gui, opts)
    opts = opts or {}
    local W = self
    local ops, problems = {}, {}
    local function problem(inst, msg) problems[#problems + 1] = W.M.GetFullName(inst) .. ": " .. msg end
    local function inter(a, b)
        if not a then return b end
        if not b then return a end
        local x1, y1 = max(a[1], b[1]), max(a[2], b[2])
        local x2, y2 = min(a[1] + a[3], b[1] + b[3]), min(a[2] + a[4], b[2] + b[4])
        return {x1, y1, max(0, x2 - x1), max(0, y2 - y1), a[5] or b[5]}
    end
    local function walk(inst, clip, depth)
        local d = D(inst)
        if not GUI[d.class] or P(d, "Visible", true) == false or not d.lay then return end
        local L = d.lay
        local bgT = P(d, "BackgroundTransparency", 0)
        local op = {t = "rect", x = L.x, y = L.y, w = L.w, h = L.h, clip = clip, name = d.name, class = d.class}
        local corner, stroke, grad
        for _, c in ipairs(d.children) do
            local cd = D(c)
            if cd.class == "UICorner" then corner = cd.props.CornerRadius
            elseif cd.class == "UIStroke" then stroke = cd.props
            elseif cd.class == "UIGradient" then grad = cd.props end
        end
        if corner then op.radius = corner.Scale * min(L.w, L.h) + corner.Offset end
        op.rot = P(d, "Rotation", 0)
        if bgT < 1 and L.w > 0 and L.h > 0 then
            local c = P(d, "BackgroundColor3", nil)
            op.color = c and col(c) or {163, 162, 165}
            op.alpha = 1 - bgT
            if grad then
                local seq = {}
                for _, k in ipairs(grad.Color and grad.Color.keys or {}) do seq[#seq + 1] = {k.t, col(k.v)} end
                local tr = {}
                for _, k in ipairs(grad.Transparency and grad.Transparency.keys or {}) do tr[#tr + 1] = {k.t, k.v} end
                op.grad = {color = seq, transparency = tr, rotation = grad.Rotation or 0, offset = grad.Offset and {grad.Offset.X, grad.Offset.Y} or {0, 0}}
            end
            ops[#ops + 1] = op
        end
        if stroke and P(d, "Visible", true) then
            ops[#ops + 1] = {t = "stroke", x = L.x, y = L.y, w = L.w, h = L.h, clip = clip, radius = op.radius, rot = op.rot,
                             color = col(stroke.Color) or {255, 255, 255}, thickness = stroke.Thickness or 1, alpha = 1 - (stroke.Transparency or 0)}
        end
        if bgT < 1 and (d.props.BorderSizePixel == nil or d.props.BorderSizePixel ~= 0) and d.class ~= "ScrollingFrame" then
            problem(inst, "BorderSizePixel is not 0 (Roblox draws a black border)")
        end
        if d.class == "ImageLabel" and (d.props.Image or "") ~= "" then
            ops[#ops + 1] = {t = "image", x = L.x, y = L.y, w = L.w, h = L.h, clip = clip, radius = op.radius, name = d.props.Image}
        end
        if TEXTY[d.class] then
            local text = d.props.Text
            if text == nil and d.class ~= "TextBox" then problem(inst, "has no Text set (Roblox shows the default \"" .. (d.class == "TextLabel" and "Label" or "Button") .. "\")") end
            if text == nil then text = d.class == "TextLabel" and "Label" or d.class == "TextButton" and "Button" or "" end
            if d.class == "TextBox" and text == "" then text = d.props.PlaceholderText or "" end
            if text ~= "" and (P(d, "TextTransparency", 0) < 1) then
                local size = P(d, "TextSize", 14)
                local factor = fontFactor(P(d, "Font", nil))
                local pl = 0
                local lines = {text}
                local wrapped = P(d, "TextWrapped", false)
                if wrapped then lines = wrap(text, size, factor, L.w) end
                local widest = 0
                for _, l in ipairs(lines) do widest = max(widest, textWidth(l, size, factor)) end
                local truncates = P(d, "TextTruncate", nil)
                truncates = truncates and truncates.Name == "AtEnd"
                if not wrapped and widest > L.w + 0.5 then
                    problem(inst, string.format("text \"%s\" is %.0fpx wide but the label is %.0fpx (%s)", text:sub(1, 40), widest, L.w, truncates and "truncated with ..." or "overflows"))
                end
                local autoSized = d.props.AutomaticSize and d.props.AutomaticSize.Name ~= "None"
                if #lines * size * LINE > L.h + 1 and not autoSized then
                    problem(inst, string.format("%d line(s) of text %dpx need %.0fpx but the label is %.0fpx high", #lines, size, #lines * size * LINE, L.h))
                end
                local xa = P(d, "TextXAlignment", nil)
                local ya = P(d, "TextYAlignment", nil)
                ops[#ops + 1] = {t = "text", x = L.x, y = L.y, w = L.w, h = L.h, clip = clip, lines = lines, size = size,
                                 bold = (P(d, "Font", nil) and P(d, "Font", nil).Name or ""):find("Bold") ~= nil, medium = (P(d, "Font", nil) and P(d, "Font", nil).Name or ""):find("Medium") ~= nil,
                                 color = col(P(d, "TextColor3", nil)) or {27, 42, 53}, alpha = 1 - P(d, "TextTransparency", 0),
                                 xa = xa and xa.Name or "Center", ya = ya and ya.Name or "Center", name = d.name,
                                 placeholder = d.class == "TextBox" and (d.props.Text or "") == ""}
            end
        end
        local childClip = clip
        if P(d, "ClipsDescendants", false) or d.class == "ScrollingFrame" or d.class == "CanvasGroup" then
            childClip = inter(clip, {L.x, L.y, L.w, L.h})
            if d.class == "CanvasGroup" and corner then childClip = {childClip[1], childClip[2], childClip[3], childClip[4], op.radius} end   -- rounded clip
        end
        local kids = {}
        for i, c in ipairs(d.children) do kids[#kids + 1] = {c = c, i = i, z = P(D(c), "ZIndex", 1)} end
        table.sort(kids, function(a, b) if a.z ~= b.z then return a.z < b.z end return a.i < b.i end)
        for _, k in ipairs(kids) do walk(k.c, childClip, depth + 1) end
    end
    walk(gui, nil, 0)
    -- the gui's own children are walked via `walk(gui)`: a ScreenGui is not a GuiObject, so walk its children directly
    local d = D(gui)
    if not GUI[d.class] then
        local kids = {}
        for i, c in ipairs(d.children) do kids[#kids + 1] = {c = c, i = i, z = P(D(c), "ZIndex", 1)} end
        table.sort(kids, function(a, b) if a.z ~= b.z then return a.z < b.z end return a.i < b.i end)
        for _, k in ipairs(kids) do walk(k.c, nil, 1) end
    end
    return ops, problems
end

-- every ScreenGui under CoreGui (and my PlayerGui), in DisplayOrder, merged into one draw list
function World:previewAll(vp)
    vp = vp or rawget(self.camera, "__d").props.ViewportSize
    local guis = {}
    for _, root in ipairs({self.coreGui, self.localPlayer and self.M.FindFirstChildOfClass(self.localPlayer, "PlayerGui")}) do
        if root then
            for _, c in ipairs(self.M.GetChildren(root)) do
                if D(c).class == "ScreenGui" and (D(c).props.Enabled ~= false) then guis[#guis + 1] = c end
            end
        end
    end
    table.sort(guis, function(a, b) return (D(a).props.DisplayOrder or 0) < (D(b).props.DisplayOrder or 0) end)
    local ops, problems = {}, {}
    for _, g in ipairs(guis) do
        self:layout(g, vp)
        local o, p = self:drawList(g)
        for _, x in ipairs(o) do ops[#ops + 1] = x end
        for _, x in ipairs(p) do problems[#problems + 1] = x end
        for _, x in ipairs(self.layoutProblems) do problems[#problems + 1] = x end
    end
    return {w = vp.X, h = vp.Y, ops = ops, problems = problems}
end
function World:previewJson(vp) return self.jsonEncode(self:previewAll(vp)) end

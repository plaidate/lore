-- Lore core: the windowing system. Every window is a Kit state
-- (translucent, so the field keeps drawing beneath): dialog boxes
-- (typewriter, word wrap, auto-pagination, A advances / B completes),
-- choice windows, the standard pause menu (Items/Status/Save + game
-- sections), shop and inn flows, HP bars, a pooled world-space damage
-- popup, and the full-screen dither fade (hosted on Kit.fxUpdate/
-- fxDraw so it runs above the whole stack). DQ look: black panels,
-- double white border, white text.
--
-- INPUT CONTRACT: UI states read the game's global Input table —
-- Input.a/b/up/down must be EDGE-TRIGGERED (true one poll after the
-- press). The smoke autopilot feeds the same fields synthetically, so
-- windows are drivable by script. Crank also scrolls lists (house
-- rule). Every state carries st.ui=true, st.kind, st.sel, st.rows —
-- the introspection surface autopilots steer by.
--
-- Zero per-frame draw allocation: wrap buffers persist, popups pool;
-- the typewriter slices a string only while actively typing.

local gfx = playdate.graphics

UI = {
    menuActive = false,
    fadeLevel = 0, -- 0 clear .. 1 black (drawn as the dither ramp)
}

local LH = 18 -- line height, px (system font is 16 tall)

-- ---- panels (DQ look: black, double white border) -------------------------

function UI.panel(x, y, w, h)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(x, y, w, h)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(x, y, w, h)
    gfx.drawRect(x + 2, y + 2, w - 4, h - 4)
end

-- cached "NNg" purse readout (rebuilt only when gold changes) — the
-- zero-alloc way to put gold in a per-frame draw
local goldVal, goldStr = -1, ""

function UI.goldStr()
    if State.gold ~= goldVal then
        goldVal = State.gold
        goldStr = State.gold .. "g"
    end
    return goldStr
end

-- ---- word wrap (persistent buffers; runs at window-open time) -------------

-- wrap text into out[1..n] lines fitting width px; returns n
function UI.wrap(text, width, out)
    local n, line = 0, nil
    for word in text:gmatch("%S+") do
        local try = line and (line .. " " .. word) or word
        if line and gfx.getTextSize(try) > width then
            n = n + 1
            out[n] = line
            line = word
        else
            line = try
        end
    end
    if line then
        n = n + 1
        out[n] = line
    end
    return n
end

-- ---- dialog box -----------------------------------------------------------
-- Bottom panel, optional nameplate, typewriter at 2 chars/frame.
-- A: completes the page if typing, else next page / close. B: same
-- (the classic skip). cb fires after the box pops.

local DLG = { X = 8, Y = 168, W = 384, H = 64, PAD = 12, ROWS = 3 }

function UI.dialog(who, text, cb)
    local st = {
        ui = true, kind = "dialog", translucent = true,
        who = who, lines = {}, n = 0,
        page = 1,   -- first line index of the current page
        chars = 0,  -- chars revealed on this page
        total = 0,  -- chars on this page when fully shown
    }
    st.n = UI.wrap(text, DLG.W - DLG.PAD * 2, st.lines)
    local function pageTotal()
        local t = 0
        local last = math.min(st.page + DLG.ROWS - 1, st.n)
        for i = st.page, last do t = t + #st.lines[i] end
        return t
    end
    st.total = pageTotal()
    st.update = function(dt)
        if st.chars < st.total then
            st.chars = math.min(st.total, st.chars + 2)
            if Input.a or Input.b then st.chars = st.total end
            return
        end
        if Input.a or Input.b then
            Harness.count("saidLines")
            if st.page + DLG.ROWS <= st.n then
                st.page = st.page + DLG.ROWS
                st.chars, st.total = 0, pageTotal()
            else
                Kit.pop()
                if cb then cb() end
            end
        end
    end
    st.draw = function()
        UI.panel(DLG.X, DLG.Y, DLG.W, DLG.H)
        if st.who then
            local w = gfx.getTextSize(st.who)
            UI.panel(DLG.X + 8, DLG.Y - 16, w + 16, 22)
            Gfx.text(st.who, DLG.X + 16, DLG.Y - 13)
        end
        local left = st.chars
        local last = math.min(st.page + DLG.ROWS - 1, st.n)
        for i = st.page, last do
            local line = st.lines[i]
            local y = DLG.Y + 8 + (i - st.page) * LH
            if left >= #line then
                Gfx.text(line, DLG.X + DLG.PAD, y)
                left = left - #line
            elseif left > 0 then
                Gfx.text(line:sub(1, left), DLG.X + DLG.PAD, y)
                left = 0
            end
        end
        if st.chars >= st.total then -- more-arrow
            Gfx.text("*>*", DLG.X + DLG.W - 22, DLG.Y + DLG.H - 20)
        end
    end
    return Kit.push(st)
end

-- ---- shared list navigation (d-pad + crank; edge-triggered) ---------------

local function listNav(st)
    local moved = 0
    if Input.up then moved = -1 end
    if Input.down then moved = 1 end
    local t = playdate.getCrankTicks(12)
    if t ~= 0 then moved = moved + (t > 0 and 1 or -1) end
    if moved ~= 0 and st.n > 0 then
        st.sel = (st.sel - 1 + moved) % st.n + 1
    end
end

-- ---- choice window --------------------------------------------------------
-- cb(index) on A; cb(nil) on B when cancelable. Sized to content,
-- sits above the dialog row on the right.

function UI.choose(text, options, cb, cancelable)
    local st = {
        ui = true, kind = "choose", translucent = true,
        sel = 1, n = #options, rows = options, text = text,
    }
    local w = 90
    if text then w = math.max(w, gfx.getTextSize(text) + 28) end
    for i = 1, st.n do
        w = math.max(w, gfx.getTextSize(options[i]) + 44)
    end
    local top = text and 24 or 8
    local h = top + st.n * LH + 8
    local x, y = 400 - 10 - w, 164 - h
    st.update = function(dt)
        listNav(st)
        if Input.a then
            Kit.pop()
            if cb then cb(st.sel) end
        elseif Input.b and cancelable then
            Kit.pop()
            if cb then cb(nil) end
        end
    end
    st.draw = function()
        UI.panel(x, y, w, h)
        if text then Gfx.text(text, x + 12, y + 6) end
        for i = 1, st.n do
            local ry = y + top + (i - 1) * LH
            if i == st.sel then Gfx.text("*>*", x + 8, ry) end
            Gfx.text(options[i], x + 24, ry)
        end
    end
    return Kit.push(st)
end

-- ---- generic list window (menu items, shop stock) -------------------------
-- spec = { title=, rows={strings}, tag=, onA=fn(i, st), onB=fn(st),
--          x=, y=, w=, foot= }. onA/onB own popping. st.rebuild(rows)
-- swaps the row set in place.

function UI.list(spec)
    local st = {
        ui = true, kind = "list", translucent = true,
        tag = spec.tag, sel = 1, rows = spec.rows, n = #spec.rows,
    }
    local x = spec.x or 96
    local y = spec.y or 24
    local w = spec.w or 208
    local VIS = 7
    st.rebuild = function(rows)
        st.rows, st.n = rows, #rows
        if st.sel > st.n then st.sel = math.max(1, st.n) end
    end
    st.update = function(dt)
        listNav(st)
        if Input.a and st.n > 0 then
            spec.onA(st.sel, st)
        elseif Input.b then
            if spec.onB then spec.onB(st) else Kit.pop() end
        end
    end
    st.draw = function()
        local vis = math.min(st.n, VIS)
        local h = 30 + math.max(vis, 1) * LH +
            (spec.foot and 18 or 0)
        UI.panel(x, y, w, h)
        Gfx.text(spec.title, x + 12, y + 6)
        local off = 0
        if st.sel > VIS then off = st.sel - VIS end
        for i = 1, vis do
            local ri = i + off
            local ry = y + 26 + (i - 1) * LH
            if ri == st.sel then Gfx.text("*>*", x + 8, ry) end
            Gfx.text(st.rows[ri], x + 24, ry)
        end
        if st.n == 0 then Gfx.text("- nothing -", x + 24, y + 26) end
        if spec.foot then
            Gfx.text(spec.foot(), x + 12, y + h - 22)
        end
    end
    return Kit.push(st)
end

-- ---- the pause menu -------------------------------------------------------
-- Sections: Items (use/discard), Status (party page), Save, plus
-- game-registered ones (UI.addMenuSection). B closes. UI.menuActive
-- is the open flag scripts wait on.

UI.sections = {} -- { {name=, run=fn()} }

function UI.addMenuSection(name, run)
    UI.sections[#UI.sections + 1] = { name = name, run = run }
end

-- overridable: use an item from the menu; return true to consume
UI.useItem = function(item)
    Kit.toast("Nothing happened.")
    return false
end

local function itemRows(rows, ids)
    local n = 0
    for id in pairs(State.inv) do
        n = n + 1
        ids[n] = id
    end
    table.sort(ids, function(a, b) return a < b end)
    for i = #ids, n + 1, -1 do ids[i] = nil end
    for i = 1, n do
        rows[i] = ids[i] .. " x" .. State.inv[ids[i]]
    end
    for i = #rows, n + 1, -1 do rows[i] = nil end
    return rows
end

local function openItems()
    local rows, ids = {}, {}
    itemRows(rows, ids)
    UI.list{
        title = "Items", tag = "items", rows = rows,
        onA = function(i, st)
            local id = ids[i]
            UI.choose(id, { "Use", "Discard", "Back" }, function(c)
                if c == 1 then
                    if UI.useItem(id) then State.take(id, 1) end
                elseif c == 2 then
                    State.take(id, 1)
                    Kit.toast("Tossed the " .. id .. ".")
                end
                st.rebuild(itemRows(rows, ids))
            end)
        end,
    }
end

local function openStatus()
    -- row strings built once at open (schema-tolerant: wave 3 fills
    -- the party tables; anything missing gets a placeholder)
    local names, lvs = {}, {}
    local party = State.party
    local n = math.min(#party, 4)
    for i = 1, n do
        local m = party[i]
        names[i] = tostring(m.name or ("Member " .. i))
        lvs[i] = "LV " .. tostring(m.lv or m.level or 1)
    end
    local st = {
        ui = true, kind = "status", translucent = true,
        sel = 1, n = n, rows = names,
    }
    st.update = function(dt)
        if Input.b or Input.a then Kit.pop() end
    end
    st.draw = function()
        UI.panel(40, 28, 320, 184)
        Gfx.text("Status", 52, 34)
        if n == 0 then
            Gfx.text("No companions yet.", 52, 60)
        end
        for i = 1, n do
            local m = party[i]
            local y = 34 + i * 34
            Gfx.text(names[i], 52, y)
            Gfx.text(lvs[i], 180, y)
            if m.hp and m.maxhp then
                UI.hpBar(240, y + 4, 100, m.hp, m.maxhp)
            end
        end
        Gfx.text("Gold:", 52, 188)
        Gfx.text(UI.goldStr(), 100, 188)
    end
    return Kit.push(st)
end

function UI.menu(cb)
    local rows = { "Items", "Status", "Save" }
    for i = 1, #UI.sections do
        rows[#rows + 1] = UI.sections[i].name
    end
    UI.menuActive = true
    Harness.count("menuOpens")
    local st = {
        ui = true, kind = "menu", translucent = true,
        sel = 1, n = #rows, rows = rows,
    }
    st.update = function(dt)
        listNav(st)
        if Input.a then
            local pick = rows[st.sel]
            if pick == "Items" then
                openItems()
            elseif pick == "Status" then
                openStatus()
            elseif pick == "Save" then
                State.save()
                Kit.toast("Saved.")
            else
                for i = 1, #UI.sections do
                    if UI.sections[i].name == pick then
                        UI.sections[i].run()
                    end
                end
            end
        elseif Input.b then
            Kit.pop()
            UI.menuActive = false
            if cb then cb() end
        end
    end
    st.draw = function()
        local h = 30 + st.n * LH + 22
        UI.panel(268, 8, 124, h)
        Gfx.text("Menu", 280, 14)
        for i = 1, st.n do
            local ry = 34 + (i - 1) * LH
            if i == st.sel then Gfx.text("*>*", 276, ry) end
            Gfx.text(rows[i], 292, ry)
        end
        Gfx.text(UI.goldStr(), 280, 8 + h - 22)
    end
    return Kit.push(st)
end

-- ---- shop flow ------------------------------------------------------------
-- stock = { {item=, price=}, ... }. Buy at price, sell at half (1 if
-- unpriced). cb fires on Leave.

function UI.shop(stock, cb)
    local price = {}
    for i = 1, #stock do price[stock[i].item] = stock[i].price end
    local root -- forward
    local function buyRows(rows)
        for i = 1, #stock do
            rows[i] = stock[i].item .. "  " .. stock[i].price .. "g"
        end
        return rows
    end
    local function openBuy()
        local rows = buyRows({})
        UI.list{
            title = "Buy", tag = "shopbuy", rows = rows,
            foot = UI.goldStr,
            onA = function(i, st)
                local it = stock[i]
                if State.takeGold(it.price) then
                    State.add(it.item, 1)
                    Kit.toast("Bought a " .. it.item .. ".")
                else
                    Kit.toast("Not enough gold.")
                end
            end,
            onB = function(st)
                Kit.pop()
                root()
            end,
        }
    end
    local function openSell()
        local ids = {}
        local function sellRows(rows)
            local n = 0
            for id in pairs(State.inv) do
                n = n + 1
                ids[n] = id
            end
            table.sort(ids, function(a, b) return a < b end)
            for i = #ids, n + 1, -1 do ids[i] = nil end
            for i = 1, n do
                local p = math.max(1,
                    math.floor((price[ids[i]] or 2) / 2))
                rows[i] = ids[i] .. " x" .. State.inv[ids[i]]
                    .. "  " .. p .. "g"
            end
            for i = #rows, n + 1, -1 do rows[i] = nil end
            return rows
        end
        local rows = sellRows({})
        UI.list{
            title = "Sell", tag = "shopsell", rows = rows,
            foot = UI.goldStr,
            onA = function(i, st)
                local id = ids[i]
                if id and State.take(id, 1) then
                    local p = math.max(1,
                        math.floor((price[id] or 2) / 2))
                    State.giveGold(p)
                    Kit.toast("Sold a " .. id .. ".")
                end
                st.rebuild(sellRows(rows))
            end,
            onB = function(st)
                Kit.pop()
                root()
            end,
        }
    end
    root = function()
        UI.choose("What'll it be?", { "Buy", "Sell", "Leave" },
            function(i)
                if i == 1 then
                    openBuy()
                elseif i == 2 then
                    openSell()
                else
                    if cb then cb() end
                end
            end)
    end
    root()
end

-- ---- inn flow -------------------------------------------------------------
-- Confirm -> pay -> fade out -> UI.innHeal (overridable) -> fade in.

UI.innHeal = function()
    Kit.toast("You feel rested.")
end

function UI.inn(price, cb)
    UI.choose("Rest for " .. price .. "g?", { "Yes", "No" },
        function(i)
            if i ~= 1 then
                if cb then cb() end
                return
            end
            if not State.takeGold(price) then
                Kit.toast("Not enough gold.")
                if cb then cb() end
                return
            end
            UI.fadeTo(1, function()
                UI.innHeal()
                UI.fadeTo(0, cb)
            end)
        end)
end

-- ---- HP bar ---------------------------------------------------------------

function UI.hpBar(x, y, w, cur, max)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(x, y, w, 8)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(x, y, w, 8)
    local fw = math.floor((w - 4) * Util.clamp(cur / max, 0, 1))
    if fw > 0 then gfx.fillRect(x + 2, y + 2, fw, 4) end
end

-- ---- damage popups (pooled, world space) ----------------------------------
-- UI.popup spawns; Kit.fxUpdate floats them; the game's Draw.frame
-- calls UI.drawPopups() inside the Cam.apply/done bracket.

local POPN = 8
local pops = {}
for i = 1, POPN do
    pops[i] = { t = 0, x = 0, y = 0, text = "" }
end

function UI.popup(wx, wy, text)
    local best = pops[1]
    for i = 1, POPN do
        if pops[i].t < best.t then best = pops[i] end
    end
    best.x, best.y, best.text, best.t = wx, wy, text, 0.9
end

function UI.drawPopups()
    for i = 1, POPN do
        local p = pops[i]
        if p.t > 0 then
            local x = math.floor(p.x + 0.5)
            local y = math.floor(p.y + 0.5)
            gfx.drawText(p.text, x + 1, y + 1) -- black shadow
            Gfx.text(p.text, x, y)
        end
    end
end

-- ---- full-screen fade (above the whole stack via Kit.fx hooks) ------------

local fadeTarget, fadeCb, fadeSpeed = 0, nil, 2.5

-- glide UI.fadeLevel toward t01 (0 clear .. 1 black); cb on arrival
function UI.fadeTo(t01, cb, speed)
    fadeTarget = Util.clamp(t01, 0, 1)
    fadeCb = cb
    fadeSpeed = speed or 2.5
end

Kit.fxUpdate = function(dt)
    for i = 1, POPN do
        local p = pops[i]
        if p.t > 0 then
            p.t = p.t - dt
            p.y = p.y - 24 * dt
        end
    end
    local d = fadeTarget - UI.fadeLevel
    if d ~= 0 then
        local step = fadeSpeed * dt
        if math.abs(d) <= step then
            UI.fadeLevel = fadeTarget
            local cb = fadeCb
            fadeCb = nil
            if cb then cb() end
        else
            UI.fadeLevel = UI.fadeLevel + (d > 0 and step or -step)
        end
    end
end

Kit.fxDraw = function()
    if UI.fadeLevel > 0.02 then
        Gfx.over(UI.fadeLevel * 7)
        gfx.fillRect(0, 0, 400, 240)
        gfx.setColor(gfx.kColorBlack)
    end
end

-- one transient status line (alias; fleet name)
UI.toastLine = Kit.toast

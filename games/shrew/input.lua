-- Shrew input: one path for thumbs AND the smoke autopilot.
-- Input.mx/my are held movement axes (grid steps); a/b/up/down are
-- EDGE-TRIGGERED one-poll flags (the lui contract). Smoke builds
-- synthesize them: a data-driven PLAN of quest steps (each = a done
-- predicate + per-map waypoint routes + an optional talk/menu goal)
-- steers the field, and uiDrive presses every window — title,
-- dialogs, shop, menu, and the lturn battle windows — through the
-- same st.kind/sel/rows surface. Battle grammar: Fight by default,
-- Mend under 45%, herbs as backup, Curl to open the Tyrant.
-- The plan self-heals: after a death reload it re-derives the first
-- unmet step and walks there from wherever Pip wakes.

Input = {
    mx = 0, my = 0,
    a = false, b = false, aHeld = false,
    up = false, down = false, left = false, right = false,
}

-- ---- real input -----------------------------------------------------------

local function realPoll()
    local pd = playdate
    Input.mx, Input.my = Util.dpad()
    Input.a = pd.buttonJustPressed(pd.kButtonA)
    Input.aHeld = pd.buttonIsPressed(pd.kButtonA)
    Input.b = pd.buttonJustPressed(pd.kButtonB)
    Input.up = pd.buttonJustPressed(pd.kButtonUp)
    Input.down = pd.buttonJustPressed(pd.kButtonDown)
    Input.left = pd.buttonJustPressed(pd.kButtonLeft)
    Input.right = pd.buttonJustPressed(pd.kButtonRight)
end

-- ---- grid steering --------------------------------------------------------

local lastCell, stuckT = -1, 0

-- push the axes one cell toward (tx, ty); true when standing there
local function steer(tx, ty)
    local p = G.player
    local dx, dy = tx - p.cellX, ty - p.cellY
    if dx == 0 and dy == 0 then return true end
    if dx ~= 0 and (math.abs(dx) >= math.abs(dy) or dy == 0) then
        Input.mx = Util.sign(dx)
    else
        Input.my = Util.sign(dy)
    end
    local ck = p.cellX * 512 + p.cellY
    if ck == lastCell then
        stuckT = stuckT + C.DT
    else
        stuckT = 0
    end
    lastCell = ck
    if stuckT > 2 then -- wedged on a tree: sidestep at random
        Input.mx = math.random(-1, 1)
        Input.my = Input.mx == 0 and (math.random(0, 1) * 2 - 1)
            or 0
        if stuckT > 3 then stuckT = 0 end
    end
    return false
end

-- ---- the quest plan -------------------------------------------------------

local TOWN_EXIT = { { 16, 20 }, { 16, 22 } }
local ROUTE_CAVE = {
    { 24, 42 }, { 24, 52 }, { 52, 52 }, { 83, 52 }, { 83, 41 },
    { 89, 40 }, { 98, 40 }, { 103, 40 }, { 104, 40 },
}
local B1_STAIRS_RT = { { 21, 12 }, { 25, 12 }, { 25, 13 } }

local function opened(map, cell)
    return State.opened(map, cell[1], cell[2])
end

local Plan = {
    { -- buy the Thorn Pin (and herbs; uiDrive shops the list)
        done = function() return State.count("thorn_pin") > 0 end,
        wps = { town = { { 14, 6 } } }, talk = true,
    },
    { -- don the pin from the Items menu
        done = function()
            return Party.member(1).equip.weapon == "thorn_pin"
        end,
        goal = "thorn_pin", wps = {},
    },
    { -- the ferrier's oar, lost in the western ferns
        done = function()
            return State.count("oar") > 0 or State.has("boat")
        end,
        wps = { town = TOWN_EXIT,
            world = { { 24, 42 }, { 24, 52 }, { 15, 52 } } },
        talk = true,
    },
    { -- trade it for the skiff
        done = function() return State.has("boat") end,
        wps = { town = { { 16, 17 }, { 25, 17 } },
            world = { { 24, 42 }, { 24, 31 }, { 24, 30 } } },
        talk = true,
    },
    { -- grind the marsh to LV4 (encounters interrupt the pacing)
        done = function() return Party.member(1).lvl >= 4 end,
        wps = { town = TOWN_EXIT,
            world = { { 24, 42 }, { 24, 52 }, { 40, 52 },
                { 46, 57 }, { 52, 60 } } },
        pace = true,
    },
    { -- boat east, thread the pass, enter the Burrow
        done = function()
            return G.mapName == "burrow1" or G.mapName == "burrow2"
                or State.has("boss_down")
        end,
        wps = { town = TOWN_EXIT, world = ROUTE_CAVE },
    },
    { -- floor 1: the Brass Key chest
        done = function()
            return State.count("brass_key") > 0
                or State.has("burrow_door")
        end,
        wps = { town = TOWN_EXIT, world = ROUTE_CAVE,
            burrow1 = { { 3, 2 }, { 3, 12 }, { 6, 12 } } },
        talk = true,
    },
    { -- floor 1: the Seed Cake chest
        done = function() return opened("burrow1", C.B1_CAKECH) end,
        wps = { town = TOWN_EXIT, world = ROUTE_CAVE,
            burrow1 = { { 21, 12 }, { 21, 6 } } },
        talk = true,
    },
    { -- down the stairs
        done = function()
            return G.mapName == "burrow2" or State.has("boss_down")
        end,
        wps = { town = TOWN_EXIT, world = ROUTE_CAVE,
            burrow1 = B1_STAIRS_RT },
    },
    { -- the Brass Key turns
        done = function() return State.has("burrow_door") end,
        wps = { town = TOWN_EXIT, world = ROUTE_CAVE,
            burrow1 = B1_STAIRS_RT,
            burrow2 = { { 4, 8 }, { 10, 8 }, { 11, 8 } } },
    },
    { -- floor 2: the Moss Cloak chest
        done = function() return opened("burrow2", C.B2_CLOAKCH) end,
        wps = { town = TOWN_EXIT, world = ROUTE_CAVE,
            burrow1 = B1_STAIRS_RT,
            burrow2 = { { 13, 8 }, { 16, 8 }, { 16, 5 } } },
        talk = true,
    },
    { -- floor 2: the Seed Cake chest
        done = function() return opened("burrow2", C.B2_CAKECH) end,
        wps = { town = TOWN_EXIT, world = ROUTE_CAVE,
            burrow1 = B1_STAIRS_RT,
            burrow2 = { { 16, 9 }, { 16, 11 } } },
        talk = true,
    },
    { -- the Mole Tyrant (Curl, then Fight; Mend under 45%)
        done = function() return State.has("boss_down") end,
        wps = { town = TOWN_EXIT, world = ROUTE_CAVE,
            burrow1 = B1_STAIRS_RT,
            burrow2 = { { 16, 8 }, { 19, 8 }, { 20, 8 } } },
    },
}

-- ---- the window driver ----------------------------------------------------

local pressGap = 0
local menuGoal = nil     -- item id to Use from the pause menu
local goalSkill = nil    -- battle skill row to pick next
local roundN = 0         -- bcmd windows seen this battle

local function press(name)
    Input[name] = true
end

local function rowFind(rows, pat)
    for i = 1, #rows do
        if rows[i]:find(pat, 1, true) == 1 then return i end
    end
    return nil
end

local function seek(st, want)
    if st.sel < want then
        press("down")
    elseif st.sel > want then
        press("up")
    else
        press("a")
        return true
    end
    return false
end

local function decideChoose(st)
    local rows = st.rows
    if rowFind(rows, "Buy") then -- shop root
        if State.count("thorn_pin") == 0
            or State.count("herb") < 2 then
            return rowFind(rows, "Buy")
        end
        return rowFind(rows, "Leave") or #rows
    end
    if menuGoal and rowFind(rows, "Use") then
        return rowFind(rows, "Use")
    end
    if rows[1] == "Yes" then -- the inn: not tonight
        return rowFind(rows, "No") or 1
    end
    return 1
end

local function driveBattle(st)
    if st.kind == "bcmd" then
        local m = Party.member(1)
        local hurt = m.hp < m.maxhp * 0.45
        local canMend = m.mp >= 3
            and rowFind(m.skills, "mend") ~= nil
        if G.bossFight and roundN == 0 and m.mp >= 2
            and rowFind(m.skills, "curl") then
            goalSkill = "Curl"
            if seek(st, 2) then roundN = roundN + 1 end
        elseif hurt and canMend then
            goalSkill = "Mend"
            if seek(st, 2) then roundN = roundN + 1 end
        elseif hurt and (State.count("herb") > 0
            or State.count("seed_cake") > 0) then
            if seek(st, 3) then roundN = roundN + 1 end
        else
            if seek(st, 1) then roundN = roundN + 1 end
        end
    elseif st.kind == "bskill" then
        local i = goalSkill and rowFind(st.rows, goalSkill)
        if i then
            if seek(st, i) then goalSkill = nil end
        else
            press("b")
            goalSkill = nil
        end
    elseif st.kind == "bitem" then
        local i = rowFind(st.rows, "herb")
            or rowFind(st.rows, "seed_cake")
        if i then seek(st, i) else press("b") end
    else -- btarget: first living foe
        press("a")
    end
end

local function uiDrive(top)
    pressGap = pressGap + 1
    if pressGap < 4 then return end
    pressGap = 0
    local k = top.kind
    if k == "title" or k == "dialog" then
        press("a")
    elseif k == "choose" then
        local want = decideChoose(top)
        if seek(top, want) and menuGoal
            and top.rows[want] == "Use" then
            menuGoal = nil
        end
    elseif k == "menu" then
        if menuGoal then
            seek(top, rowFind(top.rows, "Items") or 1)
        else
            press("b")
        end
    elseif k == "list" then
        if top.tag == "shopbuy" then
            if State.count("thorn_pin") == 0 then
                seek(top, rowFind(top.rows, "thorn_pin") or 1)
            elseif State.count("herb") < 2 then
                seek(top, rowFind(top.rows, "herb") or 1)
            else
                press("b")
            end
        elseif top.tag == "items" and menuGoal then
            local i = rowFind(top.rows, menuGoal)
            if i then
                seek(top, i)
            else
                menuGoal = nil -- gone; never loop the menu
                press("b")
            end
        else
            press("b")
        end
    elseif k == "bcmd" or k == "bskill" or k == "bitem"
        or k == "btarget" then
        driveBattle(top)
    else -- status page or unknown: back out
        press("b")
    end
end

-- ---- the field driver -----------------------------------------------------

local curI, wpI, lastMap = -1, 1, nil
local talkGap = 0

local function nearestWp(list)
    local p, best, bd = G.player, 1, nil
    for i = 1, #list do
        local d = math.abs(list[i][1] - p.cellX)
            + math.abs(list[i][2] - p.cellY)
        if not bd or d < bd then best, bd = i, d end
    end
    return best
end

local function driveField()
    local step, si = nil, nil
    for i = 1, #Plan do
        if not Plan[i].done() then
            step, si = Plan[i], i
            break
        end
    end
    Harness.set("phase", si or 0)
    if not step then return end -- quest complete: rest, knight
    local m = Party.member(1)
    if not menuGoal and m.hp < m.maxhp * 0.4
        and State.count("herb") > 0 then
        menuGoal = "herb" -- field heal via the pause menu
    end
    if step.goal and not menuGoal then menuGoal = step.goal end
    if menuGoal then
        press("b") -- open the pause menu; uiDrive does the rest
        return
    end
    local list = step.wps[G.mapName]
    if not list or #list == 0 then return end -- warp under way
    if si ~= curI or G.mapName ~= lastMap then
        curI, lastMap = si, G.mapName
        wpI = nearestWp(list)
    end
    local w = list[math.min(wpI, #list)]
    if steer(w[1], w[2]) then
        if wpI < #list then
            wpI = wpI + 1
        elseif step.pace then
            wpI = #list - 1 -- bounce between the last two
        elseif step.talk then
            talkGap = talkGap + 1
            if talkGap > 8 then
                talkGap = 0
                press("a")
            end
        end
    end
end

-- ---- the poll -------------------------------------------------------------

local function clearEdges()
    Input.a, Input.b, Input.aHeld = false, false, false
    Input.up, Input.down = false, false
    Input.left, Input.right = false, false
end

function Input.poll()
    if not Harness.enabled then
        realPoll()
        return
    end
    clearEdges()
    Input.mx, Input.my = 0, 0
    if not Turn.active then roundN = 0 end
    local top = Kit.top()
    if top and top.ui then
        uiDrive(top)
    elseif Turn.active or Script.active then
        -- scene timers / scripted beats own the frame
    elseif G.player then
        driveField()
    end
end

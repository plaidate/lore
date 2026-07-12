-- Slice input: the one input path for humans AND the smoke autopilot.
-- Input.mx/my are the held movement axes; Input.a/b/up/down/left/right
-- are EDGE-TRIGGERED one-poll flags (the lui contract); Input.aHeld is
-- the HELD A button laction charges on. Real play maps them from the
-- d-pad/buttons; smoke builds synthesize them instead:
--
--   * a PLAYTHROUGH script (Script.run) walks the story end to end —
--     talk to the guard, shrine scene, buy a torch, open the chest,
--     save from the pause menu, verify the load round-trip — then
--     paces the meadow patch until a random encounter fires (the
--     battle interrupts the scripted walk, resolves, and the walk
--     resumes: the state stack at work);
--   * whenever a UI window is on top — dialogs, menus, AND the lturn
--     battle windows (bcmd/btarget) — the autopilot steers it through
--     the same edge flags, reading st.kind/sel/rows;
--   * after the script hands off, a field phase machine arms the
--     stick, hunts the forest roamer (hold-to-charge swings via
--     Input.aHeld), then runs a finisher script (warp home +
--     autosave) and laps the ring road forever.

Input = {
    mx = 0, my = 0, wp = 1,
    a = false, b = false, aHeld = false,
    up = false, down = false, left = false, right = false,
}

-- ---- real input --------------------------------------------------------

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

-- ---- shared waypoint steering -------------------------------------------

local lastCell, stuckT = -1, 0

-- push the axes toward tile waypoint w = {tx, ty}; true when there
local function steer(w)
    local p = G.player
    local dx = Map.cx(w[1]) - p.x
    local dy = Map.cy(w[2]) - p.y
    if math.abs(dx) < 3 and math.abs(dy) < 3 then return true end
    if math.abs(dx) >= 3 then
        Input.mx = Util.sign(dx)
    elseif math.abs(dy) >= 3 then
        Input.my = Util.sign(dy)
    end
    -- stuck = no cell progress while pushing; burst randomly
    local ck = p.cellX * 512 + p.cellY
    if ck == lastCell then
        stuckT = stuckT + C.DT
    else
        stuckT = 0
    end
    lastCell = ck
    if stuckT > 3 then
        Input.mx = math.random(-1, 1)
        Input.my = math.random(-1, 1)
        if stuckT > 4 then stuckT = 0 end
    end
    return false
end

-- ---- wave-1 ring-road waypoint walker ---------------------------------

local WPS = { { 9, 9 }, { 112, 9 }, { 112, 82 }, { 9, 82 } }

local function ringAuto()
    if steer(WPS[Input.wp]) then
        Input.wp = Input.wp % #WPS + 1
        if Input.wp == 1 then Harness.count("laps") end
    end
end

-- ---- UI window driver ---------------------------------------------------
-- Reads the lui/lturn introspection surface (st.kind/sel/rows) and
-- presses the same edge flags a thumb would, one press every few
-- polls.

local Auto = { didSave = false, done = false, phase = "story" }

local pressGap = 0

local function press(name)
    Input[name] = true
end

local function rowNamed(rows, want)
    for i = 1, #rows do
        if rows[i] == want then return i end
    end
    return 1
end

-- pick an option index from a choice window's labels
local function decide(rows)
    for i = 1, #rows do
        local r = rows[i]
        if r:find("Follow") then return i end
        if r == "No" then return i end
        if r == "Buy" then
            if State.count("torch") > 0 then
                return rowNamed(rows, "Leave")
            end
            return i
        end
    end
    return 1
end

local function seek(st, want)
    if st.sel < want then
        press("down")
    elseif st.sel > want then
        press("up")
    else
        press("a")
    end
end

local function uiDrive(top)
    pressGap = pressGap + 1
    if pressGap < 5 then return end
    pressGap = 0
    if top.kind == "dialog" then
        press("a")
    elseif top.kind == "choose" then
        seek(top, decide(top.rows))
    elseif top.kind == "menu" then
        if Auto.didSave then
            press("b")
        else
            local want = rowNamed(top.rows, "Save")
            if top.sel == want then Auto.didSave = true end
            seek(top, want)
        end
    elseif top.kind == "list" then
        if top.tag == "shopbuy" and State.count("torch") == 0 then
            seek(top, 1) -- the torch leads the stock
        else
            press("b")
        end
    elseif top.kind == "bcmd" then
        seek(top, 1) -- Fight
    elseif top.kind == "btarget" then
        press("a")   -- first living foe
    else -- status page or unknown: back out
        press("b")
    end
end

-- ---- the playthrough (run once by main.lua) -----------------------------

function Game.playthrough()
    Script.run(function()
        local p = G.player
        -- leg 1: east along the top road, then south to the guard
        walk(p, { tx = 112, ty = 9 })
        walk(p, { tx = 112, ty = C.GUARD_Y0 - 2 })
        -- the guard patrols; chase his cell until the talk lands
        for _ = 1, 8 do
            local g = G.guard
            walk(p, { tx = g.cellX, ty = g.cellY - 1 })
            if Script.interact(p) then break end
            wait(0.3)
        end
        -- leg 2: up to the shrine; the scene runs inline (engine-side
        -- step triggers stay suppressed while a script is active)
        walk(p, { tx = C.TRIG_X, ty = C.TRIG_Y + 1 })
        Script.trigger("shrine", C.TRIG_X, C.TRIG_Y)
        -- leg 3: shop with the merchant (autopilot buys the torch)
        walk(p, { tx = C.MERCH_X + 1, ty = C.MERCH_Y })
        Script.interact(p)
        -- leg 4: the chest
        walk(p, { tx = C.CHEST_X + 1, ty = C.CHEST_Y })
        Script.interact(p)
        -- leg 5: pause menu; the autopilot walks it to Save
        UI.menu()
        waituntil(function() return not UI.menuActive end)
        -- prove the save/load round trip against the live ledger
        if State.load() and hasflag("shrine_lit")
            and State.count("torch") > 0
            and State.opened("world", C.CHEST_X, C.CHEST_Y) then
            Harness.set("loadOk", 1)
        end
        -- leg 6 (wave 3): pace the meadow patch until a random
        -- encounter fires — the battle interrupts the scripted
        -- walk, the uiDrive fights it, the walk resumes
        walk(p, { tx = 111, ty = C.MEADOW_Y0 + 1 })
        for _ = 1, 40 do
            walk(p, { tx = C.MEADOW_X0 + 1, ty = C.MEADOW_Y0 + 1 })
            if (Harness.counters.battlesWon or 0) > 0 then break end
            walk(p, { tx = C.MEADOW_X1 - 1, ty = C.MEADOW_Y1 - 1 })
            if (Harness.counters.battlesWon or 0) > 0 then break end
        end
        -- hand combat to the field phase machine (arm -> hunt)
        Auto.phase = "arm"
    end)
end

-- ---- field phases: arm the stick, hunt the roamer, finish ---------------

local HUNT = nil -- south along the east road, west, into the ferns
local hwp = 1
local fightN = 0

-- close in and run charge-and-release swing cycles (16 polls held
-- covers the 0.5 s full charge at 30fps, then 4 polls released)
local function fightAuto(r)
    local p = G.player
    local dx, dy = r.x - p.x, r.y - p.y
    if dx * dx + dy * dy > 22 * 22 then
        if math.abs(dx) >= math.abs(dy) then
            Input.mx = Util.sign(dx)
        else
            Input.my = Util.sign(dy)
        end
    end
    fightN = fightN + 1
    if fightN % 20 < 16 then Input.aHeld = true end
end

local function huntAuto()
    if State.get("roamer_dead") then
        Auto.phase = "finish"
        return
    end
    HUNT = HUNT or {
        { 111, C.RING_Y1 }, { C.FOREST_X1, C.RING_Y1 },
        { C.ROAMER_X, C.ROAMER_Y },
    }
    local r = G.roamer
    if r and r.fd and r.fd.hp > 0
        and Util.dist2(r.x, r.y, G.player.x, G.player.y)
        < 70 * 70 then
        fightAuto(r)
        return
    end
    if hwp <= #HUNT then
        if steer(HUNT[hwp]) then hwp = hwp + 1 end
    elseif r then
        steer{ r.cellX, r.cellY } -- it drifted; go to it
    end
end

local function finishAuto()
    Auto.phase = "lapping"
    Script.run(function()
        -- warp home (loader hook + autosave fire), wrap up
        warp("world", 9, 9)
        toast("The road loops on.")
        Harness.set("playDone", 1)
        Auto.done = true
        Input.wp = 1
    end)
end

-- ---- the poll ------------------------------------------------------------

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
    local top = Kit.top()
    if top and top.ui then
        uiDrive(top)
    elseif Turn.active then
        -- battle scene between windows: the timers run it
    elseif Script.active then
        -- the script is walking someone; hands off
    elseif not G.player then
        -- booting
    elseif Auto.phase == "arm" then
        State.add("stick")
        Action.arm(G.player, "stick")
        Auto.phase = "hunt"
    elseif Auto.phase == "hunt" then
        huntAuto()
    elseif Auto.phase == "finish" then
        finishAuto()
    elseif Auto.done then
        ringAuto()
    end
end

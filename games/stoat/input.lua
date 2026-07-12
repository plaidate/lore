-- Stoat input: one path for thumbs AND the smoke autopilot.
--
-- THE MAPPING (the clean SoM read of the engine's input contract):
--   d-pad   move (free Act.walk)
--   A tap   interact/confirm when someone is in reach (the den's
--           elder and moss-bed; every window), otherwise a quick
--           swing of the armed weapon
--   A hold  charge (ring HUD; the crank winds it up faster);
--           release to unleash
--   B tap   POUNCE — the 3-tile dash-lunge, on a cooldown
--   B hold  pause menu after MENU_HOLD s (Items/Status/Save/
--           Skills/Equip); inside windows B is cancel (lui rule)
-- Windows read Input.a/b/up/down as edge flags per the lui
-- contract; Input.pounce/Input.menu are the field's semantic B
-- edges, only synthesized while the field state is on top.
--
-- The autopilot is slice's hunt grammar scaled to a campaign:
-- title -> intro (uiDrive answers the elder) -> per zone: hunt the
-- nearest rat (charge-swing cycles, kite telegraphs, pounce at mid
-- range, grab drops, Groom via the pause menu under 40%) -> quota
-- spawns the captain -> captain -> gate opens -> next zone; equips
-- Tailwhip + the Bramble Coat after the twins; drives the king's
-- mid-fight parley like any other window; ends on the thaw script.

Input = {
    mx = 0, my = 0,
    a = false, b = false, aHeld = false,
    up = false, down = false, left = false, right = false,
    pounce = false, menu = false,
    phase = "title",
}

-- ---- real input ----------------------------------------------------------

local bT = 0

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
    Input.pounce, Input.menu = false, false
    if Kit.top() ~= G.field then -- B belongs to the window
        bT = 0
        return
    end
    if pd.buttonIsPressed(pd.kButtonB) then
        bT = bT + C.DT
        if bT >= C.MENU_HOLD then
            Input.menu = true
            bT = -99 -- fire once per hold
        end
    else
        if bT > 0 then Input.pounce = true end
        bT = 0
    end
end

-- ---- autopilot: steering 

local Auto = { want = nil, fightN = 0, gap = 0, pw = 1 }
local lastCell, stuckT = -1, 0

local function press(name)
    Input[name] = true
end

local function steerPx(wx, wy)
    local p = G.player
    local dx, dy = wx - p.x, wy - p.y
    if math.abs(dx) < 3 and math.abs(dy) < 3 then return true end
    if math.abs(dx) >= 3 then
        Input.mx = Util.sign(dx)
    elseif math.abs(dy) >= 3 then
        Input.my = Util.sign(dy)
    end
    local ck = p.cellX * 512 + p.cellY
    if ck == lastCell then
        stuckT = stuckT + C.DT
    else
        stuckT = 0
    end
    lastCell = ck
    if stuckT > 2.5 then -- jiggle out of a corner
        Input.mx = math.random(-1, 1)
        Input.my = math.random(-1, 1)
        if stuckT > 3.5 then stuckT = 0 end
    end
    return false
end

local function steer(tx, ty)
    return steerPx(Map.cx(tx), Map.cy(ty))
end

-- ---- autopilot: the window driver 

local function rowLike(rows, pat)
    for i = 1, #rows do
        if rows[i]:find(pat) then return i end
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
    end
end

local function uiDrive(top)
    Auto.gap = Auto.gap + 1
    if Auto.gap < 5 then return end
    Auto.gap = 0
    local m = Party.member(1)
    if top.kind == "dialog" then
        press("a")
    elseif top.kind == "choose" then
        seek(top, 1) -- option 1 answers every stoat ask
    elseif top.kind == "menu" then
        local want
        if Auto.want == "groom" then
            want = rowLike(top.rows, "Skills")
        elseif Auto.want == "equip" then
            want = rowLike(top.rows, "Equip")
        end
        if want then seek(top, want) else press("b") end
    elseif top.kind == "list" and top.tag == "skills" then
        if Auto.want == "groom" and m.hp < m.maxhp * 0.6
            and m.mp >= C.GROOM_MP then
            seek(top, rowLike(top.rows, "Groom") or 1)
        else
            Auto.want = nil
            press("b")
        end
    elseif top.kind == "list" and top.tag == "equip" then
        local r
        if State.has("tailwhip") and Action.weapon ~= "tailwhip" then
            r = rowLike(top.rows, "Tailwhip")
        elseif State.count("bramble_coat") > 0
            and m.equip.armor ~= "bramble_coat" then
            r = rowLike(top.rows, "Bramble")
        end
        if r then
            seek(top, r)
        else
            Auto.want = nil
            press("b")
        end
    else -- items/status/unknown: back out
        press("b")
    end
end

-- ---- autopilot: the field 

-- Captains outrank their adds -- but only at range. The king summons
-- pups forever, so a plain nearest-foe pick grinds spawns and never
-- closes on him; beelining past the swarm gets you chewed. Rule:
-- clear an add that is already in your face, otherwise go for the boss.
local SWARM2 <const> = 40 * 40

local function nearestFoe(x0, x1)
    local p = G.player
    local boss = G.king or G.boss
    if boss and boss.fd and boss.fd.hp > 0 then
        local bx = Util.dist2(boss.x, boss.y, p.x, p.y)
        local near, nd
        for i = 1, #Act.list do
            local a = Act.list[i]
            if a ~= boss and a.fd and a.fd.hp > 0 then
                local d = Util.dist2(a.x, a.y, p.x, p.y)
                if d < SWARM2 and (not nd or d < nd) then
                    near, nd = a, d
                end
            end
        end
        if near then return near, nd end
        return boss, bx
    end
    local best, bd
    for i = 1, #Act.list do
        local a = Act.list[i]
        local f = a.fd
        if f and f.hp > 0 and a.cellX >= x0 and a.cellX <= x1 then
            local d = Util.dist2(a.x, a.y, p.x, p.y)
            if not bd or d < bd then best, bd = a, d end
        end
    end
    return best, bd
end

local function nearestDrop()
    local p = G.player
    for i = 1, #Act.list do
        local a = Act.list[i]
        if a.kind == "drop"
            and Util.dist2(a.x, a.y, p.x, p.y) < 90 * 90 then
            return a
        end
    end
    return nil
end

-- close in, kite the telegraph, run charge-swing cycles, pounce at
-- mid range
local function fightAuto(e)
    local p = G.player
    local f = e.fd
    local dx, dy = e.x - p.x, e.y - p.y
    local d2 = dx * dx + dy * dy
    Auto.fightN = Auto.fightN + 1
    if f.st == "tel" or f.st == "lunge" then -- back off the flash
        Input.mx = -Util.sign(dx)
        Input.my = -Util.sign(dy)
    else
        if d2 > 18 * 18 then
            if math.abs(dx) >= math.abs(dy) then
                Input.mx = Util.sign(dx)
            else
                Input.my = Util.sign(dy)
            end
        end
        if Auto.fightN % 70 == 0 and d2 > 26 * 26 and d2 < 64 * 64
            and G.pounceCool <= 0 and G.dashT <= 0 then
            press("pounce")
            return
        end
    end
    local wd = Action.weapons[Action.weapon]
    local hold = math.ceil(((wd.charge and wd.charge.time) or 0.5)
        * 30) + 4
    if Auto.fightN % (hold + 5) < hold then Input.aHeld = true end
end

local function zoneAuto()
    local p = G.player
    local m = Party.member(1)
    if not Auto.want and m.hp < m.maxhp * 0.4
        and m.mp >= C.GROOM_MP then
        Auto.want = "groom" -- heal through the pause menu
    end
    if not Auto.want and State.has("twins_dead")
        and (Action.weapon ~= "tailwhip"
            or m.equip.armor ~= "bramble_coat") then
        Auto.want = "equip" -- new toys after the twins
    end
    if Auto.want then
        press("menu")
        return
    end
    local zi = 1
    if State.has("fat_dead") then zi = 2 end
    if State.has("twins_dead") then zi = 3 end
    local z = G.ZONES[zi]
    Input.phase = z.name
    if p.cellX < z.x0 + 1 then -- walk the road through the gate
        steer(z.x0 + 3, C.ROAD_Y)
        return
    end
    local dp = nearestDrop()
    if dp then
        steerPx(dp.x, dp.y)
        return
    end
    local e, d2 = nearestFoe(z.x0, z.x1 + 2)
    if e and d2 < 160 * 160 then
        fightAuto(e)
    elseif e then
        steer(e.cellX, e.cellY)
    else -- patrol the spawn beds until the respawns land
        local beds = Content.SPAWNS[z.name]
        local b = beds[(Auto.pw - 1) % #beds + 1]
        if steer(b[2], b[3]) then Auto.pw = Auto.pw + 1 end
    end
end

local function fieldAuto()
    if State.has("done") then
        Input.phase = "done"
        return
    end
    if G.mapName == "den" then
        Input.phase = "den"
        steer(C.DEN_EXIT_X, C.DEN_EXIT_Y)
        return
    end
    zoneAuto()
end

-- ---- the poll 

local function clearEdges()
    Input.a, Input.b, Input.aHeld = false, false, false
    Input.up, Input.down = false, false
    Input.left, Input.right = false, false
    Input.pounce, Input.menu = false, false
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
        return
    end
    if Script.active then
        Input.phase = "script"
        return
    end
    if not G.begun then
        Input.phase = "title"
        Auto.gap = Auto.gap + 1
        if Auto.gap >= 5 then
            Auto.gap = 0
            press("a")
        end
        return
    end
    if not G.player then return end
    fieldAuto()
end

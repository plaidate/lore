-- Lore core: encounters. Two front doors, ONE battle seam: DQ-style
-- step-counted random encounters and CT-style visible roamers both
-- fire Script.battleHook (lturn wires it to Turn.start), so scripts,
-- zones and roamers all land in the same scene.
--
-- ZONES: Enc.zones(map, tbl) registers per-map encounter tables:
--   tbl = { zone -> { rate = per-step chance at the ramp start,
--                     groups = { {beast ids...}, ... },
--                     weights = { n... } } }   -- default weight 1
-- Enc.onStep(actor) is the movement hook — wire the player's
-- a.onStep to it (it also ticks Party.stepTick for field poison).
-- THE CURVE: no encounter for the first 8 steps after a reset (map
-- entry or battle end); from step 8 on, standing in a registered
-- zone, chance = rate * (steps - 7) * Enc.rateMul — a linear DQ
-- ramp, so rate is the chance on step 8 and grows every step.
--
-- MODIFIERS: Enc.repel(steps) suppresses random encounters for that
-- many steps (repel charm); Enc.rateMul is the boat/terrain seam
-- (games set it: 0 while docked at an inn, 0.5 on the boat...).
--
-- ROAMERS: Enc.roamer{ id=, x=, y=, group=, aggro=px, speed=,
-- img=/sprite= } spawns a visible enemy actor that wanders, chases
-- the player inside the aggro radius (grid steps, CT feel), and
-- triggers the same battleHook on contact; "win" removes it, any
-- other outcome backs it off for a grace beat. Enc.update(dt,
-- player) drives them from the game's field update.
--
-- Enc.enter(map) resets steps + forgets roamers at map load (the
-- game respawns them). Counter: encounters.

Enc = {
    steps = 0,
    rateMul = 1,
    active = false, -- a battle is up; suppress triggers
}

local zones = {}   -- map name -> zone table
local mapName = nil
local repelSteps = 0
local roamers = {}

function Enc.zones(map, tbl)
    zones[map] = tbl
end

-- call at map load (after Act.reset): fresh curve, no roamers
function Enc.enter(map)
    mapName = map
    Enc.steps = 0
    roamers = {}
end

function Enc.reset()
    Enc.steps = 0
end

function Enc.repel(steps)
    repelSteps = steps
end

local function pickGroup(z)
    local ws = z.weights
    local total = 0
    for i = 1, #z.groups do
        total = total + ((ws and ws[i]) or 1)
    end
    local r = math.random() * total
    for i = 1, #z.groups do
        r = r - ((ws and ws[i]) or 1)
        if r <= 0 then return z.groups[i] end
    end
    return z.groups[#z.groups]
end

-- fire a battle for a group of bestiary ids (shared by the step
-- curve and roamer contact); after(outcome) is optional
function Enc.trigger(group, after)
    if Enc.active then return false end
    Enc.active = true
    Harness.count("encounters")
    Script.battleHook(group, function(outcome)
        Enc.active = false
        Enc.steps = 0
        if after then after(outcome) end
    end)
    return true
end

-- the player's per-step hook (wire a.onStep here)
function Enc.onStep(a)
    Party.stepTick()
    if repelSteps > 0 then repelSteps = repelSteps - 1 end
    Enc.steps = Enc.steps + 1
    if Enc.active or Enc.steps <= 8 then return end
    if repelSteps > 0 or Enc.rateMul <= 0 then return end
    local ztbl = zones[mapName]
    if not ztbl then return end
    local zn = Map.zone(a.cellX, a.cellY)
    local z = zn and ztbl[zn]
    if not z then return end
    local chance = z.rate * (Enc.steps - 7) * Enc.rateMul
    if math.random() < chance then
        Enc.trigger(pickGroup(z))
    end
end

-- ---- roamers --------------------------------------------------------------

function Enc.roamer(o)
    local d = Party.bestiary[o.id]
    local r = Act.new{
        kind = "roamer", x = o.x, y = o.y, hw = 6, hh = 6,
        speed = o.speed or (d and d.fspeed) or 35,
        img = o.img, sprite = o.sprite,
        behavior = { kind = "wander", radius = o.radius or 3 },
    }
    r.roam = {
        id = o.id, group = o.group or { o.id },
        aggro = o.aggro or 72, cool = 0, chasing = false,
    }
    roamers[#roamers + 1] = r
    return r
end

function Enc.update(dt, player)
    if Enc.active then return end
    for i = #roamers, 1, -1 do
        local r = roamers[i]
        local rm = r.roam
        if rm.cool > 0 then rm.cool = rm.cool - dt end
        local d2 = Util.dist2(r.x, r.y, player.x, player.y)
        local a2 = rm.aggro * rm.aggro
        if not rm.chasing and d2 < a2 then
            rm.chasing = true
            r.behavior = { kind = "follow", target = player,
                gap = 0 }
        elseif rm.chasing and d2 > a2 * 4 then
            rm.chasing = false
            r.behavior = { kind = "wander", radius = 3 }
        end
        local touch = math.abs(r.x - player.x) < r.hw + player.hw
            and math.abs(r.y - player.y) < r.hh + player.hh
        if touch and rm.cool <= 0 then
            Enc.trigger(rm.group, function(outcome)
                if outcome == "win" then
                    Act.remove(r)
                    for j = #roamers, 1, -1 do
                        if roamers[j] == r then
                            table.remove(roamers, j)
                        end
                    end
                else
                    rm.cool = 2 -- grace beat after a flee/loss
                end
            end)
        end
    end
end

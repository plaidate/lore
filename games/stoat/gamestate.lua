-- Stoat game state: the G blackboard every module shares — pooled
-- spits (so draw can render them without touching logic), pounce/
-- charm/king timers, the pending-beat flags (death, ending) the
-- update loop resolves outside engine callbacks — plus the zone
-- table and the boss bitmask mirror.

G = {
    t = 0,
    frames = 0,
    begun = false,
    mapName = nil,
    player = nil,
    held = false,       -- last frame's aHeld (full-charge counter)
    dashT = 0,          -- pounce dash remaining, s
    dashX = 0, dashY = 0,
    pounceCool = 0,
    hurtIT = 0,         -- game-layer iframes (spit hits), s
    charmT = 0,         -- whisker-charm calm remaining, s
    pendDeath = false,  -- party wipe waiting for the blackout script
    pendEnding = false, -- king down, ending script queued
    king = nil,         -- live king entity (stage 1 or 2)
    kingAdds = 0,       -- summoned pups alive
    kingT = 0,          -- summon timer
    kingT2 = 0,         -- forced-lunge timer
    kingMusic = false,
    curZone = nil,      -- music zone last applied
    boss = nil,         -- live zone captain (fat rat)
}

-- pooled slinger spits (fixed six; t <= 0 means free)
G.spits = {}
for i = 1, 6 do
    G.spits[i] = { t = 0, x = 0, y = 0, vx = 0, vy = 0 }
end

-- zone of a world tile column (gates count with their west zone)
function G.zoneAt(tx)
    if tx <= C.GATE1_X + 1 then return "meadow" end
    if tx <= C.GATE2_X + 1 then return "thicket" end
    return "warren"
end

-- ordered zone specs the game and the autopilot share
G.ZONES = {
    { name = "meadow", x0 = 2, x1 = C.MEADOW_X1,
        lx = C.FAT_X, ly = C.FAT_Y, flag = "fat_dead" },
    { name = "thicket", x0 = C.THICKET_X0, x1 = C.THICKET_X1,
        lx = C.TWIN_X, ly = C.TWIN_Y, flag = "twins_dead" },
    { name = "warren", x0 = C.WARREN_X0, x1 = C.WORLD_W - 1,
        lx = C.KING_X, ly = C.KING_Y, flag = "king_dead" },
}

-- mirror the boss bitmask (fat=1, twins=2, king=4) into the heartbeat
function G.bossBits()
    local b = 0
    if State.has("fat_dead") then b = b + 1 end
    if State.has("twins_dead") then b = b + 2 end
    if State.has("king_dead") then b = b + 4 end
    Harness.set("bossDown", b)
    return b
end

-- Stoat maps: ONE side-flowing 140x60 world (meadow -> thicket ->
-- warren), chunk-cached by the engine, plus the tiny HOME den.
-- Terrain is hash-noise wilderness EXCEPT rows BAND_Y0..BAND_Y1: a
-- guaranteed-open valley holding the road, every spawn bed and every
-- lair — the player's (and the autopilot's) safe corridor. Canopy
-- cells over the thicket road are the walk-behind showcase. The two
-- gates are solid columns; Maps.openGate clears a road-wide gap with
-- Map.set when a captain falls (and is re-applied on load from
-- flags, since the cached row strings never mutate).

local gfx = playdate.graphics

Maps = {}

-- deterministic hash noise (map gen must not use math.random)
local function hash(x, y)
    local n = (x * 73856093 + y * 19349663 + 4271) % 2147483647
    n = (n * 48271) % 2147483647
    return n / 2147483647
end

local function noise(tx, ty)
    local a = hash(tx // 8, ty // 8)
    local b = hash(tx // 3 + 57, ty // 3 + 91)
    return a * 0.7 + b * 0.3
end

-- ---- tile art (16px; tx,ty = world tile for variation) ----------------

local function snowArt(x, y, tx, ty)
    Gfx.fill(x, y, 16, 16, 1)
    if hash(tx, ty + 77) < 0.3 then
        gfx.setColor(gfx.kColorBlack)
        local o = math.floor(hash(tx + 13, ty) * 11)
        gfx.drawPixel(x + 2 + o, y + 3 + (o * 5) % 10)
    end
end

local function thickArt(x, y, tx, ty)
    Gfx.fill(x, y, 16, 16, 2)
    if hash(tx, ty + 55) < 0.4 then
        gfx.setColor(gfx.kColorBlack)
        local o = math.floor(hash(tx + 5, ty) * 9)
        gfx.drawLine(x + 2 + o, y + 11, x + 4 + o, y + 8)
    end
end

local function dirtArt(x, y, tx, ty)
    Gfx.fill(x, y, 16, 16, 4)
    if hash(tx, ty + 33) < 0.3 then
        gfx.setColor(gfx.kColorBlack)
        local o = math.floor(hash(tx + 9, ty) * 10)
        gfx.drawPixel(x + 3 + o, y + 4 + (o * 3) % 9)
    end
end

local function pathArt(x, y, tx, ty)
    Gfx.fill(x, y, 16, 16, 0)
    gfx.setColor(gfx.kColorBlack)
    if hash(tx, ty) < 0.5 then
        gfx.drawPixel(x + 2 + math.floor(hash(tx, ty + 7) * 12),
            y + 2 + math.floor(hash(tx + 7, ty) * 12))
    end
end

local function treeArt(x, y, tx, ty)
    Gfx.fill(x, y, 16, 16, 2)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(x + 7, y + 9, 3, 6)
    gfx.fillTriangle(x + 8, y + 1, x + 2, y + 11, x + 14, y + 11)
    gfx.setColor(gfx.kColorWhite) -- snow-dusted tip
    gfx.drawPixel(x + 8, y + 2)
    gfx.drawPixel(x + 7, y + 4)
end

local function rockArt(x, y, tx, ty)
    Gfx.fill(x, y, 16, 16, 6)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillEllipseInRect(x + 2, y + 4, 12, 10)
    gfx.setColor(gfx.kColorWhite) -- white cap (landmark rule)
    gfx.fillRect(x + 5, y + 4, 5, 2)
end

local function canopyArt(x, y, tx, ty)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(x + 4, y + 4, 5)
    gfx.fillCircleAtPoint(x + 12, y + 5, 5)
    gfx.fillCircleAtPoint(x + 7, y + 12, 6)
    gfx.setColor(gfx.kColorWhite) -- snow caught in the crown
    gfx.drawPixel(x + 3, y + 2)
    gfx.drawPixel(x + 12, y + 4)
    gfx.drawPixel(x + 8, y + 11)
end

local function brambleArt(x, y, tx, ty)
    Gfx.fill(x, y, 16, 16, 3)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(x + 1, y + 3, x + 14, y + 12)
    gfx.drawLine(x + 2, y + 12, x + 13, y + 2)
    gfx.drawLine(x + 7, y + 1, x + 9, y + 14)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawPixel(x + 4, y + 6)
    gfx.drawPixel(x + 11, y + 9)
end

local function rubbleArt(x, y, tx, ty)
    Gfx.fill(x, y, 16, 16, 4)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(x + 2, y + 8, 6, 5)
    gfx.fillRect(x + 9, y + 3, 5, 4)
    gfx.fillRect(x + 6, y + 12, 7, 3)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawPixel(x + 4, y + 9)
    gfx.drawPixel(x + 11, y + 4)
end

local function holeArt(x, y, tx, ty)
    dirtArt(x, y, tx, ty)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillEllipseInRect(x + 4, y + 6, 9, 6)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawPixel(x + 4, y + 6)
end

local function denholeArt(x, y, tx, ty)
    snowArt(x, y, tx, ty)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillEllipseInRect(x + 3, y + 5, 10, 8)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawPixel(x + 5, y + 6)
end

local function denArt(x, y, tx, ty)
    Gfx.fill(x, y, 16, 16, 3)
    if (tx + ty) % 3 == 0 then
        gfx.setColor(gfx.kColorBlack)
        gfx.drawPixel(x + 6, y + 9)
    end
end

local function exitArt(x, y, tx, ty)
    denArt(x, y, tx, ty)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillEllipseInRect(x + 3, y + 4, 10, 9)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawPixel(x + 7, y + 6)
end

Maps.legend = {
    ["."] = { art = snowArt, zone = "meadow" },
    [","] = { art = thickArt, zone = "thicket", speed = 0.95 },
    [":"] = { art = dirtArt, zone = "warren", speed = 0.95 },
    ["p"] = { art = pathArt, speed = 1.2 },
    ["t"] = { art = treeArt, solid = true },
    ["#"] = { art = rockArt, solid = true },
    ["T"] = { art = canopyArt, overhead = true, under = "," },
    ["P"] = { art = canopyArt, overhead = true, under = "p",
        speed = 1.2 },
    ["b"] = { art = brambleArt, solid = true },
    ["r"] = { art = rubbleArt, solid = true },
    ["o"] = { art = holeArt, zone = "warren", speed = 0.95 },
    ["d"] = { art = denholeArt, trigger = "denhole" },
    ["e"] = { art = exitArt, trigger = "denexit" },
    ["_"] = { art = denArt },
}

-- ---- the world ---------------------------------------------------------

local function cellFor(tx, ty)
    if tx == 1 or ty == 1 or tx == C.WORLD_W
        or ty == C.WORLD_H then
        return "#"
    end
    if tx == C.GATE1_X or tx == C.GATE1_X + 1 then return "b" end
    if tx == C.GATE2_X or tx == C.GATE2_X + 1 then return "r" end
    local zone = G.zoneAt(tx)
    if ty >= C.BAND_Y0 and ty <= C.BAND_Y1 then -- the open valley
        return zone == "meadow" and "."
            or (zone == "thicket" and "," or ":")
    end
    local n = noise(tx, ty)
    if zone == "meadow" then
        if n > 0.86 then return "#" end
        if n > 0.70 then return "t" end
        return "."
    elseif zone == "thicket" then
        if n > 0.86 then return "#" end
        if n > 0.64 then return "t" end
        if n > 0.55 then return "T" end
        return ","
    end
    if n > 0.78 then return "#" end
    if n > 0.64 then return "o" end
    return ":"
end

local worldRows = nil

function Maps.world()
    if worldRows then return worldRows end
    local grid = {}
    for ty = 1, C.WORLD_H do
        local r = {}
        for tx = 1, C.WORLD_W do r[tx] = cellFor(tx, ty) end
        grid[ty] = r
    end
    -- the east-west run; the gates stay standing across it
    for tx = 3, C.WORLD_W - 2 do
        if tx < C.GATE1_X or (tx > C.GATE1_X + 1
            and tx < C.GATE2_X) or tx > C.GATE2_X + 1 then
            for ty = C.ROAD_Y - 1, C.ROAD_Y + 1 do
                grid[ty][tx] = "p"
            end
        end
    end
    -- canopy over the thicket road: the walk-behind showcase
    for tx = C.CANOPY_X0, C.CANOPY_X1 do
        grid[C.ROAD_Y - 2][tx] = "T"
        grid[C.ROAD_Y - 1][tx] = "P"
        grid[C.ROAD_Y][tx] = "P"
        grid[C.ROAD_Y + 1][tx] = "P"
        grid[C.ROAD_Y + 2][tx] = "T"
    end
    grid[C.DEN_Y][C.DEN_X] = "d" -- home
    local rows = {}
    for ty = 1, C.WORLD_H do rows[ty] = table.concat(grid[ty]) end
    worldRows = rows
    return worldRows
end

-- clear a road-wide gap through gate n (1 = bramble, 2 = tunnel);
-- world map must be loaded. Re-applied from flags at every load.
function Maps.openGate(n)
    local x = (n == 1) and C.GATE1_X or C.GATE2_X
    for ty = C.ROAD_Y - 3, C.ROAD_Y + 3 do
        Map.set(x, ty, "p")
        Map.set(x + 1, ty, "p")
    end
end

-- ---- home --------------------------------------------------------------

Maps.den = {
    "################",
    "#______________#",
    "#______________#",
    "#______________#",
    "#______________#",
    "#______________#",
    "#______________#",
    "#______________#",
    "#______________#",
    "#######e########",
}

-- Shrew maps: the three worlds and their legends. The 120x90
-- overworld is generated (deterministic hash noise + stamped
-- features: forest, marsh, the river band, the mountain ring, the
-- roads the quest walks); VOLEHOLM and the two Burrow floors are
-- rows-as-strings. Overhead roof cells give the town walk-behind;
-- the Burrow runs a dark-ish palette. All tile art is procedural.

local gfx = playdate.graphics

Maps = {}

-- ---- deterministic hash (worldgen must not touch math.random) -------

local function hash(x, y)
    local n = (x * 73856093 + y * 19349663 + 7919) % 2147483647
    n = (n * 48271) % 2147483647
    return n / 2147483647
end

-- ---- tile art (16px at x,y in the chunk context; tx,ty = world) -----

local function grassArt(x, y, tx, ty)
    Gfx.fill(x, y, 16, 16, 2)
    if hash(tx, ty + 411) < 0.3 then
        gfx.setColor(gfx.kColorBlack)
        local o = math.floor(hash(tx + 17, ty) * 11)
        gfx.fillRect(x + 2 + o, y + 4 + (o * 5) % 9, 1, 2)
    end
end

local function fernArt(x, y, tx, ty)
    Gfx.fill(x, y, 16, 16, 3)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(x + 4, y + 12, x + 4, y + 5)
    gfx.drawLine(x + 4, y + 7, x + 7, y + 4)
    gfx.drawLine(x + 11, y + 13, x + 11, y + 6)
    gfx.drawLine(x + 11, y + 8, x + 8, y + 5)
end

local function marshArt(x, y, tx, ty)
    Gfx.fill(x, y, 16, 16, 4)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(x + 3, y + 12, x + 3, y + 7)
    gfx.drawLine(x + 8, y + 13, x + 8, y + 8)
    gfx.setColor(gfx.kColorWhite)
    local o = (tx + ty) % 2 * 5
    gfx.fillRect(x + 2 + o, y + 14, 5, 1)
end

local function pathArt(x, y, tx, ty)
    Gfx.fill(x, y, 16, 16, 0)
    gfx.setColor(gfx.kColorBlack)
    if hash(tx, ty) < 0.5 then
        gfx.drawPixel(x + 2 + math.floor(hash(tx, ty + 3) * 12),
            y + 2 + math.floor(hash(tx + 3, ty) * 12))
    end
end

local function waterArt(x, y, tx, ty)
    Gfx.fill(x, y, 16, 16, 5)
    gfx.setColor(gfx.kColorWhite)
    local o = (tx + ty) % 2 * 4
    gfx.fillRect(x + 2 + o, y + 4, 5, 1)
    gfx.fillRect(x + 6 - o + 4, y + 11, 5, 1)
end

local function treeArt(x, y, tx, ty)
    Gfx.fill(x, y, 16, 16, 2)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(x + 7, y + 10, 3, 5)
    gfx.fillCircleAtPoint(x + 8, y + 6, 5)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawPixel(x + 6, y + 4)
end

local function mtnArt(x, y, tx, ty)
    Gfx.fill(x, y, 16, 16, 5)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillTriangle(x + 1, y + 14, x + 8, y + 2, x + 15, y + 14)
    gfx.setColor(gfx.kColorWhite) -- white-capped landmark
    gfx.fillTriangle(x + 6, y + 5, x + 8, y + 2, x + 10, y + 5)
end

local function dockArt(x, y, tx, ty)
    Gfx.fill(x, y, 16, 16, 0)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(x + 1, y + 5, x + 14, y + 5)
    gfx.drawLine(x + 1, y + 10, x + 14, y + 10)
end

local function gateArt(x, y, tx, ty)
    pathArt(x, y, tx, ty)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(x + 3, y + 6, 10, 8)
    gfx.fillTriangle(x + 1, y + 6, x + 8, y + 1, x + 15, y + 6)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(x + 7, y + 9, 3, 5)
end

local function caveArt(x, y, tx, ty)
    mtnArt(x, y, tx, ty)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillEllipseInRect(x + 5, y + 7, 7, 8)
end

-- town furniture
local function wallArt(x, y, tx, ty)
    Gfx.fill(x, y, 16, 16, 6)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(x + 1, y + 1, 14, 14)
    gfx.fillRect(x + 6, y + 8, 4, 7)
end

local function roofArt(x, y, tx, ty)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(x, y, 16, 16)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawLine(x, y + 3, x + 15, y + 3)
    gfx.drawLine(x, y + 11, x + 15, y + 11)
end

-- the Burrow (dark-ish palette: heavy floors, black walls)
local function bfloorArt(x, y, tx, ty)
    Gfx.fill(x, y, 16, 16, 4)
    if hash(tx, ty + 88) < 0.3 then
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(x + 3 + (tx * 5) % 9, y + 3 + (ty * 7) % 9,
            2, 1)
    end
end

local function bwallArt(x, y, tx, ty)
    Gfx.fill(x, y, 16, 16, 7)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawPixel(x + 3 + (tx * 7) % 9, y + 2 + (ty * 5) % 11)
end

local function stairArt(x, y, tx, ty)
    bfloorArt(x, y, tx, ty)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(x + 2, y + 2, 12, 12)
    gfx.drawRect(x + 5, y + 5, 9, 9)
    gfx.drawRect(x + 8, y + 8, 6, 6)
end

local function doorArt(x, y, tx, ty)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(x, y, 16, 16)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRoundRect(x + 2, y + 1, 12, 15, 3)
    gfx.fillCircleAtPoint(x + 8, y + 8, 2)
    gfx.fillRect(x + 7, y + 9, 2, 4)
end

local function keyholeArt(x, y, tx, ty)
    bfloorArt(x, y, tx, ty)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawCircleAtPoint(x + 8, y + 8, 4)
end

-- ---- legends --------------------------------------------------------------

local WORLD_LEGEND = {
    ["g"] = { art = grassArt },
    ["f"] = { art = fernArt, speed = 0.9, zone = "forest" },
    ["h"] = { art = marshArt, speed = 0.8, zone = "marsh" },
    ["p"] = { art = pathArt, speed = 1.2 },
    ["w"] = { art = waterArt, water = true },
    ["t"] = { art = treeArt, solid = true },
    ["m"] = { art = mtnArt, solid = true },
    ["d"] = { art = dockArt, trigger = "dock" },
    ["V"] = { art = gateArt, trigger = "town" },
    ["D"] = { art = caveArt, trigger = "cave" },
}

local TOWN_LEGEND = {
    ["g"] = { art = grassArt },
    ["p"] = { art = pathArt, speed = 1.2 },
    ["w"] = { art = waterArt, water = true },
    ["H"] = { art = wallArt, solid = true },
    ["R"] = { art = roofArt, overhead = true, under = "g" },
    ["E"] = { art = pathArt, speed = 1.2, trigger = "exitTown" },
}

local BURROW_LEGEND = {
    ["."] = { art = bfloorArt },
    ["#"] = { art = bwallArt, solid = true },
    ["S"] = { art = stairArt, trigger = "stairs1" },
    ["U"] = { art = stairArt, trigger = "stairs2up" },
    ["X"] = { art = stairArt, trigger = "exitBurrow" },
    ["L"] = { art = doorArt, solid = true },
    ["k"] = { art = keyholeArt, trigger = "keyhole" },
    ["B"] = { art = bfloorArt, trigger = "boss" },
}

-- ---- the overworld (generated once, cached) -------------------------------

local worldRows = nil

local function genWorld()
    local W, H = C.WORLD_W, C.WORLD_H
    local grid = {}
    for ty = 1, H do
        local r = {}
        for tx = 1, W do
            r[tx] = hash(tx, ty) < 0.055 and "t" or "g"
        end
        grid[ty] = r
    end
    local function box(b, ch, fn)
        for ty = b[2], b[4] do
            for tx = b[1], b[3] do
                grid[ty][tx] = (fn and fn(tx, ty)) or ch
            end
        end
    end
    -- forest ferns (a few inner trees), marsh reeds
    box(C.FOREST, "f", function(tx, ty)
        return hash(tx + 5, ty + 5) < 0.1 and "t" or "f"
    end)
    box(C.MARSH, "h")
    -- the river splits the east, top to bottom (no bridge: BOAT)
    for ty = 1, H do
        for tx = C.RIVER_X0, C.RIVER_X1 do grid[ty][tx] = "w" end
    end
    -- the mountain ring; a one-corridor pass on the west face
    box(C.MTN, "m")
    for ty = C.PASS_Y - 1, C.PASS_Y + 1 do
        for tx = C.MTN[1], C.CAVE_X - 1 do grid[ty][tx] = "p" end
    end
    -- roads: town->south, west row to the forest chest + east to
    -- the dock col, dock col north, east bank to the pass
    for ty = C.TOWN_Y + 1, 52 do grid[ty][C.TOWN_X] = "p" end
    for tx = C.OARCH_X, C.DOCK_X do grid[52][tx] = "p" end
    for ty = C.DOCK_Y + 1, 52 do grid[ty][C.DOCK_X] = "p" end
    for tx = C.RIVER_X1 + 1, C.MTN[1] do
        grid[C.PASS_Y][tx] = "p"
    end
    grid[C.DOCK_Y][C.DOCK_X] = "d"
    grid[C.TOWN_Y][C.TOWN_X] = "V"
    grid[C.CAVE_Y][C.CAVE_X] = "D"
    local rows = {}
    for ty = 1, H do rows[ty] = table.concat(grid[ty]) end
    return rows
end

-- ---- VOLEHOLM (32x22): six roofed buildings, the pond, the gate -----------

local TOWN_ROWS = {
    "gggggggggggggggggggggggggggggggg",
    "gggRRRRRggggRRRRRggggRRRRRgggggg",
    "gggRRRRRggggRRRRRggggRRRRRgggggg",
    "gggHHHHHggggHHHHHggggHHHHHgggggg",
    "gggggggggggggggggggggggggggggggg",
    "ggpppppppppppppppppppppppppggggg",
    "gggggggggggggggggggggggggggggggg",
    "ggggRRRRRgggggRRRRRgggRRRRRggggg",
    "ggggRRRRRgggggRRRRRgggRRRRRggggg",
    "ggggHHHHHgggggHHHHHgggHHHHHggggg",
    "gggggggggggggggggggggggggggggggg",
    "ggpppppppppppppppppppppppppggggg",
    "gggggggggggggggggggggggwwwwwgggg",
    "ggggggggggggggggggggggwwwwwwwggg",
    "gggggggggggggggggggggggwwwwwgggg",
    "gggggggggggggggggggggggggggggggg",
    "gggggggggggggggggggggggggggggggg",
    "gggggggggggggggggggggggggggggggg",
    "gggggggggggggggggggggggggggggggg",
    "ggggggggggggggpppggggggggggggggg",
    "ggggggggggggggpppggggggggggggggg",
    "ggggggggggggggEEEggggggggggggggg",
}

-- ---- THE BURROW (26x16 a floor) -------------------------------------------

local B1_ROWS = {
    "##########################",
    "#X.......................#",
    "#........................#",
    "#..##.....##......##.....#",
    "#........................#",
    "#......##.......##.......#",
    "#........................#",
    "#...##.......##......##..#",
    "#........................#",
    "#........................#",
    "#......##........##......#",
    "#........................#",
    "#...##.......##.........S#",
    "#........................#",
    "#.....##........##.......#",
    "##########################",
}

local B2_ROWS = {
    "##########################",
    "#..........#.............#",
    "#...##.....#....##....##.#",
    "#..........#.............#",
    "#...##.....#.....####....#",
    "#..........#.............#",
    "#..........#.............#",
    "#U........kL.......B.....#",
    "#..........#.............#",
    "#..........#.............#",
    "#...##.....#.....####....#",
    "#..........#.............#",
    "#...##.....#....##....##.#",
    "#..........#.............#",
    "#..........#.............#",
    "##########################",
}

-- ---- chest placement (loot spawns as interactable actors) -----------------

Maps.chests = {
    world = { { C.OARCH_X, C.OARCH_Y, "oar", 1 } },
    burrow1 = {
        { C.B1_KEYCH[1], C.B1_KEYCH[2], "brass_key", 1 },
        { C.B1_CAKECH[1], C.B1_CAKECH[2], "seed_cake", 1 },
    },
    burrow2 = {
        { C.B2_CLOAKCH[1], C.B2_CLOAKCH[2], "moss_cloak", 1 },
        { C.B2_CAKECH[1], C.B2_CAKECH[2], "seed_cake", 1 },
    },
    town = {},
}

-- ---- lookup ---------------------------------------------------------------

function Maps.def(name)
    if name == "world" then
        worldRows = worldRows or genWorld()
        return { rows = worldRows, legend = WORLD_LEGEND }
    elseif name == "town" then
        return { rows = TOWN_ROWS, legend = TOWN_LEGEND }
    elseif name == "burrow1" then
        return { rows = B1_ROWS, legend = BURROW_LEGEND }
    end
    return { rows = B2_ROWS, legend = BURROW_LEGEND }
end

-- Slice simulation: procedural 120x90 overworld (hash-noise terrain +
-- a stamped ring road, canopy walk-behind band, shrine trigger), the
-- white-rigged player, 4 NPCs (stand/wander/2 patrols), touch
-- counting, and the field state the cabinet runs. Wave 2 adds the
-- story layer: a guard you can talk to (and who escorts you shrine-
-- ward), a scripted shrine scene, a merchant with a 3-item stock, one
-- persistent chest, the pause menu, and save/load — all on the east
-- road so the demo stays one compact loop. Wave 3 adds the combat
-- proof: a one-walker Party sheet, meadow/forest encounter zones
-- (sod mites + bramble hares -> lturn scenes), a stick weapon and a
-- flag-gated bramble-hare roamer felled by laction, and lmusic field
-- song (A A B) + battle stinger + victory fanfare.

local gfx = playdate.graphics

G = { t = 0 }

Game = {}

-- ---- deterministic hash noise (map gen must not use math.random) ----

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

-- ---- tile art (16px, drawn into the chunk at x,y; tx,ty = world) ----

local function grassArt(x, y, tx, ty)
    -- mid-gray field (palette rule): grass must read darker than
    -- the white road so the white player pops on both
    Gfx.fill(x, y, 16, 16, 2)
    if hash(tx, ty + 999) < 0.35 then
        gfx.setColor(gfx.kColorBlack)
        local o = math.floor(hash(tx + 31, ty) * 10)
        gfx.fillRect(x + 3 + o, y + 5 + (o * 7) % 8, 1, 2)
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

local function waterArt(x, y, tx, ty)
    Gfx.fill(x, y, 16, 16, 4)
    gfx.setColor(gfx.kColorWhite)
    local o = (tx + ty) % 2 * 4
    gfx.fillRect(x + 2 + o, y + 4, 5, 1)
    gfx.fillRect(x + 6 - o + 4, y + 11, 5, 1)
end

local function mtnArt(x, y, tx, ty)
    Gfx.fill(x, y, 16, 16, 5)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillTriangle(x + 1, y + 14, x + 8, y + 2, x + 15, y + 14)
    gfx.setColor(gfx.kColorWhite) -- white-capped landmark
    gfx.fillTriangle(x + 6, y + 5, x + 8, y + 2, x + 10, y + 5)
end

local function treeArt(x, y, tx, ty)
    Gfx.fill(x, y, 16, 16, 1)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(x + 7, y + 10, 3, 5)
    gfx.fillCircleAtPoint(x + 8, y + 6, 5)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawPixel(x + 6, y + 4)
    gfx.drawPixel(x + 10, y + 7)
end

-- canopy: pre-rendered once per def (transparent corners), drawn
-- per-cell after actors — the walk-behind layer
local function canopyArt(x, y, tx, ty)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(x + 4, y + 5, 5)
    gfx.fillCircleAtPoint(x + 12, y + 4, 5)
    gfx.fillCircleAtPoint(x + 8, y + 12, 6)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawPixel(x + 3, y + 3)
    gfx.drawPixel(x + 11, y + 6)
    gfx.drawPixel(x + 7, y + 11)
    gfx.drawPixel(x + 13, y + 13)
end

local function shrineArt(x, y, tx, ty)
    pathArt(x, y, tx, ty)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRoundRect(x + 4, y + 3, 8, 10, 2)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawPixel(x + 7, y + 6)
    gfx.drawPixel(x + 8, y + 8)
end

-- fern undergrowth: the walkable forest floor (encounter zone)
local function fernArt(x, y, tx, ty)
    Gfx.fill(x, y, 16, 16, 3)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(x + 4, y + 12, x + 4, y + 5)
    gfx.drawLine(x + 4, y + 7, x + 7, y + 4)
    gfx.drawLine(x + 11, y + 13, x + 11, y + 6)
    gfx.drawLine(x + 11, y + 8, x + 8, y + 5)
end

local LEGEND = {
    ["g"] = { art = grassArt, speed = 1, zone = "meadow" },
    ["f"] = { art = fernArt, speed = 0.9, zone = "forest" },
    ["p"] = { art = pathArt, speed = 1.25 },
    ["w"] = { art = waterArt, water = true, zone = "water" },
    ["m"] = { art = mtnArt, solid = true },
    ["t"] = { art = treeArt, solid = true, zone = "forest" },
    ["T"] = { art = canopyArt, overhead = true, under = "g" },
    ["P"] = { art = canopyArt, overhead = true, under = "p",
        speed = 1.25 },
    ["x"] = { art = shrineArt, trigger = "shrine", speed = 1.25 },
}

-- ---- world generation ------------------------------------------------

local function genRows()
    local grid = {}
    for ty = 1, C.WORLD_H do
        local r = {}
        for tx = 1, C.WORLD_W do
            local n = noise(tx, ty)
            if n < 0.22 then r[tx] = "w"
            elseif n > 0.82 then r[tx] = "m"
            elseif n > 0.66 then r[tx] = "t"
            else r[tx] = "g" end
        end
        grid[ty] = r
    end
    -- NPC clearing (wander home lives here)
    for ty = 12, 18 do
        for tx = 14, 26 do grid[ty][tx] = "g" end
    end
    -- the ring road: two-tile-wide walkable bands
    for tx = C.RING_X0, C.RING_X1 + 1 do
        grid[C.RING_Y0][tx] = "p"
        grid[C.RING_Y0 + 1][tx] = "p"
        grid[C.RING_Y1][tx] = "p"
        grid[C.RING_Y1 + 1][tx] = "p"
    end
    for ty = C.RING_Y0, C.RING_Y1 + 1 do
        grid[ty][C.RING_X0] = "p"
        grid[ty][C.RING_X0 + 1] = "p"
        grid[ty][C.RING_X1] = "p"
        grid[ty][C.RING_X1 + 1] = "p"
    end
    -- canopy band across the top road: walk-behind proof
    for tx = C.CANOPY_X0, C.CANOPY_X1 do
        grid[C.RING_Y0 - 1][tx] = "T"
        grid[C.RING_Y0][tx] = "P"
        grid[C.RING_Y0 + 1][tx] = "P"
        grid[C.RING_Y0 + 2][tx] = "T"
    end
    -- wave-3 combat patches: guaranteed meadow by the east road,
    -- ferns (forest zone, the roamer's lair) touching the south road
    for ty = C.MEADOW_Y0, C.MEADOW_Y1 do
        for tx = C.MEADOW_X0, C.MEADOW_X1 do grid[ty][tx] = "g" end
    end
    for ty = C.FOREST_Y0, C.FOREST_Y1 do
        for tx = C.FOREST_X0, C.FOREST_X1 do grid[ty][tx] = "f" end
    end
    -- the shrine trigger on the east road
    grid[C.TRIG_Y][C.TRIG_X] = "x"
    local rows = {}
    for ty = 1, C.WORLD_H do rows[ty] = table.concat(grid[ty]) end
    return rows
end

-- ---- rigs (palette rules: white player, dark NPCs w/ eye pixel) -----

local function playerArt(dir, frame)
    gfx.setColor(gfx.kColorBlack) -- outline
    gfx.fillEllipseInRect(3, 1, 10, 10)
    gfx.fillRect(2, 8, 12, 9)
    gfx.setColor(gfx.kColorWhite) -- white body
    gfx.fillEllipseInRect(4, 2, 8, 8)
    gfx.fillRect(3, 9, 10, 7)
    gfx.setColor(gfx.kColorBlack) -- eyes by facing
    if dir == Act.DOWN then
        gfx.fillRect(6, 5, 1, 2)
        gfx.fillRect(9, 5, 1, 2)
    elseif dir == Act.LEFT then
        gfx.fillRect(5, 5, 1, 2)
    elseif dir == Act.RIGHT then
        gfx.fillRect(10, 5, 1, 2)
    end -- UP: back of head, no eyes
    local o = (frame == 1) and 0 or 2 -- alternating legs
    gfx.fillRect(4 + o, 16, 3, 3)
    gfx.fillRect(9 - o, 16, 3, 3)
end

local function npcArt(dir, frame)
    gfx.setColor(gfx.kColorBlack) -- dark body
    gfx.fillEllipseInRect(4, 2, 8, 8)
    gfx.fillRect(3, 9, 10, 7)
    gfx.setColor(gfx.kColorWhite) -- the eye pixel(s)
    if dir == Act.DOWN then
        gfx.drawPixel(6, 5)
        gfx.drawPixel(9, 5)
    elseif dir == Act.LEFT then
        gfx.drawPixel(5, 5)
    elseif dir == Act.RIGHT then
        gfx.drawPixel(10, 5)
    end
    gfx.setColor(gfx.kColorBlack)
    local o = (frame == 1) and 0 or 2
    gfx.fillRect(4 + o, 16, 3, 3)
    gfx.fillRect(9 - o, 16, 3, 3)
end

-- ---- chest art (two static images, built once) -----------------------

local function chestImg(open)
    local img = gfx.image.new(14, 12)
    gfx.pushContext(img)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRoundRect(0, 2, 14, 10, 2)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRoundRect(0, 2, 14, 10, 2)
    if open then
        gfx.fillRect(2, 4, 10, 3) -- thrown-back lid glints white
    else
        gfx.drawLine(1, 6, 12, 6) -- lid seam
        gfx.drawPixel(6, 8)       -- the clasp
    end
    gfx.popContext()
    return img
end

-- ---- wave-3 content: monsters, items, skills, songs -------------------
-- Bestiary artFns are parametric (w, h): lturn draws them 48x48,
-- laction 16x16. Palette rule: dark bodies, white eye pixels.

local function miteArt(w, h)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillEllipseInRect(w * 0.1, h * 0.35, w * 0.8, h * 0.5)
    gfx.drawLine(w * 0.2, h * 0.8, w * 0.08, h * 0.95)
    gfx.drawLine(w * 0.5, h * 0.85, w * 0.5, h * 0.98)
    gfx.drawLine(w * 0.8, h * 0.8, w * 0.92, h * 0.95)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(w * 0.35, h * 0.55,
        math.max(1, w * 0.05))
    gfx.fillCircleAtPoint(w * 0.65, h * 0.55,
        math.max(1, w * 0.05))
end

local function hareArt(w, h)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillEllipseInRect(w * 0.24, 0, w * 0.16, h * 0.5)
    gfx.fillEllipseInRect(w * 0.56, 0, w * 0.16, h * 0.5)
    gfx.fillEllipseInRect(w * 0.15, h * 0.35, w * 0.7, h * 0.6)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(w * 0.38, h * 0.58,
        math.max(1, w * 0.05))
    gfx.fillCircleAtPoint(w * 0.62, h * 0.58,
        math.max(1, w * 0.05))
end

local ITEMS = {
    herb = { name = "Herb", kind = "heal", power = 12, price = 6,
        target = "one" },
    torch = { name = "Torch", kind = "key", price = 10 },
    rope = { name = "Rope", kind = "key", price = 8 },
    stick = { name = "Stick", kind = "weapon", power = 3,
        price = 5 },
}

local SKILLS = {
    gust = { name = "Gust", mp = 2, power = 9, kind = "dmg",
        target = "one", element = "wind" },
    mend = { name = "Mend", mp = 2, power = 10, kind = "heal",
        target = "self" },
}

local BESTIARY = {
    sod_mite = {
        name = "Sod Mite", hp = 7, atk = 4, def = 2, agi = 3,
        xp = 12, gold = 4, ai = "basic", artFn = miteArt,
        elems = { wind = 1.5 },
        drop = { item = "herb", chance = 0.3 },
    },
    bramble_hare = {
        name = "Bramble Hare", hp = 14, atk = 6, def = 3, agi = 5,
        mp = 4, xp = 18, gold = 7, ai = "sly", skills = { "mend" },
        artFn = hareArt, fspeed = 45,
    },
}

local SONGS = {
    field = {
        tempo = 100,
        patterns = {
            A = {
                bass = { 36, 0, 0, 0, 43, 0, 0, 0,
                    36, 0, 0, 0, 41, 0, 0, 0 },
                lead = { 60, 0, 64, 0, 67, 0, 64, 0,
                    60, 0, 64, 0, 65, 64, 62, 0 },
                hat = { 1, 0, 0, 0, 1, 0, 0, 0,
                    1, 0, 0, 0, 1, 0, 1, 0 },
            },
            B = {
                bass = { 34, 0, 0, 0, 41, 0, 0, 0,
                    34, 0, 0, 0, 43, 0, 0, 0 },
                lead = { 62, 0, 65, 0, 69, 0, 65, 0,
                    62, 0, 65, 0, 67, 65, 64, 0 },
                hat = { 1, 0, 0, 0, 1, 0, 0, 0,
                    1, 0, 0, 0, 1, 0, 1, 0 },
            },
        },
        order = { "A", "A", "B" },
    },
    battle = {
        tempo = 140,
        patterns = {
            A = {
                bass = { 33, 0, 33, 0, 33, 0, 33, 0,
                    31, 0, 31, 0, 36, 0, 35, 0 },
                lead = { 69, 0, 0, 68, 69, 0, 72, 0,
                    67, 0, 0, 66, 67, 0, 71, 0 },
                hat = { 1, 0, 1, 0, 1, 0, 1, 0,
                    1, 0, 1, 0, 1, 1, 1, 0 },
            },
        },
        order = { "A" },
    },
    fanfare = { -- the 2-bar victory sting (once, then field resumes)
        tempo = 120,
        patterns = {
            A = {
                bass = { 48, 0, 0, 0, 48, 0, 0, 0,
                    43, 0, 0, 0, 48, 0, 0, 0 },
                lead = { 72, 0, 72, 0, 72, 0, 76, 0,
                    79, 0, 0, 0, 76, 0, 79, 0 },
            },
        },
        order = { "A", "A" },
    },
}
G.songs = SONGS

-- ---- init + update --------------------------------------------------

local rowsCache = nil

-- the map loader (also Script.loader, so warp() lands here): rebuild
-- the world + all actors; chest visual honors the State ledger
function Game.loadMap(name, tx, ty)
    G.mapName = name -- slice has the one map, "world"
    rowsCache = rowsCache or genRows()
    Map.load{ rows = rowsCache, legend = LEGEND }
    Act.reset()
    Action.reset()
    Enc.enter(name)
    G.prig = G.prig or Act.rig(playerArt)
    G.nrig = G.nrig or Act.rig(npcArt)
    G.chestShut = G.chestShut or chestImg(false)
    G.chestOpen = G.chestOpen or chestImg(true)
    G.player = Act.new{
        kind = "player", x = Map.cx(tx), y = Map.cy(ty),
        hw = 5, hh = 5, speed = C.PLAYER_SPEED, sprite = G.prig,
        onTrigger = function(id, ttx, tty)
            if Script.trigger(id, ttx, tty) then
                Harness.count("toasts")
            end
        end,
        onStep = function(a) Enc.onStep(a) end,
    }
    G.npcs = {}
    local function npc(kind, ntx, nty, behavior)
        local a = Act.new{
            kind = kind, x = Map.cx(ntx), y = Map.cy(nty),
            hw = 5, hh = 5, speed = C.NPC_SPEED, sprite = G.nrig,
            behavior = behavior,
        }
        G.npcs[#G.npcs + 1] = a
        return a
    end
    npc("npc", 16, 13, { kind = "stand" })
    npc("npc", 20, 15, { kind = "wander", radius = 3 })
    npc("npc", 20, 9,
        { kind = "patrol", points = { { 20, 9 }, { 35, 9 } } })
    G.guard = npc("guard", C.TRIG_X, C.GUARD_Y0, { kind = "patrol",
        points = { { C.TRIG_X, C.GUARD_Y0 },
            { C.TRIG_X, C.GUARD_Y1 } } })
    G.merchant = npc("merchant", C.MERCH_X, C.MERCH_Y,
        { kind = "stand" })
    local opened = State.opened(name, C.CHEST_X, C.CHEST_Y)
    G.chest = Act.new{
        kind = "chest",
        x = Map.cx(C.CHEST_X), y = Map.cy(C.CHEST_Y),
        hw = 6, hh = 5,
        img = opened and G.chestOpen or G.chestShut,
    }
    -- the forest roamer (laction field foe); stays down once slain
    G.roamer = nil
    if not State.get("roamer_dead") then
        G.roamer = Action.spawn{
            id = "bramble_hare",
            x = Map.cx(C.ROAMER_X), y = Map.cy(C.ROAMER_Y),
            aggro = 80,
            onDeath = function() State.set("roamer_dead") end,
        }
    end
    Cam.reset()
    Cam.center(G.player.x, G.player.y)
    Script.followTarget = G.player
    Script.enter(name)
end

-- ---- the story (attach points; scripts read like screenplays) --------

local function registerStory()
    Script.onTalk("guard", function(npc, player)
        if hasflag("guard_led") then
            say("Guard", "The shrine hums, friend. I heard it too.")
            return
        end
        say("Guard", "Cold night on the east road, traveler.")
        local i = ask("The shrine calls. Join me?",
            { "Follow me", "Farewell" })
        if i == 1 then
            npc.behavior = nil -- off patrol: escort duty
            walk(npc, { tx = C.TRIG_X - 1, ty = C.TRIG_Y + 1 })
            face(npc, "right")
            say("Guard", "The shrine lies just ahead. After you.")
            setflag("guard_led")
        else
            say("Guard", "Safe travels, then.")
        end
    end)

    Script.onTrigger("shrine", function()
        local wx, wy = Map.cx(C.TRIG_X), Map.cy(C.TRIG_Y)
        if hasflag("shrine_lit") then
            toast("The shrine is quiet now.")
            return
        end
        pan(wx, wy - 24, 160)
        fade(0.7)
        wait(0.4)
        setflag("shrine_lit")
        toast("The shrine hums")
        UI.popup(wx, wy - 14, "hum")
        fade(0)
        panBack()
    end)

    Script.onTalk("merchant", function()
        say("Merchant", "Torches, herbs, rope. Road prices.")
        shop{
            { item = "torch", price = 10 },
            { item = "herb", price = 6 },
            { item = "rope", price = 8 },
        }
        say("Merchant", "Mind the dark out there.")
    end)

    Script.onTalk("chest", function(chest)
        if State.opened(G.mapName, chest.cellX, chest.cellY) then
            say(nil, "The chest is empty.")
        else
            State.markOpened(G.mapName, chest.cellX, chest.cellY)
            chest.img = G.chestOpen
            give("herb", 2)
            UI.popup(chest.x, chest.y - 16, "+2 herb")
        end
    end)

    Script.onEnter("world", function()
        toast("The wind stirs over the ring road.")
    end)
end

function Game.init()
    if Harness.enabled then State.wipe() end -- deterministic smoke
    if not State.load() then
        State.gold = C.GOLD_START -- fresh ledger
    end
    -- the sheet + combat content (registries survive a State.load)
    Party.defineItems(ITEMS)
    Party.defineSkills(SKILLS)
    Party.defineBestiary(BESTIARY)
    Party.add{
        id = "walker", name = "Walker", lvl = 1, hp = 26, mp = 6,
        atk = 6, def = 4, agi = 4,
        growth = { hp = 6, mp = 2, atk = 2, def = 1, agi = 1 },
        learn = { [2] = "gust" },
    }
    Enc.zones("world", {
        meadow = { rate = 0.02, groups = { { "sod_mite" } } },
        forest = {
            rate = 0.03,
            groups = { { "bramble_hare" },
                { "sod_mite", "sod_mite" } },
            weights = { 2, 1 },
        },
    })
    Turn.defaults = { music = SONGS.battle,
        fanfare = SONGS.fanfare }
    Action.define{
        stick = { cooldown = 0.35, arc = { len = 14, wid = 18 },
            charge = { time = 0.5, mult = 2 } },
    }
    Script.loader = Game.loadMap
    registerStory()
    Game.loadMap("world", 9, 9)
    Music.play(SONGS.field)
    G.field = { update = Game.update, draw = Draw.frame }
end

function Game.update(dt)
    G.t = G.t + dt
    local p = G.player
    Act.walk(p, Input.mx, Input.my, dt)
    Act.updateAll(dt)
    Action.update(dt, Input.aHeld, p) -- field combat (A = charge)
    Enc.update(dt, p)              -- roamer chase/contact (engine)
    for i = 1, #G.npcs do -- edge-triggered touch counting
        local n = G.npcs[i]
        local touch = math.abs(n.x - p.x) < (n.hw + p.hw)
            and math.abs(n.y - p.y) < (n.hh + p.hh)
        if touch and not n.touching then
            Harness.count("npcTouches")
        end
        n.touching = touch
    end
    Cam.update(dt)
    Cam.follow(p.x, p.y, dt)
    if Input.a then
        Script.interact(p)
    elseif Input.b then
        UI.menu()
    end
end

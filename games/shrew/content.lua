-- Shrew content: the eight items, Pip's four spells (+ foe casts),
-- the five-strong bestiary (procedural DQ front-view portraits,
-- parametric w,h — 48x48 in the scene), each foe's GRAMS yield
-- (dinner!), and the per-zone encounter tables. Tuning table lives
-- in config.lua's header.

local gfx = playdate.graphics

Content = {}

-- ---- items (8) ------------------------------------------------------------

Content.ITEMS = {
    herb = { name = "Herb", kind = "heal", power = 12, price = 6,
        target = "one" },
    antidote = { name = "Antidote", kind = "cure", price = 5 },
    seed_cake = { name = "Seed Cake", kind = "heal", power = 30,
        price = 20, target = "one" },
    oar = { name = "Oar", kind = "key", price = 2 },
    brass_key = { name = "Brass Key", kind = "key", price = 2 },
    thorn_pin = { name = "Thorn Pin", kind = "weapon", power = 4,
        price = 14 },
    bark_vest = { name = "Bark Vest", kind = "armor", power = 2,
        price = 12 },
    moss_cloak = { name = "Moss Cloak", kind = "armor", power = 4,
        price = 30 },
}

-- ---- skills (Pip learns at LV 1/2/3/4; gust/tremor are foe casts) ---------

Content.SKILLS = {
    squeak = { name = "Squeak", mp = 2, power = 8, kind = "dmg",
        target = "one", element = "sound" },
    nibble = { name = "Nibble", mp = 3, power = 7, kind = "dmg",
        target = "one", drain = 0.25 },
    curl = { name = "Curl", mp = 2, kind = "buff", target = "self" },
    mend = { name = "Mend", mp = 3, power = 16, kind = "heal",
        target = "self" },
    gust = { name = "Gust", mp = 2, power = 7, kind = "dmg",
        target = "one" },
    tremor = { name = "Tremor", mp = 4, power = 13, kind = "dmg",
        target = "one" },
}

-- ---- portraits (dark bodies, white eye pixels — house palette) ----------

local function eyes(w, h, lx, rx, ey)
    gfx.setColor(gfx.kColorWhite)
    local r = math.max(1, w * 0.05)
    gfx.fillCircleAtPoint(w * lx, h * ey, r)
    if rx then gfx.fillCircleAtPoint(w * rx, h * ey, r) end
end

local function aphidArt(w, h)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillEllipseInRect(w * 0.15, h * 0.3, w * 0.7, h * 0.6)
    gfx.drawLine(w * 0.35, h * 0.32, w * 0.2, h * 0.08)
    gfx.drawLine(w * 0.65, h * 0.32, w * 0.8, h * 0.08)
    gfx.drawLine(w * 0.3, h * 0.88, w * 0.2, h * 0.98)
    gfx.drawLine(w * 0.7, h * 0.88, w * 0.8, h * 0.98)
    eyes(w, h, 0.38, 0.62, 0.55)
end

local function weevilArt(w, h)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillEllipseInRect(w * 0.1, h * 0.35, w * 0.8, h * 0.55)
    gfx.fillEllipseInRect(w * 0.35, h * 0.15, w * 0.3, h * 0.3)
    gfx.fillRect(w * 0.47, h * 0.05, w * 0.06, h * 0.2)
    gfx.setColor(gfx.kColorWhite) -- shell seam
    gfx.drawLine(w * 0.5, h * 0.4, w * 0.5, h * 0.85)
    eyes(w, h, 0.42, 0.58, 0.28)
end

local function midgeArt(w, h)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillTriangle(w * 0.1, h * 0.25, w * 0.45, h * 0.5,
        w * 0.12, h * 0.6)
    gfx.fillTriangle(w * 0.9, h * 0.25, w * 0.55, h * 0.5,
        w * 0.88, h * 0.6)
    gfx.fillEllipseInRect(w * 0.35, h * 0.35, w * 0.3, h * 0.5)
    gfx.fillCircleAtPoint(w * 0.5, h * 0.3, w * 0.12)
    eyes(w, h, 0.45, 0.55, 0.28)
end

local function tickArt(w, h)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillEllipseInRect(w * 0.15, h * 0.2, w * 0.7, h * 0.7)
    for i = 0, 2 do
        local yy = h * (0.35 + i * 0.2)
        gfx.drawLine(w * 0.17, yy, w * 0.02, yy + h * 0.1)
        gfx.drawLine(w * 0.83, yy, w * 0.98, yy + h * 0.1)
    end
    gfx.fillEllipseInRect(w * 0.4, h * 0.08, w * 0.2, h * 0.18)
    eyes(w, h, 0.46, 0.54, 0.14)
end

local function tyrantArt(w, h)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillEllipseInRect(w * 0.08, h * 0.15, w * 0.84, h * 0.8)
    -- digging claws
    gfx.fillTriangle(w * 0.1, h * 0.6, w * 0.02, h * 0.95,
        w * 0.28, h * 0.85)
    gfx.fillTriangle(w * 0.9, h * 0.6, w * 0.98, h * 0.95,
        w * 0.72, h * 0.85)
    gfx.setColor(gfx.kColorWhite)
    -- star nose
    gfx.fillCircleAtPoint(w * 0.5, h * 0.5, w * 0.08)
    gfx.drawLine(w * 0.5, h * 0.36, w * 0.5, h * 0.64)
    gfx.drawLine(w * 0.36, h * 0.5, w * 0.64, h * 0.5)
    gfx.drawLine(w * 0.4, h * 0.4, w * 0.6, h * 0.6)
    gfx.drawLine(w * 0.6, h * 0.4, w * 0.4, h * 0.6)
    -- claw seams
    gfx.drawLine(w * 0.08, h * 0.75, w * 0.2, h * 0.78)
    gfx.drawLine(w * 0.92, h * 0.75, w * 0.8, h * 0.78)
    eyes(w, h, 0.34, 0.66, 0.3)
end

-- ---- the bestiary (grams = dinner yield, the quest currency) --------------

Content.BESTIARY = {
    aphid = { name = "Aphid Grunt", hp = 8, atk = 5, def = 2,
        agi = 3, xp = 6, gold = 3, ai = "basic", artFn = aphidArt,
        grams = 0.5, elems = { sound = 1.2 },
        drop = { item = "herb", chance = 0.25 } },
    weevil = { name = "Weevil Guard", hp = 12, atk = 6, def = 6,
        agi = 2, xp = 10, gold = 5, ai = "basic", artFn = weevilArt,
        grams = 1 },
    midge = { name = "Marsh Midge", hp = 9, atk = 4, def = 2,
        agi = 5, mp = 6, skills = { "gust" }, ai = "caster",
        xp = 9, gold = 4, artFn = midgeArt, grams = 0.5,
        elems = { sound = 1.5 } },
    tick = { name = "Tick", hp = 12, atk = 5, def = 3, agi = 4,
        ai = "sly", xp = 12, gold = 6, artFn = tickArt, grams = 1,
        drop = { item = "antidote", chance = 0.2 } },
    mole_tyrant = { name = "Mole Tyrant", hp = 70, atk = 13,
        def = 10, agi = 5, mp = 24, skills = { "tremor" },
        ai = "boss", xp = 60, gold = 30, artFn = tyrantArt,
        grams = 5 },
}

-- ---- encounter zones ------------------------------------------------------

Content.ZONES = {
    forest = {
        rate = C.ENC_RATE,
        groups = { { "aphid" }, { "aphid", "aphid" },
            { "weevil" } },
        weights = { 3, 2, 2 },
    },
    marsh = {
        rate = C.ENC_RATE,
        groups = { { "midge" }, { "tick" }, { "midge", "tick" },
            { "weevil", "aphid" } },
        weights = { 3, 2, 2, 1 },
    },
}

-- ---- Pip ------------------------------------------------------------------

Content.PIP = {
    id = "pip", name = "Pip", lvl = 1, hp = 24, mp = 8,
    atk = 7, def = 5, agi = 5, skills = { "squeak" },
    growth = { hp = 7, mp = 3, atk = 2, def = 2, agi = 1 },
    learn = { [2] = "nibble", [3] = "curl", [4] = "mend" },
}

-- the town shop's six-line stock
Content.STOCK = {
    { item = "herb", price = 6 },
    { item = "antidote", price = 5 },
    { item = "seed_cake", price = 20 },
    { item = "thorn_pin", price = 14 },
    { item = "bark_vest", price = 12 },
    { item = "moss_cloak", price = 30 },
}

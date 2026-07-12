-- Stoat content: the data the engine turns into a game. Rigs
-- (palette rules: WHITE Ermine with a black outline and the ermine
-- signature black tail tip; dark rats with a white eye pixel),
-- parametric bestiary art (one rat base fn, per-variant dressing —
-- lturn would draw them 48x48, laction draws 16x16, boss overrides
-- go bigger), the ITEMS/SKILLS/BESTIARY registries, the weapon arcs
-- (tailwhip's 180-degree sweep reads as a short, very WIDE arc;
-- pounce holds the dash-lunge numbers game.lua throws), per-zone
-- spawn beds, and the five songs.

local gfx = playdate.graphics

Content = {}

-- ---- rigs ------------------------------------------------------------

function Content.ermineArt(dir, frame)
    local o = (frame == 1) and 0 or 1
    gfx.setColor(gfx.kColorBlack) -- the tail: TIP IS BLACK
    if dir == Act.LEFT then
        gfx.fillRect(12, 12 - o, 4, 3)
    elseif dir == Act.RIGHT then
        gfx.fillRect(0, 12 - o, 4, 3)
    else
        gfx.fillRect(12, 11 + o, 3, 5)
    end
    gfx.setColor(gfx.kColorBlack) -- outline
    gfx.fillEllipseInRect(4, 0, 8, 9)
    gfx.fillEllipseInRect(3, 7, 10, 11)
    gfx.setColor(gfx.kColorWhite) -- slim white winter coat
    gfx.fillEllipseInRect(5, 1, 6, 7)
    gfx.fillEllipseInRect(4, 8, 8, 9)
    gfx.setColor(gfx.kColorBlack) -- eyes/nose by facing
    if dir == Act.DOWN then
        gfx.fillRect(6, 3, 1, 2)
        gfx.fillRect(9, 3, 1, 2)
    elseif dir == Act.LEFT then
        gfx.fillRect(5, 3, 1, 2)
        gfx.drawPixel(4, 5)
    elseif dir == Act.RIGHT then
        gfx.fillRect(10, 3, 1, 2)
        gfx.drawPixel(11, 5)
    end -- UP: back of head
    gfx.setColor(gfx.kColorBlack) -- legs alternate
    gfx.fillRect(5 + o * 2, 17, 2, 3)
    gfx.fillRect(9 - o * 2, 17, 2, 3)
end

function Content.elderArt(dir, frame)
    Content.ermineArt(dir, frame)
    gfx.setColor(gfx.kColorBlack) -- age flecks on the coat
    gfx.drawPixel(7, 10)
    gfx.drawPixel(9, 12)
    gfx.drawPixel(6, 13)
end

function Content.bedImg()
    local img = gfx.image.new(16, 12)
    gfx.pushContext(img)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillEllipseInRect(0, 1, 16, 11)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillEllipseInRect(2, 3, 12, 7) -- the moss hollow
    gfx.setColor(gfx.kColorBlack)
    gfx.drawPixel(5, 6)
    gfx.drawPixel(9, 5)
    gfx.drawPixel(7, 8)
    gfx.popContext()
    return img
end

-- ---- rats (dark bodies, one white eye pixel) --------------------------

local function ratBase(w, h)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillEllipseInRect(w * 0.1, h * 0.32, w * 0.62, h * 0.52)
    gfx.fillEllipseInRect(w * 0.54, h * 0.36, w * 0.36, h * 0.36)
    gfx.fillCircleAtPoint(w * 0.62, h * 0.3,
        math.max(1, w * 0.09)) -- ear
    gfx.drawLine(w * 0.12, h * 0.6, 0, h * 0.88) -- tail
    gfx.setColor(gfx.kColorWhite) -- the eye
    gfx.fillRect(w * 0.72, h * 0.46, math.max(1, w * 0.06),
        math.max(1, h * 0.06))
end

local function pupArt(w, h)
    ratBase(w * 0.78, h * 0.78)
end

local function spearArt(w, h)
    ratBase(w, h)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawLine(w * 0.3, h * 0.9, w * 0.95, h * 0.12) -- the spear
end

local function slingerArt(w, h)
    ratBase(w, h)
    gfx.setColor(gfx.kColorWhite) -- bulging cheek pouch
    gfx.drawCircleAtPoint(w * 0.8, h * 0.6, math.max(1, w * 0.1))
end

local function fatArt(w, h)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillEllipseInRect(w * 0.04, h * 0.2, w * 0.78, h * 0.7)
    gfx.fillEllipseInRect(w * 0.58, h * 0.32, w * 0.38, h * 0.4)
    gfx.drawLine(w * 0.06, h * 0.62, 0, h * 0.92)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(w * 0.76, h * 0.44, math.max(1, w * 0.07),
        math.max(1, h * 0.07))
    gfx.drawLine(w * 0.2, h * 0.56, w * 0.44, h * 0.56) -- belly fold
end

local function eliteArt(w, h)
    spearArt(w, h)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawLine(w * 0.2, h * 0.5, w * 0.46, h * 0.5) -- war stripe
end

local function kingArt(w, h)
    ratBase(w, h)
    gfx.setColor(gfx.kColorWhite) -- the crown
    local cx, cy = w * 0.68, h * 0.26
    gfx.fillTriangle(cx - w * 0.14, cy, cx + w * 0.14, cy,
        cx, cy - h * 0.2)
    gfx.fillTriangle(cx - w * 0.22, cy, cx - w * 0.06, cy,
        cx - w * 0.18, cy - h * 0.14)
    gfx.fillTriangle(cx + w * 0.06, cy, cx + w * 0.22, cy,
        cx + w * 0.18, cy - h * 0.14)
end

-- ---- registries --------------------------------------------------------

Content.ITEMS = {
    herb = { name = "Herb", kind = "heal", power = 15, price = 4 },
    dried_vole = { name = "Dried Vole", kind = "heal", power = 25,
        price = 8 },
    winterberry = { name = "Winterberry", kind = "heal", power = 45,
        price = 12 },
    whisker_charm = { name = "Whisker Charm", kind = "charm",
        price = 20 },
    winter_coat = { name = "Winter Coat", kind = "armor", power = 2,
        price = 15 },
    bramble_coat = { name = "Bramble Coat", kind = "armor",
        power = 5, price = 40 },
    bite = { name = "Bite", kind = "weapon", power = 2, price = 0 },
    tailwhip = { name = "Tailwhip", kind = "weapon", power = 4,
        price = 0 },
}

Content.SKILLS = {
    growl = { name = "Growl", mp = C.GROWL_MP, power = 0,
        kind = "field", target = "all" },
    groom = { name = "Groom", mp = C.GROOM_MP, power = 0,
        kind = "field", target = "self" },
}

Content.WEAPONS = {
    bite = { cooldown = 0.3, arc = { len = 13, wid = 16 },
        charge = { time = 0.5, mult = 2 } },
    tailwhip = { cooldown = 0.65, arc = { len = 10, wid = 44 },
        charge = { time = 0.8, mult = 2.4 } },
    pounce = { cooldown = C.POUNCE_COOL,
        arc = { len = 22, wid = 18 } },
}

Content.BESTIARY = {
    rat_pup = { name = "Rat Pup", hp = 10, atk = 5, def = 2,
        agi = 3, xp = 4, gold = 2, fspeed = 46, artFn = pupArt,
        drop = { item = "herb", chance = 0.35 } },
    rat_spear = { name = "Rat Spear", hp = 16, atk = 7, def = 3,
        agi = 4, xp = 7, gold = 4, fspeed = 40, artFn = spearArt,
        drop = { item = "herb", chance = 0.25 } },
    rat_slinger = { name = "Rat Slinger", hp = 12, atk = 6, def = 2,
        agi = 5, xp = 9, gold = 5, fspeed = 42, artFn = slingerArt,
        drop = { item = "winterberry", chance = 0.25 } },
    fat_rat = { name = "Fat Rat", hp = 70, atk = 8, def = 4,
        agi = 3, xp = 30, gold = 25, fspeed = 52, artFn = fatArt,
        drop = { item = "winterberry", chance = 1 } },
    spear_elite = { name = "Spear Elite", hp = 38, atk = 8, def = 4,
        agi = 5, xp = 22, gold = 15, fspeed = 46, artFn = eliteArt,
        drop = { item = "dried_vole", chance = 0.6 } },
    rat_king = { name = "Rat King", hp = 90, atk = 9, def = 5,
        agi = 5, xp = 45, gold = 40, fspeed = 46, artFn = kingArt },
    rat_king2 = { name = "Rat King", hp = 90, atk = 11, def = 5,
        agi = 6, xp = 55, gold = 60, fspeed = 58, artFn = kingArt },
}

-- per-zone spawn beds {id, tx, ty}, all inside the open valley band
Content.SPAWNS = {
    meadow = {
        { "rat_pup", 14, 27 }, { "rat_pup", 20, 33 },
        { "rat_pup", 30, 27 }, { "rat_spear", 26, 31 },
        { "rat_spear", 38, 33 }, { "rat_pup", 42, 28 },
    },
    thicket = {
        { "rat_pup", 54, 27 }, { "rat_spear", 60, 33 },
        { "rat_spear", 70, 28 }, { "rat_slinger", 76, 32 },
        { "rat_pup", 84, 27 }, { "rat_spear", 90, 33 },
    },
    warren = {
        { "rat_spear", 102, 28 }, { "rat_slinger", 108, 33 },
        { "rat_pup", 114, 27 }, { "rat_slinger", 120, 32 },
        { "rat_spear", 126, 28 }, { "rat_pup", 112, 31 },
    },
}

-- ---- songs -------------------------------------------------------------
-- meadow: bright A-B; thicket: suspense A-A-B; warren: low A-B with
-- a pad drone; king: driving two-pattern battle stinger; fanfare:
-- one pass, then the interrupted field song resumes mid-phrase.

Content.SONGS = {
    meadow = {
        tempo = 112,
        patterns = {
            A = {
                bass = { 36, 0, 0, 0, 43, 0, 36, 0,
                    41, 0, 0, 0, 43, 0, 0, 0 },
                lead = { 60, 0, 62, 64, 67, 0, 64, 0,
                    60, 0, 62, 64, 69, 67, 64, 0 },
                hat = { 1, 0, 0, 0, 1, 0, 0, 0,
                    1, 0, 0, 0, 1, 0, 1, 0 },
            },
            B = {
                bass = { 41, 0, 0, 0, 45, 0, 41, 0,
                    43, 0, 0, 0, 36, 0, 0, 0 },
                lead = { 65, 0, 67, 69, 72, 0, 69, 0,
                    67, 0, 65, 64, 62, 0, 64, 0 },
                hat = { 1, 0, 0, 0, 1, 0, 0, 0,
                    1, 0, 0, 0, 1, 0, 1, 0 },
            },
        },
        order = { "A", "B" },
    },
    thicket = {
        tempo = 92,
        patterns = {
            A = {
                bass = { 33, 0, 0, 33, 0, 0, 32, 0,
                    33, 0, 0, 33, 0, 0, 31, 0 },
                pad = { 45, 0, 0, 0, 0, 0, 0, 0,
                    44, 0, 0, 0, 0, 0, 0, 0 },
                lead = { 0, 0, 69, 0, 0, 68, 0, 0,
                    0, 0, 69, 0, 71, 0, 68, 0 },
                hat = { 1, 0, 0, 0, 0, 0, 1, 0,
                    1, 0, 0, 0, 0, 0, 1, 0 },
            },
            B = {
                bass = { 36, 0, 0, 36, 0, 0, 35, 0,
                    33, 0, 0, 33, 0, 0, 32, 0 },
                pad = { 48, 0, 0, 0, 0, 0, 0, 0,
                    45, 0, 0, 0, 0, 0, 0, 0 },
                lead = { 0, 0, 72, 0, 71, 0, 69, 0,
                    0, 0, 68, 0, 69, 0, 71, 0 },
                hat = { 1, 0, 0, 0, 1, 0, 1, 0,
                    1, 0, 0, 0, 1, 0, 1, 0 },
            },
        },
        order = { "A", "A", "B" },
    },
    warren = {
        tempo = 80,
        patterns = {
            A = {
                bass = { 26, 0, 0, 0, 0, 0, 26, 0,
                    24, 0, 0, 0, 0, 0, 0, 0 },
                pad = { 38, 0, 0, 0, 0, 0, 0, 0,
                    36, 0, 0, 0, 0, 0, 0, 0 },
                lead = { 0, 0, 0, 0, 62, 0, 0, 0,
                    0, 0, 0, 0, 0, 60, 0, 0 },
                hat = { 0, 0, 0, 0, 1, 0, 0, 0,
                    0, 0, 0, 0, 1, 0, 0, 0 },
            },
            B = {
                bass = { 29, 0, 0, 0, 0, 0, 29, 0,
                    26, 0, 0, 0, 0, 0, 24, 0 },
                pad = { 41, 0, 0, 0, 0, 0, 0, 0,
                    38, 0, 0, 0, 0, 0, 0, 0 },
                lead = { 0, 0, 0, 0, 65, 0, 62, 0,
                    0, 0, 0, 0, 60, 0, 0, 0 },
                hat = { 0, 0, 0, 0, 1, 0, 0, 0,
                    0, 0, 1, 0, 1, 0, 0, 0 },
            },
        },
        order = { "A", "B" },
    },
    king = {
        tempo = 150,
        patterns = {
            A = {
                bass = { 31, 31, 0, 31, 31, 0, 31, 0,
                    29, 29, 0, 29, 29, 0, 31, 0 },
                lead = { 67, 0, 0, 66, 67, 0, 70, 0,
                    65, 0, 0, 64, 65, 0, 67, 0 },
                hat = { 1, 0, 1, 0, 1, 0, 1, 1,
                    1, 0, 1, 0, 1, 1, 1, 0 },
            },
            B = {
                bass = { 34, 34, 0, 34, 34, 0, 34, 0,
                    31, 31, 0, 31, 29, 0, 27, 0 },
                lead = { 70, 0, 0, 69, 70, 0, 72, 0,
                    67, 0, 65, 0, 63, 0, 65, 0 },
                hat = { 1, 0, 1, 0, 1, 0, 1, 1,
                    1, 0, 1, 0, 1, 1, 1, 1 },
            },
        },
        order = { "A", "B" },
    },
    fanfare = {
        tempo = 116,
        patterns = {
            A = {
                bass = { 48, 0, 0, 0, 48, 0, 0, 0,
                    43, 0, 0, 0, 48, 0, 0, 0 },
                lead = { 72, 0, 72, 0, 72, 0, 76, 0,
                    79, 0, 0, 76, 79, 0, 0, 0 },
            },
        },
        order = { "A" },
    },
}

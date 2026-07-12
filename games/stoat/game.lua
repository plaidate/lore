-- Stoat simulation: Secret of Mana grammar over the Lore engine.
-- The engine owns swings/charge/foe AI/drops (laction on the shared
-- lparty sheet); this file owns the GAME-layer moves, all built on
-- public seams with zero engine changes:
--   * POUNCE — the B-dash: a 3-tile lunge whose hitbox (numbers in
--     Action.define's "pounce" entry) is swept along the dash by
--     hand; anything it drops to 0 hp is reaped by Action.update's
--     own kill sweep the same frame.
--   * SLINGERS — spawned with aggro 0 so the engine keeps them in
--     the idle drift; the game steers that drift (keep-range) and
--     spits pooled projectiles with a hand-rolled hit test.
--   * GROWL/GROOM — menu skills over the Action foes / the sheet.
--   * THE KING — two stacked Action.spawn stages: stage 1 summons
--     pups then spin-lunges below half; its death IS the mid-fight
--     parley (Script.run freezes laction by construction) and
--     stage 2 rises desperate. No overkill can skip the beat.
--   * DEATH (the DQ rule) — Action.onDown is overridden: half your
--     gold and a blackout back to the den moss-bed, not the
--     engine's default full-restore-in-place.

local gfx = playdate.graphics

Game = {}

-- ---- kill accounting ---------------------------------------------------

local function creditKill(zone)
    Harness.count("kills")
    local n = State.bump("kills_" .. zone)
    Harness.set("k_" .. zone, n)
end

-- ---- captains ----------------------------------------------------------

local function bigImg(id, s)
    local img = gfx.image.new(s, s)
    gfx.pushContext(img)
    Party.bestiary[id].artFn(s, s)
    gfx.popContext()
    return img
end

local function onFat()
    creditKill("meadow")
    State.set("fat_dead")
    Maps.openGate(1)
    Kit.toast("The bramble wall withers open!")
    Sfx.gate()
    Music.stinger(Content.SONGS.fanfare, true)
    G.bossBits()
    G.boss = nil
end

local function onTwin()
    creditKill("thicket")
    if State.bump("twin_down") < 2 then return end
    State.set("twins_dead")
    State.set("tailwhip")
    State.add("bramble_coat", 1)
    Maps.openGate(2)
    Kit.toast("Learned Tailwhip! Got the Bramble Coat!")
    Sfx.gate()
    Music.stinger(Content.SONGS.fanfare, true)
    G.bossBits()
end

local onKing1, onKing2 -- forward

function Game.spawnKing(stage)
    local e = Action.spawn{
        id = (stage == 1) and "rat_king" or "rat_king2",
        x = Map.cx(C.KING_X), y = Map.cy(C.KING_Y), aggro = 110,
        onDeath = (stage == 1) and onKing1 or onKing2,
    }
    e.img = G.kingImg
    e.hw, e.hh = 10, 9
    G.kingT, G.kingT2 = 0, 0
    return e
end

onKing1 = function()
    creditKill("warren")
    State.set("king1_dead")
    G.king = Game.spawnKing(2) -- rises under the parley, frozen
    if not Script.active then Script.run(Story.parley) end
end

onKing2 = function()
    creditKill("warren")
    State.set("king_dead")
    Harness.set("kingDown", 1)
    G.king = nil
    G.bossBits()
    Music.stinger(Content.SONGS.fanfare, true)
    G.pendEnding = true
end

-- quiet = respawning after a reload, skip the fanfare toast
local function spawnCaptain(z, quiet)
    if z.name == "meadow" then
        G.boss = Action.spawn{
            id = "fat_rat", x = Map.cx(C.FAT_X), y = Map.cy(C.FAT_Y),
            aggro = 120, onDeath = onFat,
        }
        G.boss.img = G.fatImg
        G.boss.hw, G.boss.hh = 9, 8
    elseif z.name == "thicket" then
        State.counters.twin_down = 0
        for k = 0, 1 do
            local e = Action.spawn{
                id = "spear_elite", x = Map.cx(C.TWIN_X + k * 3),
                y = Map.cy(C.TWIN_Y + k), aggro = 110,
                onDeath = onTwin,
            }
            e.img = G.eliteImg
            e.hw, e.hh = 7, 7
        end
    else
        local stage = State.has("king1_dead") and 2 or 1
        G.king = Game.spawnKing(stage)
    end
    if not quiet then Kit.toast("A rat captain emerges!") end
end

local function checkQuota()
    for i = 1, 3 do
        local z = G.ZONES[i]
        if not State.has(z.name .. "_boss")
            and State.counterOf("kills_" .. z.name) >= C.QUOTA then
            State.set(z.name .. "_boss")
            spawnCaptain(z)
        end
    end
end

-- ---- the map loader (also Script.loader, so warp() lands here) ---------

local function spawnRat(zone, id, tx, ty)
    Action.spawn{
        id = id, x = Map.cx(tx), y = Map.cy(ty),
        aggro = (id == "rat_slinger") and 0 or 84,
        respawn = C.RESPAWN,
        onDeath = function() creditKill(zone) end,
    }
end

function Game.loadMap(name, tx, ty)
    G.mapName = name
    Map.load{
        rows = (name == "den") and Maps.den or Maps.world(),
        legend = Maps.legend,
    }
    Act.reset()
    Action.reset()
    G.rig = G.rig or Act.rig(Content.ermineArt)
    G.erig = G.erig or Act.rig(Content.elderArt)
    G.bedImg = G.bedImg or Content.bedImg()
    G.fatImg = G.fatImg or bigImg("fat_rat", 28)
    G.eliteImg = G.eliteImg or bigImg("spear_elite", 22)
    G.kingImg = G.kingImg or bigImg("rat_king", 32)
    G.player = Act.new{
        kind = "player", x = Map.cx(tx), y = Map.cy(ty),
        hw = 5, hh = 5, speed = C.PLAYER_SPEED, sprite = G.rig,
        onTrigger = function(id, ttx, tty)
            Script.trigger(id, ttx, tty)
        end,
    }
    G.dashT, G.pounceCool, G.hurtIT, G.charmT = 0, 0, 0, 0
    for i = 1, 6 do G.spits[i].t = 0 end
    G.boss, G.king, G.kingAdds, G.kingMusic = nil, nil, 0, false
    if name == "world" then
        if State.has("fat_dead") then Maps.openGate(1) end
        if State.has("twins_dead") then Maps.openGate(2) end
        for i = 1, 3 do
            local z = G.ZONES[i]
            local beds = Content.SPAWNS[z.name]
            for j = 1, #beds do
                local s = beds[j]
                spawnRat(z.name, s[1], s[2], s[3])
            end
            if State.has(z.name .. "_boss")
                and not State.has(z.flag) then
                spawnCaptain(z, true)
            end
        end
    else
        Act.new{ kind = "elder", x = Map.cx(C.ELDER_X),
            y = Map.cy(C.ELDER_Y), hw = 5, hh = 5, sprite = G.erig }
        Act.new{ kind = "mossbed", x = Map.cx(C.BED_X),
            y = Map.cy(C.BED_Y), hw = 7, hh = 5, img = G.bedImg }
    end
    Action.arm(G.player, Action.weapon or "bite")
    Cam.reset()
    Cam.center(G.player.x, G.player.y)
    Script.followTarget = G.player
    G.curZone = nil -- force a music re-pick
end

-- ---- pounce: the B-dash ------------------------------------------------

local function tryPounce()
    if G.dashT > 0 or G.pounceCool > 0 then return end
    G.dashT = C.POUNCE_T
    G.pounceCool = C.POUNCE_COOL
    G.dashX = Act.DX[G.player.dir]
    G.dashY = Act.DY[G.player.dir]
    Harness.count("pounces")
    Sfx.pounce()
end

local function updDash(dt)
    G.dashT = G.dashT - dt
    local p = G.player
    Act.move(p, G.dashX * C.POUNCE_SPEED * dt,
        G.dashY * C.POUNCE_SPEED * dt)
    local w = Action.weapons.pounce.arc
    local m = Party.member(1)
    for i = 1, #Act.list do
        local e = Act.list[i]
        local f = e.fd
        if f and f.hp > 0 and f.iT <= 0 then
            local rx = (e.x - p.x) * G.dashX + (e.y - p.y) * G.dashY
            local cx = (e.y - p.y) * G.dashX - (e.x - p.x) * G.dashY
            if rx > -4 and rx < w.len
                and math.abs(cx) < w.wid * 0.5 + e.hw then
                local dmg, _, miss = Party.attack(Party.atkOf(m),
                    f.def, Party.agiOf(m), f.agi, false)
                if not miss then
                    dmg = math.floor(dmg * C.POUNCE_MULT)
                    f.hp = f.hp - dmg
                    f.iT = 0.3
                    f.st, f.t = "recover", 0.4
                    UI.popup(e.x, e.y - 16, "-" .. dmg)
                    Act.move(e, G.dashX * 12, G.dashY * 12)
                    Kit.shake(0.12)
                    Sfx.hit()
                end
            end
        end
    end
end

-- ---- slingers + spits (the game-layer projectile) ----------------------

local function spitAt(x, y, nx, ny)
    for i = 1, 6 do
        local s = G.spits[i]
        if s.t <= 0 then
            s.t = C.SPIT_LIFE
            s.x, s.y = x, y - 4
            s.vx, s.vy = nx * C.SPIT_SPEED, ny * C.SPIT_SPEED
            Sfx.spit()
            return
        end
    end
end

local function updSlingers(dt)
    local p = G.player
    for i = 1, #Act.list do
        local a = Act.list[i]
        local f = a.fd
        if f and f.id == "rat_slinger" and f.hp > 0 then
            local dx, dy = p.x - a.x, p.y - a.y
            local d2 = dx * dx + dy * dy
            if d2 < C.SPIT_NEAR * C.SPIT_NEAR then -- keep range
                f.wx, f.wy = -Util.sign(dx), -Util.sign(dy)
            elseif d2 > C.SPIT_FAR * C.SPIT_FAR then
                f.wx, f.wy = Util.sign(dx), Util.sign(dy)
            else
                f.wx, f.wy = 0, 0
            end
            f.spitT = (f.spitT or (1 + math.random())) - dt
            if f.spitT <= 0 and d2 < 170 * 170
                and G.charmT <= 0 then
                f.spitT = C.SPIT_COOL
                local d = math.max(1, math.sqrt(d2))
                spitAt(a.x, a.y, dx / d, dy / d)
            end
        end
    end
end

local function updSpits(dt)
    local p = G.player
    local m = Party.member(1)
    for i = 1, 6 do
        local s = G.spits[i]
        if s.t > 0 then
            s.t = s.t - dt
            s.x = s.x + s.vx * dt
            s.y = s.y + s.vy * dt
            local stx, sty = Map.tileAt(s.x, s.y)
            if math.abs(s.x - p.x) < p.hw + 3
                and math.abs(s.y - p.y) < p.hh + 3
                and G.hurtIT <= 0 and G.dashT <= 0 then
                s.t = 0 -- a pounce dash dodges spits
                G.hurtIT = C.HURT_IT
                local d = Party.bestiary.rat_slinger
                local dmg, _, miss = Party.attack(d.atk,
                    Party.defOf(m), d.agi, Party.agiOf(m),
                    m.status.guard ~= nil)
                if miss then
                    UI.popup(p.x, p.y - 18, "miss")
                else
                    m.hp = math.max(0, m.hp - dmg)
                    UI.popup(p.x, p.y - 18, "-" .. dmg)
                    Kit.shake(0.15)
                    Sfx.hurt()
                    if m.hp <= 0 then Action.onDown(m) end
                end
                Kit.burst(Action.parts, s.x, s.y, 5, 60)
            elseif s.t <= 0 or Map.solid(stx, sty) then
                s.t = 0
                Kit.burst(Action.parts, s.x, s.y, 4, 50)
            end
        end
    end
end

-- ---- the king controller ------------------------------------------------
-- Stage 1: summons pups ("spears summon" beat), spin-lunges below
-- half. Stage 2 (post-parley): desperate — faster, summons AND
-- forced lunges.

local function updKing(dt)
    local e = G.king
    if not e then return end
    local f = e.fd
    local p = G.player
    if not G.kingMusic
        and Util.dist2(e.x, e.y, p.x, p.y) < 150 * 150 then
        G.kingMusic = true
        Music.stinger(Content.SONGS.king)
        Kit.toast("The Rat King screeches!")
    end
    local stage2 = (f.id == "rat_king2")
    local spin = stage2 or f.hp <= f.maxhp * 0.5
    G.kingT = G.kingT + dt
    G.kingT2 = G.kingT2 + dt
    if (stage2 or not spin)
        and G.kingT >= (stage2 and 4.5 or 6) then
        G.kingT = 0
        if G.kingAdds < (stage2 and 3 or 2) then
            G.kingAdds = G.kingAdds + 1
            Action.spawn{
                id = "rat_pup",
                x = e.x + math.random(-24, 24),
                y = e.y + math.random(-20, 20), aggro = 200,
                onDeath = function()
                    G.kingAdds = G.kingAdds - 1
                    creditKill("warren")
                end,
            }
        end
    end
    if spin and G.kingT2 >= (stage2 and 1.6 or 2.2)
        and f.st == "chase" then
        G.kingT2 = 0
        f.st, f.t = "tel", 0.28 -- forced spin lunge
    end
end

-- whisker charm: chasing rats beyond arm's reach lose the scent
local function calmRats()
    local p = G.player
    for i = 1, #Act.list do
        local e = Act.list[i]
        local f = e.fd
        if f and f.st == "chase"
            and Util.dist2(e.x, e.y, p.x, p.y) > 40 * 40 then
            f.st = "idle"
            f.t = 0
        end
    end
end

-- ---- menu skills (Growl / Groom) ----------------------------------------

-- stagger + shove every rat within r px of the player
function Game.scare(r)
    local p = G.player
    for i = 1, #Act.list do
        local e = Act.list[i]
        local f = e.fd
        if f and f.hp > 0
            and Util.dist2(e.x, e.y, p.x, p.y) < r * r then
            f.st, f.t = "recover", 1.8
            local dx, dy = e.x - p.x, e.y - p.y
            local d = math.max(1, math.sqrt(dx * dx + dy * dy))
            Act.move(e, dx / d * 14, dy / d * 14)
            UI.popup(e.x, e.y - 16, "!")
        end
    end
end

function Game.cast(id)
    local m = Party.member(1)
    local sk = Party.skills[id]
    if m.mp < sk.mp then
        Kit.toast("Too winded.")
        return
    end
    m.mp = m.mp - sk.mp
    if id == "groom" then
        local amt = math.floor(m.maxhp * C.GROOM_FRAC)
        Party.heal(m, amt)
        UI.popup(G.player.x, G.player.y - 18, "+" .. amt)
        Kit.toast("You groom your winter coat.")
        Harness.count("grooms")
        Sfx.groom()
    else -- growl
        Game.scare(C.GROWL_R)
        Kit.toast("A shrill stoat war-cry!")
        Harness.count("growls")
        Sfx.growl()
    end
end

local function addMenuSections()
    UI.addMenuSection("Skills", function()
        local rows, ids = {}, {}
        local m = Party.member(1)
        for i = 1, #m.skills do
            local sk = Party.skills[m.skills[i]]
            rows[i] = sk.name .. "  " .. sk.mp .. "mp"
            ids[i] = m.skills[i]
        end
        UI.list{
            title = "Skills", tag = "skills", rows = rows,
            onA = function(i) Game.cast(ids[i]) end,
        }
    end)
    UI.addMenuSection("Equip", function()
        local rows, ids = {}, {}
        local function build()
            local m = Party.member(1)
            local n = 0
            local function put(id, on)
                n = n + 1
                ids[n] = id
                rows[n] = Party.items[id].name .. (on and " *" or "")
            end
            put("bite", Action.weapon == "bite")
            if State.has("tailwhip") then
                put("tailwhip", Action.weapon == "tailwhip")
            end
            put("winter_coat", m.equip.armor == "winter_coat")
            if State.count("bramble_coat") > 0 then
                put("bramble_coat",
                    m.equip.armor == "bramble_coat")
            end
            for i = #rows, n + 1, -1 do rows[i], ids[i] = nil, nil end
            return rows
        end
        build()
        UI.list{
            title = "Equip", tag = "equip", rows = rows,
            onA = function(i, st)
                local it = Party.items[ids[i]]
                if it.kind == "weapon" then
                    Action.arm(G.player, ids[i])
                else
                    Party.member(1).equip.armor = ids[i]
                end
                st.rebuild(build())
            end,
        }
    end)
end

-- ---- init ---------------------------------------------------------------

local gfxTitleLines = {
    "Winter coat on. Three fields to clear.",
    "d-pad move - A swing (hold: charge)",
    "B pounce (hold B: menu) - crank winds up",
    "Press A",
}

function Game.init()
    if Harness.enabled then State.wipe() end -- deterministic smoke
    if not State.load() then
        State.gold = C.GOLD_START
    end
    Party.defineItems(Content.ITEMS)
    Party.defineSkills(Content.SKILLS)
    Party.defineBestiary(Content.BESTIARY)
    local m = Party.add{
        id = "ermine", name = "Ermine", lvl = 1,
        hp = 30, mp = 8, atk = 7, def = 4, agi = 6,
        skills = { "growl", "groom" },
        growth = { hp = 8, mp = 2, atk = 2, def = 1, agi = 1 },
    }
    if not m.equip.armor then
        State.add("winter_coat", 1)
        m.equip.armor = "winter_coat"
    end
    Action.define(Content.WEAPONS)
    -- the DQ death rule replaces the engine's restore-in-place
    Action.onDown = function(mm)
        mm.hp = 1 -- hold on until the blackout script lands
        G.pendDeath = true
    end
    local baseUse = UI.useItem
    UI.useItem = function(id)
        if id == "whisker_charm" then
            Game.scare(100)
            G.charmT = 15
            Kit.toast("Your whiskers bristle; rats shy away.")
            return true
        end
        return baseUse(id)
    end
    addMenuSections()
    Script.loader = Game.loadMap
    Story.register()
    G.title = {
        update = function(dt)
            if Input.a then Game.begin() end
        end,
        draw = function()
            Gfx.fill(0, 0, 400, 240, 6)
            Kit.title("STOAT", gfxTitleLines)
        end,
    }
    G.field = { update = Game.update, draw = Draw.frame }
end

function Game.begin()
    if G.begun then return end
    G.begun = true
    Kit.pop() -- the title
    Kit.push(G.field)
    Game.loadMap("den", C.DEN_IN_X, C.DEN_IN_Y)
    if not State.has("intro") then Script.run(Story.intro) end
end

-- ---- music + pickup ping -------------------------------------------------

local function updMusic()
    if G.kingMusic and not State.has("king_dead") then return end
    local z = (G.mapName == "den") and "meadow"
        or G.zoneAt(G.player.cellX)
    if z ~= G.curZone then
        G.curZone = z
        Music.play(Content.SONGS[z])
    end
end

local invN = -1

local function pickupPing()
    local n = State.count("herb") + State.count("winterberry")
        + State.count("dried_vole")
    if invN >= 0 and n > invN then Sfx.pickup() end
    invN = n
end

-- ---- the field update 

function Game.update(dt)
    G.t = G.t + dt
    G.frames = G.frames + 1
    if G.pendDeath and not Script.active then
        G.pendDeath = false
        Harness.count("deaths")
        State.gold = math.floor(State.gold / 2)
        Script.run(Story.death)
        return
    end
    if G.pendEnding and not Script.active then
        G.pendEnding = false
        Script.run(Story.ending)
        return
    end
    local p = G.player
    if G.pounceCool > 0 then G.pounceCool = G.pounceCool - dt end
    if G.hurtIT > 0 then G.hurtIT = G.hurtIT - dt end
    if G.charmT > 0 then G.charmT = G.charmT - dt end
    if Input.pounce then tryPounce() end
    if G.dashT > 0 then -- the dash owns the player while it runs
        updDash(dt)
    else
        Act.walk(p, Input.mx, Input.my, dt)
    end
    Act.updateAll(dt)
    p = G.player -- a step-trigger warp may have rebuilt the world
    -- full-charge counter (sample before Action.update resets it)
    if G.held and not Input.aHeld and Action.charge01 >= 0.9 then
        Harness.count("charges")
    end
    G.held = Input.aHeld
    Action.update(dt, Input.aHeld, p)
    if G.mapName == "world" then
        updSlingers(dt)
        updSpits(dt)
        updKing(dt)
        checkQuota()
        if G.charmT > 0 then calmRats() end
    end
    updMusic()
    pickupPing()
    Cam.update(dt)
    Cam.follow(p.x, p.y, dt)
    if Input.menu then
        UI.menu()
    elseif Input.a then
        Script.interact(p) -- den only; a miss costs nothing
    end
end

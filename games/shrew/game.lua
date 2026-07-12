-- Shrew simulation: boot (title -> intro -> free play), the map
-- loader (world/town/burrow floors, chest + NPC + Tyrant spawns,
-- persistent Brass-Key door), the battle seam (grams-on-win, the
-- boss's own stinger, the DQ death flow), gear-equips-on-Use, and
-- the grid-step field update (classic DQ movement via Act.stepTo).

local gfx = playdate.graphics

Game = {}

-- ---- rigs + props (built once) --------------------------------------------

local function pipArt(dir, frame)
    gfx.setColor(gfx.kColorBlack) -- outline
    gfx.fillEllipseInRect(3, 2, 10, 9)
    gfx.fillRect(2, 8, 12, 9)
    gfx.setColor(gfx.kColorWhite) -- white shrew
    gfx.fillEllipseInRect(4, 3, 8, 7)
    gfx.fillRect(3, 9, 10, 7)
    gfx.setColor(gfx.kColorBlack)
    if dir == Act.DOWN then
        gfx.fillRect(6, 5, 1, 2)
        gfx.fillRect(9, 5, 1, 2)
        gfx.drawPixel(7, 8) -- snout
    elseif dir == Act.LEFT then
        gfx.fillRect(5, 5, 1, 2)
        gfx.drawLine(2, 7, 4, 7) -- pointy snout
    elseif dir == Act.RIGHT then
        gfx.fillRect(10, 5, 1, 2)
        gfx.drawLine(11, 7, 13, 7)
    end
    local o = (frame == 1) and 0 or 2
    gfx.fillRect(4 + o, 16, 3, 3)
    gfx.fillRect(9 - o, 16, 3, 3)
end

local function npcArt(dir, frame)
    gfx.setColor(gfx.kColorBlack) -- dark vole
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

local function chestImg(open)
    local img = gfx.image.new(14, 12)
    gfx.pushContext(img)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRoundRect(0, 2, 14, 10, 2)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRoundRect(0, 2, 14, 10, 2)
    if open then
        gfx.fillRect(2, 4, 10, 3)
    else
        gfx.drawLine(1, 6, 12, 6)
        gfx.drawPixel(6, 8)
    end
    gfx.popContext()
    return img
end

local function tyrantImg()
    local img = gfx.image.new(22, 22)
    gfx.pushContext(img)
    Content.BESTIARY.mole_tyrant.artFn(22, 22)
    gfx.popContext()
    return img
end

-- ---- the map loader (also Script.loader, so warp() lands here) ------------

function Game.loadMap(name, tx, ty)
    G.mapName = name
    Map.load(Maps.def(name))
    Act.reset()
    Enc.enter(name)
    if name == "burrow2" and hasflag("burrow_door") then
        Map.set(C.B2_DOOR[1], C.B2_DOOR[2], ".") -- stays open
    end
    G.prig = G.prig or Act.rig(pipArt)
    G.nrig = G.nrig or Act.rig(npcArt)
    G.chestShut = G.chestShut or chestImg(false)
    G.chestOpen = G.chestOpen or chestImg(true)
    G.player = Act.new{
        kind = "player", x = Map.cx(tx), y = Map.cy(ty),
        hw = 5, hh = 5, speed = C.PLAYER_SPEED, sprite = G.prig,
        swims = hasflag("boat"),
        onTrigger = function(id, ttx, tty)
            Script.trigger(id, ttx, tty)
        end,
        onStep = function(a) Enc.onStep(a) end,
    }
    if name == "town" then
        local function npc(kind, nx, ny, behavior)
            return Act.new{
                kind = kind, x = Map.cx(nx), y = Map.cy(ny),
                hw = 5, hh = 5, speed = C.NPC_SPEED,
                sprite = G.nrig, behavior = behavior,
            }
        end
        npc("elder", C.ELDER_X, C.ELDER_Y, { kind = "stand" })
        npc("shopkeep", C.SHOP_X, C.SHOP_Y, { kind = "stand" })
        npc("innkeep", C.INN_X, C.INN_Y, { kind = "stand" })
        npc("ferrier", C.FERRIER_X, C.FERRIER_Y,
            { kind = "stand" })
        npc("kid", C.KID_X, C.KID_Y,
            { kind = "wander", radius = 2 })
    end
    G.tyrant = nil
    if name == "burrow2" and not hasflag("boss_down") then
        G.timg = G.timg or tyrantImg()
        G.tyrant = Act.new{
            kind = "tyrant", x = Map.cx(C.B2_TYRANT[1]),
            y = Map.cy(C.B2_TYRANT[2]), hw = 8, hh = 8,
            img = G.timg,
        }
    end
    local chs = Maps.chests[name]
    for i = 1, #chs do
        local ch = chs[i]
        local opened = State.opened(name, ch[1], ch[2])
        Act.new{
            kind = "chest", x = Map.cx(ch[1]), y = Map.cy(ch[2]),
            hw = 6, hh = 5, loot = ch[3], lootN = ch[4],
            img = opened and G.chestOpen or G.chestShut,
        }
    end
    Cam.reset()
    Cam.center(G.player.x, G.player.y)
    Script.followTarget = G.player
    Sfx.playFor(name)
    Script.enter(name)
end

-- ---- the battle seam: grams on win, boss stinger, death flow --------------

local function idsOf(group)
    if type(group) == "string" then
        return Turn.groups[group] or { group }
    end
    return group
end

local function hookBattles()
    Script.battleHook = function(group, done)
        local ids = idsOf(group)
        local grams, boss = 0, false
        for i = 1, #ids do
            local d = Content.BESTIARY[ids[i]]
            grams = grams + ((d and d.grams) or 0)
            if ids[i] == "mole_tyrant" then boss = true end
        end
        local opts = boss and { music = Sfx.songs.boss,
            fanfare = Sfx.songs.fanfare } or nil
        G.bossFight = boss -- the autopilot opens bosses with Curl
        Turn.start(group, opts, function(outcome)
            G.bossFight = false
            if outcome == "win" then GS.addGrams(grams) end
            done(outcome)
            if outcome == "lose" and not Script.active then
                GS.deathFlow() -- scripts handle their own losses
            end
        end)
    end
end

-- gear equips from the Items menu ("Use" a pin/vest = don it)
local function wrapUseItem()
    local base = UI.useItem
    UI.useItem = function(id)
        local it = Party.items[id]
        if it and (it.kind == "weapon" or it.kind == "armor") then
            local m = Party.member(1)
            if it.kind == "weapon" then
                m.equip.weapon = id
            else
                m.equip.armor = id
            end
            Kit.toast("Pip dons the " .. it.name .. ".")
            return false -- gear stays in the bag
        end
        return base(id)
    end
end

-- ---- title / new / continue -----------------------------------------------

function Game.newGame()
    State.wipe()
    State.flags, State.counters, State.quests = {}, {}, {}
    State.party, State.inv, State.openedSet = {}, {}, {}
    State.gold = C.GOLD_START
    Party.add(Content.PIP)
    Game.loadMap("town", C.TSTART_X, C.TSTART_Y)
    Script.run(Story.intro)
end

function Game.continueGame()
    local m, x, y = GS.savedPos() -- ledger loaded at boot
    Game.loadMap(m, x, y)
end

local function pushTitle()
    local rows = State.hasSave() and { "CONTINUE", "NEW" }
        or { "NEW" }
    local st = {
        ui = true, kind = "title", sel = 1, n = #rows, rows = rows,
    }
    st.update = function(dt)
        if Input.up then st.sel = (st.sel - 2) % st.n + 1 end
        if Input.down then st.sel = st.sel % st.n + 1 end
        if Input.a then
            Kit.pop()
            if rows[st.sel] == "CONTINUE" then
                Game.continueGame()
            else
                Game.newGame()
            end
        end
    end
    st.draw = function()
        Gfx.fill(0, 0, 400, 240, 7)
        Kit.bigCentered("SHREW", 42, 3)
        Kit.centered("Eat " .. C.GOAL_G .. "g by dawn.", 110)
        for i = 1, st.n do
            local y = 140 + (i - 1) * 20
            if i == st.sel then Kit.centered("*> " .. rows[i]
                .. " <*", y)
            else Kit.centered(rows[i], y) end
        end
    end
    Kit.push(st)
end

-- ---- boot -----------------------------------------------------------------

function Game.init()
    if Harness.enabled then State.wipe() end -- deterministic smoke
    if not State.load() then State.gold = C.GOLD_START end
    Party.defineItems(Content.ITEMS)
    Party.defineSkills(Content.SKILLS)
    Party.defineBestiary(Content.BESTIARY)
    Party.add(Content.PIP) -- re-registers growth; save-idempotent
    Enc.zones("world", Content.ZONES)
    Turn.defaults = { music = Sfx.songs.battle,
        fanfare = Sfx.songs.fanfare }
    Script.loader = Game.loadMap
    GS.wrapSave()
    hookBattles()
    wrapUseItem()
    Story.register()
    Harness.set("grams", 0)
    G.field = { update = Game.update, draw = Draw.frame }
    Kit.push(G.field)
    pushTitle()
end

-- ---- the field update (grid steps) ----------------------------------------

function Game.update(dt)
    G.t = G.t + dt
    local p = G.player
    if not p.stepping then
        if Input.mx ~= 0 then
            Act.stepTo(p, Input.mx > 0 and Act.RIGHT or Act.LEFT)
        elseif Input.my ~= 0 then
            Act.stepTo(p, Input.my > 0 and Act.DOWN or Act.UP)
        end
    end
    Act.updateAll(dt)
    Cam.update(dt)
    Cam.follow(p.x, p.y, dt)
    if Input.a then
        Script.interact(p)
    elseif Input.b then
        UI.menu()
    end
end

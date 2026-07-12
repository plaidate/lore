-- Lore core: the turn-based battle scene (Dragon Quest front view).
-- Turn.start(group, opts, done) pushes an OPAQUE Kit state: the
-- field beneath is hidden and — since only the top state updates —
-- fully paused. Layout: enemy portraits (bestiary artFn rendered
-- ONCE per encounter into pooled 48x48 images, 4 slots) centered on
-- a black field, a battle message line up top, party status columns
-- (name/HP/MP, strings cached until the value moves) along the
-- bottom, and command windows pushed ABOVE the scene as Kit states.
-- The windows read the same edge-triggered Input contract as lui
-- and expose st.ui/kind/sel/rows (kinds "bcmd" Fight/Skill/Item/
-- Guard/Run, "btarget", "bskill", "bitem"), so the wave-2 autopilot
-- grammar drives whole battles.
--
-- FLOW per round: every living, awake member picks a command; foes
-- pick via their bestiary ai ("basic" attacks, "caster" spends mp
-- on its first dmg skill, "sly" heals itself below half, twice
-- max); all actions sort by AGI * U[0.75..1.25] and resolve with
-- lparty's canonical math (guard halves, sleep skips w/ 1/3 wake +
-- wake-on-hit 50%, member poison ticks at round end). Victory ->
-- XP/gold/drops as a snappy timed message queue (level-up + learn
-- lines from Party.giveXP), done("win"). Defeat -> done("lose") —
-- the game decides game over. Run: chance = clamp(pAgi / (pAgi +
-- fAgi) + 0.15, 0.25, 0.95) vs the fastest living foe ->
-- done("ran").
--
-- group: a name registered via Turn.defineGroups, a bestiary id, or
-- an array of ids. opts (falls back to game-set Turn.defaults):
--   { music = battle stinger song, fanfare = victory song (played
--     once, then the interrupted field song resumes where it left) }
-- Script.battleHook is wired here, so script battle(group) and all
-- of lenc land in this scene. Counters: battles, battlesWon.

local gfx = playdate.graphics

Turn = {
    active = false,
    groups = {},
    defaults = nil, -- game-set default opts
}

function Turn.defineGroups(t)
    for k, v in pairs(t) do Turn.groups[k] = v end
end

-- ---- pooled foe slots -----------------------------------------------------

local MAXF = 4
local FOE_Y = 56
local slots = nil

local function makeSlots()
    slots = {}
    for i = 1, MAXF do
        slots[i] = { img = gfx.image.new(48, 48), live = false }
    end
end

-- ---- the battle record (one battle at a time; tables reused) --------------

local B = {
    phase = "idle", t = 0, done = nil, opts = nil,
    nfoe = 0, msg = nil, waiting = false, memberI = 0,
    queue = {}, qn = 0, oi = 0,
    msgQ = {}, mqn = 0, mqi = 0,
}

local CMDROWS = { "Fight", "Skill", "Item", "Guard", "Run" }
local tnames, tmap = {}, {} -- target window surface (reused)

local function setMsg(text)
    B.msg = text
end

local function addMsgQ(text)
    B.mqn = B.mqn + 1
    B.msgQ[B.mqn] = text
end

-- ---- helpers --------------------------------------------------------------

local function firstLive()
    for i = 1, B.nfoe do
        if slots[i].live then return slots[i] end
    end
    return nil
end

local function liveFoes()
    local n = 0
    for i = 1, B.nfoe do
        if slots[i].live then n = n + 1 end
    end
    return n
end

local function randMember()
    local n, pick = 0, nil
    for i = 1, #State.party do
        local m = State.party[i]
        if m.hp > 0 then
            n = n + 1
            if math.random(n) == 1 then pick = m end
        end
    end
    return pick
end

local function mostHurt()
    local best
    for i = 1, #State.party do
        local m = State.party[i]
        if m.hp > 0 and (not best
            or m.hp / m.maxhp < best.hp / best.maxhp) then
            best = m
        end
    end
    return best
end

local function memberIndex(m)
    for i = 1, #State.party do
        if State.party[i] == m then return i end
    end
    return 1
end

local function rowX(i)
    return 16 + (i - 1) * 96
end

-- ---- battle windows (same Input contract + surface as lui) ----------------

local function bnav(st)
    local mv = 0
    if Input.up then mv = -1 end
    if Input.down then mv = 1 end
    if mv ~= 0 and st.n > 0 then
        st.sel = (st.sel - 1 + mv) % st.n + 1
    end
end

-- rows + onA(i) / onB() (nil onB = not cancelable); extra(st) draws
-- on top (the target chevron)
local function bwin(kind, rows, x, y, w, onA, onB, extra)
    local st = {
        ui = true, kind = kind, translucent = true,
        sel = 1, rows = rows, n = #rows,
    }
    st.update = function(dt)
        bnav(st)
        if Input.a and st.n > 0 then
            Kit.pop()
            onA(st.sel)
        elseif Input.b and onB then
            Kit.pop()
            onB()
        end
    end
    st.draw = function()
        local h = 12 + math.max(st.n, 1) * 18
        UI.panel(x, y, w, h)
        for i = 1, st.n do
            local ry = y + 6 + (i - 1) * 18
            if i == st.sel then Gfx.text("*>*", x + 6, ry) end
            Gfx.text(st.rows[i], x + 22, ry)
        end
        if st.n == 0 then Gfx.text("-", x + 22, y + 6) end
        if extra then extra(st) end
    end
    return Kit.push(st)
end

-- ---- command collection ---------------------------------------------------

local function queueCmd(who, kind, target, skill, item)
    B.qn = B.qn + 1
    local q = B.queue[B.qn]
    if not q then
        q = {}
        B.queue[B.qn] = q
    end
    q.who, q.kind, q.target = who, kind, target
    q.skill, q.item = skill, item
    local agi = who.foe and who.agi or Party.agiOf(who)
    q.init = agi * (0.75 + math.random() * 0.5)
    B.waiting = false
end

local openCmd -- forward

local function openTarget(m, kind, skill)
    local n = 0
    for i = 1, B.nfoe do
        if slots[i].live then
            n = n + 1
            tnames[n] = slots[i].name
            tmap[n] = slots[i]
        end
    end
    for i = #tnames, n + 1, -1 do
        tnames[i], tmap[i] = nil, nil
    end
    bwin("btarget", tnames, 240, 64, 148, function(i)
        queueCmd(m, kind, tmap[i], skill)
    end, function()
        openCmd(m)
    end, function(st)
        local s = tmap[st.sel]
        if s then Kit.marker(s.x + 24, FOE_Y - 2, B.t) end
    end)
end

local function openSkills(m)
    local rows, ids = {}, {}
    for i = 1, #m.skills do
        local sid = m.skills[i]
        local sk = Party.skills[sid]
        if sk and m.mp >= (sk.mp or 0) then
            rows[#rows + 1] = sk.name .. "  " .. (sk.mp or 0)
            ids[#ids + 1] = sid
        end
    end
    bwin("bskill", rows, 120, 64, 150, function(i)
        local sid = ids[i]
        local sk = Party.skills[sid]
        if sk.kind == "dmg" and sk.target == "one"
            and liveFoes() > 1 then
            openTarget(m, "skill", sid)
        elseif sk.kind == "dmg" and sk.target == "one" then
            queueCmd(m, "skill", firstLive(), sid)
        else
            queueCmd(m, "skill", nil, sid)
        end
    end, function()
        openCmd(m)
    end)
end

local function openItems(m)
    local rows, ids = {}, {}
    for id in pairs(State.inv) do
        local it = Party.items[id]
        if it and (it.kind == "heal" or it.kind == "cure") then
            ids[#ids + 1] = id
        end
    end
    table.sort(ids)
    for i = 1, #ids do
        rows[i] = ids[i] .. " x" .. State.inv[ids[i]]
    end
    bwin("bitem", rows, 120, 64, 150, function(i)
        queueCmd(m, "item", nil, nil, ids[i])
    end, function()
        openCmd(m)
    end)
end

openCmd = function(m)
    B.waiting = true
    bwin("bcmd", CMDROWS, 12, 60, 100, function(i)
        if i == 1 then -- Fight
            if liveFoes() > 1 then
                openTarget(m, "fight")
            else
                queueCmd(m, "fight", firstLive())
            end
        elseif i == 2 then
            openSkills(m)
        elseif i == 3 then
            openItems(m)
        elseif i == 4 then
            queueCmd(m, "guard")
        else
            queueCmd(m, "run")
        end
    end)
end

-- ---- round assembly -------------------------------------------------------

local function enemyDecide()
    for i = 1, B.nfoe do
        local s = slots[i]
        if s.live then
            local acted = false
            if s.ai == "sly" and s.hp < s.maxhp / 2
                and s.healed < 2 then
                queueCmd(s, "foeheal")
                acted = true
            elseif (s.ai == "caster" or (s.ai == "boss"
                and s.hp < s.maxhp / 2)) and s.skills then
                -- "boss": basic until half hp, then a skill barrage
                for j = 1, #s.skills do
                    local sk = Party.skills[s.skills[j]]
                    if sk and sk.kind == "dmg"
                        and s.mp >= (sk.mp or 0) then
                        queueCmd(s, "foeskill", randMember(),
                            s.skills[j])
                        acted = true
                        break
                    end
                end
            end
            if not acted then
                queueCmd(s, "foefight", randMember())
            end
        end
    end
end

local function buildOrder()
    for i = 2, B.qn do
        local q = B.queue[i]
        local j = i - 1
        while j >= 1 and B.queue[j].init < q.init do
            B.queue[j + 1] = B.queue[j]
            j = j - 1
        end
        B.queue[j + 1] = q
    end
end

local function beginRound()
    B.phase = "command"
    B.memberI, B.qn, B.oi = 0, 0, 0
    B.waiting = false
end

local function nextCommand()
    while true do
        B.memberI = B.memberI + 1
        local m = Party.member(B.memberI)
        if not m then
            enemyDecide()
            buildOrder()
            B.phase, B.oi, B.t = "act", 1, 0.35
            return
        end
        if m.hp > 0 then
            m.status.guard = nil -- guard expires here
            if m.status.sleep then
                local s = m.status.sleep
                if s <= 1 or math.random(3) == 1 then
                    m.status.sleep = nil
                    setMsg(m.name .. " wakes up!")
                else
                    m.status.sleep = s - 1
                    setMsg(m.name .. " is fast asleep.")
                end
            end
            if m.hp > 0 and not m.status.sleep then
                openCmd(m)
                return
            end
        end
    end
end

-- ---- resolution -----------------------------------------------------------

local finish -- forward

local function startVictory()
    Harness.count("battlesWon")
    local xp, gold = 0, 0
    B.mqn, B.mqi = 0, 0
    addMsgQ("Victory!")
    for i = 1, B.nfoe do
        local s = slots[i]
        xp = xp + s.xp
        gold = gold + s.gold
        if s.drop and math.random() < (s.drop.chance or 0) then
            State.add(s.drop.item, 1)
            addMsgQ("The " .. s.name .. " drops a "
                .. s.drop.item .. "!")
        end
    end
    State.giveGold(gold)
    addMsgQ("Gained " .. xp .. " xp and " .. gold .. "g.")
    local lines = Party.giveXP(xp, {})
    for i = 1, #lines do addMsgQ(lines[i]) end
    B.phase, B.t = "victory", 0.01
    local o = B.opts
    if o and o.fanfare then
        Music.stinger(o.fanfare, true) -- once, then field resumes
    elseif o and o.music then
        Music.resume()
    end
end

local function checkEnd()
    if liveFoes() == 0 then
        startVictory()
        return true
    end
    if not Party.anyAlive() then
        B.phase, B.t = "lose", 1.4
        setMsg("The party falls...")
        return true
    end
    return false
end

local function hitFoe(s, dmg, crit)
    s.hp = s.hp - dmg
    UI.popup(s.x + 16, FOE_Y + 8, "-" .. dmg)
    Kit.shake(crit and 0.2 or 0.1)
    Snd.play("noise", 320, 0.07, 0.25)
    if s.hp <= 0 then
        s.live = false
        Snd.boom(180, 2)
    end
end

local function doAction(q)
    B.t = 0.55
    local who = q.who
    if who.foe then
        if not who.live then
            B.t = 0.05
            return
        end
        local m = q.target
        if not m or m.hp <= 0 then m = randMember() end
        if not m then return end
        local mi = memberIndex(m)
        if q.kind == "foeheal" then
            local amt = math.max(1, math.floor(who.maxhp / 3))
            who.hp = math.min(who.maxhp, who.hp + amt)
            who.healed = who.healed + 1
            setMsg("The " .. who.name .. " knits itself!")
            UI.popup(who.x + 16, FOE_Y + 8, "+" .. amt)
            return
        end
        local guarded = m.status.guard ~= nil
        local amt, crit, miss
        if q.kind == "foeskill" then
            local sk = Party.skills[q.skill]
            who.mp = who.mp - (sk.mp or 0)
            amt = Party.skillPower(sk, nil)
            if guarded then
                amt = math.max(1, math.floor(amt / 2))
            end
            setMsg("The " .. who.name .. " casts "
                .. sk.name .. "!")
        else
            amt, crit, miss = Party.attack(who.atk, Party.defOf(m),
                who.agi, Party.agiOf(m), guarded)
            setMsg("The " .. who.name .. " attacks!")
        end
        if miss then
            UI.popup(rowX(mi) + 24, 192, "miss")
            return
        end
        m.hp = math.max(0, m.hp - amt)
        if m.status.sleep and math.random() < 0.5 then
            m.status.sleep = nil
        end
        UI.popup(rowX(mi) + 24, 192, "-" .. amt)
        Kit.shake(0.15)
        Snd.play("noise", 260, 0.07, 0.25)
        if m.hp <= 0 then setMsg(m.name .. " falls!") end
        checkEnd()
        return
    end
    -- a party member's action
    local m = who
    if m.hp <= 0 then
        B.t = 0.05
        return
    end
    if q.kind == "fight" then
        local s = q.target
        if not s or not s.live then s = firstLive() end
        if not s then
            checkEnd()
            return
        end
        local dmg, crit, miss = Party.attack(Party.atkOf(m), s.def,
            Party.agiOf(m), s.agi, false)
        setMsg(crit and "A telling blow!" or m.name .. " attacks!")
        if miss then
            UI.popup(s.x + 16, FOE_Y + 8, "miss")
        else
            hitFoe(s, dmg, crit)
            if not s.live then
                setMsg("The " .. s.name .. " is defeated!")
            end
        end
        checkEnd()
    elseif q.kind == "skill" then
        local sk = Party.skills[q.skill]
        if not sk or m.mp < (sk.mp or 0) then
            B.t = 0.05
            return
        end
        m.mp = m.mp - (sk.mp or 0)
        setMsg(m.name .. " casts " .. sk.name .. "!")
        if sk.kind == "heal" then
            local t = (sk.target == "self") and m or mostHurt()
            if t then
                local amt = Party.skillPower(sk, nil)
                Party.heal(t, amt)
                UI.popup(rowX(memberIndex(t)) + 24, 192,
                    "+" .. amt)
            end
        elseif sk.kind == "dmg" then
            if sk.target == "all" then
                for i = 1, B.nfoe do
                    local s = slots[i]
                    if s.live then
                        hitFoe(s, Party.skillPower(sk, s), false)
                    end
                end
            else
                local s = q.target
                if not s or not s.live then s = firstLive() end
                if s then
                    local amt = Party.skillPower(sk, s)
                    hitFoe(s, amt, false)
                    if sk.drain then -- drain-lite: heal a fraction
                        local h = math.max(1,
                            math.floor(amt * sk.drain))
                        Party.heal(m, h)
                        UI.popup(rowX(memberIndex(m)) + 24, 192,
                            "+" .. h)
                    end
                    if not s.live then
                        setMsg("The " .. s.name .. " is defeated!")
                    end
                end
            end
        else -- buff: minimal — a guard that outlives the round
            m.status.guard = 1
        end
        checkEnd()
    elseif q.kind == "item" then
        if State.take(q.item, 1) then
            local it = Party.items[q.item]
            setMsg(m.name .. " uses a " .. q.item .. ".")
            if it.kind == "heal" then
                local t = mostHurt()
                if t then
                    Party.heal(t, it.power or 10)
                    UI.popup(rowX(memberIndex(t)) + 24, 192,
                        "+" .. (it.power or 10))
                end
            elseif it.kind == "cure" then
                Party.cure(m, "poison")
            end
        else
            B.t = 0.05
        end
    elseif q.kind == "guard" then
        m.status.guard = 1
        setMsg(m.name .. " guards.")
    elseif q.kind == "run" then
        local pAgi, fAgi = 1, 1
        for i = 1, #State.party do
            local pm = State.party[i]
            if pm.hp > 0 then
                pAgi = math.max(pAgi, Party.agiOf(pm))
            end
        end
        for i = 1, B.nfoe do
            if slots[i].live then
                fAgi = math.max(fAgi, slots[i].agi)
            end
        end
        local chance = Util.clamp(pAgi / (pAgi + fAgi) + 0.15,
            0.25, 0.95)
        if math.random() < chance then
            B.phase, B.t = "ran", 0.8
            setMsg("You flee!")
        else
            setMsg("Can't escape!")
        end
    end
end

local function stepAct()
    if B.oi > B.qn then
        for i = 1, #State.party do -- poison round tick
            local m = State.party[i]
            if m.hp > 0 and m.status.poison then
                local d = Party.poisonTick(m)
                if d > 0 then
                    UI.popup(rowX(i) + 24, 192, "-" .. d)
                end
            end
        end
        if not checkEnd() then beginRound() end
        return
    end
    local q = B.queue[B.oi]
    B.oi = B.oi + 1
    doAction(q)
end

-- ---- end of battle --------------------------------------------------------

finish = function(outcome)
    Kit.pop() -- the battle state (windows are long popped)
    Turn.active = false
    B.phase = "idle"
    local d = B.done
    B.done = nil
    if d then d(outcome) end
end

local function stepEnd()
    if B.phase == "victory" then
        B.mqi = B.mqi + 1
        if B.mqi <= B.mqn then
            setMsg(B.msgQ[B.mqi])
            B.t = 0.7
        else
            finish("win")
        end
    elseif B.phase == "lose" then
        if B.opts and B.opts.music then Music.resume() end
        finish("lose")
    elseif B.phase == "ran" then
        if B.opts and B.opts.music then Music.resume() end
        finish("ran")
    end
end

-- ---- the scene state ------------------------------------------------------

-- cached party row strings (rebuilt only when a value moves)
local prow = {}
for i = 1, 4 do
    prow[i] = { hp = -1, mp = -1, hps = "", mps = "" }
end

local function rowStrs(i, m)
    local r = prow[i]
    if r.hp ~= m.hp then
        r.hp = m.hp
        r.hps = "HP " .. m.hp
    end
    if r.mp ~= m.mp then
        r.mp = m.mp
        r.mps = "MP " .. m.mp
    end
    return r
end

local function update(dt)
    B.t = B.t - dt
    if B.phase == "intro" then
        if B.t <= 0 then
            beginRound()
        end
    elseif B.phase == "command" then
        if not B.waiting then nextCommand() end
    elseif B.phase == "act" then
        if B.t <= 0 then stepAct() end
    else -- victory / lose / ran
        if B.t <= 0 then stepEnd() end
    end
end

-- The stage is DITHERED, not black. Portraits obey the house palette
-- (dark bodies, white eye pixels) because the same artFn also draws
-- the field sprite -- and a dark body on a black backdrop is an
-- invisible silhouette with floating eyes. A mid-gray stage lets one
-- monster definition read in both battle engines.
local STAGE_Y <const> = 40
local STAGE_H <const> = 128

local function draw()
    gfx.setDrawOffset(Kit.sx, Kit.sy)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(-4, -4, 408, 248)
    Gfx.fill(8, STAGE_Y, 384, STAGE_H, 3)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(8, STAGE_Y, 384, STAGE_H)
    gfx.drawRect(4, 4, 392, 232)
    for i = 1, B.nfoe do
        local s = slots[i]
        if s.live then
            s.img:draw(s.x, FOE_Y)
            if s.hp < s.maxhp then
                UI.hpBar(s.x, FOE_Y + 52, 48, s.hp, s.maxhp)
            end
        end
    end
    if B.msg then Gfx.text(B.msg, 16, 14) end
    UI.panel(8, 176, 384, 58)
    local n = math.min(#State.party, 4)
    for i = 1, n do
        local m = State.party[i]
        local r = rowStrs(i, m)
        local x = rowX(i)
        Gfx.text(m.name, x, 182)
        Gfx.text(r.hps, x, 198)
        Gfx.text(r.mps, x, 214)
    end
    UI.drawPopups()
    gfx.setDrawOffset(0, 0)
end

Turn.state = { kind = "battle", update = update, draw = draw }

-- ---- entry ----------------------------------------------------------------

local function resolveGroup(group)
    if type(group) == "string" then
        return Turn.groups[group] or { group }
    end
    return group
end

-- push the battle scene; done(outcome) fires after the state pops.
-- outcome: "win" | "lose" | "ran"
function Turn.start(group, opts, done)
    assert(not Turn.active, "Turn.start: a battle is already up")
    if not slots then makeSlots() end
    opts = opts or Turn.defaults
    local ids = resolveGroup(group)
    B.nfoe = math.min(#ids, MAXF)
    for i = 1, MAXF do slots[i].live = false end
    for i = 1, B.nfoe do
        local d = Party.bestiary[ids[i]]
        assert(d, "Turn.start: no bestiary entry '"
            .. tostring(ids[i]) .. "'")
        local s = slots[i]
        s.id, s.name = ids[i], d.name or ids[i]
        s.maxhp, s.hp = d.hp, d.hp
        s.atk, s.def, s.agi = d.atk, d.def, d.agi
        s.mp = d.mp or 0
        s.skills, s.ai = d.skills, d.ai or "basic"
        s.xp, s.gold = d.xp or 0, d.gold or 0
        s.drop, s.elems = d.drop, d.elems
        s.live, s.foe, s.healed = true, true, 0
        s.x = 200 - B.nfoe * 28 + (i - 1) * 56 + 4
        s.img:clear(gfx.kColorClear)
        if d.artFn then
            gfx.pushContext(s.img)
            d.artFn(48, 48)
            gfx.popContext()
        end
    end
    B.opts, B.done = opts, done
    B.phase, B.t = "intro", 0.7
    B.mqn, B.mqi = 0, 0
    if B.nfoe == 1 then
        setMsg("A " .. slots[1].name .. " draws near!")
    else
        setMsg("Foes draw near!")
    end
    Turn.active = true
    Harness.count("battles")
    if opts and opts.music then Music.stinger(opts.music) end
    Kit.push(Turn.state)
end

-- the wave-3 seam closes: script battle(group) and lenc both land
-- here (games may still override for custom scenes)
Script.battleHook = function(group, done)
    Turn.start(group, nil, done)
end

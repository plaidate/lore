-- Lore core: the coroutine event runner. A scripted beat is plain Lua
-- run in ONE coroutine (Script.run asserts exclusivity); its
-- primitives BLOCK until the engine finishes them, so events read
-- like a screenplay:
--
--   say(who, text)          dialog box, waits for the last A
--   ask(text, opts) -> i    choice window
--   walk(actor, spec)       grid stepTo chain; {tx=,ty=} or {dx=,dy=}
--   face(actor, dir)        "up"/"down"/"left"/"right" or Act const
--   wait(secs)              timer
--   fade(t01)               full-screen dither fade (lui hosts it)
--   pan(wx, wy, spd)        scripted camera pan; panBack() returns
--   give(item, n)           inventory + "Got ..." toast
--   giveGold(n) takeGold(n) purse (takeGold -> bool)
--   setflag(f) hasflag(f)   story flags
--   warp(map, tx, ty)       Script.loader hook + State.autosave()
--   shop(stock) inn(price)  lui flows
--   battle(group) -> res    Script.battleHook (wave 3 wires lturn)
--   toast(text)             status line
--   waituntil(pred)         generic engine-condition wait
--
-- While a script runs it owns a translucent Kit state: field update
-- (and so field input) is suppressed, but the world stays visible and
-- Script.tick keeps actors animating (Act.updateAll), the camera
-- panning, and Cam following Script.followTarget. Windows a primitive
-- opens push ABOVE the script state and freeze it — classic RPG grammar.
--
-- Attach points: Script.onTrigger(id, fn) (step triggers routed via
-- Script.trigger from the player's onTrigger), Script.onTalk(kind, fn)
-- + Script.interact(player) (games call it on A: facing-cell probe w/
-- a near-miss fallback that auto-faces the pair), Script.onEnter(map,
-- fn) fired by Script.enter after a map loads. Handlers called while a
-- script is ALREADY running (the smoke playthrough) run INLINE in the
-- same coroutine; engine-side dispatch while busy is dropped.

Script = {
    active = false,
    co = nil,
    loader = nil,       -- game registers: fn(mapName, tx, ty)
    followTarget = nil, -- actor the camera follows during scripts
}

local handlers = { trigger = {}, talk = {}, enter = {} }
local cond = nil          -- engine-side wait predicate fn(dt)
local ready, rv = false, nil -- callback-style resume slot
local walkJob = nil
local panSaved = nil

-- ---- the runner -----------------------------------------------------------

local function inside()
    return Script.co ~= nil and coroutine.running() == Script.co
end

local function finish()
    Script.active = false
    Script.co = nil
    cond, ready, rv = nil, false, nil
    walkJob, panSaved = nil, nil
    -- pop the script state plus any window a dying script left open
    while #Kit.stack > 0 do
        if Kit.pop() == Script.state then break end
    end
end

local function step()
    local ok, err = coroutine.resume(Script.co, rv)
    rv = nil
    if not ok then
        finish()
        error(err, 0) -- surface in the harness latch
    end
    if coroutine.status(Script.co) == "dead" then finish() end
end

-- start the one active script; fn runs as a coroutine immediately
function Script.run(fn)
    assert(not Script.active, "Script.run: a script is already active")
    Script.active = true
    Script.co = coroutine.create(fn)
    Kit.push(Script.state)
    step()
end

-- drive a pending scripted walk one engine frame
local function driveWalk(dt)
    local j = walkJob
    if not j or j.done then return end
    local a = j.a
    if a.stepping then
        j.stall = 0
        return
    end
    if a.cellX == j.tx and a.cellY == j.ty then
        j.done = true
        return
    end
    local d1, d2 = Act.dirToward(a.cellX, a.cellY, j.tx, j.ty)
    if d1 and Act.stepTo(a, d1) then return end
    if d2 and Act.stepTo(a, d2) then return end
    j.stall = j.stall + dt
    if j.stall > 0.7 then
        Act.stepTo(a, math.random(4)) -- jiggle out of the corner
        if j.stall > 6 then j.done = true end -- never hang a script
    end
end

-- the script state's update: keep the world alive, then resume the
-- coroutine when its wait is over
local function tick(dt)
    Act.updateAll(dt)
    Cam.update(dt)
    if Script.followTarget and not panSaved and not Cam.panning then
        Cam.follow(Script.followTarget.x, Script.followTarget.y, dt)
    end
    driveWalk(dt)
    if not Script.co then return end
    if ready then
        ready = false
        step()
    elseif cond then
        if cond(dt) then
            cond = nil
            step()
        end
    end
end

Script.state = {
    kind = "script", translucent = true, update = tick,
}

-- ---- blocking plumbing ----------------------------------------------------

local function resumeWith(v)
    rv = v
    ready = true
end

local function block()
    assert(inside(), "script primitive called outside a script")
    return coroutine.yield()
end

local function blockOn(c)
    assert(inside(), "script primitive called outside a script")
    cond = c
    return coroutine.yield()
end

-- ---- primitives (globals: scripts read like screenplays) ------------------

function say(who, text)
    UI.dialog(who, text, resumeWith)
    block()
end

function ask(text, options)
    UI.choose(text, options, resumeWith)
    return block()
end

-- spec: {tx=, ty=} absolute or {dx=, dy=} relative (tiles)
function walk(actor, spec)
    local tx = spec.tx or (actor.cellX + (spec.dx or 0))
    local ty = spec.ty or (actor.cellY + (spec.dy or 0))
    walkJob = { a = actor, tx = tx, ty = ty, stall = 0 }
    blockOn(function() return walkJob.done end)
    walkJob = nil
end

local DIRNAME = {
    up = Act.UP, down = Act.DOWN, left = Act.LEFT, right = Act.RIGHT,
}
local FLIP = { Act.UP, Act.DOWN, Act.RIGHT, Act.LEFT }

function face(actor, dir)
    actor.dir = DIRNAME[dir] or dir
end

function wait(secs)
    local t = secs
    blockOn(function(dt)
        t = t - dt
        return t <= 0
    end)
end

function fade(t01)
    UI.fadeTo(t01, resumeWith)
    block()
end

function pan(wx, wy, speed)
    if not panSaved then
        panSaved = { x = Cam.x + 200, y = Cam.y + 120 }
    end
    Cam.panTo(wx, wy, speed)
    blockOn(function() return not Cam.panning end)
end

function panBack()
    if not panSaved then return end
    Cam.panTo(panSaved.x, panSaved.y)
    panSaved = nil
    blockOn(function() return not Cam.panning end)
end

function give(item, n)
    n = n or 1
    State.add(item, n)
    if n == 1 then
        Kit.toast("Got a " .. item .. ".")
    else
        Kit.toast("Got " .. n .. " " .. item .. ".")
    end
end

function giveGold(n)
    State.giveGold(n)
    Kit.toast("Got " .. n .. " gold.")
end

function takeGold(n)
    return State.takeGold(n)
end

function setflag(f)
    State.set(f, true)
end

function hasflag(f)
    return State.has(f)
end

-- map change: the game-registered loader rebuilds map + actors, then
-- the ledger autosaves (the map-change autosave hook)
function warp(mapName, tx, ty)
    assert(Script.loader, "warp: no Script.loader registered")
    Script.loader(mapName, tx, ty)
    State.autosave()
end

function shop(stock)
    UI.shop(stock, resumeWith)
    block()
end

function inn(price)
    UI.inn(price, resumeWith)
    block()
end

function toast(text)
    Kit.toast(text)
end

-- wave-3 seam: real battles replace the hook. Default: instant win.
Script.battleHook = function(group, done)
    Kit.toast("The " .. tostring(group) .. " scatter!")
    done("win")
end

function battle(group)
    Script.battleHook(group, resumeWith)
    return block()
end

function waituntil(pred)
    blockOn(pred)
end

-- ---- attach points --------------------------------------------------------

function Script.onTrigger(id, fn)
    handlers.trigger[id] = fn
end

function Script.onTalk(kind, fn)
    handlers.talk[kind] = fn
end

function Script.onEnter(mapName, fn)
    handlers.enter[mapName] = fn
end

-- run a handler: inline when already inside the script coroutine
-- (playthroughs), as a fresh script when idle, dropped when busy
local function dispatch(fn, a, b, c)
    if inside() then
        fn(a, b, c)
        return true
    end
    if Script.active then return false end
    Script.run(function() fn(a, b, c) end)
    return true
end

-- step-trigger route: wire actor.onTrigger to this
function Script.trigger(id, tx, ty)
    local fn = handlers.trigger[id]
    if not fn then return false end
    return dispatch(fn, id, tx, ty)
end

-- map-entry route: call after Map.load/loader
function Script.enter(mapName)
    local fn = handlers.enter[mapName]
    if not fn then return false end
    return dispatch(fn, mapName)
end

-- A-press interaction: probe the facing cell for a talk-handler
-- actor; fall back to the nearest one within 26px (auto-facing the
-- pair). Returns true when a handler ran.
function Script.interact(player)
    local fx, fy = Act.facingCell(player)
    local best, bestD
    for i = 1, #Act.list do
        local a = Act.list[i]
        if a ~= player and handlers.talk[a.kind] then
            if a.cellX == fx and a.cellY == fy then
                best = a
                break
            end
            local d = Util.dist2(a.x, a.y, player.x, player.y)
            if d < 26 * 26 and (not bestD or d < bestD) then
                best, bestD = a, d
            end
        end
    end
    if not best then return false end
    local d1 = Act.dirToward(player.cellX, player.cellY,
        best.cellX, best.cellY)
    if d1 then
        player.dir = d1
        best.dir = FLIP[d1]
    end
    return dispatch(handlers.talk[best.kind], best, player)
end

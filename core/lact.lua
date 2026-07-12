-- Lore core: actors. An actor is an AABB ({x,y} center px, {hw,hh}
-- half extents) with a 4-direction 2-frame procedural rig (Act.rig
-- builds 8 16x20 images once). Two movement grammars: Act.walk = free
-- AABB movement vs solids/water (axis-separated 1px substeps, action
-- feel) and Act.stepTo = tile-to-tile tween (classic DQ feel). NPC
-- behaviors (stand/wander/patrol/follow), a facing-cell probe for
-- interaction, step-triggers (Map.trigger cell -> a.onTrigger), and a
-- painter-sorted drawAll (y-order, stable, in-place — no allocation).
-- Wave-3 seams: a.onStep(a, tx, ty) fires on every cell change (lenc
-- counts encounter steps there); Act.remove(a) deletes one actor
-- (laction kills, lenc roamers, collected pickups).

local gfx = playdate.graphics

Act = {
    list = {},
    DOWN = 1, UP = 2, LEFT = 3, RIGHT = 4,
    DX = { 0, 0, -1, 1 },
    DY = { 1, -1, 0, 0 },
    ANIM_FPS = 6,
}

-- build a rig: fn16(dir, frame) draws a 16x20 actor into the current
-- context (origin 0,0); returns rig[dir][frame] = image, built once
function Act.rig(fn16)
    local rig = {}
    for d = 1, 4 do
        rig[d] = {}
        for f = 1, 2 do
            local img = gfx.image.new(16, 20) -- transparent
            gfx.pushContext(img)
            fn16(d, f)
            gfx.popContext()
            rig[d][f] = img
        end
    end
    return rig
end

-- Act.new{ kind=, x=, y=, hw=, hh=, speed=, sprite=rig,
--          behavior = {kind="stand"|"wander"|"patrol"|"follow", ...},
--          onTrigger = fn(id, tx, ty), swims = bool }
function Act.new(o)
    local a = o or {}
    a.kind = a.kind or "actor"
    a.hw, a.hh = a.hw or 5, a.hh or 5
    a.speed = a.speed or 60
    a.dir = a.dir or Act.DOWN
    a.frame, a.animT = 1, 0
    a.moving, a.stepping = false, false
    a.steps = 0
    a.cellX, a.cellY = Map.tileAt(a.x, a.y)
    if a.behavior and a.behavior.kind == "wander" then
        local b = a.behavior
        b.homeX, b.homeY = b.homeX or a.cellX, b.homeY or a.cellY
        b.radius = b.radius or 3
    end
    Act.list[#Act.list + 1] = a
    a.seq = #Act.list -- stable painter tiebreak
    return a
end

-- clear all actors (map switches)
function Act.reset()
    Act.list = {}
end

-- delete one actor (dead field foe, collected pickup)
function Act.remove(a)
    local list = Act.list
    for i = 1, #list do
        if list[i] == a then
            table.remove(list, i)
            return true
        end
    end
    return false
end

-- a cell an actor cannot enter: solid, or water for non-swimmers
local function cellBlocked(a, tx, ty)
    if Map.solid(tx, ty) then return true end
    if not a.swims and Map.water(tx, ty) then return true end
    return false
end

-- is the actor's box at (x, y) overlapping any blocked tile?
function Act.blocked(a, x, y)
    local tx0, ty0 = Map.tileAt(x - a.hw, y - a.hh)
    local tx1, ty1 = Map.tileAt(x + a.hw - 0.01, y + a.hh - 0.01)
    for ty = ty0, ty1 do
        for tx = tx0, tx1 do
            if cellBlocked(a, tx, ty) then return true end
        end
    end
    return false
end

-- axis-separated 1px-substep move; mutates a.x/a.y, returns hitX, hitY
function Act.move(a, dx, dy)
    local hitX, hitY = false, false
    local sx = Util.sign(dx)
    local rem = math.abs(dx)
    while rem > 0 do
        local step = math.min(1, rem)
        if Act.blocked(a, a.x + sx * step, a.y) then
            hitX = true
            break
        end
        a.x = a.x + sx * step
        rem = rem - step
    end
    local sy = Util.sign(dy)
    rem = math.abs(dy)
    while rem > 0 do
        local step = math.min(1, rem)
        if Act.blocked(a, a.x, a.y + sy * step) then
            hitY = true
            break
        end
        a.y = a.y + sy * step
        rem = rem - step
    end
    return hitX, hitY
end

-- free movement from an input vector (mx/my in -1..1); applies the
-- terrain speed multiplier, sets facing + walk animation
function Act.walk(a, mx, my, dt)
    if mx == 0 and my == 0 then return false, false end
    if math.abs(mx) >= math.abs(my) then
        a.dir = mx > 0 and Act.RIGHT or Act.LEFT
    else
        a.dir = my > 0 and Act.DOWN or Act.UP
    end
    local spd = a.speed * Map.speed(a.cellX, a.cellY) * dt
    if mx ~= 0 and my ~= 0 then spd = spd * 0.7071 end
    a.moving = true
    a.animT = a.animT + dt
    return Act.move(a, mx * spd, my * spd)
end

-- grid-step movement: face dir, and if the next cell is open start a
-- tile-to-tile tween (advanced by Act.update). Returns true if the
-- step started; false when blocked or already mid-step.
function Act.stepTo(a, dir)
    if a.stepping then return false end
    a.dir = dir -- face even when blocked (classic)
    local tx = a.cellX + Act.DX[dir]
    local ty = a.cellY + Act.DY[dir]
    if cellBlocked(a, tx, ty) then return false end
    a.stx, a.sty = Map.cx(tx), Map.cy(ty)
    a.stepping = true
    return true
end

-- the map cell the actor is facing (interaction probe)
function Act.facingCell(a)
    local tx, ty = Map.tileAt(a.x, a.y)
    return tx + Act.DX[a.dir], ty + Act.DY[a.dir]
end

-- pick the grid direction from (x0,y0) toward (x1,y1); returns the
-- long-axis dir and the short-axis dir (either may be nil)
function Act.dirToward(x0, y0, x1, y1)
    local dx, dy = x1 - x0, y1 - y0
    local h = dx ~= 0 and (dx > 0 and Act.RIGHT or Act.LEFT) or nil
    local v = dy ~= 0 and (dy > 0 and Act.DOWN or Act.UP) or nil
    if math.abs(dx) >= math.abs(dy) then
        return h or v, h and v or nil
    end
    return v or h, v and h or nil
end

local function updBehavior(a, dt)
    local b = a.behavior
    if a.stepping or not b then return end
    if b.kind == "wander" then
        b.t = (b.t or (0.5 + math.random())) - dt
        if b.t > 0 then return end
        b.t = 0.6 + math.random() * 1.6
        local d = math.random(4)
        local nx = a.cellX + Act.DX[d] - b.homeX
        local ny = a.cellY + Act.DY[d] - b.homeY
        if nx * nx + ny * ny <= b.radius * b.radius then
            Act.stepTo(a, d)
        end
    elseif b.kind == "patrol" then
        b.i = b.i or 1
        local p = b.points[b.i]
        if a.cellX == p[1] and a.cellY == p[2] then
            b.i = b.i % #b.points + 1
            p = b.points[b.i]
        end
        local d1, d2 = Act.dirToward(a.cellX, a.cellY, p[1], p[2])
        if d1 and not Act.stepTo(a, d1) and d2 then
            Act.stepTo(a, d2)
        end
    elseif b.kind == "follow" then
        local t = b.target
        local dx = math.abs(t.cellX - a.cellX)
        local dy = math.abs(t.cellY - a.cellY)
        if dx + dy > (b.gap or 1) then
            local d1, d2 = Act.dirToward(a.cellX, a.cellY,
                t.cellX, t.cellY)
            if d1 and not Act.stepTo(a, d1) and d2 then
                Act.stepTo(a, d2)
            end
        end
    end -- "stand": nothing
end

-- per-actor tick: step tween, behavior, animation frame, cell change
-- + step-trigger dispatch. Player movement (Act.walk) happens before
-- this in the game's update.
function Act.update(a, dt)
    if a.stepping then
        local spd = a.speed * Map.speed(a.cellX, a.cellY) * dt
        local dx, dy = a.stx - a.x, a.sty - a.y
        if math.abs(dx) + math.abs(dy) <= spd then
            a.x, a.y, a.stepping = a.stx, a.sty, false
        else
            a.x = a.x + Util.clamp(dx, -spd, spd)
            a.y = a.y + Util.clamp(dy, -spd, spd)
        end
        a.moving = true
        a.animT = a.animT + dt
    end
    updBehavior(a, dt)
    if a.moving then
        a.frame = math.floor(a.animT * Act.ANIM_FPS) % 2 + 1
    else
        a.frame, a.animT = 1, 0
    end
    local tx, ty = Map.tileAt(a.x, a.y)
    if tx ~= a.cellX or ty ~= a.cellY then
        a.cellX, a.cellY = tx, ty
        a.steps = a.steps + 1
        if a.onStep then a.onStep(a, tx, ty) end
        local id = Map.trigger(tx, ty)
        if id and a.onTrigger then a.onTrigger(id, tx, ty) end
    end
    a.moving = false
end

function Act.updateAll(dt)
    local list = Act.list
    for i = 1, #list do Act.update(list[i], dt) end
end

-- painter-sorted draw: in-place insertion sort on y (seq breaks ties
-- so equal-y actors never Z-flicker); mostly-sorted lists are ~free.
-- Rig frames anchor feet at y + hh; a.img (plain image) centers.
function Act.drawAll()
    local list = Act.list
    for i = 2, #list do
        local a = list[i]
        local j = i - 1
        while j >= 1 and (list[j].y > a.y
            or (list[j].y == a.y and list[j].seq > a.seq)) do
            list[j + 1] = list[j]
            j = j - 1
        end
        list[j + 1] = a
    end
    for i = 1, #list do
        local a = list[i]
        if a.sprite then
            a.sprite[a.dir][a.frame]:draw(
                math.floor(a.x - 8 + 0.5),
                math.floor(a.y + a.hh - 20 + 0.5))
        elseif a.img then
            a.img:draw(math.floor(a.x - a.img.width / 2 + 0.5),
                math.floor(a.y - a.img.height / 2 + 0.5))
        end
    end
end

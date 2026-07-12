-- Lore core: the cabinet. RPG flow is a STATE STACK, not a mode
-- string: Kit.push/pop states ({update=, draw=, translucent=}); each
-- frame Kit.run updates the TOP state only and draws from the lowest
-- non-covered state up (an opaque state covers everything below it —
-- so a dialog with translucent=true keeps the field visible under
-- it). Plus the fleet furniture: white text/panels, cached big text,
-- particles, screen shake, marker, toasts, title/over screens.
-- Kit.fxUpdate(dt)/Kit.fxDraw() are the above-the-stack overlay hooks
-- (lui hosts the full-screen fade + popup pool there): fxUpdate ticks
-- every frame no matter which state is on top; fxDraw paints after
-- all states, under the toast.

local gfx = playdate.graphics

Kit = {}

-- ---- the state stack -------------------------------------------------

Kit.stack = {}

function Kit.push(st)
    Kit.stack[#Kit.stack + 1] = st
    return st
end

function Kit.pop()
    local st = Kit.stack[#Kit.stack]
    Kit.stack[#Kit.stack] = nil
    return st
end

function Kit.top()
    return Kit.stack[#Kit.stack]
end

-- ---- text and panels ---------------------------------------------------

local cache = {}

function Kit.bigText(text)
    local img = cache[text]
    if not img then
        local w, h = gfx.getTextSize(text)
        img = gfx.image.new(w, h)
        gfx.pushContext(img)
        gfx.drawText(text, 0, 0)
        gfx.popContext()
        cache[text] = img
    end
    return img
end

function Kit.panel(x, y, w, h)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(x, y, w, h)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(x, y, w, h)
end

function Kit.text(t, x, y)
    Gfx.text(t, x, y)
end

function Kit.centered(t, y)
    local w = gfx.getTextSize(t)
    Kit.text(t, math.floor((400 - w) / 2), y)
end

function Kit.bigCentered(text, y, scale)
    local img = Kit.bigText(text)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    img:drawScaled(math.floor((400 - img.width * scale) / 2), y, scale)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

-- title screen: big name + instruction lines (last line = the prompt)
function Kit.title(name, lines)
    local h = 78 + #lines * 18 + 14
    Kit.panel(46, 42, 308, h)
    Kit.bigCentered(name, 50, 3)
    for i, line in ipairs(lines) do
        Kit.centered(line, 94 + i * 18)
    end
end

-- game-over screen: big reason + sub lines
function Kit.over(reason, lines)
    Kit.panel(78, 70, 244, 50 + #lines * 18)
    Kit.bigCentered(reason, 80, 2)
    for i, line in ipairs(lines) do
        Kit.centered(line, 98 + i * 18)
    end
end

-- ---- toast: one transient status line ("Got 3 Herbs") ---------------

Kit.toastT, Kit.toastMsg = 0, ""

function Kit.toast(text, secs)
    Kit.toastMsg = text
    Kit.toastT = secs or 2
end

function Kit.drawToast()
    local w = gfx.getTextSize(Kit.toastMsg)
    local x = math.floor((400 - w) / 2)
    Kit.panel(x - 8, 212, w + 16, 24)
    Kit.text(Kit.toastMsg, x, 216)
end

-- ---- debris particles ---------------------------------------------
-- 2x2 squares with velocity, a lifetime and (optionally) a floor to
-- bounce off with friction. 60 cap per list.

function Kit.spawnPart(list, x, y, spread, up)
    if #list > 60 then return end
    list[#list + 1] = {
        x = x, y = y,
        vx = (math.random() - 0.5) * (spread or 90),
        vy = (math.random() - 0.5) * (spread or 90) - (up or 0),
        t = 0.35 + math.random() * 0.35,
        white = math.random() < 0.5,
    }
end

function Kit.burst(list, x, y, n, spread, up)
    for _ = 1, n do Kit.spawnPart(list, x, y, spread, up) end
end

-- floorY (optional): particles bounce there, vy * -0.4, vx * 0.6
function Kit.updateParts(list, dt, gravity, floorY)
    for i = #list, 1, -1 do
        local q = list[i]
        q.t = q.t - dt
        q.vy = q.vy + (gravity or 0) * dt
        q.x = q.x + q.vx * dt
        q.y = q.y + q.vy * dt
        if floorY and q.y > floorY and q.vy > 0 then
            q.y = floorY
            q.vy = -q.vy * 0.4
            q.vx = q.vx * 0.6
        end
        if q.t <= 0 then table.remove(list, i) end
    end
end

function Kit.drawParts(list)
    for i = 1, #list do
        local q = list[i]
        gfx.setColor(q.white and gfx.kColorWhite or gfx.kColorBlack)
        gfx.fillRect(math.floor(q.x), math.floor(q.y), 2, 2)
    end
end

-- ---- screen shake ---------------------------------------------------
-- Kit.shake(0.25) on impacts; Kit.run ticks it. Cam.apply folds
-- Kit.sx/sy into the world draw offset.

Kit.shakeT, Kit.sx, Kit.sy = 0, 0, 0

function Kit.shake(t)
    Kit.shakeT = math.max(Kit.shakeT, t)
end

function Kit.updateShake(dt)
    Kit.shakeT = math.max(0, Kit.shakeT - dt)
    if Kit.shakeT > 0 then
        Kit.sx = math.random(-2, 2)
        Kit.sy = math.random(-2, 2)
    else
        Kit.sx, Kit.sy = 0, 0
    end
end

-- bold player locator: bobbing black-outlined white chevron above
-- (x, y), drawn after the overhead layer so the player never vanishes
function Kit.marker(x, y, t)
    local sy = math.floor(y + math.sin((t or 0) * 5) * 2 + 0.5)
    x = math.floor(x + 0.5)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillTriangle(x - 5, sy - 8, x + 5, sy - 8, x, sy)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillTriangle(x - 3, sy - 7, x + 3, sy - 7, x, sy - 2)
end

-- ---- the cabinet ---------------------------------------------------
-- Kit.run{ init=, extra=, shotPath= }: the shared main loop. Owns the
-- refresh rate (30, unthrottled in smoke), the random seed, Harness
-- wiring and the frame counter. Per frame: Input.poll (if defined),
-- shake + toast timers, TOP state update, pending callbacks, then the
-- draw pass from the lowest non-covered state up; updMs/drwMs EMAs
-- fold into the smoke heartbeat. init MUST push the first state.
function Kit.run(opts)
    playdate.display.setRefreshRate(SMOKE_BUILD and 0 or 30)
    math.randomseed(playdate.getSecondsSinceEpoch())
    if opts.init then opts.init() end
    assert(#Kit.stack > 0, "Kit.run: init must Kit.push a state")
    if Harness.enabled then
        Harness.extra = opts.extra
        if opts.shotPath and playdate.simulator then
            Harness.shotPath = opts.shotPath
        end
    end
    local frame = 0
    local updMs, drwMs = 0, 0
    local function tick()
        local dt = (C and C.DT) or 1 / 30
        if Input and Input.poll then Input.poll() end
        playdate.resetElapsedTime()
        Kit.updateShake(dt)
        if Kit.toastT > 0 then Kit.toastT = Kit.toastT - dt end
        local top = Kit.top()
        if top and top.update then top.update(dt) end
        Util.runPending(dt)
        if Kit.fxUpdate then Kit.fxUpdate(dt) end
        updMs = updMs * 0.95 + playdate.getElapsedTime() * 50
        playdate.resetElapsedTime()
        local n = #Kit.stack
        local lo = n
        while lo > 1 and Kit.stack[lo].translucent do lo = lo - 1 end
        for i = lo, n do
            local st = Kit.stack[i]
            if st.draw then st.draw() end
        end
        if Kit.fxDraw then Kit.fxDraw() end
        if Kit.toastT > 0 then Kit.drawToast() end
        drwMs = drwMs * 0.95 + playdate.getElapsedTime() * 50
        Harness.set("updMs", math.floor(updMs * 10) / 10)
        Harness.set("drwMs", math.floor(drwMs * 10) / 10)
    end
    function playdate.update()
        frame = frame + 1
        Harness.frame(frame, tick)
    end
end

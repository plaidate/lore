-- Lore core: the camera. Cam.x/y is the viewport's world top-left;
-- Cam.apply routes world drawing through setDrawOffset (with Kit's
-- shake), Cam.done returns to screen space for HUD/UI. follow() is an
-- exponential chase clamped to the map; panTo() is the scripted pan
-- for cutscenes — while Cam.panning, follow() yields to the pan.

local gfx = playdate.graphics

Cam = { x = 0, y = 0, panning = false }

local px, py, pspeed = 0, 0, 0

local function clampX(x)
    return Util.clamp(x, 0, math.max(0, Map.PW - 400))
end

local function clampY(y)
    return Util.clamp(y, 0, math.max(0, Map.PH - 240))
end

function Cam.reset()
    Cam.x, Cam.y, Cam.panning = 0, 0, false
end

-- snap the viewport onto a world point (map entry, respawn)
function Cam.center(wx, wy)
    Cam.x = clampX(wx - 200)
    Cam.y = clampY(wy - 120)
end

-- smooth-follow a world point; call once per frame. No-op mid-pan.
function Cam.follow(wx, wy, dt, rate)
    if Cam.panning then return end
    local k = math.min(1, (rate or 6) * dt)
    Cam.x = Cam.x + (clampX(wx - 200) - Cam.x) * k
    Cam.y = Cam.y + (clampY(wy - 120) - Cam.y) * k
end

-- scripted pan: glide until (wx, wy) is centered, speed in px/s
function Cam.panTo(wx, wy, speed)
    px, py = clampX(wx - 200), clampY(wy - 120)
    pspeed = speed or 120
    Cam.panning = true
end

-- advance an active pan; call once per frame (before follow)
function Cam.update(dt)
    if not Cam.panning then return end
    local dx, dy = px - Cam.x, py - Cam.y
    local d = math.sqrt(dx * dx + dy * dy)
    local step = pspeed * dt
    if d <= step then
        Cam.x, Cam.y, Cam.panning = px, py, false
    else
        Cam.x = Cam.x + dx / d * step
        Cam.y = Cam.y + dy / d * step
    end
end

-- start drawing the world (integer offset + Kit's screen shake)
function Cam.apply()
    gfx.setDrawOffset(Kit.sx - math.floor(Cam.x + 0.5),
        Kit.sy - math.floor(Cam.y + 0.5))
end

-- back to screen space (HUD, dialog, overlays)
function Cam.done()
    gfx.setDrawOffset(0, 0)
end

-- world-space viewport rect, for culling
function Cam.view()
    return Cam.x, Cam.y, Cam.x + 400, Cam.y + 240
end

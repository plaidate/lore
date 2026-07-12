-- Lore core: math helpers and the delayed-call scheduler (fleet
-- standard). Util.runPending is reentrancy-safe: callbacks may call
-- Util.after or Util.clearPending mid-scan without corrupting the list.

Util = {}

function Util.clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi else return v end
end

-- NB: Util.sign(0) == 0, which never matches a +/-1 facing check.
function Util.sign(v)
    if v > 0 then return 1 elseif v < 0 then return -1 else return 0 end
end

function Util.lerp(a, b, t)
    return a + (b - a) * t
end

function Util.dist2(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return dx * dx + dy * dy
end

function Util.choose(list)
    return list[math.random(#list)]
end

-- d-pad as a movement vector: -1/0/1 per axis
function Util.dpad()
    local pd = playdate
    local mx, my = 0, 0
    if pd.buttonIsPressed(pd.kButtonLeft) then mx = -1 end
    if pd.buttonIsPressed(pd.kButtonRight) then mx = 1 end
    if pd.buttonIsPressed(pd.kButtonUp) then my = -1 end
    if pd.buttonIsPressed(pd.kButtonDown) then my = 1 end
    return mx, my
end

local pending = {}

function Util.after(delay, fn)
    pending[#pending + 1] = { t = delay, fn = fn }
end

function Util.clearPending()
    pending = {}
end

function Util.runPending(dt)
    -- alias so a callback calling clearPending can't nil out mid-scan
    local list = pending
    local n = #list
    local w = 0
    for i = 1, n do
        local p = list[i]
        p.t = p.t - dt
        if p.t <= 0 then
            p.fn() -- fires in registration order; may append past n
        else
            w = w + 1
            list[w] = p
        end
    end
    -- slide anything appended during the scan down over expired slots
    local m = #list
    for i = n + 1, m do
        w = w + 1
        list[w] = list[i]
    end
    for i = w + 1, m do list[i] = nil end
end

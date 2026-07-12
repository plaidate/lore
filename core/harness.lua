-- Lore core: the smoke-test harness as a first-class module.
--
-- The Makefile stages smokeflag.lua into every build: SMOKE_BUILD=false
-- for release, true for `make <game>-smoke`. When off, everything here
-- is a no-op and games pay nothing. When on: counters, a pcall-wrapped
-- update writing the FIRST error to the "err" datastore, a 90-frame
-- heartbeat to "smoke", periodic PNG screenshots, and an autopilot hook
-- the game's input module consults.

import "smokeflag"

Harness = {
    enabled = SMOKE_BUILD,
    counters = {},
    autopilot = nil, -- game sets Harness.autopilot = function() ... end
    extra = nil,     -- optional fn(tbl) adding fields to the heartbeat
    shotPath = SMOKE_SHOT_PATH, -- abs host path injected by the Makefile
}

if Harness.enabled then
    playdate.datastore.delete("err") -- stale errors must not latch
end

function Harness.count(key, n)
    if not Harness.enabled then return end
    Harness.counters[key] = (Harness.counters[key] or 0) + (n or 1)
end

function Harness.set(key, val)
    if not Harness.enabled then return end
    Harness.counters[key] = val
end

local errLatched = false

-- wraps the real per-frame update; called by Kit.run
function Harness.frame(frame, updateFn)
    if not Harness.enabled then
        updateFn()
        return
    end
    local ok, err = pcall(updateFn)
    if not ok and not errLatched then
        errLatched = true -- keep the FIRST error, not the last
        playdate.datastore.write({ err = tostring(err) }, "err")
    end
    if frame % 90 == 0 then
        local t = {}
        for k, v in pairs(Harness.counters) do t[k] = v end
        t.frame = frame
        if Harness.extra then
            pcall(Harness.extra, t)
        end
        playdate.datastore.write(t, "smoke")
    end
    if Harness.shotPath and frame % 300 == 0 and playdate.simulator then
        playdate.simulator.writeToFile(
            playdate.graphics.getDisplayImage(), Harness.shotPath)
    end
end

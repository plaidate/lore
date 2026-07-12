-- Headless smoke: run a game's SMOKE build logic under system Lua 5.4
-- with a stubbed Playdate SDK — no Simulator. Drawing is no-op'd; the
-- datastore stub mimics JSON round-trip semantics (dict keys become
-- strings, arrays stay arrays), so save/load bugs surface here.
--
--   lua tools/headless.lua slice [frames]
--
-- Exits 0 and prints the final heartbeat + PASS when the run latches
-- no error and the game's expectations (EXPECT below) hold.

local game = arg[1] or "slice"
local FRAMES = tonumber(arg[2]) or 20000

-- per-game counter expectations (min values)
local EXPECT = {
    slice = {
        playDone = 1, loadOk = 1, chestsOpened = 1, saves = 2,
        saidLines = 4, menuOpens = 1, flagsSet = 2, laps = 1,
        toasts = 1,
        -- wave 3: turn battles, action combat, music
        encounters = 1, battles = 1, battlesWon = 1, levelUps = 1,
        swings = 1, actionKills = 1, stingers = 2, musicBars = 4,
    },
    shrew = {
        done = 1, bossDown = 1, boatUnlocked = 1, grams = 12,
        battles = 5, battlesWon = 5, encounters = 5, levelUps = 3,
        chestsOpened = 5, saves = 2, saidLines = 10, flagsSet = 4,
        stingers = 3, musicBars = 4, menuOpens = 1,
    },
    stoat = {
        done = 1, kingDown = 1, bossDown = 7, kills = 18,
        k_meadow = 6, k_thicket = 6, k_warren = 6,
        swings = 25, charges = 5, pounces = 1, actionKills = 18,
        saidLines = 6, menuOpens = 1, saves = 1, flagsSet = 5,
        stingers = 3, musicBars = 8,
    },
}

-- ---- SDK stub -------------------------------------------------------------

local function noop() end

local function newImage(w, h)
    return {
        width = w or 1, height = h or 1,
        draw = noop, drawScaled = noop, clear = noop,
    }
end

local gfx = {
    kColorBlack = 0, kColorWhite = 1, kColorClear = 2,
    kDrawModeCopy = 0, kDrawModeFillWhite = 1,
    image = { new = function(w, h) return newImage(w, h) end },
    pushContext = noop, popContext = noop,
    setColor = noop, setPattern = noop, setImageDrawMode = noop,
    fillRect = noop, drawRect = noop, drawLine = noop,
    drawPixel = noop, fillTriangle = noop, fillCircleAtPoint = noop,
    drawCircleAtPoint = noop, drawArc = noop,
    fillEllipseInRect = noop, fillRoundRect = noop,
    drawRoundRect = noop, setDrawOffset = noop,
    drawText = noop,
    getTextSize = function(s) return #tostring(s) * 7, 16 end,
    getDisplayImage = function() return newImage(400, 240) end,
}

-- JSON round trip: dict keys stringify, contiguous arrays survive
local function jsonify(v)
    if type(v) ~= "table" then return v end
    local n = 0
    for _ in pairs(v) do n = n + 1 end
    local isArray = n == #v
    local out = {}
    for k, val in pairs(v) do
        if isArray then
            out[k] = jsonify(val)
        else
            out[tostring(k)] = jsonify(val)
        end
    end
    return out
end

local disk = {}

-- silent synths (lmusic voices, lsnd pools)
local sound = {
    kWaveSquare = 0, kWaveTriangle = 1, kWaveSawtooth = 2,
    kWaveSine = 3, kWaveNoise = 4,
    synth = {
        new = function() return { playNote = noop } end,
    },
}

playdate = {
    graphics = gfx,
    sound = sound,
    datastore = {
        write = function(t, name)
            disk[name or "data"] = jsonify(t)
        end,
        read = function(name)
            local v = disk[name or "data"]
            return v and jsonify(v) or nil
        end,
        delete = function(name) disk[name or "data"] = nil end,
    },
    display = { setRefreshRate = noop },
    kButtonA = "a", kButtonB = "b", kButtonUp = "up",
    kButtonDown = "down", kButtonLeft = "left", kButtonRight = "right",
    buttonIsPressed = function() return false end,
    buttonJustPressed = function() return false end,
    getCrankTicks = function() return 0 end,
    getCrankChange = function() return 0, 0 end,
    getSecondsSinceEpoch = function()
        return tonumber(os.getenv("SEED")) or 12345
    end,
    resetElapsedTime = noop,
    getElapsedTime = function() return 0 end,
    simulator = nil,
}

-- ---- import shim ----------------------------------------------------------

local root = arg[0]:gsub("tools/headless%.lua$", "")
if root == arg[0] then root = "./" end
local loaded = {}

function import(name)
    if loaded[name] then return end
    loaded[name] = true
    if name == "smokeflag" or name:find("^CoreLibs/") then return end
    local paths = {
        root .. "core/" .. name .. ".lua",
        root .. "games/" .. game .. "/" .. name .. ".lua",
    }
    for _, p in ipairs(paths) do
        local f = io.open(p, "r")
        if f then
            f:close()
            dofile(p)
            return
        end
    end
    error("import: cannot find " .. name)
end

SMOKE_BUILD = true
SMOKE_SHOT_PATH = nil

-- ---- run ------------------------------------------------------------------

import("main")

for _ = 1, FRAMES do
    playdate.update()
end

local err = disk["err"]
local beat = disk["smoke"] or {}
local keys = {}
for k in pairs(beat) do keys[#keys + 1] = k end
table.sort(keys)
for _, k in ipairs(keys) do
    print(string.format("  %-14s %s", k, tostring(beat[k])))
end
if err then
    print("FAIL: latched error: " .. tostring(err.err))
    os.exit(1)
end
local bad = false
for k, want in pairs(EXPECT[game] or {}) do
    local got = tonumber(beat[k]) or 0
    if got < want then
        print(string.format("FAIL: %s = %s, want >= %s", k, got, want))
        bad = true
    end
end
if bad then os.exit(1) end
print("PASS (" .. FRAMES .. " frames)")

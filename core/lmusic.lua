-- Lore core: pattern+order-list music — dither's 16-step sequencer
-- grown tracker arms, because RPGs need LONG songs. A SONG:
--
--   { tempo = 104,               -- bpm; steps are sixteenth notes
--     voices = { bass = "tri" }, -- optional per-voice wave override
--                                -- (square/tri/saw/sine/noise)
--     patterns = {
--       A = { bass = {16 midi notes, 0 = rest},
--             lead = {...}, pad = {...}, hat = {...} },
--       B = { ... } },
--     order = { "A", "A", "B" } }  -- pattern sequence; loops
--
-- Four voices, fleet-quiet mix: bass (tri .12), lead (square .07),
-- pad (sine .05), hat (noise tick .04). Clock-driven — accumulate
-- dt, fire steps on beat boundaries, zero drift — and ticked from
-- Kit.fxUpdate (chained after lui's), so music runs under EVERY
-- state: field, script, windows, battles.
--
--   Music.play(song)          start a song from the top
--   Music.stop()              silence (also clears the saved slot)
--   Music.stinger(song, once) interrupt: SAVES the current song +
--                             position (once only — chained
--                             stingers keep the original save, so
--                             battle jingle -> victory fanfare
--                             still resumes the FIELD song); with
--                             once=true the stinger auto-resumes
--                             after one pass of its order list
--   Music.resume()            restore the saved song where it left
--
-- Counters: musicBars (pattern starts), stingers.

Music = {}

local snd = playdate.sound

local WAVE = {
    square = snd.kWaveSquare,
    tri = snd.kWaveTriangle,
    saw = snd.kWaveSawtooth,
    sine = snd.kWaveSine,
    noise = snd.kWaveNoise,
}

local VOICES = { "bass", "lead", "pad", "hat" }
local DEFWAVE = { bass = "tri", lead = "square",
    pad = "sine", hat = "noise" }
local VOL = { bass = 0.12, lead = 0.07, pad = 0.05, hat = 0.04 }
local SUS = { bass = 1.8, lead = 0.9, pad = 1.4, hat = 0.3 }

-- midi note -> Hz
function Music.midihz(n)
    return 440 * 2 ^ ((n - 69) / 12)
end

-- lazily-built synths, one per (voice, wave) pair
local synths = {}

local function synthFor(voice, wave)
    local key = voice .. wave
    local s = synths[key]
    if not s then
        s = snd.synth.new(WAVE[wave] or WAVE.square)
        synths[key] = s
    end
    return s
end

local cur = nil   -- { song, orderI, stepI, clock, once, stinger }
local saved = nil -- the interrupted song's playhead

local function start(song, once, stinger)
    cur = { song = song, orderI = 1, stepI = 0, clock = 0,
        once = once or false, stinger = stinger or false }
end

function Music.play(song)
    saved = nil
    start(song)
end

function Music.stop()
    cur, saved = nil, nil
end

function Music.stinger(song, once)
    Harness.count("stingers")
    if cur and not cur.stinger then saved = cur end
    start(song, once, true)
end

function Music.resume()
    cur = saved
    saved = nil
end

function Music.update(dt)
    local c = cur
    if not c then return end
    local song = c.song
    local stepDur = 60 / song.tempo / 4
    c.clock = c.clock + dt
    while c.clock >= stepDur do
        c.clock = c.clock - stepDur
        c.stepI = c.stepI + 1
        if c.stepI > 16 then
            c.stepI = 1
            c.orderI = c.orderI + 1
            if c.orderI > #song.order then
                if c.once then
                    Music.resume()
                    return
                end
                c.orderI = 1
            end
        end
        if c.stepI == 1 then Harness.count("musicBars") end
        local pat = song.patterns[song.order[c.orderI]]
        if pat then
            for i = 1, 4 do
                local v = VOICES[i]
                local line = pat[v]
                local n = line and line[c.stepI]
                if n and n ~= 0 then
                    local wave = (song.voices and song.voices[v])
                        or DEFWAVE[v]
                    local s = synthFor(v, wave)
                    if v == "hat" then
                        s:playNote(4000, VOL.hat, stepDur * SUS.hat)
                    else
                        s:playNote(Music.midihz(n), VOL[v],
                            stepDur * SUS[v])
                    end
                end
            end
        end
    end
end

-- tick above the whole state stack (after lui's popup/fade fx)
local prevFx = Kit.fxUpdate
Kit.fxUpdate = function(dt)
    if prevFx then prevFx(dt) end
    Music.update(dt)
end

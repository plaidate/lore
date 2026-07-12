-- Shrew music: lmusic pattern+order songs. Three map themes — a
-- pastoral overworld round (A A B C), the Voleholm waltz (A B, an
-- oom-pah-pah lilt), the Burrow drone (A B over a low pad) — plus
-- the battle stinger, the Mole Tyrant's own heavier stinger, and
-- the once-through victory fanfare that hands back to the field
-- song mid-phrase. Notes are midi numbers, 0 = rest.

Sfx = {}

Sfx.songs = {
    overworld = { -- pastoral: C major stroll, A A B C
        tempo = 96,
        patterns = {
            A = {
                bass = { 36, 0, 0, 0, 43, 0, 0, 0,
                    45, 0, 0, 0, 41, 0, 43, 0 },
                lead = { 60, 0, 64, 0, 67, 0, 64, 0,
                    69, 0, 67, 0, 65, 64, 62, 0 },
                hat = { 1, 0, 0, 0, 1, 0, 0, 0,
                    1, 0, 0, 0, 1, 0, 0, 0 },
            },
            B = {
                bass = { 41, 0, 0, 0, 43, 0, 0, 0,
                    36, 0, 0, 0, 43, 0, 41, 0 },
                lead = { 65, 0, 69, 0, 72, 0, 69, 0,
                    67, 0, 64, 0, 62, 64, 65, 0 },
                hat = { 1, 0, 0, 0, 1, 0, 0, 0,
                    1, 0, 0, 0, 1, 0, 1, 0 },
            },
            C = {
                bass = { 33, 0, 0, 0, 41, 0, 0, 0,
                    43, 0, 0, 0, 43, 0, 0, 0 },
                lead = { 64, 0, 65, 0, 64, 0, 62, 0,
                    60, 0, 62, 0, 64, 0, 0, 0 },
                pad = { 57, 0, 0, 0, 0, 0, 0, 0,
                    55, 0, 0, 0, 0, 0, 0, 0 },
                hat = { 1, 0, 0, 0, 1, 0, 0, 0,
                    1, 0, 0, 0, 1, 0, 0, 0 },
            },
        },
        order = { "A", "A", "B", "C" },
    },
    town = { -- Voleholm waltz: oom-pah-pah in G, A B
        tempo = 84,
        patterns = {
            A = {
                bass = { 43, 0, 0, 47, 0, 50, 0, 0,
                    38, 0, 0, 45, 0, 50, 0, 0 },
                lead = { 71, 0, 0, 0, 74, 0, 72, 0,
                    69, 0, 0, 0, 72, 0, 71, 0 },
                pad = { 59, 0, 0, 0, 0, 0, 0, 0,
                    57, 0, 0, 0, 0, 0, 0, 0 },
            },
            B = {
                bass = { 48, 0, 0, 52, 0, 55, 0, 0,
                    43, 0, 0, 47, 0, 50, 0, 0 },
                lead = { 76, 0, 0, 0, 74, 0, 72, 0,
                    71, 0, 72, 0, 74, 0, 0, 0 },
                pad = { 60, 0, 0, 0, 0, 0, 0, 0,
                    59, 0, 0, 0, 0, 0, 0, 0 },
            },
        },
        order = { "A", "B" },
    },
    burrow = { -- the Burrow drone: low, padded, patient
        tempo = 70,
        voices = { lead = "sine" },
        patterns = {
            A = {
                bass = { 31, 0, 0, 0, 0, 0, 0, 0,
                    31, 0, 0, 0, 34, 0, 0, 0 },
                pad = { 43, 0, 0, 0, 0, 0, 0, 0,
                    46, 0, 0, 0, 0, 0, 0, 0 },
                lead = { 0, 0, 0, 0, 58, 0, 0, 0,
                    0, 0, 55, 0, 0, 0, 0, 0 },
            },
            B = {
                bass = { 29, 0, 0, 0, 0, 0, 0, 0,
                    31, 0, 0, 0, 0, 0, 0, 0 },
                pad = { 41, 0, 0, 0, 0, 0, 0, 0,
                    43, 0, 0, 0, 0, 0, 0, 0 },
                lead = { 0, 0, 0, 0, 53, 0, 0, 0,
                    0, 0, 56, 0, 55, 0, 0, 0 },
            },
        },
        order = { "A", "B" },
    },
    battle = { -- field scrap stinger
        tempo = 144,
        patterns = {
            A = {
                bass = { 33, 0, 33, 0, 31, 0, 31, 0,
                    33, 0, 33, 0, 36, 0, 35, 0 },
                lead = { 69, 0, 0, 68, 69, 0, 72, 0,
                    67, 0, 0, 66, 67, 0, 71, 0 },
                hat = { 1, 0, 1, 0, 1, 0, 1, 0,
                    1, 0, 1, 0, 1, 1, 1, 0 },
            },
        },
        order = { "A" },
    },
    boss = { -- the Mole Tyrant: heavier, lower, faster
        tempo = 152,
        patterns = {
            A = {
                bass = { 29, 29, 0, 29, 32, 0, 29, 0,
                    28, 28, 0, 28, 31, 0, 28, 0 },
                lead = { 65, 0, 64, 0, 65, 0, 68, 0,
                    64, 0, 63, 0, 64, 0, 67, 0 },
                hat = { 1, 1, 0, 1, 1, 0, 1, 0,
                    1, 1, 0, 1, 1, 1, 1, 0 },
            },
            B = {
                bass = { 27, 27, 0, 27, 29, 0, 27, 0,
                    32, 32, 0, 32, 34, 0, 35, 0 },
                lead = { 63, 0, 62, 0, 63, 0, 65, 0,
                    68, 0, 67, 0, 68, 0, 71, 0 },
                hat = { 1, 1, 0, 1, 1, 0, 1, 0,
                    1, 1, 0, 1, 1, 1, 1, 0 },
            },
        },
        order = { "A", "B" },
    },
    fanfare = { -- once through, then the map song picks back up
        tempo = 120,
        patterns = {
            A = {
                bass = { 48, 0, 0, 0, 48, 0, 0, 0,
                    43, 0, 0, 0, 48, 0, 0, 0 },
                lead = { 72, 0, 72, 0, 72, 0, 76, 0,
                    79, 0, 0, 0, 76, 0, 79, 0 },
            },
        },
        order = { "A", "A" },
    },
}

-- map name -> theme
Sfx.mapSong = {
    world = "overworld", town = "town",
    burrow1 = "burrow", burrow2 = "burrow",
}

-- play a map's theme, but never restart the one already playing
function Sfx.playFor(mapName)
    local id = Sfx.mapSong[mapName]
    if not id or G.curSong == id then return end
    G.curSong = id
    Music.play(Sfx.songs[id])
end

function Sfx.chestJingle()
    Snd.play("tri", 660, 0.08, 0.2)
    Util.after(0.09, function() Snd.play("tri", 880, 0.12, 0.2) end)
end

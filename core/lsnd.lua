-- Lore core: synth SFX (fleet port from dither). One
-- playdate.sound.synth per wave covers a whole game's sounds; a
-- small round-robin pool per wave lets effects overlap. Mixed
-- louder than the music (which sits fleet-quiet underneath).

Snd = {}

local snd = playdate.sound
local waves = {
    square = snd.kWaveSquare,
    tri = snd.kWaveTriangle,
    saw = snd.kWaveSawtooth,
    noise = snd.kWaveNoise,
}

local pools = {}
local idx = {}

function Snd.play(wave, freq, dur, vol)
    local pool = pools[wave]
    if not pool then
        pool = {}
        for i = 1, 3 do pool[i] = snd.synth.new(waves[wave]) end
        pools[wave] = pool
        idx[wave] = 0
    end
    idx[wave] = idx[wave] % 3 + 1
    pool[idx[wave]]:playNote(freq, vol or 0.25, dur or 0.1)
end

-- descending noise sweep (explosions, deaths)
function Snd.boom(freq, n)
    for i = 0, (n or 3) - 1 do
        Util.after(i * 0.05, function()
            Snd.play("noise", (freq or 220) * (1 - i * 0.2),
                0.08, 0.3)
        end)
    end
end

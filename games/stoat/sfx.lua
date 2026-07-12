-- Stoat sfx: named one-shots over the Snd pools. The engine already
-- voices swings/hits/hurts inside laction; these cover the game
-- layer's own moves (pounce, spits, growl/groom, pickups, gates).

Sfx = {}

function Sfx.pounce()
    Snd.play("saw", 180, 0.1, 0.3)
    Snd.play("noise", 500, 0.06, 0.2)
end

function Sfx.hit()
    Snd.play("noise", 420, 0.06, 0.25)
end

function Sfx.hurt()
    Snd.play("noise", 240, 0.1, 0.3)
end

function Sfx.spit()
    Snd.play("square", 900, 0.05, 0.12)
end

function Sfx.pickup()
    Snd.play("tri", 880, 0.06, 0.2)
    Util.after(0.07, function()
        Snd.play("tri", 1320, 0.08, 0.2)
    end)
end

function Sfx.growl()
    Snd.play("saw", 110, 0.25, 0.35)
end

function Sfx.groom()
    Snd.play("tri", 520, 0.12, 0.2)
    Util.after(0.1, function()
        Snd.play("tri", 660, 0.12, 0.2)
    end)
end

function Sfx.gate()
    Snd.boom(300, 3)
end

-- Slice — the Lore engine's vertical-slice dev game (and its living
-- demo): a 120x90 chunk-cached overworld, a free-walking white-rigged
-- player, NPCs, a canopy walk-behind band — plus the wave-2 story
-- systems: a talkable guard, a scripted shrine scene, a merchant
-- shop, a persistent chest, the pause menu and save/load — and the
-- wave-3 combat proof: a one-walker Party, random lturn encounters
-- in the meadow, a stick-armed laction hunt for the forest roamer,
-- lmusic field song + battle stinger + fanfare. The smoke autopilot
-- BEATS all of it (playthrough script + battle windows + field
-- phases), then laps the ring road forever.
--
--   config.lua   C: tunables
--   game.lua     G + Game: worldgen, rigs, story, simulation
--   input.lua    Input: d-pad/buttons + smoke autopilot + playthrough
--   draw.lua     Draw: the field frame

import "lib"

import "config"
import "game"
import "input"
import "draw"

Kit.run{
    init = function()
        Game.init()
        Kit.push(G.field)
        if Harness.enabled then
            Util.after(1, Game.playthrough)
        end
    end,
    extra = function(t)
        t.steps = G.player.steps
        t.chunkBuilds = Map.builds
        t.px = math.floor(G.player.x)
        t.py = math.floor(G.player.y)
        t.wp = Input.wp
        t.gold = State.gold
        t.stack = #Kit.stack
        local m = Party.member(1)
        if m then
            t.lvl = m.lvl
            t.php = m.hp
        end
    end,
}

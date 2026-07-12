-- SHREW — the Lore engine's turn-based proof game (Dragon Quest
-- grammar). Pip, a shrew knight, must eat half her body weight —
-- 12 grams — by dawn; defeated bugs are dinner. One overworld with
-- a boat-gated river, VOLEHOLM, the two-floor Burrow, the Mole
-- Tyrant. The smoke autopilot beats the whole quest.
--
--   config.lua     C: tunables + the XP/grams tuning table
--   gamestate.lua  G/GS: grams meter, save position, death flow
--   maps.lua       the three map defs + legends
--   content.lua    ITEMS / SKILLS / BESTIARY / zones / Pip
--   sfx.lua        songs (3 themes, 2 stingers, fanfare)
--   script.lua     story beats + intro/ending
--   game.lua       boot, loader, battle seam, field update
--   input.lua      Input contract + the playthrough autopilot
--   draw.lua       the field frame + HUD

import "lib"

import "config"
import "gamestate"
import "maps"
import "content"
import "sfx"
import "script"
import "game"
import "input"
import "draw"

Kit.run{
    init = Game.init,
    extra = function(t)
        t.grams = GS.grams()
        t.chests = Harness.counters.chestsOpened or 0
        t.map = G.mapName
        t.stack = #Kit.stack
        if G.player then
            t.px, t.py = G.player.cellX, G.player.cellY
            t.steps = G.player.steps
        end
        local m = Party.member(1)
        if m then
            t.lvl = m.lvl
            t.php = m.hp
            t.pmp = m.mp
        end
        t.gold = State.gold
    end,
}

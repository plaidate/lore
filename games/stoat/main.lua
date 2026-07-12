-- Stoat — Lore's action proof game (Secret of Mana grammar).
-- Ermine the stoat, in winter coat, drives the rat clan from three
-- connected field zones (meadow -> thicket -> warren, one chunked
-- 140x60 map) before the thaw ruins the larders: swing/charge/
-- pounce field combat on the shared lparty sheet, a kill quota per
-- zone that draws out a captain, gates cleared by Map.set, the
-- pause-menu stack (Items/Status/Save/Skills/Equip), a den map with
-- a moss-bed heal, and the Rat King's scripted MID-FIGHT parley —
-- the CT nod, free because laction freezes under lscript.
--
--   config.lua     C: tunables
--   gamestate.lua  G: shared blackboard, zones, pools
--   content.lua    rigs, rat art, ITEMS/SKILLS/BESTIARY, songs
--   maps.lua       world gen, den, legend, gates
--   sfx.lua        game-layer one-shots
--   script.lua     Story: intro/parley/ending/death + attach points
--   game.lua       Game: sim, pounce, slingers, king, menus
--   input.lua      Input: the mapping + the campaign autopilot
--   draw.lua       Draw: the frame + HUD

import "lib"

import "config"
import "gamestate"
import "content"
import "maps"
import "sfx"
import "script"
import "game"
import "input"
import "draw"

Kit.run{
    init = function()
        Game.init()
        Kit.push(G.title)
    end,
    extra = function(t)
        t.map = G.mapName
        t.phase = Input.phase
        t.gold = State.gold
        t.stack = #Kit.stack
        t.chunkBuilds = Map.builds
        if G.player then
            t.px = math.floor(G.player.x)
            t.py = math.floor(G.player.y)
            t.zone = G.zoneAt(G.player.cellX)
        end
        local m = Party.member(1)
        if m then
            t.lvl = m.lvl
            t.php = m.hp
            t.pmp = m.mp
        end
    end,
}

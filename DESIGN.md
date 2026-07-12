# Lore — the RPG engine

## The thesis

The fleet's engines own rendering ideas: lines, grid, volume, shade.
Lore owns **story state over a world**: the machinery that makes a
16-bit-era RPG — a big walkable world, people to talk to, a party
that grows, and battles in two grammars (real-time action in the
field, Secret of Mana; menu-driven turns in a scene, Dragon Quest /
Final Fantasy — with Chrono Trigger's on-map battles reachable as a
hybrid of the two). Everything renders on the Playdate's 1-bit
screen with the fleet's palette discipline; everything is data-driven
tables so a game is mostly content, not code.

A game earns Lore if it needs persistent story state — flags, a
party, an inventory that survives a save. A game that just wants a
tile world belongs in tiles.

## The five hard problems (and their answers)

1. **An overworld is too big to pre-render.** tiles' one-blit
   background works because rooms are screen-sized. A 200x200-tile
   overworld is a 3200x3200 image. Answer: **chunked pre-render** —
   the world renders into screen-sized chunks on demand, kept in a
   small LRU cache (9 chunks covers any camera position + scroll);
   drawing is still 1-4 blits/frame, and Map.set repaints within a
   cached chunk exactly like tiles.
2. **RPG flow is a stack, not a mode string.** Opening the menu
   pauses the field; a dialog can open a choice which opens a shop.
   Answer: the cabinet runs a **state stack** (push/pop of
   update/draw pairs); field keeps drawing under a dialog box.
3. **Cutscenes are sequential; game loops are not.** Answer:
   **coroutine scripts** — an event is plain Lua run in a coroutine
   that yields while the engine walks an NPC, types a line, or fades;
   `say`, `walk`, `face`, `give`, `battle`, `iff` read like a
   screenplay. The same runner drives the smoke autopilot: a
   playthrough is just another script.
4. **Two battle grammars, one character sheet.** Answer: stats,
   skills, items, and damage math live in **lparty**, shared by both
   battle modules. A game picks its grammar per encounter: `lturn`
   (scene-swap, menu commands, SPD-ordered turns) or `laction`
   (field hitboxes, cooldown ring, knockback). Chrono-style = laction
   movement + lturn command windows on the field; the pieces compose.
5. **RPGs need long music.** The fleet's 16-step loops read as
   jingles. Answer: **lmusic** extends the step sequencer with
   *patterns + an order list* (tracker-style: A A B C), per-song
   voices, and interrupt/resume (battle fanfare cuts in, map theme
   resumes where it left).

## Core modules (dependency order)

- **`lutil.lua` (Util)** — clamp/sign/lerp + the deferred scheduler
  (fleet standard).
- **`lgfx.lua` (Gfx)** — 1-bit kit: the fleet ramp table (8 dither
  levels, opaque + overlay forms), white-text helpers, the palette
  rules as defaults (white player, dark NPCs w/ eye pixel, mid-gray
  terrain).
- **`lmap.lua` (Map)** — layered tile worlds: legend (char -> tile
  def: art fn, solid, water, speed, encounter zone, trigger id,
  overhead flag), rows-as-strings maps, TWO layers (ground +
  overhead canopy drawn after actors for walk-behind), chunked
  pre-render + LRU cache (default 9 chunks), `Map.set` single-cell
  repaint, `Map.load(name)` switching with per-map persistent state
  hooks. Tile art is procedural (16px fns) per fleet style.
- **`lcam.lua` (Cam)** — clamped smooth-follow camera over
  setDrawOffset (tcam descendant), plus scripted pans for cutscenes.
- **`lact.lua` (Act)** — actors: 4-direction, 2-frame procedural
  walk cycles built once into images; free movement w/ AABB vs tile
  solids (action games) or grid-step movement (classic feel) — both
  provided; NPC behaviors (stand/wander/patrol/follow); interaction
  (facing tile probe) and step-on triggers; painter-sorted draw with
  the overhead layer.
- **`lstate.lua` (State)** — the story ledger: flags, counters,
  party roster, inventory, gold, chest/door persistence keyed by
  map+cell, quest-stage helpers, SAVE/LOAD to datastore (versioned,
  string keys — the vault lesson), autosave hook at map changes.
- **`lscript.lua` (Script)** — coroutine event runner: primitives
  `say(who, text)`, `ask(text, options)`, `walk(actor, path|to)`,
  `face`, `wait`, `fade`, `pan`, `give/take(item|gold)`, `setflag`,
  `iff(flag)`, `battle(group)`, `warp(map, x, y)`, `shop(stock)`,
  `inn(price)`. Scripts attach to triggers, NPCs, map entry, story
  flags. One script runs at a time (RPG grammar); the stack pauses
  field control during scripted beats.
- **`lui.lua` (UI)** — the windowing system: bordered black panels
  w/ white text (DQ look), typewriter dialog box w/ B-skip and
  auto-pagination + word wrap, choice menus (nested, cancelable),
  the standard pause menu (Items / Magic / Equip / Status / Save),
  shop and inn flows, HP/MP bars, damage popups, toast lines
  ("Got 3 Herbs"). Crank scrolls long menus (house crank duty).
- **`lparty.lua` (Party)** — the character sheet: stats
  (HP/MP/ATK/DEF/AGI/LVL/XP w/ curve fns), party of 1-4, equipment
  slots w/ stat mods, items (heal/cure/key/gear), skills/spells
  (cost, power, target pattern, element), status effects
  (poison/sleep/guard), XP/level-up/learning, gold. All content =
  data tables (BESTIARY, ITEMS, SKILLS) games supply.
- **`lenc.lua` (Enc)** — encounters: per-zone random tables (steps +
  rate curve, DQ-style), or visible roamers on the map (CT-style)
  w/ chase AI that trigger on contact; repel/boat modifiers.
- **`lturn.lua` (Turn)** — turn-based battle scene: Fade-in swap,
  DQ front view (procedural enemy portraits, party status rows),
  command menu (Fight/Skill/Item/Guard/Run), AGI turn order,
  target selection, damage/miss/crit math from lparty, enemy AI
  patterns (attack/skill/heal-below-half), victory -> XP/gold/loot +
  level-up flow, defeat -> game-over hook. Scene owns its own draw;
  field is fully paused beneath.
- **`laction.lua` (Action)** — field combat: weapon swing arcs
  (hitbox by facing), swing cooldown w/ SoM-style charge meter
  (hold to charge %, crank optional wind-up), enemy field AI
  (aggro radius, telegraph, attack, knockback, iframes), same
  lparty damage math, drops on the spot, respawn rules per map.
- **`lmusic.lua` (Music)** — pattern+order-list sequencer (A A B C),
  4 voices, per-song tempo, `Music.play(song)`, `Music.stinger(j)`
  (interrupt w/ resume), fleet-quiet mix. **`lsnd.lua` (Snd)** —
  pools (fleet port).
- **`lkit.lua` (Kit)** — the cabinet: `Kit.run{}` main loop w/ the
  **state stack** (`Kit.push(state)/Kit.pop()`, states = {update,
  draw, translucent}), best/save plumbing deferred to lstate,
  shake/particles/marker, title/game-over screens.
- **`harness.lua`** — fleet smoke harness (first-error latch,
  heartbeat, screenshots) + the script-driven autopilot hook:
  smoke builds run a *playthrough script* through lscript.

## Proof games (both must be COMPLETABLE by their autopilot)

1. **`shrew`** — turn-based, Dragon Quest grammar. A shrew knight
   must eat half her body weight by dawn (shrews die if they don't):
   overworld (chunked, ~120x90 w/ forest/marsh encounter zones +
   a boat), one town (shop, inn, 5 NPCs w/ flag-gated dialogue),
   one 2-floor burrow dungeon w/ chests + locked door + boss (the
   Mole Tyrant), 5 enemy types, 4 spells, 8 items, levels 1-6,
   save/continue. Beatable in ~10 minutes; autopilot script beats
   it in smoke.
2. **`stoat`** — action, Secret of Mana grammar. A stoat in winter
   coat clears three field zones (meadow/thicket/warren) of an
   invading rat clan: swing/charge combat, 3 weapons (bite/pounce/
   tailwhip w/ different arcs), roaming enemies w/ telegraphs,
   herb pickups, one mini-boss per zone + rat king, the same pause
   menu/equip/save stack. CT-nod: the rat king fight uses scripted
   mid-fight dialogue via lscript.

Shared: both use the same lui/lstate/lparty/lmusic stacks — that
sharing IS the proof that the engine, not the game, owns the RPG.

## Non-goals

No general A* pathfinding beyond straight-line NPC walks (tiles owns
BFS if a game needs it). No procedural quest generation. No
multi-save slots in v1 (one save + autosave). No Mode-7 flying — the
boat is the vehicle story. Chrono-style dual/triple techs: the data
model allows them (skills w/ multi-actor cost) but no engine module;
a game composes them.

## Build order

1. Foundations: lutil/lgfx/lmap/lcam/lact + lkit/harness (a walkable
   chunked overworld with NPCs = the vertical slice).
2. Story: lstate/lscript/lui (talk, menu, save).
3. Sheet + battles: lparty/lenc/lturn/laction + lmusic/lsnd.
4. shrew, then stoat (or parallel once core is frozen).
5. Smoke: script-driven full playthroughs, screenshots eyeballed,
   launcher art, release.

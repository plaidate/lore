# Lore — Developer's Guide

The fleet's RPG engine: story state over a chunked tile world. Sister
repo to `tiles/` (screen-sized rooms) and `dither/` (whose collection
skeleton this copies). `DESIGN.md` is the binding contract; this file
grows with each wave. Waves 1 (foundations), 2 (story: state,
scripts, windows) and 3 (sheet, battles, music) are in.

## Philosophy

The engine owns the machinery of a 16-bit RPG — world, camera, actors,
state stack — as data-driven tables; a game is mostly content. Games
use globals-as-modules (`Util`, `Gfx`, `Map`, `Cam`, `Act`, `Kit`,
`Harness`, per-game `C`/`G`/`Game`/`Input`/`Draw`). Fixed 30fps,
`C.DT = 1/30`. Procedural art only; zero per-frame draw allocation.

## The shared core (`core/`)

- **`lib.lua`** — the one import a game starts with (dependency
  order).
- **`lutil.lua`** `Util` — clamp/sign/lerp/dist2/choose/dpad + the
  reentrancy-safe `after`/`runPending` scheduler.
- **`lgfx.lua`** `Gfx` — 8-level Bayer ramp: `Gfx.level(k)` opaque,
  `Gfx.over(k)` black-speckle overlay, `Gfx.fill`, `Gfx.text` (white).
  Palette rules live in its header.
- **`lmap.lua`** `Map` — legend + rows-as-strings worlds, chunked
  pre-render (416x256 chunks, 9-deep LRU, ~117KB), ground + overhead
  layers, `Map.set` single-cell repaint, queries
  (`get/solid/water/speed/zone/trigger/tileAt/cx/cy`), `Map.builds`
  stat.
- **`lcam.lua`** `Cam` — clamped smooth follow over `setDrawOffset`,
  `panTo` scripted pans, `apply`/`done` bracket world drawing.
- **`lact.lua`** `Act` — rigged actors, free AABB movement
  (`Act.walk`) and grid steps (`Act.stepTo`), behaviors
  (stand/wander/patrol/follow), `facingCell`, step-triggers,
  painter-sorted `drawAll`.
- **`lkit.lua`** `Kit` — the cabinet: the STATE STACK
  (`push/pop/top`, states = `{update=, draw=, translucent=}`; top
  updates, draw runs from the lowest non-covered state up),
  `Kit.run{init=, extra=, shotPath=}`, panels/text/toast/particles/
  shake/marker/title/over.
- **`harness.lua`** `Harness` — smoke harness: first-error latch,
  stale-err delete at boot, 90-frame heartbeat, screenshots to
  `SMOKE_SHOT_PATH`, autopilot slot.
- **`lstate.lua`** `State` — the story ledger: flags
  (`set/get/has`), named counters (`bump/counterOf`), `State.party`
  (member tables, schema owned by lparty), inventory
  (`add/take/count`), gold
  (`giveGold/takeGold`), chest persistence (`opened/markOpened`,
  string keys `"map:x:y"` — the vault lesson), quest `stage`,
  `save/load/hasSave/wipe` (datastore `"save"`, envelope `{v=1}`,
  all keys JSON-safe), `State.autosave` hook fired by `warp`.
- **`lui.lua`** `UI` — windows as translucent Kit states: `dialog`
  (typewriter, wrap, pagination), `choose`, `list`, `menu`
  (Items/Status/Save + `UI.addMenuSection`; `UI.menuActive`),
  `shop` (sell at half), `inn` (`UI.innHeal` hook), `hpBar`,
  pooled `popup` + `drawPopups` (world space, game's Draw calls
  it), `UI.fadeTo` (full-screen dither fade riding
  `Kit.fxUpdate/fxDraw`), `UI.goldStr` cached readout, `UI.wrap`.
  INPUT CONTRACT: windows read the game's `Input.a/b/up/down` as
  EDGE-TRIGGERED flags; the crank also scrolls lists. Every window
  exposes `st.ui/kind/sel/rows` so autopilots can steer it.
- **`lscript.lua`** `Script` — the coroutine event runner:
  `Script.run(fn)` (one at a time; pushes a translucent state that
  suppresses field update but keeps actors/camera alive), blocking
  primitives as globals — `say ask walk face wait fade pan panBack
  give giveGold takeGold setflag hasflag warp shop inn toast battle
  waituntil` (`battle` = `Script.battleHook`, wired to `Turn.start`
  by lturn; `warp` = `Script.loader` + autosave). Attach points:
  `onTrigger/onTalk/onEnter` + `Script.trigger/interact/enter`;
  handlers invoked inside a running script run INLINE (that's how a
  smoke playthrough calls story beats), engine-side dispatch while
  busy is dropped. `Script.followTarget` keeps the camera on the
  player during scripted walks.
- **`lparty.lua`** `Party` — the character sheet BOTH battle
  grammars share (the design point). Members live in `State.party`
  (save-safe tables; growth/learn defs in a side registry —
  `Party.add` every boot, it is load-idempotent). Content
  registries: `defineItems/defineSkills/defineBestiary` (schemas in
  the header). Canonical math: `Party.attack` (atk*2-def,
  +/-12.5%, crit 1/16 x1.5, miss = clamp(dAgi/(aAgi*16), 0, .5)),
  `Party.skillPower` (power +/- variance x elems multiplier),
  `Party.next(lvl) = 10*lvl^2`, `Party.giveXP` (growths + learned
  skills, lines into a caller array), statuses
  (poison/sleep/guard) + `stepTick`, derived `atkOf/defOf/agiOf`
  (equipment via ITEMS), `heal/restoreAll`. Wires the `UI.useItem`
  and `UI.innHeal` defaults.
- **`lenc.lua`** `Enc` — encounters: `Enc.zones(map, tbl)` ({zone ->
  rate/groups/weights}), `Enc.onStep(player)` (wire `a.onStep`;
  DQ curve: quiet 8 steps then chance = rate*(steps-7)*rateMul),
  `Enc.repel(steps)` + `Enc.rateMul` modifiers, `Enc.trigger`
  (weighted group -> `Script.battleHook`), CT roamers
  (`Enc.roamer` + `Enc.update`: wander -> aggro-chase -> contact
  triggers the same hook), `Enc.enter(map)` reset.
- **`lturn.lua`** `Turn` — the DQ battle scene: `Turn.start(group,
  opts, done)` pushes an OPAQUE state (field hidden + paused);
  pooled 48x48 portraits from bestiary `artFn`; command windows
  (`bcmd`/`btarget`/`bskill`/`bitem`) are Kit states above the
  scene speaking the lui Input contract + `st.kind/sel/rows`
  surface, so autopilots drive battles unchanged. AGI-jittered
  rounds, enemy ai basic/caster/sly, victory = timed message queue
  (xp/gold/drops/level-ups), run check, `Turn.defineGroups`,
  `Turn.defaults` ({music=, fanfare=}). Wires `Script.battleHook`.
- **`laction.lua`** `Action` — SoM field combat on the same sheet
  (player = `Party.member(1)`): `Action.define` weapons
  (arc len/wid, cooldown, charge time/mult), `Action.arm` (mirrors
  into `equip.weapon`), `Action.update(dt, held, player)`
  (hold-to-charge + crank wind-up, `Action.charge01` for the HUD),
  pooled hitbox, knockback/hitstop/iframes, foe AI (idle/chase/
  telegraph/lunge/recover), `Action.spawn` (bestiary, 16x16 artFn,
  drops, respawn, onDeath), `Action.onDown` hook, `Action.draw()`
  in the world bracket, `Action.reset()` on map change.
- **`lmusic.lua`** `Music` — pattern+order sequencer: songs =
  {tempo, voices?, patterns={A={bass/lead/pad/hat}}, order}, 4
  quiet voices, `play/stop`, `stinger(song, once)` (saves the
  interrupted playhead ONCE across chained stingers; once=true
  auto-`resume`s — battle jingle then victory fanfare then the
  field song picks up mid-phrase), ticks on a chained
  `Kit.fxUpdate` so it never pauses. **`lsnd.lua`** `Snd` — the
  fleet synth-pool port (`Snd.play`, `Snd.boom`).

## Per-game conventions

`games/<name>/` (lowercase; the dir name is the make target):
`main.lua` (imports + `Kit.run`), `config.lua` (`C`), `game.lua`
(`G` + `Game`), `input.lua` (`Input.poll`, autopilot when
`Harness.enabled`), `draw.lua` (`Draw.frame`), `pdxinfo` with
`bundleID=com.sdwfrost.lore.<name>`, `README.md` (stripped from
staging).

The canonical frame (see `games/slice/draw.lua`):
`Cam.apply` -> `Map.draw(Cam.x, Cam.y)` -> `Act.drawAll` ->
`Map.drawOverhead` -> `Action.draw` -> popups -> marker ->
`Cam.done` -> HUD. The field update calls `Action.update(dt,
Input.aHeld, player)` and `Enc.update(dt, player)`; the player
actor wires `onStep = Enc.onStep`.

## Build + smoke checklist

- `make <game>` / `make <game>-smoke` stage `core/*` + the game dir
  into `build/<g>/source`, write `smokeflag.lua`, run `pdc`.
- `tools/smoke.sh <game> [secs] [until-grep]` runs the Simulator
  headless, polls the datastore (`com.sdwfrost.lore.<game>`), copies
  the heartbeat to `results/`.
- `lua tools/headless.lua <game> [frames]` runs the same smoke build
  under system Lua 5.4 with a stubbed SDK (drawing no-op'd, datastore
  JSON semantics simulated) — catches script/state logic bugs in two
  seconds without the Simulator; per-game counter minimums live in
  its `EXPECT` table.
- Wire it: counters on everything that proves play (steps, laps,
  touches, toasts), `updMs`/`drwMs` come free from `Kit.run`,
  autopilot in `Input.poll`, LOOK AT THE SCREENSHOTS.
- Green bar for a wave: `make <game>` and `make <game>-smoke` compile,
  smoke run has no `err.json`, all counters advance.

## Per-game notes

- **slice** — the vertical slice and living engine demo: a 120x90
  hash-noise overworld with a stamped ring road, a canopy
  walk-behind band, and NPCs. Wave 2 gave it a story beat, all on
  the east road: a guard (talk -> "Follow me" escort via `walk`), a
  scripted shrine scene (pan/fade/`setflag`/toast), a merchant
  (3-item `shop`), one persistent chest, the pause menu and
  save/load. The smoke autopilot runs a full PLAYTHROUGH script
  (talk -> shrine -> buy torch -> chest -> menu Save -> load check
  -> `warp` home + autosave), steering every window through the
  synthetic edge-input path, then laps the ring forever;
  `chunkBuilds` growing past 9 per lap is the LRU cache proof.
  Counters: `saidLines flagsSet chestsOpened saves menuOpens loadOk
  playDone` on top of the wave-1 set. Wave 3 arms it: a one-walker
  Party (level 2 learns Gust), meadow/fern encounter zones (sod
  mite, bramble hare), `Turn.defaults` battle stinger + fanfare
  over an A A B field song, and a flag-gated bramble-hare roamer
  (`Action.spawn` + `onDeath` sets `roamer_dead`) killed by
  charged stick swings. The playthrough gains a meadow-pacing leg
  (the encounter interrupts the scripted walk and resumes it);
  then a field phase machine (`arm -> hunt -> finish`) does the
  laction proof before the finisher script warps home. New
  counters: `encounters battles battlesWon levelUps swings
  actionKills stingers musicBars` (+ `lvl`/`php` heartbeat
  fields).

## Wave-2 house lessons

- Windows freeze the world by construction: a dialog state sits
  ABOVE the script state, so `Script.tick` (and NPC behaviors) stop
  until it pops — no explicit pause flag anywhere.
- Story blocking bug to avoid: an escorted NPC parked on the
  player's walking line gets re-interacted by the probe's proximity
  fallback. Park escorts OFF the path column and flag-gate their
  re-talk line.
- The autopilot's only interface to windows is the same
  edge-triggered `Input` flags a thumb produces, plus the window's
  `st.kind/sel/rows` surface — keep both stable.

## Wave-3 house lessons

- An OPAQUE Kit state IS the battle swap: pushing `Turn.state`
  hides and pauses the field for free (top-only update + covered
  draw). A random encounter can fire mid-scripted-walk; the battle
  stacks above the script state, resolves, pops, and the walk
  resumes — no special casing anywhere.
- Field combat cannot run under a script (`Script.run` suppresses
  the field update that ticks `Action`). So the slice autopilot
  ends its script BEFORE the laction leg and drives the hunt from
  `Input.poll` phases (`Turn.active`/`Script.active` guards keep
  the phases quiet during battles/scripts).
- Anything that must tick under EVERY state (music!) chains onto
  `Kit.fxUpdate` — never a game update.
- `Music.stinger` saves the interrupted playhead only when the
  current song is not itself a stinger; that one rule makes
  jingle -> fanfare -> field-resume compose without a stack.
- Members must stay JSON-clean (the datastore round trip): keep
  growth/learn defs OUT of the member table (side registry keyed
  by id, re-registered every boot by `Party.add`).
- `laction` foes need the player reference before any weapon is
  armed — pass the player through `Action.update(dt, held, p)`,
  don't rely on `Action.arm` having run.

## Autopilot lesson: captains outrank their adds

Stoat's Rat King summons pups forever. The autopilot picked the
*nearest* foe, so it farmed the summons and never closed on the king —
57 warren kills, level 8, boss untouched (it looked like a grind, not a
bug; the counters told the truth). Beelining the boss instead got the
stoat chewed by the swarm. The rule that works, and the one to copy:

    clear an add that is already in your face (< 40px),
    otherwise the boss IS the target.

Corollary: this class of bug hides from headless seeds. The Simulator
seeds from the clock, so run the real thing before you believe a
playthrough.

## SDK 3.0.6: refreshRate(0) is not fast any more

Smoke runs cap at ~40-45 fps wall regardless of workload (measured with
sub-millisecond updMs/drwMs; muting audio changed nothing). Size smoke
windows for real time: a 60k-frame RPG playthrough needs ~25 minutes.

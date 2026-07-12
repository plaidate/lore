# Lore — an RPG engine for the Playdate

A shared engine for 16-bit-era role-playing games on the Playdate's
400x240 1-bit screen: a big walkable world, people to talk to, a party
that grows, and battles in **two grammars** — real-time action in the
field (*Secret of Mana*) and menu-driven turns in a scene (*Dragon
Quest* / *Final Fantasy*) — over one shared character sheet.

See [DESIGN.md](DESIGN.md) for the thesis and the five hard problems it
solves; [DEVGUIDE.md](DEVGUIDE.md) to build a game on it.

## The games

| Game | Grammar | What it is |
|---|---|---|
| **Shrew** | turn-based | Pip the shrew knight must eat half her body weight by dawn. Overworld, a town, a boat, a two-floor burrow, and the Mole Tyrant. |
| **Stoat** | action | Ermine drives the rat clan from three field zones. Charge swings, pounces, telegraphed enemies, and a Rat King who stops mid-fight to talk. |
| **Slice** | — | The engine's vertical slice: a walkable chunked overworld, NPCs, a shop, a chest, a battle, a save. |

## The engine

- **Chunked worlds** — an overworld too big to pre-render is drawn from
  a 9-chunk LRU cache: 1-4 blits a frame at any world size.
- **A state stack** — menus over dialogs over the field; a random
  encounter can interrupt a scripted walk, resolve, and hand the walk
  back untouched.
- **Coroutine screenplays** — events are plain Lua that reads like a
  script (`say`, `walk`, `give`, `battle`). Smoke-test playthroughs are
  written the same way: the autopilot is a walkthrough.
- **One character sheet, two battle engines** — stats, items, skills and
  damage math shared by `lturn` (scene battles) and `laction` (field
  combat).
- **Tracker music** — patterns plus an order list, with battle stingers
  that interrupt and resume the map theme mid-phrase.

Every game is beaten end-to-end by its own autopilot in the headless
Simulator before it ships. Procedural art only — no image files.

MIT. Part of the [plaidate](https://github.com/plaidate) fleet.

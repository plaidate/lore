# Stoat

Lore's action proof game, Secret of Mana grammar. Ermine the stoat
(white winter coat, black tail tip) must drive the rat clan from
three field zones — snowy MEADOW, canopied THICKET (walk-behind
cells over the road), dark WARREN — on one connected, chunk-cached
140x60 map before the thaw ruins the winter larders. Fell six rats
in a zone and its captain shows: the Fat Rat, then the Twin Spears
(they yield the Tailwhip and the Bramble Coat), then the RAT KING in
the warren depths — a three-phase fight (pup summons, spin lunges,
desperate) with a scripted mid-fight parley at the halfway mark, the
Chrono Trigger nod: laction freezes under lscript by construction.
Each captain clears a gate (bramble wall, collapsed tunnel) via
Map.set. Home is a tiny den map: a stage-gated elder and the
moss-bed, the inn-free heal-and-save.

Controls: d-pad moves. A talks when someone is in reach (the den),
otherwise swings — HOLD A to charge (ring HUD; the crank winds it up
faster), release to unleash. B taps POUNCE, the 3-tile dash-lunge on
a cooldown (it dodges slinger spit); HOLD B for the pause menu
(Items / Status / Save / Skills / Equip; crank scrolls). Growl
scares every rat around you; Groom heals. Party wipe follows the DQ
rule: half your gold and a blackout back to the moss-bed.

Game-layer moves on engine seams (no core changes): the pounce
hitbox is swept along the dash by hand and the engine's kill sweep
reaps it; slingers spawn with aggro 0 so the game steers their idle
drift to keep range and spit pooled projectiles; the king is two
stacked Action.spawn stages so no overkill can skip the parley.

The smoke autopilot beats the whole campaign headlessly: intro,
three zone quotas, three captains, the equip stop, the parley
window, the thaw ending (`done=1`) — seeds 1, 7 and 31337 under
`lua tools/headless.lua stoat`.

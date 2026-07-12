# Slice

The Lore engine's vertical-slice dev game — a walkable 120x90
procedural overworld proving the wave-1 foundations (chunked
pre-render + LRU cache, canopy walk-behind, free AABB movement, NPC
behaviors and step-triggers) and the wave-2 story systems: talk to
the guard on the east road (he'll escort you shrine-ward), step on
the shrine stone for a scripted scene (pan/fade/flag), buy a torch
from the merchant, loot the one chest (stays open across saves), and
save from the pause menu.

Wave 3 makes it fight: a one-walker Party sheet, random lturn
encounters in the meadow/fern zones (sod mites, bramble hares; DQ
front view, Fight/Skill/Item/Guard/Run, XP -> level 2 learns Gust),
a stick weapon swung through laction (hold A to charge — or crank
the wind-up — release to swing) against a bramble-hare roamer in the
south ferns, and lmusic underneath it all: an A A B field song, a
battle stinger, a two-bar victory fanfare that hands back to the
field song mid-phrase.

Controls: d-pad walks, A talks/opens (hold: charge the stick once
armed), B opens the pause menu (Items / Status / Save; crank
scrolls). Not a game yet; it stays as the engine demo.

The smoke autopilot BEATS all of it — the story playthrough script,
battle command windows via the same st.kind/sel/rows surface, then
an arm-and-hunt field phase that kills the roamer — and laps the
ring road forever.

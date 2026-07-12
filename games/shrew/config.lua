-- Shrew config: every tunable in one table, commented with units.
--
-- XP / ENCOUNTER TUNING (Party.next = 10*lvl^2 total xp):
--   LV2 @ 10xp   LV3 @ 40   LV4 @ 90   LV5 @ 160   LV6 @ 250
--   Aphid Grunt  6xp 3s 0.5g      | Weevil Guard 10xp 5s 1.0g
--   Marsh Midge  9xp 4s 0.5g      | Tick        12xp 6s 1.0g
--   Mole Tyrant 60xp 30s 5.0g (+ the Grub Cellar feast tops 12g)
--   forest groups {aphid}x3 {aphid,aphid}x2 {weevil}x2
--     -> ~8.9xp / ~0.8g a battle
--   marsh groups {midge}x3 {tick}x2 {midge,tick}x2 {weevil,aphid}x1
--     -> ~12.4xp / ~1.0g a battle
--   Grinding marsh to LV4 (90xp) = ~8-10 battles = ~8-10 g eaten,
--   so the 12g dawn meter NEEDS the Tyrant's 5g cellar. Boss math:
--   LV4 Pip (atk 13+4 pin, def 11, hp 45) vs hp 70 / def 10 /
--   atk 13 tyrant = a 4-6 round fight with Curl + Mend; LV3 dies.
--   Encounter rate 0.06/step on the DQ ramp = ~a battle per 14
--   zone steps.

C = {
    DT = 1 / 30,        -- fixed step, s

    WORLD_W = 120,      -- overworld size, tiles
    WORLD_H = 90,
    PLAYER_SPEED = 88,  -- px/s (grid-step tween speed)
    NPC_SPEED = 40,

    GOAL_G = 12,        -- grams eaten to win
    GOLD_START = 40,    -- fresh purse, seeds
    INN_PRICE = 5,      -- seeds a night
    ENC_RATE = 0.06,    -- per-step ramp base, both zones

    -- overworld landmarks (tile coords)
    TOWN_X = 24, TOWN_Y = 30,     -- Voleholm gate tile (warp in)
    EXIT_X = 24, EXIT_Y = 32,     -- world spawn leaving town
    FOREST = { 8, 44, 22, 60 },   -- fern patch x0,y0,x1,y1
    OARCH_X = 14, OARCH_Y = 52,   -- the ferrier's oar chest
    MARSH = { 36, 50, 60, 64 },   -- marsh patch
    RIVER_X0 = 84, RIVER_X1 = 88, -- the river band (all rows)
    DOCK_X = 83, DOCK_Y = 40,     -- west-bank dock tile
    MTN = { 99, 34, 110, 46 },    -- mountain ring box
    PASS_Y = 40,                  -- corridor row through the ring
    CAVE_X = 104, CAVE_Y = 40,    -- Burrow mouth (warp in)
    CAVE_OUT_X = 102,             -- world spawn leaving the Burrow
    CAVE_OUT_Y = 40,

    -- Voleholm (tile coords on the town map)
    TSPAWN_X = 16, TSPAWN_Y = 19, -- spawn entering from the world
    TSTART_X = 7, TSTART_Y = 6,   -- new-game spawn (by the elder)
    ELDER_X = 5, ELDER_Y = 5,
    SHOP_X = 14, SHOP_Y = 5,
    INN_X = 23, INN_Y = 5,
    FERRIER_X = 25, FERRIER_Y = 16,
    KID_X = 10, KID_Y = 14,

    -- The Burrow (tile coords per floor)
    B1_IN = { 4, 2 },             -- spawn from the cave mouth
    B1_OUT = { 2, 2 },            -- exit trigger cell
    B1_KEYCH = { 7, 12 },         -- chest: Brass Key
    B1_CAKECH = { 22, 6 },        -- chest: Seed Cake
    B1_STAIRS = { 25, 13 },       -- down to floor 2
    B2_IN = { 4, 8 },             -- spawn from the stairs
    B2_UP = { 2, 8 },             -- stairs back up
    B2_KEYHOLE = { 11, 8 },       -- step here with the Brass Key
    B2_DOOR = { 12, 8 },          -- the locked door cell
    B2_CLOAKCH = { 16, 4 },       -- chest: Moss Cloak
    B2_CAKECH = { 16, 12 },       -- chest: Seed Cake
    B2_BOSS = { 20, 8 },          -- the boss trigger cell
    B2_TYRANT = { 22, 8 },        -- where the Tyrant stands
}

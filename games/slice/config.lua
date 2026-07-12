-- Slice config: every tunable in one table, commented with units.

C = {
    DT = 1 / 30,        -- fixed step, s

    WORLD_W = 120,      -- overworld width, tiles
    WORLD_H = 90,       -- overworld height, tiles

    PLAYER_SPEED = 70,  -- px/s on speed-1 ground
    NPC_SPEED = 40,     -- px/s on speed-1 ground

    -- the walkable ring road stamped over the terrain (tile coords;
    -- two-tile-wide bands at y0/y1 rows and x0/x1 cols)
    RING_X0 = 8, RING_Y0 = 8,
    RING_X1 = 111, RING_Y1 = 81,

    CANOPY_X0 = 40,     -- canopy band over the top road, tiles
    CANOPY_X1 = 64,

    TRIG_X = 112,       -- shrine trigger cell on the east road
    TRIG_Y = 45,

    -- wave-2 story furniture, all on the east road (x = 111/112)
    GOLD_START = 30,    -- fresh-save purse, g
    GUARD_Y0 = 60,      -- guard patrol leg, tiles (x = TRIG_X)
    GUARD_Y1 = 70,
    CHEST_X = 111,      -- the one chest
    CHEST_Y = 48,
    MERCH_X = 111,      -- the shop NPC
    MERCH_Y = 52,

    -- wave-3 combat furniture: a guaranteed meadow patch by the
    -- east road (random encounters) and a fern patch touching the
    -- south road (forest zone + the roamer), tile coords
    MEADOW_X0 = 104, MEADOW_Y0 = 50,
    MEADOW_X1 = 110, MEADOW_Y1 = 53,
    FOREST_X0 = 40, FOREST_Y0 = 76,
    FOREST_X1 = 46, FOREST_Y1 = 80,
    ROAMER_X = 43,      -- the bramble hare's lair (fern patch)
    ROAMER_Y = 78,
}

-- Stoat config: every tunable in one table, commented with units.

C = {
    DT = 1 / 30,        -- fixed step, s

    WORLD_W = 140,      -- world width, tiles
    WORLD_H = 60,       -- world height, tiles

    PLAYER_SPEED = 72,  -- px/s on speed-1 ground

    ROAD_Y = 30,        -- the east-west run (rows ROAD_Y-1..+1)
    BAND_Y0 = 25,       -- guaranteed-open valley band, tiles: the
    BAND_Y1 = 35,       -- road, every spawn and every lair live here

    GATE1_X = 47,       -- bramble wall cols (x, x+1): meadow|thicket
    GATE2_X = 95,       -- collapsed tunnel cols: thicket|warren
    MEADOW_X1 = 46,     -- zone spans; see G.ZONES
    THICKET_X0 = 49,
    THICKET_X1 = 94,
    WARREN_X0 = 97,

    CANOPY_X0 = 56,     -- canopy band over the thicket road, tiles
    CANOPY_X1 = 78,

    DEN_X = 4,          -- den hole on the west road (world map)
    DEN_Y = 29,
    START_X = 6,        -- where the den exit drops you (world map)
    START_Y = 30,

    DEN_IN_X = 8,       -- den map: entry cell...
    DEN_IN_Y = 7,
    DEN_EXIT_X = 8,     -- ...exit trigger cell...
    DEN_EXIT_Y = 10,
    BED_X = 4, BED_Y = 4,       -- ...the moss-bed actor...
    ELDER_X = 12, ELDER_Y = 4,  -- ...and the elder

    QUOTA = 6,          -- rat kills per zone before the captain shows

    FAT_X = 40, FAT_Y = 30,     -- boss lairs (all on the road)
    TWIN_X = 88, TWIN_Y = 29,
    KING_X = 132, KING_Y = 30,

    POUNCE_SPEED = 220, -- dash px/s
    POUNCE_T = 0.22,    -- dash length, s (~3 tiles)
    POUNCE_COOL = 1.1,  -- s between pounces
    POUNCE_MULT = 1.4,  -- damage scale on the dash hitbox

    SPIT_SPEED = 95,    -- slinger projectile, px/s
    SPIT_LIFE = 1.8,    -- s in flight
    SPIT_COOL = 1.7,    -- s between spits
    SPIT_NEAR = 88,     -- slinger backs off inside this, px
    SPIT_FAR = 150,     -- ...and closes outside this, px

    HURT_IT = 0.8,      -- game-layer player iframes (spit hits), s
    MENU_HOLD = 0.35,   -- hold B this long for the pause menu, s

    GROWL_MP = 2,       -- Growl: AoE scare
    GROWL_R = 84,       -- ...radius, px
    GROOM_MP = 3,       -- Groom: self-heal
    GROOM_FRAC = 0.5,   -- ...fraction of maxhp restored

    GOLD_START = 12,    -- fresh-save purse, g
    RESPAWN = 20,       -- zone rat respawn, s
}

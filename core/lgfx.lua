-- Lore core: the 1-bit kit. An 8-level Bayer dither ramp (0 = white ..
-- 7 = black) in two forms per level — opaque (setPattern's 8-byte form
-- paints BOTH colors) and overlay (the 16-number form: 8 bitmap rows +
-- 8 alpha rows, black speckle only, scene shows through) — plus white
-- text. Palette rules (house): mid-gray terrain, WHITE player with a
-- black outline, dark NPCs/enemies with a white eye pixel, and
-- white-capped landmarks, so everything reads against dithered ground.

local gfx = playdate.graphics

Gfx = {}

Gfx.LEVELS = 7 -- levels run 0..7 inclusive

-- Bayer 8x8 threshold matrix (values 0..63), built recursively:
-- B2 = [[0,2],[3,1]], B2n[y][x] = 4*Bn[y%n][x%n] + B2[y*2//n][x*2//n]
local BAYER
do
    local b = { { 0 } }
    local n = 1
    while n < 8 do
        local m = {}
        for y = 0, 2 * n - 1 do
            m[y + 1] = {}
            for x = 0, 2 * n - 1 do
                local q = b[y % n + 1][x % n + 1] * 4
                local sub = (y >= n and 1 or 0) * 2 + (x >= n and 1 or 0)
                -- quadrant order 0,2 / 3,1
                local add = (sub == 0 and 0) or (sub == 1 and 2)
                    or (sub == 2 and 3) or 1
                m[y + 1][x + 1] = q + add
            end
        end
        b = m
        n = n * 2
    end
    BAYER = b
end

-- Level k blackens pixels whose threshold < k*64/7, so 0 is solid
-- white and 7 solid black. pat[k] = 8 numbers (opaque); over[k] = 16
-- numbers (bitmap 0x00 rows = black ink + alpha rows opaque only
-- where the ramp is black).
local pat, over = {}, {}
for k = 0, 7 do
    local cut = math.floor(k * 64 / 7 + 0.5)
    local p, o = {}, {}
    for y = 1, 8 do
        local row = 0xFF
        for x = 1, 8 do
            if BAYER[y][x] < cut then
                row = row & ~(1 << (8 - x))
            end
        end
        p[y] = row
        o[y] = 0x00
        o[y + 8] = ~row & 0xFF
    end
    pat[k], over[k] = p, o
end

local function quant(k)
    k = math.floor(k + 0.5)
    if k < 0 then return 0 elseif k > 7 then return 7 end
    return k
end

-- opaque gray: paints both black and white pixels (terrain, panels).
-- Un-set with gfx.setColor (color and pattern are mutually exclusive).
function Gfx.level(k)
    gfx.setPattern(pat[quant(k)])
end

-- black-speckle overlay: only the black pixels draw, the scene shows
-- through the rest (shadows, dusk tints, dissolves)
function Gfx.over(k)
    gfx.setPattern(over[quant(k)])
end

function Gfx.fill(x, y, w, h, k)
    Gfx.level(k)
    gfx.fillRect(x, y, w, h)
end

-- white text (the setImageDrawMode dance); resets to copy mode
function Gfx.text(t, x, y)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawText(t, x, y)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

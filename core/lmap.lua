-- Lore core: layered tile worlds too big to pre-render whole. The map
-- renders on demand into 416x256px chunks (26x16 tiles — one screen +
-- margin) held in a 9-record LRU pool (~13KB each, ~117KB total);
-- Map.draw blits the 1-4 visible chunks, Map.set repaints one cell in
-- the one cached chunk that holds it, and the overhead layer (canopy
-- walk-behind) draws per-cell after actors from per-chunk cell lists.
-- Zero per-frame allocation: pooled records, persistent visible list.
--
-- A map def is { rows = {strings}, legend = {ch = def}, wrap = false }.
-- A tile def: { art = fn(x, y, tx, ty)  -- draw 16px tile at x,y in
--                                       -- the CURRENT context; tx,ty
--                                       -- world tile for variation
--               solid = bool, water = bool, speed = mult (default 1),
--               zone = id, trigger = id,
--               overhead = bool,  -- art is the canopy, pre-rendered
--                                 -- ONCE per def and drawn per-cell
--                                 -- after actors (so it is uniform)
--               under = "ch" }    -- ground char painted beneath an
--                                 -- overhead cell in the chunk
-- Tiles are 16px, tile coords are 1-based; world px of tile (tx,ty)
-- start at ((tx-1)*16, (ty-1)*16). `wrap` is parsed but reserved for
-- a later wave: out-of-bounds always reads as solid.

local gfx = playdate.graphics

Map = {
    TILE = 16,
    CW = 26, CH = 16,        -- chunk size in tiles
    CPW = 416, CPH = 256,    -- chunk size in px
    POOL = 9,                -- LRU depth: 3x3 chunks around the camera
    W = 0, H = 0,            -- map size in tiles
    PW = 0, PH = 0,          -- map size in px
    legend = {},
    grid = {},
    builds = 0,              -- stat: chunk renders since Map.load
    tick = 0,
    wrap = false,
}

local T = Map.TILE
local pool = nil     -- POOL chunk records, images allocated once
local vis, visN = {}, 0

local function makePool()
    pool = {}
    for i = 1, Map.POOL do
        pool[i] = {
            img = gfx.image.new(Map.CPW, Map.CPH, gfx.kColorWhite),
            key = -1, stamp = 0, cx = 0, cy = 0,
            on = 0, otx = {}, oty = {}, oimg = {},
        }
    end
end

-- rebuild a chunk's overhead cell list (cheap scan; on build/set only)
local function rescanOverhead(rec)
    rec.on = 0
    local tx0 = rec.cx * Map.CW
    local ty0 = rec.cy * Map.CH
    for j = 1, Map.CH do
        local row = Map.grid[ty0 + j]
        if row then
            for i = 1, Map.CW do
                local d = row[tx0 + i]
                d = d and Map.legend[d]
                if d and d.overhead then
                    rec.on = rec.on + 1
                    rec.otx[rec.on] = tx0 + i
                    rec.oty[rec.on] = ty0 + j
                    rec.oimg[rec.on] = d.img
                end
            end
        end
    end
end

-- paint one cell (chunk-local px lx,ly) into an open chunk context
local function paintCell(lx, ly, tx, ty)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(lx, ly, T, T)
    local row = Map.grid[ty]
    local d = row and row[tx]
    d = d and Map.legend[d]
    if not d then return end
    if d.overhead then
        local u = d.underDef
        if u then u.art(lx, ly, tx, ty) end
    else
        d.art(lx, ly, tx, ty)
    end
end

local function buildChunk(rec, cx, cy)
    rec.cx, rec.cy = cx, cy
    rec.key = cy * 4096 + cx
    Map.builds = Map.builds + 1
    gfx.pushContext(rec.img)
    for j = 0, Map.CH - 1 do
        for i = 0, Map.CW - 1 do
            paintCell(i * T, j * T, cx * Map.CW + i + 1,
                cy * Map.CH + j + 1)
        end
    end
    gfx.popContext()
    rescanOverhead(rec)
end

-- fetch a chunk record, rendering + evicting the LRU one if needed
local function getChunk(cx, cy)
    local key = cy * 4096 + cx
    local best, bestStamp
    for i = 1, Map.POOL do
        local r = pool[i]
        if r.key == key then
            r.stamp = Map.tick
            return r
        end
        if not bestStamp or r.stamp < bestStamp then
            best, bestStamp = r, r.stamp
        end
    end
    buildChunk(best, cx, cy)
    best.stamp = Map.tick
    return best
end

-- load a map def; resets the chunk cache and stats. Pre-renders each
-- overhead def's art once into def.img and resolves def.underDef.
function Map.load(def)
    if not pool then makePool() end
    Map.legend = def.legend
    Map.wrap = def.wrap or false -- reserved
    local rows = def.rows
    Map.W, Map.H = #rows[1], #rows
    Map.PW, Map.PH = Map.W * T, Map.H * T
    Map.grid = {}
    for y = 1, Map.H do
        assert(#rows[y] == Map.W, "Map.load: row " .. y .. " is "
            .. #rows[y] .. " chars, expected " .. Map.W)
        local r = {}
        for x = 1, Map.W do
            local ch = rows[y]:sub(x, x)
            assert(Map.legend[ch],
                "Map.load: no legend for '" .. ch .. "'")
            r[x] = ch
        end
        Map.grid[y] = r
    end
    for ch, d in pairs(Map.legend) do
        d.ch = ch
        if d.overhead then
            d.img = gfx.image.new(T, T) -- transparent
            gfx.pushContext(d.img)
            d.art(0, 0, 0, 0)
            gfx.popContext()
            d.underDef = d.under and Map.legend[d.under] or nil
        end
    end
    for i = 1, Map.POOL do
        pool[i].key, pool[i].stamp = -1, 0
    end
    Map.builds, Map.tick, visN = 0, 0, 0
end

-- blit the 1-4 chunks visible from camera top-left (world px); call
-- with the draw offset active (world space). Records the visible set
-- for Map.drawOverhead.
function Map.draw(camx, camy)
    Map.tick = Map.tick + 1
    local c0x = Util.clamp(math.floor(camx / Map.CPW), 0,
        math.max(0, math.ceil(Map.W / Map.CW) - 1))
    local c1x = Util.clamp(math.floor((camx + 399) / Map.CPW), c0x,
        math.max(0, math.ceil(Map.W / Map.CW) - 1))
    local c0y = Util.clamp(math.floor(camy / Map.CPH), 0,
        math.max(0, math.ceil(Map.H / Map.CH) - 1))
    local c1y = Util.clamp(math.floor((camy + 239) / Map.CPH), c0y,
        math.max(0, math.ceil(Map.H / Map.CH) - 1))
    visN = 0
    for cy = c0y, c1y do
        for cx = c0x, c1x do
            local rec = getChunk(cx, cy)
            rec.img:draw(cx * Map.CPW, cy * Map.CPH)
            visN = visN + 1
            vis[visN] = rec
        end
    end
end

-- draw the overhead layer (canopy cells of the visible chunks) —
-- call AFTER actors, still in world space, same camera as Map.draw
function Map.drawOverhead(camx, camy)
    for v = 1, visN do
        local rec = vis[v]
        for i = 1, rec.on do
            rec.oimg[i]:draw((rec.otx[i] - 1) * T,
                (rec.oty[i] - 1) * T)
        end
    end
end

-- change one cell: updates the grid, repaints the cell inside the one
-- cached chunk holding it (and refreshes that chunk's overhead list);
-- nothing else is invalidated
function Map.set(tx, ty, ch)
    assert(Map.legend[ch],
        "Map.set: undefined tile char '" .. tostring(ch) .. "'")
    local row = Map.grid[ty]
    if not row or not row[tx] then return end
    row[tx] = ch
    local key = math.floor((ty - 1) / Map.CH) * 4096
        + math.floor((tx - 1) / Map.CW)
    for i = 1, Map.POOL do
        local rec = pool[i]
        if rec.key == key then
            gfx.pushContext(rec.img)
            paintCell((tx - 1) % Map.CW * T, (ty - 1) % Map.CH * T,
                tx, ty)
            gfx.popContext()
            rescanOverhead(rec)
            return
        end
    end
end

-- ---- queries ---------------------------------------------------------

function Map.get(tx, ty)
    local row = Map.grid[ty]
    return row and row[tx]
end

function Map.defAt(tx, ty)
    local ch = Map.get(tx, ty)
    return ch and Map.legend[ch]
end

-- out of bounds counts as solid
function Map.solid(tx, ty)
    local d = Map.defAt(tx, ty)
    if not d then return true end
    return d.solid == true
end

function Map.water(tx, ty)
    local d = Map.defAt(tx, ty)
    return d ~= nil and d.water == true
end

function Map.speed(tx, ty)
    local d = Map.defAt(tx, ty)
    return (d and d.speed) or 1
end

function Map.zone(tx, ty)
    local d = Map.defAt(tx, ty)
    return d and d.zone
end

function Map.trigger(tx, ty)
    local d = Map.defAt(tx, ty)
    return d and d.trigger
end

-- tile containing a world pixel
function Map.tileAt(wx, wy)
    return math.floor(wx / T) + 1, math.floor(wy / T) + 1
end

-- world px center of a tile
function Map.cx(tx) return (tx - 1) * T + 8 end
function Map.cy(ty) return (ty - 1) * T + 8 end

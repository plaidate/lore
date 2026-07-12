-- Stoat rendering: the canonical Lore frame (chunked map, painter
-- actors, canopy walk-behind, laction overlays) plus the game layer
-- in world space (pooled spits, the hold-A charge ring around
-- Ermine) and a screen-space HUD — level line, HP/MP bars, gold,
-- the zone quota readout, and a dither gloom over the warren. All
-- HUD strings are cached and rebuilt only when their value moves.

local gfx = playdate.graphics

Draw = {}

-- white text with a black shadow so it reads on snow
local function label(t, x, y)
    gfx.drawText(t, x + 1, y + 1)
    Gfx.text(t, x, y)
end

local lvVal, lvStr = -1, ""
local qVal, qStr = -1, ""

local function lvLine(m)
    if m.lvl ~= lvVal then
        lvVal = m.lvl
        lvStr = "Ermine LV" .. m.lvl
    end
    return lvStr
end

local function questLine()
    local v
    if State.has("done") then
        v = -2
        if qVal ~= v then qStr = "The fields are safe" end
    else
        local zi = 1
        if State.has("fat_dead") then zi = 2 end
        if State.has("twins_dead") then zi = 3 end
        local z = G.ZONES[zi]
        local k = math.min(C.QUOTA,
            State.counterOf("kills_" .. z.name))
        local boss = State.has(z.name .. "_boss")
        v = zi * 100 + k + (boss and 50 or 0)
        if qVal ~= v then
            if boss then
                qStr = z.name .. ": the captain!"
            else
                qStr = z.name .. " rats " .. k .. "/" .. C.QUOTA
            end
        end
    end
    qVal = v
    return qStr
end

function Draw.frame()
    Cam.apply()
    Map.draw(Cam.x, Cam.y)
    Act.drawAll()
    Map.drawOverhead(Cam.x, Cam.y)
    Action.draw()
    for i = 1, 6 do -- slinger spits
        local s = G.spits[i]
        if s.t > 0 then
            gfx.setColor(gfx.kColorBlack)
            gfx.fillCircleAtPoint(math.floor(s.x),
                math.floor(s.y), 3)
            gfx.setColor(gfx.kColorWhite)
            gfx.drawPixel(math.floor(s.x) - 1,
                math.floor(s.y) - 1)
        end
    end
    if Action.charge01 > 0.04 then -- the hold-A charge ring
        local p = G.player
        gfx.setColor(gfx.kColorWhite)
        gfx.drawArc(math.floor(p.x), math.floor(p.y), 13, 0,
            360 * Action.charge01)
        gfx.setColor(gfx.kColorBlack)
    end
    UI.drawPopups()
    Kit.marker(G.player.x, G.player.y - 16, G.t)
    Cam.done()
    if G.mapName == "world"
        and G.zoneAt(G.player.cellX) == "warren" then
        Gfx.over(2) -- the warren gloom
        gfx.fillRect(0, 0, 400, 240)
        gfx.setColor(gfx.kColorBlack)
    end
    local m = Party.member(1)
    label(lvLine(m), 4, 2)
    UI.hpBar(4, 22, 60, m.hp, m.maxhp)
    UI.hpBar(4, 32, 40, m.mp, math.max(1, m.maxmp))
    label(UI.goldStr(), 364, 2)
    label(questLine(), 140, 2)
end

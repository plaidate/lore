-- Shrew story ledger extras: the GRAMS EATEN quest meter (a State
-- counter, so it rides every save), the save-position wrap (map +
-- cell recorded into the ledger so CONTINUE and the death reload
-- know where to put Pip), and the DQ death flow (dialog, half your
-- seeds, back to the last save). G is the per-boot game table.

G = { t = 0, mapName = "town", curSong = nil }

GS = {}

-- ---- grams ----------------------------------------------------------------

function GS.grams()
    return State.counterOf("grams")
end

function GS.addGrams(n)
    State.bump("grams", n)
    Harness.set("grams", GS.grams())
end

-- cached "N.N/12g" meter readout (zero-alloc draw)
local gVal, gStr = -1, ""

function GS.gramsStr()
    local g = GS.grams()
    if g ~= gVal then
        gVal = g
        local whole = math.floor(g)
        if g == whole then
            gStr = whole .. "/" .. C.GOAL_G .. "g"
        else
            gStr = whole .. ".5/" .. C.GOAL_G .. "g"
        end
    end
    return gStr
end

-- ---- save position --------------------------------------------------------

-- install once: every State.save (menu, autosave) records where Pip
-- stands, so load/continue/death all land somewhere sensible
function GS.wrapSave()
    local base = State.save
    State.save = function()
        if G.player then
            State.set("pos_map", G.mapName)
            State.counters.posx = G.player.cellX
            State.counters.posy = G.player.cellY
        end
        base()
    end
end

function GS.savedPos()
    local m = State.get("pos_map")
    if type(m) ~= "string" then
        return "town", C.TSTART_X, C.TSTART_Y
    end
    return m, State.counterOf("posx"), State.counterOf("posy")
end

-- ---- the death flow (engine-side party wipes) -----------------------------

function GS.deathFlow()
    UI.dialog(nil,
        "[Pip's whiskers droop... the night goes dark.]",
        function()
            State.gold = math.floor(State.gold / 2)
            if State.hasSave() then State.load() end
            Party.restoreAll()
            Harness.count("deaths")
            local m, x, y = GS.savedPos()
            Game.loadMap(m, x, y)
            Kit.toast("Dawn is closer. Eat!")
        end)
end

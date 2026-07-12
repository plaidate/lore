-- Lore core: the story ledger. Everything a save file remembers lives
-- here: flags, named counters, the party roster (opaque tables — wave
-- 3 owns the schema), the inventory (item id -> count), gold, opened
-- chests/doors keyed "map:x:y" (the vault lesson: datastore JSON
-- stringifies integer keys, so every set is STRING-keyed at write and
-- read), and quest stages. State.save/load round-trip a versioned
-- envelope {v=1, ...} through playdate.datastore — all keys JSON-safe
-- (dict keys are strings, arrays are contiguous). State.autosave is
-- the hook lscript's warp() fires on map changes (default: save).

State = {
    FILE = "save",
    flags = {},
    counters = {},
    party = {},     -- array of opaque member tables (wave-3 schema)
    inv = {},       -- item id (string) -> count
    gold = 0,
    openedSet = {}, -- "map:x:y" -> true
    quests = {},    -- quest id -> stage number
}

-- ---- flags ----------------------------------------------------------------

function State.set(flag, v)
    if v == nil then v = true end
    if v == false then v = nil end
    if v and not State.flags[flag] then Harness.count("flagsSet") end
    State.flags[flag] = v
end

function State.get(flag)
    return State.flags[flag]
end

function State.has(flag)
    return State.flags[flag] ~= nil
end

-- ---- named counters (kills, steps, deaths...) -----------------------------

function State.bump(name, n)
    local v = (State.counters[name] or 0) + (n or 1)
    State.counters[name] = v
    return v
end

function State.counterOf(name)
    return State.counters[name] or 0
end

-- ---- inventory ------------------------------------------------------------

function State.add(item, n)
    State.inv[item] = (State.inv[item] or 0) + (n or 1)
end

-- take n (default 1); false and no change if short
function State.take(item, n)
    n = n or 1
    local have = State.inv[item] or 0
    if have < n then return false end
    if have == n then
        State.inv[item] = nil -- absent, not 0: keeps the JSON lean
    else
        State.inv[item] = have - n
    end
    return true
end

function State.count(item)
    return State.inv[item] or 0
end

-- ---- gold -----------------------------------------------------------------

function State.giveGold(n)
    State.gold = State.gold + n
end

function State.takeGold(n)
    if State.gold < n then return false end
    State.gold = State.gold - n
    return true
end

-- ---- chest/door persistence (string keys: the vault lesson) ---------------

local function okey(map, tx, ty)
    return map .. ":" .. tx .. ":" .. ty
end

function State.opened(map, tx, ty)
    return State.openedSet[okey(map, tx, ty)] == true
end

function State.markOpened(map, tx, ty)
    local k = okey(map, tx, ty)
    if not State.openedSet[k] then Harness.count("chestsOpened") end
    State.openedSet[k] = true
end

-- ---- quest stages ---------------------------------------------------------

-- State.stage("main") reads (0 if unset); State.stage("main", 2) sets
function State.stage(quest, set)
    if set ~= nil then State.quests[quest] = set end
    return State.quests[quest] or 0
end

-- ---- save / load ----------------------------------------------------------

function State.save()
    playdate.datastore.write({
        v = 1,
        flags = State.flags,
        counters = State.counters,
        party = State.party,
        inv = State.inv,
        gold = State.gold,
        opened = State.openedSet,
        quests = State.quests,
    }, State.FILE)
    Harness.count("saves")
end

-- replaces the live ledger from disk; false (untouched) if no/old save
function State.load()
    local env = playdate.datastore.read(State.FILE)
    if not env or env.v ~= 1 then return false end
    State.flags = env.flags or {}
    State.counters = env.counters or {}
    State.party = env.party or {}
    State.inv = env.inv or {}
    State.gold = env.gold or 0
    State.openedSet = env.opened or {}
    State.quests = env.quests or {}
    return true
end

function State.hasSave()
    return playdate.datastore.read(State.FILE) ~= nil
end

function State.wipe()
    playdate.datastore.delete(State.FILE)
end

-- the map-change hook (lscript's warp calls it); games may override
State.autosave = function()
    State.save()
end

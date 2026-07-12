-- Shrew story: every scripted beat, DQ-bracketed. Attach points:
-- five Voleholm NPCs (the elder's line changes after the boss, the
-- ferrier trades the lost oar for her skiff), chests, the map-warp
-- triggers, the Brass Key door, and the Mole Tyrant — whose script
-- carries the win (Grub Cellar feast -> sunrise ending -> done=1)
-- and the loss (thrown out, back to town).

Story = {}

local function warpToTown()
    warp("town", C.TSPAWN_X, C.TSPAWN_Y)
end

function Story.register()
    -- ---- Voleholm ---------------------------------------------------
    Script.onTalk("elder", function()
        if hasflag("boss_down") then
            say("Elder Bram",
                "[The Tyrant beaten and the cellar open! Eat, "
                .. "Pip. Dawn holds no fear for a full belly.]")
            return
        end
        say("Elder Bram",
            "[Pip. A shrew who does not eat half her weight by "
            .. "dawn is a shrew the dawn does not meet.]")
        say("Elder Bram",
            "[The Mole Tyrant hoards the Grub Cellar under the "
            .. "eastern mountains. Cross the river; eat what "
            .. "fights you on the way.]")
    end)

    Script.onTalk("shopkeep", function()
        say("Mrs. Vole", "[Pins, vests, cakes. All for seeds.]")
        shop(Content.STOCK)
        say("Mrs. Vole", "[Sharp pin, long life.]")
    end)

    Script.onTalk("innkeep", function()
        say("Innkeep", "[A bed of moss, " .. C.INN_PRICE
            .. " seeds. Best rest in Voleholm.]")
        inn(C.INN_PRICE)
    end)

    Script.onTalk("ferrier", function()
        if hasflag("boat") then
            say("Ferrier Sedge",
                "[Fair currents, Pip. The skiff waits at the "
                .. "dock south-east.]")
        elseif State.count("oar") > 0 then
            State.take("oar", 1)
            say("Ferrier Sedge",
                "[My oar! You dear thing. Take the skiff, then "
                .. "- step right off the dock, the reeds bear "
                .. "you.]")
            setflag("boat")
            G.player.swims = true
            Harness.set("boatUnlocked", 1)
            toast("You can cross water now!")
        else
            say("Ferrier Sedge",
                "[I'd ferry you east, but my oar's gone - "
                .. "dropped it in the western ferns. Fetch it "
                .. "and the skiff is yours.]")
        end
    end)

    Script.onTalk("kid", function()
        if hasflag("boss_down") then
            say("Vole Kid", "[You BEAT him? Tell it again!]")
        else
            say("Vole Kid",
                "[The Burrow's lower door is locked. A guard "
                .. "buried a brass key on the first floor, they "
                .. "say.]")
        end
    end)

    -- ---- chests (loot rides on the actor) ---------------------------
    Script.onTalk("chest", function(ch)
        if State.opened(G.mapName, ch.cellX, ch.cellY) then
            say(nil, "[The chest is empty.]")
            return
        end
        State.markOpened(G.mapName, ch.cellX, ch.cellY)
        ch.img = G.chestOpen
        Sfx.chestJingle()
        give(ch.loot, ch.lootN)
    end)

    -- ---- warp triggers ----------------------------------------------
    Script.onTrigger("town", warpToTown)
    Script.onTrigger("exitTown", function()
        warp("world", C.EXIT_X, C.EXIT_Y)
    end)
    Script.onTrigger("cave", function()
        warp("burrow1", C.B1_IN[1], C.B1_IN[2])
    end)
    Script.onTrigger("exitBurrow", function()
        warp("world", C.CAVE_OUT_X, C.CAVE_OUT_Y)
    end)
    Script.onTrigger("stairs1", function()
        warp("burrow2", C.B2_IN[1], C.B2_IN[2])
    end)
    Script.onTrigger("stairs2up", function()
        warp("burrow1", C.B1_STAIRS[1] - 1, C.B1_STAIRS[2])
    end)

    Script.onTrigger("dock", function()
        if hasflag("boat") then
            toast("The reed skiff bobs. Walk on out.")
        else
            toast("No crossing without the ferrier's skiff.")
        end
    end)

    -- the Brass Key turns here; Map.set persists via the flag
    Script.onTrigger("keyhole", function()
        if hasflag("burrow_door") then return end
        if State.count("brass_key") > 0 then
            setflag("burrow_door")
            Map.set(C.B2_DOOR[1], C.B2_DOOR[2], ".")
            Snd.play("square", 220, 0.15, 0.25)
            toast("The Brass Key turns! The door grinds open.")
        else
            toast("A heavy door. It wants a brass key.")
        end
    end)

    -- ---- the boss ------------------------------------------------------
    Script.onTrigger("boss", function()
        if hasflag("boss_down") then
            toast("The Grub Cellar is yours.")
            return
        end
        say("Mole Tyrant",
            "[WHO scratches at MY cellar? A morsel with a pin?]")
        say("Pip",
            "[A knight who must eat by dawn. Stand aside, "
            .. "Tyrant!]")
        local r = battle("mole_tyrant")
        if r ~= "win" then
            say(nil, "[Pip is flung from the cellar...]")
            Party.restoreAll()
            warpToTown()
            return
        end
        setflag("boss_down")
        Harness.set("bossDown", 1)
        if G.tyrant then
            Act.remove(G.tyrant)
            G.tyrant = nil
        end
        -- the hoard: the feast that fills the dawn meter
        local need = C.GOAL_G - GS.grams()
        if need > 0 then GS.addGrams(need) end
        say(nil,
            "[The Grub Cellar spills open - fat grubs, seed "
            .. "butter, beetle jerky. Pip FEASTS.]")
        Story.ending()
    end)
end

-- ---- the intro (new game) ----------------------------------------------

function Story.intro()
    say("Elder Bram",
        "[Pip, little knight. Night is short and your belly "
        .. "is law: " .. C.GOAL_G .. " grams by dawn, or the "
        .. "dawn is not yours.]")
    say("Pip", "[Then everything that squeaks back is supper.]")
    give("herb", 1)
    toast("Eat " .. C.GOAL_G .. "g by dawn!")
end

-- ---- the ending (sunrise pan + credits) --------------------------------

function Story.ending()
    fade(1)
    warp("world", C.CAVE_OUT_X, C.CAVE_OUT_Y)
    fade(0)
    pan(C.RIVER_X0 * 16, C.PASS_Y * 16, 90)
    say(nil,
        "[The sun climbs over the river. Pip, twelve grams "
        .. "the heavier, watches it come.]")
    say(nil,
        "[A shrew who eats the night survives the dawn. "
        .. "SHREW - a Lore engine tale.]")
    panBack()
    setflag("quest_done")
    Harness.set("done", 1)
    toast("Thanks for playing!")
end

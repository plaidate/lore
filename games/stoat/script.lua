-- Stoat story: every scripted beat, plus the attach points. The den
-- elder's dialogue is stage-gated by story flags; the moss-bed is
-- the inn-free heal (rest + save); the den hole/exit triggers warp.
-- Story.parley is the CT nod: it fires MID-KING-FIGHT (between the
-- king's two stages) and laction freezes under it by construction —
-- Script.run suppresses the field update that ticks Action. The
-- ending pans the thaw back across all three zones.

Story = {}

Story.intro = function()
    say("Elder", "Ermine. The rat clan gnaws at our three fields "
        .. "while the larders sleep under the snow.")
    say("Elder", "Drive them from meadow, thicket and warren "
        .. "before the thaw spoils everything.")
    say("Elder", "Fell six in each field and their captain will "
        .. "show. Go. Your winter coat was made for this.")
    give("herb", 2)
    setflag("intro")
    State.stage("main", 1)
end

-- the mid-fight beat: the wounded king stands, speaks, and rises
-- desperate (stage 2 is already spawned, frozen under this script)
Story.parley = function()
    say("Rat King", "Hold, white shadow! Enough of my children "
        .. "feed the frost already.")
    say("Rat King", "Your kind hoards three fields of plenty. We "
        .. "came because we starve.")
    local i = ask("Your answer:", { "The fields are ours.",
        "Then take the far woods." })
    if i == 2 then setflag("king_mercy") end
    setflag("king_parley")
    say("Rat King", "So be it. A king dies standing!")
    toast("The Rat King rises, desperate!")
end

Story.ending = function()
    wait(0.6)
    if hasflag("king_mercy") then
        say(nil, "The broken clan streams east, toward the far "
            .. "woods you offered.")
    else
        say(nil, "The broken clan scatters into the winter dark.")
    end
    pan(Map.cx(70), Map.cy(C.ROAD_Y), 320)
    toast("Drip... drip. The canopy sheds its snow.")
    pan(Map.cx(16), Map.cy(C.ROAD_Y), 320)
    say("Ermine", "The larders will hold. Spring can come.")
    say(nil, "THE THAW ARRIVES - the three fields are safe - "
        .. "THE END")
    panBack()
    State.stage("main", 9)
    setflag("done")
    Harness.set("done", 1)
    Harness.set("doneAt", G.frames)
    State.save()
end

-- party wipe (the DQ rule): gold was halved by game.lua; black out
-- home to the moss-bed with everything restored
Story.death = function()
    fade(1)
    wait(0.3)
    warp("den", C.BED_X + 1, C.BED_Y + 1)
    Party.restoreAll()
    toast("You wake in the moss-bed, purse lighter...")
    fade(0)
end

function Story.register()
    Script.onTalk("elder", function()
        if hasflag("done") then
            say("Elder", "The thaw sings, Ermine. You did that.")
        elseif hasflag("twins_dead") then
            say("Elder", "Their king holes up at the warren's "
                .. "deepest end. Finish it.")
        elseif hasflag("fat_dead") then
            say("Elder", "The thicket rustles wrong. Mind what "
                .. "hangs over the road.")
        elseif hasflag("intro") then
            say("Elder", "Six from each field draws the captain "
                .. "out. The meadow first.")
        else
            say("Elder", "Catch your breath, then hear me out.")
        end
    end)

    Script.onTalk("mossbed", function()
        local i = ask("Curl up in the moss-bed?", { "Yes", "No" })
        if i == 1 then
            fade(1)
            Party.restoreAll()
            State.save()
            toast("You wake warm and whole.")
            fade(0)
        end
    end)

    Script.onTrigger("denexit", function()
        warp("world", C.START_X, C.START_Y)
    end)

    Script.onTrigger("denhole", function()
        warp("den", C.DEN_IN_X, C.DEN_IN_Y)
    end)
end

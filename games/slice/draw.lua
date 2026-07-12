-- Slice rendering: chunked map, painter-sorted actors, then the
-- overhead canopy (walk-behind), laction overlays (telegraph rings,
-- foe HP bars, swing flash, debris), popups, the player marker — all
-- in world space between Cam.apply/done. HUD (title, gold, and once
-- armed the walker's HP bar + charge meter) stays screen-space; the
-- gold string is cached and rebuilt on change.

Draw = {}

function Draw.frame()
    Cam.apply()
    Map.draw(Cam.x, Cam.y)
    Act.drawAll()
    Map.drawOverhead(Cam.x, Cam.y)
    Action.draw()
    UI.drawPopups()
    Kit.marker(G.player.x, G.player.y - 16, G.t)
    Cam.done()
    Kit.text("*slice*", 4, 2)
    Kit.text(UI.goldStr(), 368, 2)
    if Action.weapon then
        local m = Party.member(1)
        if m then UI.hpBar(4, 220, 56, m.hp, m.maxhp) end
        UI.hpBar(4, 231, 56,
            math.floor(Action.charge01 * 100), 100)
    end
end

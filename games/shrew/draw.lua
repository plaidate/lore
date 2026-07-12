-- Shrew rendering: the canonical Lore frame — chunked map, painter
-- actors, overhead roofs (town walk-behind), popups, the player
-- marker — inside the Cam bracket; screen-space HUD after: the
-- GRAMS EATEN dawn meter (cached string) and the seed purse.

Draw = {}

function Draw.frame()
    Cam.apply()
    Map.draw(Cam.x, Cam.y)
    Act.drawAll()
    Map.drawOverhead(Cam.x, Cam.y)
    UI.drawPopups()
    Kit.marker(G.player.x, G.player.y - 16, G.t)
    Cam.done()
    Kit.panel(2, 2, 92, 22)
    Kit.text(GS.gramsStr(), 10, 5)
    Kit.text(UI.goldStr(), 362, 5)
end

local _, ns = ...

--------------------------------------------------
-- TOTEM ICONS & IN RANGE MARK (an extension for FlareUI): settings and start-up
--------------------------------------------------
local DEFAULTS = { inRange = true, inRangeBars = true, nameplates = "above", totemBuffs = {} }

local started = false
local function Refresh()
    if not started then return end
    ns.InRange.Refresh()
    ns.TotemIcons.Refresh()
end

ns.OnReady("FlareUI_TotemMarksDB", DEFAULTS, function()
    ns.RegisterOptions("FlareUI: Totem Icons & In Range Mark", {
        { key = "inRange", label = "In Range Mark",
          flare = { key = "uf.extTotemRange", section = "uf.extensions", sectionTitle = "Extensions", tab = "settings", half = true },
          tip = "Yellow dashes march round a totem while its buff is on you, and stop when you walk out of its range. Totems without a buff, such as Searing or Tremor, are never marked. A totem is learned the first time you stand in its buff out of combat. In a group, another shaman's totem of the same kind lights the mark too." },
        { key = "inRangeBars", label = "In Range Mark on Action Bars",
          flare = { key = "uf.extTotemRangeBars", section = "uf.extensions", sectionTitle = "Extensions", tab = "settings", half = true },
          tip = "The In Range Mark on the totem's spell too, on the totem bar and wherever it is on your action bars." },
        { key = "nameplates", label = "Totem Icons on Nameplates",
          flare = { key = "qol.extNpTotems", section = "qol.nameplates", tab = "nameplates" },
          tip = "A totem's icon on its nameplate, so you can see where each totem stands. Your own and your group's totems show only with friendly nameplates on. Off while another nameplate addon draws the plates.",
          choices = { { "off", "Off" }, { "above", "Above the Nameplate" }, { "instead", "Instead of the Nameplate" } } },
    }, "/flaretotems", Refresh)
end, function()
    started = true
    Refresh()
end)

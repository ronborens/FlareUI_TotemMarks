local _, ns = ...

--------------------------------------------------
-- NAMEPLATE TOTEM ICONS (an extension for FlareUI)
-- A totem's spell icon above its nameplate, or in place of the plate (Blizzard's plate faded out, the
-- icon left), so every totem down is easy to spot. A totem is known by its name: the shaman's totem
-- spells' names in the client's language, the rank left off ("Searing Totem III"), so an NPC shaman's
-- totems count too. A secret name leaves the plate as it is. Plates are recycled: each plate has an
-- icon, re-checked whenever a unit gets the plate. Stands down while another nameplate addon draws
-- the plates.
--------------------------------------------------
local TotemIcons = {
    SPELLS = {   -- rank 1 of each
        3599, 1535, 8190, 8227, 8181,              -- Searing, Fire Nova, Magma, Flametongue, Frost Resistance
        8071, 2484, 8075, 5730, 8143,              -- Stoneskin, Earthbind, Strength of Earth, Stoneclaw, Tremor
        5394, 5675, 8184, 8166, 8170, 16190,       -- Healing Stream, Mana Spring, Fire Resistance, Poison / Disease Cleansing, Mana Tide
        8177, 8512, 8835, 10595, 15107, 25908, 6495,   -- Grounding, Windfury, Grace of Air, Nature Resistance, Windwall, Tranquil Air, Sentry
    },
    SIZE = 24,
    SIZE_INSTEAD = 30,   -- bigger when it stands in for the plate
    GAP = 2,             -- above the plate's name
    icons = {},          -- plate -> icon frame
    faded = {},          -- plate unit frames faded out for Instead
    -- events: the listener, made the first time the option is on; byName: spell name -> icon file
}
ns.TotemIcons = TotemIcons

local function Readable(v) return canaccessvalue == nil or canaccessvalue(v) end

-- another nameplate addon draws the plates (FlareUI knows which ones)
local function OtherNameplates()
    local F = _G.FlareUI
    local tweaks = type(F) == "table" and F.Tweaks
    if type(tweaks) ~= "table" or type(tweaks.GetNameplateAddon) ~= "function" then return false end
    local ok, name = pcall(tweaks.GetNameplateAddon, tweaks)
    return ok and name and true or false
end

function TotemIcons.Mode()
    local mode = ns.db and ns.db.nameplates or "off"
    if mode == "off" or OtherNameplates() then return "off" end
    return mode
end

-- A name the client hasn't loaded yet comes back nil: the list is built again next time
function TotemIcons.Names()
    local names = TotemIcons.byName
    if names and names.complete then return names end
    names = { complete = true }
    for _, id in ipairs(TotemIcons.SPELLS) do
        local okName, name = pcall(C_Spell.GetSpellName, id)
        local okIcon, icon = pcall(C_Spell.GetSpellTexture, id)
        if okName and name and okIcon and icon then names[name] = icon else names.complete = false end
    end
    TotemIcons.byName = names
    return names
end

-- The icon for a nameplate unit that is a totem, or nil
function TotemIcons.For(unit)
    local name = UnitName(unit)
    if not (Readable(name) and type(name) == "string") then return nil end
    local names = TotemIcons.Names()
    local icon = names[name] or names[(name:gsub("%s+[IVX]+$", ""))]
    return type(icon) ~= "boolean" and icon or nil
end

-- the plate's health bar, or the plate itself
local function PlateBar(plate)
    local unitFrame = plate.UnitFrame
    local bar = unitFrame and unitFrame.HealthBarsContainer and unitFrame.HealthBarsContainer.healthBar
    if bar and not bar:IsForbidden() then return bar end
    return plate
end

function TotemIcons.Get(plate)
    local icon = TotemIcons.icons[plate]
    if not icon then
        icon = CreateFrame("Frame", nil, plate)
        -- a thin dark edge round the art
        icon.edge = icon:CreateTexture(nil, "BACKGROUND")
        icon.edge:SetAllPoints()
        icon.edge:SetColorTexture(0, 0, 0, 1)
        icon.art = icon:CreateTexture(nil, "ARTWORK")
        icon.art:SetPoint("TOPLEFT", 1, -1)
        icon.art:SetPoint("BOTTOMRIGHT", -1, 1)
        icon.art:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        TotemIcons.icons[plate] = icon
    end
    return icon
end

-- Instead: Blizzard's plate only loses its alpha (its values can be secret, so nothing is replaced)
function TotemIcons.Fade(unitFrame, out)
    if not unitFrame or unitFrame:IsForbidden() then return end
    if out then
        TotemIcons.faded[unitFrame] = true
        unitFrame:SetAlpha(0)
    elseif TotemIcons.faded[unitFrame] then
        TotemIcons.faded[unitFrame] = nil
        unitFrame:SetAlpha(1)
    end
end

function TotemIcons.Clear(plate)
    if TotemIcons.icons[plate] then TotemIcons.icons[plate]:Hide() end
    TotemIcons.Fade(plate.UnitFrame, false)
end

function TotemIcons.Update(unit)
    if not Readable(unit) then return end
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate or plate:IsForbidden() then return end
    local mode = TotemIcons.Mode()
    local art = mode ~= "off" and TotemIcons.For(unit)
    if not art then
        TotemIcons.Clear(plate)
        return
    end
    local icon = TotemIcons.Get(plate)
    icon.art:SetTexture(art)
    icon:ClearAllPoints()
    local unitFrame = plate.UnitFrame
    if mode == "instead" then
        icon:SetSize(TotemIcons.SIZE_INSTEAD, TotemIcons.SIZE_INSTEAD)
        icon:SetPoint("CENTER", PlateBar(plate), "CENTER", 0, 0)
        TotemIcons.Fade(unitFrame, true)
    else
        icon:SetSize(TotemIcons.SIZE, TotemIcons.SIZE)
        -- above the name when the plate shows one, else above the health bar
        local name = unitFrame and unitFrame.name
        local over = (name and not name:IsForbidden() and name:IsShown()) and name or PlateBar(plate)
        icon:SetPoint("BOTTOM", over, "TOP", 0, TotemIcons.GAP)
        TotemIcons.Fade(unitFrame, false)
    end
    icon:Show()
end

function TotemIcons.OnEvent(_, event, unit)
    if not Readable(unit) then return end
    if event == "NAME_PLATE_UNIT_ADDED" then
        TotemIcons.Update(unit)
    else
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        if plate then TotemIcons.Clear(plate) end
    end
end

-- Switched on and off live from the options
function TotemIcons.Refresh()
    local on = TotemIcons.Mode() ~= "off"
    if on and not TotemIcons.events then
        TotemIcons.events = CreateFrame("Frame")
        TotemIcons.events:SetScript("OnEvent", TotemIcons.OnEvent)
    end
    local events = TotemIcons.events
    -- never on this session: Blizzard's plates stay untouched
    if not events then return end
    if on then
        events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
        events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    else
        events:UnregisterAllEvents()
    end
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        local unit = plate.unitToken
        if on and unit and Readable(unit) then TotemIcons.Update(unit) else TotemIcons.Clear(plate) end
    end
end

local _, ns = ...

--------------------------------------------------
-- IN RANGE MARK (an extension for FlareUI)
-- A mark on a totem while its buff is on you: marching ants, yellow dashes moving round its edge. Walk
-- out of the totem's range and the mark goes. On the totems standing (FlareUI Totems), and with Also on
-- Action Bars on the totem's spell wherever it is slotted: Blizzard's totem bar and the action bars.
-- Your buffs are secret in a fight, so the game draws the mark: an AuraContainer with one group
-- filtered by the totem's buff IDs, whose button carries the mark. Only a buff that is up can be shown
-- this way (nothing can be shown for a missing one, and whether an aura's frame shows is itself
-- secret), which is why the mark says "in range".
-- A totem's buff IDs are learned out of a fight, by icon (any language), and saved account-wide:
-- totemBuffs[icon] = { [buff ID] = true }. Totems with no buff of their own (Searing, Tremor,
-- Windfury's weapon enchant) are never learned and never marked.
-- The art under a container's button has "secret aspects": no OnShow script may be set on it, and in a
-- fight it is a forbidden object (any call from an addon is an error). So it is set up once, as the
-- game makes it, and touched again only out of a fight, behind IsForbidden. Containers are made out of
-- a fight.
--------------------------------------------------
local InRange = {}
ns.InRange = InRange

local MEDIA = "Interface\\AddOns\\FlareUI_TotemMarks\\Media\\"
local MAX = _G.MAX_TOTEMS or 4
local MARK_YELLOW = { 1, 0.85, 0.1 }
-- Marching Ants (tools/auraart.js): 4 x 4 frames of dashes round a circle, and round a square, each
-- frame a step on, played as a flipbook. (The ring was first one picture turned by a Rotation
-- animation: a turning texture keeps the place it had when the turning began, so a mark moved onto
-- another totem button was drawn where it used to be.)
local ANTS_RING, ANTS_SQUARE = MEDIA .. "AntsRing", MEDIA .. "AntsSquare"
local ANTS_GRID = 4
local ANTS_STEP_RING = 0.67   -- seconds the ring's dashes take to move on by one dash and gap
local ANTS_STEP = 0.5         -- the same for the square's
local MARK_GROUP = "buff"
local LEVEL_MARK = 4     -- over a totem button: above the swipe, under the time
local BAR_PREFIXES = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
    "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button", "MultiCastActionButton",
}

local coverHost   -- the marks' frame, on FlareUI's totem holder (faded with it)
local UpdateRange

local function Readable(v) return canaccessvalue == nil or canaccessvalue(v) end

-- Shamans only: no other class has totems of its own to mark, and nothing here runs for them
local isShaman
local function MarkOn()
    if isShaman == nil then
        local _, class = UnitClass("player")
        if class then isShaman = class == "SHAMAN" end
    end
    return isShaman and ns.db and ns.db.inRange == true or false
end

local function BarsOn()
    return not (ns.db and ns.db.inRangeBars == false)
end

local function AurasLocked()
    if not (C_Secrets and C_Secrets.ShouldAurasBeSecret) then return false end
    local ok, secret = pcall(C_Secrets.ShouldAurasBeSecret)
    return not ok or (canaccessvalue ~= nil and not canaccessvalue(secret)) or secret == true
end

-- icon -> the IDs of the buffs seen with that totem down
local function Learned()
    if not ns.db then return nil end
    if type(ns.db.totemBuffs) ~= "table" then ns.db.totemBuffs = {} end
    return ns.db.totemBuffs
end

-- icon -> the slot (element) its totem stands in, noted out of a fight: in one the totems can't be
-- read, and a totem button is then only trusted to show an icon that belongs in its slot
local function Slots()
    if not ns.db then return {} end
    if type(ns.db.totemSlots) ~= "table" then ns.db.totemSlots = {} end
    return ns.db.totemSlots
end

-- Out of a fight: the buffs on you that share a standing totem's icon are that totem's
local function Learn()
    if InCombatLockdown() or AurasLocked() then return end
    local learned = Learned()
    if not learned then return end
    local icons
    local slots = Slots()
    for slot = 1, MAX do
        local ok, have, _, _, _, icon = pcall(GetTotemInfo, slot)
        if ok and Readable(have) and have and Readable(icon) and icon then
            icons = icons or {}
            icons[icon] = true
            slots[icon] = slot
        end
    end
    if not icons then return end
    local changed = false
    for i = 1, 40 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not ok or not Readable(aura) or not aura then break end
        local icon, id = aura.icon, aura.spellId
        if Readable(icon) and Readable(id) and icon and type(id) == "number" and icons[icon] then
            learned[icon] = type(learned[icon]) == "table" and learned[icon] or {}
            if not learned[icon][id] then
                learned[icon][id] = true
                changed = true
            end
        end
    end
    return changed
end

local function IDKey(ids)
    local list = {}
    for id in pairs(ids) do list[#list + 1] = id end
    table.sort(list)
    return table.concat(list, ",")
end

-- The mark's art on a frame, in the frame's shape (round on a totem, square on an action button). The
-- ants march by the texture's own animation, so nothing runs in Lua: a flipbook of dashes a step
-- further round the shape each frame (a client without flipbooks shows them standing).
local function MakeMark(art, round)
    art.Ants = art:CreateTexture(nil, "OVERLAY")
    art.Ants:SetTexture(round and ANTS_RING or ANTS_SQUARE)
    art.Ants:SetVertexColor(MARK_YELLOW[1], MARK_YELLOW[2], MARK_YELLOW[3], 1)
    art.Ants:SetAllPoints(art)
    art.March = art.Ants:CreateAnimationGroup()
    art.March:SetLooping("REPEAT")
    art.Ants:SetTexCoord(0, 1 / ANTS_GRID, 0, 1 / ANTS_GRID)   -- the first frame
    local ok, flip = pcall(art.March.CreateAnimation, art.March, "FlipBook")
    if ok and flip then
        flip:SetDuration(round and ANTS_STEP_RING or ANTS_STEP)
        pcall(flip.SetFlipBookRows, flip, ANTS_GRID)
        pcall(flip.SetFlipBookColumns, flip, ANTS_GRID)
        pcall(flip.SetFlipBookFrames, flip, ANTS_GRID * ANTS_GRID)
    end
    return art
end

-- The ants on or off; art in a fight is left as it is (the option is a setting: changed out of one)
local function StyleMark(art, on)
    if art.IsForbidden and art:IsForbidden() then return end
    -- (the texture can be forbidden while its frame is not)
    pcall(function()
        art.Ants:SetShown(on)
        if on then art.March:Play() else art.March:Stop() end
    end)
end

local markFailed = false
local function MarkContainer(parent, ids, init)
    if markFailed or InCombatLockdown() then return nil end
    if C_AddOns.DoesAddOnExist("Blizzard_AuraContainer") and not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
    end
    local ok, container = pcall(CreateFrame, "AuraContainer", nil, parent, "CustomAuraContainerTemplate")
    if not (ok and type(container) == "table" and container.AddAuraGroup) then
        markFailed = true
        return nil
    end
    container:SetUnit("player")
    container:SetSize(1, 1)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    local E = Enum or {}
    local added = pcall(container.AddAuraGroup, container, MARK_GROUP, "HELPFUL", {
        maxFrameCount = 1,
        candidateFilters = { includeSpellIDs = ids },
        sortMethod = E.AuraContainerSortMethod and E.AuraContainerSortMethod.Default,
        sortDirection = E.AuraContainerSortDirection and E.AuraContainerSortDirection.Normal,
        initializeFrame = init,
        layout = { elementWidth = 1, elementHeight = 1, elementSpacing = 0, lineSpacing = 0 },
    })
    if not added then
        markFailed = true
        return nil
    end
    container:Show()
    pcall(container.SetEnabled, container, true)
    return container
end

-- THE TOTEMS STANDING. Blizzard's totem buttons are pooled and change slot, and the art can't be
-- moved in a fight, so each learned totem's mark is anchored to a frame of this addon's own, its spot.
-- The spot is what moves: onto the icon of the totem standing, or off the screen.
-- mark: { container, sig, spot, arts, parked, used }
local marks = {}       -- marks[icon]
local markLevel = 0    -- a totem button's frame level, for art made later

local seatLog = {}   -- the last moves, for /flaretotemsdebug
local function LogSeat(text)
    seatLog[#seatLog + 1] = ("%.2f %s"):format(GetTime(), text)
    if #seatLog > 40 then table.remove(seatLog, 1) end
end

local function ParkMark(mark)
    if mark.parked then return end
    mark.parked = true
    mark.seat = nil
    mark.spot:ClearAllPoints()
    mark.spot:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -50, 50)
    mark.spot:SetSize(1, 1)
    LogSeat("park")
end

-- (a spot already on this button is left alone: nothing is moved that doesn't have to be)
local function SeatMark(mark, button)
    if mark.seat == button and not mark.parked then return end
    mark.parked = false
    mark.seat = button
    mark.spot:ClearAllPoints()
    mark.spot:SetAllPoints(button.Icon)
    local okRect, left, bottom, width = pcall(mark.spot.GetRect, mark.spot)
    LogSeat(("seat slot %s points %s rect %s,%s w%s combat=%s"):format(tostring(button.slot), tostring(mark.spot:GetNumPoints()),
        okRect and left and math.floor(left) or "?", okRect and bottom and math.floor(bottom) or "?",
        okRect and width and math.floor(width) or "?", tostring(InCombatLockdown())))
end

-- Edit Mode shows FlareUI's sample totems: the marks step aside with the live totems
local function EditModeAlpha()
    if not coverHost then return end
    local manager = _G.EditModeManagerFrame
    coverHost:SetAlpha(manager and manager:IsShown() and 0 or 1)
end

-- The marks draw in the totem buttons' own layer of the screen (strata), or a higher one, never a
-- lower: the buttons' layer changes as Blizzard and FlareUI hand the totem frame back and forth, and
-- a mark left in a lower one is drawn underneath the icon, out of sight.
local STRATA_RANK = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6,
                      FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
local function RaiseHost(button)
    if not coverHost then return end
    local ok, strata = pcall(button.GetFrameStrata, button)
    if not (ok and Readable(strata) and STRATA_RANK[strata]) then return end
    local wanted = STRATA_RANK[strata] > STRATA_RANK.MEDIUM and strata or "MEDIUM"
    if coverHost:GetFrameStrata() ~= wanted then pcall(coverHost.SetFrameStrata, coverHost, wanted) end
end

local function BuildMarks(learned)
    if markFailed or InCombatLockdown() then return end
    if not coverHost then
        local holder = _G.FlareUI_Totems or UIParent
        coverHost = CreateFrame("Frame", nil, holder)
        coverHost:SetAllPoints(holder)
        coverHost:SetFrameStrata("MEDIUM")
        local manager = _G.EditModeManagerFrame
        if manager then
            manager:HookScript("OnShow", EditModeAlpha)
            manager:HookScript("OnHide", EditModeAlpha)
        end
        EditModeAlpha()
    end
    for icon, ids in pairs(learned) do
        local key = type(ids) == "table" and next(ids) and IDKey(ids)
        local mark = marks[icon]
        if key and not mark then
            mark = { arts = setmetatable({}, { __mode = "k" }), spot = CreateFrame("Frame", nil, coverHost) }
            ParkMark(mark)
            local made = setmetatable({}, { __mode = "k" })   -- the game can set a button up again
            mark.container = MarkContainer(coverHost, ids, function(auraButton)
                if made[auraButton] then return end
                local art = CreateFrame("Frame", nil, auraButton)
                made[auraButton] = art
                art:SetAllPoints(mark.spot)
                art:SetFrameLevel(markLevel + LEVEL_MARK)
                StyleMark(MakeMark(art, true), MarkOn())
                mark.arts[art] = true
            end)
            if not mark.container then return end
            mark.sig = key
            marks[icon] = mark
        elseif key and mark.sig ~= key then
            -- another rank's buff learned since
            if pcall(mark.container.SetAuraGroupCandidateFilters, mark.container, MARK_GROUP, { includeSpellIDs = ids }) then
                mark.sig = key
            end
        end
    end
end

-- The icon of the totem on a button: GetTotemInfo by its slot, which is the truth whenever it can be
-- read (a totem with no icon there has none: the button's texture is then a leftover from the totem
-- it showed before, the buttons being reused). In a fight it can't be read; the icon the button shows
-- is taken when that can be read and the totem belongs in the button's slot. A totem dropped in a
-- fight can't be told at all (its icon is secret too): the second result says so.
local function TotemOn(button, tex)
    local slot = button.slot
    if not (Readable(slot) and type(slot) == "number") then return nil, false end
    local ok, have, _, _, _, icon = pcall(GetTotemInfo, slot)
    if ok and Readable(have) and Readable(icon) then
        return have and icon or nil, false
    end
    local shown = tex.GetTextureFileID and tex:GetTextureFileID()
    if Readable(shown) and shown then
        local home = Slots()[shown]   -- (a totem whose slot was never noted is taken on trust)
        if home == nil or home == slot then return shown, false end
    end
    return nil, true
end

-- THE BARS. An action button holding a learned totem's spell (the totem's icon is its spell's) gets a
-- container of its own, its mark laid on the button's icon.
local barButtons
local function BarButtons()
    if barButtons then return barButtons end
    barButtons = {}
    for _, prefix in ipairs(BAR_PREFIXES) do
        for i = 1, 12 do
            local button = _G[prefix .. i]
            if button then barButtons[#barButtons + 1] = button end
        end
    end
    return barButtons
end

-- the icon of the spell in a button's slot (a spell, or a macro that casts one)
local function BarSpellIcon(button)
    local slot = button.action
    if not (Readable(slot) and type(slot) == "number" and slot > 0) then return nil end
    local ok, kind, id, subType = pcall(GetActionInfo, slot)
    if not (ok and Readable(kind) and Readable(id)) then return nil end
    if kind == "spell" or (kind == "macro" and Readable(subType) and subType == "spell") then
        local okIcon, icon = pcall(C_Spell.GetSpellTexture, id)
        if okIcon and Readable(icon) then return icon end
    end
end

local function SyncBarMark(button, learned, on)
    local mark = button.FlareUIExt_TotemMark
    local icon = learned and BarSpellIcon(button)
    local ids = icon and learned[icon]
    local key = type(ids) == "table" and next(ids) and IDKey(ids)
    if not key then
        if mark and mark.sig then
            -- (refused in a fight: tried again at its end)
            if pcall(mark.container.SetAuraGroupEnabled, mark.container, MARK_GROUP, false) then mark.sig = nil end
        end
        return
    end
    if not mark then
        mark = { arts = setmetatable({}, { __mode = "k" }) }
        local made = setmetatable({}, { __mode = "k" })   -- the game can set a button up again
        mark.container = MarkContainer(button, ids, function(auraButton)
            if made[auraButton] then return end
            local art = CreateFrame("Frame", nil, auraButton)
            made[auraButton] = art
            art:SetAllPoints(button.icon or button)
            art:SetFrameLevel(button:GetFrameLevel() + LEVEL_MARK)
            StyleMark(MakeMark(art, false), MarkOn())
            mark.arts[art] = true
        end)
        if not mark.container then return end
        button.FlareUIExt_TotemMark = mark
        mark.sig = key
    elseif mark.sig ~= key then
        if pcall(mark.container.SetAuraGroupCandidateFilters, mark.container, MARK_GROUP, { includeSpellIDs = ids })
            and pcall(mark.container.SetAuraGroupEnabled, mark.container, MARK_GROUP, true) then
            mark.sig = key
        end
    end
    for art in pairs(mark.arts) do StyleMark(art, on) end
end

-- Listens while the option is on: totems and slots change, and out of a fight your buffs teach
local rangeEvents = CreateFrame("Frame")
local listening, pending = false, false
local RANGE_EVENTS = { "PLAYER_TOTEM_UPDATE", "PLAYER_REGEN_ENABLED", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED",
                       "UPDATE_BONUS_ACTIONBAR", "SPELLS_CHANGED", "PLAYER_ENTERING_WORLD" }
local function Listen(on)
    if on == listening then return end
    listening = on
    if on then
        rangeEvents:RegisterUnitEvent("UNIT_AURA", "player")
        for _, event in ipairs(RANGE_EVENTS) do rangeEvents:RegisterEvent(event) end
    else
        rangeEvents:UnregisterAllEvents()
    end
end

UpdateRange = function()
    local on = MarkOn()
    Listen(on)
    local learned = on and Learned()
    local calm = not InCombatLockdown()
    if learned and calm then
        Learn()
        BuildMarks(learned)
    end
    -- the totems standing
    local frame = _G.TotemFrame
    for _, mark in pairs(marks) do mark.used = false end
    if learned and frame and frame.totemPool then
        for button in frame.totemPool:EnumerateActive() do
            local tex = button.Icon and button.Icon.Texture
            local icon, untold
            if tex then icon, untold = TotemOn(button, tex) end
            local function Seat(mark)
                local ok, err = pcall(SeatMark, mark, button)
                if ok then
                    markLevel = button:GetFrameLevel()
                    mark.used = true
                    RaiseHost(button)
                else
                    mark.seat = nil
                    LogSeat("seat failed: " .. tostring(err))
                end
            end
            if icon and marks[icon] then
                Seat(marks[icon])
            elseif untold then
                -- A totem dropped in a fight: which one can't be read, but its slot (element) can, and
                -- only one totem stands in a slot. Every learned totem of that slot is seated here; the
                -- game shows only the mark whose buff is on you.
                local slot, slots = button.slot, Slots()
                for learnedIcon, mark in pairs(marks) do
                    if slots[learnedIcon] == slot then Seat(mark) end
                end
            end
        end
    end
    for _, mark in pairs(marks) do
        if not mark.used then pcall(ParkMark, mark) end
        for art in pairs(mark.arts) do
            StyleMark(art, on)
            -- (art can be forbidden out of a fight too, while auras are still secret)
            if calm and not art:IsForbidden() then pcall(art.SetFrameLevel, art, markLevel + LEVEL_MARK) end
        end
    end
    -- the bars
    local bars = learned and BarsOn() and learned or nil
    for _, button in ipairs(BarButtons()) do
        if bars or button.FlareUIExt_TotemMark then SyncBarMark(button, bars, on) end
    end
end

-- A burst of events is read once, on the next frame (after Blizzard and FlareUI have laid the totems
-- out)
local function Schedule()
    if pending then return end
    pending = true
    C_Timer.After(0, function()
        pending = false
        UpdateRange()
    end)
end

-- Your buffs changing only matter when they teach a totem's buff (never in a fight)
rangeEvents:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_TOTEM_UPDATE" or event == "PLAYER_REGEN_ENABLED" then
        LogSeat("event " .. event .. " combat=" .. tostring(InCombatLockdown()))
    end
    if event == "UNIT_AURA" and not Learn() then return end
    Schedule()
end)

local hooked = false
function InRange.Refresh()
    -- the totem buttons are placed again whenever Blizzard lays the totem frame out
    local frame = _G.TotemFrame
    if not hooked and MarkOn() and frame and type(frame.Layout) == "function" then
        hooked = true
        hooksecurefunc(frame, "Layout", function() if MarkOn() then Schedule() end end)
    end
    UpdateRange()
end

-- /flaretotemsdebug: what the In Range Mark sees right now, printed and saved (for bug reports)
function InRange.Debug()
    local out = {}
    local function add(text) out[#out + 1] = text end
    local function show(v)
        if v == nil then return "nil" end
        if not Readable(v) then return "<secret>" end
        return tostring(v)
    end
    local _, class = UnitClass("player")
    add(("class=%s on=%s bars=%s listening=%s combat=%s locked=%s failed=%s"):format(show(class), show(MarkOn()),
        show(BarsOn()), show(listening), show(InCombatLockdown()), show(AurasLocked()), show(markFailed)))
    local holder = _G.FlareUI_Totems
    add(("holder=%s holderShown=%s host=%s hostParentIsHolder=%s hostAlpha=%s"):format(show(holder ~= nil),
        show(holder and holder:IsShown()), show(coverHost ~= nil), show(coverHost and coverHost:GetParent() == holder),
        show(coverHost and coverHost:GetAlpha())))
    for slot = 1, MAX do
        local ok, have, name, _, _, icon = pcall(GetTotemInfo, slot)
        add(("totem %d: ok=%s have=%s name=%s icon=%s"):format(slot, show(ok), show(have), show(name), show(icon)))
    end
    for i = 1, 40 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not ok then add("buff " .. i .. ": error " .. show(aura)) break end
        if not Readable(aura) then add("buff " .. i .. ": <secret>") break end
        if not aura then break end
        add(("buff %d: name=%s icon=%s id=%s"):format(i, show(aura.name), show(aura.icon), show(aura.spellId)))
    end
    for icon, ids in pairs(Learned() or {}) do
        add(("learned %s: %s slot=%s"):format(show(icon), type(ids) == "table" and IDKey(ids) or show(ids), show(Slots()[icon])))
    end
    for icon, mark in pairs(marks) do
        local arts = 0
        for _ in pairs(mark.arts) do arts = arts + 1 end
        add(("mark %s: sig=%s parked=%s used=%s arts=%d"):format(show(icon), show(mark.sig), show(mark.parked), show(mark.used), arts))
        local function rect(region)
            local ok, l, b, w, h = pcall(region.GetRect, region)
            if not ok then return "error" end
            return ("%s,%s %sx%s"):format(show(l and math.floor(l)), show(b and math.floor(b)), show(w and math.floor(w)), show(h and math.floor(h)))
        end
        local spot = mark.spot
        local okPoint, _, relativeTo = pcall(spot.GetPoint, spot, 1)
        add(("  spot: points=%s rect=%s onSeatIcon=%s seatIconRect=%s shown=%s visible=%s strata=%s"):format(show(spot:GetNumPoints()),
            rect(spot), show(okPoint and mark.seat and relativeTo == mark.seat.Icon), mark.seat and rect(mark.seat.Icon) or "none",
            show(spot:IsShown()), show(spot:IsVisible()), show(spot:GetFrameStrata())))
        local container = mark.container
        local okCon, conShown = pcall(container.IsShown, container)
        add(("  container: forbidden=%s shown=%s"):format(show(container:IsForbidden()), okCon and show(conShown) or "error"))
        local n = 0
        for art in pairs(mark.arts) do
            n = n + 1
            if n > 2 then
                -- (the rest are the same)
            elseif art:IsForbidden() or InCombatLockdown() then
                add("  art " .. n .. ": forbidden=" .. show(art:IsForbidden()) .. " (in combat)")
            else
                local parent = art:GetParent()
                local okVis, vis = pcall(art.IsVisible, art)
                local okPar, parVis = pcall(parent.IsShown, parent)
                add(("  art %d: shown=%s visible=%s parentShown=%s rect=%s level=%s strata=%s ants=%s playing=%s alpha=%s"):format(n,
                    show(art:IsShown()), okVis and show(vis) or "error", okPar and show(parVis) or "error", rect(art),
                    show(art:GetFrameLevel()), show(art:GetFrameStrata()), show(art.Ants:IsShown()), show(art.March:IsPlaying()),
                    show(art:GetEffectiveAlpha())))
            end
        end
    end
    for _, line in ipairs(seatLog) do add("  log " .. line) end
    add("now " .. ("%.2f"):format(GetTime()))
    local frame = _G.TotemFrame
    add(("totemFrame=%s pool=%s shown=%s"):format(show(frame ~= nil), show(frame and frame.totemPool ~= nil), show(frame and frame:IsShown())))
    if frame and frame.totemPool then
        for button in frame.totemPool:EnumerateActive() do
            local tex = button.Icon and button.Icon.Texture
            add(("button: slot=%s seen=%s texture=%s level=%s strata=%s iconLevel=%s parent=%s hostStrata=%s"):format(show(button.slot),
                show(tex and TotemOn(button, tex)), show(tex and tex.GetTextureFileID and tex:GetTextureFileID()),
                show(button:GetFrameLevel()), show(button:GetFrameStrata()), show(button.Icon and button.Icon:GetFrameLevel()),
                show(frame:GetParent() and frame:GetParent():GetName()), show(coverHost and coverHost:GetFrameStrata())))
        end
    end
    for _, button in ipairs(BarButtons()) do
        local icon = BarSpellIcon(button)
        local learned = Learned()
        if icon and learned and learned[icon] then
            local mark = button.FlareUIExt_TotemMark
            add(("bar %s: icon=%s mark=%s sig=%s"):format(show(button:GetName()), show(icon), show(mark ~= nil), show(mark and mark.sig)))
        end
    end
    if ns.db then ns.db.debug = out end
    for _, line in ipairs(out) do print("|cff00ccffTotems:|r " .. line) end
end
SLASH_FLARETOTEMSDEBUG1 = "/flaretotemsdebug"
SlashCmdList["FLARETOTEMSDEBUG"] = function() InRange.Debug() end

-- Drive-By Buff: options window and slash commands.
local ADDON, ns = ...
if ns.disabled then return end
local L = ns.L
local PREFIX = ns.PREFIX

local panel
local checks = {}

local function AddCheck(parent, x, y, label, tip, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    fs:SetText(label)
    cb:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        ns.Refresh()
    end)
    if tip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(label)
            GameTooltip:AddLine(tip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    cb.Sync = function() cb:SetChecked(get() and true or false) end
    checks[#checks + 1] = cb
    return cb, fs
end

local function AddHeader(parent, y, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", 16, y)
    fs:SetText(text)
    return fs
end

local function AddButton(parent, x, y, width, text, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetPoint("TOPLEFT", x, y)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

local function Build()
    local db = ns.db
    panel = CreateFrame("Frame", "DriveByBuffOptions", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:SetClampedToScreen(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    if panel.SetBackdrop then
        panel:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        panel:SetBackdropColor(0.04, 0.06, 0.11, 0.96)
        panel:SetBackdropBorderColor(0.41, 0.8, 0.94, 1)
    end
    tinsert(UISpecialFrames, "DriveByBuffOptions") -- Esc closes it

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText("Drive-By Buff")

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    local y = -44
    AddCheck(panel, 14, y, L["Enabled"], nil,
        function() return db.enabled end, function(v) db.enabled = v end)
    y = y - 26
    AddCheck(panel, 14, y, L["Include myself"], nil,
        function() return db.self end, function(v) db.self = v end)
    y = y - 26
    AddCheck(panel, 14, y, L["Caster buffs skip warriors and rogues"],
        L["Buffs that only help mana users (Arcane Intellect, Divine Spirit) are not offered to classes without mana."],
        function() return db.manaOnly end, function(v) db.manaOnly = v end)
    y = y - 26
    AddCheck(panel, 14, y, L["Offer PvP-flagged strangers"],
        L["Buffing a PvP-flagged player flags you for PvP too. Off: they are skipped unless you are already flagged."],
        function() return db.pvp end, function(v) db.pvp = v end)
    y = y - 26
    AddCheck(panel, 14, y, L["Ignore strangers in cities and inns"],
        L["While you are resting, only your group is offered buffs."],
        function() return db.quietResting end, function(v) db.quietResting = v end)
    y = y - 26
    AddCheck(panel, 14, y, L["Hide the button in combat"],
        L["The game does not let the button update in combat, so by default it hides until combat ends."],
        function() return db.hideInCombat end,
        function(v)
            db.hideInCombat = v
            if InCombatLockdown() then
                print(PREFIX .. L["this takes effect after combat."])
            else
                ns.ApplyCombatHide()
            end
        end)
    y = y - 36

    AddHeader(panel, y, L["Buffs"])
    local strangersHead = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    strangersHead:SetPoint("TOPLEFT", 236, y - 2)
    strangersHead:SetText(L["also strangers"])
    y = y - 20

    local buffs = ns.MyBuffs()
    if #buffs == 0 then
        local none = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        none:SetPoint("TOPLEFT", 18, y - 4)
        none:SetWidth(330)
        none:SetJustifyH("LEFT")
        none:SetText(L["Your class has no buffs that are cast on other players, so the button stays hidden on this character."])
        y = y - 40
    else
        for _, buff in ipairs(buffs) do
            local name = ns.SpellName(buff.ranks[1][1]) or buff.key
            local cb, fs = AddCheck(panel, 14, y, name, nil,
                function()
                    local v = db.buffs[buff.key]
                    if v == nil then return buff.default end
                    return v
                end,
                function(v) db.buffs[buff.key] = v end)
            if not ns.HighestKnown(buff) then
                fs:SetText(name .. " |cff808080(" .. L["not learned"] .. ")|r")
            end
            AddCheck(panel, 258, y, "", nil,
                function()
                    local v = db.strangers[buff.key]
                    if v == nil then return buff.strangers end
                    return v
                end,
                function(v) db.strangers[buff.key] = v end)
            y = y - 26
        end
    end
    y = y - 12

    AddHeader(panel, y, L["Noticing people"])
    y = y - 20
    local platesText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    platesText:SetPoint("TOPLEFT", 18, y)
    platesText:SetWidth(330)
    platesText:SetJustifyH("LEFT")
    platesText:SetText(L["People running by are noticed through friendly nameplates. With them off, only your group, your target and your mouseover are checked."])
    y = y - 44
    local platesButton
    local function SyncPlates()
        platesButton:SetText(ns.FriendlyPlatesOn() and L["Friendly nameplates: ON"] or L["Friendly nameplates: OFF"])
    end
    platesButton = AddButton(panel, 16, y, 190, "", function()
        ns.SetFriendlyPlates(not ns.FriendlyPlatesOn())
        SyncPlates()
    end)
    y = y - 36

    AddHeader(panel, y, L["Button"])
    y = y - 22
    local moveButton
    local function SyncMove()
        moveButton:SetText(ns.IsUnlocked() and L["Lock position"] or L["Move the button"])
    end
    moveButton = AddButton(panel, 16, y, 150, "", function()
        ns.ToggleMove()
        SyncMove()
    end)
    AddButton(panel, 174, y, 150, L["Reset position"], function() ns.ResetPosition() end)
    y = y - 34

    panel:SetSize(370, -y + 10)
    panel:SetScript("OnShow", function()
        for _, cb in ipairs(checks) do cb.Sync() end
        SyncPlates()
        SyncMove()
    end)
    panel:Hide()
end

local function ToggleOptions()
    if not ns.db then return end
    if not panel then Build() end
    if panel:IsShown() then panel:Hide() else panel:Show() end
end

local function OnOff(v) return v and "|cff40ff40on|r" or "|cffff4040off|r" end

SLASH_DRIVEBYBUFF1 = "/dbb"
SLASH_DRIVEBYBUFF2 = "/drivebybuff"
SlashCmdList.DRIVEBYBUFF = function(msg)
    local db = ns.db
    if not db then return end
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "" or msg == "options" or msg == "config" then
        ToggleOptions()
    elseif msg == "on" or msg == "off" then
        db.enabled = (msg == "on")
        print(PREFIX .. OnOff(db.enabled))
        ns.Refresh()
    elseif msg == "plates" then
        ns.SetFriendlyPlates(not ns.FriendlyPlatesOn())
    elseif msg == "move" then
        ns.ToggleMove()
    elseif msg == "reset" then
        ns.ResetPosition()
    elseif msg == "debug" then
        db.debug = not db.debug
        print(PREFIX .. "debug log " .. OnOff(db.debug) .. " (" .. #(db.log or {}) .. " lines; /reload saves it to disk)")
    elseif msg == "clearlog" then
        db.log = nil
        print(PREFIX .. "debug log cleared.")
    else
        print(PREFIX .. L["commands:"])
        print("  /dbb - " .. L["open the options window"])
        print("  /dbb on | off - " .. L["turn the button on or off"])
        print("  /dbb plates - " .. L["toggle friendly nameplates"])
        print("  /dbb move - " .. L["show the button so you can drag it; again to lock"])
        print("  /dbb reset - " .. L["put the button back in the middle"])
        print("  /dbb debug - " .. L["toggle the debug log (for bug reports)"])
    end
end

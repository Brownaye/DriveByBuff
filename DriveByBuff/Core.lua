-- Drive-By Buff
-- A button pops up with the name of a nearby player or group member who is
-- missing one of your buffs. Left-click casts it on them.
--
-- How people are noticed:
--   * group members: always (party / raid unit tokens)
--   * strangers: friendly nameplates, your mouseover and your target
--
-- Things this client enforces, which shape the code below:
--   * a cast button cannot be changed in combat, so the list only updates
--     out of combat (and the button hides in combat by default)
--   * a spell cannot be cast straight at a nameplate, so strangers are
--     targeted by name, buffed, and your previous target is put back
--   * some values are "secret" and must never be stored or compared

local ADDON, ns = ...
if ns.disabled then return end
local L = ns.L

local PREFIX = "|cff69ccf0Drive-By Buff|r: "
ns.PREFIX = PREFIX

local STICKY    = 4    -- seconds a stranger stays listed after we lose sight of them
local SKIP_TIME = 300  -- seconds a right-clicked person is skipped
local DONE_TIME = 10   -- seconds to wait for a buff we just cast to show up

local DEFAULTS = {
    enabled = true,
    self = true,
    pvp = false,
    manaOnly = true,
    hideInCombat = true,
    quietResting = false,
    debug = false,
}

local db
local holder, button
local unlocked = false
local myBuffs = {}      -- this class's buffs (from Data.lua)
local buffByKey = {}
local buffBySpell = {}  -- rank spell ID -> buff
local plateUnits = {}   -- nameplate unit tokens on screen
local strangers = {}    -- guid -> record, for people outside the group
local skipped = {}      -- guid -> time until which the person is skipped
local done = {}         -- guid .. key -> time until which that buff is not re-offered
local myCast = {}       -- guid -> { key, time } of the exclusive buff we last put on them
local current           -- record shown on the button
local lastClick         -- { guid, key, name, time }
local lastPreClick

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------
local function Secret(v)
    return issecretvalue ~= nil and issecretvalue(v) or false
end

-- Debug log, kept in DriveByBuffDB.log (saved on /reload or logout).
local function Log(fmt, ...)
    if not db or not db.debug then return end
    local n = select("#", ...)
    local args = { ... }
    for i = 1, n do
        if Secret(args[i]) then args[i] = "<secret>" else args[i] = tostring(args[i]) end
    end
    local ok, text = pcall(string.format, fmt, unpack(args, 1, n))
    if not ok then text = "log format error: " .. fmt end
    db.log = db.log or {}
    db.log[#db.log + 1] = date("%H:%M:%S") .. " " .. text
    while #db.log > 300 do table.remove(db.log, 1) end
end

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    if GetSpellInfo then return (GetSpellInfo(id)) end
end
ns.SpellName = SpellName

local function SpellSubtext(id)
    if C_Spell and C_Spell.GetSpellSubtext then return C_Spell.GetSpellSubtext(id) end
    if GetSpellSubtext then return GetSpellSubtext(id) end
end

local function SpellTexture(id)
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
    if GetSpellTexture then return GetSpellTexture(id) end
end
ns.SpellTexture = SpellTexture

local function Known(id)
    if IsSpellKnownOrOverridesKnown then return IsSpellKnownOrOverridesKnown(id) end
    if IsPlayerSpell then return IsPlayerSpell(id) end
    if IsSpellKnown then return IsSpellKnown(id) end
    return false
end

---------------------------------------------------------------------------
-- Buff helpers
---------------------------------------------------------------------------
local function HighestKnown(buff)
    for i = #buff.ranks, 1, -1 do
        if Known(buff.ranks[i][1]) then return i end
    end
end
ns.HighestKnown = HighestKnown

-- Highest rank we know that can go on someone of this level (a buff rank
-- cannot be cast on a target more than 10 levels below it).
local function RankForLevel(buff, level, highest)
    if not level or level <= 0 then return highest end
    for i = highest, 1, -1 do
        if level >= buff.ranks[i][2] - 10 and Known(buff.ranks[i][1]) then return i end
    end
    return nil
end

local function CastText(buff, index, highest)
    local id = buff.ranks[index][1]
    local name = SpellName(id)
    if not name then return nil end
    if index < highest then
        local sub = SpellSubtext(id)
        if sub and sub ~= "" then return name .. "(" .. sub .. ")" end
    end
    return name
end

local function BuffEnabled(buff)
    local v = db.buffs[buff.key]
    if v == nil then return buff.default end
    return v
end

local function StrangersEnabled(buff)
    local v = db.strangers[buff.key]
    if v == nil then return buff.strangers end
    return v
end

-- Returns inRange, spellRangeAnswer, within28yards (the last two for the log).
local function InRange(unit, id)
    local r
    if C_Spell and C_Spell.IsSpellInRange then
        local ok, v = pcall(C_Spell.IsSpellInRange, id, unit)
        if ok then r = v end
    elseif IsSpellInRange then
        local name = SpellName(id)
        r = name and IsSpellInRange(name, unit)
        if r == 1 then r = true elseif r == 0 then r = false end
    end
    if Secret(r) then r = nil end

    -- The spell check often has no answer for people outside the group, so
    -- also ask whether they are within 28 yards.
    local near
    if CheckInteractDistance and not InCombatLockdown() then
        local ok, v = pcall(CheckInteractDistance, unit, 4)
        if ok and not Secret(v) then near = v end
    end

    local inRange
    if r ~= nil then inRange = r
    elseif near ~= nil then inRange = near and true or false
    else inRange = true end
    return inRange, r, near
end

-- One pass over a unit's buffs: which spell IDs and names they have, and
-- which names were cast by us. Errors (unreadable data) are caught below.
local function ScanAuras(unit)
    local ids, names, mine = {}, {}, {}
    for i = 1, 40 do
        local name, id, src
        if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
            local aura = C_UnitAuras.GetBuffDataByIndex(unit, i)
            if not aura then break end
            name, id, src = aura.name, aura.spellId, aura.sourceUnit
        elseif UnitBuff then
            local n, _, _, _, _, _, source, _, _, spellId = UnitBuff(unit, i)
            if not n then break end
            name, id, src = n, spellId, source
        else
            break
        end
        if Secret(name) or Secret(id) then error("secret aura") end
        if id then ids[id] = true end
        if name then
            names[name] = true
            if not Secret(src) and src == "player" then mine[name] = true end
        end
    end
    return ids, names, mine
end

local function Auras(unit)
    local ok, ids, names, mine = pcall(ScanAuras, unit)
    if ok then return ids, names, mine end
end

-- Does the unit have this buff at the wanted rank or better?
local function HasBuff(buff, index, ids, names)
    if buff.group then
        for _, gid in ipairs(buff.group) do
            if ids[gid] then return true end
            local gname = SpellName(gid)
            if gname and names[gname] then return true end
        end
    end
    local lower = false
    for j, r in ipairs(buff.ranks) do
        if ids[r[1]] then
            if j >= index then return true end
            lower = true
        end
    end
    if lower then return false end -- a weaker rank we can improve on
    local name = SpellName(buff.ranks[1][1])
    return name ~= nil and names[name] == true
end

-- Does the unit have any rank of this buff (single or group version)?
local function HasAnyRank(buff, ids, names)
    return HasBuff(buff, 1, ids, names)
end

---------------------------------------------------------------------------
-- Who needs what
---------------------------------------------------------------------------
local function FullName(unit)
    local name, second = UnitName(unit)
    if not name then return nil end
    if second and second ~= "" then return name .. "-" .. second, name end
    return name, name
end

-- Checks one buff against one person. Returns the rank index to cast, or nil.
local function WantsBuff(buff, c)
    if not BuffEnabled(buff) then return end
    if not c.isGroup and not StrangersEnabled(buff) then return end
    if buff.casters and db.manaOnly and c.class and ns.NO_MANA[c.class] then return end
    if done[c.guid .. buff.key] and done[c.guid .. buff.key] > c.now then return end
    local highest = HighestKnown(buff)
    if not highest then return end
    local index = RankForLevel(buff, c.level, highest)
    if not index then return end
    if HasBuff(buff, index, c.ids, c.names) then return end
    local inRange, spellRange, near = InRange(c.unit, buff.ranks[index][1])
    if not inRange then return end
    c.spellRange, c.near = spellRange, near
    return index, highest
end

-- For buffs that replace each other (paladin blessings): pick one.
local function PickExclusive(tag, c)
    local cast = myCast[c.guid]
    -- We only just cast one on them: wait for it to show up.
    if cast and c.now - cast.time <= DONE_TIME then return end
    for _, buff in ipairs(myBuffs) do
        if buff.exclusive == tag and HasAnyRank(buff, c.ids, c.names) then
            local name = SpellName(buff.ranks[1][1])
            if (name and c.mine[name]) or (cast and cast.key == buff.key) then
                return -- they already carry one of ours
            end
        end
    end
    myCast[c.guid] = nil -- ours has worn off or been replaced
    local prefs = ns.EXCLUSIVE_PREF[tag] or {}
    local order = prefs[c.class or ""] or prefs.DEFAULT or {}
    for _, key in ipairs(order) do
        local buff = buffByKey[key]
        if buff then
            local index, highest = WantsBuff(buff, c)
            if index then return buff, index, highest end
        end
    end
end

-- Returns a record if this unit should be offered a buff, or nil.
local function Evaluate(unit, isGroup, now)
    if not UnitExists(unit) or not UnitIsPlayer(unit) then return end
    if not UnitIsFriend("player", unit) or UnitCanAttack("player", unit) then return end
    -- Friendly-looking is not enough: the other faction in a neutral town
    -- cannot be attacked but cannot be buffed either.
    if not UnitCanAssist("player", unit) then return end
    if not UnitIsConnected(unit) or UnitIsDeadOrGhost(unit) or not UnitIsVisible(unit) then return end
    local guid = UnitGUID(unit)
    if not guid or Secret(guid) then return end
    if skipped[guid] and skipped[guid] > now then return end
    if not isGroup and not db.pvp and UnitIsPVP(unit) and not UnitIsPVP("player") then return end

    local ids, names, mine = Auras(unit)
    if not ids then return end
    local _, class = UnitClass(unit)
    local c = {
        unit = unit, guid = guid, isGroup = isGroup, now = now,
        class = class, level = UnitLevel(unit),
        ids = ids, names = names, mine = mine,
    }

    local pick, index, highest
    local triedTags = {}
    for _, buff in ipairs(myBuffs) do
        if buff.exclusive then
            if not triedTags[buff.exclusive] then
                triedTags[buff.exclusive] = true
                pick, index, highest = PickExclusive(buff.exclusive, c)
            end
        else
            index, highest = WantsBuff(buff, c)
            if index then pick = buff end
        end
        if pick then break end
    end
    if not pick then return end

    local target, short = FullName(unit)
    if not target then return end
    return {
        guid = guid, name = short, target = target, class = class, level = c.level,
        via = unit, buff = pick, rank = index, highest = highest,
        spellID = pick.ranks[index][1], spellRange = c.spellRange, near = c.near,
    }
end

local function Collect()
    local now = GetTime()
    local list, seen = {}, {}

    local function AddGroup(unit)
        local guid = UnitExists(unit) and UnitGUID(unit)
        if not guid or Secret(guid) or seen[guid] then return end
        seen[guid] = true
        local rec = Evaluate(unit, true, now)
        if rec then
            rec.group, rec.unit = true, unit
            list[#list + 1] = rec
        end
    end

    local me = UnitGUID("player")
    if db.self then
        AddGroup("player")
    elseif me and not Secret(me) then
        seen[me] = true
    end
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do AddGroup("raid" .. i) end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do AddGroup("party" .. i) end
    end

    local quiet = db.quietResting and IsResting()
    local function AddStranger(unit)
        local guid = UnitExists(unit) and UnitGUID(unit)
        if not guid or Secret(guid) or seen[guid] then return end
        seen[guid] = true
        local rec = not quiet and Evaluate(unit, false, now) or nil
        if rec then
            local old = strangers[guid]
            rec.first = old and old.first or now
            rec.seen = now
            strangers[guid] = rec
        else
            strangers[guid] = nil
        end
    end

    for unit in pairs(plateUnits) do AddStranger(unit) end
    AddStranger("target")
    AddStranger("mouseover")

    local strangerList = {}
    for guid, rec in pairs(strangers) do
        if quiet or now - rec.seen > STICKY or (skipped[guid] and skipped[guid] > now)
           or (done[guid .. rec.buff.key] and done[guid .. rec.buff.key] > now) then
            strangers[guid] = nil
        else
            strangerList[#strangerList + 1] = rec
        end
    end
    table.sort(strangerList, function(a, b) return a.first > b.first end)
    for _, rec in ipairs(strangerList) do list[#list + 1] = rec end

    return list
end

---------------------------------------------------------------------------
-- The button
---------------------------------------------------------------------------
local function ColorName(rec)
    local c = rec.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[rec.class]
    if c and c.colorStr then return "|c" .. c.colorStr .. rec.name .. "|r" end
    return rec.name
end

-- Points the button at this person. Returns a short description (for the
-- log), or nil if there is nothing to cast.
--   * group members, yourself, or someone you already have targeted: a plain
--     "cast this spell on this unit" action. No target change.
--   * everyone else: a macro that targets them by name, casts, and puts your
--     target back.
local function ApplyAction(rec)
    local unit = rec.group and rec.unit
    if not unit and UnitExists("target") then
        local g = UnitGUID("target")
        if not Secret(g) and g == rec.guid then unit = "target" end
    end
    if unit then
        button:SetAttribute("type1", "spell")
        button:SetAttribute("spell1", rec.spellID)
        button:SetAttribute("unit", unit)
        button:SetAttribute("macrotext1", nil)
        return "spell " .. rec.spellID .. " on " .. unit
    end

    local spell = CastText(rec.buff, rec.rank, rec.highest)
    if not spell then return nil end
    local restore = UnitExists("target") and "/targetlasttarget" or "/cleartarget"
    -- Players here can have a second name; try every way of writing it.
    local lines = "/targetexact " .. rec.target
    if rec.name ~= rec.target then
        lines = lines .. "\n/targetexact " .. (rec.target:gsub("%-", " ", 1))
            .. "\n/targetexact " .. rec.name
    end
    local macro = lines .. "\n/cast [help,nodead] " .. spell .. "\n" .. restore
    button:SetAttribute("type1", "macro")
    button:SetAttribute("macrotext1", macro)
    button:SetAttribute("unit", nil)
    button:SetAttribute("spell1", nil)
    return "macro " .. (macro:gsub("\n", " | "))
end

local function SavePosition()
    local point, _, relPoint, x, y = button:GetPoint(1)
    db.point, db.relPoint, db.x, db.y = point, relPoint, x, y
end

local function ApplyCombatHide()
    if not holder or InCombatLockdown() then return end
    if db.hideInCombat then
        RegisterStateDriver(holder, "visibility", "[combat] hide; show")
    else
        UnregisterStateDriver(holder, "visibility")
        holder:Show()
    end
end
ns.ApplyCombatHide = ApplyCombatHide

local function CreateButton()
    -- The holder is what hides in combat; the button lives inside it.
    holder = CreateFrame("Frame", "DriveByBuffHolder", UIParent, "SecureHandlerStateTemplate")
    holder:SetSize(1, 1)
    holder:SetPoint("CENTER")

    local template = "SecureActionButtonTemplate" .. (BackdropTemplateMixin and ",BackdropTemplate" or "")
    button = CreateFrame("Button", "DriveByBuffButton", holder, template)
    button:SetSize(190, 36)
    button:SetPoint(db.point or "CENTER", UIParent, db.relPoint or "CENTER", db.x or 0, db.y or -160)
    button:SetFrameStrata("HIGH")
    button:SetClampedToScreen(true)
    button:SetMovable(true)
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:RegisterForDrag("LeftButton")
    button:Hide()

    if button.SetBackdrop then
        button:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        button:SetBackdropColor(0.05, 0.08, 0.15, 0.9)
        button:SetBackdropBorderColor(0.41, 0.8, 0.94, 1)
    end

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(26, 26)
    button.icon:SetPoint("LEFT", 6, 0)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.text:SetPoint("LEFT", button.icon, "RIGHT", 6, 0)
    button.text:SetPoint("RIGHT", -26, 0)
    button.text:SetJustifyH("LEFT")
    button.text:SetWordWrap(false)

    button.count = button:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    button.count:SetPoint("RIGHT", -6, 0)

    button:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")

    button:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        if unlocked or IsShiftKeyDown() then self:StartMoving() end
    end)
    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Drive-By Buff")
        if current and not unlocked then
            local spell = SpellName(current.spellID) or "?"
            GameTooltip:AddLine(string.format(L["Left-click: cast %s on %s"], spell, current.name), 1, 1, 1)
            GameTooltip:AddLine(L["Right-click: skip them for 5 minutes"], 1, 1, 1)
        end
        GameTooltip:AddLine(L["Shift-drag: move the button"], 1, 1, 1)
        GameTooltip:AddLine(L["Type /dbb for options"], 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Just before the click is handled: point the action at the person
    -- again, so it matches what you have targeted right now.
    button:SetScript("PreClick", function(self, mouse)
        if InCombatLockdown() or unlocked or not current or mouse ~= "LeftButton" then return end
        self.desc = ApplyAction(current) or self.desc
        lastPreClick = GetTime()
    end)

    button:SetScript("PostClick", function(self, mouse, down)
        if down or unlocked or not current then return end
        local now = GetTime()
        local c = current
        if mouse == "RightButton" then
            skipped[c.guid] = now + SKIP_TIME
            strangers[c.guid] = nil
            Log("SKIP %s", c.name)
            return
        end
        -- The button stays up until the buff actually lands (see
        -- UNIT_SPELLCAST_SUCCEEDED), so a failed cast can be retried.
        lastClick = { guid = c.guid, key = c.buff.key, name = c.name, time = now }
        if db.debug then
            Log("CLICK %s lvl=%s buff=%s rank=%s group=%s via=%s", c.name, c.level, c.buff.key, c.rank, c.group or false, c.via)
            Log("  seen %s ago | spell range=%s within 28yd=%s | action=[%s]",
                c.seen and string.format("%.1fs", now - c.seen) or "-", c.spellRange, c.near, self.desc)
        end
    end)

    ApplyCombatHide()
end

local function Refresh()
    if not button or InCombatLockdown() then return end

    if unlocked then
        current = nil
        button:SetAttribute("type1", nil)
        button.icon:SetTexture(myBuffs[1] and SpellTexture(myBuffs[1].ranks[1][1]) or "Interface\\Icons\\INV_Misc_QuestionMark")
        button.text:SetText(L["Drag me, then /dbb move"])
        button.count:SetText("")
        button:Show()
        return
    end

    if not db.enabled or #myBuffs == 0 or UnitIsDeadOrGhost("player") or UnitOnTaxi("player") then
        current = nil
        button:Hide()
        return
    end

    local list = Collect()
    if #list == 0 then
        current = nil
        button:Hide()
        return
    end

    -- Keep showing the same person while they still need something, so the
    -- name does not jump around under the mouse.
    local pick = list[1]
    if current then
        for _, rec in ipairs(list) do
            if rec.guid == current.guid then pick = rec break end
        end
    end

    local desc = ApplyAction(pick)
    if not desc then
        current = nil
        button:Hide()
        return
    end

    current = pick
    button.desc = desc
    button.icon:SetTexture(SpellTexture(pick.spellID))
    button.text:SetText(ColorName(pick))
    button.count:SetText(#list > 1 and ("+" .. (#list - 1)) or "")
    button:Show()
end
ns.Refresh = Refresh

---------------------------------------------------------------------------
-- Things the options window calls
---------------------------------------------------------------------------
local PLATE_CVARS = { "nameplateShowFriends", "nameplateShowFriendlyPlayers" }

local function GetCVarSafe(name)
    local ok, value = pcall(GetCVar, name)
    if ok then return value end
end

function ns.FriendlyPlatesOn()
    for _, name in ipairs(PLATE_CVARS) do
        if GetCVarSafe(name) == "1" then return true end
    end
    return false
end

function ns.SetFriendlyPlates(on)
    if InCombatLockdown() then
        print(PREFIX .. L["can't change nameplates in combat."])
        return
    end
    for _, name in ipairs(PLATE_CVARS) do
        if GetCVarSafe(name) ~= nil then pcall(SetCVar, name, on and "1" or "0") end
    end
    print(PREFIX .. (on and L["friendly nameplates ON - passers-by will be noticed."]
        or L["friendly nameplates OFF - only your mouseover, target and group are checked."]))
end

function ns.ToggleMove()
    if InCombatLockdown() then print(PREFIX .. L["not in combat."]) return end
    unlocked = not unlocked
    print(PREFIX .. (unlocked and L["drag the button where you want it, then type /dbb move again."] or L["button locked."]))
    Refresh()
end

function ns.IsUnlocked() return unlocked end

function ns.ResetPosition()
    if InCombatLockdown() then print(PREFIX .. L["not in combat."]) return end
    db.point, db.relPoint, db.x, db.y = nil, nil, nil, nil
    button:ClearAllPoints()
    button:SetPoint("CENTER", UIParent, "CENTER", 0, -160)
end

function ns.MyBuffs() return myBuffs end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local function SetupClass()
    local _, class = UnitClass("player")
    myBuffs = ns.BUFFS[class] or {}
    for _, buff in ipairs(myBuffs) do
        buffByKey[buff.key] = buff
        for _, r in ipairs(buff.ranks) do buffBySpell[r[1]] = buff end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("UNIT_SPELLCAST_FAILED")
frame:RegisterEvent("UI_ERROR_MESSAGE")

frame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        DriveByBuffDB = DriveByBuffDB or {}
        db = DriveByBuffDB
        if (db.version or 1) < 2 then
            -- Settings from the first, mage-only version.
            db.version = 2
            db.debug = false
            db.log = nil
        end
        for k, v in pairs(DEFAULTS) do
            if db[k] == nil then db[k] = v end
        end
        db.buffs = db.buffs or {}
        db.strangers = db.strangers or {}
        ns.db = db
        SetupClass()
        CreateButton()
        C_Timer.NewTicker(0.3, Refresh)
        return
    end
    if not db then return end

    if event == "PLAYER_ENTERING_WORLD" then
        wipe(plateUnits)
        if #myBuffs > 0 and not db.hinted and not ns.FriendlyPlatesOn() then
            db.hinted = true
            print(PREFIX .. L["friendly nameplates are off, so only your mouseover, target and group are checked. Type /dbb to turn them on and notice everyone running by."])
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        ApplyCombatHide()
    elseif event == "PLAYER_TARGET_CHANGED" then
        if db.debug and lastPreClick and GetTime() - lastPreClick < 1 then
            if UnitExists("target") then
                local n, second = UnitName("target")
                Log("  target became: %s / %s", n, second)
            else
                Log("  target became: none")
            end
        end
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        plateUnits[arg1] = true
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        plateUnits[arg1] = nil
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- Our buff landed: stop offering it to that person straight away.
        if arg1 == "player" and arg3 and not Secret(arg3) and buffBySpell[arg3] then
            local buff = buffBySpell[arg3]
            local now = GetTime()
            if lastClick and now - lastClick.time < 3 and lastClick.key == buff.key then
                Log("CAST OK %s on %s", buff.key, lastClick.name)
                done[lastClick.guid .. buff.key] = now + DONE_TIME
                if buff.exclusive then myCast[lastClick.guid] = { key = buff.key, time = now } end
                lastClick = nil
            end
        end
    elseif event == "UNIT_SPELLCAST_FAILED" then
        if arg1 == "player" and arg3 and not Secret(arg3) and buffBySpell[arg3] then
            Log("CAST FAILED %s", buffBySpell[arg3].key)
        end
        return
    elseif event == "UI_ERROR_MESSAGE" then
        if db.debug and lastClick and GetTime() - lastClick.time < 1.5 then
            Log("GAME SAID: %s", arg2)
        end
        return
    end
    Refresh()
end)

-- Minimal fake WoW API to smoke-test Drive-By Buff outside the game.
now = 100
local function newFrame(kind, name)
    local f = { scripts = {}, attrs = {}, shown = true, kind = kind, name = name }
    local mt = {}
    mt.__index = function(t, k)
        if k == "SetScript" then return function(self, n, fn) self.scripts[n] = fn end end
        if k == "GetScript" then return function(self, n) return self.scripts[n] end end
        if k == "SetAttribute" then return function(self, n, v) self.attrs[n] = v end end
        if k == "GetAttribute" then return function(self, n) return self.attrs[n] end end
        if k == "Show" then return function(self) self.shown = true end end
        if k == "Hide" then return function(self) self.shown = false end end
        if k == "IsShown" then return function(self) return self.shown end end
        if k == "GetPoint" then return function() return "CENTER", nil, "CENTER", 0, -160 end end
        if k == "SetText" then return function(self, v) self.textValue = v end end
        if k == "GetChecked" then return function(self) return self.checked end end
        if k == "SetChecked" then return function(self, v) self.checked = v end end
        if k == "CreateFontString" or k == "CreateTexture" then return function() return newFrame("region") end end
        return function() end
    end
    return setmetatable(f, mt)
end
FRAMES = {}
function CreateFrame(kind, name, parent, template)
    local f = newFrame(kind, name); f.template = template
    if name then _G[name] = f end
    FRAMES[#FRAMES + 1] = f
    return f
end
UIParent = newFrame("Frame", "UIParent")
GameTooltip = newFrame("GameTooltip")
BackdropTemplateMixin = {}
UISpecialFrames = {}
tinsert = table.insert
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
date = os.date
RAID_CLASS_COLORS = { MAGE = { colorStr = "ff3fc7eb" }, WARRIOR = { colorStr = "ffc69b6d" }, PRIEST = { colorStr = "ffffffff" } }
SlashCmdList = {}
WOW_PROJECT_ID, WOW_PROJECT_CAMELOT = 99, 99
function GetBuildInfo() return "1.60.1", "12345", "Nov 1 2026", 16001 end
function GetTime() return now end
function InCombatLockdown() return COMBAT or false end
function IsShiftKeyDown() return false end
function IsInRaid() return false end
function IsInGroup() return GROUP or false end
function GetNumSubgroupMembers() return GROUP and 1 or 0 end
function GetNumGroupMembers() return 0 end
function IsResting() return false end
function UnitOnTaxi() return false end
function RegisterStateDriver(f, s, v) f.driver = v end
function UnregisterStateDriver(f) f.driver = nil end
local cvars = { nameplateShowFriends = "0" }
function GetCVar(n) return cvars[n] end
function SetCVar(n, v) cvars[n] = v end
TICKERS = {}
C_Timer = { NewTicker = function(_, fn) TICKERS[#TICKERS + 1] = fn end }

UNITS = {}
SPELLS = {}
function addSpell(id, name, sub) SPELLS[id] = { name = name, sub = sub } end
C_Spell = {
    GetSpellName = function(id) return SPELLS[id] and SPELLS[id].name end,
    GetSpellSubtext = function(id) return SPELLS[id] and SPELLS[id].sub end,
    GetSpellTexture = function(id) return 136000 + id end,
    IsSpellInRange = function(id, unit) return nil end,
}
function IsSpellKnownOrOverridesKnown(id) return KNOWN[id] or false end
function CheckInteractDistance(unit, i) return UNITS[unit] and UNITS[unit].near ~= false end
C_UnitAuras = { GetBuffDataByIndex = function(unit, i)
    local u = UNITS[unit]; local a = u and u.auras and u.auras[i]
    if a then return { name = a.name, spellId = a.id, sourceUnit = a.src } end
end }
local function U(unit) return UNITS[unit] end
function UnitExists(u) return U(u) ~= nil end
function UnitIsPlayer(u) return U(u) and U(u).player ~= false end
function UnitIsFriend(a, u) return U(u) and U(u).friend ~= false end
function UnitCanAttack() return false end
function UnitCanAssist(a, u) return U(u) and U(u).assist ~= false end
function UnitIsConnected() return true end
function UnitIsDeadOrGhost(u) return U(u) and U(u).dead or false end
function UnitIsVisible() return true end
function UnitGUID(u) return U(u) and U(u).guid end
function UnitIsPVP(u) return U(u) and U(u).pvp or false end
function UnitClass(u) return "x", U(u) and U(u).class end
function UnitLevel(u) return U(u) and U(u).level or 0 end
function UnitName(u) if U(u) then return U(u).name, U(u).second end end
function UnitPower() return 500 end
function issecretvalue(v) return false end

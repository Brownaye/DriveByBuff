-- Drive-By Buff: buff data for WoW Forever.
local ADDON, ns = ...

-- WoW Forever only.
local function IsForever()
    if WOW_PROJECT_CAMELOT and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT then return true end
    local _, _, _, toc = GetBuildInfo()
    return type(toc) == "number" and toc >= 16000 and toc < 17000
end
if not IsForever() then
    ns.disabled = true
    return
end

-- Strings fall back to the English key, so a translation only needs to
-- fill in ns.L["English text"] = "translated text".
ns.L = setmetatable({}, { __index = function(_, key) return key end })

-- Each buff:
--   key        saved-settings name
--   ranks      { spellID, level trained at }, lowest rank first
--   group      spell IDs of the group-wide version (counts as already buffed)
--   casters    only useful to mana users (see the "casters only" option)
--   exclusive  buffs sharing this tag replace each other on a target
--   default    offered unless the player turns it off
--   strangers  offered to people outside your group by default
ns.BUFFS = {
    MAGE = {
        { key = "intellect", casters = true, default = true, strangers = true,
          ranks = { {1459, 1}, {1460, 14}, {1461, 28}, {10156, 42}, {10157, 56} },
          group = { 23028 } },
    },
    PRIEST = {
        { key = "fortitude", default = true, strangers = true,
          ranks = { {1243, 1}, {1244, 12}, {1245, 24}, {2791, 36}, {10937, 48}, {10938, 60} },
          group = { 21562, 21564 } },
        { key = "spirit", casters = true, default = true, strangers = true,
          ranks = { {14752, 30}, {14818, 40}, {14819, 50}, {27841, 60} },
          group = { 27681 } },
        { key = "shadowprot", default = false, strangers = false,
          ranks = { {976, 30}, {10957, 42}, {10958, 56} },
          group = { 27683 } },
    },
    DRUID = {
        { key = "motw", default = true, strangers = true,
          ranks = { {1126, 1}, {5232, 10}, {6756, 20}, {5234, 30}, {8907, 40}, {9884, 50}, {9885, 60} },
          group = { 21849, 21850 } },
        { key = "thorns", default = true, strangers = false,
          ranks = { {467, 6}, {782, 14}, {1075, 24}, {8914, 34}, {9756, 44}, {9910, 54} } },
    },
    PALADIN = {
        { key = "might", exclusive = "blessing", default = true, strangers = true,
          ranks = { {19740, 4}, {19834, 12}, {19835, 22}, {19836, 32}, {19837, 42}, {19838, 52}, {25291, 60} },
          group = { 25782, 25916 } },
        { key = "wisdom", exclusive = "blessing", default = true, strangers = true,
          ranks = { {19742, 14}, {19850, 24}, {19852, 34}, {19853, 44}, {19854, 54}, {25290, 60} },
          group = { 25894, 25918 } },
        { key = "kings", exclusive = "blessing", default = true, strangers = true,
          ranks = { {20217, 20} },
          group = { 25898 } },
    },
    SHAMAN = {
        { key = "waterbreathing", default = false, strangers = false, ranks = { {131, 22} } },
        { key = "waterwalking", default = false, strangers = false, ranks = { {546, 28} } },
    },
    WARLOCK = {
        { key = "unendingbreath", default = false, strangers = false, ranks = { {5697, 16} } },
    },
}

-- A paladin can keep one blessing on each person. Which one to offer, by
-- the target's class, first usable wins.
ns.EXCLUSIVE_PREF = {
    blessing = {
        WARRIOR = { "might", "kings" },
        ROGUE   = { "might", "kings" },
        HUNTER  = { "might", "kings", "wisdom" },
        MAGE    = { "wisdom", "kings" },
        PRIEST  = { "wisdom", "kings" },
        WARLOCK = { "wisdom", "kings" },
        DRUID   = { "wisdom", "kings", "might" },
        SHAMAN  = { "wisdom", "kings", "might" },
        PALADIN = { "wisdom", "kings", "might" },
        DEFAULT = { "kings", "might", "wisdom" },
    },
}

-- Classes with no mana bar (for the "casters only" option).
ns.NO_MANA = { WARRIOR = true, ROGUE = true }

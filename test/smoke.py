import io
import os
from lupa import lua51 as L

# Tests the installed copy unless DBB_DIR points somewhere else (the dev folder).
ADDON_DIR = os.environ.get("DBB_DIR", r"C:\Games\World of Warcraft\_forever_\Interface\AddOns\DriveByBuff")
FILES = ["Data.lua", "Core.lua", "Options.lua"]


def run(cls, known, scenario):
    rt = L.LuaRuntime()
    rt.execute("PLAYER_CLASS = '%s'; KNOWN = {}" % cls)
    for k in known:
        rt.execute("KNOWN[%d] = true" % k)
    rt.execute(io.open("harness.lua", encoding="utf-8").read())
    rt.execute("UNITS.player = { guid='P', name='Porridge', class=PLAYER_CLASS, level=23, auras={} }; NS = {}")
    load = rt.eval("function(src, name) local fn, err = loadstring(src, name) if not fn then error(err) end fn('DriveByBuff', NS) end")
    for f in FILES:
        load(io.open(ADDON_DIR + "\\" + f, encoding="utf-8").read(), "=" + f)
    return rt.execute(scenario)


COMMON = r"""
  addSpell(1459,'Arcane Intellect','Rank 1') addSpell(1460,'Arcane Intellect','Rank 2') addSpell(23028,'Arcane Brilliance')
  addSpell(1243,'Power Word: Fortitude','Rank 1') addSpell(1244,'Power Word: Fortitude','Rank 2') addSpell(14752,'Divine Spirit','Rank 1')
  addSpell(19740,'Blessing of Might','Rank 1') addSpell(19834,'Blessing of Might','Rank 2') addSpell(19742,'Blessing of Wisdom','Rank 1') addSpell(20217,'Blessing of Kings')
  addSpell(25782,'Greater Blessing of Might')
  local frame
  for _, f in ipairs(FRAMES) do if f.scripts.OnEvent then frame = f end end
  local function fire(...) frame.scripts.OnEvent(frame, ...) end
  local function tick() for _, t in ipairs(TICKERS) do t() end end
  fire('ADDON_LOADED', 'DriveByBuff')
  fire('PLAYER_ENTERING_WORLD')
  local b = DriveByBuffButton
  local out = {}
  local function show(label)
    local macro = b.attrs.macrotext1 and (b.attrs.macrotext1:gsub('\n', ' | '))
    out[#out+1] = label .. ': shown=' .. tostring(b.shown) .. ' text=' .. tostring(b.text and b.text.textValue)
      .. ' type=' .. tostring(b.attrs.type1) .. ' spell=' .. tostring(b.attrs.spell1) .. ' unit=' .. tostring(b.attrs.unit)
      .. ' macro=' .. tostring(macro) .. ' count=' .. tostring(b.count and b.count.textValue)
      .. ' cost=' .. tostring(b.cost and b.cost.textValue)
  end
  local function click(mouse)
    b.scripts.PreClick(b, mouse, true); b.scripts.PostClick(b, mouse, true)
    b.scripts.PreClick(b, mouse, false); b.scripts.PostClick(b, mouse, false)
  end
"""

MAGE = COMMON + r"""
  COSTS[1460] = 40
  tick(); show('mana: costs 40 of 1000 -> 4%'); b.scripts.OnEnter(b)
  COSTS[1460] = 4
  tick(); show('mana: costs 4 of 1000 -> <1%')
  COSTS[1460] = 40; MANA_NOW = 30
  tick(); show('mana: have 30, need 40 -> No mana'); b.scripts.OnEnter(b)
  SECRET_MANA = true
  tick(); show('mana secret, game says nothing -> no cost shown')
  USABLE_API = true
  tick(); show('mana secret, game says short -> No mana'); b.scripts.OnEnter(b)
  SECRET_MANA = false; USABLE_API = false; MANA_NOW = 500; COSTS[1460] = nil
  tick(); show('free spell -> no cost shown')
  click('MiddleButton'); tick(); show('middle-click -> hidden')
  out[#out+1] = 'snoozed=' .. tostring(NS.IsSnoozed()) .. ' seconds=' .. tostring(DriveByBuffDB.snoozeUntil - time())
  SlashCmdList.DRIVEBYBUFF('move'); show('snoozed, /dbb move still shows it'); SlashCmdList.DRIVEBYBUFF('move')
  tick(); show('snoozed, locked again -> hidden')
  DriveByBuffDB.snoozeUntil = time() - 1
  tick(); show('snooze ran out -> back')
  SlashCmdList.DRIVEBYBUFF('snooze'); tick(); show('/dbb snooze -> hidden')
  SlashCmdList.DRIVEBYBUFF('wake'); show('/dbb wake -> back')
  SlashCmdList.DRIVEBYBUFF('snooze'); SlashCmdList.DRIVEBYBUFF('on'); show('/dbb on also wakes')
  tick(); show('self needs AI')
  UNITS.player.auras = { {name='Arcane Intellect', id=1460} }
  tick(); show('self buffed')
  UNITS.nameplate1 = { guid='A', name='Uno', second='Dead', class='WARRIOR', level=38, auras={} }
  fire('NAME_PLATE_UNIT_ADDED', 'nameplate1')
  tick(); show('warrior stranger, casters-only on')
  DriveByBuffDB.manaOnly = false
  tick(); show('warrior stranger, casters-only off')
  click('LeftButton'); show('after click')
  fire('UNIT_SPELLCAST_SUCCEEDED', 'player', 'x', 1460)
  tick(); show('after cast ok (hidden for 10s)')
  UNITS.nameplate2 = { guid='B', name='Tiny', class='MAGE', level=3, auras={} }
  fire('NAME_PLATE_UNIT_ADDED', 'nameplate2')
  tick(); show('level 3 mage -> rank 1 by name')
  UNITS.nameplate2.auras = { {name='Arcane Brilliance', id=23028} }
  tick(); show('has Brilliance')
  UNITS.nameplate2.auras = { {name='Arcane Intellect', id=1459} }
  UNITS.nameplate2.level = 30
  tick(); show('lvl 30 with rank 1 -> upgrade')
  UNITS.target = UNITS.nameplate2
  tick(); show('same person targeted -> spell on target')
  click('RightButton'); tick(); show('right-click skip')
  UNITS.nameplate3 = { guid='C', name='Ally', class='MAGE', level=30, auras={}, assist=false }
  fire('NAME_PLATE_UNIT_ADDED', 'nameplate3'); tick(); show('cannot assist')
  UNITS.nameplate4 = { guid='D', name='Flag', class='MAGE', level=30, auras={}, pvp=true }
  fire('NAME_PLATE_UNIT_ADDED', 'nameplate4'); tick(); show('pvp flagged')
  GROUP = true; UNITS.party1 = { guid='E', name='Pal', class='PRIEST', level=22, auras={} }
  tick(); show('party member')
  COMBAT = true; UNITS.party1.auras = { {name='Arcane Intellect', id=1460} }; tick(); show('in combat (no change)')
  COMBAT = false
  SlashCmdList.DRIVEBYBUFF(''); out[#out+1] = 'options shown=' .. tostring(DriveByBuffOptions.shown)
  for _, f in ipairs(FRAMES) do if f.kind == 'CheckButton' and f.scripts.OnClick then f.checked = true; f.scripts.OnClick(f) end end
  DriveByBuffOptions.scripts.OnShow(DriveByBuffOptions)
  for _, f in ipairs(FRAMES) do if f.template == 'UIPanelButtonTemplate' then f.scripts.OnClick(f) end end
  for _, m in ipairs({'move','move','reset','plates','debug','clearlog','help','on','off'}) do SlashCmdList.DRIVEBYBUFF(m) end
  out[#out+1] = 'holder driver=' .. tostring(DriveByBuffHolder.driver)
  return table.concat(out, '\n')
"""

PRIEST = COMMON + r"""
  UNITS.player.auras = { {name='Power Word: Fortitude', id=1244} }
  UNITS.nameplate1 = { guid='A', name='Uno', class='WARRIOR', level=38, auras={} }
  fire('NAME_PLATE_UNIT_ADDED', 'nameplate1'); tick(); show('warrior needs fort')
  click('LeftButton'); fire('UNIT_SPELLCAST_SUCCEEDED', 'player', 'x', 1244)
  UNITS.nameplate1.auras = { {name='Power Word: Fortitude', id=1244} }
  tick(); show('warrior: spirit skipped (no mana)')
  UNITS.nameplate2 = { guid='B', name='Mag', class='MAGE', level=38, auras={ {name='Power Word: Fortitude', id=1244} } }
  fire('NAME_PLATE_UNIT_ADDED', 'nameplate2'); tick(); show('mage needs spirit')
  UNITS.nameplate2.level = 12; tick(); show('lvl 12 mage: spirit too high')
  return table.concat(out, '\n')
"""

PALADIN = COMMON + r"""
  UNITS.player.auras = { {name='Blessing of Wisdom', id=19742, src='player'} }
  UNITS.nameplate1 = { guid='A', name='War', class='WARRIOR', level=38, auras={} }
  fire('NAME_PLATE_UNIT_ADDED', 'nameplate1'); tick(); show('warrior -> might')
  click('LeftButton'); fire('UNIT_SPELLCAST_SUCCEEDED', 'player', 'x', 19834)
  UNITS.nameplate1.auras = { {name='Blessing of Might', id=19834} }
  now = 200; tick(); show('warrior has my might (no source info) -> nothing')
  UNITS.nameplate2 = { guid='B', name='Mag', class='MAGE', level=38, auras={ {name='Blessing of Wisdom', id=19742} } }
  fire('NAME_PLATE_UNIT_ADDED', 'nameplate2'); tick(); show('mage has someone elses wisdom -> kings')
  UNITS.nameplate2.auras[2] = {name='Blessing of Kings', id=20217}
  UNITS.nameplate3 = { guid='C', name='Rog', class='ROGUE', level=38, auras={ {name='Greater Blessing of Might', id=25782} } }
  fire('NAME_PLATE_UNIT_ADDED', 'nameplate3'); tick(); show('rogue has greater might -> kings')
  return table.concat(out, '\n')
"""

WARRIOR = COMMON + r"""
  UNITS.nameplate1 = { guid='A', name='War', class='WARRIOR', level=38, auras={} }
  fire('NAME_PLATE_UNIT_ADDED', 'nameplate1'); tick(); show('warrior player: nothing')
  SlashCmdList.DRIVEBYBUFF(''); out[#out+1] = 'options shown=' .. tostring(DriveByBuffOptions.shown)
  return table.concat(out, '\n')
"""

WARLOCK = COMMON + r"""
  addSpell(5697,'Unending Breath') addSpell(132,'Detect Lesser Invisibility')
  addSpell(2970,'Detect Invisibility') addSpell(11743,'Detect Greater Invisibility')
  GROUP = true; UNITS.party1 = { guid='E', name='Pal', class='PRIEST', level=40, auras={} }
  tick(); show('both off by default -> nothing')
  DriveByBuffDB.buffs.detectinvis = true
  tick(); show('self lvl 23 -> Lesser')
  UNITS.player.auras = { {name='Detect Greater Invisibility', id=11743} }
  DriveByBuffDB.buffs.detectinvis = true
  tick(); show('party lvl 40 -> Detect Invisibility')
  UNITS.party1.level = 20; tick(); show('party lvl 20 -> Lesser')
  UNITS.party1.level = 40
  UNITS.party1.auras = { {name='Detect Lesser Invisibility', id=132} }
  tick(); show('has Lesser -> upgrade to Detect Invisibility')
  UNITS.party1.auras = { {name='Detect Greater Invisibility', id=11743} }
  tick(); show('has Greater -> nothing')
  UNITS.party1.auras = { {name='Detect Invisibility', id=2970} }
  UNITS.nameplate1 = { guid='A', name='Uno', class='WARRIOR', level=40, auras={} }
  fire('NAME_PLATE_UNIT_ADDED', 'nameplate1'); tick(); show('stranger, strangers off -> nothing')
  DriveByBuffDB.strangers.detectinvis = true
  tick(); show('stranger, strangers on -> Detect Invisibility')
  return table.concat(out, '\n')
"""

for name, cls, known, sc in [
    ("WARLOCK", "WARLOCK", [5697, 132, 2970], WARLOCK),
    ("MAGE", "MAGE", [1459, 1460], MAGE),
    ("PRIEST", "PRIEST", [1243, 1244, 14752], PRIEST),
    ("PALADIN", "PALADIN", [19740, 19834, 19742, 20217], PALADIN),
    ("WARRIOR", "WARRIOR", [], WARRIOR),
]:
    print("=====", name)
    try:
        print(run(cls, known, sc))
    except Exception as e:
        print("ERROR:", e)

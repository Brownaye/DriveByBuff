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

KEYS = COMMON + r"""
  local function fort() UNITS.player.auras = { {name='Power Word: Fortitude', id=1244}, {name='Divine Spirit', id=14752} } end
  local function state(k) for _, bf in ipairs(NS.MyBuffs()) do if bf.key == k then return NS.BuffState(bf), bf end end end
  fort()
  UNITS.nameplate1 = { guid='A', name='Uno', class='MAGE', level=38, auras={} }
  fire('NAME_PLATE_UNIT_ADDED', 'nameplate1'); tick(); show('mage needs fort')
  -- bind a key from the options window
  SlashCmdList.DRIVEBYBUFF('')
  local keyBtns = {}
  for _, f in ipairs(FRAMES) do if f.scripts.OnKeyDown then keyBtns[#keyBtns+1] = f end end
  out[#out+1] = 'key rows=' .. #keyBtns .. ' first=' .. tostring(keyBtns[1].textValue)
  keyBtns[1].scripts.OnClick(keyBtns[1], 'LeftButton'); out[#out+1] = 'waiting text=' .. tostring(keyBtns[1].textValue)
  keyBtns[1].scripts.OnKeyDown(keyBtns[1], 'LSHIFT'); out[#out+1] = 'modifier alone ignored, waiting=' .. tostring(keyBtns[1].waiting)
  CTRL = true; keyBtns[1].scripts.OnKeyDown(keyBtns[1], 'F'); CTRL = false
  out[#out+1] = 'bound=' .. tostring(NS.GetKey(NS.KEY_BUFF)) .. ' action=' .. tostring(BINDINGS['CTRL-F']) .. ' text=' .. tostring(keyBtns[1].textValue) .. ' saved=' .. SAVED_BINDINGS
  keyBtns[1].scripts.OnClick(keyBtns[1], 'LeftButton'); keyBtns[1].scripts.OnKeyDown(keyBtns[1], 'ESCAPE')
  out[#out+1] = 'esc cancels, still=' .. tostring(NS.GetKey(NS.KEY_BUFF))
  keyBtns[1].scripts.OnClick(keyBtns[1], 'LeftButton'); keyBtns[1].scripts.OnKeyDown(keyBtns[1], 'G')
  out[#out+1] = 'rebound=' .. tostring(NS.GetKey(NS.KEY_BUFF)) .. ' old CTRL-F=' .. tostring(BINDINGS['CTRL-F'])
  BINDINGS['H'] = 'JUMP'
  keyBtns[2].scripts.OnClick(keyBtns[2], 'LeftButton'); keyBtns[2].scripts.OnKeyDown(keyBtns[2], 'H')
  out[#out+1] = 'skip key=' .. tostring(NS.GetKey(NS.KEY_SKIP)) .. ' (took H from JUMP)'
  COMBAT = true; keyBtns[3].scripts.OnClick(keyBtns[3], 'LeftButton'); COMBAT = false
  out[#out+1] = 'no binding in combat, waiting=' .. tostring(keyBtns[3].waiting)
  b.scripts.OnEnter(b)
  keyBtns[1].scripts.OnClick(keyBtns[1], 'RightButton')
  out[#out+1] = 'right-click clears=' .. tostring(NS.GetKey(NS.KEY_BUFF)) .. ' text=' .. tostring(keyBtns[1].textValue)
  b.scripts.OnEnter(b)
  -- the button empties when it hides, so a key cannot fire a stale buff
  UNITS.nameplate1.auras = { {name='Power Word: Fortitude', id=1244}, {name='Divine Spirit', id=14752} }
  tick(); show('nobody left -> hidden AND emptied')
  UNITS.nameplate1.auras = {}
  tick(); show('needs fort again')
  fire('PLAYER_REGEN_DISABLED'); show('combat starts -> emptied')
  tick(); show('tick during combat start -> still empty')
  fire('PLAYER_REGEN_ENABLED'); show('combat over -> back')
  DriveByBuffDB.hideInCombat = false
  fire('PLAYER_REGEN_DISABLED'); show('combat, button stays visible -> action kept')
  fire('PLAYER_REGEN_ENABLED'); DriveByBuffDB.hideInCombat = true
  -- key press as down+up, down only, up only
  click('LeftButton'); out[#out+1] = 'left click ok'
  local sk = DriveByBuffSkipKey
  UNITS.nameplate2 = { guid='B', name='Dos', class='MAGE', level=38, auras={} }
  fire('NAME_PLATE_UNIT_ADDED', 'nameplate2'); tick(); show('two people')
  sk.scripts.OnClick(sk, 'LeftButton', true); sk.scripts.OnClick(sk, 'LeftButton', false); show('skip key down+up -> one skipped')
  sk.scripts.OnClick(sk, 'LeftButton', false); show('skip key up only -> second skipped')
  sk.scripts.OnClick(sk, 'LeftButton', false); show('skip key with nobody -> nothing')
  local sn = DriveByBuffSnoozeKey
  sn.scripts.OnClick(sn, 'LeftButton', true); sn.scripts.OnClick(sn, 'LeftButton', false)
  out[#out+1] = 'snooze key -> snoozed=' .. tostring(NS.IsSnoozed())
  sn.scripts.OnClick(sn, 'LeftButton', true); sn.scripts.OnClick(sn, 'LeftButton', false)
  out[#out+1] = 'snooze key again -> snoozed=' .. tostring(NS.IsSnoozed())
  -- buff icons
  UNITS.nameplate3 = { guid='C', name='Tres', class='MAGE', level=38, auras={} }
  fire('NAME_PLATE_UNIT_ADDED', 'nameplate3'); tick(); show('stranger needs fort')
  local strip = DriveByBuffStrip
  b.scripts.OnEnter(b)
  local vis = 0; for _, t in ipairs(strip.icons) do if t.shown then vis = vis + 1 end end
  out[#out+1] = 'strip shown=' .. tostring(strip.shown) .. ' icons=' .. #strip.icons .. ' visible(learned)=' .. vis
  out[#out+1] = 'states: fort=' .. state('fortitude') .. ' spirit=' .. state('spirit') .. ' shadow=' .. state('shadowprot')
  local fi, si = strip.icons[1], strip.icons[2]
  fi.scripts.OnEnter(fi)
  fi.scripts.OnClick(fi, 'LeftButton'); out[#out+1] = 'fort click -> ' .. state('fortitude') .. ' mark=' .. tostring(fi.mark.textValue)
  tick(); show('fort group only: stranger gets spirit')
  UNITS.player.auras = {}; tick(); show('fort group only: self still gets fort')
  fort()
  fi.scripts.OnClick(fi, 'LeftButton'); out[#out+1] = 'fort click -> ' .. state('fortitude')
  si.scripts.OnClick(si, 'LeftButton'); si.scripts.OnClick(si, 'LeftButton'); out[#out+1] = 'spirit 2 clicks -> ' .. state('spirit')
  tick(); show('fort off + spirit off -> nothing')
  fi.scripts.OnClick(fi, 'LeftButton'); out[#out+1] = 'fort click -> ' .. state('fortitude')
  fi.scripts.OnClick(fi, 'RightButton'); out[#out+1] = 'fort right-click (back) -> ' .. state('fortitude')
  fi.scripts.OnClick(fi, 'RightButton'); fi.scripts.OnClick(fi, 'RightButton'); out[#out+1] = 'fort 2 right-clicks -> ' .. state('fortitude')
  tick(); show('fort everyone again')
  DriveByBuffDB.icons = false; b.scripts.OnEnter(b); out[#out+1] = 'icons option off -> strip shown=' .. tostring(strip.shown)
  DriveByBuffDB.icons = true; b.scripts.OnEnter(b); out[#out+1] = 'icons option on -> strip shown=' .. tostring(strip.shown)
  -- the options window rows follow the same state
  local labels = {}
  for _, f in ipairs(FRAMES) do if f.label and f.buff then labels[#labels+1] = f.buff.key .. '=' .. tostring(f.label.textValue) end end
  out[#out+1] = 'options rows: ' .. table.concat(labels, ' ')
  -- old settings carry over
  DriveByBuffDB.buffs.spirit = true; DriveByBuffDB.strangers.spirit = false
  out[#out+1] = 'old settings spirit on/strangers off -> ' .. state('spirit')
  DriveByBuffDB.buffs.spirit = false; DriveByBuffDB.strangers.spirit = true
  out[#out+1] = 'old settings spirit off/strangers on -> ' .. state('spirit')
  return table.concat(out, '\n')
"""

for name, cls, known, sc in [
    ("WARLOCK", "WARLOCK", [5697, 132, 2970], WARLOCK),
    ("MAGE", "MAGE", [1459, 1460], MAGE),
    ("PRIEST", "PRIEST", [1243, 1244, 14752], PRIEST),
    ("PALADIN", "PALADIN", [19740, 19834, 19742, 20217], PALADIN),
    ("WARRIOR", "WARRIOR", [], WARRIOR),
    ("KEYS + ICONS (priest)", "PRIEST", [1243, 1244, 14752], KEYS),
]:
    print("=====", name)
    try:
        print(run(cls, known, sc))
    except Exception as e:
        print("ERROR:", e)

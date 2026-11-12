# Drive-By Buff

**Buff everyone you run past, with one click.** An addon for WoW Forever.

[![Latest release](https://img.shields.io/github/v/release/Brownaye/DriveByBuff)](https://github.com/Brownaye/DriveByBuff/releases/latest)
[![Licence: MIT](https://img.shields.io/badge/licence-MIT-blue)](LICENSE)

![A button pops up for a passing player who is missing your buff](screenshots/1-drive-by.png)

You know the feeling: a low-level warrior runs past, you want to throw them a buff, and by the time you've clicked them and found the spell they're gone.

Drive-By Buff does the finding for you. When someone nearby is missing one of your buffs, a button pops up with their name on it. Click it and they're buffed. That's the whole addon.

## Why you'll like it

- **One click, no targeting.** You never have to click the player or find the spell on your bars.
- **Your target stays put.** It buffs them and hands your own target straight back.
- **Always the right rank.** It casts the highest rank you know, and drops to a lower one for low-level players who can't take it.
- **No wasted mana.** Anyone who already has the same buff or a better one, including the group-wide versions, is skipped.
- **Handles a crowd.** In a busy spot it queues everyone up and shows how many are waiting.
- **Keeps your group covered.** In a party or raid it keeps offering members until nobody is missing a buff.
- **You stay in control.** One click is one cast. It never casts anything by itself.
- **Small and standalone.** Three small files, no libraries, nothing else to install.

## How it works

1. Someone without your buff comes into range.
2. A button appears with their name, in their class colour, and the buff's icon.
3. **Left-click** to buff them. **Right-click** to skip them for 5 minutes.

If they're missing two of your buffs, the button moves on to the second once the first lands.

![The button queues several players](screenshots/2-queue.png)

## Supported buffs

| Class | Buffs |
|---|---|
| Mage | Arcane Intellect |
| Priest | Power Word: Fortitude, Divine Spirit, Shadow Protection (off by default) |
| Druid | Mark of the Wild, Thorns (group only by default) |
| Paladin | Blessing of Might, Wisdom or Kings, chosen by the target's class |
| Shaman | Water Breathing, Water Walking (both off by default) |
| Warlock | Unending Breath (off by default) |

Warriors, hunters and rogues have no buffs that are cast on another player, so the button stays hidden on those characters.

## Install

Download the zip from the [Releases page](https://github.com/Brownaye/DriveByBuff/releases), then extract the `DriveByBuff` folder into `World of Warcraft\_forever_\Interface\AddOns`. Restart the game.

## Setup (30 seconds)

1. Type `/dbb` to open the options.
2. Turn on **Friendly nameplates**. This is how the addon notices people running by. Without it, only your group, your target and whoever your mouse is over are checked.
3. Shift-drag the button to where you want it.

## Options (`/dbb`)

![Options window](screenshots/3-options.png)

- Turn each buff on or off, and choose whether it is offered to strangers or only your group.
- Include yourself.
- Caster buffs skip warriors and rogues.
- Offer PvP-flagged strangers (off by default, because buffing them flags you).
- Ignore strangers in cities and inns.
- Hide the button in combat.

## Good to know

- The game does not allow addons to change a cast button during combat, so the list only updates out of combat.
- Mage is the most heavily tested class. If a buff misbehaves on another class, type `/dbb debug`, reproduce it, `/reload`, and include the `DriveByBuffDB` log from your SavedVariables in the report.

## Commands

- `/dbb` - open the options window
- `/dbb on` / `/dbb off` - turn the button on or off
- `/dbb plates` - toggle friendly nameplates
- `/dbb move` - show the button so you can drag it; again to lock
- `/dbb reset` - put the button back in the middle
- `/dbb debug` - toggle the debug log

## Bugs and ideas

Found a problem or want another buff added? [Open an issue](https://github.com/Brownaye/DriveByBuff/issues).

## Licence

MIT. See [LICENSE](LICENSE).

# Changelog

## 1.3.0

- Key bindings: bind a key to buff the person on the button, another to skip them, and another to hide the button for 10 minutes. Set them in `/dbb` (click the key button, press a key; right-click clears it) or on the game's Key Bindings page.
- Buff icons on the button: put the mouse on the button and your buff icons appear. Click one to choose who gets that buff: everyone, your group only, or off. No need to open the options. If the icons get in your way, turn off "Show buff icons on the button" in `/dbb`.
- The options window uses the same icons, in place of the two columns of tick boxes. Your existing choices carry over.
- The button no longer keeps its last buff after it hides, so a bound key does nothing when nobody needs a buff.

## 1.2.0

- Middle-click the button to hide it for 10 minutes. `/dbb wake` brings it back sooner, `/dbb snooze` does the same as the middle-click.
- The button shows roughly how much of your mana bar the buff will cost (for example `4%`).
- When you don't have the mana for the buff, the button says `No mana` and its border turns red.

## 1.1.0

- Warlock: Detect Invisibility (Lesser, normal and Greater), off by default. Turn it on in `/dbb`.
- The button now sits on the lowest layer, so other addons' windows draw over it instead of under it.

## 1.0.0

First public release.

- Buffs for mage, priest, druid, paladin, shaman and warlock.
- Options window (`/dbb`) with per-buff switches.
- Highest known rank, with automatic lower ranks for low-level players.
- Skips players who already have the same or a better buff.
- Button hides in combat by default.

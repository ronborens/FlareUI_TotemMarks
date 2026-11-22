# Totem Icons & In Range Mark for FlareUI

An unofficial add-on for FlareUI with two features for anyone who plays with or against totems: icons on totem nameplates so you can tell totems apart, and a moving mark that tells a shaman whether they are still standing in range of their own totems.

_Not made by, or affiliated with, FlareUI's author._

## Feature 1: Totem Icons on Nameplates

In the base game, every totem's nameplate looks the same: a small health bar with a name. In a fight with several totems on the ground, you have to read each name to find the one that matters.

With this addon, each totem's nameplate shows that totem's spell icon:

- **Above the Nameplate:** the icon sits above the totem's name and health bar.
- **Instead of the Nameplate:** the health bar and name are hidden and a larger icon stands in their place, which keeps the screen clean.

Examples of how this helps:

- **In PvP:** spot the enemy's Grounding or Tremor Totem instantly and kill it first, instead of reading four near-identical nameplates.
- **In a group:** see at a glance where the Windfury or Mana Spring Totem is standing so you can stay near it.
- **Against NPC shamans:** enemy totems get icons too, so you know which one to destroy.

It works for every class, not only shamans, and it recognises totems in any game language.

## Feature 2: In Range Mark (for shamans)

Totem buffs only reach players standing close to the totem. In the base game, the only way to know you have walked out of range is to notice a small buff icon disappearing.

With this addon, yellow dashes march round the totem's icon for as long as its buff is on you:

- **Dashes moving:** you are in range and have the buff.
- **Dashes gone:** you have walked out of range, so step back in or drop the totem again.

The mark appears in three places, so you see it wherever you are looking:

- On FlareUI's totem tracker (the icons of your standing totems).
- On the game's totem bar.
- On the totem's spell wherever it sits on your action bars.

Example: you drop Strength of Earth Totem and chase a fleeing enemy. The dashes on the totem's icon stop the moment you leave its range, so you know your melee hits have lost the buff and can decide whether to re-drop it.

It works in combat, including for totems you drop in the middle of a fight.

## Options

The options appear inside FlareUI's own settings window. You can also type `/flaretotems`, or open the game's Options > AddOns.

- **In Range Mark:** on or off.
- **In Range Mark on Action Bars:** on or off.
- **Totem Icons on Nameplates:** Off, Above the Nameplate, or Instead of the Nameplate.

## Good to know

- The In Range Mark is for shamans and does nothing at all on other classes, so it costs them nothing.
- A totem is learned the first time you stand in its buff out of combat. Until then it has no mark.
- Totems with no buff of their own, such as Searing or Tremor, are never marked.
- In a group, another shaman's totem of the same kind lights the mark too, because the buff is the same.
- Your own and your group's totems show nameplate icons only with friendly nameplates switched on.
- Nameplate icons stand down while another nameplate addon draws the plates.

## Install

1. Download the latest zip from this project's [Releases](https://github.com/ronborens/FlareUI_TotemMarks/releases).
2. Extract it into your game's `Interface/AddOns` folder, so that `FlareUI_TotemMarks` sits beside `FlareUI`.
3. Restart the game.

To run it straight from the source, clone this repository into `Interface/AddOns` as `FlareUI_TotemMarks`.

## Problems and ideas

Please open an [issue](https://github.com/ronborens/FlareUI_TotemMarks/issues) and say which FlareUI version you have. For a problem with the In Range Mark, type `/flaretotemsdebug` while it is happening and include the lines it prints.

## Requirements

- [FlareUI](https://www.curseforge.com/wow/addons/flareui) must be installed and enabled.

This is an unofficial extension. It is not made or endorsed by the FlareUI authors, so please report problems here and not to them. MIT licensed.

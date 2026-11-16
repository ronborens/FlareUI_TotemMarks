# FlareUI: Totem Icons & In Range Mark

Two helpers for anyone who plays with or against totems.

**Totem Icons on Nameplates.** Each totem's nameplate shows the totem's icon, either above the plate or instead of it, so you can tell at a glance which totem is which.

**In Range Mark (shamans).** Yellow dashes march round a totem's icon while its buff is on you, and stop when you walk out of its range. The mark shows on FlareUI's totem icons, on the totem bar and on the totem's spell wherever it sits on your action bars. Works in combat.

## Options

The options appear inside FlareUI's own settings window. You can also type `/flaretotems`, or open the game's Options > AddOns.

- In Range Mark: on or off
- In Range Mark on Action Bars: on or off
- Totem Icons on Nameplates: Off, Above the Nameplate, or Instead of the Nameplate

## Good to know

- The In Range Mark does nothing at all on other classes, so it costs them nothing.
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

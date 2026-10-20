# REAPER Scripts

Small Lua scripts for REAPER. Color palette requires the extensions listed below; the other scripts need no extensions.

## Scripts

- [Garbus - Color_palette.lua](scripts/Garbus%20-%20Color_palette.lua) — Based on [Rodilab's Color palette v2.21](https://github.com/ReaTeam/ReaScripts/blob/master/Various/rodilab_Color%20palette.lua), with immediate Alt/Option number entry for user colors. Provides a customizable gradient and saved user palette for coloring tracks, items, takes, take markers, project markers, and regions. Includes random coloring, sequential coloring, and an Arm mode for painting targets with the mouse.

- [Garbus - Empty_tracks_to_bottom.lua](scripts/Garbus%20-%20Empty_tracks_to_bottom.lua) — Colors empty selected tracks purple and moves them below the other selected tracks, preserving order within each group. A track is empty if it contains no audio takes or MIDI notes; MIDI CC-only tracks count as empty. Reordering requires ordinary tracks in the same folder or at the top level.

- [Garbus - MIDI_length_to_next_note.lua](scripts/Garbus%20-%20MIDI_length_to_next_note.lua) — By Szymon Kusior. Sets selected MIDI note ends to the nearest later note start in the active take, considering all pitches and channels, including unselected and muted notes. For notes at the latest selected start position, rounds each duration to the nearest current MIDI grid multiple (at least one step). This can lengthen or shorten notes.

## Usage

In REAPER's **Actions → Show action list**, choose **New action → Load ReaScript**, load a script, and run it with the appropriate selection. For **Empty tracks to bottom**, select tracks in the arrange view. For **MIDI length to next note**, open a take in the MIDI editor and select notes; load and run the script from the MIDI editor action list. Changes made by either of these two scripts can be undone in one step.

### Color palette

Requires REAPER 6.28 or later, ReaImGui 0.5.1 or later, js_ReaScriptAPI, and SWS. Load and run it from the main action list. To reuse the original's saved palette, place this script beside `rodilab_Color palette.lua`; it also shares the original's settings.

Select the targets and click a color. The target button follows the last valid REAPER context; right-click it to choose a target manually. Drag colors from the gradient into the user palette to save them, or right-click a user color to edit it. Palette files can be saved and loaded in Settings.

With the palette window focused:

- Hold **Alt** (**Option** on macOS) and type a user color number. Each digit immediately applies the accumulated number: hold Alt, press **1** to apply color 1, then **2** to apply color 12. Release Alt/Option to reset the number for the next entry.
- Invalid numbers keep the last applied color; **Alt/Option+0** alone does nothing. If **Quit after apply color** is enabled, the window waits until Alt/Option is released before closing.
- In **Arm** mode, Alt/Option number entry chooses the painting color instead of immediately coloring the selection.
- **1–9** without Alt/Option select individual user colors, and **0** restores the default color. See **Settings → Shortcuts** for the remaining shortcuts and configurable mouse modifiers.

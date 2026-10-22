# REAPER Scripts

Small Lua scripts for REAPER. Color palette requires the extensions listed below; the other scripts need no extensions.

## Scripts

- [Garbus - Color_palette.lua](scripts/Garbus%20-%20Color_palette.lua) — Based on [Rodilab's Color palette v2.21](https://github.com/ReaTeam/ReaScripts/blob/master/Various/rodilab_Color%20palette.lua), with immediate Alt/Option number entry for user colors. Provides a customizable gradient and saved user palette for coloring tracks, items, takes, take markers, project markers, and regions. Includes random coloring, sequential coloring, and an Arm mode for painting targets with the mouse.

- [Garbus - Empty_tracks_to_bottom.lua](scripts/Garbus%20-%20Empty_tracks_to_bottom.lua) — Colors empty selected tracks purple and moves them below the other selected tracks, preserving order within each group. A track is empty if it contains no audio takes or MIDI notes; MIDI CC-only tracks count as empty. Reordering requires ordinary tracks in the same folder or at the top level.

- [Garbus - MIDI_length_to_next_note.lua](scripts/Garbus%20-%20MIDI_length_to_next_note.lua) — By Szymon Kusior. Processes all editable takes in the active MIDI editor independently, changing only selected notes. Sets their ends to the nearest later note start in the same take, considering all pitches and channels, including unselected and muted notes. For notes at each take's latest selected start position, rounds each duration to the nearest current MIDI grid multiple (at least one step). This can lengthen or shorten notes. Takes that are visible but not editable are left unchanged.

- [Garbus - MIDI_quantize_selected_to_grid.lua](scripts/Garbus%20-%20MIDI_quantize_selected_to_grid.lua) — Quantizes selected note starts in all editable takes of the active MIDI editor to the current MIDI grid, preserving note lengths. Supports straight, triplet, dotted and swing grids. Leaves unselected notes and non-note events unchanged. Uses the active take's grid for all voices and leaves the active take and editor settings unchanged. One Undo restores the operation.

## Usage

### Install MIDI tools and SIB/ReWire

Close REAPER, then run `python3 install.py` from this repository, or double-click `install.command` on macOS. Requires Python 3.9 or later. The installer copies the latest MIDI length, MIDI quantize and SIB/ReWire scripts into the REAPER `Scripts` resource folder and registers them in the action list. It assigns **Q** to MIDI quantize and **Shift+Q** to MIDI length in the MIDI Editor section; SIB/ReWire is added to the Main section without a keyboard shortcut.

Existing script action IDs and other shortcuts are preserved. Previous versions of changed files are backed up under `Garbus-install-backups` in the resource folder. REAPER must be closed because the installer updates `reaper-kb.ini`; it stops if REAPER is running. Running the installer again updates the same files and registrations. Use `python3 install.py --dry-run` to preview changes, or `--resource-path "/path/to/REAPER"` for a portable/custom resource folder. The installer does not launch the installed scripts.

### Manual loading

In REAPER's **Actions → Show action list**, choose **New action → Load ReaScript**, load a script, and run it with the appropriate selection. For **Empty tracks to bottom**, select tracks in the arrange view. For **MIDI length to next note**, open one or more takes in the same MIDI editor, enable editing for the takes you want to change, and select notes; load and run the script from the MIDI editor action list. Changes made by either of these two scripts can be undone in one step, including changes across multiple MIDI takes.

### MIDI quantize selected to grid

In the MIDI editor, open **Actions → Show action list**, select the **MIDI Editor** section, then **New action → Load ReaScript** and load `scripts/Garbus - MIDI_quantize_selected_to_grid.lua`. You can load it directly from this repository. Assign **Q** to the new script, replacing its previous assignment; keep **Shift+Q** assigned to MIDI length to next note.

Select notes in the editable voices, choose the MIDI grid, and press **Q** once. The script snaps note starts with full strength while preserving their lengths. It uses the current grid instead of the last quantize dialog settings, and runs even if ordinary snap is turned off. No dialog or Enter key is needed. With no selected notes, it does nothing. Moving a note can place it beyond an item's edges; item boundaries are not changed. Pooled/looped MIDI retains REAPER's shared-source behavior.

Run its regression checks from the repository root with `lua tests/midi_quantize_selected_to_grid_test.lua`. These use a mocked REAPER API and do not open or change a project.

### Color palette

Requires REAPER 6.28 or later, ReaImGui 0.5.1 or later, js_ReaScriptAPI, and SWS. Load and run it from the main action list. To reuse the original's saved palette, place this script beside `rodilab_Color palette.lua`; it also shares the original's settings.

Select the targets and click a color. The target button follows the last valid REAPER context; right-click it to choose a target manually. Drag colors from the gradient into the user palette to save them, or right-click a user color to edit it. Palette files can be saved and loaded in Settings.

With the palette window focused:

- Hold **Alt** (**Option** on macOS) and type a user color number. Each digit immediately applies the accumulated number: hold Alt, press **1** to apply color 1, then **2** to apply color 12. Release Alt/Option to reset the number for the next entry.
- Invalid numbers keep the last applied color; **Alt/Option+0** alone does nothing. If **Quit after apply color** is enabled, the window waits until Alt/Option is released before closing.
- In **Arm** mode, Alt/Option number entry chooses the painting color instead of immediately coloring the selection.
- **1–9** without Alt/Option select individual user colors, and **0** restores the default color. See **Settings → Shortcuts** for the remaining shortcuts and configurable mouse modifiers.

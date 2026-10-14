# REAPER Scripts

Small Lua scripts for REAPER. No extensions required.

## Scripts

- [Garbus - Empty_tracks_to_bottom.lua](scripts/Garbus%20-%20Empty_tracks_to_bottom.lua) — Colors empty selected tracks purple and moves them below the other selected tracks, preserving order within each group. A track is empty if it contains no audio takes or MIDI notes; MIDI CC-only tracks count as empty. Reordering requires ordinary tracks in the same folder or at the top level.

## Usage

In REAPER's **Actions → Show action list**, choose **New action → Load ReaScript**, load a script, select the tracks, and run it. Changes can be undone in one step.

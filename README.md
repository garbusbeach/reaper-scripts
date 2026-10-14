# REAPER Scripts

Small Lua scripts for REAPER. No extensions required.

## Scripts

- [Garbus - Empty_tracks_to_bottom.lua](scripts/Garbus%20-%20Empty_tracks_to_bottom.lua) — Colors empty selected tracks purple and moves them below the other selected tracks, preserving order within each group. A track is empty if it contains no audio takes or MIDI notes; MIDI CC-only tracks count as empty. Reordering requires ordinary tracks in the same folder or at the top level.

- [Garbus - MIDI_length_to_next_note.lua](scripts/Garbus%20-%20MIDI_length_to_next_note.lua) — By Szymon Kusior. Sets selected MIDI note ends to the nearest later note start in the active take, considering all pitches and channels, including unselected and muted notes. For notes at the latest selected start position, rounds each duration to the nearest current MIDI grid multiple (at least one step). This can lengthen or shorten notes.

## Usage

In REAPER's **Actions → Show action list**, choose **New action → Load ReaScript**, load a script, and run it with the appropriate selection. For **Empty tracks to bottom**, select tracks in the arrange view. For **MIDI length to next note**, open a take in the MIDI editor and select notes; load and run the script from the MIDI editor action list. Changes can be undone in one step.

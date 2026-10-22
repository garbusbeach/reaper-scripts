-- @description Quantize selected MIDI note starts to the editor grid in all editable takes
-- @author Garbus
-- @version 1.0
--
-- Run from the MIDI editor action list; suggested shortcut: Q.
-- Only selected notes in this editor's editable takes are moved.
-- The active take's current MIDI grid is used for every take, including
-- triplet/dotted divisions and swing. Grid lines restart at each measure.
-- Each note's start and end move by the same PPQ offset, preserving its length.
-- Pitches, channels, velocities, mute and selection states are kept.
-- CC, text and SysEx events, and visible but non-editable takes, are not edited.
-- The active take, editor settings and quantize dialog settings are not changed.
-- No selection means no changes. One Undo restores the whole operation.
-- No SWS or ReaPack extensions are required.

local TITLE = "Quantize selected MIDI notes to grid"
local PPQ_TOLERANCE = 0.000001

local function nearest_grid_qn(startQN, gridQN, swing)
    local _, measureStart, measureEnd = reaper.TimeMap_QNToMeasures(0, startQN)

    -- Swing delays alternate grid lines by up to half a grid step.
    -- Looking at one pair of steps is enough even for very fine grids.
    local pairStart = measureStart
        + math.floor((startQN - measureStart) / (2 * gridQN)) * 2 * gridQN
    local candidates = {
        measureStart,
        pairStart,
        pairStart + gridQN * (1 + swing * 0.5),
        pairStart + 2 * gridQN,
        measureEnd
    }
    local nearest = measureStart
    local distance = math.abs(startQN - nearest)

    for _, candidate in ipairs(candidates) do
        -- Include the next barline even if the grid does not divide the bar
        -- evenly, such as quarter notes in 7/8 or a partial measure.
        if candidate >= measureStart and candidate <= measureEnd then
            local candidateDistance = math.abs(startQN - candidate)
            if candidateDistance < distance
                or (candidateDistance == distance and candidate > nearest) then
                nearest = candidate
                distance = candidateDistance
            end
        end
    end

    return nearest
end

local function get_take_changes(take, gridQN, swing)
    local changes = {}
    local index = reaper.MIDI_EnumSelNotes(take, -1)

    while index ~= -1 do
        local ok, selected, muted, startPos, endPos, chan, pitch, vel =
            reaper.MIDI_GetNote(take, index)
        assert(ok, "Cannot read a selected MIDI note.")

        local startQN = reaper.MIDI_GetProjQNFromPPQPos(take, startPos)
        local snappedQN = nearest_grid_qn(startQN, gridQN, swing)
        local newStart = reaper.MIDI_GetPPQPosFromProjQN(take, snappedQN)

        if math.abs(newStart - startPos) > PPQ_TOLERANCE then
            table.insert(changes, {
                index = index,
                selected = selected,
                muted = muted,
                startPos = newStart,
                endPos = endPos + (newStart - startPos),
                chan = chan,
                pitch = pitch,
                vel = vel
            })
        end

        index = reaper.MIDI_EnumSelNotes(take, index)
    end

    return changes
end

local function main()
    local editor = reaper.MIDIEditor_GetActive()
    local activeTake = editor and reaper.MIDIEditor_GetTake(editor)

    if not activeTake then
        reaper.ShowMessageBox("No active MIDI editor take found.", TITLE, 0)
        return
    end

    -- MIDI_GetGrid reports a take's most recent grid. Read the active take
    -- once so every voice follows the grid currently shown in this editor.
    local gridQN, swing = reaper.MIDI_GetGrid(activeTake)
    if not gridQN or gridQN <= 0 then
        reaper.ShowMessageBox("Cannot read the current MIDI grid.", TITLE, 0)
        return
    end
    swing = swing or 0

    -- Compute every change before writing any notes.
    local takeChanges = {}
    local index = 0
    while true do
        local take = reaper.MIDIEditor_EnumTakes(editor, index, true)
        if not take then break end

        local changes = get_take_changes(take, gridQN, swing)
        if #changes > 0 then
            table.insert(takeChanges, { take = take, notes = changes })
        end
        index = index + 1
    end

    if #takeChanges == 0 then return end

    reaper.Undo_BeginBlock()
    local touchedTakes = {}
    local ok, err = xpcall(function()
        for _, change in ipairs(takeChanges) do
            table.insert(touchedTakes, change.take)
            for _, note in ipairs(change.notes) do
                assert(reaper.MIDI_SetNote(
                    change.take, note.index, note.selected, note.muted,
                    note.startPos, note.endPos, note.chan, note.pitch, note.vel,
                    true
                ), "Cannot move a selected MIDI note.")
            end
        end
    end, debug.traceback)

    -- Sort and close Undo even if a write fails partway through.
    for _, take in ipairs(touchedTakes) do
        local sorted, sortError = pcall(reaper.MIDI_Sort, take)
        if not sorted and ok then ok, err = false, sortError end
    end
    reaper.Undo_EndBlock("Quantize selected MIDI note starts to grid", -1)
    reaper.UpdateArrange()

    if not ok then
        reaper.ShowMessageBox(
            "Quantization could not be completed. Undo restores any changes.\n\n"
                .. tostring(err), TITLE, 0
        )
    end
end

main()

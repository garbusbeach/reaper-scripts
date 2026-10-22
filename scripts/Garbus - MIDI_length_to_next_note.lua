-- @description Set selected MIDI note ends to the next note and quantize the last selected onset
-- @author Szymon Kusior
-- @version 2.2
--
-- PURPOSE
-- Open one or more takes in REAPER's MIDI editor, select notes, then run this
-- script.
-- It sets each selected note's end to the nearest later note start, except for
-- notes at the latest selected start position, whose lengths are rounded to
-- the current MIDI grid.
--
-- NOTE LENGTH RULES
-- Each editable take is processed independently. The next start is found among
-- all notes in that take, including unselected and muted notes, on any pitch
-- or MIDI channel. Notes starting at the same position are not treated as a
-- later note.
-- Setting an end to the next start can lengthen or shorten an existing note.
-- Every selected note at the latest selected start position has its length
-- rounded to the nearest grid multiple, with a minimum length of one grid step.
-- This rounds note duration; it does not snap note starts or ends to grid lines.
--
-- SCOPE AND UNDO
-- Only selected notes in editable takes of the active MIDI editor are edited.
-- Takes that are only visible, but not editable, are left unchanged.
-- Note starts, pitches, velocities, channels, mute and selection states are kept.
-- With no notes or no selected notes, the script makes no changes.
-- No SWS or ReaPack extensions are required.
-- One Undo restores the note lengths changed by this run.

local function get_note_changes(take)
    local _, notes = reaper.MIDI_CountEvts(take)
    if notes == 0 then return {} end

    local noteData = {}
    local lastSelectedStart = nil

    -- Read all notes and find the latest selected start position.
    for i = 0, notes - 1 do
        local ok, selected, muted, startPos, endPos, chan, pitch, vel =
            reaper.MIDI_GetNote(take, i)

        if ok then
            table.insert(noteData, {
                index = i,
                selected = selected,
                muted = muted,
                startPos = startPos,
                endPos = endPos,
                chan = chan,
                pitch = pitch,
                vel = vel
            })

            if selected then
                if lastSelectedStart == nil
                    or startPos > lastSelectedStart then
                    lastSelectedStart = startPos
                end
            end
        end
    end

    if lastSelectedStart == nil then return {} end

    local gridQN = reaper.MIDI_GetGrid(take)

    if not gridQN or gridQN <= 0 then return nil end

    local changes = {}

    for _, currentNote in ipairs(noteData) do
        if currentNote.selected then
            local newEndPos = nil

            if currentNote.startPos == lastSelectedStart then
                -- Notes at the latest selected start position:
                -- round each duration to a multiple of the current grid.
                local startQN = reaper.MIDI_GetProjQNFromPPQPos(
                    take, currentNote.startPos
                )
                local endQN = reaper.MIDI_GetProjQNFromPPQPos(
                    take, currentNote.endPos
                )

                local lengthQN = endQN - startQN
                local gridSteps = math.floor(lengthQN / gridQN + 0.5)

                -- Keep the rounded duration at least one grid step long.
                gridSteps = math.max(1, gridSteps)

                newEndPos = reaper.MIDI_GetPPQPosFromProjQN(
                    take, startQN + gridSteps * gridQN
                )
            else
                -- Other selected notes:
                -- set the end to the nearest strictly later note start.
                for _, otherNote in ipairs(noteData) do
                    if otherNote.startPos > currentNote.startPos then
                        if newEndPos == nil
                            or otherNote.startPos < newEndPos then
                            newEndPos = otherNote.startPos
                        end
                    end
                end
            end

            if newEndPos and newEndPos > currentNote.startPos
                and newEndPos ~= currentNote.endPos then
                currentNote.endPos = newEndPos
                table.insert(changes, currentNote)
            end
        end
    end

    return changes
end

local function main()
    local editor = reaper.MIDIEditor_GetActive()
    local takeIndex = 0
    local take = editor and reaper.MIDIEditor_EnumTakes(editor, takeIndex, true)

    if not take then
        reaper.ShowMessageBox(
            "No editable MIDI editor takes found.",
            "MIDI length to next note",
            0
        )
        return
    end

    -- Prepare every take before editing, so an invalid grid cannot leave
    -- only part of a multi-take selection changed.
    local takeChanges = {}

    while take do
        local changes = get_note_changes(take)

        if not changes then
            reaper.ShowMessageBox(
                "Cannot read the current MIDI grid.",
                "MIDI length to next note",
                0
            )
            return
        end

        if #changes > 0 then
            table.insert(takeChanges, { take = take, notes = changes })
        end

        takeIndex = takeIndex + 1
        take = reaper.MIDIEditor_EnumTakes(editor, takeIndex, true)
    end

    if #takeChanges == 0 then return end

    -- All editable takes share one Undo step.
    reaper.Undo_BeginBlock()

    for _, change in ipairs(takeChanges) do
        for _, note in ipairs(change.notes) do
            reaper.MIDI_SetNote(
                change.take,
                note.index,
                note.selected,
                note.muted,
                note.startPos,
                note.endPos,
                note.chan,
                note.pitch,
                note.vel,
                true
            )
        end

        reaper.MIDI_Sort(change.take)
    end

    reaper.Undo_EndBlock(
        "Extend selected MIDI notes and quantize last note length",
        -1
    )
    reaper.UpdateArrange()
end

main()

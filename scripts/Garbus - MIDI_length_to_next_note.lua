-- @description Set selected MIDI note ends to the next note and quantize the last selected onset
-- @author Szymon Kusior
-- @version 2.1
--
-- PURPOSE
-- Open a take in REAPER's MIDI editor, select notes, then run this script.
-- It sets each selected note's end to the nearest later note start, except for
-- notes at the latest selected start position, whose lengths are rounded to
-- the current MIDI grid.
--
-- NOTE LENGTH RULES
-- The next start is found among all notes in the active take, including
-- unselected and muted notes, on any pitch or MIDI channel. Notes starting
-- at the same position are not treated as a later note.
-- Setting an end to the next start can lengthen or shorten an existing note.
-- Every selected note at the latest selected start position has its length
-- rounded to the nearest grid multiple, with a minimum length of one grid step.
-- This rounds note duration; it does not snap note starts or ends to grid lines.
--
-- SCOPE AND UNDO
-- Only selected notes in the active MIDI editor take are edited.
-- Note starts, pitches, velocities, channels, mute and selection states are kept.
-- With no notes or no selected notes, the script makes no changes.
-- No SWS or ReaPack extensions are required.
-- One Undo restores the note lengths changed by this run.

function main()
    local editor = reaper.MIDIEditor_GetActive()
    local take = editor and reaper.MIDIEditor_GetTake(editor)

    if not take then
        reaper.ShowMessageBox(
            "No active MIDI editor take found.",
            "MIDI length to next note",
            0
        )
        return
    end

    local _, notes = reaper.MIDI_CountEvts(take)
    if notes == 0 then return end

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

    if lastSelectedStart == nil then return end

    local gridQN = reaper.MIDI_GetGrid(take)

    if not gridQN or gridQN <= 0 then
        reaper.ShowMessageBox(
            "Cannot read the current MIDI grid.",
            "MIDI length to next note",
            0
        )
        return
    end

    reaper.Undo_BeginBlock()

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

            if newEndPos and newEndPos > currentNote.startPos then
                reaper.MIDI_SetNote(
                    take,
                    currentNote.index,
                    currentNote.selected,
                    currentNote.muted,
                    currentNote.startPos,
                    newEndPos,
                    currentNote.chan,
                    currentNote.pitch,
                    currentNote.vel,
                    true
                )
            end
        end
    end

    reaper.MIDI_Sort(take)
    reaper.Undo_EndBlock(
        "Extend selected MIDI notes and quantize last note length",
        -1
    )
    reaper.UpdateArrange()
end

main()

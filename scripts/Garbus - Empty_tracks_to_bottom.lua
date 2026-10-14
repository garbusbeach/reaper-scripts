-- @description Color empty selected tracks purple and move them below the others
-- @author Garbus
-- @version 1.1
--
-- PURPOSE
-- Select tracks in REAPER, then run this script. It gives empty tracks a purple
-- color and moves them below the other tracks in the original selection.
--
-- WHAT COUNTS AS EMPTY
--   * A track with no media items.
--   * A track whose items contain no audio/non-MIDI takes and no MIDI notes.
--   * An empty item without any takes also counts as empty.
--
-- Every take is checked, including inactive takes. Muted MIDI notes still count
-- as notes. CC, pitch bend, program changes, text and SysEx do not count as notes.
-- The script checks the whole track, regardless of any selected time range.
--
-- ORDER AND SCOPE
-- The original order is preserved within both groups: non-empty and empty.
-- Tracks outside the original selection are not recolored or explicitly moved,
-- although their numerical positions can shift when selected tracks are moved.
-- Example: 1(audio), 2(empty), 3(notes), 4(empty MIDI), 5(CC only), 6(notes)
-- becomes 1, 3, 6, 2, 4, 5, with tracks 2, 4 and 5 colored purple.
--
-- FOLDERS
-- When a move is needed, select ordinary tracks with the same folder parent,
-- or ordinary tracks at the top level. The script rejects selections containing
-- folder parents or tracks from different parents before making any changes.
-- Closing markers are rebuilt so moved children remain in their original folder.
-- If no move is needed, eligible tracks are simply colored.
--
-- RUNNING AND UNDO
-- No SWS or ReaPack extensions are required.
-- The original track selection is restored after a move.
-- One Undo restores the changes made by this run.
-- The script does not edit, delete or move media items between tracks.
-- A track that becomes non-empty later keeps its existing color on a later run.

-- Short alias for REAPER's API table. Every r.SomeFunction(...) below is a call
-- to the corresponding reaper.SomeFunction(...).
local r = reaper

-- In these API calls, project 0 means the currently active project tab.
local PROJECT = 0

-- All dialogs and the Undo description are intentionally written in English.
local TITLE = "Empty tracks to bottom"

-- COLOR CONFIGURATION: change the three RGB values to choose another color.
-- ColorToNative converts RGB to the platform-specific format REAPER expects.
-- Lua's | operator combines that color with REAPER's custom-color enable flag.
-- Without 0x1000000, I_CUSTOMCOLOR would store RGB without enabling its use.
local PURPLE = r.ColorToNative(160, 80, 220) | 0x1000000

-- Return true only when this track contains no qualifying content.
-- A single non-MIDI take or a single MIDI note is enough to return false.
local function is_empty(track)
  -- REAPER indexes media items from 0; subtract 1 to reach the last valid index.
  -- If there are no items, the loop never runs and the function returns true.
  for item_index = 0, r.CountTrackMediaItems(track) - 1 do
    local item = r.GetTrackMediaItem(track, item_index)

    -- An item can contain several takes. Checking only the active take could
    -- incorrectly mark a track empty when another take contains audio or notes.
    -- Take indices are also zero-based in REAPER.
    for take_index = 0, r.GetMediaItemNumTakes(item) - 1 do
      local take = r.GetMediaItemTake(item, take_index)

      -- A take slot can be empty. A missing take contributes no content.
      if take then
        -- Do not analyze waveform amplitude. Any audio/non-MIDI take counts as
        -- content, even if its audio happens to be silent.
        if not r.TakeIsMIDI(take) then return false end

        -- MIDI_CountEvts returns four values:
        -- result/status, note count, CC count, and text/SysEx count.
        -- "_" discards the first value; we use only the second, note_count.
        -- We deliberately do not inspect the CC or text/SysEx counters.
        local _, note_count = r.MIDI_CountEvts(take)

        -- Do not silently classify unreadable MIDI as empty.
        if note_count == nil then error("Cannot read MIDI notes.") end

        -- Count all stored notes in the take, including muted notes and notes
        -- outside the item's currently visible/cropped portion. This is a
        -- content check, not a test of whether the track currently makes sound.
        if note_count > 0 then return false end
      end
    end
  end

  -- Every item/take has now been checked. None contained audio or MIDI notes,
  -- so this track belongs to the empty group.
  return true
end

local function main()
  -- These are Lua arrays, indexed from 1:
  --   selected: every originally selected track, in project order.
  --   empty:    only the empty tracks from that selection, in project order.
  -- Store track objects, rather than track numbers, because numbers change
  -- when tracks are reordered but the objects still refer to the same tracks.
  local selected, empty = {}, {}

  -- saw_empty remembers that an empty track has appeared earlier.
  -- needs_reorder becomes true only if a non-empty selected track follows one.
  -- If the groups are already in the right order, no movement is necessary.
  local saw_empty, needs_reorder = false, false

  -- Read the project from top to bottom. CountTracks/GetTrack exclude the
  -- master track, so the master is never classified or colored.
  for index = 0, r.CountTracks(PROJECT) - 1 do
    local track = r.GetTrack(PROJECT, index)
    if r.IsTrackSelected(track) then
      -- #array is its length; array[#array + 1] appends a value.
      selected[#selected + 1] = track

      if is_empty(track) then
        empty[#empty + 1] = track
        saw_empty = true
      elseif saw_empty then
        -- Example: empty track 2 followed by non-empty track 3 requires a move.
        -- Once true, this flag stays true for the rest of the scan.
        needs_reorder = true
      end
    end
  end

  -- Nothing to color or move. This also handles an empty track selection.
  -- Return before opening an Undo block or temporarily changing selection.
  if #empty == 0 then return end

  -- Validate the selection before any edits.
  -- A folder parent can have no items while its children contain music.
  -- Moving that parent or moving children across parents would change routing,
  -- so this script supports reordering ordinary siblings only.
  if needs_reorder then
    -- GetParentTrack returns nil for a top-level track. Comparing nil with nil
    -- also makes the same-parent check work for top-level selections.
    local parent = r.GetParentTrack(selected[1])

    for _, track in ipairs(selected) do
      -- I_FOLDERDEPTH describes the nesting CHANGE after this track:
      --   +1: this track opens a folder.
      --    0: this track does not change the nesting.
      --   -1: this track closes one folder; -2 closes two, and so on.
      -- A negative value is allowed: the last child is still an ordinary track.
      if r.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH") > 0
          or r.GetParentTrack(track) ~= parent then
        r.ShowMessageBox(
          "Select ordinary tracks inside one folder " ..
          "or ordinary tracks at the top level.\n\n" ..
          "This selection includes a folder parent or tracks from different folders.",
          TITLE, 0)
        return
      end
    end
  end

  -- Capture the destination BEFORE replacing the original selection.
  -- IP_TRACKNUMBER is 1-based, while ReorderSelectedTracks expects a zero-based
  -- insertion index in the current, pre-move layout.
  -- For example, track 6 has IP_TRACKNUMBER = 6; index 6 is the position just
  -- after that track. REAPER accounts for removing selected tracks before
  -- inserting the block, so we must not subtract the number of empty tracks.
  -- selected[#selected] is the last originally selected track.
  local destination = math.floor(
    r.GetMediaTrackInfo_Value(selected[#selected], "IP_TRACKNUMBER"))

  -- Preserve the master's selection state separately. Although the master is
  -- excluded from classification, temporarily changing selection can deselect it.
  local master = r.GetMasterTrack(PROJECT)
  local master_selected = r.IsTrackSelected(master)

  -- Snapshot folder information by track identity before a move.
  -- "depth" is the absolute nesting level BEFORE a track:
  --   top level = 0, child of one folder = 1, child of two folders = 2.
  -- "delta" is I_FOLDERDEPTH: how the level changes AFTER that track.
  -- These are different values; both are needed for restoration.
  --
  -- Example before: Folder(+1), Empty(0), Notes(-1).
  -- Example after:  Folder(+1), Notes(0), Empty(-1).
  -- The closing -1 must belong to the new last child, not to the Notes track.
  local depths, original_deltas = {}, {}
  local depth = 0

  if needs_reorder then
    -- Include all project tracks, because moving a closing child may cause
    -- REAPER to adjust folder markers on neighboring unselected tracks too.
    for index = 0, r.CountTracks(PROJECT) - 1 do
      local track = r.GetTrack(PROJECT, index)
      local delta = r.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
      depths[track] = depth
      original_deltas[track] = delta
      depth = depth + delta
    end
  end

  -- Group the move, recoloring and selection restoration into one Undo step.
  r.Undo_BeginBlock2(PROJECT)

  -- Hide intermediate redraws while selection and folder markers are changed.
  -- This +1 must be balanced by a -1 below, including after a caught error.
  r.PreventUIRefresh(1)

  -- Keep the requested move and its actual outcome separate. Folder cleanup
  -- must know whether the track order really changed.
  local reordered = false

  -- xpcall catches errors in the edit block. It lets the cleanup below run
  -- even if moving or coloring fails. debug.traceback supplies error details.
  local ok, err = xpcall(function()
    if needs_reorder then
      -- The native move API operates on the CURRENT track selection.
      -- Temporarily select only the empty group, preserving its project order.
      r.SetOnlyTrackSelected(empty[1])
      for index = 2, #empty do r.SetTrackSelected(empty[index], true) end
      r.SetTrackSelected(master, false)

      -- Move that group immediately before the captured destination.
      -- The second argument, 0, requests a normal move; we are not asking
      -- REAPER to make the preceding track a new folder.
      -- The non-empty tracks keep their relative order as the empty ones leave.
      assert(r.ReorderSelectedTracks(destination, 0),
        "Cannot move tracks.")
      reordered = true
    end

    -- Set only the empty group's track colors. Non-empty tracks keep their
    -- existing colors, including any color assigned by an earlier script run.
    for _, track in ipairs(empty) do
      r.SetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR", PURPLE)
    end
  end, debug.traceback)

  if needs_reorder then
    local count = r.CountTracks(PROJECT)

    -- Rebuild folder markers in the CURRENT track order.
    for index = 0, count - 1 do
      local track = r.GetTrack(PROJECT, index)

      -- If the move failed, the original per-track delta is the value to restore.
      local delta = original_deltas[track]

      if reordered then
        -- The required change after a track is:
        --   original depth of the next track - original depth of this track.
        -- Equal depths give 0; one level shallower gives -1.
        -- For the final project track, no next track exists, so use depth 0:
        -- every still-open folder must be closed at the end of the project.
        local next_track = r.GetTrack(PROJECT, index + 1)
        local next_depth = next_track and depths[next_track] or 0
        delta = next_depth - depths[track]
      end

      r.SetMediaTrackInfo_Value(track, "I_FOLDERDEPTH", delta)
    end

    -- Remove the temporary empty-only selection, then restore the original
    -- selection using the saved track objects. Their numbers may have changed.
    for index = 0, count - 1 do
      r.SetTrackSelected(r.GetTrack(PROJECT, index), false)
    end
    for _, track in ipairs(selected) do r.SetTrackSelected(track, true) end
    r.SetTrackSelected(master, master_selected)
  end

  -- Balance PreventUIRefresh(1), refresh track-panel layout, and redraw arrange.
  r.PreventUIRefresh(-1)
  r.TrackList_AdjustWindows(false)
  r.UpdateArrange()

  -- -1 includes all relevant project state changes in the Undo entry.
  r.Undo_EndBlock2(PROJECT,
    "Empty tracks: color purple and move to bottom of selection", -1)

  -- Report an edit-block error after releasing redraw suppression and closing
  -- the Undo block. This does not automatically undo any completed edits.
  if not ok then r.ShowMessageBox(err, TITLE, 0) end
end

-- REAPER normally creates an automatic Undo entry for a non-deferred script.
-- An empty defer callback suppresses that automatic entry; the explicit Undo
-- block in main() records actual edits, and no-op runs create no extra entry.
r.defer(function() end)

-- Catch errors raised outside the edit block too, such as a MIDI read failure
-- during classification, and show the details instead of failing silently.
local ok, err = xpcall(main, debug.traceback)
if not ok then r.ShowMessageBox(err, TITLE, 0) end

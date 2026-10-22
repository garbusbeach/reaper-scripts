-- @description Create SIB + Sibelius ReWire + -1000 ms delay, or open existing SIB
-- @version 1.0.1
-- @author Garbus / OpenAI
-- @about
--   Instalacja: Actions > Show action list > New action > Load ReaScript.
--   Nowy SIB: pierwsza sciezka, fiolet, ReWire Sibelius, JS delay -1000 ms.
--   Otwiera zapisany_projekt.sib obok zapisanego_projektu.rpp, jesli plik istnieje.
--   Istniejacy SIB: tylko pokazuje ReWire i otwiera/aktywuje Sibeliusa.
--   Nie tworzy ani nie zapisuje plikow .sib. Nie wymaga SWS ani ReaPack.
--   Wymaga dzialajacego Sibelius ReWire w tej instalacji REAPER-a.

local CONFIG = {
  track_name = "SIB",
  -- Fiolet w stylu Sibeliusa (#6E2B91); zmien RGB, jesli wolisz inny odcien.
  color_rgb = {110, 43, 145},
  delay_ms = -1000,
  -- Opcjonalna dokladna nazwa z przegladarki FX, np. "ReWire: Sibelius/x86_64".
  rewire_fx_name = "",
  mac_app = "Sibelius", -- moze byc tez pelna sciezka do Sibelius.app
  -- Windows: zostaw puste dla standardowej instalacji albo podaj pelna sciezke.
  windows_exe = "",
}

local TITLE = "SIB / Sibelius ReWire"
local OS = reaper.GetOS()
local IS_MAC = OS:find("OSX", 1, true) ~= nil
  or OS:find("macOS", 1, true) ~= nil
local IS_WINDOWS = OS:find("Win", 1, true) ~= nil

local function fail(message)
  error(message, 0)
end

local function normalize_name(name)
  return (name or ""):match("^%s*(.-)%s*$"):upper()
end

local function find_sib_track(project)
  for i = 0, reaper.CountTracks(project) - 1 do
    local track = reaper.GetTrack(project, i)
    local _, name = reaper.GetTrackName(track)
    if normalize_name(name) == normalize_name(CONFIG.track_name) then
      return track
    end
  end
end

local function is_sibelius_rewire(track, fx)
  local _, name = reaper.TrackFX_GetFXName(track, fx, "")
  local kind, ident = "", ""
  if reaper.TrackFX_GetNamedConfigParm then
    local _, value = reaper.TrackFX_GetNamedConfigParm(track, fx, "fx_type")
    kind = value or ""
    _, value = reaper.TrackFX_GetNamedConfigParm(track, fx, "fx_ident")
    ident = value or ""
  end
  local combined = ((name or "") .. " " .. ident):lower()
  return combined:find("sibelius", 1, true) ~= nil
    and (kind:lower() == "rewire"
      or combined:find("rewire", 1, true) ~= nil)
end

local function rewire_candidates()
  local names, seen, installed = {}, {}, {}
  local function add(name)
    if name and name ~= "" and not seen[name:lower()] then
      names[#names + 1] = name
      seen[name:lower()] = true
    end
  end
  add(CONFIG.rewire_fx_name)
  if reaper.EnumInstalledFX then
    local i = 0
    while true do
      local ok, name = reaper.EnumInstalledFX(i)
      if not ok then break end
      local lower = (name or ""):lower()
      if lower:find("rewire", 1, true)
        and lower:find("sibelius", 1, true)
        -- x86_64/x86-64 are 64-bit; exclude only the 32-bit x86 variant.
        and (not lower:find("x86", 1, true)
          or lower:find("x86_64", 1, true)
          or lower:find("x86-64", 1, true))
        and not lower:find("32-bit", 1, true)
        and not lower:find("x32", 1, true) then
        installed[#installed + 1] = name
      end
      i = i + 1
    end
  end
  table.sort(installed, function(a, b)
    local a64 = a:lower():find("64", 1, true) and 1 or 0
    local b64 = b:lower():find("64", 1, true) and 1 or 0
    if a64 ~= b64 then return a64 > b64 end
    return a < b
  end)
  for _, name in ipairs(installed) do add(name) end
  add("ReWire: Sibelius/x86_64")
  add("ReWire: Sibelius (x64)")
  add("ReWire: Sibelius")
  add("ReWire: Sibelius Ultimate")
  return names
end

local function find_existing_rewire(track, candidates)
  for fx = 0, reaper.TrackFX_GetCount(track) - 1 do
    if is_sibelius_rewire(track, fx) then return fx end
  end
  -- Query-only lookup also handles a renamed FX instance.
  for _, name in ipairs(candidates) do
    local fx = reaper.TrackFX_AddByName(track, name, false, 0)
    if fx >= 0 then return fx end
  end
end

local function add_rewire(track, candidates)
  for _, name in ipairs(candidates) do
    local fx = reaper.TrackFX_AddByName(track, name, false, -1000)
    if fx >= 0 then
      if is_sibelius_rewire(track, fx) then return fx end
      -- Do not accidentally keep a similarly named VST instead of ReWire.
      reaper.TrackFX_Delete(track, fx)
    end
  end
  fail("Nie znaleziono 64-bitowego Sibelius ReWire w FX.\n\n"
    .. "Sprawdz, czy mozesz dodac go recznie z kategorii ReWire. "
    .. "W razie innej nazwy wpisz ja w CONFIG.rewire_fx_name.\n\n"
    .. "Probowane nazwy:\n" .. table.concat(candidates, "\n"))
end

local function add_delay(track)
  local candidates = {
    "JS: delay/time_adjustment",
    "JS: Time Adjustment Delay or Negative Delay",
    "JS: Time Adjustment Delay",
    "JS: time_adjustment",
  }
  local fx = -1
  for _, name in ipairs(candidates) do
    fx = reaper.TrackFX_AddByName(track, name, false, -1001)
    if fx >= 0 then break end
  end
  if fx < 0 then fail("Nie znaleziono fabrycznego JS: Time Adjustment Delay.") end
  local _, label = reaper.TrackFX_GetParamName(track, fx, 0, "")
  local _, minimum, maximum = reaper.TrackFX_GetParam(track, fx, 0)
  if reaper.TrackFX_GetNumParams(track, fx) < 4
    or not (label or ""):lower():find("ms", 1, true)
    or CONFIG.delay_ms < minimum or CONFIG.delay_ms > maximum then
    fail("JS: Time Adjustment Delay ma nieoczekiwane parametry. "
      .. "Nie ustawiono opoznienia.")
  end
  -- Verified against Cockos Effects/delay/time_adjustment:
  -- Delay Amount (ms), Wet Mix (dB), Dry Mix (dB), Additional Delay (samples).
  local values = {CONFIG.delay_ms, 0, -120, 0}
  for i, value in ipairs(values) do
    if not reaper.TrackFX_SetParam(track, fx, i - 1, value) then
      fail("Nie udalo sie ustawic parametru JS delay: " .. (i - 1))
    end
  end
  local actual = reaper.TrackFX_GetParam(track, fx, 0)
  if math.abs(actual - CONFIG.delay_ms) > 0.001 then
    fail("JS delay nie przyjal wartosci " .. CONFIG.delay_ms .. " ms.")
  end
  return fx
end

local function matching_score(project_filename)
  if not project_filename or project_filename == "" then return nil end
  local stem, count = project_filename:gsub("%.[Rr][Pp][Pp]$", "")
  if count == 0 then return nil end
  local path = stem .. ".sib"
  if reaper.file_exists(path) then return path end
end

local function quote_argument(value)
  if value:find("[%z\r\n]") then
    fail("Sciezka lub nazwa aplikacji zawiera niedozwolony znak sterujacy.")
  end
  if IS_WINDOWS then
    -- Windows CommandLineToArgvW/CRT quoting; no cmd.exe or start command.
    value = value:gsub('(\\*)"', function(slashes)
      return slashes .. slashes .. '\\"'
    end)
    value = value:gsub('(\\+)$', '%1%1')
    return '"' .. value .. '"'
  end
  -- POSIX shell-safe quoting, including apostrophes and shell metacharacters.
  return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function windows_executable()
  if CONFIG.windows_exe ~= "" then
    if reaper.file_exists(CONFIG.windows_exe) then return CONFIG.windows_exe end
    fail("Nie ma pliku CONFIG.windows_exe:\n" .. CONFIG.windows_exe)
  end
  local root = os.getenv("ProgramW6432") or os.getenv("ProgramFiles")
    or "C:\\Program Files"
  local avid = root .. "\\Avid"
  local path = avid .. "\\Sibelius\\Sibelius.exe"
  if reaper.file_exists(path) then return path end
  if reaper.EnumerateSubdirectories then
    local i = 0
    while true do
      local directory = reaper.EnumerateSubdirectories(avid, i)
      if not directory then break end
      if directory:lower():find("sibelius", 1, true) then
        path = avid .. "\\" .. directory .. "\\Sibelius.exe"
        if reaper.file_exists(path) then return path end
      end
      i = i + 1
    end
  end
  fail("Podaj sciezke do Sibelius.exe w CONFIG.windows_exe na gorze skryptu.")
end

local function open_sibelius(score_path)
  local command, timeout
  if IS_MAC then
    command = "/usr/bin/open -a " .. quote_argument(CONFIG.mac_app)
    if score_path then command = command .. " " .. quote_argument(score_path) end
    timeout = 5000 -- open dispatches a launch/open event; it does not wait for exit
  elseif IS_WINDOWS then
    command = quote_argument(windows_executable())
    if score_path then command = command .. " " .. quote_argument(score_path) end
    timeout = -1 -- do not block REAPER while Sibelius is running
  else
    fail("Otwieranie Sibeliusa jest obslugiwane na macOS i Windows.")
  end
  local result = reaper.ExecProcess(command, timeout)
  local status = result and tonumber(result:match("^%s*([%-]?%d+)"))
  if not result or (status and status ~= 0) then
    fail("ReWire jest otwarte, ale nie udalo sie otworzyc aplikacji Sibelius.\n\n"
      .. tostring(result or "Brak odpowiedzi systemu")
      .. "\n\nNa macOS sprawdz CONFIG.mac_app; na Windows CONFIG.windows_exe.")
  end
end

local function main()
  if not IS_MAC and not IS_WINDOWS then
    fail("Ten skrypt wymaga macOS lub Windows oraz zainstalowanego Sibelius ReWire.")
  end
  local project, filename = reaper.EnumProjects(-1, "")
  local track = find_sib_track(project)
  local candidates = rewire_candidates()
  if track then
    local fx = find_existing_rewire(track, candidates)
    if not fx then
      reaper.TrackFX_Show(track, 0, 1)
      fail("Sciezka SIB juz istnieje, ale nie zawiera Sibelius ReWire.\n"
        .. "Dodaj ReWire na tej sciezce i uruchom skrypt ponownie.")
    end
    reaper.TrackFX_Show(track, fx, 3)
    open_sibelius(nil) -- do not reload/change the score for an existing SIB track
    return
  end

  local created, rewire_fx
  reaper.Undo_BeginBlock2(project)
  reaper.PreventUIRefresh(1)
  local ok, problem = pcall(function()
    reaper.InsertTrackAtIndex(0, false)
    created = reaper.GetTrack(project, 0)
    if not created then fail("Nie udalo sie utworzyc sciezki SIB.") end
    reaper.GetSetMediaTrackInfo_String(created, "P_NAME", CONFIG.track_name, true)
    local rgb = CONFIG.color_rgb
    reaper.SetTrackColor(created, reaper.ColorToNative(rgb[1], rgb[2], rgb[3]) | 0x1000000)
    reaper.SetMediaTrackInfo_Value(created, "I_NCHAN", 2)
    reaper.SetMediaTrackInfo_Value(created, "B_MAINSEND", 1)
    rewire_fx = add_rewire(created, candidates)
    add_delay(created)
  end)
  if not ok and created then reaper.DeleteTrack(created) end
  reaper.PreventUIRefresh(-1)
  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock2(project, ok and "Create SIB / Sibelius ReWire / -1000 ms"
    or "SIB setup cancelled", -1)
  if not ok then fail(problem) end

  reaper.SetOnlyTrackSelected(created)
  reaper.TrackFX_Show(created, rewire_fx, 3)
  open_sibelius(matching_score(filename))
end

local ok, problem = pcall(main)
if not ok then reaper.ShowMessageBox(tostring(problem), TITLE, 0) end

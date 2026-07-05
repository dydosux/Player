local dfpwm = require("cc.audio.dfpwm")

local musicDir = "music"
local manifestPath = "tracks.json"

local speakers = {}

local function refreshSpeakers()
  speakers = { peripheral.find("speaker") }
  return #speakers
end

local function stopSpeakers()
  for _, speaker in ipairs(speakers) do
    pcall(function() speaker.stop() end)
  end
end

if refreshSpeakers() == 0 then error("Speaker not found") end

local screen = peripheral.find("monitor") or term.current()
if screen.setTextScale then screen.setTextScale(0.5) end

local selected = 1
local playing = false
local stopRequested = false

local function loadTracks()
  if not fs.exists(manifestPath) then
    error("tracks.json not found. Run: update")
  end

  local file = fs.open(manifestPath, "r")
  local text = file.readAll()
  file.close()

  local manifest = textutils.unserialiseJSON(text)
  if type(manifest) ~= "table" or type(manifest.tracks) ~= "table" then
    error("tracks.json format is invalid")
  end
  return manifest.tracks
end

local tracks = loadTracks()

local function clear()
  screen.setBackgroundColor(colors.black)
  screen.setTextColor(colors.white)
  screen.clear()
  screen.setCursorPos(1, 1)
end

local function writeAt(x, y, text, fg, bg)
  screen.setCursorPos(x, y)
  if bg then screen.setBackgroundColor(bg) end
  if fg then screen.setTextColor(fg) end
  screen.write(text)
  screen.setBackgroundColor(colors.black)
  screen.setTextColor(colors.white)
end

local function draw()
  clear()
  local w, h = screen.getSize()
  writeAt(2, 1, "Music Player", colors.cyan)
  writeAt(2, 2, "Speakers: " .. #speakers .. "  Enter/click: play  S: stop  U: update  Q: quit", colors.gray)

  for i = 1, math.min(#tracks, h - 4) do
    local track = tracks[i]
    local title = track.title or track.file or ("Track " .. i)
    if #title > w - 4 then title = title:sub(1, w - 7) .. "..." end
    if i == selected then
      writeAt(2, i + 3, "> " .. title, colors.black, playing and colors.lime or colors.white)
    else
      writeAt(2, i + 3, "  " .. title, colors.white)
    end
  end
end

local function playTrack(track)
  local path = fs.combine(musicDir, track.file)

  if not fs.exists(path) then
    playing = false
    local encoded = textutils.urlEncode(track.file)
    draw()
    writeAt(2, select(2, screen.getSize()), "Missing " .. encoded .. ". Run update.", colors.red)
    sleep(2)
    return
  end

  playing = true
  stopRequested = false
  refreshSpeakers()
  draw()

  local decoder = dfpwm.make_decoder()
  local file = fs.open(path, "rb")

  while not stopRequested do
    local chunk = file.read(16 * 1024)
    if not chunk then break end

    local buffer = decoder(chunk)
    local pending = {}
    local remaining = 0
    for index = 1, #speakers do
      pending[index] = true
      remaining = remaining + 1
    end

    while remaining > 0 and not stopRequested do
      for index, speaker in ipairs(speakers) do
        if pending[index] then
          local ok, played = pcall(function() return speaker.playAudio(buffer) end)
          if not ok or played then
            pending[index] = false
            remaining = remaining - 1
          end
        end
      end

      if remaining > 0 then
        local event, key = os.pullEvent()
        if event == "key" and keys.getName(key) == "s" then
          stopRequested = true
        end
      end
    end
  end

  file.close()
  stopSpeakers()
  playing = false
  draw()
end

local function runUpdate()
  clear()
  shell.run("update")
  tracks = loadTracks()
  selected = math.min(selected, #tracks)
  if selected < 1 then selected = 1 end
  sleep(1)
  draw()
end

draw()
while true do
  local event, a, b, c = os.pullEvent()
  if event == "key" then
    local key = keys.getName(a)
    if key == "up" then
      selected = math.max(1, selected - 1)
      draw()
    elseif key == "down" then
      selected = math.min(#tracks, selected + 1)
      draw()
    elseif key == "enter" then
      playTrack(tracks[selected])
    elseif key == "s" then
      stopRequested = true
      stopSpeakers()
    elseif key == "u" then
      runUpdate()
    elseif key == "q" then
      stopSpeakers()
      clear()
      return
    end
  elseif event == "monitor_touch" or event == "mouse_click" then
    local y = event == "monitor_touch" and c or b
    local index = y - 3
    if tracks[index] then
      selected = index
      playTrack(tracks[selected])
    end
  end
end

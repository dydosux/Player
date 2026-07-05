local files = {}

local playerSource = [[
local dfpwm = require("cc.audio.dfpwm")

local musicDir = "music"
local manifestPath = "tracks.json"
local owner = "dydosux"
local repo = "Player"
local branch = "main"
local rawBase = "https://raw.githubusercontent.com/" .. owner .. "/" .. repo .. "/" .. branch .. "/"
local githubRawBase = "https://github.com/" .. owner .. "/" .. repo .. "/raw/" .. branch .. "/"

local speaker = peripheral.find("speaker")
if not speaker then error("Speaker not found") end

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
  writeAt(2, 2, "Enter/click: play  S: stop  U: update  Q: quit", colors.gray)

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

  playing = true
  stopRequested = false
  draw()

  local decoder = dfpwm.make_decoder()
  local file = nil
  local response = nil

  if fs.exists(path) then
    file = fs.open(path, "rb")
  else
    local encoded = textutils.urlEncode(track.file)
    for _, url in ipairs({ rawBase .. encoded, githubRawBase .. encoded }) do
      response = http.get(url, nil, true)
      if response then break end
    end
    if not response then
      playing = false
      draw()
      writeAt(2, select(2, screen.getSize()), "Cannot stream track. Try again.", colors.red)
      sleep(2)
      return
    end
  end

  while not stopRequested do
    local chunk = file and file.read(16 * 1024) or response.read(16 * 1024)
    if not chunk then break end
    local buffer = decoder(chunk)
    while not speaker.playAudio(buffer) do
      local event = { os.pullEvent() }
      if event[1] == "speaker_audio_empty" then
        break
      elseif event[1] == "key" and keys.getName(event[2]) == "s" then
        stopRequested = true
        break
      end
    end
  end
  if file then file.close() end
  if response then response.close() end
  speaker.stop()
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
      speaker.stop()
    elseif key == "u" then
      runUpdate()
    elseif key == "q" then
      speaker.stop()
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

]]
local updateSource = [[
local owner = "dydosux"
local repo = "Player"
local branch = "main"
local rawBase = "https://raw.githubusercontent.com/" .. owner .. "/" .. repo .. "/" .. branch .. "/"
local githubRawBase = "https://github.com/" .. owner .. "/" .. repo .. "/raw/" .. branch .. "/"
local musicDir = "music"

local function ensureDir(path)
  if not fs.exists(path) then fs.makeDir(path) end
end

local function download(url, path, binary)
  for attempt = 1, 5 do
    for _, candidate in ipairs({ url, url:gsub(rawBase, githubRawBase) }) do
      if fs.exists(path) then fs.delete(path) end
      shell.run("wget", candidate, path)
      if fs.exists(path) then
        sleep(0.5)
        return true
      end
    end
    print("Retry " .. attempt .. "/5")
    sleep(2)
  end
  print("Failed: " .. url)
  return false
end

local function loadManifest()
  if not download(rawBase .. "tracks.json", "tracks.json", false) then
    error("Cannot download tracks.json")
  end

  local file = fs.open("tracks.json", "r")
  local text = file.readAll()
  file.close()

  return textutils.unserialiseJSON(text)
end

ensureDir(musicDir)
local manifest = loadManifest()
if type(manifest) ~= "table" or type(manifest.tracks) ~= "table" then
  error("tracks.json format is invalid")
end

print("Track list updated: " .. #manifest.tracks)
print("Songs will stream from GitHub when played.")

]]
local tracksSource = [[
{
  "tracks": [
    {
      "title": "Bar Song",
      "file": "BarSong.dfpwm"
    },
    {
      "title": "Gradusy - Plavanie",
      "file": "GradusyPlavanie.dfpwm"
    },
    {
      "title": "Gradusy - Po pustakam",
      "file": "GradusyPopystakam.dfpwm"
    },
    {
      "title": "Kyrtka",
      "file": "Kyrtka.dfpwm"
    },
    {
      "title": "Macarena",
      "file": "Macarena.dfpwm"
    },
    {
      "title": "Milky",
      "file": "Milky.dfpwm"
    },
    {
      "title": "Naturaleno",
      "file": "Naturaleno.dfpwm"
    },
    {
      "title": "SMS",
      "file": "SMS.dfpwm"
    },
    {
      "title": "Sozvezdia",
      "file": "Sozvezdia.dfpwm"
    }
  ]
}

]]

local function writeFile(path, text)
  if fs.exists(path) then fs.delete(path) end
  local file = fs.open(path, "w")
  file.write(text)
  file.close()
  print("Wrote " .. path)
end

writeFile("player", playerSource)
writeFile("update", updateSource)
writeFile("tracks.json", tracksSource)
if not fs.exists("music") then fs.makeDir("music") end

print("Installed core files.")
print("Run: update")
print("Then run: player")

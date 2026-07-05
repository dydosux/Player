local playerSource = [==[local dfpwm = require("cc.audio.dfpwm")

local owner = "dydosux"
local repo = "Player"
local branch = "main"
local rawBase = "https://raw.githubusercontent.com/" .. owner .. "/" .. repo .. "/" .. branch .. "/"
local githubRawBase = "https://github.com/" .. owner .. "/" .. repo .. "/raw/" .. branch .. "/"
local apiUrl = "https://api.github.com/repos/" .. owner .. "/" .. repo .. "/contents?ref=" .. branch

local musicDir = "music"
local tracksPath = "tracks.json"
local tempListPath = ".repo_files.json"

local tracks = {}
local selected = 1
local playing = false
local status = "Ready"
local speakers = {}
local speakerNames = {}
local screens = {}
local screenKeys = {}
local screen = term.current()
local buttonsByScreen = {}
local volumeBarsByScreen = {}
local screenHeightsByScreen = {}
local listOffsetsByScreen = {}
local stopRequested = false
local manualStopRequested = false
local nextRequested = false
local prevRequested = false
local listOffset = 0
local volume = 1.0

local function refreshScreens()
  screens = {}
  screenKeys = {}
  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "monitor" then
      local monitor = peripheral.wrap(name)
      if monitor then
        if monitor.setTextScale then monitor.setTextScale(0.5) end
        screens[#screens + 1] = monitor
        screenKeys[#screenKeys + 1] = name
      end
    end
  end
  if #screens == 0 then
    screens[1] = term.current()
    screenKeys[1] = "__term"
  end
end

local function ensureDir(path)
  if not fs.exists(path) then fs.makeDir(path) end
end

local function clear(bg)
  screen.setBackgroundColor(bg or colors.black)
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

local function center(y, text, fg, bg)
  local w = screen.getSize()
  writeAt(math.max(1, math.floor((w - #text) / 2) + 1), y, text, fg, bg)
end

local function addButton(key, id, x, y, w, label, fg, bg)
  buttonsByScreen[key] = buttonsByScreen[key] or {}
  buttonsByScreen[key][#buttonsByScreen[key] + 1] = { id = id, x = x, y = y, w = w, h = 1 }
  writeAt(x, y, string.rep(" ", w), fg, bg)
  writeAt(x + math.max(0, math.floor((w - #label) / 2)), y, label, fg, bg)
end

local function hitButton(key, x, y)
  for _, button in ipairs(buttonsByScreen[key] or {}) do
    if x >= button.x and x < button.x + button.w and y >= button.y and y < button.y + button.h then
      return button.id
    end
  end
end

local function hitVolume(key, x, y)
  local bar = volumeBarsByScreen[key]
  if bar and y == bar.y and x >= bar.x and x < bar.x + bar.w then
    return math.max(0, math.min(1, (x - bar.x + 1) / bar.w))
  end
end

local function refreshSpeakers()
  speakers = {}
  speakerNames = {}
  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "speaker" then
      local speaker = peripheral.wrap(name)
      if speaker then
        speakerNames[#speakerNames + 1] = name
        speakers[#speakers + 1] = speaker
      end
    end
  end
  return #speakers
end

local function stopSpeakers()
  for _, speaker in ipairs(speakers) do
    pcall(function() speaker.stop() end)
  end
end

local function testSpeakers()
  refreshSpeakers()
  stopSpeakers()
  sleep(0.1)
  local workingSpeakers = {}
  local workingNames = {}
  for index, speaker in ipairs(speakers) do
    local ok = pcall(function()
      speaker.stop()
      return speaker.playNote("harp", 0.05, 12)
    end)
    if ok then
      workingSpeakers[#workingSpeakers + 1] = speaker
      workingNames[#workingNames + 1] = speakerNames[index]
    end
  end
  speakers = workingSpeakers
  speakerNames = workingNames
  return #speakers
end

local function safeRead(path)
  if not fs.exists(path) then return nil end
  local file = fs.open(path, "r")
  local text = file.readAll()
  file.close()
  return text
end

local function saveTracks()
  local file = fs.open(tracksPath, "w")
  file.write(textutils.serialiseJSON({ tracks = tracks }))
  file.close()
end

local function loadTracks()
  local text = safeRead(tracksPath)
  if not text then
    tracks = {}
    return
  end
  local data = textutils.unserialiseJSON(text)
  tracks = type(data) == "table" and type(data.tracks) == "table" and data.tracks or {}
  if selected > #tracks then selected = #tracks end
  if selected < 1 then selected = 1 end
end

local function titleFromFile(name)
  return name:gsub("%.dfpwm$", ""):gsub("_", " "):gsub("-", " ")
end

local function downloadFresh(url, path)
  if fs.exists(path) then fs.delete(path) end
  for attempt = 1, 5 do
    for _, candidate in ipairs({ url, url:gsub(rawBase, githubRawBase) }) do
      shell.run("wget", candidate, path)
      if fs.exists(path) then return true end
    end
    sleep(1)
  end
  return false
end

local function downloadIfMissing(url, path)
  if fs.exists(path) then return true, "exists" end
  return downloadFresh(url, path), "downloaded"
end

local function drawLoading(title, detail, step, total)
  refreshScreens()
  for index, target in ipairs(screens) do
    screen = target
    local frames = { "|", "/", "-", "\\" }
    local w, h = screen.getSize()
    clear(colors.black)
    center(math.max(2, math.floor(h / 2) - 3), "ServerFOX Music", colors.cyan)
    center(math.max(3, math.floor(h / 2) - 1), title .. " " .. frames[(step % #frames) + 1], colors.lime)
    center(math.max(4, math.floor(h / 2) + 1), detail or "", colors.white)
    if total and total > 0 then
      local barW = math.max(10, math.min(w - 6, 34))
      local filled = math.floor((step / total) * barW)
      local bar = string.rep("#", filled) .. string.rep("-", barW - filled)
      center(math.max(5, math.floor(h / 2) + 3), "[" .. bar .. "]", colors.yellow)
      center(math.max(6, math.floor(h / 2) + 4), tostring(step) .. "/" .. tostring(total), colors.gray)
    end
  end
end

local function drawSpeakerScan()
  refreshScreens()
  for _, target in ipairs(screens) do
    screen = target
    clear(colors.black)
    local w, h = screen.getSize()
    center(2, "Speaker Scan", colors.cyan)
    center(4, "Found working speakers: " .. tostring(#speakers), colors.lime)
    local maxLines = h - 7
    for i = 1, math.min(#speakerNames, maxLines) do
      local name = speakerNames[i]
      if #name > w - 4 then name = name:sub(1, w - 7) .. "..." end
      writeAt(2, 5 + i, tostring(i) .. ". " .. name, colors.white)
    end
    center(h - 1, "Press any key...", colors.gray)
  end
  os.pullEvent("key")
end

local function discoverTracks()
  drawLoading("Updating library", "Reading GitHub repository", 1, 1)
  if not downloadFresh(apiUrl, tempListPath) then
    status = "GitHub list failed"
    return false
  end

  local files = textutils.unserialiseJSON(safeRead(tempListPath) or "")
  if type(files) ~= "table" then
    status = "Bad GitHub response"
    return false
  end

  local found = {}
  for _, item in ipairs(files) do
    if type(item) == "table" and item.type == "file" and type(item.name) == "string" then
      if item.name:lower():sub(-6) == ".dfpwm" then
        found[#found + 1] = {
          title = titleFromFile(item.name),
          file = item.name,
          url = item.download_url or (rawBase .. textutils.urlEncode(item.name)),
        }
      end
    end
  end
  table.sort(found, function(a, b) return a.title:lower() < b.title:lower() end)
  tracks = found
  saveTracks()
  status = "Found " .. #tracks .. " tracks"
  return true
end

local function updateLibrary()
  ensureDir(musicDir)
  if not discoverTracks() then return false end

  local done = 0
  for _, track in ipairs(tracks) do
    done = done + 1
    drawLoading("Downloading tracks", track.title or track.file, done, #tracks)
    local path = fs.combine(musicDir, track.file)
    downloadIfMissing(track.url or (rawBase .. textutils.urlEncode(track.file)), path)
  end
  status = "Updated. Free " .. fs.getFreeSpace("/") .. " bytes"
  return true
end

local function selfUpdate()
  drawLoading("Updating player", "Downloading latest player.lua", 1, 2)
  if downloadFresh(rawBase .. "player.lua", ".player_new") then
    if fs.exists("player") then fs.delete("player") end
    fs.move(".player_new", "player")
    drawLoading("Updating player", "Done. Rebooting app", 2, 2)
    sleep(1)
    shell.run("player")
    error()
  else
    status = "Self-update failed"
  end
end

local function draw()
  refreshScreens()
  refreshSpeakers()
  buttonsByScreen = {}
  volumeBarsByScreen = {}
  screenHeightsByScreen = {}
  listOffsetsByScreen = {}
  for screenIndex, target in ipairs(screens) do
    screen = target
    local key = screenKeys[screenIndex]
    clear(colors.black)
    local w, h = screen.getSize()
    screenHeightsByScreen[key] = h
    writeAt(2, 1, "ServerFOX Music", colors.cyan)
    writeAt(math.max(2, w - 13), 1, "SPK " .. tostring(#speakers), colors.lime)
    local volumeText = "VOL " .. tostring(math.floor(volume * 100 + 0.5)) .. "%"
    writeAt(math.max(2, w - #volumeText - 1), 2, volumeText, colors.yellow)
    writeAt(2, 2, status:sub(1, math.max(1, w - #volumeText - 4)), colors.gray)

    local listTop = 4
    local listBottom = h - 6
    for line = listTop, listBottom do
      writeAt(1, line, string.rep(" ", w), colors.white, colors.black)
    end

    local visible = math.max(1, listBottom - listTop + 1)
    local offset = 0
    if selected > visible then offset = selected - visible end
    listOffset = offset
    listOffsetsByScreen[key] = offset
    for i = 1, math.min(#tracks, visible) do
      local index = i + offset
      local track = tracks[index]
      local title = track and (track.title or track.file) or ""
      if #title > w - 5 then title = title:sub(1, w - 8) .. "..." end
      if index == selected then
        writeAt(2, listTop + i - 1, "> " .. title, colors.black, playing and colors.lime or colors.white)
      else
        writeAt(2, listTop + i - 1, "  " .. title, colors.white)
      end
    end

    local buttonY = h - 4
    local bw = math.max(6, math.floor((w - 7) / 5))
    addButton(key, "prev", 2, buttonY, bw, "Prev", colors.white, colors.gray)
    addButton(key, "play", 3 + bw, buttonY, bw, "Play", colors.black, colors.lime)
    addButton(key, "stop", 4 + bw * 2, buttonY, bw, "Stop", colors.white, colors.red)
    addButton(key, "next", 5 + bw * 3, buttonY, bw, "Next", colors.white, colors.gray)
    addButton(key, "update", 6 + bw * 4, buttonY, bw, "Update", colors.white, colors.blue)

    local barW = math.max(8, math.min(w - 20, 28))
    local filled = math.floor(volume * barW + 0.5)
    local barX = 10
    volumeBarsByScreen[key] = { x = barX + 1, y = h - 2, w = barW }
    writeAt(2, h - 2, "Volume [", colors.yellow)
    writeAt(barX + 1, h - 2, string.rep("#", filled) .. string.rep("-", barW - filled), colors.yellow)
    writeAt(barX + barW + 1, h - 2, "]", colors.yellow)
    writeAt(2, h, "Keys: Enter S U N/P R Q  +/- vol  T scan", colors.gray)
  end
end

local function selectNext()
  if #tracks == 0 then return end
  selected = selected + 1
  if selected > #tracks then selected = 1 end
end

local function selectPrev()
  if #tracks == 0 then return end
  selected = selected - 1
  if selected < 1 then selected = #tracks end
end

local function controlAction(id)
  if id == "stop" then
    stopRequested = true
    manualStopRequested = true
    stopSpeakers()
  elseif id == "next" then
    nextRequested = true
    stopRequested = true
    stopSpeakers()
  elseif id == "prev" then
    prevRequested = true
    stopRequested = true
    stopSpeakers()
  elseif id == "update" then
    stopRequested = true
    manualStopRequested = true
    stopSpeakers()
    updateLibrary()
    loadTracks()
    draw()
  elseif id == "play" then
    return
  end
end

local function changeVolume(delta)
  volume = math.max(0, math.min(1, volume + delta))
  status = "Volume " .. tostring(math.floor(volume * 100 + 0.5)) .. "%"
end

local function handlePlaybackEvent(event, a, b, c)
  if event == "key" then
    local key = keys.getName(a)
    if key == "s" then controlAction("stop")
    elseif key == "n" or key == "right" then controlAction("next")
    elseif key == "p" or key == "left" then controlAction("prev")
    elseif key == "minus" then changeVolume(-0.1); draw()
    elseif key == "equals" or key == "numPadAdd" then changeVolume(0.1); draw()
    end
  elseif event == "monitor_touch" or event == "mouse_click" then
    local screenKey = event == "monitor_touch" and a or "__term"
    local x = b
    local y = c
    local newVolume = hitVolume(screenKey, x, y)
    if newVolume then
      volume = newVolume
      changeVolume(0)
      draw()
      return
    end
    local id = hitButton(screenKey, x, y)
    if id then controlAction(id) end
  end
end

local function playSelected()
  if #tracks == 0 then
    status = "No tracks. Press Update"
    draw()
    return
  end

  local track = tracks[selected]
  local path = fs.combine(musicDir, track.file)
  if not fs.exists(path) then
    status = "Missing track. Updating..."
    draw()
    updateLibrary()
    if not fs.exists(path) then
      status = "Still missing: " .. track.file
      draw()
      return
    end
  end

  status = "Scanning speakers..."
  draw()
  testSpeakers()
  if #speakers == 0 then
    status = "No speakers found"
    draw()
    return
  end

  playing = true
  stopRequested = false
  manualStopRequested = false
  nextRequested = false
  prevRequested = false
  status = "Playing: " .. (track.title or track.file)
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
          local ok, played = pcall(function() return speaker.playAudio(buffer, volume) end)
          if not ok then
            ok, played = pcall(function() return speaker.playAudio(buffer) end)
          end
          if not ok or played then
            pending[index] = false
            remaining = remaining - 1
          end
        end
      end
      if remaining > 0 then
        handlePlaybackEvent(os.pullEvent())
      end
    end
  end
  file.close()
  stopSpeakers()
  playing = false

  if nextRequested then
    selectNext()
    playSelected()
  elseif prevRequested then
    selectPrev()
    playSelected()
  elseif manualStopRequested then
    status = "Stopped"
    draw()
  else
    selectNext()
    playSelected()
  end
end

loadTracks()
if #tracks == 0 then status = "Press Update to load tracks" end
draw()

while true do
  local event, a, b, c = os.pullEvent()
  if event == "key" then
    local key = keys.getName(a)
    if key == "up" then selected = math.max(1, selected - 1); draw()
    elseif key == "down" then selected = math.min(#tracks, selected + 1); draw()
    elseif key == "enter" then playSelected()
    elseif key == "s" then controlAction("stop"); draw()
    elseif key == "u" then updateLibrary(); loadTracks(); draw()
    elseif key == "n" or key == "right" then selectNext(); draw()
    elseif key == "p" or key == "left" then selectPrev(); draw()
    elseif key == "minus" then changeVolume(-0.1); draw()
    elseif key == "equals" or key == "numPadAdd" then changeVolume(0.1); draw()
    elseif key == "t" then testSpeakers(); drawSpeakerScan(); draw()
    elseif key == "r" then selfUpdate()
    elseif key == "q" then stopSpeakers(); clear(); return
    end
  elseif event == "monitor_touch" or event == "mouse_click" then
    local screenKey = event == "monitor_touch" and a or "__term"
    local x = b
    local y = c
    local handled = false
    local newVolume = hitVolume(screenKey, x, y)
    if newVolume then
      volume = newVolume
      changeVolume(0)
      draw()
      handled = true
    end
    if not handled then
      local id = hitButton(screenKey, x, y)
      if id == "play" then
        playSelected()
        handled = true
      elseif id == "next" then
        selectNext()
        draw()
        handled = true
      elseif id == "prev" then
        selectPrev()
        draw()
        handled = true
      elseif id then
        controlAction(id)
        draw()
        handled = true
      end
    end
    if not handled then
      local h = screenHeightsByScreen[screenKey] or select(2, screen.getSize())
      local index = y - 3 + (listOffsetsByScreen[screenKey] or listOffset)
      if index >= 1 and index <= #tracks and y < h - 3 then
        selected = index
        draw()
      end
    end
  elseif event == "peripheral" or event == "peripheral_detach" then
    testSpeakers()
    draw()
  end
end
]==]

local function writeFile(path, text)
  if fs.exists(path) then fs.delete(path) end
  local file = fs.open(path, "w")
  file.write(text)
  file.close()
  print("Wrote " .. path)
end

writeFile("player", playerSource)
if not fs.exists("music") then fs.makeDir("music") end
print("Installed ServerFOX Music player.")
print("Run: player")
print("Use Update inside player to download tracks.")
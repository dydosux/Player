local dfpwm = require("cc.audio.dfpwm")

local owner = "dydosux"
local repo = "Player"
local branch = "main"
local rawBase = "https://raw.githubusercontent.com/" .. owner .. "/" .. repo .. "/" .. branch .. "/"
local githubRawBase = "https://github.com/" .. owner .. "/" .. repo .. "/raw/" .. branch .. "/"
local apiUrl = "https://api.github.com/repos/" .. owner .. "/" .. repo .. "/contents?ref=" .. branch

local musicDir = "music"
local tracksPath = "tracks.json"
local tempListPath = ".repo_files.json"

local screen = peripheral.find("monitor") or term.current()
if screen.setTextScale then screen.setTextScale(0.5) end

local tracks = {}
local selected = 1
local playing = false
local status = "Ready"
local speakers = {}
local buttons = {}
local stopRequested = false
local nextRequested = false
local prevRequested = false
local listOffset = 0

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

local function addButton(id, x, y, w, label, fg, bg)
  buttons[#buttons + 1] = { id = id, x = x, y = y, w = w, h = 1 }
  writeAt(x, y, string.rep(" ", w), fg, bg)
  writeAt(x + math.max(0, math.floor((w - #label) / 2)), y, label, fg, bg)
end

local function hitButton(x, y)
  for _, button in ipairs(buttons) do
    if x >= button.x and x < button.x + button.w and y >= button.y and y < button.y + button.h then
      return button.id
    end
  end
end

local function refreshSpeakers()
  speakers = { peripheral.find("speaker") }
  return #speakers
end

local function stopSpeakers()
  for _, speaker in ipairs(speakers) do
    pcall(function() speaker.stop() end)
  end
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
  buttons = {}
  refreshSpeakers()
  clear(colors.black)
  local w, h = screen.getSize()
  writeAt(2, 1, "ServerFOX Music", colors.cyan)
  writeAt(w - 13, 1, "SPK " .. tostring(#speakers), colors.lime)
  writeAt(2, 2, status, colors.gray)

  local listTop = 4
  local listBottom = h - 4
  for line = listTop, listBottom do
    writeAt(1, line, string.rep(" ", w), colors.white, colors.black)
  end

  local visible = math.max(1, listBottom - listTop + 1)
  local offset = 0
  if selected > visible then offset = selected - visible end
  listOffset = offset
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

  local y = h - 2
  local bw = math.max(7, math.floor((w - 7) / 5))
  addButton("prev", 2, y, bw, "Prev", colors.white, colors.gray)
  addButton("play", 3 + bw, y, bw, "Play", colors.black, colors.lime)
  addButton("stop", 4 + bw * 2, y, bw, "Stop", colors.white, colors.red)
  addButton("next", 5 + bw * 3, y, bw, "Next", colors.white, colors.gray)
  addButton("update", 6 + bw * 4, y, bw, "Update", colors.white, colors.blue)
  writeAt(2, h, "Keys: Up/Down Enter S U N/P R Q", colors.gray)
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
    stopSpeakers()
    updateLibrary()
    loadTracks()
    draw()
  elseif id == "play" then
    stopRequested = true
  end
end

local function handlePlaybackEvent(event, a, b, c)
  if event == "key" then
    local key = keys.getName(a)
    if key == "s" then controlAction("stop")
    elseif key == "n" or key == "right" then controlAction("next")
    elseif key == "p" or key == "left" then controlAction("prev")
    end
  elseif event == "monitor_touch" or event == "mouse_click" then
    local x = b
    local y = c
    local id = hitButton(x, y)
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

  refreshSpeakers()
  if #speakers == 0 then
    status = "No speakers found"
    draw()
    return
  end

  playing = true
  stopRequested = false
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
          local ok, played = pcall(function() return speaker.playAudio(buffer) end)
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
  else
    status = "Stopped"
    draw()
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
    elseif key == "r" then selfUpdate()
    elseif key == "q" then stopSpeakers(); clear(); return
    end
  elseif event == "monitor_touch" or event == "mouse_click" then
    local x = b
    local y = c
    local id = hitButton(x, y)
    if id == "play" then playSelected()
    elseif id then controlAction(id)
    else
      local _, h = screen.getSize()
      local index = y - 3 + listOffset
      if index >= 1 and index <= #tracks and y < h - 3 then
        selected = index
        draw()
      end
    end
  elseif event == "peripheral" or event == "peripheral_detach" then
    refreshSpeakers()
    draw()
  end
end

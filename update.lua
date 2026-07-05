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

local count = 0
for _, track in ipairs(manifest.tracks) do
  if type(track.file) == "string" then
    local localPath = fs.combine(musicDir, track.file)
    local url = rawBase .. textutils.urlEncode(track.file)
    if download(url, localPath, true) then
      count = count + 1
      print("OK: " .. (track.title or track.file))
    end
  end
end

print("Updated tracks: " .. count)

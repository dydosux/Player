local owner = "dydosux"
local repo = "Player"
local branch = "main"
local rawBase = "https://raw.githubusercontent.com/" .. owner .. "/" .. repo .. "/" .. branch .. "/"
local musicDir = "music"

local function ensureDir(path)
  if not fs.exists(path) then fs.makeDir(path) end
end

local function download(url, path, binary)
  local response = http.get(url, nil, binary)
  if not response then
    print("Failed: " .. url)
    return false
  end

  local data = response.readAll()
  response.close()

  local file = fs.open(path, binary and "wb" or "w")
  file.write(data)
  file.close()
  return true
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

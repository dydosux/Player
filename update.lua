local owner = "dydosux"
local repo = "Player"
local branch = "main"
local rawBase = "https://raw.githubusercontent.com/" .. owner .. "/" .. repo .. "/" .. branch .. "/"
local githubRawBase = "https://github.com/" .. owner .. "/" .. repo .. "/raw/" .. branch .. "/"
local apiUrl = "https://api.github.com/repos/" .. owner .. "/" .. repo .. "/contents?ref=" .. branch
local musicDir = "music"

local function ensureDir(path)
  if not fs.exists(path) then fs.makeDir(path) end
end

local function downloadFresh(url, path)
  if fs.exists(path) then fs.delete(path) end
  for attempt = 1, 5 do
    for _, candidate in ipairs({ url, url:gsub(rawBase, githubRawBase) }) do
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

local function download(url, path, binary)
  if fs.exists(path) then
    print("Exists: " .. path)
    return true
  end
  return downloadFresh(url, path)
end

local function titleFromFile(name)
  local title = name:gsub("%.dfpwm$", "")
  title = title:gsub("_", " "):gsub("-", " ")
  return title
end

local function saveManifest(tracks)
  local file = fs.open("tracks.json", "w")
  file.write(textutils.serialiseJSON({ tracks = tracks }))
  file.close()
end

local function loadManifest()
  if not downloadFresh(apiUrl, "repo_files.json") then
    print("Cannot load GitHub file list, using existing tracks.json")
    local file = fs.open("tracks.json", "r")
    local text = file.readAll()
    file.close()
    return textutils.unserialiseJSON(text)
  end

  local file = fs.open("repo_files.json", "r")
  local text = file.readAll()
  file.close()

  local files = textutils.unserialiseJSON(text)
  if type(files) ~= "table" then error("GitHub file list is invalid") end

  local tracks = {}
  for _, item in ipairs(files) do
    if type(item) == "table" and item.type == "file" and type(item.name) == "string" then
      if item.name:lower():sub(-6) == ".dfpwm" then
        tracks[#tracks + 1] = {
          title = titleFromFile(item.name),
          file = item.name,
          url = item.download_url,
        }
      end
    end
  end

  table.sort(tracks, function(a, b) return a.title:lower() < b.title:lower() end)
  saveManifest(tracks)
  return { tracks = tracks }
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
    local url = track.url or (rawBase .. textutils.urlEncode(track.file))
    if download(url, localPath, true) then
      count = count + 1
      print("OK: " .. (track.title or track.file))
    end
  end
end

print("Updated tracks: " .. count)
print("Free space: " .. fs.getFreeSpace("/") .. " bytes")

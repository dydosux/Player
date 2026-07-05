local owner = "dydosux"
local repo = "Test"
local branch = "main"
local rawBase = "https://raw.githubusercontent.com/" .. owner .. "/" .. repo .. "/" .. branch .. "/"

local files = {
  { url = rawBase .. "player.lua", path = "player" },
  { url = rawBase .. "update.lua", path = "update" },
  { url = rawBase .. "tracks.json", path = "tracks.json" },
}

local function download(url, path, binary)
  print("Downloading " .. path)
  local handle = http.get(url, nil, binary)
  if not handle then error("Cannot download: " .. url) end
  local data = handle.readAll()
  handle.close()

  local file = fs.open(path, binary and "wb" or "w")
  file.write(data)
  file.close()
end

for _, item in ipairs(files) do
  download(item.url, item.path, false)
end

shell.run("update")
print("Installed. Run: player")

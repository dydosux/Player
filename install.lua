local owner = "dydosux"
local repo = "Player"
local branch = "main"
local rawBase = "https://raw.githubusercontent.com/" .. owner .. "/" .. repo .. "/" .. branch .. "/"

local files = {
  { url = rawBase .. "player.lua", path = "player" },
  { url = rawBase .. "update.lua", path = "update" },
  { url = rawBase .. "tracks.json", path = "tracks.json" }
}

local function download(url, path)
  print("Downloading " .. path)
  if fs.exists(path) then fs.delete(path) end
  shell.run("wget", url, path)
  if not fs.exists(path) then
    error("Cannot download: " .. url)
  end
end

for _, item in ipairs(files) do
  download(item.url, item.path)
end

shell.run("update")
print("Installed. Run: player")

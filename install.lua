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
  for attempt = 1, 5 do
    if fs.exists(path) then fs.delete(path) end
    shell.run("wget", url, path)
    if fs.exists(path) then return end
    print("Retry " .. attempt .. "/5")
    sleep(1)
  end
  error("Cannot download: " .. url)
end

for _, item in ipairs(files) do
  download(item.url, item.path)
end

shell.run("update")
print("Installed. Run: player")

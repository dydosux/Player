local owner = "dydosux"
local repo = "Player"
local branch = "main"
local rawBase = "https://raw.githubusercontent.com/" .. owner .. "/" .. repo .. "/" .. branch .. "/"
local githubRawBase = "https://github.com/" .. owner .. "/" .. repo .. "/raw/" .. branch .. "/"

local files = {
  { url = rawBase .. "player.lua", path = "player" },
  { url = rawBase .. "update.lua", path = "update" },
  { url = rawBase .. "tracks.json", path = "tracks.json" }
}

local function download(url, path)
  print("Downloading " .. path)
  for attempt = 1, 5 do
    for _, base in ipairs({ rawBase, githubRawBase }) do
      if fs.exists(path) then fs.delete(path) end
      shell.run("wget", base .. url, path)
      if fs.exists(path) then
        sleep(0.5)
        return
      end
    end
    print("Retry " .. attempt .. "/5")
    sleep(2)
  end
  error("Cannot download: " .. path)
end

for _, item in ipairs(files) do
  download(item.url:gsub(rawBase, ""), item.path)
end

shell.run("update")
print("Installed. Run: player")

-- loader.lua
local BASE = "https://raw.githubusercontent.com/divso123/script/main/games/"

local games = {
    [112274915308120] = "test.lua",
    [286090429]  = "arsenal.lua",
    [4924922222] = "brookhaven.lua",
    -- add PlaceId = "filename.lua" for each game
}

local script_name = games[game.PlaceId]
if script_name then
    loadstring(game:HttpGet(BASE .. script_name))()
else
    warn("[PotatoUI] No script for this game — PlaceId: " .. game.PlaceId)
end

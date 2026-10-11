-- loader.lua
local BASE = "https://raw.githubusercontent.com/YOURNAME/PotatoUI/main/games/"

local games = {
    [2753915549] = "bloxfruits.lua",
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

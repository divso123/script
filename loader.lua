-- loader.lua
local BASE = "https://raw.githubusercontent.com/divso123/script/main/games/"

local games = {
    [79389059854988] = "myanimemine.lua",
    [2753915549] = "bloxfruits.lua",
    [4924922222] = "brookhaven.lua",
    -- add PlaceId = "filename.lua" for each game
}

local script_name = games[game.PlaceId]
if script_name then
    loadstring(game:HttpGet(BASE .. script_name))()
else
    warn("Game is not Supported! — PlaceId: " .. game.PlaceId)
end

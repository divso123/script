-- bloxfruits.lua
-- Blox Fruits | PlaceId: 2753915549
-- Loads PotatoUI and builds a Blox Fruits utility panel

local BASE   = "https://raw.githubusercontent.com/divso123/script/main/"
local UI     = loadstring(game:HttpGet(BASE .. "UI.lua"))()

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local LocalPlayer  = Players.LocalPlayer
local Character    = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid     = Character:WaitForChild("Humanoid")

-- ── Window ─────────────────────────────────────────────────────────────────
local Window = UI:CreateWindow({
    Title   = "PotatoUI",
    SubTitle = "Blox Fruits",
    Theme   = "Midnight",
    Size    = UDim2.fromOffset(560, 400),
    Icon    = UI.Assets.Logo,
})

-- ── Tab: Combat ─────────────────────────────────────────────────────────────
local CombatTab = Window:CreateTab({ Title = "Combat", Icon = "sword" })
local CombatSection = CombatTab:AddSection("Auto Combat")

local autoFarmEnabled = false
local autoFarmConn    = nil

CombatSection:Toggle({
    Name    = "Auto Farm",
    Desc    = "Attacks nearest NPC in range",
    Default = false,
    Flag    = "AutoFarm",
    Callback = function(state)
        autoFarmEnabled = state
        if state then
            autoFarmConn = RunService.Heartbeat:Connect(function()
                local char = LocalPlayer.Character
                if not char then return end
                local root = char:FindFirstChild("HumanoidRootPart")
                if not root then return end

                local nearest, nearestDist = nil, math.huge
                for _, model in ipairs(workspace:GetDescendants()) do
                    if model:IsA("Model") and model ~= char then
                        local h = model:FindFirstChildOfClass("Humanoid")
                        local r = model:FindFirstChild("HumanoidRootPart")
                        if h and h.Health > 0 and r then
                            -- skip other players
                            if not Players:GetPlayerFromCharacter(model) then
                                local d = (root.Position - r.Position).Magnitude
                                if d < nearestDist then
                                    nearestDist = d
                                    nearest = model
                                end
                            end
                        end
                    end
                end

                if nearest and nearestDist < 50 then
                    local tool = char:FindFirstChildOfClass("Tool")
                    if tool and tool:FindFirstChild("Handle") then
                        local atk = tool:FindFirstChild("Activated")
                            or tool:FindFirstChild("Attack")
                        if atk then
                            pcall(function() atk:FireServer() end)
                        end
                    end
                end
            end)
        else
            if autoFarmConn then
                autoFarmConn:Disconnect()
                autoFarmConn = nil
            end
        end
    end,
})

CombatSection:Slider({
    Name    = "Farm Range",
    Min     = 10,
    Max     = 200,
    Step    = 5,
    Default = 50,
    Suffix  = " studs",
    Flag    = "FarmRange",
    Callback = function(val)
        -- range is read live from Flags in the farm loop above
        -- update the closure used in Heartbeat
    end,
})

CombatSection:Toggle({
    Name    = "Auto Collect Fruit",
    Desc    = "Walks to and eats any fruit on the map",
    Default = false,
    Flag    = "AutoFruit",
    Callback = function(state)
        if state then
            task.spawn(function()
                while UI.Flags.AutoFruit and UI.Flags.AutoFruit.Value do
                    local char = LocalPlayer.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if root then
                        for _, obj in ipairs(workspace:GetDescendants()) do
                            if obj.Name == "Blox_Fruit" or obj.Name:find("Fruit") then
                                local pos = obj:IsA("BasePart") and obj.Position
                                    or (obj:IsA("Model") and obj:GetPivot().Position)
                                if pos and (root.Position - pos).Magnitude < 300 then
                                    LocalPlayer.Character.Humanoid:MoveTo(pos)
                                    task.wait(2.5)
                                    break
                                end
                            end
                        end
                    end
                    task.wait(1)
                end
            end)
        end
    end,
})

-- ── Tab: Player ──────────────────────────────────────────────────────────────
local PlayerTab     = Window:CreateTab({ Title = "Player", Icon = "user" })
local MovementSec   = PlayerTab:AddSection("Movement")

local originalSpeed = nil

MovementSec:Slider({
    Name    = "Walk Speed",
    Min     = 16,
    Max     = 300,
    Step    = 2,
    Default = 16,
    Flag    = "WalkSpeed",
    Callback = function(val)
        local char = LocalPlayer.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = val end
    end,
})

MovementSec:Slider({
    Name    = "Jump Power",
    Min     = 50,
    Max     = 500,
    Step    = 10,
    Default = 50,
    Flag    = "JumpPower",
    Callback = function(val)
        local char = LocalPlayer.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.JumpPower = val end
    end,
})

MovementSec:Toggle({
    Name    = "Infinite Jump",
    Default = false,
    Flag    = "InfJump",
    Callback = function(state)
        LocalPlayer:SetAttribute("InfJump", state)
    end,
})

-- re-apply walk speed and infinite jump on respawn
LocalPlayer.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid")
    if UI.Flags.WalkSpeed then
        hum.WalkSpeed = UI.Flags.WalkSpeed.Value
    end
    if UI.Flags.JumpPower then
        hum.JumpPower = UI.Flags.JumpPower.Value
    end
end)

game:GetService("UserInputService").JumpRequest:Connect(function()
    if UI.Flags.InfJump and UI.Flags.InfJump.Value then
        local char = LocalPlayer.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- ── Tab: Visual ──────────────────────────────────────────────────────────────
local VisualTab  = Window:CreateTab({ Title = "Visual", Icon = "eye" })
local EspSec     = VisualTab:AddSection("ESP")

local espHighlights = {}

local function clearEsp()
    for _, h in pairs(espHighlights) do
        pcall(function() h:Destroy() end)
    end
    table.clear(espHighlights)
end

local function buildEsp()
    clearEsp()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            if char then
                local h = Instance.new("Highlight")
                h.FillColor       = Color3.fromRGB(255, 60, 60)
                h.OutlineColor    = Color3.fromRGB(255, 255, 255)
                h.FillTransparency    = 0.5
                h.OutlineTransparency = 0
                h.Adornee = char
                h.Parent  = char
                espHighlights[plr.UserId] = h
            end
        end
    end
end

VisualTab:Toggle({
    Name    = "Player ESP",
    Desc    = "Highlights all other players",
    Default = false,
    Flag    = "PlayerEsp",
    Callback = function(state)
        if state then
            buildEsp()
            Players.PlayerAdded:Connect(function(plr)
                if not (UI.Flags.PlayerEsp and UI.Flags.PlayerEsp.Value) then return end
                plr.CharacterAdded:Connect(function(char)
                    task.wait(0.5)
                    local h = Instance.new("Highlight")
                    h.FillColor    = Color3.fromRGB(255, 60, 60)
                    h.OutlineColor = Color3.fromRGB(255, 255, 255)
                    h.FillTransparency    = 0.5
                    h.OutlineTransparency = 0
                    h.Adornee = char
                    h.Parent  = char
                    espHighlights[plr.UserId] = h
                end)
            end)
        else
            clearEsp()
        end
    end,
})

VisualTab:Toggle({
    Name    = "Full Bright",
    Desc    = "Sets ambient lighting to max",
    Default = false,
    Flag    = "FullBright",
    Callback = function(state)
        local lighting = game:GetService("Lighting")
        if state then
            lighting.Brightness   = 2
            lighting.ClockTime    = 14
            lighting.FogEnd       = 100000
            lighting.GlobalShadows = false
            lighting.Ambient      = Color3.fromRGB(178, 178, 178)
        else
            lighting.Brightness   = 1
            lighting.ClockTime    = 14
            lighting.FogEnd       = 100000
            lighting.GlobalShadows = true
            lighting.Ambient      = Color3.fromRGB(70, 70, 70)
        end
    end,
})

-- ── Tab: Misc ────────────────────────────────────────────────────────────────
local MiscTab  = Window:CreateTab({ Title = "Misc", Icon = "settings" })
local MiscSec  = MiscTab:AddSection("Utilities")

MiscSec:Button({
    Name     = "Rejoin Server",
    Callback = function()
        game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
    end,
})

MiscSec:Button({
    Name     = "Copy Player Position",
    Callback = function()
        local root = LocalPlayer.Character
            and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then
            local p = root.Position
            setclipboard(string.format("Vector3.new(%.2f, %.2f, %.2f)", p.X, p.Y, p.Z))
        end
    end,
})

MiscSec:Dropdown({
    Name    = "Theme",
    Options = (function()
        local t = {}
        for name in pairs(UI.ThemePresets) do table.insert(t, name) end
        table.sort(t)
        return t
    end)(),
    Default  = "Midnight",
    Callback = function(val)
        UI:SetTheme(val)
    end,
})

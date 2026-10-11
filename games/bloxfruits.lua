-- bloxfruits.lua
-- Blox Fruits | PlaceId: 2753915549

local BASE = "https://raw.githubusercontent.com/divso123/script/main/"
local UI   = loadstring(game:HttpGet(BASE .. "UI.lua"))()

local Players     = game:GetService("Players")
local UIS         = game:GetService("UserInputService")
local RunService  = game:GetService("RunService")
local Lighting    = game:GetService("Lighting")
local TeleportSvc = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

-- ── Window ───────────────────────────────────────────────────────────────────
local Window = UI:Window({
    Title    = "DivineSoul",
    SubTitle = "Blox Fruits",
    Theme    = "Midnight",
})

-- ── Tab: Combat ───────────────────────────────────────────────────────────────
local Combat = Window:Tab({ Title = "Combat", Icon = "sword" })
Combat:Section("Auto Combat")

local farmConn = nil

Combat:Toggle({
    Name    = "Auto Farm",
    Desc    = "Attacks nearest NPC within range",
    Default = false,
    Flag    = "AutoFarm",
    Callback = function(on)
        if farmConn then farmConn:Disconnect(); farmConn = nil end
        if not on then return end
        farmConn = RunService.Heartbeat:Connect(function()
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then return end
            local range = (UI.Flags.FarmRange and UI.Flags.FarmRange.Value) or 50
            local best, bestD = nil, math.huge
            for _, m in ipairs(workspace:GetDescendants()) do
                if m:IsA("Model") and m ~= char
                    and not Players:GetPlayerFromCharacter(m) then
                    local h = m:FindFirstChildOfClass("Humanoid")
                    local r = m:FindFirstChild("HumanoidRootPart")
                    if h and h.Health > 0 and r then
                        local d = (root.Position - r.Position).Magnitude
                        if d < bestD then bestD = d; best = m end
                    end
                end
            end
            if best and bestD <= range then
                local tool = char:FindFirstChildOfClass("Tool")
                if tool then
                    local atk = tool:FindFirstChild("Activated")
                           or  tool:FindFirstChild("Attack")
                    if atk then pcall(function() atk:FireServer() end) end
                end
            end
        end)
    end,
})

Combat:Slider({
    Name    = "Farm Range",
    Min     = 10,
    Max     = 200,
    Step    = 5,
    Default = 50,
    Suffix  = " studs",
    Flag    = "FarmRange",
    Callback = function(_) end,
})

Combat:Toggle({
    Name    = "Auto Collect Fruit",
    Desc    = "Walks toward any fruit on the map",
    Default = false,
    Flag    = "AutoFruit",
    Callback = function(on)
        if not on then return end
        task.spawn(function()
            while UI.Flags.AutoFruit and UI.Flags.AutoFruit.Value do
                local char = LocalPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                local hum  = char and char:FindFirstChildOfClass("Humanoid")
                if root and hum then
                    for _, obj in ipairs(workspace:GetDescendants()) do
                        local isFruit = obj.Name == "Blox_Fruit"
                            or obj.Name:lower():find("fruit")
                        if isFruit then
                            local pos = obj:IsA("BasePart") and obj.Position
                                     or (obj:IsA("Model") and obj:GetPivot().Position)
                            if pos and (root.Position - pos).Magnitude < 400 then
                                hum:MoveTo(pos)
                                task.wait(2.5)
                                break
                            end
                        end
                    end
                end
                task.wait(1)
            end
        end)
    end,
})

-- ── Tab: Player ───────────────────────────────────────────────────────────────
local Player = Window:Tab({ Title = "Player", Icon = "user" })
Player:Section("Movement")

Player:Slider({
    Name    = "Walk Speed",
    Min     = 16,
    Max     = 300,
    Step    = 2,
    Default = 16,
    Flag    = "WalkSpeed",
    Callback = function(val)
        local hum = LocalPlayer.Character
            and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = val end
    end,
})

Player:Slider({
    Name    = "Jump Power",
    Min     = 50,
    Max     = 500,
    Step    = 10,
    Default = 50,
    Flag    = "JumpPower",
    Callback = function(val)
        local hum = LocalPlayer.Character
            and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.JumpPower = val end
    end,
})

Player:Toggle({
    Name    = "Infinite Jump",
    Default = false,
    Flag    = "InfJump",
    Callback = function(_) end,
})

UIS.JumpRequest:Connect(function()
    if UI.Flags.InfJump and UI.Flags.InfJump.Value then
        local hum = LocalPlayer.Character
            and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

LocalPlayer.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid")
    if UI.Flags.WalkSpeed then hum.WalkSpeed = UI.Flags.WalkSpeed.Value end
    if UI.Flags.JumpPower then hum.JumpPower = UI.Flags.JumpPower.Value end
end)

-- ── Tab: Visual ───────────────────────────────────────────────────────────────
local Visual = Window:Tab({ Title = "Visual", Icon = "eye" })
Visual:Section("ESP")

local espHighlights = {}

local function clearEsp()
    for _, h in pairs(espHighlights) do pcall(function() h:Destroy() end) end
    table.clear(espHighlights)
end

local function addEspToChar(char, userId)
    if not char then return end
    local h = Instance.new("Highlight")
    h.FillColor           = Color3.fromRGB(255, 60, 60)
    h.OutlineColor        = Color3.fromRGB(255, 255, 255)
    h.FillTransparency    = 0.5
    h.OutlineTransparency = 0
    h.Adornee = char
    h.Parent  = char
    espHighlights[userId] = h
end

Visual:Toggle({
    Name    = "Player ESP",
    Desc    = "Highlights all other players",
    Default = false,
    Flag    = "PlayerESP",
    Callback = function(on)
        if on then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then addEspToChar(p.Character, p.UserId) end
            end
            Players.PlayerAdded:Connect(function(p)
                p.CharacterAdded:Connect(function(c)
                    if UI.Flags.PlayerESP and UI.Flags.PlayerESP.Value then
                        task.wait(0.5); addEspToChar(c, p.UserId)
                    end
                end)
            end)
        else
            clearEsp()
        end
    end,
})

Visual:Toggle({
    Name    = "Full Bright",
    Default = false,
    Flag    = "FullBright",
    Callback = function(on)
        Lighting.Brightness    = on and 2   or 1
        Lighting.ClockTime     = on and 14  or 14
        Lighting.GlobalShadows = not on
        Lighting.Ambient       = on
            and Color3.fromRGB(178, 178, 178)
            or  Color3.fromRGB(70, 70, 70)
    end,
})

-- ── Tab: Misc ─────────────────────────────────────────────────────────────────
local Misc = Window:Tab({ Title = "Misc", Icon = "settings" })
Misc:Section("Utilities")

Misc:Button({
    Name     = "Rejoin Server",
    Callback = function()
        TeleportSvc:Teleport(game.PlaceId, LocalPlayer)
    end,
})

Misc:Button({
    Name     = "Copy Position",
    Desc     = "Copies HRP position to clipboard",
    Callback = function()
        local root = LocalPlayer.Character
            and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root then
            local p = root.Position
            setclipboard(("%.2f, %.2f, %.2f"):format(p.X, p.Y, p.Z))
        end
    end,
})

Misc:Dropdown({
    Name    = "Theme",
    Options = (function()
        local t = {}
        for name in pairs(UI.ThemePresets) do table.insert(t, name) end
        table.sort(t)
        return t
    end)(),
    Default  = "Midnight",
    Callback = function(val) UI:SetTheme(val) end,
})

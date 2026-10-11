-- test.lua
-- uses AirFlow (SakuraFlower) API loaded from your UI.lua

local UI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/divso123/script/main/UI.lua"
))()

-- ══════════════════════════════════════
-- WINDOW
-- ══════════════════════════════════════
local Window = UI:Window({
    Title   = "PotatoUI Test",
    Theme   = "Midnight",   -- swap to: Sakura, Nebula, Dracula, Ocean, etc.
    Intro   = false,
})

-- ══════════════════════════════════════
-- TAB 1 — BUTTONS
-- ══════════════════════════════════════
local tab1 = Window:Tab({ Name = "Buttons", Icon = "lucide:mouse-pointer-click" })

tab1:Section("Button Tests")

tab1:Button({
    Name     = "Basic Button",
    Desc     = "Prints a message to console",
    Callback = function()
        print("[Test] Basic Button clicked")
    end
})

tab1:Button({
    Name     = "Print Player Name",
    Desc     = "Prints your username",
    Callback = function()
        print("[Test] Player:", game.Players.LocalPlayer.Name)
    end
})

tab1:Button({
    Name     = "Print PlaceId",
    Desc     = "Useful for adding to loader.lua",
    Callback = function()
        print("[Test] PlaceId:", game.PlaceId)
    end
})

-- ══════════════════════════════════════
-- TAB 2 — TOGGLES
-- ══════════════════════════════════════
local tab2 = Window:Tab({ Name = "Toggles", Icon = "lucide:toggle-left" })

tab2:Section("Toggle Tests")

local tog1 = tab2:Toggle({
    Name     = "Toggle A",
    Desc     = "Starts OFF",
    Default  = false,
    Callback = function(val)
        print("[Test] Toggle A:", val)
    end
})

local tog2 = tab2:Toggle({
    Name     = "Toggle B",
    Desc     = "Starts ON",
    Default  = true,
    Callback = function(val)
        print("[Test] Toggle B:", val)
    end
})

tab2:Divider()

tab2:Button({
    Name     = "Read Both Toggles",
    Callback = function()
        print("[Test] Toggle A:", tog1:Get())
        print("[Test] Toggle B:", tog2:Get())
    end
})

tab2:Button({
    Name     = "Flip Toggle A",
    Callback = function()
        tog1:Set(not tog1:Get())
    end
})

-- ══════════════════════════════════════
-- TAB 3 — SLIDERS
-- ══════════════════════════════════════
local tab3 = Window:Tab({ Name = "Sliders", Icon = "lucide:sliders-horizontal" })

tab3:Section("Slider Tests")

local spd = tab3:Slider({
    Name     = "Walk Speed",
    Min      = 16,
    Max      = 300,
    Default  = 16,
    Step     = 1,
    Suffix   = " spd",
    Callback = function(val)
        print("[Test] WalkSpeed:", val)
        local char = game.Players.LocalPlayer.Character
        if char and char:FindFirstChild("Humanoid") then
            char.Humanoid.WalkSpeed = val
        end
    end
})

local jp = tab3:Slider({
    Name     = "Jump Power",
    Min      = 0,
    Max      = 200,
    Default  = 50,
    Step     = 1,
    Callback = function(val)
        print("[Test] JumpPower:", val)
        local char = game.Players.LocalPlayer.Character
        if char and char:FindFirstChild("Humanoid") then
            char.Humanoid.JumpPower = val
        end
    end
})

tab3:Divider()

tab3:Button({
    Name     = "Read Slider Values",
    Callback = function()
        print("[Test] Speed:", spd:Get(), "| Jump:", jp:Get())
    end
})

tab3:Button({
    Name     = "Reset Sliders",
    Callback = function()
        spd:Set(16)
        jp:Set(50)
        print("[Test] Sliders reset")
    end
})

-- ══════════════════════════════════════
-- TAB 4 — DROPDOWN
-- ══════════════════════════════════════
local tab4 = Window:Tab({ Name = "Dropdown", Icon = "lucide:chevrons-up-down" })

tab4:Section("Dropdown Tests")

local drop = tab4:Dropdown({
    Name    = "Pick a Color",
    Options = { "Red", "Green", "Blue", "Purple", "Orange" },
    Default = "Red",
    Callback = function(val)
        print("[Test] Dropdown selected:", val)
    end
})

tab4:Button({
    Name     = "Read Dropdown",
    Callback = function()
        print("[Test] Current:", drop:Get())
    end
})

-- ══════════════════════════════════════
-- TAB 5 — INFO
-- ══════════════════════════════════════
local tab5 = Window:Tab({ Name = "Info", Icon = "lucide:info" })

tab5:Section("Live Game Info")

tab5:Button({
    Name     = "Print Player Info",
    Callback = function()
        local p = game.Players.LocalPlayer
        print("[Test] Name:", p.Name)
        print("[Test] UserId:", p.UserId)
        print("[Test] Team:", p.Team and p.Team.Name or "none")
    end
})

tab5:Button({
    Name     = "Print Position",
    Callback = function()
        local char = game.Players.LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local pos = char.HumanoidRootPart.Position
            print(string.format("[Test] Pos: X=%.2f Y=%.2f Z=%.2f", pos.X, pos.Y, pos.Z))
        else
            print("[Test] No character found")
        end
    end
})

tab5:Button({
    Name     = "Print All Players",
    Callback = function()
        print("[Test] Players in server:")
        for _, p in ipairs(game.Players:GetPlayers()) do
            print("  →", p.Name, "| UserId:", p.UserId)
        end
    end
})

tab5:Divider()

tab5:Button({
    Name     = "Run Full Dump",
    Style    = "Primary",
    Callback = function()
        print("══════════════════════════════")
        print("  AirFlow Test Dump")
        print("══════════════════════════════")
        print("PlaceId:", game.PlaceId)
        print("Player:", game.Players.LocalPlayer.Name)
        print("Toggle A:", tog1:Get())
        print("Toggle B:", tog2:Get())
        print("Speed slider:", spd:Get())
        print("Jump slider:", jp:Get())
        print("Dropdown:", drop:Get())
        print("══════════════════════════════")
    end
})

print("[Test] Loaded via loader.lua — AirFlow UI ready")

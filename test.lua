-- test.lua
-- Add to loader.lua: [game.PlaceId] = "test.lua"
-- UI.lua must be live on your repo

local UI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/divso123/script/main/UI.lua"
))()

-- ══════════════════════════════════════
-- WINDOW
-- ══════════════════════════════════════
local win = UI:CreateWindow({
    Title  = "PotatoUI Test",
    Width  = 520,
    Height = 380,
})

-- ══════════════════════════════════════
-- TAB 1 — BUTTONS & TOGGLES
-- ══════════════════════════════════════
local tab1 = win:CreateTab("Buttons")

tab1:CreateLabel("— Button Tests —")

tab1:CreateButton({
    Name     = "Basic Button",
    Callback = function()
        print("[PotatoUI] Basic Button clicked")
    end
})

tab1:CreateButton({
    Name     = "Print Player Name",
    Callback = function()
        print("[PotatoUI] Player:", game.Players.LocalPlayer.Name)
    end
})

tab1:CreateSeparator()
tab1:CreateLabel("— Toggle Tests —")

local tog1 = tab1:CreateToggle({
    Name     = "Toggle A (default OFF)",
    Default  = false,
    Callback = function(state)
        print("[PotatoUI] Toggle A:", state)
    end
})

local tog2 = tab1:CreateToggle({
    Name     = "Toggle B (default ON)",
    Default  = true,
    Callback = function(state)
        print("[PotatoUI] Toggle B:", state)
    end
})

tab1:CreateSeparator()

tab1:CreateButton({
    Name     = "Read Both Toggles",
    Callback = function()
        print("[PotatoUI] Toggle A value:", tog1:GetValue())
        print("[PotatoUI] Toggle B value:", tog2:GetValue())
    end
})

tab1:CreateButton({
    Name     = "Flip Toggle A",
    Callback = function()
        local current = tog1:GetValue()
        tog1:SetValue(not current)
        print("[PotatoUI] Flipped Toggle A to:", not current)
    end
})

-- ══════════════════════════════════════
-- TAB 2 — SLIDERS
-- ══════════════════════════════════════
local tab2 = win:CreateTab("Sliders")

tab2:CreateLabel("— Slider Tests —")

local spd = tab2:CreateSlider({
    Name     = "Walk Speed",
    Min      = 16,
    Max      = 300,
    Default  = 16,
    Callback = function(val)
        print("[PotatoUI] WalkSpeed slider:", val)
        local char = game.Players.LocalPlayer.Character
        if char and char:FindFirstChild("Humanoid") then
            char.Humanoid.WalkSpeed = val
        end
    end
})

local jp = tab2:CreateSlider({
    Name     = "Jump Power",
    Min      = 0,
    Max      = 200,
    Default  = 50,
    Callback = function(val)
        print("[PotatoUI] JumpPower slider:", val)
        local char = game.Players.LocalPlayer.Character
        if char and char:FindFirstChild("Humanoid") then
            char.Humanoid.JumpPower = val
        end
    end
})

tab2:CreateSeparator()

tab2:CreateButton({
    Name     = "Read Slider Values",
    Callback = function()
        print("[PotatoUI] Speed:", spd:GetValue(), "| Jump:", jp:GetValue())
    end
})

tab2:CreateButton({
    Name     = "Reset Sliders",
    Callback = function()
        spd:SetValue(16)
        jp:SetValue(50)
        print("[PotatoUI] Sliders reset")
    end
})

-- ══════════════════════════════════════
-- TAB 3 — DROPDOWN & TEXTBOX
-- ══════════════════════════════════════
local tab3 = win:CreateTab("Input")

tab3:CreateLabel("— Dropdown Tests —")

local drop = tab3:CreateDropdown({
    Name    = "Pick a Color",
    Options = {"Red", "Green", "Blue", "Purple", "Orange"},
    Default = "Red",
    Callback = function(val)
        print("[PotatoUI] Dropdown selected:", val)
    end
})

tab3:CreateButton({
    Name     = "Read Dropdown",
    Callback = function()
        print("[PotatoUI] Current dropdown value:", drop:GetValue())
    end
})

tab3:CreateSeparator()
tab3:CreateLabel("— Textbox Tests —")

local box = tab3:CreateTextbox({
    Name        = "Say Something",
    Placeholder = "type here then press Enter",
    Default     = "",
    Callback    = function(val)
        print("[PotatoUI] Textbox submitted:", val)
    end,
})

tab3:CreateButton({
    Name     = "Read Textbox",
    Callback = function()
        print("[PotatoUI] Textbox value:", box:GetValue())
    end
})

tab3:CreateButton({
    Name     = "Clear Textbox",
    Callback = function()
        box:SetValue("")
        print("[PotatoUI] Textbox cleared")
    end
})

-- ══════════════════════════════════════
-- TAB 4 — LIVE GAME INFO
-- ══════════════════════════════════════
local tab4 = win:CreateTab("Info")

tab4:CreateLabel("— Live Game Info —")

tab4:CreateButton({
    Name     = "Print PlaceId",
    Callback = function()
        print("[PotatoUI] PlaceId:", game.PlaceId)
    end
})

tab4:CreateButton({
    Name     = "Print Player Info",
    Callback = function()
        local p = game.Players.LocalPlayer
        print("[PotatoUI] Name:", p.Name)
        print("[PotatoUI] UserId:", p.UserId)
        print("[PotatoUI] Team:", p.Team and p.Team.Name or "none")
    end
})

tab4:CreateButton({
    Name     = "Print Character Position",
    Callback = function()
        local char = game.Players.LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local pos = char.HumanoidRootPart.Position
            print(string.format("[PotatoUI] Pos: X=%.2f Y=%.2f Z=%.2f", pos.X, pos.Y, pos.Z))
        else
            print("[PotatoUI] No character found")
        end
    end
})

tab4:CreateButton({
    Name     = "Print All Players",
    Callback = function()
        print("[PotatoUI] Players in server:")
        for _, p in ipairs(game.Players:GetPlayers()) do
            print("  →", p.Name, "| UserId:", p.UserId)
        end
    end
})

tab4:CreateSeparator()

tab4:CreateButton({
    Name     = "Run All Tests (console dump)",
    Callback = function()
        print("══════════════════════════════")
        print("  PotatoUI Full Test Dump")
        print("══════════════════════════════")
        print("PlaceId:", game.PlaceId)
        print("Player:", game.Players.LocalPlayer.Name)
        print("Toggle A:", tog1:GetValue())
        print("Toggle B:", tog2:GetValue())
        print("Speed slider:", spd:GetValue())
        print("Jump slider:", jp:GetValue())
        print("Dropdown:", drop:GetValue())
        print("Textbox:", box:GetValue())
        print("══════════════════════════════")
    end
})

print("[PotatoUI] Test script loaded via loader.lua — all tabs ready")

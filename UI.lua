-- PotoatoUI.lua
-- Lua 5.1 / Luau · Roblox Executor environment (Synapse X, KRNL, Fluxus, etc.)
-- Drop this in your executor's workspace or host it on your own GitHub raw URL
-- No HttpGet dependency — this IS the library

local PotatoUI = {}
PotatoUI.__index = PotatoUI

-- ══════════════════════════════════════
-- SERVICES
-- ══════════════════════════════════════
local Players       = game:GetService("Players")
local TweenService  = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService    = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Mouse       = LocalPlayer:GetMouse()

-- ══════════════════════════════════════
-- THEME
-- ══════════════════════════════════════
local Theme = {
    Background   = Color3.fromRGB(20, 20, 28),
    TopBar       = Color3.fromRGB(30, 30, 42),
    Accent       = Color3.fromRGB(120, 80, 220),
    AccentHover  = Color3.fromRGB(140, 100, 240),
    Tab          = Color3.fromRGB(35, 35, 50),
    TabActive    = Color3.fromRGB(50, 50, 72),
    Element      = Color3.fromRGB(28, 28, 40),
    ElementHover = Color3.fromRGB(38, 38, 55),
    TextPrimary  = Color3.fromRGB(230, 230, 240),
    TextSub      = Color3.fromRGB(140, 140, 160),
    Toggle_ON    = Color3.fromRGB(100, 200, 130),
    Toggle_OFF   = Color3.fromRGB(60, 60, 80),
    Slider_Fill  = Color3.fromRGB(120, 80, 220),
    Slider_Track = Color3.fromRGB(40, 40, 58),
    Border       = Color3.fromRGB(55, 55, 78),
    Shadow       = Color3.fromRGB(10, 10, 16),
}

-- ══════════════════════════════════════
-- INTERNAL HELPERS
-- ══════════════════════════════════════
local function tween(obj, props, t, style, dir)
    style = style or Enum.EasingStyle.Quad
    dir   = dir   or Enum.EasingDirection.Out
    TweenService:Create(obj, TweenInfo.new(t or 0.15, style, dir), props):Play()
end

local function makeFrame(parent, size, pos, color, zindex)
    local f = Instance.new("Frame")
    f.Size            = size
    f.Position        = pos
    f.BackgroundColor3 = color
    f.BorderSizePixel = 0
    f.ZIndex          = zindex or 1
    f.Parent          = parent
    return f
end

local function makeLabel(parent, text, size, pos, color, fontsize, zindex)
    local l = Instance.new("TextLabel")
    l.Size               = size
    l.Position           = pos
    l.BackgroundTransparency = 1
    l.Text               = text
    l.TextColor3         = color or Theme.TextPrimary
    l.TextSize           = fontsize or 14
    l.Font               = Enum.Font.GothamMedium
    l.TextXAlignment     = Enum.TextXAlignment.Left
    l.ZIndex             = zindex or 2
    l.Parent             = parent
    return l
end

local function makeButton(parent, size, pos, color, zindex)
    local b = Instance.new("TextButton")
    b.Size              = size
    b.Position          = pos
    b.BackgroundColor3  = color
    b.BorderSizePixel   = 0
    b.Text              = ""
    b.AutoButtonColor   = false
    b.ZIndex            = zindex or 2
    b.Parent            = parent
    return b
end

local function corner(obj, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 6)
    c.Parent = obj
    return c
end

local function stroke(obj, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color     = color or Theme.Border
    s.Thickness = thickness or 1
    s.Parent    = obj
    return s
end

-- drag logic for window
local function makeDraggable(topbar, frame)
    local dragging, dragStart, startPos = false, nil, nil
    topbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = input.Position
            startPos  = frame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

-- ══════════════════════════════════════
-- WINDOW
-- ══════════════════════════════════════
function PotatoUI:CreateWindow(config)
    config = config or {}
    local title  = config.Title  or "PotatoUI"
    local width  = config.Width  or 520
    local height = config.Height or 380

    -- ScreenGui
    local gui = Instance.new("ScreenGui")
    gui.Name              = "PotatoUI_" .. title
    gui.ResetOnSpawn      = false
    gui.ZIndexBehavior    = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset    = true
    -- executor env: use gethui() if available, else PlayerGui
    gui.Parent = (syn and syn.protect_gui and syn.protect_gui(gui)) and gethui and gethui()
        or (gethui and gethui())
        or LocalPlayer:WaitForChild("PlayerGui")

    -- main frame
    local main = makeFrame(
        gui,
        UDim2.new(0, width, 0, height),
        UDim2.new(0.5, -width/2, 0.5, -height/2),
        Theme.Background,
        1
    )
    corner(main, 10)
    stroke(main, Theme.Border, 1)

    -- shadow
    local shadow = makeFrame(gui,
        UDim2.new(0, width + 20, 0, height + 20),
        UDim2.new(0.5, -(width+20)/2, 0.5, -(height+20)/2),
        Theme.Shadow, 0)
    corner(shadow, 14)
    shadow.BackgroundTransparency = 0.5

    -- topbar
    local topbar = makeFrame(main,
        UDim2.new(1, 0, 0, 40),
        UDim2.new(0, 0, 0, 0),
        Theme.TopBar, 2)
    corner(topbar, 10)

    -- cover bottom corners of topbar
    makeFrame(topbar, UDim2.new(1, 0, 0, 10),
        UDim2.new(0,0,1,-10), Theme.TopBar, 1)

    -- title label
    makeLabel(topbar, "  " .. title,
        UDim2.new(1,-80,1,0), UDim2.new(0,0,0,0),
        Theme.TextPrimary, 15, 3)

    -- accent line under topbar
    local accentLine = makeFrame(main,
        UDim2.new(1,0,0,2),
        UDim2.new(0,0,0,40),
        Theme.Accent, 2)

    -- close button
    local closeBtn = makeButton(topbar,
        UDim2.new(0,30,0,30),
        UDim2.new(1,-36,0,5),
        Theme.Element, 4)
    corner(closeBtn, 6)
    local closeLabel = Instance.new("TextLabel")
    closeLabel.Size = UDim2.new(1,0,1,0)
    closeLabel.BackgroundTransparency = 1
    closeLabel.Text = "✕"
    closeLabel.TextColor3 = Theme.TextSub
    closeLabel.TextSize = 14
    closeLabel.Font = Enum.Font.GothamBold
    closeLabel.ZIndex = 5
    closeLabel.Parent = closeBtn
    closeBtn.MouseButton1Click:Connect(function()
        tween(main, {Size = UDim2.new(0,width,0,0)}, 0.2)
        task.wait(0.21)
        gui:Destroy()
    end)
    closeBtn.MouseEnter:Connect(function()
        tween(closeBtn, {BackgroundColor3 = Color3.fromRGB(200,60,60)}, 0.1)
    end)
    closeBtn.MouseLeave:Connect(function()
        tween(closeBtn, {BackgroundColor3 = Theme.Element}, 0.1)
    end)

    -- minimize button
    local minBtn = makeButton(topbar,
        UDim2.new(0,30,0,30),
        UDim2.new(1,-70,0,5),
        Theme.Element, 4)
    corner(minBtn, 6)
    local minLabel = Instance.new("TextLabel")
    minLabel.Size = UDim2.new(1,0,1,0)
    minLabel.BackgroundTransparency = 1
    minLabel.Text = "–"
    minLabel.TextColor3 = Theme.TextSub
    minLabel.TextSize = 16
    minLabel.Font = Enum.Font.GothamBold
    minLabel.ZIndex = 5
    minLabel.Parent = minBtn
    local minimized = false
    minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        tween(main, {Size = minimized
            and UDim2.new(0,width,0,42)
            or  UDim2.new(0,width,0,height)}, 0.2)
    end)

    makeDraggable(topbar, main)

    -- tab bar
    local tabBar = makeFrame(main,
        UDim2.new(0, 120, 1, -44),
        UDim2.new(0, 0, 0, 42),
        Theme.Tab, 2)
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.Padding = UDim.new(0, 4)
    tabLayout.Parent  = tabBar
    local tabPad = Instance.new("UIPadding")
    tabPad.PaddingTop   = UDim.new(0,8)
    tabPad.PaddingLeft  = UDim.new(0,6)
    tabPad.PaddingRight = UDim.new(0,6)
    tabPad.Parent = tabBar

    -- content area
    local contentArea = makeFrame(main,
        UDim2.new(1,-124,1,-44),
        UDim2.new(0,122,0,44),
        Theme.Background, 2)

    -- divider between tabBar and content
    makeFrame(main, UDim2.new(0,1,1,-44), UDim2.new(0,120,0,42), Theme.Border, 3)

    local Window  = {}
    local tabs    = {}
    local activeTab = nil

    -- ══════════════════════════════════
    -- TAB
    -- ══════════════════════════════════
    function Window:CreateTab(name)
        -- tab button
        local tabBtn = makeButton(tabBar,
            UDim2.new(1,0,0,32),
            UDim2.new(0,0,0,0),
            Theme.Tab, 3)
        corner(tabBtn, 6)
        makeLabel(tabBtn, "  " .. name,
            UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
            Theme.TextSub, 13, 4)

        -- tab content scroll
        local scroll = Instance.new("ScrollingFrame")
        scroll.Size              = UDim2.new(1,0,1,0)
        scroll.Position          = UDim2.new(0,0,0,0)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel   = 0
        scroll.ScrollBarThickness = 3
        scroll.ScrollBarImageColor3 = Theme.Accent
        scroll.CanvasSize        = UDim2.new(0,0,0,0)
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.Visible           = false
        scroll.ZIndex            = 3
        scroll.Parent            = contentArea
        local listLayout = Instance.new("UIListLayout")
        listLayout.Padding       = UDim.new(0,6)
        listLayout.Parent        = scroll
        local pad = Instance.new("UIPadding")
        pad.PaddingTop   = UDim.new(0,8)
        pad.PaddingLeft  = UDim.new(0,8)
        pad.PaddingRight = UDim.new(0,8)
        pad.Parent       = scroll

        local Tab = { _scroll = scroll, _btn = tabBtn }

        local function activate()
            for _, t in ipairs(tabs) do
                t._scroll.Visible = false
                tween(t._btn, {BackgroundColor3 = Theme.Tab}, 0.1)
            end
            scroll.Visible = true
            tween(tabBtn, {BackgroundColor3 = Theme.TabActive}, 0.1)
            activeTab = Tab
        end

        tabBtn.MouseButton1Click:Connect(activate)
        tabBtn.MouseEnter:Connect(function()
            if activeTab ~= Tab then
                tween(tabBtn, {BackgroundColor3 = Theme.ElementHover}, 0.1)
            end
        end)
        tabBtn.MouseLeave:Connect(function()
            if activeTab ~= Tab then
                tween(tabBtn, {BackgroundColor3 = Theme.Tab}, 0.1)
            end
        end)

        table.insert(tabs, Tab)
        if #tabs == 1 then activate() end  -- first tab auto-selected

        -- ════════════════════════════
        -- LABEL
        -- ════════════════════════════
        function Tab:CreateLabel(text)
            local row = makeFrame(scroll,
                UDim2.new(1,-16,0,28),
                UDim2.new(0,0,0,0),
                Color3.fromRGB(0,0,0), 4)
            row.BackgroundTransparency = 1
            makeLabel(row, text,
                UDim2.new(1,0,1,0), UDim2.new(0,4,0,0),
                Theme.TextSub, 13, 5)
        end

        -- ════════════════════════════
        -- BUTTON
        -- ════════════════════════════
        function Tab:CreateButton(config)
            config = config or {}
            local row = makeFrame(scroll,
                UDim2.new(1,-16,0,36),
                UDim2.new(0,0,0,0),
                Theme.Element, 4)
            corner(row, 6)
            stroke(row, Theme.Border, 1)
            makeLabel(row, config.Name or "Button",
                UDim2.new(1,-10,1,0), UDim2.new(0,10,0,0),
                Theme.TextPrimary, 13, 5)
            local hit = makeButton(row,
                UDim2.new(1,0,1,0),
                UDim2.new(0,0,0,0),
                Color3.new(), 5)
            hit.BackgroundTransparency = 1
            hit.MouseButton1Click:Connect(function()
                tween(row, {BackgroundColor3 = Theme.Accent}, 0.08)
                task.wait(0.12)
                tween(row, {BackgroundColor3 = Theme.Element}, 0.12)
                if config.Callback then config.Callback() end
            end)
            hit.MouseEnter:Connect(function()
                tween(row, {BackgroundColor3 = Theme.ElementHover}, 0.1)
            end)
            hit.MouseLeave:Connect(function()
                tween(row, {BackgroundColor3 = Theme.Element}, 0.1)
            end)
        end

        -- ════════════════════════════
        -- TOGGLE
        -- ════════════════════════════
        function Tab:CreateToggle(config)
            config = config or {}
            local state = config.Default or false
            local row = makeFrame(scroll,
                UDim2.new(1,-16,0,36),
                UDim2.new(0,0,0,0),
                Theme.Element, 4)
            corner(row, 6)
            stroke(row, Theme.Border, 1)
            makeLabel(row, config.Name or "Toggle",
                UDim2.new(1,-60,1,0), UDim2.new(0,10,0,0),
                Theme.TextPrimary, 13, 5)

            -- track
            local track = makeFrame(row,
                UDim2.new(0,42,0,22),
                UDim2.new(1,-52,0.5,-11),
                state and Theme.Toggle_ON or Theme.Toggle_OFF, 5)
            corner(track, 11)

            -- knob
            local knob = makeFrame(track,
                UDim2.new(0,16,0,16),
                UDim2.new(0, state and 22 or 4, 0.5, -8),
                Color3.fromRGB(240,240,240), 6)
            corner(knob, 8)

            local function setToggle(val)
                state = val
                tween(track, {BackgroundColor3 = state and Theme.Toggle_ON or Theme.Toggle_OFF}, 0.15)
                tween(knob,  {Position = UDim2.new(0, state and 22 or 4, 0.5, -8)}, 0.15)
                if config.Callback then config.Callback(state) end
            end

            local hit = makeButton(row, UDim2.new(1,0,1,0),
                UDim2.new(0,0,0,0), Color3.new(), 6)
            hit.BackgroundTransparency = 1
            hit.MouseButton1Click:Connect(function()
                setToggle(not state)
            end)

            return { SetValue = setToggle, GetValue = function() return state end }
        end

        -- ════════════════════════════
        -- SLIDER
        -- ════════════════════════════
        function Tab:CreateSlider(config)
            config = config or {}
            local min     = config.Min     or 0
            local max     = config.Max     or 100
            local default = config.Default or min
            local current = default

            local row = makeFrame(scroll,
                UDim2.new(1,-16,0,52),
                UDim2.new(0,0,0,0),
                Theme.Element, 4)
            corner(row, 6)
            stroke(row, Theme.Border, 1)

            local nameLabel = makeLabel(row,
                config.Name or "Slider",
                UDim2.new(1,-60,0,20), UDim2.new(0,10,0,6),
                Theme.TextPrimary, 13, 5)
            local valLabel = makeLabel(row,
                tostring(current),
                UDim2.new(0,50,0,20), UDim2.new(1,-58,0,6),
                Theme.TextSub, 13, 5)
            valLabel.TextXAlignment = Enum.TextXAlignment.Right

            local track = makeFrame(row,
                UDim2.new(1,-20,0,6),
                UDim2.new(0,10,1,-16),
                Theme.Slider_Track, 5)
            corner(track, 3)

            local fill = makeFrame(track,
                UDim2.new((current-min)/(max-min),0,1,0),
                UDim2.new(0,0,0,0),
                Theme.Slider_Fill, 6)
            corner(fill, 3)

            local knob = makeFrame(track,
                UDim2.new(0,14,0,14),
                UDim2.new((current-min)/(max-min),0,0.5,-7),
                Color3.fromRGB(240,240,240), 7)
            corner(knob, 7)
            stroke(knob, Theme.Accent, 2)

            local sliding = false
            local function updateSlider(inputX)
                local trackAbs = track.AbsolutePosition.X
                local trackW   = track.AbsoluteSize.X
                local pct      = math.clamp((inputX - trackAbs) / trackW, 0, 1)
                current        = math.floor(min + pct * (max - min) + 0.5)
                pct            = (current - min) / (max - min)
                tween(fill,  {Size     = UDim2.new(pct, 0, 1, 0)}, 0.05)
                tween(knob,  {Position = UDim2.new(pct, 0, 0.5, -7)}, 0.05)
                valLabel.Text = tostring(current)
                if config.Callback then config.Callback(current) end
            end

            local hitBtn = makeButton(track,
                UDim2.new(1,0,0,20), UDim2.new(0,0,0.5,-10),
                Color3.new(), 8)
            hitBtn.BackgroundTransparency = 1
            hitBtn.MouseButton1Down:Connect(function()
                sliding = true
                updateSlider(Mouse.X)
            end)
            UserInputService.InputChanged:Connect(function(input)
                if sliding and input.UserInputType == Enum.UserInputType.MouseMovement then
                    updateSlider(Mouse.X)
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    sliding = false
                end
            end)

            return {
                SetValue = function(val)
                    current = math.clamp(val, min, max)
                    local pct = (current-min)/(max-min)
                    tween(fill,  {Size     = UDim2.new(pct,0,1,0)}, 0.1)
                    tween(knob,  {Position = UDim2.new(pct,0,0.5,-7)}, 0.1)
                    valLabel.Text = tostring(current)
                end,
                GetValue = function() return current end
            }
        end

        -- ════════════════════════════
        -- DROPDOWN
        -- ════════════════════════════
        function Tab:CreateDropdown(config)
            config = config or {}
            local options  = config.Options  or {}
            local selected = config.Default  or options[1] or "Select..."
            local open     = false

            local row = makeFrame(scroll,
                UDim2.new(1,-16,0,36),
                UDim2.new(0,0,0,0),
                Theme.Element, 4)
            corner(row, 6)
            stroke(row, Theme.Border, 1)

            makeLabel(row, config.Name or "Dropdown",
                UDim2.new(0.5,0,1,0), UDim2.new(0,10,0,0),
                Theme.TextPrimary, 13, 5)

            local selLabel = makeLabel(row, selected,
                UDim2.new(0.4,0,1,0), UDim2.new(0.52,0,0,0),
                Theme.TextSub, 12, 5)
            selLabel.TextXAlignment = Enum.TextXAlignment.Right

            local arrow = makeLabel(row, "▾",
                UDim2.new(0,20,1,0), UDim2.new(1,-24,0,0),
                Theme.TextSub, 14, 5)
            arrow.TextXAlignment = Enum.TextXAlignment.Center

            -- dropdown list (absolute, overlays siblings)
            local listFrame = makeFrame(row,
                UDim2.new(1,0,0,0),
                UDim2.new(0,0,1,2),
                Theme.Tab, 10)
            corner(listFrame, 6)
            stroke(listFrame, Theme.Border, 1)
            listFrame.Visible       = false
            listFrame.ClipsDescendants = true

            local listLayout2 = Instance.new("UIListLayout")
            listLayout2.Parent  = listFrame
            listLayout2.Padding = UDim.new(0,2)
            local lpad = Instance.new("UIPadding")
            lpad.PaddingTop   = UDim.new(0,4)
            lpad.PaddingLeft  = UDim.new(0,4)
            lpad.PaddingRight = UDim.new(0,4)
            lpad.PaddingBottom = UDim.new(0,4)
            lpad.Parent = listFrame

            for _, opt in ipairs(options) do
                local optBtn = makeButton(listFrame,
                    UDim2.new(1,0,0,28),
                    UDim2.new(0,0,0,0),
                    Theme.Element, 11)
                corner(optBtn, 4)
                makeLabel(optBtn, "  " .. tostring(opt),
                    UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
                    Theme.TextPrimary, 12, 12)
                optBtn.MouseButton1Click:Connect(function()
                    selected      = tostring(opt)
                    selLabel.Text = selected
                    open          = false
                    listFrame.Visible = false
                    tween(listFrame, {Size = UDim2.new(1,0,0,0)}, 0.15)
                    if config.Callback then config.Callback(selected) end
                end)
                optBtn.MouseEnter:Connect(function()
                    tween(optBtn, {BackgroundColor3 = Theme.ElementHover}, 0.08)
                end)
                optBtn.MouseLeave:Connect(function()
                    tween(optBtn, {BackgroundColor3 = Theme.Element}, 0.08)
                end)
            end

            local listH = (#options * 30) + 8
            local hitBtn = makeButton(row, UDim2.new(1,0,1,0),
                UDim2.new(0,0,0,0), Color3.new(), 6)
            hitBtn.BackgroundTransparency = 1
            hitBtn.MouseButton1Click:Connect(function()
                open = not open
                listFrame.Visible = open
                tween(listFrame, {Size = open
                    and UDim2.new(1,0,0,listH)
                    or  UDim2.new(1,0,0,0)}, 0.15)
            end)

            return {
                SetValue = function(val) selected = val; selLabel.Text = val end,
                GetValue = function() return selected end,
                Refresh  = function(newOpts)
                    -- rebuild options list
                    for _, c in ipairs(listFrame:GetChildren()) do
                        if c:IsA("TextButton") then c:Destroy() end
                    end
                    options = newOpts
                    for _, opt in ipairs(options) do
                        -- same optBtn build as above
                    end
                end
            }
        end

        -- ════════════════════════════
        -- TEXTBOX
        -- ════════════════════════════
        function Tab:CreateTextbox(config)
            config = config or {}
            local row = makeFrame(scroll,
                UDim2.new(1,-16,0,36),
                UDim2.new(0,0,0,0),
                Theme.Element, 4)
            corner(row, 6)
            stroke(row, Theme.Border, 1)
            makeLabel(row, config.Name or "Input",
                UDim2.new(0.4,0,1,0), UDim2.new(0,10,0,0),
                Theme.TextPrimary, 13, 5)

            local box = Instance.new("TextBox")
            box.Size             = UDim2.new(0.52,0,0,24)
            box.Position         = UDim2.new(0.44,0,0.5,-12)
            box.BackgroundColor3 = Theme.Tab
            box.TextColor3       = Theme.TextPrimary
            box.PlaceholderText  = config.Placeholder or "..."
            box.PlaceholderColor3 = Theme.TextSub
            box.TextSize         = 13
            box.Font             = Enum.Font.GothamMedium
            box.Text             = config.Default or ""
            box.ClearTextOnFocus = config.ClearOnFocus ~= false
            box.BorderSizePixel  = 0
            box.ZIndex           = 5
            box.Parent           = row
            corner(box, 4)
            stroke(box, Theme.Border, 1)

            box.FocusLost:Connect(function(enter)
                if enter and config.Callback then
                    config.Callback(box.Text)
                end
            end)
            if config.ChangedCallback then
                box:GetPropertyChangedSignal("Text"):Connect(function()
                    config.ChangedCallback(box.Text)
                end)
            end

            return {
                GetValue = function() return box.Text end,
                SetValue = function(v) box.Text = v end
            }
        end

        -- ════════════════════════════
        -- SEPARATOR
        -- ════════════════════════════
        function Tab:CreateSeparator()
            makeFrame(scroll,
                UDim2.new(1,-16,0,1),
                UDim2.new(0,0,0,0),
                Theme.Border, 5)
        end

        return Tab
    end

    return Window
end

return PotatoUI

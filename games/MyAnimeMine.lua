-- mutation-roller.lua
-- Mutation Roller | DivineSoul Hub | AirFlow UI port

local BASE = "https://raw.githubusercontent.com/divso123/script/main/"
local UI   = loadstring(game:HttpGet(BASE .. "UI.lua"))()

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer      = Players.LocalPlayer

-- ── Remote ───────────────────────────────────────────────────────────────────
local GamestateEvent = ReplicatedStorage
    :WaitForChild("Remotes")
    :WaitForChild("GamestateEvent")

-- ── Settings ──────────────────────────────────────────────────────────────────
local MUTATIONS = {
    "Bronze", "Diamond", "Platinum", "Rainbow",
    "Frozen", "Inferno", "Nightmare", "Unreal",
}
local SLOTS = {
    "M1","M2","M3","M4","M5","M6",
    "M7","M8","M9","M10","M11","M12",
}

-- ── State ─────────────────────────────────────────────────────────────────────
local rollDelay    = 0.1
local autoRolling  = false
local lastVariant  = nil
local StatusLabel  -- forward
local VariantLabel -- forward

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function log(msg)
    print(("[%s] [MutRoller] %s"):format(os.date("%H:%M:%S"), tostring(msg)))
end

local function findMyPlot()
    local mineWorld = workspace:FindFirstChild("MineWorld")
    if not mineWorld then return nil end
    local plots = mineWorld:FindFirstChild("Plots")
    if not plots then return nil end
    for _, plot in ipairs(plots:GetChildren()) do
        local id = plot:GetAttribute("OwnerUserId")
        if id and tonumber(id) == LocalPlayer.UserId then
            return plot
        end
    end
    return nil
end

local function getCrew(slot)
    local plot = findMyPlot()
    if not plot then return nil end
    local crewFolder = plot:FindFirstChild("Crew")
    if not crewFolder then return nil end
    return crewFolder:FindFirstChild("Crew_" .. slot)
end

local function getVariant(slot)
    local crew = getCrew(slot)
    if not crew then return "N/A" end
    local v = crew:GetAttribute("Variant")
    return v ~= nil and tostring(v) or "None"
end

-- ── Window ────────────────────────────────────────────────────────────────────
local Window = UI:Window({
    Title    = "DivineSoul",
    SubTitle = "Mutation Roller",
    Theme    = "Midnight",
})

-- ── Tab: Roll ─────────────────────────────────────────────────────────────────
local RollTab = Window:Tab({ Title = "Roll", Icon = "zap" })

RollTab:Section("Target Slot")

RollTab:Dropdown({
    Name    = "Slot",
    Desc    = "Which crew slot to roll mutations on",
    Options = SLOTS,
    Default = "M1",
    Flag    = "TargetSlot",
    Callback = function(val)
        log("SLOT: " .. val)
    end,
})

RollTab:Section("Target Mutations")

RollTab:Dropdown({
    Name        = "Mutations",
    Desc        = "Stop rolling when one of these is rolled",
    Options     = MUTATIONS,
    Default     = "Unreal",
    Multi       = true,
    Flag        = "TargetMutations",
    Callback    = function(val)
        log("MUTATIONS updated")
    end,
})

RollTab:Section("Settings")

RollTab:Slider({
    Name     = "Roll Delay",
    Desc     = "Seconds between each roll attempt",
    Min      = 0,
    Max      = 2,
    Step     = 0.05,
    Default  = 0.1,
    Suffix   = "s",
    Flag     = "RollDelay",
    Callback = function(val)
        rollDelay = val
        log("DELAY: " .. val)
    end,
})

RollTab:Section("Status")

VariantLabel = RollTab:Label({ Text = "Current Variant: —" })
StatusLabel  = RollTab:Label({ Text = "Ready." })

RollTab:Section("Control")

RollTab:Button({
    Name     = "Start Auto Roll",
    Desc     = "Rolls the selected slot until a target mutation appears",
    Callback = function()
        if autoRolling then
            log("Already rolling.")
            return
        end

        -- read flags
        local slot = (UI.Flags and UI.Flags.TargetSlot) or "M1"
        local mutFlags = UI.Flags and UI.Flags.TargetMutations
        local targetMuts = {}
        if type(mutFlags) == "table" then
            for k, v in pairs(mutFlags) do
                if v then targetMuts[k] = true end
            end
        elseif type(mutFlags) == "string" and mutFlags ~= "" then
            targetMuts[mutFlags] = true
        else
            targetMuts["Unreal"] = true
        end

        local delay = (UI.Flags and UI.Flags.RollDelay) or rollDelay

        -- validate
        local hasTarget = next(targetMuts) ~= nil
        if not hasTarget then
            if StatusLabel then StatusLabel:Set("Select at least one mutation.") end
            log("FAIL: no target mutation selected")
            return
        end

        local plot = findMyPlot()
        if not plot then
            if StatusLabel then StatusLabel:Set("Mine plot not found.") end
            log("FAIL: no plot")
            return
        end

        local crew = getCrew(slot)
        if not crew then
            if StatusLabel then StatusLabel:Set(slot .. " not found.") end
            log("FAIL: crew not found for " .. slot)
            return
        end

        autoRolling = true
        lastVariant = crew:GetAttribute("Variant")

        if StatusLabel  then StatusLabel:Set("Rolling " .. slot .. "…") end
        if VariantLabel then VariantLabel:Set("Current Variant: " .. tostring(lastVariant or "None")) end
        log("START | Slot: " .. slot .. " | Delay: " .. delay)

        task.spawn(function()
            while autoRolling do
                local currentCrew = getCrew(slot)
                if not currentCrew then
                    autoRolling = false
                    if StatusLabel then StatusLabel:Set(slot .. " disappeared.") end
                    log("STOP: crew disappeared")
                    break
                end

                local beforeVariant = currentCrew:GetAttribute("Variant")
                if VariantLabel then
                    VariantLabel:Set("Current Variant: " .. tostring(beforeVariant or "None"))
                end

                -- set up detector before firing
                local result = nil
                local detected = false
                local conn
                conn = currentCrew:GetAttributeChangedSignal("Variant"):Connect(function()
                    local v = currentCrew:GetAttribute("Variant")
                    if v ~= nil and tostring(v) ~= tostring(beforeVariant) then
                        result = tostring(v)
                        detected = true
                    end
                end)

                -- fire roll
                GamestateEvent:FireServer("MineRollMutation", slot)

                -- wait for attribute change
                local timeout = math.max(delay * 3, 1)
                local t0 = os.clock()
                while autoRolling and not detected and os.clock() - t0 < timeout do
                    local cur = currentCrew:GetAttribute("Variant")
                    if cur ~= nil and tostring(cur) ~= tostring(beforeVariant) then
                        result = tostring(cur)
                        detected = true
                        break
                    end
                    task.wait()
                end
                if conn then conn:Disconnect() end

                if not autoRolling then break end

                if result ~= nil then
                    lastVariant = result
                    if VariantLabel then VariantLabel:Set("Current Variant: " .. result) end
                    if StatusLabel  then StatusLabel:Set("Rolled: " .. result) end
                    log("ROLLED: " .. result)

                    -- check target
                    if targetMuts[result] then
                        autoRolling = false
                        if StatusLabel then StatusLabel:Set("TARGET FOUND: " .. result .. " ✓") end
                        log("TARGET FOUND: " .. result)
                        break
                    end
                else
                    local cur = tostring(currentCrew:GetAttribute("Variant") or "None")
                    if VariantLabel then VariantLabel:Set("Current Variant: " .. cur) end
                    if StatusLabel  then StatusLabel:Set("No change detected.") end
                end

                if autoRolling then task.wait(delay) end
            end
        end)
    end,
})

RollTab:Button({
    Name     = "Stop",
    Desc     = "Stop the auto roll loop",
    Callback = function()
        if not autoRolling then
            if StatusLabel then StatusLabel:Set("Not rolling.") end
            return
        end
        autoRolling = false
        if StatusLabel then StatusLabel:Set("Stopped.") end
        log("STOPPED manually")
    end,
})

-- ── Tab: Info ─────────────────────────────────────────────────────────────────
local InfoTab = Window:Tab({ Title = "Info", Icon = "info" })
InfoTab:Section("How to use")
InfoTab:Paragraph({
    Name    = "Guide",
    Content = "1. Pick your target slot (M1–M12)\n2. Pick one or more target mutations\n3. Adjust roll delay if needed\n4. Hit Start Auto Roll\n5. It stops automatically when a target mutation drops",
})
InfoTab:Section("Notes")
InfoTab:Paragraph({
    Name    = "Notes",
    Content = "Fires GamestateEvent → MineRollMutation each loop. Uses attribute-change signals so detection is near-instant. Export to file unavailable here — check console logs for a full roll history.",
})

-- ── Init ──────────────────────────────────────────────────────────────────────
log("========================================")
log("MUTATION ROLLER LOADED (DivineSoul Hub)")
log("SLOT: M1 | DELAY: " .. rollDelay)
log("========================================")

-- live variant poll
task.spawn(function()
    while true do
        if not autoRolling then
            local slot = (UI.Flags and UI.Flags.TargetSlot) or "M1"
            local v = getVariant(slot)
            if VariantLabel then
                VariantLabel:Set("Current Variant: " .. v)
            end
        end
        task.wait(0.2)
    end
end)

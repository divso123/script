-- mutation-roller.lua
-- Mutation Roller + Auto Upgrader | DivineSoul Hub | AirFlow UI port

local BASE = "https://raw.githubusercontent.com/divso123/script/main/"
local UI   = loadstring(game:HttpGet(BASE .. "UI.lua"))()

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local LocalPlayer       = Players.LocalPlayer

-- ── Remote ────────────────────────────────────────────────────────────────────
local GamestateEvent = ReplicatedStorage
    :WaitForChild("Remotes")
    :WaitForChild("GamestateEvent")

-- ── Constants ─────────────────────────────────────────────────────────────────
local MUTATIONS = {
    "Bronze", "Diamond", "Platinum", "Rainbow",
    "Frozen", "Inferno", "Nightmare", "Unreal",
}
local SLOTS = {
    "M1","M2","M3","M4","M5","M6",
    "M7","M8","M9","M10","M11","M12",
}
local UPGRADE_TYPES = { "Speed", "MineSpeed", "Damage" }

-- ── State: Roll ───────────────────────────────────────────────────────────────
local rollDelay    = 0.1
local selectedSlot = "M1"
local autoRolling  = false
local lastVariant  = nil
local StatusLabel  -- forward
local VariantLabel -- forward

-- ── State: Upgrade ────────────────────────────────────────────────────────────
local upgradeDelay    = 0.1
local autoUpgrading   = false
local upgradeSlots    = { M1=true }  -- default all-slots or per-slot toggle
local upgradeTypes    = { Speed=true, MineSpeed=true, Damage=true }
local UpgradeStatus   -- forward

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function log(msg)
    print(("[%s] [DivineSoul] %s"):format(os.date("%H:%M:%S"), tostring(msg)))
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

-- Display_M1 etc. also carry Variant — check both in case one updates faster
local function getDisplay(slot)
    local plot = findMyPlot()
    if not plot then return nil end
    local crewFolder = plot:FindFirstChild("Crew")
    if not crewFolder then return nil end
    return crewFolder:FindFirstChild("Display_" .. slot)
end

local function getVariant(slot)
    local crew = getCrew(slot)
    if crew then
        local v = crew:GetAttribute("Variant")
        if v ~= nil then return tostring(v) end
    end
    local disp = getDisplay(slot)
    if disp then
        local v = disp:GetAttribute("Variant")
        if v ~= nil then return tostring(v) end
    end
    return "N/A"
end

-- ── Window ────────────────────────────────────────────────────────────────────
local Window = UI:Window({
    Title    = "DivineSoul",
    SubTitle = "Mine Tools",
    Theme    = "Midnight",
})

-- ═════════════════════════════════════════════════════════════════════════════
-- TAB: ROLL
-- ═════════════════════════════════════════════════════════════════════════════
local RollTab = Window:Tab({ Title = "Roll", Icon = "zap" })

RollTab:Section("Target Slot")

RollTab:Dropdown({
    Name     = "Slot",
    Desc     = "Which crew slot to roll mutations on",
    Options  = SLOTS,
    Default  = "M1",
    Flag     = "TargetSlot",
    Callback = function(val)
        selectedSlot = val
        log("ROLL SLOT: " .. val)
        if VariantLabel then
            VariantLabel:Set("Current Variant: " .. getVariant(val))
        end
    end,
})

RollTab:Section("Target Mutations")

RollTab:Dropdown({
    Name     = "Mutations",
    Desc     = "Stop rolling when one of these is rolled",
    Options  = MUTATIONS,
    Default  = "Unreal",
    Multi    = true,
    Flag     = "TargetMutations",
    Callback = function(_) log("MUTATIONS updated") end,
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
        log("ROLL DELAY: " .. val)
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
        if autoRolling then return end

        local slot     = selectedSlot
        local mutFlags = UI.Flags and UI.Flags.TargetMutations
        local targetMuts = {}
        if type(mutFlags) == "table" then
            for k, v in pairs(mutFlags) do if v then targetMuts[k] = true end end
        elseif type(mutFlags) == "string" and mutFlags ~= "" then
            targetMuts[mutFlags] = true
        else
            targetMuts["Unreal"] = true
        end

        local delay = (UI.Flags and UI.Flags.RollDelay) or rollDelay

        if not next(targetMuts) then
            if StatusLabel then StatusLabel:Set("Select at least one mutation.") end
            return
        end
        if not findMyPlot() then
            if StatusLabel then StatusLabel:Set("Mine plot not found.") end
            return
        end
        local crew = getCrew(slot)
        if not crew then
            if StatusLabel then StatusLabel:Set(slot .. " not found.") end
            return
        end

        autoRolling = true
        lastVariant = crew:GetAttribute("Variant")
        if StatusLabel  then StatusLabel:Set("Rolling " .. slot .. "…") end
        if VariantLabel then VariantLabel:Set("Current Variant: " .. tostring(lastVariant or "None")) end
        log("ROLL START | " .. slot)

        -- Heartbeat state machine — Delta mobile safe (no task.spawn loop)
        -- States: "fire" → "poll" → "wait" → "fire" …
        local hbState      = "fire"
        local hbBefore     = "N/A"
        local hbT0         = 0
        local hbWaitT0     = 0
        local rollCount    = 0
        local hbConn

        hbConn = RunService.Heartbeat:Connect(function()
            if not autoRolling then
                hbConn:Disconnect()
                return
            end

            if hbState == "fire" then
                rollCount += 1
                log("ROLL ITER #" .. rollCount)
                hbBefore = getVariant(slot)
                GamestateEvent:FireServer("MineRollMutation", slot)
                hbT0    = os.clock()
                hbState = "poll"

            elseif hbState == "poll" then
                local cur = getVariant(slot)
                if cur ~= "N/A" and cur ~= hbBefore then
                    -- variant changed
                    if VariantLabel then VariantLabel:Set("Current Variant: " .. cur) end
                    lastVariant = cur
                    if StatusLabel then StatusLabel:Set("Rolled: " .. cur .. " (#" .. rollCount .. ")") end
                    log("ROLLED: " .. cur)
                    if targetMuts[cur] then
                        autoRolling = false
                        hbConn:Disconnect()
                        if StatusLabel then StatusLabel:Set("TARGET FOUND: " .. cur .. " ✓") end
                        log("TARGET FOUND: " .. cur)
                        return
                    end
                    hbWaitT0 = os.clock()
                    hbState  = "wait"
                elseif os.clock() - hbT0 > 1.5 then
                    -- timed out waiting for change
                    local cur2 = getVariant(slot)
                    if VariantLabel then VariantLabel:Set("Current Variant: " .. cur2) end
                    if StatusLabel then StatusLabel:Set("Rolling… #" .. rollCount) end
                    hbWaitT0 = os.clock()
                    hbState  = "wait"
                end

            elseif hbState == "wait" then
                if os.clock() - hbWaitT0 >= math.max(delay, 0.05) then
                    hbState = "fire"
                end
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
        log("ROLL STOPPED")
    end,
})

-- ═════════════════════════════════════════════════════════════════════════════
-- TAB: UPGRADE
-- ═════════════════════════════════════════════════════════════════════════════
local UpgTab = Window:Tab({ Title = "Upgrade", Icon = "arrow-up" })

UpgTab:Section("Slots to Upgrade")

-- individual toggles for all 12 slots
local slotToggles = {}
for _, slot in ipairs(SLOTS) do
    UpgTab:Toggle({
        Name     = slot,
        Default  = slot == "M1",
        Flag     = "UpgSlot_" .. slot,
        Callback = function(val)
            upgradeSlots[slot] = val
            log("UPGRADE SLOT " .. slot .. ": " .. tostring(val))
        end,
    })
    upgradeSlots[slot] = (slot == "M1")
end

UpgTab:Section("Stat Types")

for _, utype in ipairs(UPGRADE_TYPES) do
    UpgTab:Toggle({
        Name     = utype,
        Default  = true,
        Flag     = "UpgType_" .. utype,
        Callback = function(val)
            upgradeTypes[utype] = val
            log("UPGRADE TYPE " .. utype .. ": " .. tostring(val))
        end,
    })
end

UpgTab:Section("Settings")

UpgTab:Slider({
    Name     = "Upgrade Delay",
    Desc     = "Seconds between each upgrade fire",
    Min      = 0,
    Max      = 1,
    Step     = 0.05,
    Default  = 0.1,
    Suffix   = "s",
    Flag     = "UpgradeDelay",
    Callback = function(val)
        upgradeDelay = val
        log("UPGRADE DELAY: " .. val)
    end,
})

UpgTab:Section("Status")

UpgradeStatus = UpgTab:Label({ Text = "Idle." })

UpgTab:Section("Control")

UpgTab:Button({
    Name     = "Start Auto Upgrade",
    Desc     = "Continuously fires upgrades for all enabled slots and stats",
    Callback = function()
        if autoUpgrading then return end

        -- snapshot which slots/types are active
        local slots = {}
        for _, s in ipairs(SLOTS) do
            if upgradeSlots[s] then table.insert(slots, s) end
        end
        local types = {}
        for _, t in ipairs(UPGRADE_TYPES) do
            if upgradeTypes[t] then table.insert(types, t) end
        end

        if #slots == 0 then
            if UpgradeStatus then UpgradeStatus:Set("Enable at least one slot.") end
            return
        end
        if #types == 0 then
            if UpgradeStatus then UpgradeStatus:Set("Enable at least one stat type.") end
            return
        end

        autoUpgrading = true
        local delay = (UI.Flags and UI.Flags.UpgradeDelay) or upgradeDelay
        log(("UPGRADE START | Slots: %d | Types: %s"):format(#slots, table.concat(types, ", ")))
        if UpgradeStatus then
            UpgradeStatus:Set(("Running — %d slot(s), %d type(s)"):format(#slots, #types))
        end

        -- Heartbeat state machine — Delta mobile safe
        local upgSlotIdx = 1
        local upgTypeIdx = 1
        local upgWaitT0  = 0
        local upgWaiting = false
        local upgConn

        upgConn = RunService.Heartbeat:Connect(function()
            if not autoUpgrading then
                upgConn:Disconnect()
                if UpgradeStatus then UpgradeStatus:Set("Stopped.") end
                return
            end

            if upgWaiting then
                if os.clock() - upgWaitT0 >= math.max(delay, 0.05) then
                    upgWaiting = false
                end
                return
            end

            local s = slots[upgSlotIdx]
            local t = types[upgTypeIdx]
            if s and t then
                GamestateEvent:FireServer("MineUpgradeCharacter", s, t)
                log(("UPGRADE: %s → %s"):format(s, t))
            end

            -- advance indices
            upgTypeIdx += 1
            if upgTypeIdx > #types then
                upgTypeIdx = 1
                upgSlotIdx += 1
                if upgSlotIdx > #slots then
                    upgSlotIdx = 1
                end
            end

            upgWaitT0  = os.clock()
            upgWaiting = true
        end)
    end,
})

UpgTab:Button({
    Name     = "Stop",
    Desc     = "Stop the auto upgrade loop",
    Callback = function()
        if not autoUpgrading then
            if UpgradeStatus then UpgradeStatus:Set("Not running.") end
            return
        end
        autoUpgrading = false
        log("UPGRADE STOPPED")
        -- status set by the loop on exit
    end,
})

UpgTab:Button({
    Name     = "Upgrade Once",
    Desc     = "Fire one round of upgrades right now, then stop",
    Callback = function()
        local slots = {}
        for _, s in ipairs(SLOTS) do
            if upgradeSlots[s] then table.insert(slots, s) end
        end
        local types = {}
        for _, t in ipairs(UPGRADE_TYPES) do
            if upgradeTypes[t] then table.insert(types, t) end
        end
        if #slots == 0 or #types == 0 then return end
        local delay = (UI.Flags and UI.Flags.UpgradeDelay) or upgradeDelay
        local count = 0
        task.spawn(function()
            for _, slot in ipairs(slots) do
                for _, utype in ipairs(types) do
                    GamestateEvent:FireServer("MineUpgradeCharacter", slot, utype)
                    count += 1
                    task.wait(delay)
                end
            end
            if UpgradeStatus then UpgradeStatus:Set(("Fired %d upgrade(s)."):format(count)) end
            log(("UPGRADE ONCE: %d fired"):format(count))
        end)
    end,
})

-- ═════════════════════════════════════════════════════════════════════════════
-- TAB: INFO
-- ═════════════════════════════════════════════════════════════════════════════
local InfoTab = Window:Tab({ Title = "Info", Icon = "info" })
InfoTab:Section("Roll")
InfoTab:Paragraph({
    Name    = "Roll Guide",
    Content = "1. Pick target slot (M1–M12)\n2. Pick one or more target mutations\n3. Hit Start Auto Roll\n4. Stops automatically on a match",
})
InfoTab:Section("Upgrade")
InfoTab:Paragraph({
    Name    = "Upgrade Guide",
    Content = "Toggle which slots and stat types to upgrade.\nStart Auto Upgrade fires continuously.\nUpgrade Once fires a single round.\nTypes: Speed, MineSpeed, Damage",
})

-- ── Init ──────────────────────────────────────────────────────────────────────
log("========================================")
log("MINE TOOLS LOADED (DivineSoul Hub)")
log("ROLL DELAY: " .. rollDelay .. " | UPGRADE DELAY: " .. upgradeDelay)
log("========================================")

-- live variant poll
task.spawn(function()
    task.wait(1)
    while true do
        if not autoRolling and VariantLabel then
            VariantLabel:Set("Current Variant: " .. getVariant(selectedSlot))
        end
        task.wait(0.2)
    end
end)

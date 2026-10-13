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



-- AirFlow stores controls (not raw values) in UI.Flags.
-- Always read a control through :Get() when available.
local function getFlagValue(name, fallback)
    local flags = UI and UI.Flags
    local control = flags and flags[name]
    if control then
        if type(control.Get) == "function" then
            local ok, value = pcall(function()
                return control:Get()
            end)
            if ok and value ~= nil then
                return value
            end
        end
        if control.Value ~= nil then
            return control.Value
        end
    end
    return fallback
end

local function setFlagValue(name, value)
    local control = UI and UI.Flags and UI.Flags[name]
    if control and type(control.Set) == "function" then
        pcall(function() control:Set(value) end)
    end
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

-- Maximum levels reported for this game's three upgrade stats.
local UPGRADE_CAPS = { MineSpeed = 16, Speed = 17, Damage = 200 }

-- Read a stat from the slot's attributes or ValueBase objects. This deliberately
-- checks the slot's Crew/Display instances only; it does not guess from UI text.
local function getUpgradeLevel(slot, stat)
    local plot = findMyPlot()
    local holders = plot and plot:FindFirstChild("Holders")
    local holder = holders and holders:FindFirstChild(slot)
    local candidates = { getCrew(slot), getDisplay(slot), holder }
    local aliases = {
        MineSpeed = {"MineSpeed", "Mine Speed", "Mine_Speed", "MineSpeedLevel"},
        Speed = {"Speed", "SpeedLevel"},
        Damage = {"Damage", "DamageLevel"},
    }
    local names = aliases[stat] or {stat}
    for _, root in ipairs(candidates) do
        if root then
            for _, name in ipairs(names) do
                local value = root:GetAttribute(name)
                if value ~= nil and tonumber(value) then return tonumber(value) end
            end
            for _, obj in ipairs(root:GetDescendants()) do
                for _, name in ipairs(names) do
                    if obj.Name == name and obj:IsA("ValueBase") and tonumber(obj.Value) then
                        return tonumber(obj.Value)
                    end
                    local value = obj:GetAttribute(name)
                    if value ~= nil and tonumber(value) then return tonumber(value) end
                end
            end
        end
    end
    return nil
end

local function canUpgrade(slot, stat, baselineLevel, sentCount)
    local cap = UPGRADE_CAPS[stat]
    if not cap then return true end
    local level = getUpgradeLevel(slot, stat)
    if level == nil then
        return nil, ("Can't verify %s level for %s; skipped for safety."):format(stat, slot)
    end
    -- Account for requests already sent while replicated level data catches up.
    local projected = math.max(level, (baselineLevel or level) + (sentCount or 0))
    if projected >= cap then
        return false, ("%s %s is capped or pending cap (%s/%s).")
            :format(slot, stat, tostring(projected), tostring(cap))
    end
    return true
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

RollTab:Section("Mutation Slot")

-- Compact single-select dropdown: choose the one slot to roll.
RollTab:Dropdown({
    Name     = "Select Slot",
    Desc     = "Choose the crew slot to roll mutations on",
    Options  = SLOTS,
    Default  = "M1",
    Flag     = "TargetSlot",
    Searchable = true,
    Callback = function(val)
        if type(val) ~= "string" or val == "" then return end
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

local function startAutoRoll()

        if autoRolling then return end

        local slot     = selectedSlot
        local mutFlags = getFlagValue("TargetMutations", {"Unreal"})
        local targetMuts = {}
        if type(mutFlags) == "table" then
            -- AirFlow multi-dropdown :Get() returns an array of selected option names.
            for _, mutation in ipairs(mutFlags) do
                if type(mutation) == "string" and mutation ~= "" then
                    targetMuts[mutation] = true
                end
            end
            -- Also tolerate a dictionary-style selection table.
            if not next(targetMuts) then
                for mutation, enabled in pairs(mutFlags) do
                    if type(mutation) == "string" and enabled == true then
                        targetMuts[mutation] = true
                    end
                end
            end
        elseif type(mutFlags) == "string" and mutFlags ~= "" then
            targetMuts[mutFlags] = true
        end

        local delay = tonumber(getFlagValue("RollDelay", rollDelay)) or rollDelay

        if not next(targetMuts) then
            if StatusLabel then StatusLabel:Set("Select at least one mutation.") end
            setFlagValue("AutoRollEnabled", false)
            return
        end
        if not findMyPlot() then
            if StatusLabel then StatusLabel:Set("Mine plot not found.") end
            setFlagValue("AutoRollEnabled", false)
            return
        end
        local crew = getCrew(slot)
        if not crew then
            if StatusLabel then StatusLabel:Set(slot .. " not found.") end
            setFlagValue("AutoRollEnabled", false)
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
        local variantSignals = {}
        local function watchVariant(instance)
            if instance then
                table.insert(variantSignals, instance:GetAttributeChangedSignal("Variant"):Connect(function()
                    -- Heartbeat will read the latest replicated value on the next tick.
                    -- The signal also wakes the state machine's attention to rapid updates.
                    if hbState == "poll" then
                        local changed = getVariant(slot)
                        if changed ~= "N/A" then
                            lastVariant = changed
                        end
                    end
                end))
            end
        end
        watchVariant(crew)
        watchVariant(getDisplay(slot))

        hbConn = RunService.Heartbeat:Connect(function()
            if not autoRolling then
                hbConn:Disconnect()
                for _, connection in ipairs(variantSignals) do
                    connection:Disconnect()
                end
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
                        for _, connection in ipairs(variantSignals) do
                            connection:Disconnect()
                        end
                        if StatusLabel then StatusLabel:Set("TARGET FOUND: " .. cur .. " ✓") end
                        log("TARGET FOUND: " .. cur)
                        setFlagValue("AutoRollEnabled", false)
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
                local currentDelay = tonumber(getFlagValue("RollDelay", rollDelay)) or rollDelay
                if os.clock() - hbWaitT0 >= math.max(currentDelay, 0.05) then
                    hbState = "fire"
                end
            end
        end)
end

local function stopAutoRoll()
    if not autoRolling then return end
    autoRolling = false
    if StatusLabel then StatusLabel:Set("Stopped.") end
    log("ROLL STOPPED")
end

RollTab:Toggle({
    Name     = "Auto Roll",
    Desc     = "Turn on to roll until a selected mutation is found; turn off to stop",
    Default  = false,
    Flag     = "AutoRollEnabled",
    Callback = function(enabled)
        if enabled then
            startAutoRoll()
        else
            stopAutoRoll()
        end
    end,
})

-- ═════════════════════════════════════════════════════════════════════════════
-- TAB: UPGRADE
-- ═════════════════════════════════════════════════════════════════════════════
local UpgTab = Window:Tab({ Title = "Upgrade", Icon = "arrow-up" })

UpgTab:Section("Slots to Upgrade")

-- One compact multi-select dropdown replaces 12 separate slot toggles.
-- The selected values are kept in upgradeSlots for the existing upgrade loop.
UpgTab:Dropdown({
    Name       = "Select Slots",
    Desc       = "Choose one or more crew slots to upgrade",
    Options    = SLOTS,
    Default    = {"M1"},
    Multi      = true,
    Searchable = true,
    Flag       = "UpgSlots",
    Callback   = function(values)
        for _, slot in ipairs(SLOTS) do
            upgradeSlots[slot] = false
        end
        if type(values) == "table" then
            for _, slot in ipairs(values) do
                if upgradeSlots[slot] ~= nil or table.find(SLOTS, slot) then
                    upgradeSlots[slot] = true
                end
            end
        elseif type(values) == "string" and table.find(SLOTS, values) then
            upgradeSlots[values] = true
        end
        local selected = {}
        for _, slot in ipairs(SLOTS) do
            if upgradeSlots[slot] then table.insert(selected, slot) end
        end
        log("UPGRADE SLOTS: " .. (#selected > 0 and table.concat(selected, ", ") or "none"))
    end,
})

-- Ensure every slot has a known initial state before the dropdown callback runs.
for _, slot in ipairs(SLOTS) do
    if upgradeSlots[slot] == nil then
        upgradeSlots[slot] = (slot == "M1")
    end
end

UpgTab:Section("Stat Types")

-- Compact multi-select dropdown for all upgrade stats.
UpgTab:Dropdown({
    Name     = "Select Upgrade Types",
    Desc     = "Choose Speed, MineSpeed and/or Damage",
    Options  = UPGRADE_TYPES,
    Default  = {"Speed", "MineSpeed", "Damage"},
    Multi    = true,
    Flag     = "UpgTypes",
    Callback = function(values)
        for _, utype in ipairs(UPGRADE_TYPES) do
            upgradeTypes[utype] = false
        end
        if type(values) == "table" then
            for _, utype in ipairs(values) do
                if table.find(UPGRADE_TYPES, utype) then
                    upgradeTypes[utype] = true
                end
            end
        elseif type(values) == "string" and table.find(UPGRADE_TYPES, values) then
            upgradeTypes[values] = true
        end
        local selected = {}
        for _, utype in ipairs(UPGRADE_TYPES) do
            if upgradeTypes[utype] then table.insert(selected, utype) end
        end
        log("UPGRADE TYPES: " .. (#selected > 0 and table.concat(selected, ", ") or "none"))
    end,
})

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

local function startAutoUpgrade()

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
            if UpgradeStatus then UpgradeStatus:Set("Select at least one slot.") end
            setFlagValue("AutoUpgradeEnabled", false)
            return
        end
        if #types == 0 then
            if UpgradeStatus then UpgradeStatus:Set("Select at least one upgrade type.") end
            setFlagValue("AutoUpgradeEnabled", false)
            return
        end

        autoUpgrading = true
        local delay = tonumber(getFlagValue("UpgradeDelay", upgradeDelay)) or upgradeDelay
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
        local skippedPairs = {}
        local baselineLevels, sentCounts = {}, {}
        local function pairKey(slot, stat) return slot .. "|" .. stat end
        for _, slot in ipairs(slots) do
            baselineLevels[slot], sentCounts[slot] = {}, {}
            for _, stat in ipairs(types) do
                baselineLevels[slot][stat] = getUpgradeLevel(slot, stat)
                sentCounts[slot][stat] = 0
            end
        end

        upgConn = RunService.Heartbeat:Connect(function()
            if not autoUpgrading then
                upgConn:Disconnect()
                if UpgradeStatus then UpgradeStatus:Set("Stopped.") end
                return
            end

            if upgWaiting then
                local currentDelay = tonumber(getFlagValue("UpgradeDelay", upgradeDelay)) or upgradeDelay
                if os.clock() - upgWaitT0 >= math.max(currentDelay, 0.05) then
                    upgWaiting = false
                end
                return
            end

            local s = slots[upgSlotIdx]
            local t = types[upgTypeIdx]
            if s and t then
                local allowed, reason = canUpgrade(s, t, baselineLevels[s][t], sentCounts[s][t])
                if allowed then
                    GamestateEvent:FireServer("MineUpgradeCharacter", s, t)
                    sentCounts[s][t] += 1
                    log(("UPGRADE: %s → %s"):format(s, t))
                else
                    skippedPairs[pairKey(s, t)] = true
                    if UpgradeStatus and reason then UpgradeStatus:Set(reason) end
                    log(reason or (s .. " " .. t .. " is capped; skipped."))
                    local allDone = true
                    for _, checkSlot in ipairs(slots) do
                        for _, checkType in ipairs(types) do
                            if not skippedPairs[pairKey(checkSlot, checkType)] then
                                allDone = false
                                break
                            end
                        end
                        if not allDone then break end
                    end
                    if allDone then
                        autoUpgrading = false
                        if upgConn then upgConn:Disconnect() end
                        if UpgradeStatus then UpgradeStatus:Set("Auto Upgrade stopped: all selected pairs are capped or their levels could not be read.") end
                        setFlagValue("AutoUpgradeEnabled", false)
                        return
                    end
                end
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
end

local function stopAutoUpgrade()
    if not autoUpgrading then return end
    autoUpgrading = false
    log("UPGRADE STOPPED")
end

UpgTab:Toggle({
    Name     = "Auto Upgrade",
    Desc     = "Turn on to upgrade selected slots/stats; turn off to stop",
    Default  = false,
    Flag     = "AutoUpgradeEnabled",
    Callback = function(enabled)
        if enabled then
            startAutoUpgrade()
        else
            stopAutoUpgrade()
        end
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
        local delay = tonumber(getFlagValue("UpgradeDelay", upgradeDelay)) or upgradeDelay
        local count = 0
        local baselineLevels, sentCounts = {}, {}
        for _, slot in ipairs(slots) do
            baselineLevels[slot], sentCounts[slot] = {}, {}
            for _, stat in ipairs(types) do
                baselineLevels[slot][stat] = getUpgradeLevel(slot, stat)
                sentCounts[slot][stat] = 0
            end
        end
        task.spawn(function()
            for _, slot in ipairs(slots) do
                for _, utype in ipairs(types) do
                    local allowed, reason = canUpgrade(slot, utype, baselineLevels[slot][utype], sentCounts[slot][utype])
                    if allowed then
                        GamestateEvent:FireServer("MineUpgradeCharacter", slot, utype)
                        sentCounts[slot][utype] += 1
                        count += 1
                        log(("UPGRADE ONCE: %s → %s"):format(slot, utype))
                    else
                        log(reason or (slot .. " " .. utype .. " is capped; skipped."))
                        if UpgradeStatus and reason then UpgradeStatus:Set(reason) end
                    end
                    task.wait(math.max(delay, 0.05))
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
    Content = "Choose slots and stat types from the multi-select dropdowns.\nTurn Auto Upgrade on/off to start/stop. Upgrade Once fires one pass.\nCaps: MineSpeed 16, Speed 17, Damage 200. The script checks slot attributes/Value objects before sending upgrades.",
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

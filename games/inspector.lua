-- inspector.lua
-- Universal Object Inspector v3 | PotatoUI port
-- PlaceId: universal — add to loader.lua manually or call directly

local BASE = "https://raw.githubusercontent.com/divso123/script/main/"
local UI   = loadstring(game:HttpGet(BASE .. "UI.lua"))()

local Players  = game:GetService("Players")
local CoreGui  = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- ── State ────────────────────────────────────────────────────────────────────
local paths       = {}
local scanDepth   = 1
local maxMatches  = 10
local latestReport = ""

-- ── Logging ──────────────────────────────────────────────────────────────────
local function log(msg)
    print(("[%s] [Inspector] %s"):format(os.date("%H:%M:%S"), tostring(msg)))
end

-- ── Path resolver (unchanged logic) ─────────────────────────────────────────
local function getRoot(name)
    if name:lower() == "game"      then return game      end
    if name:lower() == "workspace" then return workspace end
    local ok, svc = pcall(function() return game:GetService(name) end)
    if ok and svc then return svc end
    return game:FindFirstChild(name)
end

local function splitPath(path)
    local s = {}
    for seg in path:gmatch("[^%.]+") do table.insert(s, seg) end
    return s
end

local function matchesWildcard(name, pattern)
    if pattern == name or pattern == "*" then return true end
    if pattern:sub(-1) == "*" then
        local prefix = pattern:sub(1, -2)
        return prefix == "" or name:sub(1, #prefix) == prefix
    end
    return false
end

local function resolvePath(path)
    local segments = splitPath(path)
    if #segments == 0 then return {} end
    local current = {game}
    for idx, seg in ipairs(segments) do
        local next = {}
        for _, parent in ipairs(current) do
            if idx == 1 then
                local root = getRoot(seg)
                if root then table.insert(next, root) end
            else
                for _, child in ipairs(parent:GetChildren()) do
                    if matchesWildcard(child.Name, seg) then
                        table.insert(next, child)
                    end
                end
            end
        end
        current = next
        if #current == 0 then break end
    end
    return current
end

-- ── Value / interaction describers (unchanged logic) ─────────────────────────
local SUPPORTED_VALUES = {
    StringValue=true, IntValue=true, NumberValue=true, BoolValue=true,
    ObjectValue=true, Vector3Value=true, CFrameValue=true, Color3Value=true,
    BrickColorValue=true, Vector2Value=true, RayValue=true,
    UDimValue=true, UDim2Value=true,
}

local function describeValue(obj)
    if not SUPPORTED_VALUES[obj.ClassName] then return nil end
    local ok, v = pcall(function() return obj.Value end)
    return ok and tostring(v) or nil
end

local function collectInteractions(obj, lines, indent)
    local c = obj.ClassName
    if c == "ProximityPrompt" then
        table.insert(lines, indent.."[ProximityPrompt] ActionText="..obj.ActionText.." | ObjectText="..obj.ObjectText.." | HoldDuration="..obj.HoldDuration)
    elseif c == "ClickDetector" then
        table.insert(lines, indent.."[ClickDetector] MaxActivationDistance="..obj.MaxActivationDistance)
    elseif c == "RemoteEvent"    then table.insert(lines, indent.."[RemoteEvent]")
    elseif c == "RemoteFunction" then table.insert(lines, indent.."[RemoteFunction]")
    elseif c == "BindableEvent"  then table.insert(lines, indent.."[BindableEvent]")
    elseif c == "BindableFunction" then table.insert(lines, indent.."[BindableFunction]")
    end
end

local function inspectTree(obj, depth, indent, lines)
    if depth > scanDepth then return end
    for _, child in ipairs(obj:GetChildren()) do
        local val  = describeValue(child)
        local line = indent.."- "..child.Name.." ["..child.ClassName.."]"
        if val then line = line.." = "..val end
        table.insert(lines, line)
        collectInteractions(child, lines, indent.."  ")
        inspectTree(child, depth + 1, indent.."  ", lines)
    end
end

local function describeObject(obj)
    local lines = {
        "Name:  "..obj.Name,
        "Class: "..obj.ClassName,
        "Path:  "..obj:GetFullName(),
        "",
        "Attributes:",
    }
    local attrs = obj:GetAttributes()
    local names = {}
    for k in pairs(attrs) do table.insert(names, k) end
    table.sort(names)
    if #names == 0 then
        table.insert(lines, "  (none)")
    else
        for _, k in ipairs(names) do
            table.insert(lines, "  "..k.." = "..tostring(attrs[k]))
        end
    end
    local ownVal = describeValue(obj)
    if ownVal then
        table.insert(lines, "")
        table.insert(lines, "Value:")
        table.insert(lines, "  "..ownVal)
    end
    table.insert(lines, "")
    table.insert(lines, "Children:")
    if #obj:GetChildren() == 0 then
        table.insert(lines, "  (none)")
    else
        inspectTree(obj, 0, "  ", lines)
    end
    return table.concat(lines, "\n")
end

local function scan()
    if #paths == 0 then
        log("SCAN FAILED: No paths.")
        return "No paths configured."
    end
    log(("SCAN | Paths: %d | Depth: %d | Max: %d"):format(#paths, scanDepth, maxMatches))
    local reports, total = {}, 0
    for _, path in ipairs(paths) do
        log("Resolving: "..path)
        local matches = resolvePath(path)
        total += #matches
        local lines = {
            "==================================================",
            "PATH: "..path,
            "MATCHES: "..#matches,
            "==================================================",
        }
        if #matches == 0 then
            table.insert(lines, "NOT FOUND")
            log("NOT FOUND: "..path)
        else
            log(("FOUND: %s | %d match(es)"):format(path, #matches))
            local amt = math.min(#matches, maxMatches)
            for i = 1, amt do
                table.insert(lines, "")
                table.insert(lines, ("--- Match %d/%d ---"):format(i, #matches))
                table.insert(lines, describeObject(matches[i]))
            end
            if #matches > maxMatches then
                table.insert(lines, "")
                table.insert(lines, ("... %d additional matches not shown"):format(#matches - maxMatches))
            end
        end
        table.insert(reports, table.concat(lines, "\n"))
    end
    log(("SCAN COMPLETE | Found: %d"):format(total))
    return table.concat(reports, "\n\n")
end

-- ── UI ───────────────────────────────────────────────────────────────────────
local Window = UI:Window({
    Title    = "PotatoUI",
    SubTitle = "Object Inspector",
    Theme    = "Midnight",
})

-- ── Tab: Paths ───────────────────────────────────────────────────────────────
local PathsTab = Window:Tab({ Title = "Paths", Icon = "search" })
PathsTab:Section("Add Path")

-- path input via TextInput if supported, else a manual flag approach
local currentInput = ""

PathsTab:Input({
    Name        = "Path",
    Desc        = "e.g. ReplicatedStorage.Remotes.* or Workspace.base_*",
    Placeholder = "Enter any Roblox path...",
    Flag        = "PathInput",
    Callback    = function(val)
        currentInput = val
    end,
})

PathsTab:Button({
    Name     = "Add Path",
    Desc     = "Adds the path above to the scan list",
    Callback = function()
        local path = currentInput:gsub("^%s+",""):gsub("%s+$","")
        if path == "" then return end
        for _, existing in ipairs(paths) do
            if existing == path then return end
        end
        table.insert(paths, path)
        log("PATH ADDED: "..path)
        -- refresh the list label
        local list = {}
        for i, p in ipairs(paths) do
            table.insert(list, i..". "..p)
        end
        if UI.Flags.PathList then
            UI.Flags.PathList:SetText(
                #paths == 0 and "(no paths)" or table.concat(list, "\n")
            )
        end
    end,
})

PathsTab:Button({
    Name     = "Clear All Paths",
    Callback = function()
        table.clear(paths)
        log("ALL PATHS CLEARED.")
        if UI.Flags.PathList then
            UI.Flags.PathList:SetText("(no paths)")
        end
    end,
})

PathsTab:Section("Active Paths")

PathsTab:Label({
    Text = "(no paths)",
    Flag = "PathList",
})

-- ── Tab: Scan ─────────────────────────────────────────────────────────────────
local ScanTab = Window:Tab({ Title = "Scan", Icon = "zap" })
ScanTab:Section("Settings")

ScanTab:Slider({
    Name    = "Scan Depth",
    Min     = 0,
    Max     = 20,
    Step    = 1,
    Default = 1,
    Suffix  = " levels",
    Flag    = "ScanDepth",
    Callback = function(val)
        scanDepth = val
        log("DEPTH: "..val)
    end,
})

ScanTab:Slider({
    Name    = "Max Matches",
    Min     = 1,
    Max     = 100,
    Step    = 1,
    Default = 10,
    Suffix  = " matches",
    Flag    = "MaxMatches",
    Callback = function(val)
        maxMatches = val
        log("MAX MATCHES: "..val)
    end,
})

ScanTab:Section("Run")

ScanTab:Button({
    Name     = "Scan",
    Desc     = "Resolve all paths and inspect matched objects",
    Callback = function()
        log("SCAN BUTTON PRESSED.")
        local ok, result = pcall(scan)
        latestReport = ok and result or ("SCAN ERROR:\n\n"..tostring(result))
        if UI.Flags.ScanOutput then
            UI.Flags.ScanOutput:SetText(latestReport)
        end
        log(ok and "SCAN SUCCESS." or "SCAN FAILED.")
    end,
})

ScanTab:Button({
    Name     = "Export to File",
    Desc     = "Writes the last report to workspace (requires writefile)",
    Callback = function()
        if latestReport == "" then
            local ok, result = pcall(scan)
            latestReport = ok and result or ""
        end
        if latestReport == "" then return end
        if not writefile then
            log("EXPORT FAILED: writefile unavailable.")
            return
        end
        local fname = "InspectorReport_"..os.date("%Y%m%d_%H%M%S")..".txt"
        local ok, err = pcall(writefile, fname, latestReport)
        log(ok and ("EXPORTED: "..fname) or ("EXPORT FAILED: "..tostring(err)))
    end,
})

ScanTab:Button({
    Name     = "Clear Output",
    Callback = function()
        latestReport = ""
        if UI.Flags.ScanOutput then
            UI.Flags.ScanOutput:SetText("(run a scan to see results)")
        end
        log("OUTPUT CLEARED.")
    end,
})

-- ── Tab: Output ───────────────────────────────────────────────────────────────
local OutTab = Window:Tab({ Title = "Output", Icon = "terminal" })
OutTab:Section("Last Scan Result")

OutTab:Label({
    Text = "(run a scan to see results)",
    Flag = "ScanOutput",
})

-- ── Init ──────────────────────────────────────────────────────────────────────
log("========================================")
log("UNIVERSAL OBJECT INSPECTOR LOADED (PotatoUI)")
log("DEPTH: "..scanDepth.." | MAX: "..maxMatches)
log("WRITEFILE: "..tostring(writefile ~= nil))
log("========================================")

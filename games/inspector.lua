-- inspector.lua
-- Universal Object Inspector v4 | PotatoUI port

local BASE = "https://raw.githubusercontent.com/divso123/script/main/"
local UI   = loadstring(game:HttpGet(BASE .. "UI.lua"))()

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- ── State ────────────────────────────────────────────────────────────────────
local paths        = {}
local scanDepth    = 1
local maxMatches   = 10
local latestReport = ""
local useDescendants = false

-- ── Logging ──────────────────────────────────────────────────────────────────
local function log(msg)
    print(("[%s] [Inspector] %s"):format(os.date("%H:%M:%S"), tostring(msg)))
end

-- ── Path resolver ─────────────────────────────────────────────────────────────
local function getRoot(name)
    local n = name:lower()
    if n == "game"      then return game      end
    if n == "workspace" then return workspace end
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
    if pattern == "*" or pattern == name then return true end
    if pattern:sub(-1) == "*" then
        local prefix = pattern:sub(1, -2)
        return prefix == "" or name:sub(1, #prefix):lower() == prefix:lower()
    end
    -- case-insensitive exact match fallback
    return name:lower() == pattern:lower()
end

local function resolvePath(path)
    local segments = splitPath(path)
    if #segments == 0 then return {} end
    local current = {}
    for idx, seg in ipairs(segments) do
        local next = {}
        if idx == 1 then
            local root = getRoot(seg)
            if root then table.insert(next, root) end
        else
            for _, parent in ipairs(current) do
                -- support both single-level wildcard and named child
                local ok, children = pcall(function() return parent:GetChildren() end)
                if ok then
                    for _, child in ipairs(children) do
                        if matchesWildcard(child.Name, seg) then
                            table.insert(next, child)
                        end
                    end
                end
            end
        end
        current = next
        if #current == 0 then break end
    end
    return current
end

-- ── Value / interaction describers ───────────────────────────────────────────
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
        local ok, info = pcall(function()
            return indent.."[ProximityPrompt] ActionText="..obj.ActionText
                .." | ObjectText="..obj.ObjectText
                .." | HoldDuration="..obj.HoldDuration
        end)
        table.insert(lines, ok and info or indent.."[ProximityPrompt] (restricted)")
    elseif c == "ClickDetector" then
        local ok, dist = pcall(function() return obj.MaxActivationDistance end)
        table.insert(lines, indent.."[ClickDetector] MaxActivationDistance="..(ok and tostring(dist) or "?"))
    elseif c == "RemoteEvent"      then table.insert(lines, indent.."[RemoteEvent]")
    elseif c == "RemoteFunction"   then table.insert(lines, indent.."[RemoteFunction]")
    elseif c == "BindableEvent"    then table.insert(lines, indent.."[BindableEvent]")
    elseif c == "BindableFunction" then table.insert(lines, indent.."[BindableFunction]")
    end
end

-- extra properties for common classes
local function describeClassProps(obj, lines, indent)
    local c = obj.ClassName
    local function safe(fn) local ok, v = pcall(fn) return ok and tostring(v) or "?" end
    if c == "Part" or c == "MeshPart" or c == "UnionOperation" or c == "SpecialMesh" or
       c == "WedgePart" or c == "CornerWedgePart" or c == "TrussPart" or c == "SpawnLocation" then
        table.insert(lines, indent.."Position = "..safe(function() return obj.Position end))
        table.insert(lines, indent.."Size     = "..safe(function() return obj.Size end))
        table.insert(lines, indent.."Anchored = "..safe(function() return obj.Anchored end))
        table.insert(lines, indent.."CanCollide = "..safe(function() return obj.CanCollide end))
    elseif c == "Humanoid" then
        table.insert(lines, indent.."Health    = "..safe(function() return obj.Health end))
        table.insert(lines, indent.."MaxHealth = "..safe(function() return obj.MaxHealth end))
        table.insert(lines, indent.."WalkSpeed = "..safe(function() return obj.WalkSpeed end))
        table.insert(lines, indent.."JumpPower = "..safe(function() return obj.JumpPower end))
    elseif c == "Model" then
        table.insert(lines, indent.."PrimaryPart = "..safe(function()
            return obj.PrimaryPart and obj.PrimaryPart.Name or "nil"
        end))
    elseif c == "Script" or c == "LocalScript" or c == "ModuleScript" then
        table.insert(lines, indent.."Disabled = "..safe(function() return obj.Disabled end))
    elseif c:find("Gui") or c:find("Frame") or c:find("Label") or c:find("Button") or c:find("TextBox") then
        table.insert(lines, indent.."Visible  = "..safe(function() return obj.Visible end))
        table.insert(lines, indent.."Size     = "..safe(function() return obj.Size end))
        table.insert(lines, indent.."Position = "..safe(function() return obj.AbsolutePosition end))
    end
end

local function inspectTree(obj, depth, indent, lines)
    -- fix: depth starts at 0, scanDepth=1 means 1 level of children → check depth >= scanDepth
    if depth >= scanDepth then return end
    local getter = useDescendants
        and function() return obj:GetDescendants() end
        or  function() return obj:GetChildren() end
    local ok, items = pcall(getter)
    if not ok then return end
    -- in descendants mode, skip items whose depth from obj exceeds scanDepth
    for _, child in ipairs(items) do
        local val  = describeValue(child)
        local line = indent.."- "..child.Name.." ["..child.ClassName.."]"
        if val then line = line.." = "..val end
        table.insert(lines, line)
        collectInteractions(child, lines, indent.."  ")
        if not useDescendants then
            inspectTree(child, depth + 1, indent.."  ", lines)
        end
    end
end

local function describeObject(obj)
    local lines = {
        "Name:  "..obj.Name,
        "Class: "..obj.ClassName,
        "Path:  "..obj:GetFullName(),
        "",
        "Properties:",
    }
    describeClassProps(obj, lines, "  ")

    local ok, attrs = pcall(function() return obj:GetAttributes() end)
    if ok and attrs then
        local names = {}
        for k in pairs(attrs) do table.insert(names, k) end
        table.sort(names)
        if #names > 0 then
            table.insert(lines, "")
            table.insert(lines, "Attributes:")
            for _, k in ipairs(names) do
                table.insert(lines, "  "..k.." = "..tostring(attrs[k]))
            end
        end
    end

    local ownVal = describeValue(obj)
    if ownVal then
        table.insert(lines, "")
        table.insert(lines, "Value:")
        table.insert(lines, "  "..ownVal)
    end

    table.insert(lines, "")
    table.insert(lines, "Children (depth="..scanDepth..", mode="..(useDescendants and "descendants" or "children").."):")
    local ok2, childList = pcall(function() return obj:GetChildren() end)
    if not ok2 or #childList == 0 then
        table.insert(lines, "  (none)")
    else
        inspectTree(obj, 0, "  ", lines)
    end
    return table.concat(lines, "\n")
end

local function buildPathListText()
    if #paths == 0 then return "(no paths)" end
    local list = {}
    for i, p in ipairs(paths) do table.insert(list, i..". "..p) end
    return table.concat(list, "\n")
end

-- ── Filter ───────────────────────────────────────────────────────────────────
local filterClass    = ""
local filterKeyword  = ""

local function applyFilters(report)
    if filterClass == "" and filterKeyword == "" then return report end
    local lines = {}
    for line in (report.."\n"):gmatch("([^\n]*)\n") do
        local classOk = filterClass == ""
            or line:lower():find("%["..filterClass:lower().."%]") ~= nil
        local kwOk = filterKeyword == ""
            or line:lower():find(filterKeyword:lower(), 1, true) ~= nil
        if classOk and kwOk then
            table.insert(lines, line)
        end
    end
    return table.concat(lines, "\n")
end

local function scan()
    if #paths == 0 then
        log("SCAN FAILED: No paths.")
        return "No paths configured."
    end
    log(("SCAN | Paths: %d | Depth: %d | Max: %d | Mode: %s"):format(
        #paths, scanDepth, maxMatches, useDescendants and "descendants" or "children"))
    local reports, total = {}, 0
    for _, path in ipairs(paths) do
        log("Resolving: "..path)
        local matches = resolvePath(path)
        total = total + #matches
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
    local raw = table.concat(reports, "\n\n")
    return applyFilters(raw)
end

-- ── UI ────────────────────────────────────────────────────────────────────────
local Window = UI:Window({
    Title    = "DivineSoul",
    SubTitle = "Object Inspector",
    Theme    = "Midnight",
})

-- ── Tab: Paths ────────────────────────────────────────────────────────────────
local PathsTab = Window:Tab({ Title = "Paths", Icon = "search" })
PathsTab:Section("Add Path")

local currentInput = ""
local PathListLabel

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
        local path = currentInput:gsub("^%s+", ""):gsub("%s+$", "")
        if path == "" then log("ADD FAILED: empty path.") return end
        for _, existing in ipairs(paths) do
            if existing == path then
                log("ADD SKIPPED (duplicate): "..path) return
            end
        end
        table.insert(paths, path)
        log("PATH ADDED: "..path)
        if PathListLabel then PathListLabel:Set(buildPathListText()) end
    end,
})

PathsTab:Button({
    Name     = "Remove Last Path",
    Desc     = "Removes the most recently added path",
    Callback = function()
        if #paths == 0 then log("REMOVE FAILED: no paths.") return end
        local removed = table.remove(paths)
        log("PATH REMOVED: "..removed)
        if PathListLabel then PathListLabel:Set(buildPathListText()) end
    end,
})

PathsTab:Button({
    Name     = "Remove by Number",
    Desc     = "Removes the path whose number matches the input field (type the number first)",
    Callback = function()
        local n = tonumber(currentInput:gsub("%s+",""))
        if not n or n < 1 or n > #paths then
            log("REMOVE FAILED: invalid index "..tostring(currentInput)) return
        end
        local removed = table.remove(paths, n)
        log("PATH REMOVED #"..n..": "..removed)
        if PathListLabel then PathListLabel:Set(buildPathListText()) end
    end,
})

PathsTab:Button({
    Name     = "Clear All Paths",
    Callback = function()
        table.clear(paths)
        log("ALL PATHS CLEARED.")
        if PathListLabel then PathListLabel:Set("(no paths)") end
    end,
})

PathsTab:Section("Active Paths")
PathListLabel = PathsTab:Label({ Text = "(no paths)" })

-- ── Tab: Scan ─────────────────────────────────────────────────────────────────
local ScanTab = Window:Tab({ Title = "Scan", Icon = "zap" })
ScanTab:Section("Settings")

ScanTab:Slider({
    Name     = "Scan Depth",
    Min      = 1,
    Max      = 20,
    Step     = 1,
    Default  = 1,
    Suffix   = " levels",
    Flag     = "ScanDepth",
    Callback = function(val)
        scanDepth = val
        log("DEPTH: "..val)
    end,
})

ScanTab:Slider({
    Name     = "Max Matches",
    Min      = 1,
    Max      = 100,
    Step     = 1,
    Default  = 10,
    Suffix   = " matches",
    Flag     = "MaxMatches",
    Callback = function(val)
        maxMatches = val
        log("MAX MATCHES: "..val)
    end,
})

ScanTab:Toggle({
    Name     = "Descendant Mode",
    Desc     = "Scan all descendants instead of direct children only",
    Default  = false,
    Flag     = "DescMode",
    Callback = function(val)
        useDescendants = val
        log("DESCENDANT MODE: "..tostring(val))
    end,
})

ScanTab:Section("Filter (optional)")

ScanTab:Input({
    Name        = "Filter by Class",
    Desc        = "Only show lines containing this class e.g. Part, RemoteEvent",
    Placeholder = "leave blank to show all",
    Flag        = "FilterClass",
    Callback    = function(val) filterClass = val end,
})

ScanTab:Input({
    Name        = "Filter by Keyword",
    Desc        = "Only show lines containing this text",
    Placeholder = "leave blank to show all",
    Flag        = "FilterKw",
    Callback    = function(val) filterKeyword = val end,
})

ScanTab:Section("Run")

local ScanOutputLabel

ScanTab:Button({
    Name     = "Scan",
    Desc     = "Resolve all paths and inspect matched objects",
    Callback = function()
        log("SCAN BUTTON PRESSED.")
        local ok, result = pcall(scan)
        latestReport = ok and result or ("SCAN ERROR:\n\n"..tostring(result))
        if ScanOutputLabel then ScanOutputLabel:Set(latestReport) end
        log(ok and "SCAN SUCCESS." or "SCAN FAILED.")
    end,
})

ScanTab:Button({
    Name     = "Copy to Clipboard",
    Desc     = "Copies the last report to clipboard",
    Callback = function()
        if latestReport == "" then
            log("COPY FAILED: no report.") return
        end
        local ok, err = pcall(setclipboard, latestReport)
        log(ok and "COPIED TO CLIPBOARD." or ("COPY FAILED: "..tostring(err)))
    end,
})

ScanTab:Button({
    Name     = "Export to File",
    Desc     = "Writes the last report to a .txt file (requires writefile)",
    Callback = function()
        if latestReport == "" then
            local ok, result = pcall(scan)
            latestReport = ok and result or ""
        end
        if latestReport == "" then return end
        if type(writefile) ~= "function" then
            log("EXPORT FAILED: writefile unavailable.") return
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
        if ScanOutputLabel then
            ScanOutputLabel:Set("(run a scan to see results)")
        end
        log("OUTPUT CLEARED.")
    end,
})

-- ── Tab: Output ───────────────────────────────────────────────────────────────
local OutTab = Window:Tab({ Title = "Output", Icon = "terminal" })
OutTab:Section("Last Scan Result")
ScanOutputLabel = OutTab:Paragraph({
    Name    = "Result",
    Content = "(run a scan to see results)",
})

-- ── Init ──────────────────────────────────────────────────────────────────────
log("========================================")
log("UNIVERSAL OBJECT INSPECTOR LOADED v4 (PotatoUI)")
log("DEPTH: "..scanDepth.." | MAX: "..maxMatches)
log("WRITEFILE:    "..tostring(type(writefile) == "function"))
log("SETCLIPBOARD: "..tostring(type(setclipboard) == "function"))
log("========================================")

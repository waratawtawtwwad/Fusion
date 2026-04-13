local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua'))()

local Window = Rayfield:CreateWindow({
    Name = "Fusion (Hub)",
    Icon = 0,
    LoadingTitle = "Fusion (Hub)",
    LoadingSubtitle = "by Your Typical Exploiter",
    Theme = "Default",
    ToggleUIKeybind = "K",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings = false,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "FusionHub",
        FileName = "Settings"
    },
    Discord = {
        Enabled = false,
        Invite = "noinvitelink",
        RememberJoins = true
    },
    KeySystem = false
})

local Players          = game:GetService("Players")
local Workspace        = game:GetService("Workspace")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local LocalPlayer      = Players.LocalPlayer

-- =====================
--        STATE
-- =====================

local hitboxExtenderEnabled     = false
local aimbotEnabled             = false
local killauraEnabled           = false
local hitboxSize                = 15
local aimbotRange               = 100
local hitboxExtenderConnections = {}
local aimbotConnection          = nil
local killauraConnection        = nil
local currentTarget             = nil
local originalSizes             = {}
local isAttacking               = false
local equipAllConnections       = {}

local BLACKLISTED_TOOLS = {
    ["Equip to Click TP"] = true,
    ["doctor's bag"]      = true,
    ["leech"]             = true,
    ["Broom"]             = true,
    ["Excalibur"]         = false,
}

-- =====================
--       HELPERS
-- =====================

local function GetChar()
    return LocalPlayer.Character
end

local function GetHRP()
    local char = GetChar()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function TeleportTo(cf)
    local hrp = GetHRP()
    if hrp then hrp.CFrame = cf end
end

local function Tween(cf)
    local hrp = GetHRP()
    if not hrp then return end
    TweenService:Create(hrp, TweenInfo.new(0, Enum.EasingStyle.Linear), { CFrame = cf }):Play()
end

local function TeleportDoReturn(targetCF, actionFn, waitTime)
    local hrp = GetHRP()
    if not hrp then return end
    local origin = hrp.CFrame
    TeleportTo(targetCF)
    task.wait(waitTime or 0.15)
    if actionFn then actionFn() end
    task.wait(0.05)
    TeleportTo(origin)
end

local function Find(str, tbl)
    local lower = str:lower()
    for _, v in next, tbl do
        if string.find(lower, v:lower()) then return true end
    end
    return false
end

local function GetWorkbench(name)
    local ok, model = pcall(function()
        return Workspace.workbenches[name]
    end)
    if not ok or not model then return nil, nil end
    local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    return model, part
end

local function SafeGet(fn)
    local ok, result = pcall(fn)
    return ok and result or nil
end

local function GetUnfinishedFlintlocks()
    local char = GetChar()
    local unfinished = {}
    if not char then return unfinished end
    for _, item in pairs(char:GetChildren()) do
        if item:IsA("Tool") and Find(item.Name, {"unfin", "unfinished"}) and item:FindFirstChild("Handle") then
            table.insert(unfinished, item)
        end
    end
    for _, item in pairs(LocalPlayer.Backpack:GetChildren()) do
        if item:IsA("Tool") and Find(item.Name, {"unfin", "unfinished"}) and item:FindFirstChild("Handle") then
            table.insert(unfinished, item)
        end
    end
    return unfinished
end

-- Anticheat cleanup
pcall(function()
    local char = GetChar()
    if char then
        for _, v in pairs(char:GetChildren()) do
            if v.Name == "anticheatcooldown" then v:Destroy() end
        end
        if char:FindFirstChild("Humanoid") then
            char.Humanoid.Died:Connect(function()
                local tbp = char:FindFirstChild("anticheatcooldown")
                if tbp then tbp:Destroy() end
            end)
        end
    end
end)

pcall(function()
    game:GetService("ProximityPromptService").PromptButtonHoldBegan:Connect(function(prompt)
        fireproximityprompt(prompt)
    end)
end)

-- =====================
--    HITBOX EXTENDER
-- Saves true original sizes once per character load (never overwrites
-- them on resize), handles both R6 and R15, cleans up on character
-- removal, and re-expands live when the slider moves.
-- =====================

-- Returns the parts we actually care about expanding for a character.
-- Skips accessories, tools, and anything that isn't a core body part
-- so we don't break clothing/hat mesh sizes.
local CORE_PARTS = {
    HumanoidRootPart = true,
    Head             = true,
    -- R15
    UpperTorso       = true,
    LowerTorso       = true,
    LeftUpperArm     = true, LeftLowerArm  = true, LeftHand      = true,
    RightUpperArm    = true, RightLowerArm = true, RightHand     = true,
    LeftUpperLeg     = true, LeftLowerLeg  = true, LeftFoot      = true,
    RightUpperLeg    = true, RightLowerLeg = true, RightFoot     = true,
    -- R6
    Torso            = true,
    ["Left Arm"]     = true, ["Right Arm"]  = true,
    ["Left Leg"]     = true, ["Right Leg"]  = true,
}

local function GetCoreParts(character)
    local parts = {}
    for _, v in pairs(character:GetChildren()) do
        if v:IsA("BasePart") and CORE_PARTS[v.Name] then
            table.insert(parts, v)
        end
    end
    return parts
end

-- Save true originals — only called once per fresh character, never again.
local function SaveOriginalSizes(player, character)
    if originalSizes[player] then return end -- already saved, don't overwrite
    originalSizes[player] = {}
    for _, part in pairs(GetCoreParts(character)) do
        originalSizes[player][part] = part.Size
    end
end

-- Apply hitbox expansion using the current hitboxSize.
-- Safe to call multiple times (e.g. when slider changes).
local function ApplyHitbox(character)
    if not character then return end
    local player = Players:GetPlayerFromCharacter(character)
    if not player or player == LocalPlayer then return end
    if not originalSizes[player] then return end -- originals not saved yet, bail

    for _, part in pairs(GetCoreParts(character)) do
        pcall(function()
            if part.Name == "HumanoidRootPart" then
                part.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
            elseif part.Name == "Head" then
                part.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
            else
                -- All body parts get full size so any swing registers
                part.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
            end
        end)
    end
end

-- Restore exact originals and wipe the saved table entry.
local function ResetPlayerHitbox(player)
    if not originalSizes[player] then return end
    for part, originalSize in pairs(originalSizes[player]) do
        pcall(function()
            if part and part.Parent then
                part.Size = originalSize
            end
        end)
    end
    originalSizes[player] = nil
end

-- Full setup for one player: save originals then expand.
local function SetupPlayer(player)
    if player == LocalPlayer then return end
    local character = player.Character
    if not character then return end
    -- Wait for character to fully load if needed
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    SaveOriginalSizes(player, character)
    if hitboxExtenderEnabled then
        ApplyHitbox(character)
    end
end

local function EnableHitboxExtender()
    if hitboxExtenderEnabled then return end
    hitboxExtenderEnabled = true

    -- Apply to everyone already in the server
    for _, player in pairs(Players:GetPlayers()) do
        SetupPlayer(player)
    end

    -- Hook future character spawns for existing players
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local conn = player.CharacterAdded:Connect(function(character)
                -- Wait for physics to settle and parts to replicate
                task.wait(0.75)
                if not hitboxExtenderEnabled then return end
                originalSizes[player] = nil -- fresh character, clear stale data
                SaveOriginalSizes(player, character)
                ApplyHitbox(character)
            end)
            if not hitboxExtenderConnections[player] then
                hitboxExtenderConnections[player] = {}
            end
            table.insert(hitboxExtenderConnections[player], conn)

            -- Also reset originals when character is removed (they respawn fresh)
            local remConn = player.CharacterRemoving:Connect(function()
                originalSizes[player] = nil
            end)
            table.insert(hitboxExtenderConnections[player], remConn)
        end
    end

    -- Hook players who join mid-session
    local playerAddedConn = Players.PlayerAdded:Connect(function(player)
        if player == LocalPlayer then return end
        -- Hook their character spawns
        local conn = player.CharacterAdded:Connect(function(character)
            task.wait(0.75)
            if not hitboxExtenderEnabled then return end
            originalSizes[player] = nil
            SaveOriginalSizes(player, character)
            ApplyHitbox(character)
        end)
        local remConn = player.CharacterRemoving:Connect(function()
            originalSizes[player] = nil
        end)
        if not hitboxExtenderConnections[player] then
            hitboxExtenderConnections[player] = {}
        end
        table.insert(hitboxExtenderConnections[player], conn)
        table.insert(hitboxExtenderConnections[player], remConn)
        -- They might already have a character
        task.wait(0.75)
        SetupPlayer(player)
    end)
    table.insert(hitboxExtenderConnections, playerAddedConn)
end

local function DisableHitboxExtender()
    if not hitboxExtenderEnabled then return end
    hitboxExtenderEnabled = false

    -- Reset all players back to true originals
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            ResetPlayerHitbox(player)
        end
    end

    -- Disconnect everything
    for _, conn in pairs(hitboxExtenderConnections) do
        if type(conn) == "table" then
            for _, subConn in pairs(conn) do
                pcall(function() subConn:Disconnect() end)
            end
        else
            pcall(function() conn:Disconnect() end)
        end
    end
    hitboxExtenderConnections = {}
end

-- Called by the slider — re-applies current size to all live characters
-- without touching originalSizes (originals are never overwritten).
local function RefreshAllHitboxes()
    if not hitboxExtenderEnabled then return end
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            ApplyHitbox(player.Character)
        end
    end
end

-- =====================
-- AIMBOT (Doc 1)
-- Uses mousemoverel for relative mouse delta to snap onto target
-- =====================

local function GetClosestPlayer()
    local hrp = GetHRP()
    if not hrp then return nil end
    local closestPlayer = nil
    local closestDistance = aimbotRange
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local character = player.Character
            if character and character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0 then
                local targetHRP = character:FindFirstChild("HumanoidRootPart")
                if targetHRP then
                    local distance = (hrp.Position - targetHRP.Position).Magnitude
                    if distance < closestDistance then
                        closestDistance = distance
                        closestPlayer = player
                    end
                end
            end
        end
    end
    return closestPlayer
end

-- mousemoverel wrapper — tries the executor global first, falls back to VirtualInputGame
local function MoveMouseRel(deltaX, deltaY)
    if mousemoverel then
        pcall(mousemoverel, deltaX, deltaY)
    else
        pcall(function()
            local VirtualInput = game:GetService("VirtualInputGame")
            local mouse = LocalPlayer:GetMouse()
            local newPos = Vector2.new(mouse.X + deltaX, mouse.Y + deltaY)
            VirtualInput:SendMouseMoveEvent(newPos)
        end)
    end
end

local function Aimbot()
    if not aimbotEnabled then return end
    local target = GetClosestPlayer()
    if not target then return end
    local character = target.Character
    if not character then return end
    local targetHRP = character:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end
    local mouse = LocalPlayer:GetMouse()
    local targetPos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(targetHRP.Position)
    if onScreen then
        MoveMouseRel(targetPos.X - mouse.X, targetPos.Y - mouse.Y)
    end
end

local function EnableAimbot()
    aimbotEnabled = true
    if aimbotConnection then aimbotConnection:Disconnect() end
    aimbotConnection = RunService.RenderStepped:Connect(Aimbot)
    Rayfield:Notify({ Title = "Aimbot", Content = "Enabled! Press X to disable.", Duration = 3, Image = "target" })
end

local function DisableAimbot()
    aimbotEnabled = false
    if aimbotConnection then
        aimbotConnection:Disconnect()
        aimbotConnection = nil
    end
    Rayfield:Notify({ Title = "Aimbot", Content = "Disabled.", Duration = 2, Image = "shield" })
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.X then
        if aimbotEnabled then DisableAimbot() else EnableAimbot() end
    end
end)

-- =====================
--      KILL AURA
-- =====================

local function GetAllToolsForAttack()
    local char = GetChar()
    local tools = {}
    if char then
        for _, child in pairs(char:GetChildren()) do
            if child:IsA("Tool") and child:FindFirstChild("Handle") and not BLACKLISTED_TOOLS[child.Name] then
                table.insert(tools, child)
            end
        end
    end
    for _, child in pairs(LocalPlayer.Backpack:GetChildren()) do
        if child:IsA("Tool") and child:FindFirstChild("Handle") and not BLACKLISTED_TOOLS[child.Name] then
            table.insert(tools, child)
        end
    end
    return tools
end

local function GetNearestPlayer()
    local hrp = GetHRP()
    if not hrp then return nil end
    local nearest, nearestDist = nil, math.huge
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local character = player.Character
            if character and character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0 then
                local targetHRP = character:FindFirstChild("HumanoidRootPart")
                if targetHRP then
                    local dist = (hrp.Position - targetHRP.Position).Magnitude
                    if dist < nearestDist then
                        nearestDist = dist
                        nearest = player
                    end
                end
            end
        end
    end
    return nearest
end

local function AttackTarget(targetPlayer)
    if not targetPlayer then return false end
    local character = targetPlayer.Character
    if not character then return false end
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    if not head then return false end
    local hrp = GetHRP()
    if not hrp then return false end
    local origin = hrp.CFrame
    TeleportTo(CFrame.new(head.Position) + Vector3.new(0, 2, 0))
    task.wait(0.05)
    local tools = GetAllToolsForAttack()
    for _, tool in ipairs(tools) do
        pcall(function()
            local char = GetChar()
            if char then
                char.Humanoid:EquipTool(tool)
                task.wait(0.01)
                tool:Activate()
            end
        end)
        task.wait(0.03)
    end
    TeleportTo(origin)
    return humanoid.Health > 0
end

local function KillAura()
    if not killauraEnabled then return end
    if currentTarget then
        local character = currentTarget.Character
        local humanoid = character and character:FindFirstChild("Humanoid")
        if not character or not humanoid or humanoid.Health <= 0 then
            currentTarget = nil
        end
    end
    if not currentTarget then
        currentTarget = GetNearestPlayer()
    end
    if currentTarget then
        AttackTarget(currentTarget)
        task.wait(0.1)
    end
end

local function EnableKillAura()
    killauraEnabled = true
    currentTarget = nil
    if killauraConnection then killauraConnection:Disconnect() end
    killauraConnection = RunService.RenderStepped:Connect(KillAura)
    Rayfield:Notify({ Title = "Kill Aura", Content = "Enabled! Targeting nearest player until death!", Duration = 3, Image = "sword" })
end

local function DisableKillAura()
    killauraEnabled = false
    currentTarget = nil
    if killauraConnection then
        killauraConnection:Disconnect()
        killauraConnection = nil
    end
    Rayfield:Notify({ Title = "Kill Aura", Content = "Disabled.", Duration = 2, Image = "shield" })
end

-- =====================
--    F KEY — ALL TOOLS
-- =====================

local function GetAllTools()
    local char = GetChar()
    local tools = {}
    if char then
        for _, child in pairs(char:GetChildren()) do
            if child:IsA("Tool") and child:FindFirstChild("Handle") and not BLACKLISTED_TOOLS[child.Name] then
                table.insert(tools, child)
            end
        end
    end
    for _, child in pairs(LocalPlayer.Backpack:GetChildren()) do
        if child:IsA("Tool") and child:FindFirstChild("Handle") and not BLACKLISTED_TOOLS[child.Name] then
            table.insert(tools, child)
        end
    end
    return tools
end

local function EquipAndAttackAllTools()
    if isAttacking then return end
    isAttacking = true
    local char = GetChar()
    if not char then isAttacking = false return end
    local tools = GetAllTools()
    if #tools == 0 then
        Rayfield:Notify({ Title = "Equip All", Content = "No tools found.", Duration = 3, Image = "alert-circle" })
        isAttacking = false
        return
    end
    for _, tool in ipairs(tools) do
        pcall(function() tool.Parent = char end)
    end
    task.wait(0.05)
    for _, conn in ipairs(equipAllConnections) do
        pcall(function() conn:Disconnect() end)
    end
    equipAllConnections = {}
    for _, tool in ipairs(tools) do
        local conn = tool.AncestryChanged:Connect(function()
            if tool.Parent == LocalPlayer.Backpack then
                pcall(function() tool.Parent = char end)
            end
        end)
        table.insert(equipAllConnections, conn)
    end
    for _, tool in ipairs(tools) do
        task.spawn(function()
            pcall(function()
                char.Humanoid:EquipTool(tool)
                task.wait(0.01)
                tool:Activate()
            end)
        end)
    end
    Rayfield:Notify({ Title = "Equip All", Content = "All " .. #tools .. " tools equipped and attacking!", Duration = 2, Image = "zap" })
    task.wait(0.1)
    isAttacking = false
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F then
        EquipAndAttackAllTools()
    end
end)

-- =====================
--       UI — MAIN TAB
-- =====================

local Tab1 = Window:CreateTab("Main", "map-pin")

Tab1:CreateSection("Combat")

Tab1:CreateToggle({
    Name = "Aimbot (Press X to toggle)",
    CurrentValue = false,
    Flag = "AimbotToggle",
    Callback = function(Value)
        if Value then EnableAimbot() else DisableAimbot() end
    end
})

Tab1:CreateToggle({
    Name = "Kill Aura (Target until death)",
    CurrentValue = false,
    Flag = "KillAuraToggle",
    Callback = function(Value)
        if Value then EnableKillAura() else DisableKillAura() end
    end
})

Tab1:CreateToggle({
    Name = "Hitbox Extender",
    CurrentValue = false,
    Flag = "HitboxToggle",
    Callback = function(Value)
        if Value then
            EnableHitboxExtender()
            Rayfield:Notify({ Title = "Hitbox Extender", Content = "Enabled! Size: " .. hitboxSize, Duration = 3, Image = "target" })
        else
            DisableHitboxExtender()
            Rayfield:Notify({ Title = "Hitbox Extender", Content = "Disabled.", Duration = 2, Image = "shield" })
        end
    end
})

Tab1:CreateSlider({
    Name = "Hitbox Size (5-100)",
    Range = {5, 100},
    Increment = 1,
    CurrentValue = 15,
    Flag = "HitboxSize",
    Callback = function(Value)
        hitboxSize = Value
        RefreshAllHitboxes()
        if hitboxExtenderEnabled then
            Rayfield:Notify({ Title = "Hitbox Size", Content = "Updated to " .. hitboxSize, Duration = 1, Image = "square" })
        end
    end
})

Tab1:CreateSlider({
    Name = "Aimbot Range",
    Range = {50, 500},
    Increment = 10,
    CurrentValue = 100,
    Flag = "AimbotRange",
    Callback = function(Value)
        aimbotRange = Value
    end
})

Tab1:CreateSection("Teleport")

local DESTINATIONS = {
    ["Bank"]        = CFrame.new(-563.517029, 13.6589241, -113.084167),
    ["Museum"]      = CFrame.new(-44.517025,  13.6589012,  -83.5842743),
    ["Apothecary"]  = CFrame.new(-662.517029, 13.6589241, -270.584198),
    ["Itemstore"]   = CFrame.new(-403.517059, 13.6589241,   -0.084186554),
    ["Armoury"]     = CFrame.new(-420.017029, 13.6588936, -250.084198),
    ["Dresser"]     = CFrame.new(-983.516785, 13.1588478,  -19.0836525),
    ["Blackmarket"] = CFrame.new(-1042.01709, 13.1587105, -223.083252),
    ["Secret"]      = CFrame.new(-187, 198, 225),
}

Tab1:CreateDropdown({
    Name = "Teleports",
    Options = { "Bank", "Museum", "Apothecary", "Itemstore", "Armoury", "Dresser", "Blackmarket", "Secret" },
    CurrentOption = {"Bank"},
    MultipleOptions = false,
    Flag = "TeleportDropdown",
    Callback = function(Options)
        local dest = DESTINATIONS[Options[1]]
        if dest then Tween(dest) end
    end
})

Tab1:CreateSection("Excalibur")

Tab1:CreateButton({
    Name = "Replica Excalibur",
    Callback = function()
        local hrp = GetHRP()
        if not hrp then return end
        local origin = hrp.CFrame
        TeleportTo(CFrame.new(-410.26709, -26.9660759, -58.9592018))
        local timeout = 0
        repeat
            task.wait(0.1)
            timeout += 0.1
            pcall(function()
                fireproximityprompt(Workspace["golden trash pile"].trashcore.ProximityPrompt)
            end)
        until (GetChar() and GetChar():FindFirstChild("Excalibur")) or timeout > 15
        TeleportTo(origin)
        if GetChar() and GetChar():FindFirstChild("Excalibur") then
            Rayfield:Notify({ Title = "Excalibur", Content = "Excalibur obtained!", Duration = 4, Image = "sword" })
        else
            Rayfield:Notify({ Title = "Excalibur", Content = "Timed out — try again.", Duration = 4, Image = "alert-circle" })
        end
    end
})

Tab1:CreateSection("Auto Collect")

Tab1:CreateToggle({
    Name = "Moneybags",
    CurrentValue = false,
    Flag = "MoneybagToggle",
    Callback = function(Value)
        getgenv().Moneybags = Value
        if Value then
            for _, v in pairs(Workspace:GetChildren()) do
                if v.Name == "moneybag" then
                    local part = v:IsA("BasePart") and v or v:FindFirstChildWhichIsA("BasePart")
                    if part and part.Anchored then v:Destroy() end
                end
            end
        end
        while getgenv().Moneybags do
            task.wait(0.05)
            local hrp = GetHRP()
            if hrp then
                local origin = hrp.CFrame
                local collected = false
                for _, v in pairs(Workspace:GetChildren()) do
                    if v.Name == "moneybag" then
                        local bagPart = v:IsA("BasePart") and v or v:FindFirstChildWhichIsA("BasePart")
                        if bagPart then
                            TeleportTo(CFrame.new(bagPart.Position) + Vector3.new(0, 2, 0))
                            task.wait(0.05)
                            firetouchinterest(hrp, v, 0)
                            firetouchinterest(hrp, v, 1)
                            collected = true
                        end
                    end
                end
                if collected and getgenv().Moneybags then TeleportTo(origin) end
            end
        end
    end
})

Tab1:CreateToggle({
    Name = "Auto Grab Tools",
    CurrentValue = false,
    Flag = "ToolsToggle",
    Callback = function(Value)
        getgenv().Tools = Value
        while getgenv().Tools do
            task.wait()
            local char = GetChar()
            local hrp = GetHRP()
            if char and hrp then
                local origin = hrp.CFrame
                for _, v in pairs(Workspace:GetChildren()) do
                    if v:IsA("BackpackItem") and v:FindFirstChild("Handle") and v.Name ~= "leech" and v.Name ~= "Broom" then
                        TeleportTo(CFrame.new(v.Handle.Position) + Vector3.new(0, 2, 0))
                        task.wait(0.05)
                        char.Humanoid:EquipTool(v)
                    end
                end
                TeleportTo(origin)
            end
        end
    end
})

Tab1:CreateSection("Safety")

Tab1:CreateButton({
    Name = "Void (teleport to 0,0,0)",
    Callback = function()
        Tween(CFrame.new(0, 0, 0))
    end
})

-- =====================
--     FINANCE TAB
-- =====================

local Tab2 = Window:CreateTab("Finance", "coins")

Tab2:CreateSection("Auto Craft")

Tab2:CreateParagraph({
    Title = "Instructions",
    Content = "Costs 8 shillings to buy. Press Buy, Craft (Wave System), then Sell."
})

Tab2:CreateButton({
    Name = "Buy (8 shillings)",
    Callback = function()
        local char = GetChar()
        local hrp = GetHRP()
        if not char or not hrp then return end
        if char.shillings.Value < 8 then
            Rayfield:Notify({ Title = "Buy", Content = "Not enough shillings! You need 8.", Duration = 4, Image = "alert-circle" })
            return
        end
        local promptPart = SafeGet(function() return Workspace.buyprompts.items["economy shop"].buypromptD end)
        if not promptPart then
            Rayfield:Notify({ Title = "Buy", Content = "buypromptD not found.", Duration = 3, Image = "alert-circle" })
            return
        end
        local prompt = promptPart:FindFirstChildWhichIsA("ProximityPrompt")
        if not prompt then
            Rayfield:Notify({ Title = "Buy", Content = "ProximityPrompt not found.", Duration = 3, Image = "alert-circle" })
            return
        end
        local origin = hrp.CFrame
        TeleportTo(CFrame.new(promptPart.Position) + Vector3.new(0, 3, 0))
        task.wait(0.2)
        local timeout = 0
        repeat
            task.wait(0.1)
            timeout += 0.1
            pcall(function() fireproximityprompt(prompt) end)
        until char.shillings.Value <= 0 or timeout > 30
        TeleportTo(origin)
        Rayfield:Notify({ Title = "Buy", Content = "Done buying.", Duration = 3, Image = "shopping-cart" })
    end
})

Tab2:CreateButton({
    Name = "Craft (Wave System)",
    Callback = function()
        local char = GetChar()
        local hrp = GetHRP()
        if not char or not hrp then return end
        local origin = hrp.CFrame
        for _, v in pairs(LocalPlayer.Backpack:GetChildren()) do
            if v:IsA("Tool") and Find(v.Name, {"unfin", "unfinished"}) then
                v.Parent = char
            end
        end
        local unfinishedItems = GetUnfinishedFlintlocks()
        if #unfinishedItems == 0 then
            Rayfield:Notify({ Title = "Craft", Content = "No unfinished flintlocks found.", Duration = 3, Image = "alert-circle" })
            return
        end
        local _, partA = GetWorkbench("WorkbenchA")
        local _, partB = GetWorkbench("WorkbenchB")
        local _, partC = GetWorkbench("WorkbenchC")
        local _, partD = GetWorkbench("WorkbenchD")
        local benches = {}
        if partA then table.insert(benches, partA) end
        if partB then table.insert(benches, partB) end
        if partC then table.insert(benches, partC) end
        if partD then table.insert(benches, partD) end
        if #benches == 0 then
            Rayfield:Notify({ Title = "Craft", Content = "No workbench found.", Duration = 3, Image = "alert-circle" })
            TeleportTo(origin)
            return
        end
        local craftCount, maxAttempts = 0, 30
        while #GetUnfinishedFlintlocks() > 0 and craftCount < maxAttempts do
            craftCount += 1
            for _, bench in ipairs(benches) do
                local currentUnfinished = GetUnfinishedFlintlocks()
                if #currentUnfinished == 0 then break end
                TeleportTo(CFrame.new(bench.Position) + Vector3.new(0, 3, 0))
                task.wait(0.4)
                for _, item in ipairs(currentUnfinished) do
                    if not item or not item.Parent then continue end
                    pcall(function()
                        char.Humanoid:EquipTool(item)
                        task.wait(0.15)
                        firetouchinterest(bench, item.Handle, 0)
                        task.wait(0.1)
                        firetouchinterest(bench, item.Handle, 1)
                    end)
                    task.wait(0.2)
                end
                task.wait(0.5)
            end
            task.wait(0.3)
        end
        TeleportTo(origin)
        local remaining = GetUnfinishedFlintlocks()
        if #remaining > 0 then
            Rayfield:Notify({ Title = "Craft", Content = #remaining .. " flintlocks remain uncrafted.", Duration = 5, Image = "alert-circle" })
        else
            Rayfield:Notify({ Title = "Craft", Content = "All unfinished flintlocks crafted!", Duration = 3, Image = "hammer" })
        end
    end
})

Tab2:CreateButton({
    Name = "Sell",
    Callback = function()
        local char = GetChar()
        local hrp = GetHRP()
        if not char or not hrp then return end
        local origin = hrp.CFrame
        local sellPart = nil
        for _, v in pairs(Workspace:GetDescendants()) do
            if v.Name == "sellweapon" and v:IsA("BasePart") then sellPart = v break end
        end
        if not sellPart then
            Rayfield:Notify({ Title = "Sell", Content = "Sell pad not found.", Duration = 3, Image = "alert-circle" })
            return
        end
        local sellPrompt = sellPart:FindFirstChildWhichIsA("ProximityPrompt")
        if not sellPrompt then
            Rayfield:Notify({ Title = "Sell", Content = "Sell prompt not found.", Duration = 3, Image = "alert-circle" })
            return
        end
        local sellableWeapons = {}
        for _, src in pairs({char, LocalPlayer.Backpack}) do
            for _, v in pairs(src:GetChildren()) do
                if v:IsA("Tool") and v:FindFirstChild("Handle") then
                    local name = v.Name:lower()
                    if (name:find("flintlock") or name:find("flint") or name:find("shortsword"))
                        and not name:find("unfin") and not name:find("unfinished") then
                        table.insert(sellableWeapons, v)
                    end
                end
            end
        end
        if #sellableWeapons == 0 then
            Rayfield:Notify({ Title = "Sell", Content = "No sellable weapons found!", Duration = 3, Image = "alert-circle" })
            return
        end
        for _, weapon in ipairs(sellableWeapons) do
            pcall(function() if weapon.Parent ~= char then weapon.Parent = char end end)
        end
        task.wait(0.1)
        TeleportTo(CFrame.new(sellPart.Position) + Vector3.new(0, 3, 0))
        task.wait(0.3)
        for _, weapon in ipairs(sellableWeapons) do
            if weapon and weapon.Parent == char and weapon:FindFirstChild("Handle") then
                pcall(function()
                    char.Humanoid:EquipTool(weapon)
                    task.wait(0.1)
                    firetouchinterest(sellPart, weapon.Handle, 0)
                    task.wait(0.1)
                    firetouchinterest(sellPart, weapon.Handle, 1)
                    task.wait(0.1)
                    fireproximityprompt(sellPrompt)
                end)
                task.wait(0.2)
            end
        end
        task.wait(0.2)
        TeleportTo(origin)
        Rayfield:Notify({ Title = "Sell", Content = "Sold " .. #sellableWeapons .. " weapons!", Duration = 3, Image = "banknote" })
    end
})

Tab2:CreateSection("Fast Buy")

Tab2:CreateButton({
    Name = "Buy 1 Doc Bag (2 shill)",
    Callback = function()
        local char = GetChar()
        if not char then return end
        if char.shillings.Value < 2 then
            Rayfield:Notify({ Title = "Fast Buy", Content = "Not enough shillings!", Duration = 3, Image = "alert-circle" })
            return
        end
        local promptPart = SafeGet(function() return Workspace.buyprompts.items.mix["hospital shop"].buypromptbag end)
        if not promptPart then
            Rayfield:Notify({ Title = "Fast Buy", Content = "Hospital shop not found.", Duration = 3, Image = "alert-circle" })
            return
        end
        local prompt = promptPart:FindFirstChildWhichIsA("ProximityPrompt")
        if not prompt then
            Rayfield:Notify({ Title = "Fast Buy", Content = "Prompt not found.", Duration = 3, Image = "alert-circle" })
            return
        end
        TeleportDoReturn(CFrame.new(promptPart.Position) + Vector3.new(0, 3, 0), function() pcall(function() fireproximityprompt(prompt) end) end, 0.3)
    end
})

Tab2:CreateButton({
    Name = "Buy 1 Knife (5 pence)",
    Callback = function()
        local char = GetChar()
        if not char then return end
        if char.pence.Value < 5 then
            Rayfield:Notify({ Title = "Fast Buy", Content = "Not enough pence!", Duration = 3, Image = "alert-circle" })
            return
        end
        local promptPart = SafeGet(function() return Workspace.buyprompts.items["melee shop"].buypromptA end)
        if not promptPart then
            Rayfield:Notify({ Title = "Fast Buy", Content = "Melee shop not found.", Duration = 3, Image = "alert-circle" })
            return
        end
        local prompt = promptPart:FindFirstChildWhichIsA("ProximityPrompt")
        if not prompt then
            Rayfield:Notify({ Title = "Fast Buy", Content = "Prompt not found.", Duration = 3, Image = "alert-circle" })
            return
        end
        TeleportDoReturn(CFrame.new(promptPart.Position) + Vector3.new(0, 3, 0), function() pcall(function() fireproximityprompt(prompt) end) end, 0.3)
    end
})

Tab2:CreateButton({
    Name = "Buy 1 Torch (5 pence)",
    Callback = function()
        local char = GetChar()
        if not char then return end
        if char.pence.Value < 5 then
            Rayfield:Notify({ Title = "Fast Buy", Content = "Not enough pence!", Duration = 3, Image = "alert-circle" })
            return
        end
        local promptPart = nil
        for _, v in pairs(Workspace:GetDescendants()) do
            if v.Name == "buypromptI" and v:IsA("BasePart") then promptPart = v break end
        end
        if not promptPart then
            Rayfield:Notify({ Title = "Fast Buy", Content = "buypromptI not found.", Duration = 3, Image = "alert-circle" })
            return
        end
        local prompt = promptPart:FindFirstChildWhichIsA("ProximityPrompt")
        if not prompt then
            Rayfield:Notify({ Title = "Fast Buy", Content = "Prompt not found.", Duration = 3, Image = "alert-circle" })
            return
        end
        TeleportDoReturn(CFrame.new(promptPart.Position) + Vector3.new(0, 3, 0), function() pcall(function() fireproximityprompt(prompt) end) end, 0.3)
    end
})

-- =====================
--       MISC TAB
-- =====================

local Tab3 = Window:CreateTab("Misc", "wrench")

Tab3:CreateSection("Player")

Tab3:CreateButton({
    Name = "Water Immunity",
    Callback = function()
        local char = GetChar()
        if not char then return end
        local calc = char:FindFirstChild("healthcalculator")
        if calc and calc:FindFirstChild("armor") then
            calc.armor:Destroy()
            Rayfield:Notify({ Title = "Water Immunity", Content = "Immune to water/leeches until respawn.", Duration = 4, Image = "shield" })
        else
            Rayfield:Notify({ Title = "Water Immunity", Content = "Already immune or armor not found.", Duration = 3, Image = "alert-circle" })
        end
    end
})

Tab3:CreateButton({
    Name = "No Jump Cooldown",
    Callback = function()
        getgenv().NoJumpCD = true
        while getgenv().NoJumpCD do
            task.wait()
            local char = GetChar()
            if char and char:FindFirstChild("Humanoid") then
                char.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
            end
        end
    end
})

Tab3:CreateButton({
    Name = "No Screen Effects",
    Callback = function()
        local healthgui = LocalPlayer.PlayerGui:FindFirstChild("healthgui")
        if not healthgui then
            Rayfield:Notify({ Title = "Screen Effects", Content = "healthgui not found.", Duration = 3, Image = "alert-circle" })
            return
        end
        local removed = false
        for _, name in pairs({"chills", "poopoo"}) do
            local effect = healthgui:FindFirstChild(name)
            if effect then effect:Destroy() removed = true end
        end
        if removed then
            Rayfield:Notify({ Title = "Screen Effects", Content = "Removed until next respawn.", Duration = 4, Image = "eye-off" })
        else
            Rayfield:Notify({ Title = "Screen Effects", Content = "No active screen effects found.", Duration = 3, Image = "alert-circle" })
        end
    end
})

-- =====================
--       NUKE TAB
-- =====================

local Tab4 = Window:CreateTab("NUKE", "bomb")

Tab4:CreateSection("Nuke the server")

Tab4:CreateParagraph({
    Title = "Warning",
    Content = "Spends all your shillings on grenades. Make sure you have 5+ shillings."
})

Tab4:CreateButton({
    Name = "Buy grenades until broke",
    Callback = function()
        local char = GetChar()
        local hrp = GetHRP()
        if not char or not hrp then return end
        if char.shillings.Value < 5 then
            Rayfield:Notify({ Title = "Nuke", Content = "Not enough shillings (need 5+).", Duration = 3, Image = "alert-circle" })
            return
        end
        local promptPart = nil
        local meleeShop = SafeGet(function() return Workspace.buyprompts.items["melee shop"] end)
        if meleeShop then
            for _, v in pairs(meleeShop:GetChildren()) do
                if v.Name == "buypromptF" and v:IsA("BasePart") then promptPart = v break end
            end
        end
        if not promptPart then
            for _, v in pairs(Workspace:GetDescendants()) do
                if v.Name == "buypromptF" and v:IsA("BasePart") then promptPart = v break end
            end
        end
        if not promptPart then
            Rayfield:Notify({ Title = "Nuke", Content = "Grenade prompt not found.", Duration = 3, Image = "alert-circle" })
            return
        end
        local prompt = promptPart:FindFirstChildWhichIsA("ProximityPrompt")
        if not prompt then
            Rayfield:Notify({ Title = "Nuke", Content = "ProximityPrompt not found.", Duration = 3, Image = "alert-circle" })
            return
        end
        local origin = hrp.CFrame
        TeleportTo(CFrame.new(promptPart.Position) + Vector3.new(0, 3, 0))
        task.wait(0.2)
        local initialShillings = char.shillings.Value
        repeat
            task.wait(0.1)
            pcall(function() fireproximityprompt(prompt) end)
            task.wait(0.05)
        until char.shillings.Value < 5
        TeleportTo(origin)
        Rayfield:Notify({ Title = "Nuke", Content = "Spent " .. (initialShillings - char.shillings.Value) .. " shillings on grenades!", Duration = 4, Image = "bomb" })
    end
})

-- =====================
--      SCRIPTS TAB
-- =====================

local Tab5 = Window:CreateTab("Scripts", "terminal")

Tab5:CreateSection("Infinite Yield")

Tab5:CreateButton({
    Name = "Execute Infinite Yield",
    Callback = function()
        local ok, code = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source")
        if ok then
            local fn, err = loadstring(code)
            if fn then
                fn()
                Rayfield:Notify({ Title = "Scripts", Content = "Infinite Yield loaded.", Duration = 3, Image = "terminal" })
            else
                Rayfield:Notify({ Title = "Scripts", Content = "Load error: " .. tostring(err), Duration = 5, Image = "alert-circle" })
            end
        else
            Rayfield:Notify({ Title = "Scripts", Content = "Fetch failed.", Duration = 4, Image = "alert-circle" })
        end
    end
})

Tab5:CreateSection("Click TP")

Tab5:CreateButton({
    Name = "Equip Click TP Tool",
    Callback = function()
        if LocalPlayer.Backpack:FindFirstChild("Equip to Click TP") then
            Rayfield:Notify({ Title = "Click TP", Content = "Tool already in backpack.", Duration = 3, Image = "alert-circle" })
            return
        end
        local tool = Instance.new("Tool")
        tool.RequiresHandle = false
        tool.Name = "Equip to Click TP"
        tool.Activated:Connect(function()
            local mouse = LocalPlayer:GetMouse()
            local pos = mouse.Hit + Vector3.new(0, 2.5, 0)
            local hrp = GetHRP()
            if hrp then hrp.CFrame = CFrame.new(pos.X, pos.Y, pos.Z) end
        end)
        tool.Parent = LocalPlayer.Backpack
        Rayfield:Notify({ Title = "Click TP", Content = "Tool added. Equip it and click to teleport.", Duration = 4, Image = "mouse-pointer-click" })
    end
})

-- =====================
--      CREDITS TAB
-- =====================

local Tab6 = Window:CreateTab("Credits", "info")

Tab6:CreateSection("Info")

Tab6:CreateParagraph({ Title = "Made by",       Content = "Your Typical Exploiter" })
Tab6:CreateParagraph({ Title = "Original idea", Content = "Dave" })
Tab6:CreateParagraph({ Title = "Toggle UI",     Content = "Press K to show/hide." })
Tab6:CreateParagraph({ Title = "F Key Attack",  Content = "Press F to equip and attack with all tools at once!" })
Tab6:CreateParagraph({ Title = "X Key Aimbot",  Content = "Press X to toggle aimbot on/off!" })
Tab6:CreateParagraph({ Title = "Kill Aura",     Content = "Targets nearest player until death!" })
Tab6:CreateParagraph({ Title = "Hitbox Extender", Content = "Expands player hitboxes up to size 100. Resets on disable." })

Tab6:CreateButton({
    Name = "Destroy GUI",
    Callback = function()
        DisableHitboxExtender()
        DisableAimbot()
        DisableKillAura()
        Rayfield:Destroy()
    end
})

Tab6:CreateButton({
    Name = "Equip All Tools (Same as F Key)",
    Callback = function()
        EquipAndAttackAllTools()
    end
})

Rayfield:Notify({
    Title = "Fusion (Hub)",
    Content = "Loaded! F = all tools | X = aimbot | Hitbox up to size 100",
    Duration = 5,
    Image = "check-circle",
})

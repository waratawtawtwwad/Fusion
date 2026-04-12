local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua'))()

local Window = Rayfield:CreateWindow({
    Name = "Fusion v1",
    Icon = 0,
    LoadingTitle = "Fusion v1",
    LoadingSubtitle = "by Your Typical Exploiter",
    Theme = "Default",
    ToggleUIKeybind = "K",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings = false,
    ConfigurationSaving = {
        Enabled = false,
        FolderName = nil,
        FileName = "Fusion"
    },
    Discord = {
        Enabled = false,
        Invite = "noinvitelink",
        RememberJoins = true
    },
    KeySystem = false
})

local Players      = game:GetService("Players")
local Workspace    = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer  = Players.LocalPlayer

-- BLACKLISTED TOOLS (won't be used in F key attack)
local BLACKLISTED_TOOLS = {
    ["Equip to Click TP"] = true,
    ["doctor's bag"] = true,
    ["leech"] = true,
    ["Broom"] = true,
    ["Excalibur"] = false, -- Set to true if you want to blacklist Excalibur
}

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

local function HasUnfinished()
    local char = GetChar()
    if not char then return false end
    for _, item in pairs(char:GetChildren()) do
        if Find(item.Name, {"unfin"}) then return true end
    end
    return false
end

pcall(function()
    local char = GetChar()
    for _, v in pairs(char:GetChildren()) do
        if v.Name == "anticheatcooldown" then v:Destroy() end
    end
    char.Humanoid.Died:Connect(function()
        local tbp = char:WaitForChild("anticheatcooldown", 5)
        if tbp then tbp:Destroy() end
    end)
end)

pcall(function()
    game:GetService("ProximityPromptService").PromptButtonHoldBegan:Connect(function(prompt)
        fireproximityprompt(prompt)
    end)
end)

-- ========== F KEY - ATTACK ALL TOOLS AT ONCE (EXCLUDING BLACKLISTED) ==========
local isAttacking = false

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

local function AttackAllToolsAtOnce()
    if isAttacking then return end
    isAttacking = true
    
    local char = GetChar()
    if not char then 
        isAttacking = false
        return 
    end
    
    local tools = GetAllTools()
    if #tools == 0 then
        isAttacking = false
        return
    end
    
    -- Move ALL tools to character FIRST
    for _, tool in ipairs(tools) do
        pcall(function()
            if tool.Parent ~= char then
                tool.Parent = char
            end
        end)
    end
    
    task.wait(0.05)
    
    -- Attack with EVERY tool simultaneously using threads
    local threads = {}
    for _, tool in ipairs(tools) do
        table.insert(threads, task.spawn(function()
            pcall(function()
                char.Humanoid:EquipTool(tool)
                task.wait(0.01)
                tool:Activate()
            end)
        end))
    end
    
    -- Wait for all attacks to trigger
    for _, thread in ipairs(threads) do
        task.wait(0)
    end
    
    task.wait(0.1)
    isAttacking = false
end

-- Bind F key to attack with ALL tools at once
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F then
        AttackAllToolsAtOnce()
    end
end)

local Tab1 = Window:CreateTab("Main JK", "map-pin")

Tab1:CreateSection("Teleport")

local DESTINATIONS = {
    ["Bank"]        = CFrame.new(-563.517029, 13.6589241, -113.084167, 0, 0, 1, 0, 1, 0, -1, 0, 0),
    ["Museum"]      = CFrame.new(-44.517025,  13.6589012, -83.5842743, 0, 0, 1, 0, 1, 0, -1, 0, 0),
    ["Apothecary"]  = CFrame.new(-662.517029, 13.6589241, -270.584198, -1, 0, 0, 0, 1, 0, 0, 0, -1),
    ["Itemstore"]   = CFrame.new(-403.517059, 13.6589241, -0.084186554, 1, 0, 0, 0, 1, 0, 0, 0, 1),
    ["Armoury"]     = CFrame.new(-420.017029, 13.6588936, -250.084198, 0, 0, 1, 0, 1, 0, -1, 0, 0),
    ["Dresser"]     = CFrame.new(-983.516785, 13.1588478, -19.0836525, 0, 0, -1, 0, 1, 0, 1, 0, 0),
    ["Blackmarket"] = CFrame.new(-1042.01709, 13.1587105, -223.083252, 0, 0, 1, 0, 1, 0, -1, 0, 0),
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
                    if part and part.Anchored then
                        v:Destroy()
                    end
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
                if collected and getgenv().Moneybags then
                    TeleportTo(origin)
                end
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
                    if
                        v:IsA("BackpackItem") and
                        v:FindFirstChild("Handle") and
                        v.Name ~= "leech" and
                        v.Name ~= "Broom"
                    then
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

local Tab2 = Window:CreateTab("Finance", "coins")

Tab2:CreateSection("Auto Craft")

Tab2:CreateParagraph({
    Title = "Instructions",
    Content = "Costs 8 shillings to buy. Press Buy, Craft (Wave Effect), then Sell."
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

        local promptPart = SafeGet(function()
            return Workspace.buyprompts.items["economy shop"].buypromptD
        end)
        if not promptPart then
            Rayfield:Notify({ Title = "Buy", Content = "buypromptD not found in buyprompts/items/economy shop.", Duration = 3, Image = "alert-circle" })
            return
        end

        local prompt = promptPart:FindFirstChildWhichIsA("ProximityPrompt")
        if not prompt then
            Rayfield:Notify({ Title = "Buy", Content = "ProximityPrompt not found on buypromptD.", Duration = 3, Image = "alert-circle" })
            return
        end

        Rayfield:Notify({ Title = "Buy", Content = "Buying with 8 shillings...", Duration = 3, Image = "shopping-cart" })

        local origin = hrp.CFrame
        TeleportTo(CFrame.new(promptPart.Position) + Vector3.new(0, 3, 0))
        task.wait(0.2)

        local timeout = 0
        repeat
            task.wait(0.1)
            timeout += 0.1
            pcall(function() fireproximityprompt(prompt) end)
        until char.shillings.Value <= 0
            or (hrp.Position - promptPart.Position).Magnitude > 25
            or timeout > 30

        TeleportTo(origin)
        Rayfield:Notify({ Title = "Buy", Content = "Done buying.", Duration = 3, Image = "shopping-cart" })
    end
})

-- WAVE CRAFTING SYSTEM - Equips each unfinished tool in sequence like a wave
Tab2:CreateButton({
    Name = "Craft (Wave Effect)",
    Callback = function()
        local backpack = LocalPlayer.Backpack
        local char = GetChar()
        local hrp = GetHRP()
        if not char or not hrp then return end
        local origin = hrp.CFrame

        -- Move unfinished items from backpack to character
        for _, v in pairs(backpack:GetChildren()) do
            if Find(v.Name, {"unfinished"}) then
                v.Parent = char
            end
        end

        for _, v in pairs(backpack:GetChildren()) do
            if v:IsA("Tool") and Find(v.Name, {"flint", "shortsword"}) and not Find(v.Name, {"unfinished", "ammo"}) then
                v.Parent = char
            end
        end

        if not HasUnfinished() then
            Rayfield:Notify({ Title = "Craft", Content = "No unfinished items found.", Duration = 3, Image = "alert-circle" })
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
            Rayfield:Notify({ Title = "Craft", Content = "No workbench found in Workspace.workbenches.", Duration = 3, Image = "alert-circle" })
            TeleportTo(origin)
            return
        end

        local waveCount = 0
        local maxWaves = 20
        local giveUp = false

        while HasUnfinished() and not giveUp do
            waveCount += 1
            if waveCount > maxWaves then
                giveUp = true
                break
            end

            Rayfield:Notify({ Title = "Craft", Content = "Wave " .. waveCount .. "...", Duration = 2, Image = "hammer" })

            for _, bench in ipairs(benches) do
                if not HasUnfinished() then break end

                TeleportTo(CFrame.new(bench.Position) + Vector3.new(0, 3, 0))
                task.wait(0.3)

                -- Get all unfinished items and sort them for wave effect
                local unfinishedItems = {}
                for _, item in pairs(char:GetChildren()) do
                    if Find(item.Name, {"unfin"}) and item:FindFirstChild("Handle") then
                        table.insert(unfinishedItems, item)
                    end
                end

                -- WAVE EFFECT: Equip each tool in sequence with a flowing wave motion
                for waveIndex, item in ipairs(unfinishedItems) do
                    pcall(function()
                        -- Create wave effect by equipping in sequence
                        char.Humanoid:EquipTool(item)
                        task.wait(0.08) -- Small delay between each equip for wave effect
                        
                        -- Touch the bench with the tool
                        firetouchinterest(bench, item.Handle, 0)
                        task.wait(0.05)
                        firetouchinterest(bench, item.Handle, 1)
                        
                        -- Visual wave effect notification
                        if waveIndex % 3 == 0 then
                            Rayfield:Notify({ 
                                Title = "Wave Effect", 
                                Content = "Crafted " .. waveIndex .. "/" .. #unfinishedItems .. " items", 
                                Duration = 1, 
                                Image = "zap" 
                            })
                        end
                    end)
                    task.wait(0.05) -- Wave timing
                end
                
                task.wait(0.2)
            end
        end

        TeleportTo(origin)

        if giveUp then
            Rayfield:Notify({ Title = "Craft", Content = "Max waves reached — some items may not have crafted.", Duration = 5, Image = "alert-circle" })
        else
            Rayfield:Notify({ Title = "Craft", Content = "All items crafted with wave effect!", Duration = 3, Image = "hammer" })
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
            if v.Name == "sellweapon" and v:IsA("BasePart") and v.Rotation == Vector3.new(0, 0, 0) then
                sellPart = v
                break
            end
        end

        if not sellPart then
            Rayfield:Notify({ Title = "Sell", Content = "Sell pad not found.", Duration = 3, Image = "alert-circle" })
            return
        end

        local sellPrompt = sellPart:FindFirstChildWhichIsA("ProximityPrompt")
        if not sellPrompt then
            Rayfield:Notify({ Title = "Sell", Content = "Sell prompt not found on pad.", Duration = 3, Image = "alert-circle" })
            return
        end

        for _, v in pairs(LocalPlayer.Backpack:GetChildren()) do
            if
                v:IsA("Tool") and
                Find(v.Name, {"flint", "shortsword"}) and
                not Find(v.Name, {"unfinished"}) and
                not Find(v.Name, {"ammo"})
            then
                v.Parent = char
            end
        end

        TeleportTo(CFrame.new(sellPart.Position) + Vector3.new(0, 3, 0))
        task.wait(0.3)

        for _, v in pairs(char:GetChildren()) do
            if
                v:IsA("Tool") and
                Find(v.Name, {"flint", "shortsword"}) and
                not Find(v.Name, {"unfinished"}) and
                not Find(v.Name, {"ammo"}) and
                v:FindFirstChild("Handle")
            then
                pcall(function()
                    firetouchinterest(sellPart, v.Handle, 0)
                    task.wait(0.05)
                    firetouchinterest(sellPart, v.Handle, 1)
                end)
                task.wait(0.05)
            end
        end

        local timeout = 0
        repeat
            task.wait(0.1)
            timeout += 0.1
            pcall(function() fireproximityprompt(sellPrompt) end)
            pcall(function()
                firetouchinterest(sellPart, hrp, 0)
                firetouchinterest(sellPart, hrp, 1)
            end)
        until timeout > 5

        task.wait(0.1)
        TeleportTo(origin)
        Rayfield:Notify({ Title = "Sell", Content = "Done selling.", Duration = 3, Image = "banknote" })
    end
})

Tab2:CreateSection("Fast Buy")

Tab2:CreateButton({
    Name = "Buy 1 Doc Bag (2 shill)",
    Callback = function()
        local char = GetChar()
        local hrp = GetHRP()
        if not char or not hrp then return end
        if char.shillings.Value < 2 then
            Rayfield:Notify({ Title = "Fast Buy", Content = "Not enough shillings! You need 2.", Duration = 3, Image = "alert-circle" })
            return
        end
        local promptPart = SafeGet(function()
            return Workspace.buyprompts.items.mix["hospital shop"].buypromptbag
        end)
        if not promptPart then
            Rayfield:Notify({ Title = "Fast Buy", Content = "Hospital shop buypromptbag not found.", Duration = 3, Image = "alert-circle" })
            return
        end
        local prompt = promptPart:FindFirstChildWhichIsA("ProximityPrompt")
        if not prompt then
            Rayfield:Notify({ Title = "Fast Buy", Content = "ProximityPrompt not found.", Duration = 3, Image = "alert-circle" })
            return
        end
        TeleportDoReturn(
            CFrame.new(promptPart.Position) + Vector3.new(0, 3, 0),
            function() pcall(function() fireproximityprompt(prompt) end) end,
            0.3
        )
    end
})

Tab2:CreateButton({
    Name = "Buy 1 Knife (5 pence)",
    Callback = function()
        local char = GetChar()
        local hrp = GetHRP()
        if not char or not hrp then return end
        if char.pence.Value < 5 then
            Rayfield:Notify({ Title = "Fast Buy", Content = "Not enough pence! You need 5.", Duration = 3, Image = "alert-circle" })
            return
        end
        local promptPart = SafeGet(function()
            return Workspace.buyprompts.items["melee shop"].buypromptA
        end)
        if not promptPart then
            Rayfield:Notify({ Title = "Fast Buy", Content = "Melee shop buypromptA not found.", Duration = 3, Image = "alert-circle" })
            return
        end
        local prompt = promptPart:FindFirstChildWhichIsA("ProximityPrompt")
        if not prompt then
            Rayfield:Notify({ Title = "Fast Buy", Content = "ProximityPrompt not found.", Duration = 3, Image = "alert-circle" })
            return
        end
        TeleportDoReturn(
            CFrame.new(promptPart.Position) + Vector3.new(0, 3, 0),
            function() pcall(function() fireproximityprompt(prompt) end) end,
            0.3
        )
    end
})

Tab2:CreateButton({
    Name = "Buy 1 Torch (5 pence)",
    Callback = function()
        local char = GetChar()
        local hrp = GetHRP()
        if not char or not hrp then return end
        if char.pence.Value < 5 then
            Rayfield:Notify({ Title = "Fast Buy", Content = "Not enough pence! You need 5.", Duration = 3, Image = "alert-circle" })
            return
        end
        local promptPart = nil
        for _, v in pairs(Workspace:GetDescendants()) do
            if v.Name == "buypromptI" and v:IsA("BasePart") then
                promptPart = v
                break
            end
        end
        if not promptPart then
            Rayfield:Notify({ Title = "Fast Buy", Content = "buypromptI not found in workspace.", Duration = 3, Image = "alert-circle" })
            return
        end
        local prompt = promptPart:FindFirstChildWhichIsA("ProximityPrompt")
        if not prompt then
            Rayfield:Notify({ Title = "Fast Buy", Content = "ProximityPrompt not found.", Duration = 3, Image = "alert-circle" })
            return
        end
        TeleportDoReturn(
            CFrame.new(promptPart.Position) + Vector3.new(0, 3, 0),
            function() pcall(function() fireproximityprompt(prompt) end) end,
            0.3
        )
    end
})

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
            char.pounds.Changed:Connect(function(new)
                LocalPlayer.PlayerGui.money.pounds.Text = new .. " Pounds"
            end)
            char.pence.Changed:Connect(function(new)
                LocalPlayer.PlayerGui.money.pence.Text = new .. " Pence"
            end)
            char.shillings.Changed:Connect(function(new)
                LocalPlayer.PlayerGui.money.shillings.Text = new .. " Shillings"
            end)
            char.farthings.Changed:Connect(function(new)
                LocalPlayer.PlayerGui.money.farthings.Text = new .. " Farthings"
            end)
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

        -- Look for buypromptF (grenade shop - same cart as torch but with F)
        local promptPart = nil
        local meleeShop = SafeGet(function() return Workspace.buyprompts.items["melee shop"] end)
        if meleeShop then
            for _, v in pairs(meleeShop:GetChildren()) do
                if v.Name == "buypromptF" and v:IsA("BasePart") then
                    promptPart = v
                    break
                end
            end
        end
        
        if not promptPart then
            for _, v in pairs(Workspace:GetDescendants()) do
                if v.Name == "buypromptF" and v:IsA("BasePart") then
                    promptPart = v
                    break
                end
            end
        end

        if not promptPart then
            Rayfield:Notify({ Title = "Nuke", Content = "Grenade prompt (buypromptF) not found.", Duration = 3, Image = "alert-circle" })
            return
        end

        local prompt = promptPart:FindFirstChildWhichIsA("ProximityPrompt")
        if not prompt then
            Rayfield:Notify({ Title = "Nuke", Content = "ProximityPrompt not found on buypromptF.", Duration = 3, Image = "alert-circle" })
            return
        end

        local origin = hrp.CFrame
        TeleportTo(CFrame.new(promptPart.Position) + Vector3.new(0, 3, 0))
        task.wait(0.2)

        local timeout = 0
        local initialShillings = char.shillings.Value
        repeat
            task.wait(0.1)
            timeout += 0.1
            pcall(function() fireproximityprompt(prompt) end)
            task.wait(0.05)
        until char.shillings.Value < 5
            or (hrp.Position - promptPart.Position).Magnitude > 25
            or timeout > 60

        TeleportTo(origin)
        local spent = initialShillings - char.shillings.Value
        Rayfield:Notify({ Title = "Nuke", Content = "Spent " .. spent .. " shillings on grenades!", Duration = 4, Image = "bomb" })
    end
})

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

local Tab6 = Window:CreateTab("Credits", "info")

Tab6:CreateSection("Info")

Tab6:CreateParagraph({ Title = "Made by", Content = "Your Typical Exploiter" })
Tab6:CreateParagraph({ Title = "Original idea", Content = "Dave" })
Tab6:CreateParagraph({ Title = "Toggle UI", Content = "Press K to show/hide." })
Tab6:CreateParagraph({ Title = "F Key Attack", Content = "Press F to attack with ALL tools at once (blacklisted tools excluded)!" })
Tab6:CreateParagraph({ Title = "Wave Crafting", Content = "Equips each unfinished tool in sequence like a flowing wave!" })

Tab6:CreateButton({
    Name = "Destroy GUI",
    Callback = function()
        Rayfield:Destroy()
    end
})

Tab6:CreateButton({
    Name = "Equip All Tools",
    Callback = function()
        local char = GetChar()
        if not char then return end

        local toolsToEquip = {}
        for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
            if tool:IsA("Tool") and not BLACKLISTED_TOOLS[tool.Name] then
                table.insert(toolsToEquip, tool)
            end
        end
        for _, tool in pairs(char:GetChildren()) do
            if tool:IsA("Tool") and not BLACKLISTED_TOOLS[tool.Name] then
                table.insert(toolsToEquip, tool)
            end
        end

        if #toolsToEquip == 0 then
            Rayfield:Notify({ Title = "Equip All", Content = "No tools found.", Duration = 3, Image = "alert-circle" })
            return
        end

        for _, tool in ipairs(toolsToEquip) do
            pcall(function()
                tool.Parent = char
            end)
        end

        task.wait(0.05)

        getgenv().EquipAllConnections = getgenv().EquipAllConnections or {}
        for _, conn in ipairs(getgenv().EquipAllConnections) do
            pcall(function() conn:Disconnect() end)
        end
        getgenv().EquipAllConnections = {}

        for _, tool in ipairs(toolsToEquip) do
            local conn = tool.AncestryChanged:Connect(function()
                if tool.Parent == LocalPlayer.Backpack then
                    pcall(function() tool.Parent = char end)
                end
            end)
            table.insert(getgenv().EquipAllConnections, conn)
        end

        for _, tool in ipairs(toolsToEquip) do
            task.spawn(function()
                pcall(function() tool:Activate() end)
            end)
        end

        Rayfield:Notify({ Title = "Equip All", Content = "All " .. #toolsToEquip .. " tools equipped and locked in.", Duration = 3, Image = "zap" })
    end
})

Rayfield:Notify({
    Title = "YTE (Premium)",
    Content = "Loaded! Press F to attack with ALL tools! Wave crafting system active!",
    Duration = 5,
    Image = "check-circle",
})

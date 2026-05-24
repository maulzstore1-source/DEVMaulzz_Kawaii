-- Avatar Changer Server - RGB Animation FORCE RESTART FIXED
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local InsertService = game:GetService("InsertService")

-- Create RemoteEvents
local changeAvatarEvent = Instance.new("RemoteEvent")
changeAvatarEvent.Name = "ChangeAvatarEvent"
changeAvatarEvent.Parent = ReplicatedStorage

local resetAvatarEvent = Instance.new("RemoteEvent")
resetAvatarEvent.Name = "ResetAvatarEvent"
resetAvatarEvent.Parent = ReplicatedStorage

local addAccessoryEvent = Instance.new("RemoteEvent")
addAccessoryEvent.Name = "AddAccessoryEvent"
addAccessoryEvent.Parent = ReplicatedStorage

local removeAccessoryEvent = Instance.new("RemoteEvent")
removeAccessoryEvent.Name = "RemoveAccessoryEvent"
removeAccessoryEvent.Parent = ReplicatedStorage

-- NEW: Remote untuk restart RGB animation dari client
local restartRGBEvent = Instance.new("RemoteEvent")
restartRGBEvent.Name = "RestartRGBEvent"
restartRGBEvent.Parent = ReplicatedStorage

-- Store player data
local playerData = {}
local savedHeadGUIs = {}

-- SIMPAN HEADGUI DENGAN SEMUA SCRIPTS NYA!
local function saveHeadGUI(player)
    if player.Character then
        local head = player.Character:FindFirstChild("Head")
        if head then
            -- Cari BillboardGui
            for _, child in pairs(head:GetChildren()) do
                if child:IsA("BillboardGui") then
                    -- CLONE LENGKAP DENGAN SEMUA SCRIPTS!
                    local clonedGui = child:Clone()
                    
                    -- Pastikan semua LocalScript enabled
                    for _, script in pairs(clonedGui:GetDescendants()) do
                        if script:IsA("LocalScript") or script:IsA("Script") then
                            script.Disabled = false
                            script.Enabled = true
                        end
                    end
                    
                    savedHeadGUIs[player.UserId] = clonedGui
                    print("💾 HeadGUI saved for " .. player.Name .. " (with RGB scripts)")
                    return
                end
            end
        end
    end
end

-- RESTORE HEADGUI DENGAN RGB ANIMATION!
local function restoreHeadGUI(player)
    if not savedHeadGUIs[player.UserId] then 
        print("⚠️ No saved HeadGUI for " .. player.Name)
        return 
    end
    
    task.wait(0.3) -- Wait for character to fully load
    
    if player.Character then
        local head = player.Character:FindFirstChild("Head")
        if head then
            -- Hapus semua BillboardGui yang ada
            for _, child in pairs(head:GetChildren()) do
                if child:IsA("BillboardGui") then
                    child:Destroy()
                end
            end
            
            task.wait(0.1)
            
            -- Clone GUI yang udah disimpan
            local restoredGui = savedHeadGUIs[player.UserId]:Clone()
            restoredGui.Parent = head
            
            -- RESTART SEMUA LOCALSCRIPT BIAR RGB JALAN!
            task.wait(0.1)
            
            for _, script in pairs(restoredGui:GetDescendants()) do
                if script:IsA("LocalScript") then
                    -- Method 1: Disable then enable
                    script.Disabled = true
                    script.Enabled = false
                    task.wait(0.05)
                    script.Disabled = false
                    script.Enabled = true
                    print("🔄 Restarted RGB LocalScript: " .. script.Name)
                elseif script:IsA("Script") then
                    -- If it's a regular script
                    script.Disabled = true
                    task.wait(0.05)
                    script.Disabled = false
                    print("🔄 Restarted RGB Script: " .. script.Name)
                end
            end
            
            -- EXTRA: Fire event ke client buat restart dari sisi client juga
            task.wait(0.2)
            restartRGBEvent:FireClient(player)
            
            print("✅ HeadGUI restored with RGB for " .. player.Name)
        end
    end
end

-- Save original avatar
local function saveOriginalAvatar(player)
    if not playerData[player.UserId] then
        playerData[player.UserId] = {
        currentAvatarId = nil,
        accessories = {},
        accessoryObjects = {}
        }
    end
end

-- Smooth avatar change
local function changeAvatarSmooth(player, targetUserId)
    if not player.Character then return end
    
    local humanoid = player.Character:FindFirstChild("Humanoid")
    local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
    
    if not humanoid or not rootPart then return end
    
    saveOriginalAvatar(player)
    
    -- SAVE HEADGUI SEBELUM GANTI!
    saveHeadGUI(player)
    
    playerData[player.UserId].currentAvatarId = targetUserId
    
    -- SMOOTH EFFECTS
    for i = 1, 25 do
        local part = Instance.new("Part")
        part.Size = Vector3.new(0.4, 0.4, 0.4)
        part.Shape = Enum.PartType.Ball
        part.Material = Enum.Material.Neon
        part.Color = Color3.fromRGB(88, 101, 242)
        part.CanCollide = false
        part.Anchored = true
        part.Transparency = 0.2
        
        local angle = (i / 25) * math.pi * 2
        local radius = 3
        part.Position = rootPart.Position + Vector3.new(
        math.cos(angle) * radius,
        math.random(0, 4),
        math.sin(angle) * radius
        )
        part.Parent = workspace
        
        local targetPos = rootPart.Position + Vector3.new(0, math.random(1, 3), 0)
        TweenService:Create(part, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
        Position = targetPos,
        Transparency = 1,
        Size = Vector3.new(0, 0, 0)
        }):Play()
        
        task.delay(0.7, function() part:Destroy() end)
        end
            
            local beam = Instance.new("Part")
            beam.Size = Vector3.new(5, 0.5, 5)
            beam.Shape = Enum.PartType.Cylinder
            beam.Material = Enum.Material.Neon
            beam.Color = Color3.fromRGB(88, 101, 242)
            beam.CanCollide = false
            beam.Anchored = true
            beam.Transparency = 0.3
            beam.Position = rootPart.Position
            beam.Orientation = Vector3.new(0, 0, 90)
            beam.Parent = workspace
            
            TweenService:Create(beam, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {
            Size = Vector3.new(8, 0.5, 8),
            Transparency = 1
            }):Play()
            task.delay(0.6, function() beam:Destroy() end)
                
                for i = 1, 3 do
                    task.wait(0.1)
                    local ring = Instance.new("Part")
                    ring.Size = Vector3.new(0.5, 0.2, 0.5)
                    ring.Shape = Enum.PartType.Cylinder
                    ring.Material = Enum.Material.Neon
                    ring.Color = Color3.fromRGB(120, 130, 255)
                    ring.CanCollide = false
                    ring.Anchored = true
                    ring.Transparency = 0.4
                    ring.Position = rootPart.Position + Vector3.new(0, i * 0.5, 0)
                    ring.Orientation = Vector3.new(0, 0, 90)
                    ring.Parent = workspace
                    
                    TweenService:Create(ring, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
                    Size = Vector3.new(12, 0.2, 12),
                    Transparency = 1
                    }):Play()
                    task.delay(0.5, function() ring:Destroy() end)
                    end
                        
                        -- Fade out
                        for _, part in pairs(player.Character:GetDescendants()) do
                            if part:IsA("BasePart") or part:IsA("Decal") then
                                TweenService:Create(part, TweenInfo.new(0.3), {Transparency = 1}):Play()
                            end
                        end
                        
                        task.wait(0.4)
                        
                        -- Remove old accessories (NOT HEADGUI!)
                        for _, item in pairs(player.Character:GetChildren()) do
                            if item:IsA("Accessory") or item:IsA("Hat") or item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") then
                                item:Destroy()
                            end
                        end
                        
                        -- Apply new avatar
                        local success, description = pcall(function()
                            return Players:GetHumanoidDescriptionFromUserId(targetUserId)
                        end)
                        
                        if success and description then
                            humanoid:ApplyDescription(description)
                            
                            -- WAIT FOR CHARACTER TO FULLY LOAD
                            task.wait(0.8)
                            
                            -- RESTORE HEADGUI DENGAN RGB!
                            restoreHeadGUI(player)
                            
                            -- EXTRA WAIT BUAT MASTIIN RGB JALAN
                            task.wait(0.3)
                            
                            -- RESTART RGB LAGI KALO PERLU
                            if player.Character then
                                local head = player.Character:FindFirstChild("Head")
                                if head then
                                    for _, gui in pairs(head:GetChildren()) do
                                        if gui:IsA("BillboardGui") then
                                            for _, script in pairs(gui:GetDescendants()) do
                                                if script:IsA("LocalScript") then
                                                    -- Force restart again!
                                                    script.Disabled = true
                                                    task.wait(0.1)
                                                    script.Disabled = false
                                                    print("🔄 FORCE RESTARTED RGB: " .. script.Name)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        
                        task.wait(0.2)
                        
                        -- Fade in
                        for _, part in pairs(player.Character:GetDescendants()) do
                            if part:IsA("BasePart") then
                                local original = 0
                                if part.Name == "HumanoidRootPart" then
                                    original = 1
                                end
                                TweenService:Create(part, TweenInfo.new(0.4), {Transparency = original}):Play()
                            elseif part:IsA("Decal") then
                                TweenService:Create(part, TweenInfo.new(0.4), {Transparency = 0}):Play()
                            end
                        end
                        
                        -- Burst effect
                        local burst = Instance.new("Part")
                        burst.Size = Vector3.new(1, 1, 1)
                        burst.Shape = Enum.PartType.Ball
                        burst.Material = Enum.Material.Neon
                        burst.Color = Color3.fromRGB(88, 101, 242)
                        burst.CanCollide = false
                        burst.Anchored = true
                        burst.Transparency = 0.3
                        burst.Position = rootPart.Position + Vector3.new(0, 1, 0)
                        burst.Parent = workspace
                        
                        TweenService:Create(burst, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
                        Size = Vector3.new(10, 10, 10),
                        Transparency = 1
                        }):Play()
                        task.delay(0.5, function() burst:Destroy() end)
                            
                            -- Re-add custom accessories
                            if playerData[player.UserId] and playerData[player.UserId].accessories then
                                task.wait(0.3)
                                for assetId, _ in pairs(playerData[player.UserId].accessories) do
                                    addAccessory(player, assetId)
                                end
                            end
                            
                            print("✨ Avatar changed - HeadGUI RGB FORCE RESTARTED!")
                        end
                        
                        -- Add Accessory
                        function addAccessory(player, assetId)
                            if player.Character then
                                local humanoid = player.Character:FindFirstChild("Humanoid")
                                if humanoid then
                                    local success, model = pcall(function()
                                        return InsertService:LoadAsset(assetId)
                                    end)
                                    
                                    if success and model then
                                        local accessory = model:FindFirstChildOfClass("Accessory")
                                        
                                        if accessory then
                                            local clonedAccessory = accessory:Clone()
                                            humanoid:AddAccessory(clonedAccessory)
                                            
                                            if not playerData[player.UserId] then
                                                saveOriginalAvatar(player)
                                            end
                                            playerData[player.UserId].accessories[assetId] = true
                                            
                                            if not playerData[player.UserId].accessoryObjects[assetId] then
                                                playerData[player.UserId].accessoryObjects[assetId] = {}
                                            end
                                            table.insert(playerData[player.UserId].accessoryObjects[assetId], clonedAccessory)
                                            
                                            print("✅ Added accessory " .. assetId .. " (" .. accessory.Name .. ")")
                                        else
                                            warn("❌ No Accessory found in asset " .. assetId)
                                        end
                                        
                                        model:Destroy()
                                    else
                                        warn("❌ Failed to load asset: " .. assetId)
                                    end
                                end
                            end
                        end
                        
                        -- Remove Accessory
                        function removeAccessory(player, assetId)
                            if player.Character then
                                if playerData[player.UserId] and playerData[player.UserId].accessoryObjects[assetId] then
                                    for _, accessory in pairs(playerData[player.UserId].accessoryObjects[assetId]) do
                                        if accessory and accessory.Parent then
                                            accessory:Destroy()
                                            print("✅ Removed accessory from saved objects: " .. assetId)
                                        end
                                    end
                                    playerData[player.UserId].accessoryObjects[assetId] = {}
                                end
                                
                                for _, item in pairs(player.Character:GetChildren()) do
                                    if item:IsA("Accessory") then
                                        local handle = item:FindFirstChild("Handle")
                                        if handle then
                                            for _, mesh in pairs(handle:GetDescendants()) do
                                                if mesh:IsA("SpecialMesh") or mesh:IsA("MeshPart") then
                                                    local meshId = mesh:IsA("SpecialMesh") and mesh.MeshId or mesh.MeshId
                                                    if meshId and (meshId:find(tostring(assetId)) or meshId:find("rbxassetid://" .. assetId)) then
                                                        item:Destroy()
                                                        print("✅ Removed accessory by mesh check: " .. item.Name)
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                                
                                if playerData[player.UserId] and playerData[player.UserId].accessories then
                                    playerData[player.UserId].accessories[assetId] = nil
                                end
                                
                                print("✅ Accessory removal complete for " .. assetId)
                            end
                        end
                        
                        -- Reset avatar
                        local function resetAvatar(player)
                            if not player.Character then return end
                            
                            local humanoid = player.Character:FindFirstChild("Humanoid")
                            if humanoid and playerData[player.UserId] then
                                
                                playerData[player.UserId].currentAvatarId = nil
                                playerData[player.UserId].accessories = {}
                                playerData[player.UserId].accessoryObjects = {}
                                
                                local success, description = pcall(function()
                                    return Players:GetHumanoidDescriptionFromUserId(player.UserId)
                                end)
                                
                                if success and description then
                                    humanoid:ApplyDescription(description)
                                    
                                    task.wait(0.8)
                                    restoreHeadGUI(player)
                                    
                                    -- RESTART RGB LAGI
                                    task.wait(0.3)
                                    if player.Character then
                                        local head = player.Character:FindFirstChild("Head")
                                        if head then
                                            for _, gui in pairs(head:GetChildren()) do
                                                if gui:IsA("BillboardGui") then
                                                    for _, script in pairs(gui:GetDescendants()) do
                                                        if script:IsA("LocalScript") then
                                                            script.Disabled = true
                                                            task.wait(0.1)
                                                            script.Disabled = false
                                                            print("🔄 RESET - RGB RESTARTED!")
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                    
                                    print("✅ Avatar reset - HeadGUI RGB restored!")
                                end
                            end
                        end
                        
                        -- Player joined
                        Players.PlayerAdded:Connect(function(player)
                            saveOriginalAvatar(player)
                            
                            player.CharacterAdded:Connect(function(character)
                                -- Save HeadGUI on spawn
                                task.wait(2.5) -- Tunggu character & HeadGUI load
                                saveHeadGUI(player)
                                
                                task.wait(0.5)
                                
                                -- Reapply avatar if needed
                                if playerData[player.UserId] and playerData[player.UserId].currentAvatarId then
                                    local humanoid = character:WaitForChild("Humanoid", 5)
                                    if humanoid then
                                        task.wait(0.3)
                                        changeAvatarSmooth(player, playerData[player.UserId].currentAvatarId)
                                    end
                                else
                                    if playerData[player.UserId] and playerData[player.UserId].accessories then
                                        task.wait(0.5)
                                        for assetId, _ in pairs(playerData[player.UserId].accessories) do
                                            addAccessory(player, assetId)
                                        end
                                    end
                                end
                            end)
                        end)
                        
                        -- Event handlers
                        changeAvatarEvent.OnServerEvent:Connect(function(player, targetUserId)
                            if typeof(targetUserId) == "number" then
                                changeAvatarSmooth(player, targetUserId)
                            end
                        end)
                        
                        resetAvatarEvent.OnServerEvent:Connect(function(player)
                            resetAvatar(player)
                        end)
                        
                        addAccessoryEvent.OnServerEvent:Connect(function(player, assetId)
                            if typeof(assetId) == "number" then
                                addAccessory(player, assetId)
                            end
                        end)
                        
                        removeAccessoryEvent.OnServerEvent:Connect(function(player, assetId)
                            if typeof(assetId) == "number" then
                                removeAccessory(player, assetId)
                            end
                        end)
                        
                        -- Cleanup
                        Players.PlayerRemoving:Connect(function(player)
                            playerData[player.UserId] = nil
                            savedHeadGUIs[player.UserId] = nil
                        end)
                        
                        print("✅ Avatar Changer FULLY WORKING - RGB FORCE RESTART!")

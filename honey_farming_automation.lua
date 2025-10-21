-- Honey Farming and Selling Automation Script
-- This script automates the process of farming honey combs, processing them, and selling honey

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanRootPart") or Character:WaitForChild("HumanoidRootPart")

-- Game elements
local InventoryGui = LocalPlayer.PlayerGui["Inventory1.5"]
local EconomyGui = LocalPlayer.PlayerGui.ECONOMY
local ProcessGui = LocalPlayer.PlayerGui.process
local AutoFarmGui = LocalPlayer.PlayerGui["auto fram"]

-- Remote events
local FarmRemote = ReplicatedStorage.Remotes.Farm
local DataRemote = ReplicatedStorage.Remotes.data
local EconomyRemote = EconomyGui.ClientHandler.RemoteEvent

-- Locations
local FARM_POSITION = Vector3.new(4547.98828, 388.356171, -1488.61279)
local FARM_CFRAME = CFrame.new(4547.98828, 388.356171, -1488.61279, -0.219121814, 9.00142823e-08, -0.975697517, 3.31194316e-09, 1, 9.15125469e-08, 0.975697517, 1.68209411e-08, -0.219121814)

-- Game objects
local HoneyCombProcess = workspace.AMain.HoneyCombProcess
local EconomyMarker = workspace.Markers.Economy
local JobHoneyCombs = workspace.JOB.JOB.SCRIPT.HoneyComb

-- State variables
local isRunning = false
local isProcessing = false
local collectedHoneyCombs = {}

-- Utility functions
local function waitForChild(parent, childName, timeout)
    timeout = timeout or 10
    local startTime = tick()
    while not parent:FindFirstChild(childName) and (tick() - startTime) < timeout do
        wait(0.1)
    end
    return parent:FindFirstChild(childName)
end

local function teleportTo(position)
    if RootPart then
        RootPart.CFrame = CFrame.new(position)
    end
end

local function walkTo(position)
    if Humanoid then
        Humanoid:MoveTo(position)
        Humanoid.MoveToFinished:Wait()
    end
end

local function fireProximityPrompt(object)
    local prompt = object:FindFirstChildOfClass("ProximityPrompt")
    if prompt then
        prompt:InputHoldBegin()
        wait(0.1)
        prompt:InputHoldEnd()
    end
end

-- Inventory checking functions
local function getHoneyCombCount()
    local honeyCombFrame = InventoryGui.Frame.Main.ScrollingFrame.Scrolling.HoneyComb.All.TextLabel.Text
    local current, max = honeyCombFrame:match("(%d+)/(%d+)")
    return tonumber(current) or 0, tonumber(max) or 30
end

local function getProcessedHoneyCount()
    local honeyFrame = InventoryGui.Frame.Main.ScrollingFrame.Scrolling.Honey.All.TextLabel.Text
    return tonumber(honeyFrame) or 0
end

local function getBagCapacity()
    local capacityText = InventoryGui.Frame.Main.Frame.Frame.TextLabel.Text
    local current, max = capacityText:match("([%d%.]+)/([%d%.]+) KG")
    return tonumber(current) or 0, tonumber(max) or 60
end

local function isBagFull()
    local current, max = getBagCapacity()
    return current >= max
end

local function isHoneyCombFull()
    local current, max = getHoneyCombCount()
    return current >= max
end

-- Auto-farm detection
local function isAutoFarmActive()
    return AutoFarmGui.Visible
end

-- Honey comb collection
local function collectHoneyComb(honeyComb)
    if not honeyComb or not honeyComb.Parent then
        return false
    end
    
    -- Walk to honey comb
    walkTo(honeyComb.Position)
    
    -- Fire proximity prompt
    fireProximityPrompt(honeyComb)
    
    -- Wait a bit for collection
    wait(1)
    
    return true
end

local function findNearestHoneyComb()
    local nearestHoneyComb = nil
    local nearestDistance = math.huge
    
    for _, honeyComb in pairs(JobHoneyCombs:GetChildren()) do
        if honeyComb:IsA("Model") and honeyComb.Name == "HoneyComb" then
            local distance = (honeyComb.Position - RootPart.Position).Magnitude
            if distance < nearestDistance then
                nearestDistance = distance
                nearestHoneyComb = honeyComb
            end
        end
    end
    
    return nearestHoneyComb
end

-- Processing functions
local function processHoneyCombs()
    if isProcessing then
        return
    end
    
    isProcessing = true
    
    -- Teleport to processing location
    teleportTo(HoneyCombProcess.Position)
    wait(1)
    
    -- Fire proximity prompt
    fireProximityPrompt(HoneyCombProcess)
    
    -- Wait for processing GUI to appear
    local startTime = tick()
    while not ProcessGui.Visible and (tick() - startTime) < 10 do
        wait(0.1)
    end
    
    if ProcessGui.Visible then
        -- Wait for processing to complete (honey combs to disappear from inventory)
        while getHoneyCombCount() > 0 do
            wait(0.5)
        end
    end
    
    isProcessing = false
end

-- Selling functions
local function depositItems()
    local honeyCombCount = getHoneyCombCount()
    if honeyCombCount > 0 then
        local args = {
            [1] = "post",
            [2] = "HoneyComb",
            [3] = honeyCombCount,
            [4] = LocalPlayer:FindFirstChild("Truck (150Kg)(Free)")
        }
        DataRemote:FireServer(unpack(args))
        wait(1)
    end
end

local function sellHoney()
    local honeyCount = getProcessedHoneyCount()
    if honeyCount > 0 then
        -- Teleport to economy marker
        teleportTo(EconomyMarker.Position)
        wait(1)
        
        -- Fire proximity prompt
        fireProximityPrompt(EconomyMarker)
        wait(1)
        
        -- Sell honey
        local args = {
            [1] = "Seller",
            [2] = "Honey",
            [3] = honeyCount
        }
        EconomyRemote:FireServer(unpack(args))
        wait(1)
    end
end

-- Main automation logic
local function checkAndSell()
    local currentWeight, maxWeight = getBagCapacity()
    
    if currentWeight >= maxWeight then
        print("Bag is full, managing inventory...")
        
        -- If weight exceeds capacity, deposit items first
        if currentWeight > maxWeight then
            depositItems()
        end
        
        -- Then sell honey
        sellHoney()
        
        return true
    end
    
    return false
end

local function farmHoneyCombs()
    if isAutoFarmActive() then
        print("Auto-farm is active, stopping manual collection")
        return
    end
    
    local current, max = getHoneyCombCount()
    
    if current >= max then
        print("Honey comb inventory full, processing...")
        processHoneyCombs()
        return
    end
    
    -- Find and collect nearest honey comb
    local nearestHoneyComb = findNearestHoneyComb()
    if nearestHoneyComb then
        print("Collecting honey comb...")
        collectHoneyComb(nearestHoneyComb)
    else
        print("No honey combs found")
    end
end

-- Main automation loop
local function mainLoop()
    while isRunning do
        -- Check if we need to sell
        if checkAndSell() then
            wait(2)
        else
            -- Teleport to farm location
            teleportTo(FARM_POSITION)
            wait(1)
            
            -- Check honey comb count
            local current, max = getHoneyCombCount()
            
            if current >= max then
                -- Process honey combs
                processHoneyCombs()
            else
                -- Farm honey combs
                farmHoneyCombs()
            end
        end
        
        wait(1)
    end
end

-- Control functions
local function startAutomation()
    if isRunning then
        print("Automation is already running!")
        return
    end
    
    isRunning = true
    print("Starting honey farming automation...")
    
    -- Stop auto-farm if it's running
    if isAutoFarmActive() then
        local args = {[1] = "Stop"}
        FarmRemote:FireServer(unpack(args))
        wait(1)
    end
    
    -- Start main loop
    spawn(mainLoop)
end

local function stopAutomation()
    isRunning = false
    print("Stopping honey farming automation...")
end

-- GUI Creation (optional - for manual control)
local function createControlGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "HoneyFarmControl"
    screenGui.Parent = LocalPlayer.PlayerGui
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 200, 0, 100)
    frame.Position = UDim2.new(0, 10, 0, 10)
    frame.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    
    local startButton = Instance.new("TextButton")
    startButton.Size = UDim2.new(0, 80, 0, 30)
    startButton.Position = UDim2.new(0, 10, 0, 10)
    startButton.Text = "Start"
    startButton.BackgroundColor3 = Color3.new(0, 0.8, 0)
    startButton.TextColor3 = Color3.new(1, 1, 1)
    startButton.Parent = frame
    
    local stopButton = Instance.new("TextButton")
    stopButton.Size = UDim2.new(0, 80, 0, 30)
    stopButton.Position = UDim2.new(0, 100, 0, 10)
    stopButton.Text = "Stop"
    stopButton.BackgroundColor3 = Color3.new(0.8, 0, 0)
    stopButton.TextColor3 = Color3.new(1, 1, 1)
    stopButton.Parent = frame
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, 0, 0, 20)
    statusLabel.Position = UDim2.new(0, 10, 0, 50)
    statusLabel.Text = "Status: Stopped"
    statusLabel.TextColor3 = Color3.new(1, 1, 1)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Parent = frame
    
    startButton.MouseButton1Click:Connect(function()
        startAutomation()
        statusLabel.Text = "Status: Running"
    end)
    
    stopButton.MouseButton1Click:Connect(function()
        stopAutomation()
        statusLabel.Text = "Status: Stopped"
    end)
end

-- Initialize
createControlGUI()

-- Auto-start (optional)
-- startAutomation()

print("Honey Farming Automation Script Loaded!")
print("Use the GUI to start/stop the automation.")
print("The script will automatically:")
print("- Check bag capacity and sell when full")
print("- Farm honey combs when inventory is not full")
print("- Process honey combs when inventory reaches 30/30")
print("- Handle weight management and proximity prompts")
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

-- Game objects
local HoneyCombProcess = workspace.AMain.HoneyCombProcess
local EconomyMarker = workspace.Markers.Economy
local JobHoneyCombs = workspace.JOB.JOB.SCRIPT.HoneyComb

-- State variables
local isRunning = false
local isProcessing = false

-- Utility functions
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

-- Auto-farm detection
local function isAutoFarmActive()
    return AutoFarmGui.Visible
end

-- Honey comb collection
local function collectHoneyComb(honeyComb)
    if not honeyComb or not honeyComb.Parent then
        return false
    end
    
    walkTo(honeyComb.Position)
    fireProximityPrompt(honeyComb)
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
    
    teleportTo(HoneyCombProcess.Position)
    wait(1)
    
    fireProximityPrompt(HoneyCombProcess)
    
    local startTime = tick()
    while not ProcessGui.Visible and (tick() - startTime) < 10 do
        wait(0.1)
    end
    
    if ProcessGui.Visible then
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
        teleportTo(EconomyMarker.Position)
        wait(1)
        
        fireProximityPrompt(EconomyMarker)
        wait(1)
        
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
        
        if currentWeight > maxWeight then
            depositItems()
        end
        
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
        if checkAndSell() then
            wait(2)
        else
            teleportTo(FARM_POSITION)
            wait(1)
            
            local current, max = getHoneyCombCount()
            
            if current >= max then
                processHoneyCombs()
            else
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
    
    if isAutoFarmActive() then
        local args = {[1] = "Stop"}
        FarmRemote:FireServer(unpack(args))
        wait(1)
    end
    
    spawn(mainLoop)
end

local function stopAutomation()
    isRunning = false
    print("Stopping honey farming automation...")
end

-- GUI Creation
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

print("Honey Farming Automation Script Loaded!")
print("Use the GUI to start/stop the automation.")
-- WheelController.client.lua
print("🎡 [WheelController] LE SCRIPT CLIENT TOURNE !")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Events = ReplicatedStorage:WaitForChild("Events")
local Constants = require(ReplicatedStorage:WaitForChild("Constants"))

local SpinRequest = Events:WaitForChild("SpinRequest")
local SpinResult = Events:WaitForChild("SpinResult")

-- Récupération des assets physiques
local wheelAssets = Workspace:WaitForChild("WheelAssets")
local physicalWheel = wheelAssets:WaitForChild("PhysicalWheel")
local clickDetector = physicalWheel:WaitForChild("ClickDetector")

-- UI Construction (Resultats & SurfaceGui)
local function createWheelUI()
    -- 1. Result ScreenGui (toujours sur l'écran)
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "WheelResultsUI"
    screenGui.IgnoreGuiInset = true
    screenGui.Parent = playerGui

    local bgDim = Instance.new("Frame")
    bgDim.Size = UDim2.new(1, 0, 1, 0)
    bgDim.BackgroundColor3 = Color3.new(0, 0, 0)
    bgDim.BackgroundTransparency = 1
    bgDim.Visible = false
    bgDim.Parent = screenGui

    local resultContainer = Instance.new("CanvasGroup")
    resultContainer.Size = UDim2.new(0, 600, 0, 150)
    resultContainer.Position = UDim2.new(0.5, -300, 0.75, 0)
    resultContainer.BackgroundTransparency = 1
    resultContainer.Visible = false
    resultContainer.Parent = screenGui

    local resultLabel = Instance.new("TextLabel")
    resultLabel.Size = UDim2.new(1, 0, 0, 60)
    resultLabel.BackgroundTransparency = 1
    resultLabel.Text = "BRAINROT WINNER"
    resultLabel.TextColor3 = Color3.new(1, 1, 1)
		resultLabel.Font = Enum.Font.GothamBlack
    resultLabel.TextSize = 50
    resultLabel.Parent = resultContainer

    local rarityLabel = Instance.new("TextLabel")
    rarityLabel.Size = UDim2.new(1, 0, 0, 40)
    rarityLabel.Position = UDim2.new(0, 0, 0, 65)
    rarityLabel.BackgroundTransparency = 1
    rarityLabel.Text = "RARITY"
		rarityLabel.Font = Enum.Font.GothamBold
    rarityLabel.TextSize = 30
    rarityLabel.Parent = resultContainer

    -- 2. SurfaceGui (Sur la roue physique)
    local surfaceGui = Instance.new("SurfaceGui")
    surfaceGui.Name = "WheelSurface"
    surfaceGui.Face = Enum.NormalId.Right -- Face avant (pointera vers -Z)
    surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    surfaceGui.PixelsPerStud = 50
    surfaceGui.Parent = physicalWheel

    local wheelDisk = Instance.new("Frame")
    wheelDisk.Size = UDim2.new(1, 0, 1, 0)
    wheelDisk.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    wheelDisk.BorderSizePixel = 0
    wheelDisk.Parent = surfaceGui
    Instance.new("UICorner", wheelDisk).CornerRadius = UDim.new(1, 0)

    -- Segments visuels
    for i = 1, 8 do
        local segment = Instance.new("Frame")
        segment.Size = UDim2.new(0.5, 0, 0.5, 0)
        segment.AnchorPoint = Vector2.new(0.5, 1)
        segment.Position = UDim2.new(0.5, 0, 0.5, 0)
        segment.Rotation = (i - 1) * 45
        segment.BackgroundTransparency = 0.8
        segment.BackgroundColor3 = (i % 2 == 0) and Color3.fromRGB(40, 40, 45) or Color3.fromRGB(30, 30, 35)
        segment.Parent = wheelDisk

        local line = Instance.new("Frame")
        line.Size = UDim2.new(0, 4, 0.5, 0)
        line.Position = UDim2.new(0.5, -2, 0, 0)
        line.BackgroundColor3 = Color3.fromRGB(100, 100, 110)
        line.BackgroundTransparency = 0.5
        line.Parent = segment
    end

    return wheelDisk, resultContainer, bgDim
end

local wheelDiskUI, resultContainer, bgDim = createWheelUI()
local isSpinning = false

-- Interaction Click
clickDetector.MouseClick:Connect(function()
    if isSpinning then return end
    isSpinning = true
    
    resultContainer.Visible = false
    SpinRequest:FireServer(1)
end)

SpinResult.OnClientEvent:Connect(function(result)
    -- Animation de la roue PHYSIQUE
    local extraTours = 10
    local randomTargetRotation = math.random(0, 360)
    
    -- On anime la propriété CFrame pour la rotation physique
    -- Mais c'est plus simple d'animer la rotation du SurfaceGui pour le look, 
    -- et la rotation de la part pour le world.
    
    local tweenInfo = TweenInfo.new(6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    
    -- Animation visuelle (UI sur la roue)
    local targetUIRotation = wheelDiskUI.Rotation + (360 * extraTours) + randomTargetRotation
    local uiTween = TweenService:Create(wheelDiskUI, tweenInfo, {Rotation = targetUIRotation})
    
    -- Animation Physique (La part elle-même)
    -- On tourne autour de son axe local X (car Tube face X)
    local startCFrame = physicalWheel.CFrame
    local targetCFrame = startCFrame * CFrame.Angles(math.rad((360 * extraTours) + randomTargetRotation), 0, 0)
    local partTween = TweenService:Create(physicalWheel, tweenInfo, {CFrame = targetCFrame})
    
    bgDim.Visible = true
    TweenService:Create(bgDim, TweenInfo.new(1), {BackgroundTransparency = 0.5}):Play()
    
    uiTween:Play()
    partTween:Play()
    
    uiTween.Completed:Connect(function()
        local rarityInfo = Constants.RARITIES[result.Rarity]
        
        resultContainer.ResultLabel.Text = string.upper(result.Name)
        resultContainer.RarityLabel.Text = string.upper(result.Rarity)
        resultContainer.RarityLabel.TextColor3 = rarityInfo.Color
        
        resultContainer.Visible = true
        resultContainer.GroupTransparency = 1
        TweenService:Create(resultContainer, TweenInfo.new(0.5), {GroupTransparency = 0}):Play()
        
        task.wait(3)
        
        TweenService:Create(resultContainer, TweenInfo.new(0.5), {GroupTransparency = 1}):Play()
        TweenService:Create(bgDim, TweenInfo.new(1), {BackgroundTransparency = 1}):Play()
        task.wait(1)
        resultContainer.Visible = false
        bgDim.Visible = false
        isSpinning = false
    end)
end)

print("🎡 [WheelController] Prêt pour le monde physique !")

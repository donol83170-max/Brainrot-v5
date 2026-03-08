-- WheelController.client.lua
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local Events     = ReplicatedStorage:WaitForChild("Events")
local SpinResult = Events:WaitForChild("SpinResult")

-- Couleurs de Rareté Fixes et Vives exigées
local RARITY_COLORS = {
    COMMON    = Color3.fromRGB(160, 162, 168), -- Gris
    RARE      = Color3.fromRGB(0, 130, 255),   -- Bleu brillant
    EPIC      = Color3.fromRGB(155, 0, 255),   -- Violet vif
    LEGENDARY = Color3.fromRGB(255, 190, 0),   -- Or
}

local spinGui
local wheelContainer
local ptr

local SPIN_COOLDOWN = 6
local lastSpinTime = 0

local function createUI(segments)
    if spinGui then spinGui:Destroy() end

    -- 1. LE CONTENEUR PRINCIPAL
    spinGui = Instance.new("ScreenGui")
    spinGui.Name = "SpinGui"
    spinGui.IgnoreGuiInset = true
    spinGui.ResetOnSpawn = false
    spinGui.Enabled = false
    spinGui.Parent = PlayerGui

    local overlay = Instance.new("Frame")
    overlay.Name = "Overlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.BorderSizePixel = 0
    overlay.Parent = spinGui

    local WH_SIZE = 500

    -- WheelContainer : Moule à pizza rigoureusement rond
    wheelContainer = Instance.new("Frame")
    wheelContainer.Name = "WheelContainer"
    wheelContainer.Size = UDim2.new(0, WH_SIZE, 0, WH_SIZE)
    wheelContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
    wheelContainer.AnchorPoint = Vector2.new(0.5, 0.5)
    wheelContainer.BackgroundColor3 = Color3.fromRGB(180, 180, 180) -- Gris clair neutre
    wheelContainer.BackgroundTransparency = 1 -- Cacher le fond gris
    wheelContainer.ClipsDescendants = true
    wheelContainer.ZIndex = 2
    Instance.new("UICorner", wheelContainer).CornerRadius = UDim.new(1, 0)
    wheelContainer.Parent = overlay

    -- Bordure : UIStroke doré épais pour fermer la pizza
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 215, 0)
    stroke.Thickness = 5
    stroke.Parent = wheelContainer

    -- 2. LA GÉOMÉTRIE DES SEGMENTS ("Pizza") avec ImageLabel triangle blanc
    local nSeg = #segments
    local radius = WH_SIZE / 2
    local arcWidth = 2 * radius * math.tan(math.rad(180 / nSeg)) + 4 -- Marge de 4px pour assurer une jointure sans fil noir

    for i = 1, nSeg do
        local segData = segments[i]
        local rCol = RARITY_COLORS[segData.rarity] or Color3.fromRGB(180, 180, 180)
        
        -- Le triangle parfait
        local img = Instance.new("ImageLabel")
        img.Name = "Segment_" .. i
        -- Taille suffisante pour le rayon (hauteur 50% du parent, largeur suffisante pour le secteur)
        img.Size = UDim2.new(0.5, 0, 0.5, 0) 
        img.Position = UDim2.new(0.5, 0, 0.5, 0)
        img.AnchorPoint = Vector2.new(0.5, 1) -- Sommet du triangle au centre exact
        img.BackgroundTransparency = 1
        img.Image = "rbxassetid://7072740454"
        img.ImageColor3 = rCol
        img.ImageTransparency = 0
        img.Rotation = i * 30 -- Fais pivoter chaque triangle de 30°
        img.ZIndex = 2
        img.Parent = wheelContainer
    end

    -- Le Masque : Petit cercle doré au centre pour cacher les pointes
    local hubCenter = Instance.new("Frame")
    hubCenter.Name = "HubMask"
    hubCenter.Size = UDim2.new(0, 40, 0, 40)
    hubCenter.Position = UDim2.new(0.5, 0, 0.5, 0)
    hubCenter.AnchorPoint = Vector2.new(0.5, 0.5)
    hubCenter.BackgroundColor3 = Color3.fromRGB(255, 215, 0) -- Doré
    hubCenter.ZIndex = 3
    Instance.new("UICorner", hubCenter).CornerRadius = UDim.new(1, 0)
    hubCenter.Parent = wheelContainer

    -- Pointeur Rouge Fixe
    ptr = Instance.new("Frame")
    ptr.Name = "Pointer"
    ptr.Size = UDim2.new(0, 30, 0, 40)
    ptr.Position = UDim2.new(0.5, 0, 0.5, -WH_SIZE/2 - 20)
    ptr.AnchorPoint = Vector2.new(0.5, 0.5)
    ptr.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    ptr.ZIndex = 15
    ptr.Parent = overlay
    Instance.new("UICorner", ptr).CornerRadius = UDim.new(0.3, 0)
    local arrowPoint = Instance.new("Frame")
    arrowPoint.Size = UDim2.new(0, 16, 0, 16)
    arrowPoint.Position = UDim2.new(0.5, 0, 1, -8)
    arrowPoint.AnchorPoint = Vector2.new(0.5, 0.5)
    arrowPoint.Rotation = 45
    arrowPoint.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    arrowPoint.BorderSizePixel = 0
    arrowPoint.ZIndex = 14
    arrowPoint.Parent = ptr
end

-- ── ANIMATION TWEENSERVICE ──────────────────────────────
SpinResult.OnClientEvent:Connect(function(res)
    if not res.success then return end

    if res.segments then
        createUI(res.segments)
    end
    if not spinGui then return end

    local now = tick()
    if now - lastSpinTime < SPIN_COOLDOWN then return end
    lastSpinTime = now

    wheelContainer.Rotation = 0
    spinGui.Enabled = true

    local nSeg = #res.segments
    local segAngle = 360 / nSeg
    -- Segment I a sa "pointe" pivotée de I * 30. Son milieu est à (I * 30) - 15°.
    -- Le pointeur est à 0° (en haut).
    -- Pour amener le segment au centre (0°), la roue doit tourner de 360 - (I*30 - 15).
    local winAngle = (360 - ((res.winSegment * 30) - 15)) % 360
    
    local totalRots = res.rotations or 5
    local finalAngle = (360 * totalRots) + winAngle
    local duration = res.duration or 5.5
    
    local numVal = Instance.new("NumberValue")
    numVal.Value = 0

    local tween = TweenService:Create(numVal, 
        TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        { Value = finalAngle }
    )

    local conn = RunService.RenderStepped:Connect(function()
        wheelContainer.Rotation = numVal.Value
    end)

    tween.Completed:Connect(function()
        conn:Disconnect()
        numVal:Destroy()
        wheelContainer.Rotation = finalAngle % 360
        
        task.delay(3, function()
            spinGui.Enabled = false
        end)
    end)

    tween:Play()
end)

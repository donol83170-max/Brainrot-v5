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
local overlay
local wheelCanvas
local ptr

local SPIN_COOLDOWN = 6
local lastSpinTime = 0

local function createGeometryUI(segments)
    if spinGui then spinGui:Destroy() end

    -- 1. LE CONTENEUR PRINCIPAL
    spinGui = Instance.new("ScreenGui")
    spinGui.Name = "SpinGui"
    spinGui.IgnoreGuiInset = true
    spinGui.ResetOnSpawn = false
    spinGui.Enabled = false
    spinGui.Parent = PlayerGui

    overlay = Instance.new("Frame")
    overlay.Name = "Overlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.BorderSizePixel = 0
    overlay.Parent = spinGui

    local WH_SIZE = 500

    -- Bordure dorée (5 pixels d'épaisseur)
    local wheelBorder = Instance.new("Frame")
    wheelBorder.Name = "WheelBorder"
    wheelBorder.Size = UDim2.new(0, WH_SIZE + 10, 0, WH_SIZE + 10)
    wheelBorder.Position = UDim2.new(0.5, 0, 0.5, 0)
    wheelBorder.AnchorPoint = Vector2.new(0.5, 0.5)
    wheelBorder.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
    Instance.new("UICorner", wheelBorder).CornerRadius = UDim.new(1, 0)
    wheelBorder.Parent = overlay

    -- Disque gris clair neutre (CanvasGroup pour clip la rondeur)
    wheelCanvas = Instance.new("CanvasGroup")
    wheelCanvas.Name = "WheelCanvas"
    wheelCanvas.Size = UDim2.new(0, WH_SIZE, 0, WH_SIZE)
    wheelCanvas.Position = UDim2.new(0.5, 0, 0.5, 0)
    wheelCanvas.AnchorPoint = Vector2.new(0.5, 0.5)
    wheelCanvas.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
    wheelCanvas.ZIndex = 2
    Instance.new("UICorner", wheelCanvas).CornerRadius = UDim.new(1, 0)
    wheelCanvas.Parent = overlay

    -- 2. LA GÉOMÉTRIE DES SEGMENTS ("Pizza" sans superposition)
    local nSeg = #segments
    local angleDeg = 360 / nSeg -- 30 degrés obligatoirement (12 segments)

    for i = 1, nSeg do
        local segData = segments[i]
        local rCol = RARITY_COLORS[segData.rarity] or Color3.fromRGB(180, 180, 180)
        
        -- Conteneur du segment pivotant au centre
        local segContainer = Instance.new("Frame")
        segContainer.Name = "Segment_" .. i
        segContainer.Size = UDim2.new(1, 0, 1, 0)
        segContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
        segContainer.AnchorPoint = Vector2.new(0.5, 0.5)
        segContainer.Rotation = (i - 1) * angleDeg
        segContainer.BackgroundTransparency = 1
        segContainer.ZIndex = 3
        segContainer.Parent = wheelCanvas

        -- Masque du quadrant supérieur droit (0 à 90 degrés)
        local mask = Instance.new("Frame")
        mask.Name = "Mask"
        mask.Size = UDim2.new(0.5, 0, 0.5, 0)
        mask.Position = UDim2.new(0.5, 0, 0, 0)  -- Part du haut-milieu
        mask.AnchorPoint = Vector2.new(0, 0)
        mask.ClipsDescendants = true
        mask.BackgroundTransparency = 1
        mask.Parent = segContainer

        -- Rectangle coloré pivoté de (30 - 90 = -60 degrés) dans le masque (délimite les 30°)
        local fill = Instance.new("Frame")
        fill.Name = "Fill"
        fill.Size = UDim2.new(2, 0, 2, 0)
        fill.Position = UDim2.new(0, 0, 1, 0)    -- Son centre est le coin bas-gauche du masque (le centre du cercle)
        fill.AnchorPoint = Vector2.new(0.5, 0.5)
        fill.Rotation = angleDeg - 90            -- Crée la ligne de coupe parfaite à 30°
        fill.BackgroundColor3 = rCol
        fill.BorderSizePixel = 0
        fill.Parent = mask

        -- 4. ÉLÉMENTS DE CONFINEMENT : Séparateur blanc (ligne pure)
        local separator = Instance.new("Frame")
        separator.Name = "Line"
        separator.Size = UDim2.new(0, 2, 0.5, 0) -- Fine ligne sur le rayon
        separator.Position = UDim2.new(0.5, 0, 0, 0)
        separator.AnchorPoint = Vector2.new(0.5, 0)
        separator.Rotation = (i - 1) * angleDeg
        separator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        separator.BorderSizePixel = 0
        separator.ZIndex = 4
        separator.Parent = wheelCanvas
    end

    -- 4. Hub Central (Masque de jointure)
    local hubCenter = Instance.new("Frame")
    hubCenter.Name = "HubMask"
    hubCenter.Size = UDim2.new(0, 40, 0, 40)
    hubCenter.Position = UDim2.new(0.5, 0, 0.5, 0)
    hubCenter.AnchorPoint = Vector2.new(0.5, 0.5)
    hubCenter.BackgroundColor3 = Color3.fromRGB(255, 215, 0) -- Sphère dorée polie
    hubCenter.ZIndex = 5
    Instance.new("UICorner", hubCenter).CornerRadius = UDim.new(1, 0)
    hubCenter.Parent = wheelCanvas

    -- 3. ÉLÉMENTS CENTRAUX ET POINTEUR (En dehors du Canvas, au-dessus de tout)
    ptr = Instance.new("Frame")
    ptr.Name = "Pointer"
    ptr.Size = UDim2.new(0, 30, 0, 40)
    ptr.Position = UDim2.new(0.5, 0, 0.5, -WH_SIZE/2 - 20)
    ptr.AnchorPoint = Vector2.new(0.5, 0.5)
    ptr.BackgroundColor3 = Color3.fromRGB(255, 0, 0) -- Pointeur rouge fixe strict
    ptr.ZIndex = 15
    ptr.Parent = overlay
    -- Forme de flèche grossière avec UICorner pour illustrer en pure Frame
    local ptrCorner1 = Instance.new("UICorner", ptr)
    ptrCorner1.CornerRadius = UDim.new(0.3, 0)
    -- Une pointe plus basse (pour faire flèche)
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
        createGeometryUI(res.segments)
    end
    if not spinGui then return end

    local now = tick()
    if now - lastSpinTime < SPIN_COOLDOWN then return end
    lastSpinTime = now

    wheelCanvas.Rotation = 0
    spinGui.Enabled = true

    -- Calcul strict pour QuartOut
    local nSeg = #res.segments
    local segAngle = 360 / nSeg
    -- Pointeur est à 12h (0°).
    -- Pour amener le segment I sous le pointeur, on tourne de: 360 - (I - 1) * 30
    local winAngle = (360 - ((res.winSegment - 1) * segAngle)) % 360
    
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
        wheelCanvas.Rotation = numVal.Value
    end)

    tween.Completed:Connect(function()
        conn:Disconnect()
        numVal:Destroy()
        wheelCanvas.Rotation = finalAngle % 360
        
        -- Flash/CloseBtn (Désactivés pour focus géométrie pure, on ferme après 3s)
        task.delay(3, function()
            spinGui.Enabled = false
        end)
    end)

    tween:Play()
end)

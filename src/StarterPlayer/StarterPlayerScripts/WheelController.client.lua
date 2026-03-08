-- WheelController.client.lua
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local Events     = ReplicatedStorage:WaitForChild("Events")
local SpinResult = Events:WaitForChild("SpinResult")

local RARITY_COLORS = {
    COMMON    = Color3.fromRGB(160, 162, 168),
    RARE      = Color3.fromRGB(  0, 130, 255),
    EPIC      = Color3.fromRGB(155,   0, 255),
    LEGENDARY = Color3.fromRGB(255, 190,   0),
}

-- Sons
local guiTickSound = Instance.new("Sound")
guiTickSound.SoundId = "rbxassetid://6026984224"
guiTickSound.Volume = 0.5
guiTickSound.Parent = script

local guiWinSound = Instance.new("Sound")
guiWinSound.SoundId = "rbxassetid://5153734135"
guiWinSound.Volume = 1.0
guiWinSound.Parent = script

local fanfareSound = Instance.new("Sound")
fanfareSound.SoundId = "rbxassetid://3205426741"
fanfareSound.Volume = 1.0
fanfareSound.Parent = script

-- ── DÉCLARATION DE L'UI ────────────
local spinGui
local overlay
local wheelOuter
local wheelCanvas
local ptr
local winLabel
local closeBtn
local flashFrame
local spinBtn

local SPIN_COOLDOWN = 6 -- secondes
local lastSpinTime = 0

local function createUI(segments)
    if spinGui then spinGui:Destroy() end

    spinGui = Instance.new("ScreenGui")
    spinGui.Name = "SpinGui"
    spinGui.IgnoreGuiInset = true
    spinGui.ResetOnSpawn = false
    spinGui.Enabled = false
    spinGui.Parent = PlayerGui

    -- Fond translucide
    overlay = Instance.new("Frame")
    overlay.Name = "Overlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.6
    overlay.BorderSizePixel = 0
    overlay.Parent = spinGui

    -- Flash d'écran (victoire)
    flashFrame = Instance.new("Frame")
    flashFrame.Name = "Flash"
    flashFrame.Size = UDim2.new(1, 0, 1, 0)
    flashFrame.BackgroundColor3 = Color3.new(1, 1, 1)
    flashFrame.BackgroundTransparency = 1
    flashFrame.BorderSizePixel = 0
    flashFrame.ZIndex = 100
    flashFrame.Parent = spinGui

    -- ── Zone de la roue ──────────────────────────────────
    local WH_SIZE = 500
    
    -- Bordure or externe
    wheelOuter = Instance.new("Frame")
    wheelOuter.Name = "WheelOuter"
    wheelOuter.Size = UDim2.new(0, WH_SIZE + 24, 0, WH_SIZE + 24)
    wheelOuter.AnchorPoint = Vector2.new(0.5, 0.5)
    wheelOuter.Position = UDim2.new(0.5, 0, 0.5, 0)
    wheelOuter.BackgroundColor3 = Color3.fromRGB(255, 215, 0) -- Or net
    wheelOuter.Parent = overlay
    Instance.new("UICorner", wheelOuter).CornerRadius = UDim.new(0.5, 0)

    -- Base grise
    local wheelBackground = Instance.new("Frame")
    wheelBackground.Size = UDim2.new(0, WH_SIZE, 0, WH_SIZE)
    wheelBackground.AnchorPoint = Vector2.new(0.5, 0.5)
    wheelBackground.Position = UDim2.new(0.5, 0, 0.5, 0)
    wheelBackground.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
    wheelBackground.Parent = wheelOuter
    Instance.new("UICorner", wheelBackground).CornerRadius = UDim.new(0.5, 0)

    -- Partie rotative (CanvasGroup pour clip les segments qui dépassent)
    wheelCanvas = Instance.new("CanvasGroup")
    wheelCanvas.Name = "WheelCanvas"
    wheelCanvas.Size = UDim2.new(1, 0, 1, 0)
    wheelCanvas.BackgroundTransparency = 1
    wheelCanvas.Parent = wheelBackground

    -- Construction des 12 Segments Vides (lignes de séparation) + Textes
    local nSeg = #segments
    local radius = WH_SIZE / 2
    local arcWidth = (math.pi * WH_SIZE) / nSeg -- Largeur exacte de l'arc
    
    for i = 1, nSeg do
        local segData = segments[i]
        local angleDeg = (i - 1) * (360 / nSeg)

        -- Segment fond coloré (dessiné comme un large rectangle roté pour emplir le secteur, clipsé par CanvasGroup)
        local sf = Instance.new("Frame")
        -- Ajustement de la largeur pour couvrir précisément sans espace ni trop déborder
        sf.Size  = UDim2.new(0, arcWidth * 1.05, 0.5, 0) 
        sf.AnchorPoint = Vector2.new(0.5, 1)
        sf.Position = UDim2.new(0.5, 0, 0.5, 0)
        sf.Rotation = angleDeg
        sf.BackgroundColor3 = RARITY_COLORS[segData.rarity] or Color3.fromRGB(180, 180, 180)
        sf.BorderSizePixel = 0
        sf.Parent = wheelCanvas

        -- Conteneur du texte pour gérer parfaitement les dimensions radiales
        local textContainer = Instance.new("Frame")
        textContainer.Size = UDim2.new(0, arcWidth * 0.85, 0.45, 0)
        textContainer.AnchorPoint = Vector2.new(0.5, 1)
        textContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
        textContainer.Rotation = angleDeg
        textContainer.BackgroundTransparency = 1
        textContainer.Parent = wheelCanvas

        -- Texte orienté vers l'extérieur
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0.35, 0)
        lbl.Position = UDim2.new(0, 0, 0.05, 0) -- Près du bord extérieur
        lbl.BackgroundTransparency = 1
        lbl.Text = string.upper(segData.item.name)
        lbl.TextColor3 = Color3.new(1, 1, 1)
        lbl.Font = Enum.Font.LuckiestGuy
        lbl.TextScaled = true
        lbl.TextStrokeTransparency = 0
        lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
        lbl.ZIndex = 2
        lbl.Parent = textContainer

        -- Séparateur Ligne Blanche stricte (sans texture floue)
        local lineAngle = angleDeg - (180 / nSeg)
        local separator = Instance.new("Frame")
        separator.Size = UDim2.new(0, 4, 0.5, 0)
        separator.AnchorPoint = Vector2.new(0.5, 1)
        separator.Position = UDim2.new(0.5, 0, 0.5, 0)
        separator.Rotation = lineAngle
        separator.BackgroundColor3 = Color3.new(1, 1, 1)
        separator.BorderSizePixel = 0
        separator.ZIndex = 3
        separator.Parent = wheelCanvas
    end

    -- ── Anneau de Billes Lumineuses Statiques (autour de wheelOuter) ─────────────────────
    local BEAD_PALETTE = {
        Color3.fromRGB(255,  40,  40), Color3.fromRGB(255, 140,   0),
        Color3.fromRGB(255, 245,   0), Color3.fromRGB( 60, 255,  80),
        Color3.fromRGB(  0, 170, 255), Color3.fromRGB(170,   0, 255),
        Color3.fromRGB(255,   0, 180), Color3.fromRGB(255, 255, 255),
    }
    local nBeads = 24
    local beadRadius = (WH_SIZE + 24) / 2
    for i = 1, nBeads do
        local angleRad = math.rad((i - 1) * (360 / nBeads))
        local bx = 0.5 + math.sin(angleRad) * 0.5
        local by = 0.5 - math.cos(angleRad) * 0.5

        local bead = Instance.new("Frame")
        bead.Size = UDim2.new(0, 12, 0, 12)
        bead.AnchorPoint = Vector2.new(0.5, 0.5)
        bead.Position = UDim2.new(bx, 0, by, 0)
        bead.BackgroundColor3 = BEAD_PALETTE[((i - 1) % #BEAD_PALETTE) + 1]
        bead.ZIndex = 5
        Instance.new("UICorner", bead).CornerRadius = UDim.new(1, 0)
        bead.Parent = wheelOuter
    end

    -- ── Pointeur Rouge Fixe (au centre en haut, pointe vers le bas) ──────────
    ptr = Instance.new("ImageLabel")
    ptr.Size = UDim2.new(0, 40, 0, 50)
    ptr.AnchorPoint = Vector2.new(0.5, 1)
    ptr.Position = UDim2.new(0.5, 0, 0, 15) -- En haut, pointant vers l'intérieur
    ptr.BackgroundTransparency = 1
    ptr.Image = "rbxassetid://4483362458" 
    ptr.ImageColor3 = Color3.fromRGB(255, 40, 40)
    ptr.Rotation = 180
    ptr.ZIndex = 15
    ptr.Parent = wheelOuter

    -- ── Bouton Central SPIN et Étoiles ─────────────────────────────────────────
    spinBtn = Instance.new("Frame")
    spinBtn.Size = UDim2.new(0, 100, 0, 100)
    spinBtn.AnchorPoint = Vector2.new(0.5, 0.5)
    spinBtn.Position = UDim2.new(0.5, 0, 0.5, 0)
    spinBtn.BackgroundColor3 = Color3.fromRGB(255, 230, 0) -- Jaune brillant
    spinBtn.ZIndex = 10
    spinBtn.Parent = wheelOuter
    Instance.new("UICorner", spinBtn).CornerRadius = UDim.new(1, 0)
    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = Color3.new(0, 0, 0); btnStroke.Thickness = 3; btnStroke.Parent = spinBtn

    -- 3 Étoiles en haut du bouton SPIN
    local stars = Instance.new("TextLabel")
    stars.Size = UDim2.new(1, 0, 0, 20)
    stars.Position = UDim2.new(0, 0, 0.15, 0)
    stars.BackgroundTransparency = 1
    stars.Text = "★ ★ ★"
    stars.TextColor3 = Color3.fromRGB(255, 215, 0)
    stars.Font = Enum.Font.GothamBlack
    stars.TextScaled = true
    stars.TextStrokeTransparency = 0
    stars.TextStrokeColor3 = Color3.new(0, 0, 0)
    stars.ZIndex = 11
    stars.Parent = spinBtn

    local spinLbl = Instance.new("TextLabel")
    spinLbl.Size = UDim2.new(1, 0, 0.4, 0)
    spinLbl.Position = UDim2.new(0, 0, 0.4, 0)
    spinLbl.BackgroundTransparency = 1
    spinLbl.Text = "SPIN"
    spinLbl.TextColor3 = Color3.new(0, 0, 0)
    spinLbl.Font = Enum.Font.GothamBlack
    spinLbl.TextScaled = true
    spinLbl.ZIndex = 11
    spinLbl.Parent = spinBtn

    -- ── UI de Victoire ────────────────────────────────────────────────────────
    winLabel = Instance.new("TextLabel")
    winLabel.Size = UDim2.new(0.8, 0, 0, 100)
    winLabel.AnchorPoint = Vector2.new(0.5, 0)
    winLabel.Position = UDim2.new(0.5, 0, 0.1, 0)
    winLabel.BackgroundTransparency = 1
    winLabel.Text = ""
    winLabel.TextColor3 = Color3.new(1, 1, 1)
    winLabel.Font = Enum.Font.LuckiestGuy
    winLabel.TextScaled = true
    winLabel.TextStrokeTransparency = 0
    winLabel.Visible = false
    winLabel.ZIndex = 20
    winLabel.Parent = overlay

    closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 240, 0, 60)
    closeBtn.AnchorPoint = Vector2.new(0.5, 1)
    closeBtn.Position = UDim2.new(0.5, 0, 0.9, 0)
    closeBtn.BackgroundColor3 = Color3.fromRGB(220, 40, 40)
    closeBtn.Text = "FERMER"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.Font = Enum.Font.GothamBlack
    closeBtn.TextSize = 28
    closeBtn.Visible = false
    closeBtn.ZIndex = 20
    closeBtn.Parent = overlay
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0.2, 0)
    local closeStroke = Instance.new("UIStroke")
    closeStroke.Color = Color3.new(0, 0, 0); closeStroke.Thickness = 2; closeStroke.Parent = closeBtn

    closeBtn.MouseButton1Click:Connect(function()
        spinGui.Enabled = false
    end)
end

-- ── ANIMATION TWEENSERVICE ──────────────────────────────
SpinResult.OnClientEvent:Connect(function(res)
    -- Si serveur refuse
    if not res.success then 
        warn("Erreur spin:", res.reason)
        return 
    end

    -- Création d'UI si non existant ou première fois
    if res.segments then
        createUI(res.segments)
    end
    if not spinGui then return end

    -- Cooldown Local par sécurité
    local now = tick()
    if now - lastSpinTime < SPIN_COOLDOWN then return end
    lastSpinTime = now

    -- Reset UI
    wheelCanvas.Rotation = 0
    winLabel.Visible = false
    closeBtn.Visible = false
    flashFrame.BackgroundTransparency = 1
    spinGui.Enabled = true

    -- Calcul exact : Le pointeur est à 0° (en haut). 
    -- La rotation de la roue (positif = sens horaire). 
    -- L'index N se trouve à un angle de (N-1) * 30.
    -- Pour l'amener à 0°, la roue doit pivoter vers 360 - (N-1)*30.
    local nSeg = #res.segments
    local segAngle = 360 / nSeg
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

    local lastTick = -1
    local conn = RunService.RenderStepped:Connect(function()
        wheelCanvas.Rotation = numVal.Value
        
        -- Clic-clic-clic sonore (dès qu'un segment passe)
        local currentSeg = math.floor(((numVal.Value + (segAngle / 2)) % 360) / segAngle)
        if currentSeg ~= lastTick then
            lastTick = currentSeg
            guiTickSound:Play()
            -- Animation pointeur 'frappé'
            ptr.Position = UDim2.new(0.5, 0, 0, 10)
            task.delay(0.05, function() if ptr then ptr.Position = UDim2.new(0.5, 0, 0, 15) end end)
        end
    end)

    tween.Completed:Connect(function()
        conn:Disconnect()
        numVal:Destroy()
        wheelCanvas.Rotation = finalAngle % 360

        -- Flash Blanc Stylisé
        flashFrame.BackgroundTransparency = 0
        TweenService:Create(flashFrame, TweenInfo.new(1.2), {BackgroundTransparency = 1}):Play()

        -- Textes et son "Jackpot"
        winLabel.Text = "TU AS GAGNÉ : " .. string.upper(res.memeName) .. " !"
        local rCol = RARITY_COLORS[res.memeRarity] or Color3.new(1, 1, 1)
        winLabel.TextColor3 = rCol
        winLabel.Visible = true

        if res.memeRarity == "LEGENDARY" or res.memeRarity == "EPIC" then
            fanfareSound:Play()
        else
            guiWinSound:Play()
        end

        closeBtn.Visible = true
    end)

    tween:Play()
end)

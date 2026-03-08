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

-- ── DÉCLARATION DE L'UI (Créée dynamiquement) ────────────
local spinGui
local overlay
local wheelOuter
local wheelCanvas
local ptr
local winLabel
local closeBtn
local flashFrame

local function createUI(segments)
    if spinGui then spinGui:Destroy() end

    spinGui = Instance.new("ScreenGui")
    spinGui.Name = "SpinGui"
    spinGui.IgnoreGuiInset = true
    spinGui.ResetOnSpawn = false
    spinGui.Enabled = false
    spinGui.Parent = PlayerGui

    -- Fond sombre
    overlay = Instance.new("Frame")
    overlay.Name = "Overlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
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
    
    wheelOuter = Instance.new("Frame")
    wheelOuter.Name = "WheelOuter"
    wheelOuter.Size = UDim2.new(0, WH_SIZE + 16, 0, WH_SIZE + 16)
    wheelOuter.AnchorPoint = Vector2.new(0.5, 0.5)
    wheelOuter.Position = UDim2.new(0.5, 0, 0.5, 0)
    wheelOuter.BackgroundColor3 = Color3.fromRGB(255, 215, 0) -- Bordure or
    wheelOuter.Parent = overlay
    Instance.new("UICorner", wheelOuter).CornerRadius = UDim.new(0.5, 0)

    wheelCanvas = Instance.new("CanvasGroup")
    wheelCanvas.Name = "WheelCanvas"
    wheelCanvas.Size = UDim2.new(0, WH_SIZE, 0, WH_SIZE)
    wheelCanvas.AnchorPoint = Vector2.new(0.5, 0.5)
    wheelCanvas.Position = UDim2.new(0.5, 0, 0.5, 0)
    wheelCanvas.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
    wheelCanvas.Parent = wheelOuter
    Instance.new("UICorner", wheelCanvas).CornerRadius = UDim.new(0.5, 0)

    -- Segments (12 Frame en éventail)
    local nSeg = #segments
    local radius = WH_SIZE / 2
    local arcWidth = 2 * radius * math.tan(math.rad(180 / nSeg)) + 4 -- +4 px overlap

    for i = 1, nSeg do
        local segData = segments[i]
        local angle = (i - 1) * (360 / nSeg)

        local sf = Instance.new("Frame")
        sf.Size  = UDim2.new(0, arcWidth, 0.5, 0)
        sf.AnchorPoint = Vector2.new(0.5, 1)
        sf.Position = UDim2.new(0.5, 0, 0.5, 0)
        sf.Rotation = angle
        sf.BackgroundColor3 = RARITY_COLORS[segData.rarity] or Color3.new(1,1,1)
        sf.BorderSizePixel = 0
        sf.Parent = wheelCanvas

        -- Texte orienté vers le centre (situé au bord extérieur)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1.5, 0, 0, 40)
        lbl.AnchorPoint = Vector2.new(0.5, 0.5)
        lbl.Position = UDim2.new(0.5, 0, 0.2, 0) -- 20% du haut (bord du cercle)
        lbl.BackgroundTransparency = 1
        lbl.Text = string.upper(segData.item.name)
        lbl.TextColor3 = Color3.new(1, 1, 1)
        lbl.Font = Enum.Font.LuckiestGuy
        lbl.TextScaled = true
        lbl.TextStrokeTransparency = 0
        lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
        lbl.Parent = sf

        -- Étoile
        if segData.rarity == "LEGENDARY" then
            local star = Instance.new("TextLabel")
            star.Size = UDim2.new(1, 0, 0, 24)
            star.AnchorPoint = Vector2.new(0.5, 0.5)
            star.Position = UDim2.new(0.5, 0, 0.45, 0)
            star.BackgroundTransparency = 1
            star.Text = "★ ★ ★"
            star.TextColor3 = Color3.fromRGB(255, 240, 60)
            star.Font = Enum.Font.GothamBlack
            star.TextScaled = true
            star.TextStrokeTransparency = 0
            star.Parent = sf
        end
    end

    -- Hub 2D Central
    local hub = Instance.new("Frame")
    hub.Size = UDim2.new(0, 90, 0, 90)
    hub.AnchorPoint = Vector2.new(0.5, 0.5)
    hub.Position = UDim2.new(0.5, 0, 0.5, 0)
    hub.BackgroundColor3 = Color3.fromRGB(180, 180, 180) -- Métal clair
    hub.ZIndex = 5
    hub.Parent = wheelOuter
    Instance.new("UICorner", hub).CornerRadius = UDim.new(0.5, 0)
    local hubStroke = Instance.new("UIStroke")
    hubStroke.Color = Color3.fromRGB(255, 215, 0); hubStroke.Thickness = 4; hubStroke.Parent = hub

    local hubLbl = Instance.new("TextLabel")
    hubLbl.Size = UDim2.new(1, 0, 1, 0)
    hubLbl.BackgroundTransparency = 1
    hubLbl.Text = "SPIN"
    hubLbl.TextColor3 = Color3.fromRGB(255, 230, 0)
    hubLbl.Font = Enum.Font.GothamBlack
    hubLbl.TextScaled = true
    hubLbl.ZIndex = 6
    hubLbl.Parent = hub

    -- Pointeur Rouge Fixe
    ptr = Instance.new("ImageLabel")
    ptr.Size = UDim2.new(0, 50, 0, 50)
    ptr.AnchorPoint = Vector2.new(0.5, 0.5)
    ptr.Position = UDim2.new(0.5, 0, 0, -10)
    ptr.BackgroundTransparency = 1
    ptr.Image = "rbxassetid://4483362458" -- Triangle générique
    ptr.ImageColor3 = Color3.new(1, 0, 0)
    ptr.Rotation = 180
    ptr.ZIndex = 10
    ptr.Parent = wheelOuter

    -- UI de Victoire
    winLabel = Instance.new("TextLabel")
    winLabel.Size = UDim2.new(0.8, 0, 0, 80)
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
    closeBtn.Size = UDim2.new(0, 200, 0, 50)
    closeBtn.AnchorPoint = Vector2.new(0.5, 1)
    closeBtn.Position = UDim2.new(0.5, 0, 0.9, 0)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
    closeBtn.Text = "FERMER"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.Font = Enum.Font.GothamBlack
    closeBtn.TextSize = 24
    closeBtn.Visible = false
    closeBtn.ZIndex = 20
    closeBtn.Parent = overlay
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0.2, 0)

    closeBtn.MouseButton1Click:Connect(function()
        spinGui.Enabled = false
    end)
end

-- ── ANIMATION ────────────────────────────────────────────
SpinResult.OnClientEvent:Connect(function(res)
    if not res.success then return end

    -- Création conditionnelle si on reçoit les segments pour la première fois
    if res.segments then
        createUI(res.segments)
    end
    if not spinGui then return end

    -- Reset
    wheelCanvas.Rotation = 0
    winLabel.Visible = false
    closeBtn.Visible = false
    flashFrame.BackgroundTransparency = 1
    spinGui.Enabled = true

    -- Calcul (Le pointeur est à 0°. Roue tourne dans + rotation)
    -- Le segment N est à (N-1)*30 degrés. On veut qu'il arrive sous le pointeur (= 0 mod 360).
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
        
        -- Clic-clic-clic sonore
        local currentSeg = math.floor((numVal.Value % 360) / segAngle)
        if currentSeg ~= lastTick then
            lastTick = currentSeg
            guiTickSound:Play()
            -- Animation pointeur
            ptr.Position = UDim2.new(0.5, 0, 0, -15)
            task.delay(0.05, function() if ptr then ptr.Position = UDim2.new(0.5, 0, 0, -10) end end)
        end
    end)

    tween.Completed:Connect(function()
        conn:Disconnect()
        numVal:Destroy()
        wheelCanvas.Rotation = finalAngle % 360

        -- Flash Blanc
        flashFrame.BackgroundTransparency = 0
        TweenService:Create(flashFrame, TweenInfo.new(1), {BackgroundTransparency = 1}):Play()

        -- Textes et son
        winLabel.Text = "TU AS GAGNÉ : " .. string.upper(res.memeName) .. " !"
        local rCol = RARITY_COLORS[res.memeRarity] or Color3.new(1,1,1)
        winLabel.TextStrokeColor3 = Color3.new(0,0,0)
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

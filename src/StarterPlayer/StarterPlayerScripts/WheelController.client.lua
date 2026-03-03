-- WheelController.client.lua
-- Roue colorée style émission TV + ScreenGui overlay

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player     = Players.LocalPlayer
local playerGui  = player:WaitForChild("PlayerGui")
local Events     = ReplicatedStorage:WaitForChild("Events")
local Constants  = require(ReplicatedStorage:WaitForChild("Constants"))
local LootTables = require(ReplicatedStorage:WaitForChild("LootTables"))

local SpinRequest = Events:WaitForChild("SpinRequest")
local SpinResult  = Events:WaitForChild("SpinResult")

local wheelAssets = workspace:WaitForChild("WheelAssets")

local currentPhysicalWheel = nil
local currentWheelId       = 1

-- ── Couleurs ───────────────────────────────────────────────────────────────────
local SEGMENT_COLORS = {
    Color3.fromRGB(255,  80, 120),   -- 1  Rose
    Color3.fromRGB(255, 140,  40),   -- 2  Orange
    Color3.fromRGB(240, 220,  30),   -- 3  Jaune
    Color3.fromRGB( 60, 190,  80),   -- 4  Vert
    Color3.fromRGB( 40, 180, 255),   -- 5  Bleu clair
    Color3.fromRGB( 80,  80, 220),   -- 6  Bleu foncé
    Color3.fromRGB(150,  50, 220),   -- 7  Violet
    Color3.fromRGB(220,  40,  40),   -- 8  Rouge
    Color3.fromRGB( 40, 175, 155),   -- 9  Teal
    Color3.fromRGB(160, 230,  50),   -- 10 Lime
    Color3.fromRGB(255, 100,  60),   -- 11 Corail
    Color3.fromRGB(220,  60, 180),   -- 12 Magenta
}

local GREEN_OUTER  = Color3.fromRGB( 50, 175,  60)
local GREEN_DARK   = Color3.fromRGB( 30, 130,  40)
local PINK_RING    = Color3.fromRGB(220,  50, 120)
local WHITE        = Color3.new(1, 1, 1)
local DARK_RED     = Color3.fromRGB(140,  20,  20)

local RARITY_COLORS = {
    NORMAL    = Color3.fromRGB(190, 190, 190),
    RARE      = Color3.fromRGB( 80, 180, 255),
    MYTHIC    = Color3.fromRGB(170,  80, 255),
    LEGENDARY = Color3.fromRGB(255, 180,   0),
    ULTRA     = Color3.fromRGB(255,  50, 150),
}

-- ── Config roue ────────────────────────────────────────────────────────────────
local WHEEL_ITEMS = LootTables.Wheels[1].Items
local N       = 12
local SEG_ANG = 360 / N
local DIAM    = 500
local RAD     = DIAM / 2
local SEG_W   = math.ceil(2 * math.tan(math.rad(SEG_ANG / 2)) * RAD)

local isSpinning = false

local DEG_PER_SEGMENT = SEG_ANG
local HALF_SEGMENT    = DEG_PER_SEGMENT / 2
local MIN_EXTRA_TURNS = 5
local MAX_EXTRA_TURNS = 8
local MAX_WOBBLE      = 12

local function getTargetAngle(currentRotation, segmentId)
    local segCenter  = (segmentId - 1) * DEG_PER_SEGMENT + HALF_SEGMENT
    local currentMod = currentRotation % 360
    local offset     = segCenter - currentMod
    if offset < 0 then offset += 360 end
    local extraTurns = math.random(MIN_EXTRA_TURNS, MAX_EXTRA_TURNS)
    local wobble     = math.random(-MAX_WOBBLE, MAX_WOBBLE)
    return currentRotation + offset + (extraTurns * 360) + wobble
end

-- ── Construction UI ────────────────────────────────────────────────────────────
local TITLE_H    = 48
local GAP        = 8
local RESULT_H   = 70
local OUTER_SIZE = DIAM + 60   -- 560
local PANEL_W    = OUTER_SIZE + 40          -- 600
local PANEL_H    = TITLE_H + GAP + OUTER_SIZE + GAP + RESULT_H  -- 694

local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "SpinWheelUI"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn   = false
screenGui.Enabled        = false
screenGui.Parent         = playerGui

local dimBG = Instance.new("Frame")
dimBG.Size                   = UDim2.new(1, 0, 1, 0)
dimBG.BackgroundColor3       = Color3.new(0, 0, 0)
dimBG.BackgroundTransparency = 0.5
dimBG.BorderSizePixel        = 0
dimBG.Parent                 = screenGui

local panel = Instance.new("Frame")
panel.Size             = UDim2.new(0, PANEL_W, 0, PANEL_H)
panel.AnchorPoint      = Vector2.new(0.5, 0.5)
panel.Position         = UDim2.new(0.5, 0, 0.5, 0)
panel.BackgroundTransparency = 1
panel.Parent           = screenGui

-- Titre (centré en haut du panel)
local title = Instance.new("TextLabel")
title.Size                   = UDim2.new(1, 0, 0, TITLE_H)
title.Position               = UDim2.new(0, 0, 0, 0)
title.BackgroundTransparency = 1
title.Text                   = "✦  BRAINROT WHEEL  ✦"
title.TextColor3             = WHITE
title.Font                   = Enum.Font.GothamBlack
title.TextSize               = 28
title.TextXAlignment         = Enum.TextXAlignment.Center
title.Parent                 = panel

-- Bouton fermer (coin haut-droit du panel)
local closeBtn = Instance.new("TextButton")
closeBtn.Size             = UDim2.new(0, 40, 0, 40)
closeBtn.AnchorPoint      = Vector2.new(1, 0)
closeBtn.Position         = UDim2.new(1, 0, 0, 0)
closeBtn.BackgroundColor3 = Color3.fromRGB(190, 40, 40)
closeBtn.Text             = "✕"
closeBtn.TextColor3       = WHITE
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.TextSize         = 20
closeBtn.ZIndex           = 20
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0.5, 0)
closeBtn.Parent = panel

-- ── Anneau extérieur VERT avec points blancs ───────────────────────────────────
local outerRing = Instance.new("Frame")
outerRing.Name             = "OuterRing"
outerRing.Size             = UDim2.new(0, OUTER_SIZE, 0, OUTER_SIZE)
outerRing.AnchorPoint      = Vector2.new(0.5, 0)
outerRing.Position         = UDim2.new(0.5, 0, 0, TITLE_H + GAP)
outerRing.BackgroundColor3 = GREEN_OUTER
outerRing.BorderSizePixel  = 0
Instance.new("UICorner", outerRing).CornerRadius = UDim.new(0.5, 0)
outerRing.Parent = panel

local outerStroke = Instance.new("UIStroke")
outerStroke.Color     = GREEN_DARK
outerStroke.Thickness = 5
outerStroke.Parent    = outerRing

-- Points blancs autour de l'anneau
local outerR      = OUTER_SIZE / 2
local DOT_COUNT   = 24
local DOT_PLACE_R = outerR - 14
for i = 0, DOT_COUNT - 1 do
    local angle = math.rad(i * (360 / DOT_COUNT))
    local cx    = outerR + math.sin(angle) * DOT_PLACE_R
    local cy    = outerR - math.cos(angle) * DOT_PLACE_R
    local dot   = Instance.new("Frame")
    dot.Size             = UDim2.new(0, 11, 0, 11)
    dot.AnchorPoint      = Vector2.new(0.5, 0.5)
    dot.Position         = UDim2.new(0, cx, 0, cy)
    dot.BackgroundColor3 = WHITE
    dot.BorderSizePixel  = 0
    dot.ZIndex           = 2
    Instance.new("UICorner", dot).CornerRadius = UDim.new(0.5, 0)
    dot.Parent = outerRing
end

-- ── Anneau ROSE ────────────────────────────────────────────────────────────────
local innerRingBorder = Instance.new("Frame")
innerRingBorder.Size             = UDim2.new(0, DIAM + 24, 0, DIAM + 24)
innerRingBorder.AnchorPoint      = Vector2.new(0.5, 0.5)
innerRingBorder.Position         = UDim2.new(0.5, 0, 0.5, 0)
innerRingBorder.BackgroundColor3 = PINK_RING
innerRingBorder.BorderSizePixel  = 0
Instance.new("UICorner", innerRingBorder).CornerRadius = UDim.new(0.5, 0)
innerRingBorder.Parent = outerRing

-- ── Disque rotatif ─────────────────────────────────────────────────────────────
local wheelDisk = Instance.new("Frame")
wheelDisk.Name             = "WheelDisk"
wheelDisk.Size             = UDim2.new(0, DIAM, 0, DIAM)
wheelDisk.AnchorPoint      = Vector2.new(0.5, 0.5)
wheelDisk.Position         = UDim2.new(0.5, 0, 0.5, 0)
wheelDisk.BackgroundColor3 = SEGMENT_COLORS[1]
wheelDisk.BorderSizePixel  = 0
wheelDisk.ClipsDescendants = true
Instance.new("UICorner", wheelDisk).CornerRadius = UDim.new(0.5, 0)
wheelDisk.Parent = innerRingBorder

-- Segments : 6 paires de segments opposés.
-- Chaque paire = demi-barre HAUT (AnchorPoint bas) + demi-barre BAS (AnchorPoint haut)
-- Les deux demi-barres partagent la même rotation et couvrent les deux moitiés du disque.
local N_THIN   = 4
local THIN_ANG = SEG_ANG / N_THIN                                            -- 7.5°
local THIN_W   = math.ceil(2 * math.tan(math.rad(THIN_ANG / 2)) * RAD) + 4  -- ~37 px
local HALF     = N / 2                                                        -- 6

for pair = 0, HALF - 1 do
    local colorUp   = SEGMENT_COLORS[pair + 1]          -- segments 1-6  (haut)
    local colorDown = SEGMENT_COLORS[pair + 1 + HALF]   -- segments 7-12 (bas)
    for j = 0, N_THIN - 1 do
        local angle = pair * SEG_ANG + j * THIN_ANG + THIN_ANG / 2

        -- Demi-barre supérieure : pivot en bas, s'étend vers le bord "haut"
        local tU = Instance.new("Frame")
        tU.Size             = UDim2.new(0, THIN_W, 0, RAD + 5)
        tU.AnchorPoint      = Vector2.new(0.5, 1)
        tU.Position         = UDim2.new(0.5, 0, 0.5, 0)
        tU.Rotation         = angle
        tU.BackgroundColor3 = colorUp
        tU.BorderSizePixel  = 0
        tU.ZIndex           = 2
        tU.Parent           = wheelDisk

        -- Demi-barre inférieure : pivot en haut, s'étend vers le bord opposé
        local tD = Instance.new("Frame")
        tD.Size             = UDim2.new(0, THIN_W, 0, RAD + 5)
        tD.AnchorPoint      = Vector2.new(0.5, 0)
        tD.Position         = UDim2.new(0.5, 0, 0.5, 0)
        tD.Rotation         = angle
        tD.BackgroundColor3 = colorDown
        tD.BorderSizePixel  = 0
        tD.ZIndex           = 2
        tD.Parent           = wheelDisk
    end
end

-- Séparateurs blancs : pleine hauteur, centrés (AnchorPoint centre)
for i = 0, N - 1 do
    local div = Instance.new("Frame")
    div.Size             = UDim2.new(0, 3, 0, DIAM)
    div.AnchorPoint      = Vector2.new(0.5, 0.5)
    div.Position         = UDim2.new(0.5, 0, 0.5, 0)
    div.Rotation         = i * SEG_ANG
    div.BackgroundColor3 = WHITE
    div.BorderSizePixel  = 0
    div.ZIndex           = 3
    div.Parent           = wheelDisk
end

-- Labels sur chaque segment
for i = 1, N do
    local item = WHEEL_ITEMS[i]
    if not item then continue end

    local midAngle = (i - 1) * SEG_ANG + SEG_ANG / 2
    local rad      = math.rad(midAngle)
    local labelR   = RAD * 0.68
    local lx       = DIAM / 2 + labelR * math.sin(rad)
    local ly       = DIAM / 2 - labelR * math.cos(rad)

    -- Retourner le texte pour qu'il soit lisible dans la moitié basse
    local textRot = midAngle
    if midAngle > 90 and midAngle < 270 then
        textRot = midAngle + 180
    end

    local nameL = Instance.new("TextLabel")
    nameL.Size                   = UDim2.new(0, 120, 0, 24)
    nameL.AnchorPoint            = Vector2.new(0.5, 0.5)
    nameL.Position               = UDim2.new(0, lx, 0, ly)
    nameL.Rotation               = textRot
    nameL.BackgroundTransparency = 1
    nameL.Text                   = item.Name
    nameL.TextColor3             = WHITE
    nameL.Font                   = Enum.Font.GothamBold
    nameL.TextSize               = 12
    nameL.ZIndex                 = 4
    nameL.Parent                 = wheelDisk
end

-- ── Centre blanc ───────────────────────────────────────────────────────────────
local centerDecor = Instance.new("Frame")
centerDecor.Size             = UDim2.new(0, 104, 0, 104)
centerDecor.AnchorPoint      = Vector2.new(0.5, 0.5)
centerDecor.Position         = UDim2.new(0.5, 0, 0.5, 0)
centerDecor.BackgroundColor3 = WHITE
centerDecor.BorderSizePixel  = 0
centerDecor.ZIndex           = 5
Instance.new("UICorner", centerDecor).CornerRadius = UDim.new(0.5, 0)
centerDecor.Parent = innerRingBorder

local centerBtn = Instance.new("TextButton")
centerBtn.Name             = "CenterBtn"
centerBtn.Size             = UDim2.new(0, 92, 0, 92)
centerBtn.AnchorPoint      = Vector2.new(0.5, 0.5)
centerBtn.Position         = UDim2.new(0.5, 0, 0.5, 0)
centerBtn.BackgroundColor3 = WHITE
centerBtn.BorderSizePixel  = 0
centerBtn.Text             = "SPIN!"
centerBtn.TextColor3       = Color3.fromRGB(30, 140, 30)
centerBtn.Font             = Enum.Font.GothamBlack
centerBtn.TextSize         = 17
centerBtn.ZIndex           = 6
Instance.new("UICorner", centerBtn).CornerRadius = UDim.new(0.5, 0)
centerBtn.Parent = innerRingBorder

-- ── Pointeur ▼ rouge foncé en haut ─────────────────────────────────────────────
local pointerLabel = Instance.new("TextLabel")
pointerLabel.Size                   = UDim2.new(0, 44, 0, 40)
pointerLabel.AnchorPoint            = Vector2.new(0.5, 1)
pointerLabel.Position               = UDim2.new(0.5, 0, 0, 2)
pointerLabel.BackgroundTransparency = 1
pointerLabel.Text                   = "▼"
pointerLabel.TextColor3             = DARK_RED
pointerLabel.TextSize               = 36
pointerLabel.Font                   = Enum.Font.GothamBlack
pointerLabel.ZIndex                 = 10
pointerLabel.Parent                 = outerRing

-- ── Panneau résultat (dans le panel, sous l'anneau) ────────────────────────────
local resultFrame = Instance.new("Frame")
resultFrame.Size                   = UDim2.new(1, 0, 0, RESULT_H)
resultFrame.Position               = UDim2.new(0, 0, 0, TITLE_H + GAP + OUTER_SIZE + GAP)
resultFrame.BackgroundTransparency = 1
resultFrame.Visible                = false
resultFrame.Parent                 = panel

local resultLabel = Instance.new("TextLabel")
resultLabel.Name                   = "ResultLabel"
resultLabel.Size                   = UDim2.new(1, 0, 0.55, 0)
resultLabel.BackgroundTransparency = 1
resultLabel.Text                   = ""
resultLabel.TextColor3             = WHITE
resultLabel.Font                   = Enum.Font.GothamBlack
resultLabel.TextSize               = 26
resultLabel.Parent                 = resultFrame

local rarityLabel = Instance.new("TextLabel")
rarityLabel.Name                   = "RarityLabel"
rarityLabel.Size                   = UDim2.new(1, 0, 0.45, 0)
rarityLabel.Position               = UDim2.new(0, 0, 0.55, 0)
rarityLabel.BackgroundTransparency = 1
rarityLabel.Text                   = ""
rarityLabel.Font                   = Enum.Font.GothamBold
rarityLabel.TextSize               = 18
rarityLabel.Parent                 = resultFrame

-- ── Logique ────────────────────────────────────────────────────────────────────
local function openWheel(wheelId)
    currentWheelId = wheelId or 1
    local wheelData = LootTables.Wheels[currentWheelId]
    title.Text           = "✦  " .. string.upper(wheelData and wheelData.Name or "BRAINROT WHEEL") .. "  ✦"
    resultFrame.Visible  = false
    centerBtn.Text       = "SPIN!"
    centerBtn.TextColor3 = Color3.fromRGB(30, 140, 30)
    screenGui.Enabled    = true
end

local function closeWheel()
    if not isSpinning then
        screenGui.Enabled = false
    end
end

closeBtn.MouseButton1Click:Connect(closeWheel)

local function connectWheel(wheelFolder)
    local physWheel = wheelFolder:WaitForChild("PhysicalWheel", 10)
    if not physWheel then return end
    local cd  = physWheel:FindFirstChildOfClass("ClickDetector")
    local wid = wheelFolder:GetAttribute("WheelIndex") or 1
    if cd then
        cd.MouseClick:Connect(function()
            currentPhysicalWheel = physWheel
            openWheel(wid)
        end)
    end
end

-- Connecte les roues déjà présentes
for _, wheelFolder in ipairs(wheelAssets:GetChildren()) do
    task.spawn(connectWheel, wheelFolder)
end
-- Connecte les roues ajoutées après le démarrage
wheelAssets.ChildAdded:Connect(function(wheelFolder)
    task.spawn(connectWheel, wheelFolder)
end)

centerBtn.MouseButton1Click:Connect(function()
    if isSpinning then return end
    isSpinning           = true
    resultFrame.Visible  = false
    centerBtn.Text       = "..."
    centerBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
    SpinRequest:FireServer(currentWheelId)
end)

SpinResult.OnClientEvent:Connect(function(result)
    local targetRot    = getTargetAngle(wheelDisk.Rotation, result.SegmentId)
    local totalDegrees = targetRot - wheelDisk.Rotation

    print(string.format("🎯 Segment tiré : %d | %s | %s", result.SegmentId, result.Name, result.Rarity))

    local tweenInfo = TweenInfo.new(5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

    local uiTween = TweenService:Create(wheelDisk, tweenInfo, { Rotation = targetRot })
    uiTween:Play()

    if currentPhysicalWheel then
        local startCF  = currentPhysicalWheel.CFrame
        local targetCF = startCF * CFrame.Angles(math.rad(totalDegrees), 0, 0)
        TweenService:Create(currentPhysicalWheel, tweenInfo, { CFrame = targetCF }):Play()
    end

    uiTween.Completed:Wait()

    local rarityInfo       = Constants.RARITIES[result.Rarity]
    resultLabel.Text       = string.format("🎉  Gagné : %s !", string.upper(result.Name))
    rarityLabel.Text       = "✦  " .. string.upper(result.Rarity) .. "  ✦"
    rarityLabel.TextColor3 = rarityInfo.Color
    resultFrame.Visible    = true

    centerBtn.Text       = "SPIN!"
    centerBtn.TextColor3 = Color3.fromRGB(30, 140, 30)

    task.wait(4)
    resultFrame.Visible = false
    isSpinning          = false
end)

print("🎡 [WheelController] Prêt !")

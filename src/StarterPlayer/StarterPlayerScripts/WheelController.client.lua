-- WheelController.client.lua
-- Roue dorée à 12 segments avec ScreenGui overlay

local Players        = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService   = game:GetService("TweenService")

local player     = Players.LocalPlayer
local playerGui  = player:WaitForChild("PlayerGui")
local Events     = ReplicatedStorage:WaitForChild("Events")
local Constants  = require(ReplicatedStorage:WaitForChild("Constants"))
local LootTables = require(ReplicatedStorage:WaitForChild("LootTables"))

local SpinRequest = Events:WaitForChild("SpinRequest")
local SpinResult  = Events:WaitForChild("SpinResult")

local wheelAssets    = workspace:WaitForChild("WheelAssets")
local physicalWheel  = wheelAssets:WaitForChild("PhysicalWheel")
local clickDetector  = physicalWheel:WaitForChild("ClickDetector")

-- ── Couleurs ──────────────────────────────────────────────────────────────────
local GOLD_BRIGHT  = Color3.fromRGB(255, 210, 40)
local GOLD_DARK    = Color3.fromRGB(185, 130,  0)
local GOLD_BORDER  = Color3.fromRGB(255, 235, 120)
local GOLD_DIVIDER = Color3.fromRGB(220, 175, 20)
local GOLD_RIM2    = Color3.fromRGB(150, 100,  0)

local RARITY_COLORS = {
    NORMAL    = Color3.fromRGB(190, 190, 190),
    RARE      = Color3.fromRGB(80,  180, 255),
    MYTHIC    = Color3.fromRGB(170,  80, 255),
    LEGENDARY = Color3.fromRGB(255, 180,   0),
    ULTRA     = Color3.fromRGB(255,  50, 150),
}
local RARITY_PCT = {
    NORMAL = "60%", RARE = "20%", MYTHIC = "10%", LEGENDARY = "8%", ULTRA = "2%",
}

-- ── Config roue ───────────────────────────────────────────────────────────────
local WHEEL_ITEMS = LootTables.Wheels[1].Items
local N       = 12                          -- nombre de segments
local SEG_ANG = 360 / N                    -- 30° par segment
local DIAM    = 500                         -- diamètre en px
local RAD     = DIAM / 2                   -- 250 px
-- Largeur du rectangle pour couvrir exactement 30° au bord extérieur
local SEG_W   = math.ceil(2 * math.tan(math.rad(SEG_ANG / 2)) * RAD)   -- ~134 px

local isSpinning = false

-- ── Constantes d'angle (intégration du système de probabilité par poids) ──────
local DEG_PER_SEGMENT = SEG_ANG          -- 30° par segment
local HALF_SEGMENT    = DEG_PER_SEGMENT / 2   -- 15°
local MIN_EXTRA_TURNS = 5
local MAX_EXTRA_TURNS = 8
local MAX_WOBBLE      = 12   -- décalage aléatoire max (< 15° pour rester dans le segment)

-- Calcule l'angle exact pour que le segment gagnant s'arrête sous le pointeur ▼
-- Logique : le centre du segment N est à (N-1)×30 + 15° depuis 12h (sens horaire)
-- On tourne la roue de la différence nécessaire + tours bonus + petit wobble
local function getTargetAngle(currentRotation, segmentId)
    local segCenter  = (segmentId - 1) * DEG_PER_SEGMENT + HALF_SEGMENT
    local currentMod = currentRotation % 360
    local offset     = segCenter - currentMod
    if offset < 0 then offset += 360 end   -- garantit une rotation toujours en avant
    local extraTurns = math.random(MIN_EXTRA_TURNS, MAX_EXTRA_TURNS)
    local wobble     = math.random(-MAX_WOBBLE, MAX_WOBBLE)
    return currentRotation + offset + (extraTurns * 360) + wobble
end

-- ── Construction UI ───────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name          = "SpinWheelUI"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn  = false
screenGui.Enabled       = false
screenGui.Parent        = playerGui

-- Fond assombri
local dimBG = Instance.new("Frame")
dimBG.Size                  = UDim2.new(1, 0, 1, 0)
dimBG.BackgroundColor3      = Color3.new(0, 0, 0)
dimBG.BackgroundTransparency = 0.45
dimBG.BorderSizePixel       = 0
dimBG.Parent                = screenGui

-- Panneau principal (centré)
local panel = Instance.new("Frame")
panel.Size             = UDim2.new(0, DIAM + 80, 0, DIAM + 145)
panel.AnchorPoint      = Vector2.new(0.5, 0.5)
panel.Position         = UDim2.new(0.5, 0, 0.5, 0)
panel.BackgroundTransparency = 1
panel.Parent           = screenGui

-- Titre
local title = Instance.new("TextLabel")
title.Size             = UDim2.new(1, 0, 0, 48)
title.BackgroundTransparency = 1
title.Text             = "✦  BRAINROT WHEEL  ✦"
title.TextColor3       = GOLD_BORDER
title.Font             = Enum.Font.GothamBlack
title.TextSize         = 30
title.Parent           = panel

-- Bouton fermer (×)
local closeBtn = Instance.new("TextButton")
closeBtn.Size             = UDim2.new(0, 44, 0, 44)
closeBtn.AnchorPoint      = Vector2.new(1, 0)
closeBtn.Position         = UDim2.new(1, 0, 0, 0)
closeBtn.BackgroundColor3 = Color3.fromRGB(190, 40, 40)
closeBtn.Text             = "✕"
closeBtn.TextColor3       = Color3.new(1, 1, 1)
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.TextSize         = 22
closeBtn.ZIndex           = 20
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0.5, 0)
closeBtn.Parent = panel

-- ── Anneau extérieur doré ─────────────────────────────────────────────────────
local outerRing = Instance.new("Frame")
outerRing.Name             = "OuterRing"
outerRing.Size             = UDim2.new(0, DIAM + 30, 0, DIAM + 30)
outerRing.AnchorPoint      = Vector2.new(0.5, 0)
outerRing.Position         = UDim2.new(0.5, 0, 0, 50)
outerRing.BackgroundColor3 = GOLD_BORDER
outerRing.BorderSizePixel  = 0
Instance.new("UICorner", outerRing).CornerRadius = UDim.new(0.5, 0)
outerRing.Parent = panel

-- Anneau intérieur (deuxième bord)
local innerRingBorder = Instance.new("Frame")
innerRingBorder.Size             = UDim2.new(0, DIAM + 10, 0, DIAM + 10)
innerRingBorder.AnchorPoint      = Vector2.new(0.5, 0.5)
innerRingBorder.Position         = UDim2.new(0.5, 0, 0.5, 0)
innerRingBorder.BackgroundColor3 = GOLD_RIM2
innerRingBorder.BorderSizePixel  = 0
Instance.new("UICorner", innerRingBorder).CornerRadius = UDim.new(0.5, 0)
innerRingBorder.Parent = outerRing

-- ── Disque rotatif ────────────────────────────────────────────────────────────
-- C'est le seul élément qui tourne ; ClipsDescendants + UICorner = clip circulaire
local wheelDisk = Instance.new("Frame")
wheelDisk.Name             = "WheelDisk"
wheelDisk.Size             = UDim2.new(0, DIAM, 0, DIAM)
wheelDisk.AnchorPoint      = Vector2.new(0.5, 0.5)
wheelDisk.Position         = UDim2.new(0.5, 0, 0.5, 0)
wheelDisk.BackgroundColor3 = GOLD_DARK   -- fond = segments impairs
wheelDisk.BorderSizePixel  = 0
wheelDisk.ClipsDescendants = true
Instance.new("UICorner", wheelDisk).CornerRadius = UDim.new(0.5, 0)
wheelDisk.Parent = innerRingBorder

-- Segments pairs (or vif) : rectangles du centre vers le bord, pivotés au centre
for i = 0, N - 1, 2 do
    local midAngle = i * SEG_ANG + SEG_ANG / 2
    local seg = Instance.new("Frame")
    seg.Size             = UDim2.new(0, SEG_W, 0, RAD)
    seg.AnchorPoint      = Vector2.new(0.5, 1)   -- pivot = bas-centre = centre de la roue
    seg.Position         = UDim2.new(0.5, 0, 0.5, 0)
    seg.Rotation         = midAngle
    seg.BackgroundColor3 = GOLD_BRIGHT
    seg.BorderSizePixel  = 0
    seg.ZIndex           = 2
    seg.Parent           = wheelDisk
end

-- Lignes séparatrices entre les segments
for i = 0, N - 1 do
    local div = Instance.new("Frame")
    div.Size             = UDim2.new(0, 2, 0, RAD)
    div.AnchorPoint      = Vector2.new(0.5, 1)
    div.Position         = UDim2.new(0.5, 0, 0.5, 0)
    div.Rotation         = i * SEG_ANG
    div.BackgroundColor3 = GOLD_DIVIDER
    div.BorderSizePixel  = 0
    div.ZIndex           = 3
    div.Parent           = wheelDisk
end

-- Labels (nom + rareté %) sur chaque segment
for i = 1, N do
    local item = WHEEL_ITEMS[i]
    if not item then continue end

    local midAngle = (i - 1) * SEG_ANG + SEG_ANG / 2
    local rad      = math.rad(midAngle)
    local labelR   = RAD * 0.62   -- 62 % du rayon depuis le centre
    local lx       = DIAM / 2 + labelR * math.sin(rad)
    local ly       = DIAM / 2 - labelR * math.cos(rad)

    local rColor = RARITY_COLORS[item.Rarity] or Color3.new(1, 1, 1)

    -- Numéro de segment
    local numL = Instance.new("TextLabel")
    numL.Size             = UDim2.new(0, 20, 0, 14)
    numL.AnchorPoint      = Vector2.new(0.5, 0.5)
    numL.Position         = UDim2.new(0, lx, 0, ly - 18)
    numL.Rotation         = midAngle
    numL.BackgroundTransparency = 1
    numL.Text             = tostring(i)
    numL.TextColor3       = GOLD_BORDER
    numL.Font             = Enum.Font.GothamBlack
    numL.TextSize         = 11
    numL.ZIndex           = 4
    numL.Parent           = wheelDisk

    -- Nom de l'item
    local nameL = Instance.new("TextLabel")
    nameL.Size             = UDim2.new(0, 100, 0, 16)
    nameL.AnchorPoint      = Vector2.new(0.5, 0.5)
    nameL.Position         = UDim2.new(0, lx, 0, ly - 4)
    nameL.Rotation         = midAngle
    nameL.BackgroundTransparency = 1
    nameL.Text             = item.Name
    nameL.TextColor3       = Color3.new(1, 1, 1)
    nameL.Font             = Enum.Font.GothamBold
    nameL.TextSize         = 10
    nameL.ZIndex           = 4
    nameL.Parent           = wheelDisk

    -- Pourcentage de la rareté
    local pctL = Instance.new("TextLabel")
    pctL.Size             = UDim2.new(0, 80, 0, 13)
    pctL.AnchorPoint      = Vector2.new(0.5, 0.5)
    pctL.Position         = UDim2.new(0, lx, 0, ly + 10)
    pctL.Rotation         = midAngle
    pctL.BackgroundTransparency = 1
    pctL.Text             = RARITY_PCT[item.Rarity] or ""
    pctL.TextColor3       = rColor
    pctL.Font             = Enum.Font.Gotham
    pctL.TextSize         = 9
    pctL.ZIndex           = 4
    pctL.Parent           = wheelDisk

    -- Étoile décorative
    local starL = Instance.new("TextLabel")
    starL.Size             = UDim2.new(0, 16, 0, 16)
    starL.AnchorPoint      = Vector2.new(0.5, 0.5)
    starL.Position         = UDim2.new(0, lx, 0, ly + 22)
    starL.Rotation         = midAngle
    starL.BackgroundTransparency = 1
    starL.Text             = "★"
    starL.TextColor3       = rColor
    starL.Font             = Enum.Font.GothamBold
    starL.TextSize         = 12
    starL.ZIndex           = 4
    starL.Parent           = wheelDisk
end

-- ── Centre (ne tourne PAS → enfant de innerRingBorder) ───────────────────────
local centerDecor = Instance.new("Frame")
centerDecor.Size             = UDim2.new(0, 88, 0, 88)
centerDecor.AnchorPoint      = Vector2.new(0.5, 0.5)
centerDecor.Position         = UDim2.new(0.5, 0, 0.5, 0)
centerDecor.BackgroundColor3 = GOLD_DIVIDER
centerDecor.BorderSizePixel  = 0
centerDecor.ZIndex           = 5
Instance.new("UICorner", centerDecor).CornerRadius = UDim.new(0.5, 0)
centerDecor.Parent = innerRingBorder

local centerBtn = Instance.new("TextButton")
centerBtn.Name             = "CenterBtn"
centerBtn.Size             = UDim2.new(0, 72, 0, 72)
centerBtn.AnchorPoint      = Vector2.new(0.5, 0.5)
centerBtn.Position         = UDim2.new(0.5, 0, 0.5, 0)
centerBtn.BackgroundColor3 = Color3.new(1, 1, 1)
centerBtn.BorderSizePixel  = 0
centerBtn.Text             = "SPIN!"
centerBtn.TextColor3       = Color3.fromRGB(30, 160, 30)
centerBtn.Font             = Enum.Font.GothamBlack
centerBtn.TextSize         = 14
centerBtn.ZIndex           = 6
Instance.new("UICorner", centerBtn).CornerRadius = UDim.new(0.5, 0)
centerBtn.Parent = innerRingBorder

-- ── Pointeur ▼ (ne tourne PAS → enfant de outerRing) ─────────────────────────
local pointerLabel = Instance.new("TextLabel")
pointerLabel.Size             = UDim2.new(0, 44, 0, 40)
pointerLabel.AnchorPoint      = Vector2.new(0.5, 1)
pointerLabel.Position         = UDim2.new(0.5, 0, 0, 2)   -- juste au-dessus du ring
pointerLabel.BackgroundTransparency = 1
pointerLabel.Text             = "▼"
pointerLabel.TextColor3       = Color3.fromRGB(220, 50, 50)
pointerLabel.TextSize         = 34
pointerLabel.Font             = Enum.Font.GothamBlack
pointerLabel.ZIndex           = 10
pointerLabel.Parent           = outerRing

-- ── Panneau résultat (sous la roue) ──────────────────────────────────────────
local resultFrame = Instance.new("Frame")
resultFrame.Size             = UDim2.new(1, 0, 0, 72)
resultFrame.Position         = UDim2.new(0, 0, 1, 14)
resultFrame.BackgroundTransparency = 1
resultFrame.Visible          = false
resultFrame.Parent           = panel

local resultLabel = Instance.new("TextLabel")
resultLabel.Name             = "ResultLabel"
resultLabel.Size             = UDim2.new(1, 0, 0.55, 0)
resultLabel.BackgroundTransparency = 1
resultLabel.Text             = ""
resultLabel.TextColor3       = Color3.new(1, 1, 1)
resultLabel.Font             = Enum.Font.GothamBlack
resultLabel.TextSize         = 26
resultLabel.Parent           = resultFrame

local rarityLabel = Instance.new("TextLabel")
rarityLabel.Name             = "RarityLabel"
rarityLabel.Size             = UDim2.new(1, 0, 0.45, 0)
rarityLabel.Position         = UDim2.new(0, 0, 0.55, 0)
rarityLabel.BackgroundTransparency = 1
rarityLabel.Text             = ""
rarityLabel.Font             = Enum.Font.GothamBold
rarityLabel.TextSize         = 18
rarityLabel.Parent           = resultFrame

-- ── Logique ───────────────────────────────────────────────────────────────────
local function openWheel()
    resultFrame.Visible    = false
    centerBtn.Text         = "SPIN!"
    centerBtn.TextColor3   = Color3.fromRGB(30, 160, 30)
    screenGui.Enabled      = true
end

local function closeWheel()
    if not isSpinning then
        screenGui.Enabled = false
    end
end

closeBtn.MouseButton1Click:Connect(closeWheel)
clickDetector.MouseClick:Connect(openWheel)

centerBtn.MouseButton1Click:Connect(function()
    if isSpinning then return end
    isSpinning         = true
    resultFrame.Visible = false
    centerBtn.Text     = "..."
    centerBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
    SpinRequest:FireServer(1)
end)

SpinResult.OnClientEvent:Connect(function(result)
    -- Calcul précis de l'angle : le disque s'arrête sur le bon segment
    local targetRot   = getTargetAngle(wheelDisk.Rotation, result.SegmentId)
    local totalDegrees = targetRot - wheelDisk.Rotation   -- degrés totaux parcourus

    print(string.format(
        "🎯 Segment tiré : %d | %s | %s",
        result.SegmentId, result.Name, result.Rarity
    ))

    local tweenInfo = TweenInfo.new(5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

    -- Animation du disque UI (atterrit sur le segment gagnant)
    local uiTween = TweenService:Create(wheelDisk, tweenInfo, { Rotation = targetRot })
    uiTween:Play()

    -- Animation de la roue physique dans le monde (même nombre de degrés)
    local startCF  = physicalWheel.CFrame
    local targetCF = startCF * CFrame.Angles(math.rad(totalDegrees), 0, 0)
    TweenService:Create(physicalWheel, tweenInfo, { CFrame = targetCF }):Play()

    uiTween.Completed:Wait()

    -- Affichage du résultat
    local rarityInfo        = Constants.RARITIES[result.Rarity]
    resultLabel.Text        = string.format("🎉  Gagné : Segment %d — %s !", result.SegmentId, string.upper(result.Name))
    rarityLabel.Text        = "✦  " .. string.upper(result.Rarity) .. "  ✦"
    rarityLabel.TextColor3  = rarityInfo.Color
    resultFrame.Visible     = true

    -- Réinitialisation
    centerBtn.Text       = "SPIN!"
    centerBtn.TextColor3 = Color3.fromRGB(30, 160, 30)

    task.wait(4)
    resultFrame.Visible = false
    isSpinning          = false
end)

print("🎡 [WheelController] Prêt !")

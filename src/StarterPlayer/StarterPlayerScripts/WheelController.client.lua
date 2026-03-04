-- WheelController.client.lua
-- Roue colorée style émission TV + ScreenGui overlay

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local Debris            = game:GetService("Debris")

local player     = Players.LocalPlayer
local playerGui  = player:WaitForChild("PlayerGui")
local Events     = ReplicatedStorage:WaitForChild("Events")

print("🔵 [WheelController] MISE À JOUR : Roue bleue unie chargée !")

-- Nettoyage complet pour éviter les superpositions (crucial pour Rojo)
for _, ui in ipairs(playerGui:GetChildren()) do
    if ui.Name == "SpinWheelUI" then
        ui:Destroy()
    end
end

local Constants  = require(ReplicatedStorage:WaitForChild("Constants"))
local LootTables = require(ReplicatedStorage:WaitForChild("LootTables"))

local SpinRequest = Events:WaitForChild("SpinRequest")
local SpinResult  = Events:WaitForChild("SpinResult")
local GetPlayerData = Events:WaitForChild("GetPlayerData")

local wheelAssets = workspace:WaitForChild("WheelAssets")

local currentPhysicalWheel = nil
local currentWheelId       = 1

-- ── Couleurs fixes ─────────────────────────────────────────────────────────────
local GREEN_OUTER  = Color3.fromRGB( 50, 175,  60)
local GREEN_DARK   = Color3.fromRGB( 30, 130,  40)
local PINK_RING    = Color3.fromRGB(220,  50, 120)
local WHITE        = Color3.new(1, 1, 1)
local DARK_RED     = Color3.fromRGB(140,  20,  20)
local WHEEL_BLUE   = Color3.fromRGB(30, 100, 220)

-- Palette de 12 nuances de bleu pour les segments
local SEGMENT_COLORS = {
    Color3.fromRGB(0, 40, 120),    -- 1
    Color3.fromRGB(20, 110, 210),  -- 2
    Color3.fromRGB(10, 70, 160),   -- 3
    Color3.fromRGB(40, 150, 255),  -- 4
    Color3.fromRGB(0, 50, 140),    -- 5
    Color3.fromRGB(70, 180, 255),  -- 6
    Color3.fromRGB(15, 60, 130),   -- 7
    Color3.fromRGB(30, 130, 240),  -- 8
    Color3.fromRGB(5, 45, 115),    -- 9
    Color3.fromRGB(55, 165, 255),  -- 10
    Color3.fromRGB(0, 35, 105),    -- 11
    Color3.fromRGB(45, 145, 230),  -- 12
}

-- ── Config roue ────────────────────────────────────────────────────────────────
local WHEEL_ITEMS = LootTables.Wheels[1].Items
local N       = 12
local SEG_ANG = 360 / N
local DIAM    = 450 -- Réduit de 10% (500 -> 450)
local RAD     = DIAM / 2

local isSpinning = false

local function getTargetAngle(currentRotation, segmentId)
    local segCenter  = (segmentId - 1) * SEG_ANG + (SEG_ANG / 2)
    local currentMod = currentRotation % 360
    local offset     = segCenter - currentMod
    if offset < 0 then offset += 360 end
    return currentRotation + offset + (5 * 360) -- 5 tours minimum
end

-- ── Construction UI ────────────────────────────────────────────────────────────
local TITLE_H    = 48
local GAP        = 8
local RESULT_H   = 70
local OUTER_SIZE = DIAM + 60
local PANEL_W    = OUTER_SIZE + 40
local PANEL_H    = TITLE_H + GAP + OUTER_SIZE + GAP + RESULT_H

local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "SpinWheelUI"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn   = false
screenGui.Enabled        = false
screenGui.DisplayOrder   = 10 -- S'assurer qu'il est au-dessus du HUD
screenGui.Parent         = playerGui

-- BOUTON FERMER (Directement dans le ScreenGui pour être TOUJOURS visible en haut à droite)
local closeBtn = Instance.new("TextButton")
closeBtn.Name             = "CloseBtn"
closeBtn.Size             = UDim2.new(0, 60, 0, 60)
closeBtn.AnchorPoint      = Vector2.new(1, 0)
closeBtn.Position         = UDim2.new(1, -15, 0, 15)
closeBtn.BackgroundTransparency = 1 -- Suppression du rectangle (rendu transparent)
closeBtn.Text             = "X"
closeBtn.TextColor3       = Color3.fromRGB(220, 50, 50) -- La croix elle-même est rouge
closeBtn.Font             = Enum.Font.FredokaOne
closeBtn.TextSize         = 52 -- Plus grand pour compenser l'absence de fond
closeBtn.ZIndex           = 100
local closeStroke = Instance.new("UIStroke")
closeStroke.Thickness = 2
closeStroke.Color = Color3.new(0, 0, 0)
closeStroke.Parent = closeBtn
closeBtn.Parent = screenGui

local dimBG = Instance.new("Frame")
dimBG.Size                   = UDim2.new(1, 0, 1, 0)
dimBG.BackgroundColor3       = Color3.new(0, 0, 0)
dimBG.BackgroundTransparency = 0.5
dimBG.BorderSizePixel        = 0
dimBG.ZIndex                 = 1
dimBG.Parent                 = screenGui

local panel = Instance.new("Frame")
panel.Size             = UDim2.new(0, PANEL_W, 0, PANEL_H)
panel.AnchorPoint      = Vector2.new(0.5, 0.5)
panel.Position         = UDim2.new(0.5, 0, 0.5, 0)
panel.BackgroundTransparency = 1
panel.ZIndex           = 2
panel.Parent           = screenGui

local title = Instance.new("TextLabel")
title.Size                   = UDim2.new(1, 0, 0, TITLE_H)
title.BackgroundTransparency = 1
title.Text                   = "✦  BRAINROT WHEEL  ✦"
title.TextColor3             = WHITE
title.Font                   = Enum.Font.GothamBlack
title.TextSize               = 28
title.ZIndex                 = 3
title.Parent                 = panel

local outerRing = Instance.new("Frame")
outerRing.Size             = UDim2.new(0, OUTER_SIZE, 0, OUTER_SIZE)
outerRing.AnchorPoint      = Vector2.new(0.5, 0)
outerRing.Position         = UDim2.new(0.5, 0, 0, TITLE_H + GAP)
outerRing.BackgroundColor3 = GREEN_OUTER
Instance.new("UICorner", outerRing).CornerRadius = UDim.new(0.5, 0)
outerRing.Parent = panel

-- Anneau ROSE
local innerRingBorder = Instance.new("Frame")
innerRingBorder.Size             = UDim2.new(0, OUTER_SIZE + 24, 0, OUTER_SIZE + 24)
innerRingBorder.AnchorPoint      = Vector2.new(0.5, 0.5)
innerRingBorder.Position         = UDim2.new(0.5, 0, 0.5, 0)
innerRingBorder.BackgroundColor3 = PINK_RING
Instance.new("UICorner", innerRingBorder).CornerRadius = UDim.new(0.5, 0)
innerRingBorder.Parent = outerRing

-- LE DISQUE ROTATIF
local wheelDisk = Instance.new("Frame")
wheelDisk.Name             = "WheelDisk"
wheelDisk.Size             = UDim2.new(0, OUTER_SIZE, 0, OUTER_SIZE)
wheelDisk.AnchorPoint      = Vector2.new(0.5, 0.5)
wheelDisk.Position         = UDim2.new(0.5, 0, 0.5, 0)
wheelDisk.BackgroundColor3 = WHEEL_BLUE
wheelDisk.BorderSizePixel  = 0
wheelDisk.ClipsDescendants = true
Instance.new("UICorner", wheelDisk).CornerRadius = UDim.new(0.5, 0)
wheelDisk.ZIndex           = 2
wheelDisk.Parent           = innerRingBorder

-- RENDU DES SEGMENTS COLORES (360 RAYONS POUR UN REMPLISSAGE PARFAIT)
for deg = 0, 359 do
    local segmentIndex = math.floor(deg / SEG_ANG) + 1
    local ray = Instance.new("Frame")
    ray.Name             = "Ray_" .. deg
    ray.Size             = UDim2.new(0, 2, 0, OUTER_SIZE)
    ray.AnchorPoint      = Vector2.new(0.5, 0.5)
    ray.Position         = UDim2.new(0.5, 0, 0.5, 0)
    ray.Rotation         = deg
    ray.BackgroundColor3 = SEGMENT_COLORS[segmentIndex] or WHEEL_BLUE
    ray.BorderSizePixel  = 0
    ray.ZIndex           = 2
    ray.Parent           = wheelDisk
end

-- SEPARATEURS BLANCS (lignes de démarcation)
for i = 0, N - 1 do
    local div = Instance.new("Frame")
    div.Size             = UDim2.new(0, 4, 0, OUTER_SIZE)
    div.AnchorPoint      = Vector2.new(0.5, 0.5)
    div.Position         = UDim2.new(0.5, 0, 0.5, 0)
    div.Rotation         = i * SEG_ANG
    div.BackgroundColor3 = WHITE
    div.BorderSizePixel  = 0
    div.ZIndex           = 3
    div.Parent           = wheelDisk
end

-- LABELS À L'ENDROIT (PRÉCISÉMENT CENTRÉS)
for i = 1, N do
    local item = WHEEL_ITEMS[i]
    if not item then continue end

    local midAngle = (i - 1) * SEG_ANG + SEG_ANG / 2
    local rad      = math.rad(midAngle)
    -- On réduit un peu le rayon des labels pour qu'ils ne touchent pas le bord
    local labelRadius = (OUTER_SIZE / 2) * 0.65
    local lx       = OUTER_SIZE / 2 + labelRadius * math.sin(rad)
    local ly       = OUTER_SIZE / 2 - labelRadius * math.cos(rad)

    local nameL = Instance.new("TextLabel")
    nameL.Size                   = UDim2.new(0, 120, 0, 24)
    nameL.AnchorPoint            = Vector2.new(0.5, 0.5)
    nameL.Position               = UDim2.new(0, lx, 0, ly)
    nameL.Rotation               = 0 -- TOUJOURS À L'ENDROIT
    nameL.BackgroundTransparency = 1
    nameL.Text                   = item.Name
    nameL.TextColor3             = WHITE
    nameL.Font                   = Enum.Font.FredokaOne
    nameL.TextSize               = 12
    nameL.TextStrokeTransparency = 0.4 -- Ombre douce
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
    
    local cost = wheelData and wheelData.Cost or 0
    local currency = wheelData and wheelData.Currency or "Tickets"
    local icon = currency == "Gold" and "💰" or "🎟️"
    
    centerBtn.Text       = "SPIN!\n(" .. cost .. " " .. icon .. ")"
    centerBtn.TextColor3 = Color3.fromRGB(30, 140, 30)
    screenGui.Enabled    = true
end

local function closeWheel()
    if not isSpinning then
        screenGui.Enabled = false
    end
end

closeBtn.MouseEnter:Connect(function()
    TweenService:Create(closeBtn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(255, 100, 100), Size = UDim2.new(0, 70, 0, 70)}):Play()
end)

closeBtn.MouseLeave:Connect(function()
    TweenService:Create(closeBtn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(220, 50, 50), Size = UDim2.new(0, 60, 0, 60)}):Play()
end)

closeBtn.MouseButton1Click:Connect(function()
    closeWheel()
end)

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

    local wheelData = LootTables.Wheels[currentWheelId]
    local cost = wheelData and wheelData.Cost or 0
    local currency = wheelData and wheelData.Currency or "Tickets"
    
    -- Vérification locale des fonds
    local data = GetPlayerData:InvokeServer()
    if data and data.Stats then
        local hasEnough = false
        if currency == "Gold" then
            hasEnough = data.Stats.Gold >= cost
        elseif currency == "Tickets" then
            hasEnough = data.Stats.Tickets >= cost
        end
        
        if not hasEnough then
            centerBtn.Text = "FUNDS!"
            centerBtn.TextColor3 = Color3.fromRGB(190, 40, 40)
            task.delay(1, function()
                if not isSpinning then
                    local icon = currency == "Gold" and "💰" or "🎟️"
                    centerBtn.Text = "SPIN!\n(" .. cost .. " " .. icon .. ")"
                    centerBtn.TextColor3 = Color3.fromRGB(30, 140, 30)
                end
            end)
            return
        end
    end

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

    -- Setup du son de Tick pendant la rotation (UI)
    local tickSound = Instance.new("Sound")
    tickSound.SoundId = "rbxassetid://6895079661"
    tickSound.Volume = 0.5
    tickSound.Parent = wheelDisk

    local lastSeg = math.floor(wheelDisk.Rotation / SEG_ANG)
    local conn = RunService.RenderStepped:Connect(function()
        local curSeg = math.floor(wheelDisk.Rotation / SEG_ANG)
        if curSeg ~= lastSeg then
            lastSeg = curSeg
            tickSound:Play()
        end
    end)

    uiTween.Completed:Wait()
    conn:Disconnect()
    tickSound:Destroy()

    local rarityInfo       = Constants.RARITIES[result.Rarity]
    resultLabel.Text       = string.format("🎉  Gagné : %s !", string.upper(result.Name))
    rarityLabel.Text       = "✦  " .. string.upper(result.Rarity) .. "  ✦"
    rarityLabel.TextColor3 = rarityInfo.Color
    resultFrame.Visible    = true

    -- Son de victoire
    local victorySound = Instance.new("Sound")
    victorySound.SoundId = (result.Rarity == "LEGENDARY" or result.Rarity == "ULTRA") and "rbxassetid://2865227271" or "rbxassetid://3062331575"
    victorySound.Volume = 0.8
    victorySound.Parent = screenGui
    victorySound:Play()
    Debris:AddItem(victorySound, 4)

    -- Déclenchement des confettis sur la roue physique si légendaire ou ultra
    if result.Rarity == "LEGENDARY" or result.Rarity == "ULTRA" then
        if currentPhysicalWheel and currentPhysicalWheel.Parent then
            local pointerPart = currentPhysicalWheel.Parent:FindFirstChild("Pointer")
            if pointerPart then
                local conf = pointerPart:FindFirstChild("Confetti")
                if conf then
                    conf:Emit(150)
                end
            end
        end
    end

    local wheelData = LootTables.Wheels[currentWheelId]
    local cost = wheelData and wheelData.Cost or 0
    local currency = wheelData and wheelData.Currency or "Tickets"
    local icon = currency == "Gold" and "💰" or "🎟️"

    centerBtn.Text       = "SPIN!\n(" .. cost .. " " .. icon .. ")"
    centerBtn.TextColor3 = Color3.fromRGB(30, 140, 30)

    task.wait(4)
    resultFrame.Visible = false
    isSpinning          = false
end)

print("🎡 [WheelController] Prêt !")

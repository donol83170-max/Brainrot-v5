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

-- ── IDs des Decals uploadés ────────────────────────────────────────────────────
local DECAL_IDS = {
    [1] = 110862613756982, -- Roue Noob
    [2] = 82741196283644,  -- Roue Sigma
    [3] = 107234711297922, -- Roue Ultra
}

local function resolveAndApply(wheelId, imageLabel)
    if not currentPhysicalWheel or not currentPhysicalWheel.Parent then return end
    local folder = currentPhysicalWheel.Parent

    -- Fonction interne pour appliquer l'ID s'il existe
    local function applyIfReady()
        local resolvedId = folder:GetAttribute("ResolvedImageId")
        if resolvedId and resolvedId ~= "" then
            imageLabel.Image = resolvedId
            imageLabel.BackgroundTransparency = 1
            return true
        end
        return false
    end

    -- État initial (chargement)
    if not applyIfReady() then
        imageLabel.Image = ""
        imageLabel.BackgroundTransparency = 0
        imageLabel.BackgroundColor3 = WHEEL_BLUE
        
        -- Attendre que le serveur finisse de résoudre (si besoin)
        local conn
        conn = folder:GetAttributeChangedSignal("ResolvedImageId"):Connect(function()
            if applyIfReady() then
                conn:Disconnect()
            end
        end)
        
        -- Nettoyage automatique si on ferme
        task.delay(10, function() if conn and conn.Connected then conn:Disconnect() end end)
    end
end


-- ── Config roue ────────────────────────────────────────────────────────────────
local WHEEL_ITEMS = LootTables.Wheels[1].Items
local N       = 16
local SEG_ANG = 360 / N
local DIAM    = 425 -- Réduit de 5% supplémentaires (450 -> 425)
local RAD     = DIAM / 2

local isSpinning = false

local function getTargetAngle(currentRotation, segmentId)
    local midAngle = (segmentId - 1) * SEG_ANG + (SEG_ANG / 2)
    local target   = -midAngle -- Alignment direct au sommet (0°)
    
    local finalTarget = target
    while finalTarget <= currentRotation + (360 * 3) do -- Au moins 3 tours
        finalTarget += 360
    end
    
    return finalTarget
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

-- Anneau ROSE (clip circulaire)
local innerRingBorder = Instance.new("Frame")
innerRingBorder.Size             = UDim2.new(0, OUTER_SIZE + 24, 0, OUTER_SIZE + 24)
innerRingBorder.AnchorPoint      = Vector2.new(0.5, 0.5)
innerRingBorder.Position         = UDim2.new(0.5, 0, 0.5, 0)
innerRingBorder.BackgroundColor3 = WHITE
innerRingBorder.ClipsDescendants = true
Instance.new("UICorner", innerRingBorder).CornerRadius = UDim.new(0.5, 0)
innerRingBorder.Parent = outerRing

-- L'IMAGE DE LA ROUE (Texture uploadée - circulaire)
local wheelImage = Instance.new("ImageLabel")
wheelImage.Name             = "WheelImage"
wheelImage.Size             = UDim2.new(1, 0, 1, 0) -- Taille exacte pour voir toute la roue
wheelImage.AnchorPoint      = Vector2.new(0.5, 0.5)
wheelImage.Position         = UDim2.new(0.5, 0, 0.5, 0)
wheelImage.BackgroundTransparency = 1
wheelImage.ZIndex           = 3
wheelImage.ScaleType        = Enum.ScaleType.Stretch
Instance.new("UICorner", wheelImage).CornerRadius = UDim.new(0.5, 0) -- Circulaire
wheelImage.Parent           = innerRingBorder

local wheelDisk = wheelImage -- Référence pour la rotation

-- COUCHE DE LABELS (au-dessus de l'image, tourne avec la roue)
local labelLayer = Instance.new("Frame")
labelLayer.Name             = "LabelLayer"
labelLayer.Size             = UDim2.new(1, 0, 1, 0)
labelLayer.AnchorPoint      = Vector2.new(0.5, 0.5)
labelLayer.Position         = UDim2.new(0.5, 0, 0.5, 0)
labelLayer.BackgroundTransparency = 1
labelLayer.ZIndex           = 4
labelLayer.Parent           = innerRingBorder

local function rebuildLabels(wheelId)
    labelLayer.Rotation = 0
    labelLayer:ClearAllChildren()

    local items = LootTables.Wheels[wheelId] and LootTables.Wheels[wheelId].Items or {}
    local halfSize = OUTER_SIZE / 2

    for i = 1, N do
        local item = items[i]
        if not item then continue end

        local rarityInfo = Constants.RARITIES[item.Rarity]
        local weight = rarityInfo and rarityInfo.Weight or 0

        local segId    = item.SegmentId or i
        local midAngle = (segId - 1) * SEG_ANG + SEG_ANG / 2
        local rad      = math.rad(midAngle)

        -- ── NOM : long du rayon (le long de la ligne du segment) ──────────────
        -- Positionné à 58% du rayon, orienté radialement
        local nameR = halfSize * 0.58
        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size                   = UDim2.new(0, 72, 0, 14) -- Long (radial) × étroit (travers)
        nameLbl.AnchorPoint            = Vector2.new(0.5, 0.5)
        nameLbl.Position               = UDim2.new(0, halfSize + nameR * math.sin(rad),
                                                      0, halfSize - nameR * math.cos(rad))
        nameLbl.Rotation               = midAngle  -- Orienté le long du rayon
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text                   = item.Name
        nameLbl.TextColor3             = WHITE
        nameLbl.Font                   = Enum.Font.FredokaOne
        nameLbl.TextScaled             = true
        nameLbl.TextWrapped            = false
        nameLbl.TextStrokeTransparency = 0
        nameLbl.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
        nameLbl.ZIndex                 = 7
        nameLbl.Parent                 = labelLayer

        -- ── POURCENTAGE : au milieu du segment ────────────────────────────────
        local pctR = halfSize * 0.28
        local pctLbl = Instance.new("TextLabel")
        pctLbl.Size                   = UDim2.new(0, 34, 0, 16)
        pctLbl.AnchorPoint            = Vector2.new(0.5, 0.5)
        pctLbl.Position               = UDim2.new(0, halfSize + pctR * math.sin(rad),
                                                     0, halfSize - pctR * math.cos(rad))
        pctLbl.Rotation               = midAngle  -- Aussi orienté pour cohérence visuelle
        pctLbl.BackgroundTransparency = 1
        pctLbl.Text                   = weight .. "%"
        pctLbl.TextColor3             = WHITE
        pctLbl.Font                   = Enum.Font.FredokaOne
        pctLbl.TextScaled             = true
        pctLbl.TextWrapped            = false
        pctLbl.TextStrokeTransparency = 0
        pctLbl.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
        pctLbl.ZIndex                 = 7
        pctLbl.Parent                 = labelLayer
    end

    -- Synchronise la rotation du calque avec la roue
    labelLayer.Rotation = wheelImage.Rotation
end



-- Maintient les labels horizontaux (sens de lecture) pendant que la roue tourne
local function updateLabelsOrientation()
    for _, lbl in ipairs(labelLayer:GetChildren()) do
        if lbl:IsA("TextLabel") then
            lbl.Rotation = -labelLayer.Rotation
        end
    end
end

-- Labels tournent avec labelLayer naturellement (orientés dans les segments)

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
    
    -- Charger la texture (résolution depuis le Decal ID)
    resolveAndApply(currentWheelId, wheelImage)
    
    -- Dessiner les labels item + %
    rebuildLabels(currentWheelId)
    
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
    -- Synchronise les labels avec la rotation
    TweenService:Create(labelLayer, tweenInfo, { Rotation = targetRot }):Play()

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
        updateLabelsOrientation() -- Garde les textes horizontaux pendant le spin
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

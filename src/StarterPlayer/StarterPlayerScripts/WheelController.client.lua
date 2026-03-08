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
local mainFrame
local scrollList
local winLabel
local closeBtn
local flashFrame

local SPIN_COOLDOWN = 6
local lastSpinTime = 0

local ROW_HEIGHT = 80
local VISIBLE_ROWS = 5
local TOTAL_LOOPS = 5  -- Nombre de fois qu'on répète les 12 segments pour faire "tourner" la liste

local function createSlotUI(segments)
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

    -- ── Le Cadre Principal (Machine à sous) ──────────────────
    local uiHeight = ROW_HEIGHT * VISIBLE_ROWS

    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    -- Large de 400px, haut de (5 lignes de 80px = 400px)
    mainFrame.Size = UDim2.new(0, 400, 0, uiHeight)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35) -- Métal sombre 
    mainFrame.ClipsDescendants = true -- EFFET DE DÉFILEMENT ICI
    mainFrame.ZIndex = 2
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 12)
    mainFrame.Parent = overlay

    -- Bordure or (Stroke sur le mainFrame)
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 215, 0)
    stroke.Thickness = 4
    stroke.Parent = mainFrame

    -- Ombre interne optionnelle
    local shadow = Instance.new("UIGradient")
    shadow.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.new(0,0,0)),
        ColorSequenceKeypoint.new(0.2, Color3.new(1,1,1)),
        ColorSequenceKeypoint.new(0.8, Color3.new(1,1,1)),
        ColorSequenceKeypoint.new(1, Color3.new(0,0,0))
    })
    shadow.Rotation = 90
    shadow.Parent = mainFrame
    
    -- La liste défilante qui contient tous les items
    local nSeg = #segments
    local totalItems = nSeg * TOTAL_LOOPS + nSeg -- Plusieurs boucles + 1 boucle bonus pour l'arrêt
    local totalHeight = totalItems * ROW_HEIGHT

    scrollList = Instance.new("Frame")
    scrollList.Name = "ScrollList"
    scrollList.Size = UDim2.new(1, 0, 0, totalHeight)
    scrollList.Position = UDim2.new(0, 0, 0, 0)
    scrollList.BackgroundTransparency = 1
    scrollList.Parent = mainFrame

    -- Remplissage de la liste avec UIListLayout
    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 0)
    listLayout.Parent = scrollList

    local index = 1
    for loop = 0, TOTAL_LOOPS do
        for i = 1, nSeg do
            local segData = segments[i]
            local rCol = RARITY_COLORS[segData.rarity] or Color3.fromRGB(100, 100, 100)

            local row = Instance.new("Frame")
            row.Name = "Row_" .. index
            row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
            row.BackgroundColor3 = rCol
            row.BorderSizePixel = 0
            row.LayoutOrder = index
            row.ZIndex = 3
            row.Parent = scrollList

            -- Ombre/relief sur chaque ligne pour faire "bloc"
            local lineStroke = Instance.new("UIStroke")
            lineStroke.Color = Color3.new(0, 0, 0)
            lineStroke.Thickness = 2
            lineStroke.Parent = row

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(0.9, 0, 0.8, 0)
            lbl.AnchorPoint = Vector2.new(0.5, 0.5)
            lbl.Position = UDim2.new(0.5, 0, 0.5, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text = string.upper(segData.item.name)
            lbl.TextColor3 = Color3.new(1, 1, 1)
            lbl.Font = Enum.Font.LuckiestGuy
            lbl.TextScaled = true
            lbl.TextStrokeTransparency = 0
            lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
            lbl.ZIndex = 4
            lbl.Parent = row

            if segData.rarity == "LEGENDARY" then
                local sl = Instance.new("TextLabel")
                sl.Size = UDim2.new(0.2, 0, 1, 0)
                sl.Position = UDim2.new(0.8, 0, 0, 0)
                sl.BackgroundTransparency = 1
                sl.Text = "★"
                sl.TextColor3 = Color3.fromRGB(255, 240, 60)
                sl.Font = Enum.Font.GothamBlack
                sl.TextScaled = true
                sl.TextStrokeTransparency = 0
                sl.ZIndex = 5
                sl.Parent = row
                
                local sl2 = sl:Clone()
                sl2.Position = UDim2.new(0, 0, 0, 0)
                sl2.Parent = row
            end

            index = index + 1
        end
    end

    -- Les Pointeurs (Curseur au milieu) 
    -- Milieu de mainFrame = uiHeight / 2
    local pointerLeft = Instance.new("ImageLabel")
    pointerLeft.Name = "ArrowLeft"
    pointerLeft.Size = UDim2.new(0, 40, 0, 40)
    pointerLeft.AnchorPoint = Vector2.new(0.5, 0.5)
    pointerLeft.Position = UDim2.new(0, -10, 0.5, 0)
    pointerLeft.BackgroundTransparency = 1
    pointerLeft.Image = "rbxassetid://4483362458" -- Triangle générique
    pointerLeft.ImageColor3 = Color3.fromRGB(255, 215, 0)
    pointerLeft.Rotation = 90 -- Pointe vers la droite
    pointerLeft.ZIndex = 10
    pointerLeft.Parent = mainFrame

    local pointerRight = Instance.new("ImageLabel")
    pointerRight.Name = "ArrowRight"
    pointerRight.Size = UDim2.new(0, 40, 0, 40)
    pointerRight.AnchorPoint = Vector2.new(0.5, 0.5)
    pointerRight.Position = UDim2.new(1, 10, 0.5, 0)
    pointerRight.BackgroundTransparency = 1
    pointerRight.Image = "rbxassetid://4483362458"
    pointerRight.ImageColor3 = Color3.fromRGB(255, 215, 0)
    pointerRight.Rotation = -90 -- Pointe vers la gauche
    pointerRight.ZIndex = 10
    pointerRight.Parent = mainFrame

    -- Ligne de visée centrale (Overlay transparent rouge)
    local centerLine = Instance.new("Frame")
    centerLine.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
    centerLine.AnchorPoint = Vector2.new(0, 0.5)
    centerLine.Position = UDim2.new(0, 0, 0.5, 0)
    centerLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    centerLine.BackgroundTransparency = 0.85
    centerLine.BorderSizePixel = 0
    centerLine.ZIndex = 9
    centerLine.Parent = mainFrame
    local clStroke = Instance.new("UIStroke")
    clStroke.Color = Color3.fromRGB(255, 215, 0)
    clStroke.Thickness = 2
    clStroke.Parent = centerLine

    -- ── UI de Victoire ────────────────────────────────────────────────────────
    winLabel = Instance.new("TextLabel")
    winLabel.Size = UDim2.new(0.8, 0, 0, 100)
    winLabel.AnchorPoint = Vector2.new(0.5, 0)
    winLabel.Position = UDim2.new(0.5, 0, 0.1, 0) -- Au-dessus de la machine
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
    closeBtn.Position = UDim2.new(0.5, 0, 0.9, 0) -- En bas
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
    if not res.success then return end

    if res.segments then
        createSlotUI(res.segments)
    end
    if not spinGui then return end

    local now = tick()
    if now - lastSpinTime < SPIN_COOLDOWN then return end
    lastSpinTime = now

    winLabel.Visible = false
    closeBtn.Visible = false
    flashFrame.BackgroundTransparency = 1
    spinGui.Enabled = true

    local nSeg = #res.segments
    
    -- Le segment gagnant (1 à 12). On le choisit dans la dernière boucle.
    -- ex: Si 5 boucles, la 5eme boucle commence à index = 4 * 12 + 1 = 49.
    local targetGlobalIndex = (TOTAL_LOOPS - 1) * nSeg + res.winSegment
    
    -- Position Y voulue : On veut que le centre de la ligne = centre du container.
    -- Ligne "targetGlobalIndex" commence à Y = (targetGlobalIndex - 1) * ROW_HEIGHT.
    -- Son centre est Y_start + ROW_HEIGHT/2.
    -- Centre de la MainFrame = (ROW_HEIGHT * VISIBLE_ROWS)/2.
    -- Donc ScrollList.Position.Y.Offset sera = Centre_MainFrame - Centre_Ligne
    
    local centerY_MainFrame = (ROW_HEIGHT * VISIBLE_ROWS) / 2
    local centerY_TargetLine = (targetGlobalIndex - 1) * ROW_HEIGHT + (ROW_HEIGHT / 2)
    local finalYPos = centerY_MainFrame - centerY_TargetLine

    -- Reset pour effet de retour rapide ou de continuité 
    -- -> On démarre d'une boucle lointaine (la première)
    local startTargetIndex = 1 * nSeg + res.winSegment -- Optionnel: Si on veut démarrer aligné
    -- Ou mieux : On démarre à Y=0 ou aléatoire en haut
    local startYPos = centerY_MainFrame - (ROW_HEIGHT / 2) -- On cache le 1er au milieu
    
    scrollList.Position = UDim2.new(0, 0, 0, 0)

    local duration = res.duration or 5.5
    
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    local tween = TweenService:Create(scrollList, tweenInfo, { Position = UDim2.new(0, 0, 0, finalYPos) })

    local lastTickRow = 0
    local conn = RunService.RenderStepped:Connect(function()
        -- scrollList.Position.Y.Offset descend vers le négatif.
        -- Clic quand on passe une case au centre :
        local currentY = scrollList.Position.Y.Offset
        -- Index au centre = (centerY_MainFrame - currentY) / ROW_HEIGHT (approximatif)
        local passedIndex = math.floor((centerY_MainFrame - currentY) / ROW_HEIGHT)
        if passedIndex ~= lastTickRow then
            lastTickRow = passedIndex
            guiTickSound:Play()
        end
    end)

    tween.Completed:Connect(function()
        conn:Disconnect()
        
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

-- WheelController.client.lua
-- Slot Machine UI — liste défilante verticale, zéro chevauchement
--
-- ARCHITECTURE :
--   overlay (plein écran, fond sombre)
--   └─ container (colonne centrée, BG transparent)
--        ├─ title         — "BRAINROT SPIN"  (hors mainFrame)
--        ├─ arrows        — flèches gauche/droite (hors mainFrame, jamais clippées)
--        ├─ centerLine    — surbrillance dorée   (hors mainFrame, superposée)
--        ├─ mainFrame     — SEULE zone clippée, contient scrollList
--        │    └─ scrollList + UIListLayout
--        ├─ winLabel      — texte victoire
--        ├─ closeBtn
--        └─ reSpinBtn

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local Events     = ReplicatedStorage:WaitForChild("Events")
local SpinResult = Events:WaitForChild("SpinResult")

local RARITY_COLORS = {
    COMMON    = Color3.fromRGB(120, 122, 128),
    RARE      = Color3.fromRGB(  0, 120, 255),
    EPIC      = Color3.fromRGB(180,   0, 255),
    LEGENDARY = Color3.fromRGB(255, 180,   0),
}

-- Sons
local guiTickSound  = Instance.new("Sound")
guiTickSound.SoundId  = "rbxassetid://6026984224"
guiTickSound.Volume   = 0.5
guiTickSound.Parent   = script

local guiWinSound   = Instance.new("Sound")
guiWinSound.SoundId   = "rbxassetid://5153734135"
guiWinSound.Volume    = 1.0
guiWinSound.Parent    = script

local fanfareSound  = Instance.new("Sound")
fanfareSound.SoundId  = "rbxassetid://3205426741"
fanfareSound.Volume   = 1.0
fanfareSound.Parent   = script

-- ── Constantes layout ────────────────────────────────────────────────────────
local ROW_H        = 52        -- hauteur d'une ligne (px)
local ROW_PAD      = 6         -- espacement entre lignes (UIListLayout Padding)
local EFF_ROW_H    = ROW_H + ROW_PAD   -- hauteur effective par slot
local VISIBLE_ROWS = 5
local LIST_H       = ROW_H * VISIBLE_ROWS + ROW_PAD * (VISIBLE_ROWS - 1)  -- 284 px
local TOTAL_LOOPS  = 5         -- boucles complètes avant l'arrêt
local SPIN_COOLDOWN = 6
local lastSpinTime  = 0

-- ── Références UI (remplacées à chaque spin) ─────────────────────────────────
local spinGui, overlay, mainFrame, scrollList
local winLabel, closeBtn, reSpinBtn, flashFrame

-- ────────────────────────────────────────────────────────────────────────────
local function createSlotUI(segments)
    if spinGui then spinGui:Destroy() end

    spinGui = Instance.new("ScreenGui")
    spinGui.Name          = "SpinGui"
    spinGui.IgnoreGuiInset = true
    spinGui.ResetOnSpawn  = false
    spinGui.Enabled       = false
    spinGui.Parent        = PlayerGui

    -- Fond sombre plein écran
    overlay = Instance.new("Frame")
    overlay.Size                  = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3      = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.52
    overlay.BorderSizePixel       = 0
    overlay.Parent                = spinGui

    -- Flash blanc (victoire)
    flashFrame = Instance.new("Frame")
    flashFrame.Size                  = UDim2.new(1, 0, 1, 0)
    flashFrame.BackgroundColor3      = Color3.new(1, 1, 1)
    flashFrame.BackgroundTransparency = 1
    flashFrame.BorderSizePixel       = 0
    flashFrame.ZIndex                = 100
    flashFrame.Parent                = spinGui

    -- ── Colonne principale (BG transparent — guide tout) ──────────────────────
    local CONT_W = 420
    local container = Instance.new("Frame")
    container.Name             = "Container"
    container.Size             = UDim2.new(0, CONT_W, 0, LIST_H + 180)
    container.AnchorPoint      = Vector2.new(0.5, 0.5)
    container.Position         = UDim2.new(0.5, 0, 0.5, 0)
    container.BackgroundTransparency = 1
    container.Parent           = overlay

    -- Titre
    local title = Instance.new("TextLabel")
    title.Size                   = UDim2.new(1, 0, 0, 52)
    title.AnchorPoint            = Vector2.new(0.5, 0)
    title.Position               = UDim2.new(0.5, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Text                   = "BRAINROT SPIN"
    title.TextColor3             = Color3.fromRGB(255, 225, 0)
    title.Font                   = Enum.Font.LuckiestGuy
    title.TextScaled             = true
    title.TextStrokeTransparency = 0
    title.TextStrokeColor3       = Color3.new(0, 0, 0)
    title.ZIndex                 = 5
    title.Parent                 = container

    -- ── Fenêtre clippée (SEUL endroit avec ClipsDescendants) ──────────────────
    local FRAME_TOP = 58   -- offset depuis le haut du container

    mainFrame = Instance.new("Frame")
    mainFrame.Name               = "MainFrame"
    mainFrame.Size               = UDim2.new(1, 0, 0, LIST_H)
    mainFrame.Position           = UDim2.new(0, 0, 0, FRAME_TOP)
    mainFrame.BackgroundColor3   = Color3.fromRGB(18, 18, 24)
    mainFrame.BorderSizePixel    = 0
    mainFrame.ClipsDescendants   = true   -- ← clip UNIQUEMENT ici
    mainFrame.ZIndex             = 2
    mainFrame.Parent             = container

    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

    local rimStroke = Instance.new("UIStroke")
    rimStroke.Color     = Color3.fromRGB(255, 215, 0)
    rimStroke.Thickness = 4
    rimStroke.Parent    = mainFrame

    -- ── Flèches (enfants du CONTAINER, jamais clippées) ──────────────────────
    local ARROW_Y  = FRAME_TOP + LIST_H / 2   -- milieu vertical de mainFrame

    local arrowL = Instance.new("TextLabel")
    arrowL.Size              = UDim2.new(0, 32, 0, 32)
    arrowL.AnchorPoint       = Vector2.new(1, 0.5)
    arrowL.Position          = UDim2.new(0, -12, 0, ARROW_Y)
    arrowL.BackgroundTransparency = 1
    arrowL.Text              = "▶"
    arrowL.TextColor3        = Color3.fromRGB(255, 215, 0)
    arrowL.Font              = Enum.Font.GothamBlack
    arrowL.TextScaled        = true
    arrowL.TextStrokeTransparency = 0
    arrowL.ZIndex            = 10
    arrowL.Parent            = container

    local arrowR = Instance.new("TextLabel")
    arrowR.Size              = UDim2.new(0, 32, 0, 32)
    arrowR.AnchorPoint       = Vector2.new(0, 0.5)
    arrowR.Position          = UDim2.new(1, 12, 0, ARROW_Y)
    arrowR.BackgroundTransparency = 1
    arrowR.Text              = "◀"
    arrowR.TextColor3        = Color3.fromRGB(255, 215, 0)
    arrowR.Font              = Enum.Font.GothamBlack
    arrowR.TextScaled        = true
    arrowR.TextStrokeTransparency = 0
    arrowR.ZIndex            = 10
    arrowR.Parent            = container

    -- ── Surbrillance centrale (enfant du CONTAINER, au-dessus de mainFrame) ───
    local centerLine = Instance.new("Frame")
    centerLine.Size              = UDim2.new(1, 8, 0, ROW_H + 8)
    centerLine.AnchorPoint       = Vector2.new(0.5, 0.5)
    centerLine.Position          = UDim2.new(0.5, 0, 0, ARROW_Y)
    centerLine.BackgroundTransparency = 1
    centerLine.BorderSizePixel   = 0
    centerLine.ZIndex            = 9
    centerLine.Parent            = container

    local clStroke = Instance.new("UIStroke")
    clStroke.Color     = Color3.fromRGB(255, 215, 0)
    clStroke.Thickness = 3
    clStroke.Parent    = centerLine

    -- ── Liste défilante ───────────────────────────────────────────────────────
    local nSeg       = #segments
    local totalItems = nSeg * (TOTAL_LOOPS + 1)
    local totalH     = totalItems * EFF_ROW_H + ROW_PAD   -- hauteur totale

    scrollList = Instance.new("Frame")
    scrollList.Name                  = "ScrollList"
    scrollList.Size                  = UDim2.new(1, 0, 0, totalH)
    scrollList.Position              = UDim2.new(0, 0, 0, 0)
    scrollList.BackgroundTransparency = 1
    scrollList.Parent                = mainFrame

    -- UIListLayout gère tout l'alignement — pas de Position manuelle sur les lignes
    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder          = Enum.SortOrder.LayoutOrder
    listLayout.FillDirection      = Enum.FillDirection.Vertical
    listLayout.VerticalAlignment  = Enum.VerticalAlignment.Top
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.Padding            = UDim.new(0, ROW_PAD)
    listLayout.Parent             = scrollList

    -- Remplissage des lignes
    local idx = 1
    for _ = 0, TOTAL_LOOPS do
        for i = 1, nSeg do
            local seg  = segments[i]
            local rCol = RARITY_COLORS[seg.rarity] or Color3.fromRGB(90, 90, 90)

            local row = Instance.new("Frame")
            row.Name             = "Row_" .. idx
            row.Size             = UDim2.new(0.94, 0, 0, ROW_H)
            row.BackgroundColor3 = rCol
            row.BorderSizePixel  = 0
            row.LayoutOrder      = idx
            row.ZIndex           = 3
            row.Parent           = scrollList
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 7)

            local lbl = Instance.new("TextLabel")
            lbl.Size                   = UDim2.new(1, -24, 1, 0)
            lbl.AnchorPoint            = Vector2.new(0.5, 0.5)
            lbl.Position               = UDim2.new(0.5, 0, 0.5, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text                   = string.upper(seg.item.name)
            lbl.TextColor3             = Color3.new(1, 1, 1)
            lbl.Font                   = Enum.Font.LuckiestGuy
            lbl.TextScaled             = true
            lbl.TextXAlignment         = Enum.TextXAlignment.Center
            lbl.TextYAlignment         = Enum.TextYAlignment.Center
            lbl.TextStrokeTransparency = 0
            lbl.TextStrokeColor3       = Color3.new(0, 0, 0)
            lbl.ZIndex                 = 4
            lbl.Parent                 = row

            if seg.rarity == "LEGENDARY" then
                for _, xPct in ipairs({0, 1}) do
                    local star = Instance.new("TextLabel")
                    star.Size              = UDim2.new(0, 26, 1, 0)
                    star.AnchorPoint       = Vector2.new(xPct, 0.5)
                    star.Position          = UDim2.new(xPct, xPct == 0 and 4 or -4, 0.5, 0)
                    star.BackgroundTransparency = 1
                    star.Text              = "★"
                    star.TextColor3        = Color3.fromRGB(255, 240, 60)
                    star.Font              = Enum.Font.GothamBlack
                    star.TextScaled        = true
                    star.TextStrokeTransparency = 0
                    star.ZIndex            = 5
                    star.Parent            = row
                end
            end

            idx = idx + 1
        end
    end

    -- ── Message de victoire (au-dessus du container, visible après spin) ──────
    winLabel = Instance.new("TextLabel")
    winLabel.Size                   = UDim2.new(1, 0, 0, 60)
    winLabel.AnchorPoint            = Vector2.new(0.5, 1)
    winLabel.Position               = UDim2.new(0.5, 0, 0, FRAME_TOP - 8)
    winLabel.BackgroundTransparency = 1
    winLabel.Text                   = ""
    winLabel.TextColor3             = Color3.new(1, 1, 1)
    winLabel.Font                   = Enum.Font.LuckiestGuy
    winLabel.TextScaled             = true
    winLabel.TextStrokeTransparency = 0
    winLabel.TextStrokeColor3       = Color3.new(0, 0, 0)
    winLabel.Visible                = false
    winLabel.ZIndex                 = 20
    winLabel.Parent                 = container

    -- ── Boutons (sous le container, côte à côte, bien séparés) ───────────────
    local BTN_TOP = FRAME_TOP + LIST_H + 14

    closeBtn = Instance.new("TextButton")
    closeBtn.Size             = UDim2.new(0, 190, 0, 54)
    closeBtn.AnchorPoint      = Vector2.new(1, 0)
    closeBtn.Position         = UDim2.new(0.5, -6, 0, BTN_TOP)
    closeBtn.BackgroundColor3 = Color3.fromRGB(210, 35, 35)
    closeBtn.Text             = "FERMER"
    closeBtn.TextColor3       = Color3.new(1, 1, 1)
    closeBtn.Font             = Enum.Font.GothamBlack
    closeBtn.TextSize         = 24
    closeBtn.Visible          = false
    closeBtn.ZIndex           = 20
    closeBtn.Parent           = container
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 10)
    local cs = Instance.new("UIStroke"); cs.Color = Color3.new(0,0,0); cs.Thickness = 2; cs.Parent = closeBtn

    reSpinBtn = Instance.new("TextButton")
    reSpinBtn.Size             = UDim2.new(0, 190, 0, 54)
    reSpinBtn.AnchorPoint      = Vector2.new(0, 0)
    reSpinBtn.Position         = UDim2.new(0.5, 6, 0, BTN_TOP)
    reSpinBtn.BackgroundColor3 = Color3.fromRGB(30, 185, 30)
    reSpinBtn.Text             = "RE-SPIN (20G)"
    reSpinBtn.TextColor3       = Color3.new(1, 1, 1)
    reSpinBtn.Font             = Enum.Font.LuckiestGuy
    reSpinBtn.TextSize         = 22
    reSpinBtn.Visible          = false
    reSpinBtn.ZIndex           = 20
    reSpinBtn.Parent           = container
    Instance.new("UICorner", reSpinBtn).CornerRadius = UDim.new(0, 10)
    local rs = Instance.new("UIStroke"); rs.Color = Color3.new(0,0,0); rs.Thickness = 2; rs.Parent = reSpinBtn

    closeBtn.MouseButton1Click:Connect(function()
        spinGui.Enabled = false
    end)

    reSpinBtn.MouseButton1Click:Connect(function()
        local req = Events:FindFirstChild("RequestSpin")
        if req then
            spinGui.Enabled = false
            req:FireServer()
        end
    end)
end

-- ── ANIMATION ────────────────────────────────────────────────────────────────
SpinResult.OnClientEvent:Connect(function(res)
    if not res.success then return end

    -- (Re)construction de l'UI si segments transmis
    if res.segments then
        createSlotUI(res.segments)
    end
    if not spinGui then return end

    local now = tick()
    if now - lastSpinTime < SPIN_COOLDOWN then return end
    lastSpinTime = now

    winLabel.Visible   = false
    closeBtn.Visible   = false
    reSpinBtn.Visible  = false
    flashFrame.BackgroundTransparency = 1
    spinGui.Enabled    = true

    local nSeg     = #res.segments
    local centerY  = LIST_H / 2   -- centre vertical de mainFrame

    -- Index du segment gagnant dans la dernière boucle
    -- (TOTAL_LOOPS - 1) boucles complètes + winSegment
    local targetIdx = (TOTAL_LOOPS - 1) * nSeg + res.winSegment

    -- Position Y du centre de la ligne targetIdx :
    --   top de la ligne = (targetIdx - 1) * EFF_ROW_H
    --   centre de la ligne = top + ROW_H / 2
    local lineCenterY = (targetIdx - 1) * EFF_ROW_H + ROW_H / 2

    -- On veut que lineCenterY soit au centre de mainFrame (= centerY) :
    --   scrollList.Position.Y.Offset = centerY - lineCenterY   (valeur négative)
    local finalYPos = centerY - lineCenterY

    -- Départ depuis le haut (Row 1 au centre)
    local startLineCenterY = (1 - 1) * EFF_ROW_H + ROW_H / 2
    local startYPos        = centerY - startLineCenterY
    scrollList.Position    = UDim2.new(0, 0, 0, startYPos)

    local duration  = res.duration or 5.5
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    local tween     = TweenService:Create(scrollList, tweenInfo, {
        Position = UDim2.new(0, 0, 0, finalYPos)
    })

    -- Son de tick à chaque nouveau segment au centre
    local lastTick = -1
    local conn = RunService.RenderStepped:Connect(function()
        local curY     = scrollList.Position.Y.Offset
        local topY     = centerY - curY            -- Y absolu du haut de la liste dans mainFrame
        local midSlot  = math.floor((topY) / EFF_ROW_H)
        if midSlot ~= lastTick then
            lastTick = midSlot
            guiTickSound:Play()
        end
    end)

    tween.Completed:Connect(function()
        conn:Disconnect()

        -- Flash victoire
        flashFrame.BackgroundTransparency = 0
        TweenService:Create(flashFrame,
            TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { BackgroundTransparency = 1 }
        ):Play()

        -- Texte résultat
        local rCol = RARITY_COLORS[res.memeRarity] or Color3.new(1, 1, 1)
        winLabel.Text       = "TU AS GAGNÉ : " .. string.upper(res.memeName) .. " !"
        winLabel.TextColor3 = rCol
        winLabel.Visible    = true

        if res.memeRarity == "LEGENDARY" or res.memeRarity == "EPIC" then
            fanfareSound:Play()
        else
            guiWinSound:Play()
        end

        closeBtn.Visible  = true
        reSpinBtn.Visible = true
    end)

    tween:Play()
end)

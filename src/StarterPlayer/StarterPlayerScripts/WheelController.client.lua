-- WheelController.client.lua — v3 Structure Propre
--
-- HIÉRARCHIE (zéro chevauchement, zéro magie noire) :
--   spinGui
--   ├─ overlay       — fond sombre plein écran
--   ├─ flashFrame    — flash blanc victoire
--   └─ container     — colonne 420px centrée (UIListLayout Vertical)
--        ├─ title        [52px]  — "BRAINROT SPIN", caché au moment du win
--        ├─ machineRow   [284px] — contient mainFrame + flèches latérales
--        │    ├─ arrowL          — ▶ HORS mainFrame
--        │    ├─ mainFrame       — ClipsDescendants=true (la fenêtre)
--        │    │    ├─ starDecoL  — ★ fixe gauche (hors scrollList)
--        │    │    ├─ starDecoR  — ★ fixe droite (hors scrollList)
--        │    │    ├─ centerHighlight — bande dorée centrale (hors scrollList)
--        │    │    └─ scrollList + UIListLayout
--        │    └─ arrowR
--        └─ btnRow       [54px]  — FERMER | RE-SPIN côte à côte
--
--   winPopup (enfant de spinGui, ZIndex 200, popup de victoire)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local Events     = ReplicatedStorage:WaitForChild("Events")
local SpinResult = Events:WaitForChild("SpinResult")

-- ── Couleurs de rareté (identiques serveur + client) ─────────────────────────
local RARITY_COLORS = {
    COMMON    = Color3.fromRGB(100, 102, 108),
    RARE      = Color3.fromRGB(  0, 110, 255),
    EPIC      = Color3.fromRGB(255,   0, 255),   -- MAGENTA ✓
    LEGENDARY = Color3.fromRGB(255, 175,   0),
}

-- ── Sons ──────────────────────────────────────────────────────────────────────
local function makeSound(id, vol)
    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://" .. id
    s.Volume  = vol
    s.Parent  = script
    return s
end
local sndTick    = makeSound("6026984224", 0.5)
local sndWin     = makeSound("5153734135", 1.0)
local sndFanfare = makeSound("3205426741", 1.0)

-- ── Constantes layout ─────────────────────────────────────────────────────────
local ROW_H      = 52       -- hauteur d'une ligne (px)
local ROW_PAD    = 6        -- espacement UIListLayout entre lignes
local EFF        = ROW_H + ROW_PAD   -- hauteur effective par slot dans la liste
local VIS        = 5        -- lignes visibles simultanément
local LIST_H     = ROW_H * VIS + ROW_PAD * (VIS - 1)   -- 284 px
local LOOPS      = 5        -- boucles avant l'arrêt
local COOLDOWN   = 6
local lastSpin   = 0

-- ── Références (recréées à chaque spin) ──────────────────────────────────────
local spinGui, overlay, flashFrame
local mainFrame, scrollList, title
local winPopup, winPopupLabel

-- ─────────────────────────────────────────────────────────────────────────────
-- CONSTRUCTION UI
-- ─────────────────────────────────────────────────────────────────────────────
local function buildUI(segments)
    if spinGui then spinGui:Destroy() end

    spinGui = Instance.new("ScreenGui")
    spinGui.Name           = "SpinGui"
    spinGui.IgnoreGuiInset = true
    spinGui.ResetOnSpawn   = false
    spinGui.Enabled        = false
    spinGui.Parent         = PlayerGui

    -- Fond sombre
    overlay = Instance.new("Frame")
    overlay.Size                  = UDim2.new(1,0,1,0)
    overlay.BackgroundColor3      = Color3.new(0,0,0)
    overlay.BackgroundTransparency = 0.52
    overlay.BorderSizePixel       = 0
    overlay.Parent                = spinGui

    -- Flash victoire (au-dessus de tout)
    flashFrame = Instance.new("Frame")
    flashFrame.Size                   = UDim2.new(1,0,1,0)
    flashFrame.BackgroundColor3       = Color3.new(1,1,1)
    flashFrame.BackgroundTransparency = 1
    flashFrame.BorderSizePixel        = 0
    flashFrame.ZIndex                 = 100
    flashFrame.Parent                 = spinGui

    -- ── Colonne principale (UIListLayout Vertical) ────────────────────────────
    local container = Instance.new("Frame")
    container.Name                  = "Container"
    container.Size                  = UDim2.new(0, 420, 0, 52+8+LIST_H+8+54)
    container.AnchorPoint           = Vector2.new(0.5, 0.5)
    container.Position              = UDim2.new(0.5, 0, 0.5, 0)
    container.BackgroundTransparency = 1
    container.Parent                = overlay

    local colLayout = Instance.new("UIListLayout")
    colLayout.SortOrder          = Enum.SortOrder.LayoutOrder
    colLayout.FillDirection      = Enum.FillDirection.Vertical
    colLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    colLayout.VerticalAlignment  = Enum.VerticalAlignment.Top
    colLayout.Padding            = UDim.new(0, 8)
    colLayout.Parent             = container

    -- ① Titre [layoutOrder 1] ─────────────────────────────────────────────────
    title = Instance.new("TextLabel")
    title.Name                   = "Title"
    title.Size                   = UDim2.new(1, 0, 0, 52)
    title.BackgroundTransparency = 1
    title.Text                   = "BRAINROT SPIN"
    title.TextColor3             = Color3.fromRGB(255, 225, 0)
    title.Font                   = Enum.Font.LuckiestGuy
    title.TextScaled             = true
    title.TextStrokeTransparency = 0
    title.TextStrokeColor3       = Color3.new(0,0,0)
    title.LayoutOrder            = 1
    title.ZIndex                 = 5
    title.Parent                 = container

    -- ② Rangée machine (mainFrame + flèches) [layoutOrder 2] ──────────────────
    local machineRow = Instance.new("Frame")
    machineRow.Name                  = "MachineRow"
    machineRow.Size                  = UDim2.new(1, 0, 0, LIST_H)
    machineRow.BackgroundTransparency = 1
    machineRow.LayoutOrder           = 2
    machineRow.Parent                = container

    -- Flèche gauche (HORS mainFrame — jamais clippée)
    local arrowL = Instance.new("TextLabel")
    arrowL.Size              = UDim2.new(0, 30, 0, 30)
    arrowL.AnchorPoint       = Vector2.new(1, 0.5)
    arrowL.Position          = UDim2.new(0, -10, 0.5, 0)
    arrowL.BackgroundTransparency = 1
    arrowL.Text              = "▶"
    arrowL.TextColor3        = Color3.fromRGB(255, 215, 0)
    arrowL.Font              = Enum.Font.GothamBlack
    arrowL.TextScaled        = true
    arrowL.TextStrokeTransparency = 0
    arrowL.ZIndex            = 10
    arrowL.Parent            = machineRow

    -- Flèche droite (HORS mainFrame — jamais clippée)
    local arrowR = Instance.new("TextLabel")
    arrowR.Size              = UDim2.new(0, 30, 0, 30)
    arrowR.AnchorPoint       = Vector2.new(0, 0.5)
    arrowR.Position          = UDim2.new(1, 10, 0.5, 0)
    arrowR.BackgroundTransparency = 1
    arrowR.Text              = "◀"
    arrowR.TextColor3        = Color3.fromRGB(255, 215, 0)
    arrowR.Font              = Enum.Font.GothamBlack
    arrowR.TextScaled        = true
    arrowR.TextStrokeTransparency = 0
    arrowR.ZIndex            = 10
    arrowR.Parent            = machineRow

    -- Fenêtre clippée
    mainFrame = Instance.new("Frame")
    mainFrame.Name               = "MainFrame"
    mainFrame.Size               = UDim2.new(1, 0, 1, 0)
    mainFrame.BackgroundColor3   = Color3.fromRGB(15, 15, 20)
    mainFrame.BorderSizePixel    = 0
    mainFrame.ClipsDescendants   = true   -- SEUL clip de l'UI
    mainFrame.ZIndex             = 2
    mainFrame.Parent             = machineRow
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

    local rimStroke = Instance.new("UIStroke")
    rimStroke.Color     = Color3.fromRGB(255, 215, 0)
    rimStroke.Thickness = 4
    rimStroke.Parent    = mainFrame

    -- ★ Étoiles décoratives FIXES (à l'intérieur de mainFrame mais HORS scrollList)
    -- Elles ne bougent jamais, elles décorent les coins
    local function makeStar(anchorX, posX)
        local s = Instance.new("TextLabel")
        s.Size              = UDim2.new(0, 36, 0, LIST_H)
        s.AnchorPoint       = Vector2.new(anchorX, 0)
        s.Position          = UDim2.new(posX, 0, 0, 0)
        s.BackgroundTransparency = 1
        s.Text              = "★\n★\n★"
        s.TextColor3        = Color3.fromRGB(255, 230, 50)
        s.Font              = Enum.Font.GothamBlack
        s.TextScaled        = false
        s.TextSize          = 18
        s.LineHeight        = 2.2
        s.TextXAlignment    = Enum.TextXAlignment.Center
        s.TextYAlignment    = Enum.TextYAlignment.Center
        s.TextStrokeTransparency = 0.4
        s.ZIndex            = 8   -- au-dessus de scrollList (ZIndex 3-4)
        s.Parent            = mainFrame
    end
    makeStar(0, 0)    -- côté gauche
    makeStar(1, 1)    -- côté droit

    -- Surbrillance centrale (bande dorée semi-transparente — HORS scrollList)
    local highlight = Instance.new("Frame")
    highlight.Size              = UDim2.new(1, 0, 0, ROW_H + 6)
    highlight.AnchorPoint       = Vector2.new(0, 0.5)
    highlight.Position          = UDim2.new(0, 0, 0.5, 0)
    highlight.BackgroundTransparency = 1
    highlight.BorderSizePixel   = 0
    highlight.ZIndex            = 7
    highlight.Parent            = mainFrame
    local hlStroke = Instance.new("UIStroke")
    hlStroke.Color     = Color3.fromRGB(255, 215, 0)
    hlStroke.Thickness = 3
    hlStroke.Parent    = highlight

    -- ── ScrollList ────────────────────────────────────────────────────────────
    local nSeg      = #segments
    local totalRows = nSeg * (LOOPS + 1)
    local totalH    = totalRows * EFF + ROW_PAD

    scrollList = Instance.new("Frame")
    scrollList.Name                   = "ScrollList"
    scrollList.Size                   = UDim2.new(1, 0, 0, totalH)
    scrollList.Position               = UDim2.new(0, 0, 0, 0)
    scrollList.BackgroundTransparency = 1
    scrollList.ZIndex                 = 3
    scrollList.Parent                 = mainFrame

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder           = Enum.SortOrder.LayoutOrder
    listLayout.FillDirection       = Enum.FillDirection.Vertical
    listLayout.VerticalAlignment   = Enum.VerticalAlignment.Top
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.Padding             = UDim.new(0, ROW_PAD)
    listLayout.Parent              = scrollList

    -- Lignes (pas d'étoiles ici — elles sont décoratives fixes sur mainFrame)
    local idx = 1
    for _ = 0, LOOPS do
        for i = 1, nSeg do
            local seg  = segments[i]
            local rCol = RARITY_COLORS[seg.rarity] or Color3.fromRGB(80, 80, 80)

            local row = Instance.new("Frame")
            row.Name             = "R" .. idx
            row.Size             = UDim2.new(0.88, 0, 0, ROW_H)
            row.BackgroundColor3 = rCol
            row.BorderSizePixel  = 0
            row.LayoutOrder      = idx
            row.ZIndex           = 3
            row.Parent           = scrollList
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 7)

            local lbl = Instance.new("TextLabel")
            lbl.Size                   = UDim2.new(1, 0, 1, 0)
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

            idx = idx + 1
        end
    end

    -- ③ Rangée boutons [layoutOrder 3] ────────────────────────────────────────
    local btnRow = Instance.new("Frame")
    btnRow.Name                  = "BtnRow"
    btnRow.Size                  = UDim2.new(1, 0, 0, 54)
    btnRow.BackgroundTransparency = 1
    btnRow.LayoutOrder           = 3
    btnRow.Parent                = container

    local btnLayout = Instance.new("UIListLayout")
    btnLayout.SortOrder           = Enum.SortOrder.LayoutOrder
    btnLayout.FillDirection       = Enum.FillDirection.Horizontal
    btnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    btnLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
    btnLayout.Padding             = UDim.new(0, 12)
    btnLayout.Parent              = btnRow

    local function makeBtn(txt, bgColor, order)
        local b = Instance.new("TextButton")
        b.Size             = UDim2.new(0, 190, 0, 54)
        b.BackgroundColor3 = bgColor
        b.Text             = txt
        b.TextColor3       = Color3.new(1, 1, 1)
        b.Font             = Enum.Font.GothamBlack
        b.TextSize         = 22
        b.Visible          = false
        b.LayoutOrder      = order
        b.ZIndex           = 20
        b.Parent           = btnRow
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
        local st = Instance.new("UIStroke"); st.Color = Color3.new(0,0,0); st.Thickness = 2; st.Parent = b
        return b
    end

    local closeBtn  = makeBtn("FERMER",        Color3.fromRGB(210, 35, 35), 1)
    local reSpinBtn = makeBtn("RE-SPIN (20G)", Color3.fromRGB(30, 185, 30), 2)
    reSpinBtn.Font = Enum.Font.LuckiestGuy

    -- ── Pop-up victoire (ZIndex 200, toujours au-dessus, position fixe) ─────────
    -- Structure :  [  BADGE RARETÉ  ]   (fond = couleur rareté)
    --              [ NOM DU BRAINROT ]  (fond sombre)
    winPopup = Instance.new("Frame")
    winPopup.Name                  = "WinPopup"
    winPopup.Size                  = UDim2.new(0, 460, 0, 120)
    winPopup.AnchorPoint           = Vector2.new(0.5, 0)
    winPopup.Position              = UDim2.new(0.5, 0, 0, 26)
    winPopup.BackgroundColor3      = Color3.fromRGB(12, 12, 18)
    winPopup.BorderSizePixel       = 0
    winPopup.ClipsDescendants      = true
    winPopup.Visible               = false
    winPopup.ZIndex                = 200
    winPopup.Parent                = spinGui
    Instance.new("UICorner", winPopup).CornerRadius = UDim.new(0, 14)

    -- Bande de couleur rareté (haut du popup) — couleur mise à jour au gain
    local rarityBand = Instance.new("Frame")
    rarityBand.Name                  = "RarityBand"
    rarityBand.Size                  = UDim2.new(1, 0, 0, 38)
    rarityBand.Position              = UDim2.new(0, 0, 0, 0)
    rarityBand.BackgroundColor3      = Color3.fromRGB(255, 215, 0)  -- remplacé au gain
    rarityBand.BorderSizePixel       = 0
    rarityBand.ZIndex                = 201
    rarityBand.Parent                = winPopup

    local rarityLbl = Instance.new("TextLabel")
    rarityLbl.Name                   = "RarityLabel"
    rarityLbl.Size                   = UDim2.new(1, 0, 1, 0)
    rarityLbl.BackgroundTransparency = 1
    rarityLbl.Text                   = "LEGENDARY"   -- remplacé au gain
    rarityLbl.TextColor3             = Color3.new(1, 1, 1)
    rarityLbl.Font                   = Enum.Font.GothamBlack
    rarityLbl.TextScaled             = true
    rarityLbl.TextStrokeTransparency = 0.3
    rarityLbl.TextStrokeColor3       = Color3.new(0, 0, 0)
    rarityLbl.ZIndex                 = 202
    rarityLbl.Parent                 = rarityBand

    -- Nom du brainrot (zone principale)
    winPopupLabel = Instance.new("TextLabel")
    winPopupLabel.Name                   = "NameLabel"
    winPopupLabel.Size                   = UDim2.new(1, -16, 0, 72)
    winPopupLabel.AnchorPoint            = Vector2.new(0.5, 1)
    winPopupLabel.Position               = UDim2.new(0.5, 0, 1, -6)
    winPopupLabel.BackgroundTransparency = 1
    winPopupLabel.Text                   = ""
    winPopupLabel.TextColor3             = Color3.new(1, 1, 1)
    winPopupLabel.Font                   = Enum.Font.LuckiestGuy
    winPopupLabel.TextScaled             = true   -- gère "Bombardini Gusini" sans débord
    winPopupLabel.TextXAlignment         = Enum.TextXAlignment.Center
    winPopupLabel.TextStrokeTransparency = 0
    winPopupLabel.TextStrokeColor3       = Color3.new(0, 0, 0)
    winPopupLabel.ZIndex                 = 202
    winPopupLabel.Parent                 = winPopup

    -- Callbacks boutons
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

    -- Expose boutons pour l'animation
    return closeBtn, reSpinBtn
end

-- ─────────────────────────────────────────────────────────────────────────────
-- ANIMATION
-- ─────────────────────────────────────────────────────────────────────────────
SpinResult.OnClientEvent:Connect(function(res)
    if not res.success then return end
    if not res.segments  then return end

    local closeBtn, reSpinBtn = buildUI(res.segments)

    local now = tick()
    if now - lastSpin < COOLDOWN then return end
    lastSpin = now

    winPopup.Visible  = false
    flashFrame.BackgroundTransparency = 1
    spinGui.Enabled   = true

    local nSeg    = #res.segments
    local centerY = LIST_H / 2   -- centre vertical de mainFrame (px)

    -- ── Index du segment gagnant ─────────────────────────────────────────────
    -- La liste est construite avec (LOOPS+1) boucles de nSeg lignes.
    -- On cible la boucle n°TARGET_LOOP (0-indexed) pour laisser du "rebond" après.
    -- Exemple nSeg=12, TARGET_LOOP=3, winSegment=5 → targetIdx = 3*12+5 = 41
    local TARGET_LOOP = 3
    local targetIdx   = TARGET_LOOP * nSeg + res.winSegment   -- ligne 1-indexée

    -- Centre de cette ligne dans le scrollList :
    -- Ligne N démarre à (N-1)*EFF, son centre est à (N-1)*EFF + ROW_H/2
    local lineCenterY = (targetIdx - 1) * EFF + ROW_H / 2

    -- Position finale du scrollList : on veut que lineCenterY coïncide avec centerY
    -- scrollList.Y + lineCenterY = centerY  →  scrollList.Y = centerY - lineCenterY
    local finalYPos = centerY - lineCenterY   -- toujours négatif (liste monte)

    -- Départ : item 1 visible en haut de mainFrame (Y=0, pas de décalage)
    scrollList.Position = UDim2.new(0, 0, 0, 0)

    local duration  = res.duration or 5.5
    local tween = TweenService:Create(
        scrollList,
        TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        { Position = UDim2.new(0, 0, 0, finalYPos) }
    )

    -- Tick sonore à chaque passage de slot
    local lastTick = -1
    local conn = RunService.RenderStepped:Connect(function()
        local curOff   = scrollList.Position.Y.Offset
        local passed   = math.floor((centerY - curOff) / EFF)
        if passed ~= lastTick then
            lastTick = passed
            sndTick:Play()
        end
    end)

    tween.Completed:Connect(function()
        conn:Disconnect()

        -- Flash blanc
        flashFrame.BackgroundTransparency = 0
        TweenService:Create(flashFrame,
            TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { BackgroundTransparency = 1 }
        ):Play()

        -- Cache le titre, affiche le popup de victoire
        if title then title.Visible = false end

        local rCol = RARITY_COLORS[res.memeRarity] or Color3.fromRGB(160, 162, 168)

        -- Bande de rareté (couleur + label)
        local band = winPopup:FindFirstChild("RarityBand")
        if band then
            band.BackgroundColor3 = rCol
            local rl = band:FindFirstChild("RarityLabel")
            if rl then rl.Text = "✦ " .. (res.memeRarity or "?") .. " ✦" end
        end

        -- Nom du brainrot (TextScaled gère les noms longs comme "Bombardini Gusini")
        winPopupLabel.Text       = string.upper(res.memeName)
        winPopupLabel.TextColor3 = Color3.new(1, 1, 1)

        winPopup.Visible = true

        if res.memeRarity == "LEGENDARY" or res.memeRarity == "EPIC" then
            sndFanfare:Play()
        else
            sndWin:Play()
        end

        closeBtn.Visible  = true
        reSpinBtn.Visible = true
    end)

    tween:Play()
end)

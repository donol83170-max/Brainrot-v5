-- WheelClient.client.lua
-- Affiche le résultat du spin : notification d'erreur ou panneau de victoire.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Events     = ReplicatedStorage:WaitForChild("Events")
local SpinResult = Events:WaitForChild("SpinResult")

-- ══════════════════════════════════════════════════════════════════════════════
-- COULEURS DE RARETÉ — TABLE OFFICIELLE (insensible à la casse via string.find)
-- ══════════════════════════════════════════════════════════════════════════════
local function getRarityColor(rarity: string): Color3
    local r = string.upper(tostring(rarity or ""))
    if string.find(r, "ULTRA")                               then return Color3.fromRGB(255,  50,  50) end  -- ROUGE ULTRA
    if string.find(r, "EPIC")   or string.find(r, "PIQUE")  then return Color3.fromRGB(255,   0, 255) end  -- VIOLET
    if string.find(r, "LEGEND")                              then return Color3.fromRGB(255, 215,   0) end  -- DORÉ
    if string.find(r, "RARE")                                then return Color3.fromRGB(  0, 130, 255) end  -- BLEU
    if string.find(r, "COMMON") or string.find(r, "COMMUN") then return Color3.fromRGB(  0, 255,   0) end  -- VERT
    warn("[WheelClient] Rareté inconnue : '" .. tostring(rarity) .. "'")
    return Color3.fromRGB(255, 120, 0)  -- ORANGE = visible, jamais gris
end

local function getRarityLabel(rarity: string): string
    local r = string.upper(tostring(rarity or ""))
    if string.find(r, "ULTRA")                               then return "ULTRA LÉGENDAIRE" end
    if string.find(r, "EPIC")   or string.find(r, "PIQUE")  then return "ÉPIQUE"    end
    if string.find(r, "LEGEND")                              then return "LÉGENDAIRE" end
    if string.find(r, "RARE")                                then return "RARE"       end
    if string.find(r, "COMMON") or string.find(r, "COMMUN") then return "COMMUN"     end
    return tostring(rarity or "?")
end

-- ══════════════════════════════════════════════════════════════════════════════
-- NOTIFICATION "PAS ASSEZ DE COINS"
-- ══════════════════════════════════════════════════════════════════════════════
local function showNoCoins()
    -- Supprimer toute notif existante
    local old = playerGui:FindFirstChild("NoCoinsGui")
    if old then old:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name            = "NoCoinsGui"
    sg.ResetOnSpawn    = false
    sg.IgnoreGuiInset  = true
    sg.Parent          = playerGui

    local frame = Instance.new("Frame")
    frame.Size             = UDim2.new(0, 340, 0, 60)
    frame.AnchorPoint      = Vector2.new(0.5, 0)
    frame.Position         = UDim2.new(0.5, 0, 0.12, 0)
    frame.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
    frame.BorderSizePixel  = 0
    frame.Parent           = sg
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0.2, 0)

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, -12, 1, 0)
    lbl.Position               = UDim2.new(0, 6, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = "Pas assez de Brainrot Coins ! (20 requis)"
    lbl.TextColor3             = Color3.new(1, 1, 1)
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextScaled             = true
    lbl.TextStrokeTransparency = 0.5
    lbl.Parent                 = frame

    -- Slide-in depuis le haut
    frame.Position = UDim2.new(0.5, 0, -0.05, 0)
    TweenService:Create(frame,
        TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, 0, 0.12, 0) }
    ):Play()

    task.delay(2.5, function()
        if sg.Parent then
            TweenService:Create(frame,
                TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                { Position = UDim2.new(0.5, 0, -0.1, 0) }
            ):Play()
            task.delay(0.35, function() sg:Destroy() end)
        end
    end)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- PANNEAU DE RÉSULTAT
-- ══════════════════════════════════════════════════════════════════════════════
local function showResult(data)
    -- Supprimer tout panneau existant
    local old = playerGui:FindFirstChild("SpinResultGui")
    if old then old:Destroy() end

    local rarityColor = getRarityColor(data.memeRarity)
    local rarityLabel = getRarityLabel(data.memeRarity)
    print("[WheelClient] showResult — memeRarity='" .. tostring(data.memeRarity) .. "' → couleur appliquée")

    local sg = Instance.new("ScreenGui")
    sg.Name           = "SpinResultGui"
    sg.ResetOnSpawn   = false
    sg.IgnoreGuiInset = true
    sg.Parent         = playerGui

    -- Fond semi-transparent
    local overlay = Instance.new("Frame")
    overlay.Size             = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.55
    overlay.BorderSizePixel  = 0
    overlay.Parent           = sg

    -- Panneau central
    local panel = Instance.new("Frame")
    panel.Size             = UDim2.new(0, 380, 0, 460)
    panel.AnchorPoint      = Vector2.new(0.5, 0.5)
    panel.Position         = UDim2.new(0.5, 0, 0.5, 0)
    panel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    panel.BorderSizePixel  = 0
    panel.Parent           = sg
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0.04, 0)

    -- Bordure colorée (rareté)
    local stroke = Instance.new("UIStroke")
    stroke.Color     = rarityColor
    stroke.Thickness = 4
    stroke.Parent    = panel

    -- Titre "TU AS OBTENU !"
    local title = Instance.new("TextLabel")
    title.Size                   = UDim2.new(1, -20, 0, 50)
    title.Position               = UDim2.new(0, 10, 0, 14)
    title.BackgroundTransparency = 1
    title.Text                   = "TU AS OBTENU !"
    title.TextColor3             = Color3.new(1, 1, 1)
    title.Font                   = Enum.Font.GothamBlack
    title.TextScaled             = true
    title.Parent                 = panel

    -- Badge de rareté
    local rarityBadge = Instance.new("Frame")
    rarityBadge.Size             = UDim2.new(0, 160, 0, 32)
    rarityBadge.AnchorPoint      = Vector2.new(0.5, 0)
    rarityBadge.Position         = UDim2.new(0.5, 0, 0, 68)
    rarityBadge.BackgroundColor3 = rarityColor
    rarityBadge.BorderSizePixel  = 0
    rarityBadge.Parent           = panel
    Instance.new("UICorner", rarityBadge).CornerRadius = UDim.new(0.5, 0)

    local rarityLbl = Instance.new("TextLabel")
    rarityLbl.Size                   = UDim2.new(1, 0, 1, 0)
    rarityLbl.BackgroundTransparency = 1
    rarityLbl.Text                   = rarityLabel
    rarityLbl.TextColor3             = Color3.new(1, 1, 1)
    rarityLbl.Font                   = Enum.Font.GothamBold
    rarityLbl.TextScaled             = true
    rarityLbl.Parent                 = rarityBadge

    -- Image du mème
    local imgFrame = Instance.new("Frame")
    imgFrame.Size             = UDim2.new(0, 220, 0, 220)
    imgFrame.AnchorPoint      = Vector2.new(0.5, 0)
    imgFrame.Position         = UDim2.new(0.5, 0, 0, 114)
    imgFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
    imgFrame.BorderSizePixel  = 0
    imgFrame.Parent           = panel
    Instance.new("UICorner", imgFrame).CornerRadius = UDim.new(0.08, 0)

    local imgStroke = Instance.new("UIStroke")
    imgStroke.Color     = rarityColor
    imgStroke.Thickness = 3
    imgStroke.Parent    = imgFrame

    local img = Instance.new("ImageLabel")
    img.Size             = UDim2.new(0.9, 0, 0.9, 0)
    img.AnchorPoint      = Vector2.new(0.5, 0.5)
    img.Position         = UDim2.new(0.5, 0, 0.5, 0)
    img.BackgroundTransparency = 1
    img.Image            = "rbxassetid://" .. data.imageId
    img.ScaleType        = Enum.ScaleType.Fit
    img.Parent           = imgFrame

    -- Nom du mème
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size                   = UDim2.new(1, -20, 0, 50)
    nameLbl.AnchorPoint            = Vector2.new(0.5, 0)
    nameLbl.Position               = UDim2.new(0.5, 0, 0, 348)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text                   = data.memeName
    nameLbl.TextColor3             = Color3.new(1, 1, 1)
    nameLbl.Font                   = Enum.Font.GothamBlack
    nameLbl.TextScaled             = true
    nameLbl.TextStrokeTransparency = 0.5
    nameLbl.Parent                 = panel

    -- Bouton fermer
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size             = UDim2.new(0, 160, 0, 44)
    closeBtn.AnchorPoint      = Vector2.new(0.5, 0)
    closeBtn.Position         = UDim2.new(0.5, 0, 0, 404)
    closeBtn.BackgroundColor3 = rarityColor
    closeBtn.BorderSizePixel  = 0
    closeBtn.Text             = "Super !"
    closeBtn.TextColor3       = Color3.new(1, 1, 1)
    closeBtn.Font             = Enum.Font.GothamBold
    closeBtn.TextScaled       = true
    closeBtn.Parent           = panel
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0.3, 0)

    -- Animation pop-in
    panel.Size = UDim2.new(0, 0, 0, 0)
    overlay.BackgroundTransparency = 1
    TweenService:Create(overlay,
        TweenInfo.new(0.25, Enum.EasingStyle.Linear),
        { BackgroundTransparency = 0.55 }
    ):Play()
    TweenService:Create(panel,
        TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Size = UDim2.new(0, 380, 0, 460) }
    ):Play()

    -- Fermeture
    local function close()
        TweenService:Create(panel,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Size = UDim2.new(0, 0, 0, 0) }
        ):Play()
        TweenService:Create(overlay,
            TweenInfo.new(0.2, Enum.EasingStyle.Linear),
            { BackgroundTransparency = 1 }
        ):Play()
        task.delay(0.22, function() sg:Destroy() end)
    end

    closeBtn.MouseButton1Click:Connect(close)
    overlay.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            close()
        end
    end)

    -- Auto-fermeture après 8 secondes
    task.delay(8, function()
        if sg.Parent then close() end
    end)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ÉCOUTE DU REMOTE EVENT
-- ══════════════════════════════════════════════════════════════════════════════
SpinResult.OnClientEvent:Connect(function(data)
    if not data then return end

    if not data.success then
        if data.reason == "coins" then
            showNoCoins()
        elseif data.reason == "machine_full" then
            -- Affiche une notification similaire pour machine pleine
            local oldGui = playerGui:FindFirstChild("NoCoinsGui")
            if oldGui then oldGui:Destroy() end
            local sg = Instance.new("ScreenGui")
            sg.Name = "NoCoinsGui"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true
            sg.Parent = playerGui
            local frame = Instance.new("Frame")
            frame.Size = UDim2.new(0, 380, 0, 60); frame.AnchorPoint = Vector2.new(0.5, 0)
            frame.Position = UDim2.new(0.5, 0, 0.12, 0)
            frame.BackgroundColor3 = Color3.fromRGB(200, 120, 0); frame.BorderSizePixel = 0
            frame.Parent = sg
            Instance.new("UICorner", frame).CornerRadius = UDim.new(0.2, 0)
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -12, 1, 0); lbl.Position = UDim2.new(0, 6, 0, 0)
            lbl.BackgroundTransparency = 1; lbl.Text = "Machine pleine ! Envoie tes Brainrots à ta base."
            lbl.TextColor3 = Color3.new(1,1,1); lbl.Font = Enum.Font.GothamBold
            lbl.TextScaled = true; lbl.Parent = frame
            task.delay(3, function() if sg.Parent then sg:Destroy() end end)
        end
        return
    end

    -- Attendre la fin de l'animation avant d'afficher le résultat
    local waitTime = (data.duration or 5.5) + 0.3
    task.delay(waitTime, function()
        showResult(data)
    end)
end)

print("[WheelClient] Pret — en attente des resultats de spin")

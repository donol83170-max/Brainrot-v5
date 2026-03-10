-- WheelClient.client.lua
-- Affiche le résultat du spin : notification d'erreur ou panneau de victoire.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Debris            = game:GetService("Debris")
local RunService        = game:GetService("RunService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Events     = ReplicatedStorage:WaitForChild("Events")
local SpinResult = Events:WaitForChild("SpinResult")

-- ══════════════════════════════════════════════════════════════════════════════
-- COULEURS DE RARETÉ — TABLE OFFICIELLE (insensible à la casse via string.find)
-- ══════════════════════════════════════════════════════════════════════════════
local function getRarityColor(rarity: string): Color3
    local r = string.upper(tostring(rarity or ""))
    if string.find(r, "EPIC")   or string.find(r, "PIQUE")  then return Color3.fromRGB(255,   0, 255) end  -- VIOLET
    if string.find(r, "LEGEND")                              then return Color3.fromRGB(255, 215,   0) end  -- DORÉ
    if string.find(r, "RARE")                                then return Color3.fromRGB(  0, 130, 255) end  -- BLEU
    if string.find(r, "COMMON") or string.find(r, "COMMUN") then return Color3.fromRGB(  0, 255,   0) end  -- VERT
    warn("[WheelClient] Rareté inconnue : '" .. tostring(rarity) .. "'")
    return Color3.fromRGB(255, 120, 0)  -- ORANGE = visible, jamais gris
end

local function getRarityLabel(rarity: string): string
    local r = string.upper(tostring(rarity or ""))
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
-- CONFETTIS DE RARETÉ
-- ══════════════════════════════════════════════════════════════════════════════
local function spawnConfetti(color: Color3)
    local character = player.Character
    if not character then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local part = Instance.new("Part")
    part.Size         = Vector3.new(0.1, 0.1, 0.1)
    part.Anchored     = true
    part.CanCollide   = false
    part.Transparency = 1
    part.CFrame       = CFrame.new(root.Position + Vector3.new(0, 4, 0))
    part.Parent       = workspace

    local pe = Instance.new("ParticleEmitter")
    pe.Color        = ColorSequence.new(color)
    pe.LightEmission = 0.4
    pe.Size         = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.45),
        NumberSequenceKeypoint.new(1, 0.1),
    })
    pe.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0),
        NumberSequenceKeypoint.new(0.8, 0),
        NumberSequenceKeypoint.new(1,   1),
    })
    pe.Speed        = NumberRange.new(10, 22)
    pe.SpreadAngle  = Vector2.new(75, 75)
    pe.Rotation     = NumberRange.new(0, 360)
    pe.RotSpeed     = NumberRange.new(-200, 200)
    pe.Lifetime     = NumberRange.new(1.8, 3.2)
    pe.Rate         = 0
    pe.Parent       = part

    pe:Emit(90)
    Debris:AddItem(part, 4)
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

    -- Explosion de confettis colorés selon la rareté
    spawnConfetti(rarityColor)

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

    -- ViewportFrame 3D (modèle Brainrot en rotation)
    local vp = Instance.new("ViewportFrame")
    vp.Size             = UDim2.new(0, 220, 0, 220)
    vp.AnchorPoint      = Vector2.new(0.5, 0.5)
    vp.Position         = UDim2.new(0.5, 0, 0.5, -10)  -- centré dans le panel
    vp.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    vp.BorderSizePixel  = 0
    vp.Ambient          = Color3.fromRGB(160, 160, 160)
    vp.LightDirection   = Vector3.new(-1, -2, -1)
    vp.Parent           = panel
    Instance.new("UICorner", vp).CornerRadius = UDim.new(0.08, 0)

    local vpStroke = Instance.new("UIStroke")
    vpStroke.Color     = rarityColor
    vpStroke.Thickness = 3
    vpStroke.Parent    = vp

    -- Recherche du modèle dans BrainrotModels (insensible à la casse, ignore placeholders)
    local brainrotFolder = ReplicatedStorage:FindFirstChild("BrainrotModels")
    local modelClone: Instance? = nil
    if brainrotFolder then
        local searchName = string.lower(data.memeName)
        for _, child in ipairs(brainrotFolder:GetChildren()) do
            if string.lower(child.Name) == searchName
            and not child:GetAttribute("IsPlaceholder") then
                modelClone = child:Clone()
                break
            end
        end
    end

    -- Connexion de rotation (sera déconnectée à la fermeture)
    local rotConn: RBXScriptConnection? = nil

    if modelClone then
        modelClone.Parent = vp

        -- Ancrer toutes les parts pour le viewport
        for _, part in ipairs((modelClone :: Instance):GetDescendants()) do
            if part:IsA("BasePart") then
                (part :: BasePart).Anchored   = true
                (part :: BasePart).CastShadow = false
            end
        end
        if modelClone:IsA("BasePart") then
            (modelClone :: BasePart).Anchored   = true
            (modelClone :: BasePart).CastShadow = false
        end

        -- Étape 1 : placer le pivot à l'origine pour mesurer l'offset BB→pivot
        if modelClone:IsA("Model") then
            (modelClone :: Model):PivotTo(CFrame.new())
        elseif modelClone:IsA("BasePart") then
            (modelClone :: BasePart).CFrame = CFrame.new()
        end

        -- Étape 2 : bounding box (BB center = vrai centre visuel)
        local boundCF: CFrame, boundSize: Vector3
        if modelClone:IsA("Model") then
            boundCF, boundSize = (modelClone :: Model):GetBoundingBox()
        elseif modelClone:IsA("BasePart") then
            boundCF  = (modelClone :: BasePart).CFrame
            boundSize = (modelClone :: BasePart).Size
        else
            local bp = (modelClone :: Instance):FindFirstChildWhichIsA("BasePart", true) :: BasePart?
            boundCF  = bp and bp.CFrame  or CFrame.new()
            boundSize = bp and bp.Size   or Vector3.new(2, 2, 2)
        end
        -- bbCenter : décalage du centre visuel par rapport au pivot (pivot est à l'origine)
        local bbCenter = boundCF.Position
        local maxDim   = math.max(boundSize.X, boundSize.Y, boundSize.Z)

        -- Étape 3 : centrer le BB à l'origine du viewport (0, 0, 0)
        if modelClone:IsA("Model") then
            (modelClone :: Model):PivotTo(CFrame.new(-bbCenter))
        elseif modelClone:IsA("BasePart") then
            (modelClone :: BasePart).CFrame = CFrame.new(-bbCenter)
        end

        -- Caméra pointée vers (0,0,0), légèrement surélevée
        local cam = Instance.new("Camera")
        local dist = maxDim * 2.5
        cam.FieldOfView = 40
        cam.CFrame      = CFrame.lookAt(
            Vector3.new(0, boundSize.Y * 0.05, dist),
            Vector3.new(0, 0, 0)
        )
        cam.Parent       = vp
        vp.CurrentCamera = cam

        -- Rotation continue sur Y autour de l'origine (= centre BB)
        -- PivotTo( rot * CFrame.new(-bbCenter) ) :
        --   • positionne le pivot à rot*(-bbCenter) → BB center reste à (0,0,0)
        --   • applique la même rotation d'orientation au modèle
        local angle = 0
        rotConn = RunService.RenderStepped:Connect(function(dt: number)
            if not modelClone or not modelClone.Parent then return end
            angle += dt * 55  -- ~55°/s
            local rot = CFrame.Angles(0, math.rad(angle), 0)
            if modelClone:IsA("Model") then
                (modelClone :: Model):PivotTo(rot * CFrame.new(-bbCenter))
            elseif modelClone:IsA("BasePart") then
                (modelClone :: BasePart).CFrame = rot * CFrame.new(-bbCenter)
            end
        end)
    else
        -- Fallback : image statique si le modèle 3D est absent
        local img = Instance.new("ImageLabel")
        img.Size                   = UDim2.new(0.9, 0, 0.9, 0)
        img.AnchorPoint            = Vector2.new(0.5, 0.5)
        img.Position               = UDim2.new(0.5, 0, 0.5, 0)
        img.BackgroundTransparency = 1
        img.Image                  = "rbxassetid://" .. tostring(data.imageId or 0)
        img.ScaleType              = Enum.ScaleType.Fit
        img.Parent                 = vp
    end

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
        if rotConn then rotConn:Disconnect() ; rotConn = nil end
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

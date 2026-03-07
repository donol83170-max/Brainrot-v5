--!strict
-- WheelSystem.server.lua — 12 SEGMENTS · POOL SYSTEM
-- Logique : rareté pondérée d'abord, puis item dans le pool.
-- Animation : TweenService (QuartOut) sur un NumberValue → Heartbeat applique le CFrame.
-- Sons : tick à chaque cran, fanfare pour EPIC/LEGENDARY, sparkles dorées pour Strawberry Elephant.

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService          = game:GetService("RunService")
local TweenService        = game:GetService("TweenService")
local Workspace           = game:GetService("Workspace")

local DataManager = require(ServerScriptService:WaitForChild("DataManager"))

local Events           = ReplicatedStorage:WaitForChild("Events")
local SpinResult       = Events:WaitForChild("SpinResult")
local UpdateClientData = Events:WaitForChild("UpdateClientData")

-- ══════════════════════════════════════════════════════════════════════════════
-- CONFIG
-- ══════════════════════════════════════════════════════════════════════════════
local N_SEGMENTS    = 12
local SEG_ANGLE     = 360 / N_SEGMENTS   -- 30° par segment
local SPIN_COST     = 20
local SPIN_DURATION = 5.5
local WHEEL_CENTER  = Vector3.new(0, 10, 55)
local WHEEL_RADIUS  = 7

local RARITY_COLORS = {
    COMMON    = Color3.fromRGB(120, 122, 126),   -- gris
    RARE      = Color3.fromRGB(  0, 130, 255),   -- bleu
    EPIC      = Color3.fromRGB(155,   0, 255),   -- violet
    LEGENDARY = Color3.fromRGB(255, 185,   0),   -- doré
}

-- ══════════════════════════════════════════════════════════════════════════════
-- POOLS DE RARETÉ
-- imageId = 0 → à remplacer après upload sur le Toolbox Roblox
-- ══════════════════════════════════════════════════════════════════════════════
local POOL = {
    COMMON = {
        { itemId = "SkibidiHead",     imageId = 15263881432, name = "Skibidi Toilet"      },
        { itemId = "NoobiniPizza",    imageId = 0,           name = "Noobini Pizzanini"   },
        { itemId = "PipiCorni",       imageId = 0,           name = "Pipi Corni"          },
        { itemId = "MaxwellCat",      imageId = 12501659970, name = "Maxwell Cat"         },
    },
    RARE = {
        { itemId = "Tralalero",       imageId = 0,           name = "Tralalero Tralala"   },
        { itemId = "DogeMeme",        imageId = 0,           name = "Doge"                },
    },
    EPIC = {
        { itemId = "BrBrPatapim",     imageId = 0,           name = "Br Br Patapim"       },
        { itemId = "CappuccinoAss",   imageId = 0,           name = "Cappuccino Assassino" },
    },
    LEGENDARY = {
        { itemId = "StrawberryEleph", imageId = 0,           name = "Strawberry Elephant" },
        { itemId = "DragonCannell",   imageId = 0,           name = "Dragon Cannelloni"   },
    },
}

-- Poids de tirage (total = 100)
local RARITY_WEIGHTS = {
    { rarity = "COMMON",    weight = 60 },
    { rarity = "RARE",      weight = 25 },
    { rarity = "EPIC",      weight = 12 },
    { rarity = "LEGENDARY", weight = 3  },
}

-- ══════════════════════════════════════════════════════════════════════════════
-- DISPOSITION DES 12 SEGMENTS
-- 7 Common (gris), 3 Rare (bleu), 1 Epic (violet), 1 Legendary (doré)
-- Répartis de façon équilibrée visuellement.
-- ══════════════════════════════════════════════════════════════════════════════
local SEGMENTS = {
    { rarity = "COMMON",    item = POOL.COMMON[1]    },  --  1  Skibidi Toilet
    { rarity = "COMMON",    item = POOL.COMMON[4]    },  --  2  Maxwell Cat
    { rarity = "RARE",      item = POOL.RARE[1]      },  --  3  Tralalero Tralala ✦
    { rarity = "COMMON",    item = POOL.COMMON[2]    },  --  4  Noobini Pizzanini
    { rarity = "COMMON",    item = POOL.COMMON[3]    },  --  5  Pipi Corni
    { rarity = "LEGENDARY", item = POOL.LEGENDARY[1] },  --  6  Strawberry Elephant ★★
    { rarity = "COMMON",    item = POOL.COMMON[4]    },  --  7  Maxwell Cat
    { rarity = "RARE",      item = POOL.RARE[2]      },  --  8  Doge ✦
    { rarity = "COMMON",    item = POOL.COMMON[1]    },  --  9  Skibidi Toilet
    { rarity = "EPIC",      item = POOL.EPIC[1]      },  -- 10  Br Br Patapim ★
    { rarity = "COMMON",    item = POOL.COMMON[3]    },  -- 11  Pipi Corni
    { rarity = "RARE",      item = POOL.RARE[1]      },  -- 12  Tralalero Tralala ✦
}

-- Pré-calcul : index des segments pour chaque rareté
local SEGS_BY_RARITY: {[string]: {number}} = { COMMON={}, RARE={}, EPIC={}, LEGENDARY={} }
for idx, seg in ipairs(SEGMENTS) do
    table.insert(SEGS_BY_RARITY[seg.rarity], idx)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- TIRAGE PONDÉRÉ
-- ══════════════════════════════════════════════════════════════════════════════
math.randomseed(os.clock() * 1000)

local function pickRarity(): string
    local roll = math.random(1, 100)
    local cum  = 0
    for _, entry in ipairs(RARITY_WEIGHTS) do
        cum += entry.weight
        if roll <= cum then return entry.rarity end
    end
    return "COMMON"
end

local function pickItem(rarity: string)
    local pool = POOL[rarity]
    return pool[math.random(1, #pool)]
end

-- ══════════════════════════════════════════════════════════════════════════════
-- CFrame helpers
-- ══════════════════════════════════════════════════════════════════════════════
-- Cylindre axe Y → après CFrame.Angles(90°,0,0) l'axe devient Z
-- NormalId.Top regarde vers +Z (vers les joueurs côté avenue)
local INIT_CF = CFrame.new(WHEEL_CENTER) * CFrame.Angles(math.rad(90), 0, 0)

local function getWheelCF(deg: number): CFrame
    return CFrame.new(WHEEL_CENTER)
        * CFrame.fromAxisAngle(Vector3.new(0, 0, 1), math.rad(-deg))
        * CFrame.Angles(math.rad(90), 0, 0)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- CONSTRUCTION PHYSIQUE
-- ══════════════════════════════════════════════════════════════════════════════
local wheelFolder = Instance.new("Folder")
wheelFolder.Name   = "BrainrotWheel"
wheelFolder.Parent = Workspace

-- ── Poteau ───────────────────────────────────────────────────────────────────
local post = Instance.new("Part")
post.Name = "WheelPost"; post.Size = Vector3.new(1.5, 14, 1.5)
post.Position = Vector3.new(WHEEL_CENTER.X, 7, WHEEL_CENTER.Z - 0.8)
post.Anchored = true; post.Material = Enum.Material.Metal
post.Color = Color3.fromRGB(50, 50, 55); post.Parent = wheelFolder

-- ── Disque principal (tourne) ─────────────────────────────────────────────────
local wheelPart = Instance.new("Part")
wheelPart.Name = "WheelPart"; wheelPart.Shape = Enum.PartType.Cylinder
wheelPart.Size = Vector3.new(0.9, WHEEL_RADIUS * 2, WHEEL_RADIUS * 2)
wheelPart.CFrame = INIT_CF; wheelPart.Anchored = true
wheelPart.Material = Enum.Material.SmoothPlastic
wheelPart.Color = Color3.fromRGB(18, 18, 24)
wheelPart.CastShadow = false; wheelPart.Parent = wheelFolder
wheelPart:SetAttribute("SpinAngle", 0)

-- ── Jante chrome (statique) ───────────────────────────────────────────────────
local chromeRim = Instance.new("Part")
chromeRim.Shape = Enum.PartType.Cylinder
chromeRim.Size  = Vector3.new(0.8, WHEEL_RADIUS * 2 + 2.2, WHEEL_RADIUS * 2 + 2.2)
chromeRim.CFrame = INIT_CF; chromeRim.Anchored = true
chromeRim.Material = Enum.Material.Metal
chromeRim.Color = Color3.fromRGB(210, 215, 222); chromeRim.Reflectance = 0.45
chromeRim.CanCollide = false; chromeRim.CastShadow = false; chromeRim.Parent = wheelFolder

-- ── Anneau néon doré (statique) ───────────────────────────────────────────────
local neonRing = Instance.new("Part")
neonRing.Shape = Enum.PartType.Cylinder
neonRing.Size  = Vector3.new(0.22, WHEEL_RADIUS * 2 + 3.0, WHEEL_RADIUS * 2 + 3.0)
neonRing.CFrame = INIT_CF; neonRing.Anchored = true
neonRing.Material = Enum.Material.Neon
neonRing.Color = Color3.fromRGB(255, 215, 0)
neonRing.CanCollide = false; neonRing.CastShadow = false; neonRing.Parent = wheelFolder

-- ── 16 Billes néon (arc-en-ciel, statiques) ──────────────────────────────────
local BEAD_PALETTE = {
    Color3.fromRGB(255,  40,  40), Color3.fromRGB(255, 140,   0),
    Color3.fromRGB(255, 245,   0), Color3.fromRGB( 60, 255,  80),
    Color3.fromRGB(  0, 170, 255), Color3.fromRGB(170,   0, 255),
    Color3.fromRGB(255,   0, 180), Color3.fromRGB(255, 255, 255),
}
local N_BEADS   = 16
local BEAD_R    = WHEEL_RADIUS + 2.1
local BEAD_ZF   = WHEEL_CENTER.Z + 0.65
local neonBeads = {}

for i = 1, N_BEADS do
    local a    = math.rad((i - 1) * (360 / N_BEADS))
    local bead = Instance.new("Part")
    bead.Shape = Enum.PartType.Ball; bead.Size = Vector3.new(0.55, 0.55, 0.55)
    bead.Position = Vector3.new(
        WHEEL_CENTER.X + math.cos(a) * BEAD_R,
        WHEEL_CENTER.Y + math.sin(a) * BEAD_R,
        BEAD_ZF)
    bead.Anchored = true; bead.Material = Enum.Material.Neon
    bead.Color = BEAD_PALETTE[((i - 1) % #BEAD_PALETTE) + 1]
    bead.CanCollide = false; bead.CastShadow = false; bead.Parent = wheelFolder
    neonBeads[i] = bead
end

-- ── Dôme central brillant ─────────────────────────────────────────────────────
local dome = Instance.new("Part")
dome.Shape = Enum.PartType.Ball; dome.Size = Vector3.new(2.6, 2.6, 2.6)
dome.Position = WHEEL_CENTER + Vector3.new(0, 0, 0.65); dome.Anchored = true
dome.Material = Enum.Material.SmoothPlastic
dome.Color = Color3.fromRGB(255, 220, 50); dome.Reflectance = 0.6
dome.CanCollide = false; dome.CastShadow = false; dome.Parent = wheelFolder

local domeLight = Instance.new("PointLight")
domeLight.Color = Color3.fromRGB(255, 215, 0); domeLight.Brightness = 1.8
domeLight.Range = 10; domeLight.Parent = dome

-- ── Pointeur stylisé : shaft orange + pointe rouge ───────────────────────────
local POINTER_CY = WHEEL_CENTER.Y + WHEEL_RADIUS + 2.2

local pShaft = Instance.new("Part")
pShaft.Size = Vector3.new(0.35, 2.2, 0.45)
pShaft.CFrame = CFrame.new(WHEEL_CENTER.X, POINTER_CY + 1.6, WHEEL_CENTER.Z)
pShaft.Anchored = true; pShaft.Material = Enum.Material.Neon
pShaft.Color = Color3.fromRGB(255, 90, 0)
pShaft.CanCollide = false; pShaft.CastShadow = false; pShaft.Parent = wheelFolder

local pointer = Instance.new("WedgePart")
pointer.Size = Vector3.new(0.65, 1.8, 1.3)
pointer.CFrame = CFrame.new(WHEEL_CENTER.X, POINTER_CY, WHEEL_CENTER.Z)
             * CFrame.Angles(0, 0, math.rad(180))
pointer.Anchored = true; pointer.Material = Enum.Material.Neon
pointer.Color = Color3.fromRGB(255, 30, 30)
pointer.CanCollide = false; pointer.CastShadow = false; pointer.Parent = wheelFolder

local pointerLight = Instance.new("PointLight")
pointerLight.Color = Color3.fromRGB(255, 60, 0)
pointerLight.Brightness = 2.2; pointerLight.Range = 6; pointerLight.Parent = pointer

-- ── ClickDetector ─────────────────────────────────────────────────────────────
local clickDetector = Instance.new("ClickDetector")
clickDetector.MaxActivationDistance = 30
clickDetector.Parent = wheelPart

-- ══════════════════════════════════════════════════════════════════════════════
-- SONS
-- ══════════════════════════════════════════════════════════════════════════════
local soundPart = Instance.new("Part")
soundPart.Size = Vector3.new(0.1, 0.1, 0.1); soundPart.Position = WHEEL_CENTER
soundPart.Anchored = true; soundPart.Transparency = 1; soundPart.CanCollide = false
soundPart.Parent = wheelFolder

-- Son de cran (tick à chaque segment)
local tickSound = Instance.new("Sound")
tickSound.SoundId  = "rbxassetid://6026984224"
tickSound.Volume   = 0.35; tickSound.RollOffMaxDistance = 35; tickSound.Parent = soundPart

-- Son de victoire standard (COMMON / RARE)
local winSound = Instance.new("Sound")
winSound.SoundId = "rbxassetid://5153734135"
winSound.Volume  = 0.9;  winSound.RollOffMaxDistance = 50;  winSound.Parent = soundPart

-- Fanfare pour EPIC / LEGENDARY
local fanfareSound = Instance.new("Sound")
fanfareSound.SoundId = "rbxassetid://3205426741"
fanfareSound.Volume  = 1.0; fanfareSound.RollOffMaxDistance = 60; fanfareSound.Parent = soundPart

-- ══════════════════════════════════════════════════════════════════════════════
-- SURFACE GUI — 12 segments circulaires + centre SPIN
-- ══════════════════════════════════════════════════════════════════════════════
local surfGui = Instance.new("SurfaceGui")
surfGui.Name = "WheelGui"; surfGui.Face = Enum.NormalId.Top
surfGui.CanvasSize = Vector2.new(512, 512)
surfGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
surfGui.AlwaysOnTop = false; surfGui.ZOffset = 0.6; surfGui.Parent = wheelPart

local C  = 256   -- centre du canvas
local IR = 162   -- rayon des icônes (légèrement réduit : 12 segments plus serrés)
local IS = 74    -- taille des icônes

for i = 1, N_SEGMENTS do
    local seg      = SEGMENTS[i]
    local aRad     = math.rad((i - 1) * SEG_ANGLE)
    local cx       = C + IR * math.sin(aRad)
    local cy       = C - IR * math.cos(aRad)
    local rarColor = RARITY_COLORS[seg.rarity]

    -- Fond circulaire (couleur rareté)
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(0, IS + 12, 0, IS + 12)
    bg.AnchorPoint = Vector2.new(0.5, 0.5)
    bg.Position = UDim2.new(0, cx, 0, cy)
    bg.BackgroundColor3 = rarColor; bg.BorderSizePixel = 0
    bg.ZIndex = 1; bg.Parent = surfGui
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0.5, 0)

    -- Contour blanc
    local wStroke = Instance.new("UIStroke")
    wStroke.Color = Color3.new(1, 1, 1); wStroke.Thickness = 3; wStroke.Parent = bg

    -- Contour doré supplémentaire pour LEGENDARY
    if seg.rarity == "LEGENDARY" then
        local gStroke = Instance.new("UIStroke")
        gStroke.Color = Color3.fromRGB(255, 215, 0); gStroke.Thickness = 5
        gStroke.Parent = bg
    end

    -- Image du mème (ronde)
    local img = Instance.new("ImageLabel")
    img.Size = UDim2.new(0, IS, 0, IS)
    img.AnchorPoint = Vector2.new(0.5, 0.5)
    img.Position = UDim2.new(0.5, 0, 0.44, 0)
    img.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
    img.Image = seg.item.imageId ~= 0 and ("rbxassetid://" .. seg.item.imageId) or ""
    img.ScaleType = Enum.ScaleType.Fit; img.ZIndex = 2; img.Parent = bg
    Instance.new("UICorner", img).CornerRadius = UDim.new(0.5, 0)

    -- Nom court
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(0, IS + 12, 0, 16)
    nameLbl.AnchorPoint = Vector2.new(0.5, 0)
    nameLbl.Position = UDim2.new(0.5, 0, 1, 3)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = seg.item.name
    nameLbl.TextColor3 = Color3.new(1, 1, 1); nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextScaled = true; nameLbl.TextStrokeTransparency = 0.4
    nameLbl.ZIndex = 2; nameLbl.Parent = bg
end

-- Centre SPIN
local centerBg = Instance.new("Frame")
centerBg.Size = UDim2.new(0, 100, 0, 100); centerBg.AnchorPoint = Vector2.new(0.5, 0.5)
centerBg.Position = UDim2.new(0.5, 0, 0.5, 0)
centerBg.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
centerBg.BorderSizePixel = 0; centerBg.ZIndex = 3; centerBg.Parent = surfGui
Instance.new("UICorner", centerBg).CornerRadius = UDim.new(0.5, 0)

local cs = Instance.new("UIStroke")
cs.Color = Color3.fromRGB(255, 215, 0); cs.Thickness = 4; cs.Parent = centerBg

local centerLbl = Instance.new("TextLabel")
centerLbl.Size = UDim2.new(1, 0, 1, 0); centerLbl.BackgroundTransparency = 1
centerLbl.Text = "SPIN!\n💰 " .. SPIN_COST
centerLbl.TextColor3 = Color3.fromRGB(255, 230, 0); centerLbl.Font = Enum.Font.GothamBlack
centerLbl.TextScaled = true; centerLbl.ZIndex = 4; centerLbl.Parent = centerBg

-- ══════════════════════════════════════════════════════════════════════════════
-- BILLES : VAGUE DE COULEURS (accélère pendant le spin)
-- ══════════════════════════════════════════════════════════════════════════════
local beadSpinning = false

task.spawn(function()
    local NP = #BEAD_PALETTE
    while true do
        task.wait(0.07)
        local spd   = beadSpinning and 6 or 2
        local phase = (tick() * spd) % NP
        for bi, bead in ipairs(neonBeads) do
            local idx = math.floor((phase + bi * (NP / N_BEADS)) % NP) + 1
            bead.Color = BEAD_PALETTE[idx]
        end
    end
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- LOGIQUE
-- ══════════════════════════════════════════════════════════════════════════════
local wheelLocked: boolean          = false
local spinCooldowns: {[number]: number} = {}

local function getCoins(player: Player): number
    local ls    = player:FindFirstChild("leaderstats")
    local coins = ls and ls:FindFirstChild("Brainrot Coins")
    return coins and coins.Value or 0
end

-- ── Animation : TweenService sur un NumberValue ───────────────────────────────
-- TweenService ne peut pas faire plusieurs tours sur un CFrame (SLERP = chemin court).
-- Solution : tweener un NumberValue (l'angle en degrés) et appliquer via Heartbeat.
local function animateWheel(fromAngle: number, targetAngle: number, winRarity: string)
    local numVal    = Instance.new("NumberValue")
    numVal.Value    = fromAngle
    beadSpinning    = true

    local tween = TweenService:Create(
        numVal,
        TweenInfo.new(SPIN_DURATION, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        { Value = targetAngle }
    )

    local lastSeg = -1
    local startT  = tick()

    -- Heartbeat : applique l'angle + tick sonore + vibration pointeur
    local conn = RunService.Heartbeat:Connect(function()
        local angle = numVal.Value
        wheelPart.CFrame = getWheelCF(angle)

        -- Tick à chaque changement de segment
        local seg = math.floor((angle % 360) / SEG_ANGLE) % N_SEGMENTS
        if seg ~= lastSeg then
            lastSeg = seg
            tickSound:Play()
        end

        -- Vibration du pointeur (s'atténue avec la décélération)
        local elapsed  = tick() - startT
        local progress = math.min(elapsed / SPIN_DURATION, 1)
        local bobY     = math.sin(elapsed * 22) * (1 - progress) * 0.22
        pointer.CFrame = CFrame.new(WHEEL_CENTER.X, POINTER_CY + bobY, WHEEL_CENTER.Z)
                       * CFrame.Angles(0, 0, math.rad(180))
        pShaft.CFrame  = CFrame.new(WHEEL_CENTER.X, POINTER_CY + bobY + 1.6, WHEEL_CENTER.Z)
    end)

    -- Fin de l'animation
    tween.Completed:Connect(function()
        conn:Disconnect()
        numVal:Destroy()
        beadSpinning     = false
        wheelPart.CFrame = getWheelCF(targetAngle)
        wheelPart:SetAttribute("SpinAngle", targetAngle)

        -- Remet le pointeur en position de repos
        pointer.CFrame = CFrame.new(WHEEL_CENTER.X, POINTER_CY, WHEEL_CENTER.Z)
                       * CFrame.Angles(0, 0, math.rad(180))
        pShaft.CFrame  = CFrame.new(WHEEL_CENTER.X, POINTER_CY + 1.6, WHEEL_CENTER.Z)

        -- Son de victoire selon la rareté
        if winRarity == "LEGENDARY" or winRarity == "EPIC" then
            fanfareSound:Play()
            -- Sparkles dorées sur le dôme pour LEGENDARY (Strawberry Elephant compris)
            if winRarity == "LEGENDARY" then
                local sp = Instance.new("Sparkles")
                sp.SparkleColor = Color3.fromRGB(255, 215, 0)
                sp.Parent       = dome
                task.delay(5, function() if sp.Parent then sp:Destroy() end end)
            end
        else
            winSound:Play()
        end

        wheelLocked = false
    end)

    tween:Play()
end

-- ── Gestion du clic ───────────────────────────────────────────────────────────
clickDetector.MouseClick:Connect(function(player: Player)
    if wheelLocked then return end

    local now = tick()
    if spinCooldowns[player.UserId] and (now - spinCooldowns[player.UserId]) < SPIN_DURATION + 1 then
        return
    end

    -- Vérification des Coins
    if getCoins(player) < SPIN_COST then
        SpinResult:FireClient(player, { success = false, reason = "coins" })
        return
    end

    local data = DataManager.GetData(player)
    if not data then return end

    DataManager.SpendGold(player, SPIN_COST)
    spinCooldowns[player.UserId] = now
    wheelLocked = true

    -- 1. Rareté pondérée
    local winRarity = pickRarity()
    -- 2. Item dans le pool de cette rareté
    local winItem   = pickItem(winRarity)
    -- 3. Segment cible (un parmi ceux de la bonne rareté)
    local segsOfRarity = SEGS_BY_RARITY[winRarity]
    local winSegIdx    = segsOfRarity[math.random(1, #segsOfRarity)]

    -- Calcul de l'angle cible (segment winSegIdx sous le pointeur)
    local currentAngle = wheelPart:GetAttribute("SpinAngle") or 0
    local extraRot     = math.random(5, 8) * 360
    local winAngle     = (winSegIdx - 1) * SEG_ANGLE
    local currentMod   = currentAngle % 360
    local needed       = (winAngle - currentMod + 360) % 360
    if needed < 5 then needed = needed + 360 end
    local targetAngle  = currentAngle + extraRot + needed

    -- Ajout à l'inventaire
    DataManager.AddItem(player, {
        Id     = winItem.itemId,
        Name   = winItem.name,
        Rarity = winRarity,
    })

    -- Rafraîchir la galerie
    if _G.BrainrotGallery_Refresh then
        task.spawn(_G.BrainrotGallery_Refresh, player)
    end

    -- Sync HUD client
    local updated = DataManager.GetData(player)
    if updated then
        UpdateClientData:FireClient(player, updated)
    end

    print(string.format("[WheelSystem] %s → %s '%s' | seg%d | %.1f°→%.1f°",
        player.Name, winRarity, winItem.name, winSegIdx, currentAngle, targetAngle))

    -- Notifier le client AVANT l'animation (WheelClient attend data.duration)
    SpinResult:FireClient(player, {
        success    = true,
        winSegment = winSegIdx,
        memeName   = winItem.name,
        memeRarity = winRarity,
        imageId    = winItem.imageId,
        duration   = SPIN_DURATION,
    })

    -- Lancer l'animation
    animateWheel(currentAngle, targetAngle, winRarity)
end)

print(string.format(
    "[WheelSystem] 12 segments pret — COMMON %d%% | RARE %d%% | EPIC %d%% | LEGENDARY %d%%",
    RARITY_WEIGHTS[1].weight, RARITY_WEIGHTS[2].weight,
    RARITY_WEIGHTS[3].weight, RARITY_WEIGHTS[4].weight))

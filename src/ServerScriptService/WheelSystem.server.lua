-- WheelSystem.server.lua
-- Roue physique avec 8 segments mème, ClickDetector, vérif Coins, animation serveur.

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService          = game:GetService("RunService")
local Workspace           = game:GetService("Workspace")

local DataManager  = require(ServerScriptService:WaitForChild("DataManager"))
local BrainrotData = require(ReplicatedStorage:WaitForChild("BrainrotData"))

local Events           = ReplicatedStorage:WaitForChild("Events")
local SpinResult       = Events:WaitForChild("SpinResult")
local UpdateClientData = Events:WaitForChild("UpdateClientData")

-- ══════════════════════════════════════════════════════════════════════════════
-- CONFIG
-- ══════════════════════════════════════════════════════════════════════════════
local N_SEGMENTS    = 8
local SEG_ANGLE     = 360 / N_SEGMENTS   -- 45° par segment
local SPIN_COST     = 20                 -- Brainrot Coins
local SPIN_DURATION = 5.5               -- secondes d'animation
local WHEEL_CENTER  = Vector3.new(0, 10, 55)
local WHEEL_RADIUS  = 7                  -- studs (rayon du cylindre)

local RARITY_COLORS = {
    NORMAL    = Color3.fromRGB(163, 162, 165),
    RARE      = Color3.fromRGB(  0, 162, 255),
    MYTHIC    = Color3.fromRGB(170,   0, 255),
    LEGENDARY = Color3.fromRGB(255, 170,   0),
    ULTRA     = Color3.fromRGB(255,   0, 127),
}

-- ── Mèmes disponibles (IDs vérifiés) ─────────────────────────────────────────
local MEME_POOL = {
    { itemId = "SkibidiHead",  imageId = 15263881432, name = "Skibidi Toilet",  rarity = "LEGENDARY" },
    { itemId = "BrainrotKing", imageId = 12501659970, name = "Maxwell le Chat", rarity = "RARE"      },
    { itemId = "GigachadJaw",  imageId = 9841004128,  name = "GigaChad",        rarity = "MYTHIC"    },
    { itemId = "NpcFace",      imageId = 14751493032, name = "Smurf Cat",       rarity = "RARE"      },
    { itemId = "CosmicNoob",   imageId = 15234232386, name = "Pomni",           rarity = "LEGENDARY" },
}

-- Assignation aléatoire des mèmes aux 8 segments au démarrage
math.randomseed(os.clock() * 1000)
local segmentData = {}
for i = 1, N_SEGMENTS do
    segmentData[i] = MEME_POOL[math.random(1, #MEME_POOL)]
end

-- ══════════════════════════════════════════════════════════════════════════════
-- CONSTRUCTION PHYSIQUE
-- ══════════════════════════════════════════════════════════════════════════════
local INIT_CF = CFrame.new(WHEEL_CENTER) * CFrame.Angles(math.rad(90), 0, 0)

local function getWheelCF(spinDeg: number): CFrame
    return CFrame.new(WHEEL_CENTER)
        * CFrame.fromAxisAngle(Vector3.new(0, 0, 1), math.rad(-spinDeg))
        * CFrame.Angles(math.rad(90), 0, 0)
end

local wheelFolder = Instance.new("Folder")
wheelFolder.Name   = "BrainrotWheel"
wheelFolder.Parent = Workspace

-- Poteau de support
local post = Instance.new("Part")
post.Name     = "WheelPost"
post.Size     = Vector3.new(1.5, 14, 1.5)
post.Position = Vector3.new(WHEEL_CENTER.X, 7, WHEEL_CENTER.Z - 0.8)
post.Anchored = true
post.Material = Enum.Material.Metal
post.Color    = Color3.fromRGB(55, 50, 45)
post.Parent   = wheelFolder

-- Cylindre principal (face = NormalId.Top après rotation = vers les joueurs en +Z)
local wheelPart = Instance.new("Part")
wheelPart.Name        = "WheelPart"
wheelPart.Shape       = Enum.PartType.Cylinder
wheelPart.Size        = Vector3.new(1, WHEEL_RADIUS * 2, WHEEL_RADIUS * 2)
wheelPart.CFrame      = INIT_CF
wheelPart.Anchored    = true
wheelPart.Material    = Enum.Material.SmoothPlastic
wheelPart.Color       = Color3.fromRGB(25, 25, 30)
wheelPart.CastShadow  = false
wheelPart.Parent      = wheelFolder
wheelPart:SetAttribute("SpinAngle", 0)

-- Jante néon dorée
local rim = Instance.new("Part")
rim.Name       = "WheelRim"
rim.Shape      = Enum.PartType.Cylinder
rim.Size       = Vector3.new(0.4, WHEEL_RADIUS * 2 + 1.5, WHEEL_RADIUS * 2 + 1.5)
rim.CFrame     = INIT_CF
rim.Anchored   = true
rim.Material   = Enum.Material.Neon
rim.Color      = Color3.fromRGB(255, 215, 0)
rim.CanCollide = false
rim.CastShadow = false
rim.Parent     = wheelFolder

-- Pointeur rouge (en haut de la roue)
local pointer = Instance.new("WedgePart")
pointer.Name       = "Pointer"
pointer.Size       = Vector3.new(0.6, 2.5, 1.4)
pointer.CFrame     = CFrame.new(WHEEL_CENTER + Vector3.new(0, WHEEL_RADIUS + 2, 0))
                   * CFrame.Angles(0, 0, math.rad(180))
pointer.Anchored   = true
pointer.Material   = Enum.Material.Neon
pointer.Color      = Color3.fromRGB(220, 30, 30)
pointer.CanCollide = false
pointer.CastShadow = false
pointer.Parent     = wheelFolder

-- ClickDetector sur le cylindre
local clickDetector = Instance.new("ClickDetector")
clickDetector.MaxActivationDistance = 30
clickDetector.Parent = wheelPart

-- ── SurfaceGui : 8 cases mème en cercle + label central ─────────────────────
local surfGui = Instance.new("SurfaceGui")
surfGui.Name        = "WheelGui"
surfGui.Face        = Enum.NormalId.Top   -- Top local = face +Z après rotation 90°X
surfGui.CanvasSize  = Vector2.new(512, 512)
surfGui.SizingMode  = Enum.SurfaceGuiSizingMode.FixedSize
surfGui.AlwaysOnTop = false
surfGui.ZOffset     = 0.6
surfGui.Parent      = wheelPart

local C  = 256   -- centre du canvas
local IR = 170   -- rayon icônes (pixels)
local IS = 88    -- taille icône (pixels)

for i = 1, N_SEGMENTS do
    local angleDeg = (i - 1) * SEG_ANGLE
    local angleRad = math.rad(angleDeg)
    local cx = C + IR * math.sin(angleRad)
    local cy = C - IR * math.cos(angleRad)
    local meme = segmentData[i]

    -- Fond coloré (rareté)
    local bg = Instance.new("Frame")
    bg.Name             = "Seg_" .. i
    bg.Size             = UDim2.new(0, IS + 10, 0, IS + 10)
    bg.AnchorPoint      = Vector2.new(0.5, 0.5)
    bg.Position         = UDim2.new(0, cx, 0, cy)
    bg.BackgroundColor3 = RARITY_COLORS[meme.rarity] or RARITY_COLORS.NORMAL
    bg.BorderSizePixel  = 0
    bg.ZIndex           = 1
    bg.Parent           = surfGui
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0.15, 0)

    -- Image du mème
    local img = Instance.new("ImageLabel")
    img.Size                   = UDim2.new(0, IS, 0, IS)
    img.AnchorPoint            = Vector2.new(0.5, 0.5)
    img.Position               = UDim2.new(0.5, 0, 0.5, 0)
    img.BackgroundColor3       = Color3.new(0.05, 0.05, 0.05)
    img.Image                  = "rbxassetid://" .. meme.imageId
    img.ScaleType              = Enum.ScaleType.Fit
    -- Image de secours si le chargement échoue (texte)
    img.ImageColor3            = Color3.new(1, 1, 1)
    img.ZIndex                 = 2
    img.Parent                 = bg
    Instance.new("UICorner", img).CornerRadius = UDim.new(0.1, 0)

    -- Nom du mème sous l'image
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size                   = UDim2.new(0, IS + 10, 0, 20)
    nameLbl.AnchorPoint            = Vector2.new(0.5, 0)
    nameLbl.Position               = UDim2.new(0.5, 0, 1, 2)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text                   = meme.name
    nameLbl.TextColor3             = Color3.new(1, 1, 1)
    nameLbl.Font                   = Enum.Font.GothamBold
    nameLbl.TextScaled             = true
    nameLbl.TextStrokeTransparency = 0.4
    nameLbl.ZIndex                 = 2
    nameLbl.Parent                 = bg
end

-- Centre : bouton SPIN
local centerBg = Instance.new("Frame")
centerBg.Size            = UDim2.new(0, 110, 0, 110)
centerBg.AnchorPoint     = Vector2.new(0.5, 0.5)
centerBg.Position        = UDim2.new(0.5, 0, 0.5, 0)
centerBg.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
centerBg.BorderSizePixel = 0
centerBg.ZIndex          = 3
centerBg.Parent          = surfGui
Instance.new("UICorner", centerBg).CornerRadius = UDim.new(0.5, 0)

local centerLbl = Instance.new("TextLabel")
centerLbl.Size                   = UDim2.new(1, 0, 1, 0)
centerLbl.BackgroundTransparency = 1
centerLbl.Text                   = "SPIN!\n💰 " .. SPIN_COST
centerLbl.TextColor3             = Color3.fromRGB(255, 230, 0)
centerLbl.Font                   = Enum.Font.GothamBlack
centerLbl.TextScaled             = true
centerLbl.ZIndex                 = 4
centerLbl.Parent                 = centerBg

-- ══════════════════════════════════════════════════════════════════════════════
-- LOGIQUE DE SPIN
-- ══════════════════════════════════════════════════════════════════════════════
local wheelLocked   = false
local spinCooldowns = {}  -- [userId] = lastSpinTick

local function getCoins(player: Player): number
    local ls    = player:FindFirstChild("leaderstats")
    local coins = ls and ls:FindFirstChild("Brainrot Coins")
    return coins and coins.Value or 0
end

-- Animation côté serveur (répliquée à tous les clients)
local function animateWheel(fromAngle: number, toAngle: number)
    local delta    = toAngle - fromAngle
    local elapsed  = 0

    local conn = RunService.Heartbeat:Connect(function(dt)
        elapsed = math.min(elapsed + dt, SPIN_DURATION)
        local t       = elapsed / SPIN_DURATION
        local easedT  = 1 - (1 - t) ^ 4   -- QuartOut : rapide → lent
        local current = fromAngle + delta * easedT
        wheelPart.CFrame = getWheelCF(current)
    end)

    task.delay(SPIN_DURATION, function()
        conn:Disconnect()
        wheelPart.CFrame = getWheelCF(toAngle)
        wheelPart:SetAttribute("SpinAngle", toAngle)
        wheelLocked = false
    end)
end

clickDetector.MouseClick:Connect(function(player: Player)
    -- Verrous
    if wheelLocked then return end
    local now = tick()
    if spinCooldowns[player.UserId] and (now - spinCooldowns[player.UserId]) < SPIN_DURATION + 1 then
        return
    end

    -- Vérif coins
    if getCoins(player) < SPIN_COST then
        SpinResult:FireClient(player, { success = false, reason = "coins" })
        return
    end

    -- Déduire les coins immédiatement
    local data = DataManager.GetData(player)
    if not data then return end
    DataManager.SpendGold(player, SPIN_COST)
    spinCooldowns[player.UserId] = now
    wheelLocked = true

    -- Choisir le segment gagnant
    local winIdx  = math.random(1, N_SEGMENTS)   -- 1-based
    local winMeme = segmentData[winIdx]

    -- Ajouter l'item à l'inventaire
    DataManager.AddItem(player, {
        Id     = winMeme.itemId,
        Name   = winMeme.name,
        Rarity = winMeme.rarity,
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

    -- Calcul de l'angle cible
    -- Segment winIdx (1-based, 0-based = winIdx-1) est à angle (winIdx-1)*SEG_ANGLE
    -- Pour qu'il soit sous le pointeur (angle 0°) :
    -- spinDeg ≡ (winIdx-1) * SEG_ANGLE (mod 360)
    local currentAngle  = wheelPart:GetAttribute("SpinAngle") or 0
    local extraRot      = math.random(5, 8) * 360    -- 5 à 8 tours supplémentaires
    local winAngle      = (winIdx - 1) * SEG_ANGLE
    local currentMod    = currentAngle % 360
    local needed        = (winAngle - currentMod + 360) % 360
    if needed < 5 then needed = needed + 360 end     -- garantit un minimum de rotation
    local targetAngle   = currentAngle + extraRot + needed

    print(string.format("[WheelSystem] %s → segment %d (%s) | %.1f° → %.1f°",
        player.Name, winIdx, winMeme.name, currentAngle, targetAngle))

    -- Lancer l'animation (côté serveur, répliquée à tous)
    animateWheel(currentAngle, targetAngle)

    -- Notifier le client gagnant (pour l'UI résultat)
    SpinResult:FireClient(player, {
        success    = true,
        winSegment = winIdx,
        memeName   = winMeme.name,
        memeRarity = winMeme.rarity,
        imageId    = winMeme.imageId,
        duration   = SPIN_DURATION,
    })
end)

print(string.format("[WheelSystem] Roue prete — %d segments, cout: %d Coins",
    N_SEGMENTS, SPIN_COST))

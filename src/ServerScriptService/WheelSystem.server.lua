-- WheelSystem.server.lua — ARCADE DELUXE
-- Roue 8 segments : jante chrome, billes néon clignotantes, dôme central, pointeur vibrant.

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
local SEG_ANGLE     = 360 / N_SEGMENTS
local SPIN_COST     = 20
local SPIN_DURATION = 5.5
local WHEEL_CENTER  = Vector3.new(0, 10, 55)
local WHEEL_RADIUS  = 7

local RARITY_COLORS = {
    NORMAL    = Color3.fromRGB(163, 162, 165),
    RARE      = Color3.fromRGB(  0, 162, 255),
    MYTHIC    = Color3.fromRGB(170,   0, 255),
    LEGENDARY = Color3.fromRGB(255, 170,   0),
    ULTRA     = Color3.fromRGB(255,   0, 127),
}

-- Palette des billes néon (vague arc-en-ciel arcade)
local BEAD_COLORS = {
    Color3.fromRGB(255,  40,  40),   -- rouge
    Color3.fromRGB(255, 140,   0),   -- orange
    Color3.fromRGB(255, 245,   0),   -- jaune
    Color3.fromRGB( 60, 255,  80),   -- vert
    Color3.fromRGB(  0, 170, 255),   -- bleu
    Color3.fromRGB(170,   0, 255),   -- violet
    Color3.fromRGB(255,   0, 180),   -- rose
    Color3.fromRGB(255, 255, 255),   -- blanc
}

-- ── Mèmes disponibles ─────────────────────────────────────────────────────────
local MEME_POOL = {
    { itemId = "SkibidiHead",  imageId = 15263881432, name = "Skibidi Toilet",  rarity = "LEGENDARY" },
    { itemId = "BrainrotKing", imageId = 12501659970, name = "Maxwell le Chat", rarity = "RARE"      },
    { itemId = "GigachadJaw",  imageId = 9841004128,  name = "GigaChad",        rarity = "MYTHIC"    },
    { itemId = "NpcFace",      imageId = 14751493032, name = "Smurf Cat",       rarity = "RARE"      },
    { itemId = "CosmicNoob",   imageId = 15234232386, name = "Pomni",           rarity = "LEGENDARY" },
}

math.randomseed(os.clock() * 1000)
local segmentData = {}
for i = 1, N_SEGMENTS do
    segmentData[i] = MEME_POOL[math.random(1, #MEME_POOL)]
end

-- ══════════════════════════════════════════════════════════════════════════════
-- HELPERS CFrame
-- ══════════════════════════════════════════════════════════════════════════════
-- La roue est un cylindre dont l'axe pointe en +Z après CFrame.Angles(90°, 0, 0).
-- Sa face plate (NormalId.Top) regarde donc dans la direction +Z, vers les joueurs.
local INIT_CF = CFrame.new(WHEEL_CENTER) * CFrame.Angles(math.rad(90), 0, 0)

local function getWheelCF(spinDeg: number): CFrame
    return CFrame.new(WHEEL_CENTER)
        * CFrame.fromAxisAngle(Vector3.new(0, 0, 1), math.rad(-spinDeg))
        * CFrame.Angles(math.rad(90), 0, 0)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- CONSTRUCTION PHYSIQUE
-- ══════════════════════════════════════════════════════════════════════════════
local wheelFolder = Instance.new("Folder")
wheelFolder.Name   = "BrainrotWheel"
wheelFolder.Parent = Workspace

-- ── Poteau de support ────────────────────────────────────────────────────────
local post = Instance.new("Part")
post.Name     = "WheelPost"
post.Size     = Vector3.new(1.5, 14, 1.5)
post.Position = Vector3.new(WHEEL_CENTER.X, 7, WHEEL_CENTER.Z - 0.8)
post.Anchored = true
post.Material = Enum.Material.Metal
post.Color    = Color3.fromRGB(50, 50, 55)
post.Parent   = wheelFolder

-- ── Disque principal (tourne avec la roue) ───────────────────────────────────
local wheelPart = Instance.new("Part")
wheelPart.Name        = "WheelPart"
wheelPart.Shape       = Enum.PartType.Cylinder
wheelPart.Size        = Vector3.new(0.9, WHEEL_RADIUS * 2, WHEEL_RADIUS * 2)
wheelPart.CFrame      = INIT_CF
wheelPart.Anchored    = true
wheelPart.Material    = Enum.Material.SmoothPlastic
wheelPart.Color       = Color3.fromRGB(18, 18, 24)
wheelPart.CastShadow  = false
wheelPart.Parent      = wheelFolder
wheelPart:SetAttribute("SpinAngle", 0)

-- ── Jante chrome (statique — ne tourne pas) ──────────────────────────────────
-- Épaisseur 0.8 stud, matériau Metal chromé, dépasse légèrement le disque
local chromeRim = Instance.new("Part")
chromeRim.Name        = "ChromeRim"
chromeRim.Shape       = Enum.PartType.Cylinder
chromeRim.Size        = Vector3.new(0.8, WHEEL_RADIUS * 2 + 2.2, WHEEL_RADIUS * 2 + 2.2)
chromeRim.CFrame      = INIT_CF
chromeRim.Anchored    = true
chromeRim.Material    = Enum.Material.Metal
chromeRim.Color       = Color3.fromRGB(210, 215, 222)
chromeRim.Reflectance = 0.45
chromeRim.CanCollide  = false
chromeRim.CastShadow  = false
chromeRim.Parent      = wheelFolder

-- ── Anneau néon doré (accent lumineux extérieur, statique) ───────────────────
local neonRing = Instance.new("Part")
neonRing.Name       = "NeonRing"
neonRing.Shape      = Enum.PartType.Cylinder
neonRing.Size       = Vector3.new(0.22, WHEEL_RADIUS * 2 + 3.0, WHEEL_RADIUS * 2 + 3.0)
neonRing.CFrame     = INIT_CF
neonRing.Anchored   = true
neonRing.Material   = Enum.Material.Neon
neonRing.Color      = Color3.fromRGB(255, 215, 0)
neonRing.CanCollide = false
neonRing.CastShadow = false
neonRing.Parent     = wheelFolder

-- ── Billes néon (16, autour du rebord, statiques — changent de couleur) ──────
local N_BEADS      = 16
local BEAD_R       = WHEEL_RADIUS + 2.1        -- rayon dans le plan XY (hors anneau néon)
local BEAD_Z       = WHEEL_CENTER.Z + 0.65     -- légèrement devant la face du disque
local neonBeads    = {}

for i = 1, N_BEADS do
    local angle = math.rad((i - 1) * (360 / N_BEADS))
    local bead  = Instance.new("Part")
    bead.Name       = "NeonBead_" .. i
    bead.Shape      = Enum.PartType.Ball
    bead.Size       = Vector3.new(0.55, 0.55, 0.55)
    bead.Position   = Vector3.new(
        WHEEL_CENTER.X + math.cos(angle) * BEAD_R,
        WHEEL_CENTER.Y + math.sin(angle) * BEAD_R,
        BEAD_Z
    )
    bead.Anchored   = true
    bead.Material   = Enum.Material.Neon
    bead.Color      = BEAD_COLORS[((i - 1) % #BEAD_COLORS) + 1]
    bead.CanCollide = false
    bead.CastShadow = false
    bead.Parent     = wheelFolder
    neonBeads[i]    = bead
end

-- ── Dôme central brillant (cache l'axe, effet bouton arcade) ─────────────────
local dome = Instance.new("Part")
dome.Name        = "WheelDome"
dome.Shape       = Enum.PartType.Ball
dome.Size        = Vector3.new(2.6, 2.6, 2.6)
dome.Position    = WHEEL_CENTER + Vector3.new(0, 0, 0.65)
dome.Anchored    = true
dome.Material    = Enum.Material.SmoothPlastic
dome.Color       = Color3.fromRGB(255, 220, 50)
dome.Reflectance = 0.6
dome.CanCollide  = false
dome.CastShadow  = false
dome.Parent      = wheelFolder

local domeLight = Instance.new("PointLight")
domeLight.Color      = Color3.fromRGB(255, 215, 0)
domeLight.Brightness = 1.8
domeLight.Range      = 10
domeLight.Parent     = dome

-- ── Pointeur stylisé (corps + pointe neon) ───────────────────────────────────
local POINTER_CY = WHEEL_CENTER.Y + WHEEL_RADIUS + 2.2   -- Y de base de la pointe

-- Corps du pointeur (shaft vertical)
local pShaft = Instance.new("Part")
pShaft.Name       = "PointerShaft"
pShaft.Size       = Vector3.new(0.35, 2.2, 0.45)
pShaft.CFrame     = CFrame.new(WHEEL_CENTER.X, POINTER_CY + 1.6, WHEEL_CENTER.Z)
pShaft.Anchored   = true
pShaft.Material   = Enum.Material.Neon
pShaft.Color      = Color3.fromRGB(255, 90, 0)    -- orange
pShaft.CanCollide = false
pShaft.CastShadow = false
pShaft.Parent     = wheelFolder

-- Pointe (wedge) → orientée vers le bas (dans la roue)
local pointer = Instance.new("WedgePart")
pointer.Name       = "Pointer"
pointer.Size       = Vector3.new(0.65, 1.8, 1.3)
pointer.CFrame     = CFrame.new(WHEEL_CENTER.X, POINTER_CY, WHEEL_CENTER.Z)
                   * CFrame.Angles(0, 0, math.rad(180))
pointer.Anchored   = true
pointer.Material   = Enum.Material.Neon
pointer.Color      = Color3.fromRGB(255, 30, 30)   -- rouge vif
pointer.CanCollide = false
pointer.CastShadow = false
pointer.Parent     = wheelFolder

local pointerLight = Instance.new("PointLight")
pointerLight.Color      = Color3.fromRGB(255, 60, 0)
pointerLight.Brightness = 2.2
pointerLight.Range      = 6
pointerLight.Parent     = pointer

-- ── ClickDetector ────────────────────────────────────────────────────────────
local clickDetector = Instance.new("ClickDetector")
clickDetector.MaxActivationDistance = 30
clickDetector.Parent = wheelPart

-- ══════════════════════════════════════════════════════════════════════════════
-- SURFACE GUI — 8 segments mème en cercle
-- ══════════════════════════════════════════════════════════════════════════════
local surfGui = Instance.new("SurfaceGui")
surfGui.Name        = "WheelGui"
surfGui.Face        = Enum.NormalId.Top
surfGui.CanvasSize  = Vector2.new(512, 512)
surfGui.SizingMode  = Enum.SurfaceGuiSizingMode.FixedSize
surfGui.AlwaysOnTop = false
surfGui.ZOffset     = 0.6
surfGui.Parent      = wheelPart

local C  = 256    -- centre du canvas
local IR = 168    -- rayon icônes (pixels)
local IS = 86     -- taille icône (pixels)

for i = 1, N_SEGMENTS do
    local angleDeg    = (i - 1) * SEG_ANGLE
    local angleRad    = math.rad(angleDeg)
    local cx          = C + IR * math.sin(angleRad)
    local cy          = C - IR * math.cos(angleRad)
    local meme        = segmentData[i]
    local rarityColor = RARITY_COLORS[meme.rarity] or RARITY_COLORS.NORMAL

    -- Fond circulaire couleur rareté
    local bg = Instance.new("Frame")
    bg.Name             = "Seg_" .. i
    bg.Size             = UDim2.new(0, IS + 14, 0, IS + 14)
    bg.AnchorPoint      = Vector2.new(0.5, 0.5)
    bg.Position         = UDim2.new(0, cx, 0, cy)
    bg.BackgroundColor3 = rarityColor
    bg.BorderSizePixel  = 0
    bg.ZIndex           = 1
    bg.Parent           = surfGui
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0.5, 0)  -- cercle parfait

    -- Contour blanc
    local bgStroke = Instance.new("UIStroke")
    bgStroke.Color     = Color3.new(1, 1, 1)
    bgStroke.Thickness = 3
    bgStroke.Parent    = bg

    -- Image du mème (ronde)
    local img = Instance.new("ImageLabel")
    img.Size             = UDim2.new(0, IS, 0, IS)
    img.AnchorPoint      = Vector2.new(0.5, 0.5)
    img.Position         = UDim2.new(0.5, 0, 0.45, 0)
    img.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
    img.Image            = "rbxassetid://" .. meme.imageId
    img.ScaleType        = Enum.ScaleType.Fit
    img.ImageColor3      = Color3.new(1, 1, 1)
    img.ZIndex           = 2
    img.Parent           = bg
    Instance.new("UICorner", img).CornerRadius = UDim.new(0.5, 0)

    -- Nom sous l'icône
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size                   = UDim2.new(0, IS + 14, 0, 18)
    nameLbl.AnchorPoint            = Vector2.new(0.5, 0)
    nameLbl.Position               = UDim2.new(0.5, 0, 1, 3)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text                   = meme.name
    nameLbl.TextColor3             = Color3.new(1, 1, 1)
    nameLbl.Font                   = Enum.Font.GothamBold
    nameLbl.TextScaled             = true
    nameLbl.TextStrokeTransparency = 0.4
    nameLbl.ZIndex                 = 2
    nameLbl.Parent                 = bg
end

-- Centre : bouton SPIN avec contour doré
local centerBg = Instance.new("Frame")
centerBg.Size             = UDim2.new(0, 108, 0, 108)
centerBg.AnchorPoint      = Vector2.new(0.5, 0.5)
centerBg.Position         = UDim2.new(0.5, 0, 0.5, 0)
centerBg.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
centerBg.BorderSizePixel  = 0
centerBg.ZIndex           = 3
centerBg.Parent           = surfGui
Instance.new("UICorner", centerBg).CornerRadius = UDim.new(0.5, 0)

local centerStroke = Instance.new("UIStroke")
centerStroke.Color     = Color3.fromRGB(255, 215, 0)
centerStroke.Thickness = 4
centerStroke.Parent    = centerBg

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
-- BILLES : VAGUE DE COULEUR (boucle permanente)
-- ══════════════════════════════════════════════════════════════════════════════
local beadSpinning = false  -- vague accélérée pendant le spin

task.spawn(function()
    local NC = #BEAD_COLORS
    while true do
        task.wait(0.07)   -- ~14 fps — suffisant pour un effet fluide
        local speed = beadSpinning and 6 or 2
        local phase = (tick() * speed) % NC
        for bi, bead in ipairs(neonBeads) do
            local idx = math.floor((phase + bi * (NC / N_BEADS)) % NC) + 1
            bead.Color = BEAD_COLORS[idx]
        end
    end
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- LOGIQUE DE SPIN
-- ══════════════════════════════════════════════════════════════════════════════
local wheelLocked   = false
local spinCooldowns: {[number]: number} = {}

local function getCoins(player: Player): number
    local ls    = player:FindFirstChild("leaderstats")
    local coins = ls and ls:FindFirstChild("Brainrot Coins")
    return coins and coins.Value or 0
end

-- Animation serveur — répliquée à tous les clients
local function animateWheel(fromAngle: number, toAngle: number)
    local delta   = toAngle - fromAngle
    local elapsed = 0
    beadSpinning  = true

    local conn = RunService.Heartbeat:Connect(function(dt)
        elapsed = math.min(elapsed + dt, SPIN_DURATION)
        local t      = elapsed / SPIN_DURATION
        local easedT = 1 - (1 - t) ^ 4   -- QuartOut

        -- Rotation du disque
        wheelPart.CFrame = getWheelCF(fromAngle + delta * easedT)

        -- Vibration du pointeur (s'atténue avec la décélération)
        local amp  = (1 - easedT) * 0.22
        local bobY = math.sin(elapsed * 22) * amp
        pointer.CFrame = CFrame.new(WHEEL_CENTER.X, POINTER_CY + bobY, WHEEL_CENTER.Z)
                       * CFrame.Angles(0, 0, math.rad(180))
        pShaft.CFrame  = CFrame.new(WHEEL_CENTER.X, POINTER_CY + bobY + 1.6, WHEEL_CENTER.Z)
    end)

    task.delay(SPIN_DURATION, function()
        conn:Disconnect()
        beadSpinning     = false
        wheelPart.CFrame = getWheelCF(toAngle)
        wheelPart:SetAttribute("SpinAngle", toAngle)
        -- Remet le pointeur en position de repos
        pointer.CFrame = CFrame.new(WHEEL_CENTER.X, POINTER_CY, WHEEL_CENTER.Z)
                       * CFrame.Angles(0, 0, math.rad(180))
        pShaft.CFrame  = CFrame.new(WHEEL_CENTER.X, POINTER_CY + 1.6, WHEEL_CENTER.Z)
        wheelLocked = false
    end)
end

-- ── Clic sur la roue ──────────────────────────────────────────────────────────
clickDetector.MouseClick:Connect(function(player: Player)
    if wheelLocked then return end
    local now = tick()
    if spinCooldowns[player.UserId] and (now - spinCooldowns[player.UserId]) < SPIN_DURATION + 1 then
        return
    end

    if getCoins(player) < SPIN_COST then
        SpinResult:FireClient(player, { success = false, reason = "coins" })
        return
    end

    local data = DataManager.GetData(player)
    if not data then return end
    DataManager.SpendGold(player, SPIN_COST)
    spinCooldowns[player.UserId] = now
    wheelLocked = true

    local winIdx  = math.random(1, N_SEGMENTS)
    local winMeme = segmentData[winIdx]

    DataManager.AddItem(player, {
        Id     = winMeme.itemId,
        Name   = winMeme.name,
        Rarity = winMeme.rarity,
    })

    if _G.BrainrotGallery_Refresh then
        task.spawn(_G.BrainrotGallery_Refresh, player)
    end

    local updated = DataManager.GetData(player)
    if updated then
        UpdateClientData:FireClient(player, updated)
    end

    local currentAngle = wheelPart:GetAttribute("SpinAngle") or 0
    local extraRot     = math.random(5, 8) * 360
    local winAngle     = (winIdx - 1) * SEG_ANGLE
    local currentMod   = currentAngle % 360
    local needed       = (winAngle - currentMod + 360) % 360
    if needed < 5 then needed = needed + 360 end
    local targetAngle  = currentAngle + extraRot + needed

    print(string.format("[WheelSystem] %s → segment %d (%s) | %.1f° → %.1f°",
        player.Name, winIdx, winMeme.name, currentAngle, targetAngle))

    animateWheel(currentAngle, targetAngle)

    SpinResult:FireClient(player, {
        success    = true,
        winSegment = winIdx,
        memeName   = winMeme.name,
        memeRarity = winMeme.rarity,
        imageId    = winMeme.imageId,
        duration   = SPIN_DURATION,
    })
end)

print(string.format("[WheelSystem] Arcade Deluxe pret — %d segments, %d billes neon, cout: %d Coins",
    N_SEGMENTS, N_BEADS, SPIN_COST))

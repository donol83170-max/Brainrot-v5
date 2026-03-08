--!strict
-- WheelSystem.server.lua — 12 SEGMENTS · POOL SYSTEM · v4 PIVOT CHIRURGICAL
--
-- RÈGLE DE PHYSIQUE (critique) :
--   SEUL le Pivot est Anchored = true.
--   WheelDisk : Anchored = false + WeldConstraint → suit le Pivot.
--   Toutes les pièces statiques (jante, billes, dôme) : Anchored = true, NON soudées.
--
-- ROTATION CASINO (deux phases) :
--   Phase 1 — Spin rapide (constante)  : RunService.Heartbeat, N tours complets.
--   Phase 2 — Décélération (QuartOut)  : TweenService sur NumberValue → Heartbeat.
--   Résultat : départ rapide → ralentissement réaliste → arrêt précis sur le segment.
--
-- AXEL DU CYLINDRE ROBLOX = X  (Size.X = épaisseur du disque)
--   ORIGINAL_CFRAME = CFrame.Angles(0, -90°, 0)  → local +X pointe vers world -Z (joueur) ✓
--   Spin    = CFrame.Angles(deg, 0, 0)   → rotation autour de local X = axe du disque ✓
--   SurfaceGui Face = NormalId.Right → face plate circulaire visible par le joueur ✓

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
local N_SEGMENTS       = 12
local SEG_ANGLE        = 360 / N_SEGMENTS   -- 30° par segment
local SPIN_COST        = 20
local FULL_ROTATIONS   = 5     -- tours complets en phase 1
local PHASE1_DURATION  = 3.5   -- secondes — spin rapide constant
local PHASE2_DURATION  = 2.0   -- secondes — TweenService QuartOut (décélération)
local SPIN_DURATION    = PHASE1_DURATION + PHASE2_DURATION   -- 5.5 s au total
-- ── Position & taille ────────────────────────────────────────────────────────
-- Fontaine centrale à X=0, Z=0 (WorldAssets). Spawn à Z=110 regardant Z=142 (nord).
-- Galeries nord : joueurs à Z>142 regardent vers -Z (sud) → voient la fontaine (Z=0)
--   → roue à Z=-20 (20 studs derrière la fontaine, au sud) ✓
-- Face du disque vers +Z (NORD) = face aux joueurs dans leurs galeries et sur l'avenue.
local WHEEL_CENTER     = Vector3.new(0, 18, -38)
local WHEEL_RADIUS     = 10   -- agrandi pour la visibilité depuis les galeries

local RARITY_COLORS = {
    COMMON    = Color3.fromRGB(160, 162, 168),
    RARE      = Color3.fromRGB(  0, 130, 255),
    EPIC      = Color3.fromRGB(155,   0, 255),
    LEGENDARY = Color3.fromRGB(255, 190,   0),
}

-- ══════════════════════════════════════════════════════════════════════════════
-- POOLS DE RARETÉ
-- ══════════════════════════════════════════════════════════════════════════════
local POOL = {
    COMMON = {
        { itemId = "SkibidiHead",     imageId = 15263881432, name = "Skibidi Toilet"       },
        { itemId = "NoobiniPizza",    imageId = 0,           name = "Noobini Pizzanini"    },
        { itemId = "PipiCorni",       imageId = 0,           name = "Pipi Corni"           },
        { itemId = "MaxwellCat",      imageId = 12501659970, name = "Maxwell Cat"          },
    },
    RARE = {
        { itemId = "Tralalero",       imageId = 0,           name = "Tralalero Tralala"    },
        { itemId = "DogeMeme",        imageId = 0,           name = "Doge"                 },
    },
    EPIC = {
        { itemId = "BrBrPatapim",     imageId = 0,           name = "Br Br Patapim"        },
        { itemId = "CappuccinoAss",   imageId = 0,           name = "Cappuccino Assassino" },
    },
    LEGENDARY = {
        { itemId = "StrawberryEleph", imageId = 0,           name = "Strawberry Elephant"  },
        { itemId = "DragonCannell",   imageId = 0,           name = "Dragon Cannelloni"    },
    },
}

local RARITY_WEIGHTS = {
    { rarity = "COMMON",    weight = 60 },
    { rarity = "RARE",      weight = 25 },
    { rarity = "EPIC",      weight = 12 },
    { rarity = "LEGENDARY", weight = 3  },
}

local SEGMENTS = {
    { rarity = "COMMON",    item = POOL.COMMON[1]    },  --  1
    { rarity = "COMMON",    item = POOL.COMMON[4]    },  --  2
    { rarity = "RARE",      item = POOL.RARE[1]      },  --  3
    { rarity = "COMMON",    item = POOL.COMMON[2]    },  --  4
    { rarity = "COMMON",    item = POOL.COMMON[3]    },  --  5
    { rarity = "LEGENDARY", item = POOL.LEGENDARY[1] },  --  6
    { rarity = "COMMON",    item = POOL.COMMON[4]    },  --  7
    { rarity = "RARE",      item = POOL.RARE[2]      },  --  8
    { rarity = "COMMON",    item = POOL.COMMON[1]    },  --  9
    { rarity = "EPIC",      item = POOL.EPIC[1]      },  -- 10
    { rarity = "COMMON",    item = POOL.COMMON[3]    },  -- 11
    { rarity = "RARE",      item = POOL.RARE[1]      },  -- 12
}

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
-- CFRAME HELPERS
-- ORIGINAL_CFRAME = point d'ancrage fixe de toutes les rotations.
-- CFrame.Angles(0, +90°, 0) → local +X pointe vers world +Z (nord, vers joueurs) ✓
-- Spin = CFrame.Angles(deg, 0, 0) → rotation autour de local X = axe du disque ✓
-- ══════════════════════════════════════════════════════════════════════════════
local ORIGINAL_CFRAME = CFrame.new(WHEEL_CENTER) * CFrame.Angles(0, math.rad(-90), 0)

-- Retourne le CFrame du Pivot pour un angle de spin donné (en degrés, cumulatif).
-- Toutes les rotations TweenService sont relatives à ORIGINAL_CFRAME.
local function getPivotCF(deg: number): CFrame
    return ORIGINAL_CFRAME * CFrame.Angles(math.rad(deg), 0, 0)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- CONSTRUCTION PHYSIQUE
-- ══════════════════════════════════════════════════════════════════════════════
local wheelFolder       = Instance.new("Folder")
wheelFolder.Name        = "BrainrotWheel"
wheelFolder.Parent      = Workspace

-- ── Socle bas (face avant 100% dégagée — pas de poteau devant le disque) ──────
-- Un socle plat au sol + un bras arrière caché derrière le disque.
local pedestal      = Instance.new("Part")
pedestal.Name       = "WheelBase"
pedestal.Size       = Vector3.new(7, 2, 7)
pedestal.Position   = Vector3.new(WHEEL_CENTER.X, 1, WHEEL_CENTER.Z)
pedestal.Anchored   = true; pedestal.Material = Enum.Material.Metal
pedestal.Color      = Color3.fromRGB(38, 38, 44); pedestal.CastShadow = false
pedestal.Parent     = wheelFolder

-- Bras de liaison vertical (côté dos = +Z local = derrière le disque, invisible de face)
local ARM_H         = WHEEL_CENTER.Y - 2
local arm           = Instance.new("Part")
arm.Name            = "WheelArm"
arm.Size            = Vector3.new(1.4, ARM_H, 1.4)
arm.Position        = Vector3.new(WHEEL_CENTER.X, 2 + ARM_H / 2, WHEEL_CENTER.Z + 1.2)
arm.Anchored        = true; arm.Material = Enum.Material.Metal
arm.Color           = Color3.fromRGB(38, 38, 44); arm.CastShadow = false
arm.Parent          = wheelFolder

-- ── PIVOT (invisible, seul à être ancré, reçoit toutes les rotations) ─────────
local pivot         = Instance.new("Part")
pivot.Name          = "Pivot"
pivot.Shape         = Enum.PartType.Cylinder
pivot.Size          = Vector3.new(0.3, WHEEL_RADIUS * 2, WHEEL_RADIUS * 2)
pivot.CFrame        = ORIGINAL_CFRAME
pivot.Anchored      = true   -- SEUL ANCRÉ ✓
pivot.Transparency  = 1
pivot.CanCollide    = false
pivot.CastShadow    = false
pivot.Parent        = wheelFolder
pivot:SetAttribute("SpinAngle", 0)

-- ── WheelDisk (visuel, NON ancré, soudé au Pivot) ─────────────────────────────
local wheelDisk     = Instance.new("Part")
wheelDisk.Name      = "WheelDisk"
wheelDisk.Shape     = Enum.PartType.Cylinder
wheelDisk.Size      = Vector3.new(0.82, WHEEL_RADIUS * 2, WHEEL_RADIUS * 2)
wheelDisk.CFrame    = ORIGINAL_CFRAME
wheelDisk.Anchored  = false  -- NON ancré ✓ (suit le Pivot via WeldConstraint)
wheelDisk.CanCollide  = false
wheelDisk.CastShadow  = false
wheelDisk.Material    = Enum.Material.SmoothPlastic
wheelDisk.Color       = Color3.fromRGB(18, 18, 24)
wheelDisk.Parent      = wheelFolder

local diskWeld      = Instance.new("WeldConstraint")
diskWeld.Part0      = pivot      -- base = Pivot (ancré)
diskWeld.Part1      = wheelDisk  -- suit le Pivot
diskWeld.Parent     = pivot

-- ── Jante chrome (STATIQUE, non soudée) ──────────────────────────────────────
local chromeRim     = Instance.new("Part")
chromeRim.Shape     = Enum.PartType.Cylinder
chromeRim.Size      = Vector3.new(0.7, WHEEL_RADIUS * 2 + 2.2, WHEEL_RADIUS * 2 + 2.2)
chromeRim.CFrame    = ORIGINAL_CFRAME
chromeRim.Anchored  = true   -- STATIQUE ✓
chromeRim.Material  = Enum.Material.Metal
chromeRim.Color     = Color3.fromRGB(210, 215, 222); chromeRim.Reflectance = 0.45
chromeRim.CanCollide = false; chromeRim.CastShadow = false
chromeRim.Parent    = wheelFolder

-- ── Anneau néon doré (STATIQUE) ───────────────────────────────────────────────
local neonRing      = Instance.new("Part")
neonRing.Shape      = Enum.PartType.Cylinder
neonRing.Size       = Vector3.new(0.22, WHEEL_RADIUS * 2 + 3.2, WHEEL_RADIUS * 2 + 3.2)
neonRing.CFrame     = ORIGINAL_CFRAME
neonRing.Anchored   = true   -- STATIQUE ✓
neonRing.Material   = Enum.Material.Neon
neonRing.Color      = Color3.fromRGB(255, 215, 0)
neonRing.CanCollide = false; neonRing.CastShadow = false
neonRing.Parent     = wheelFolder

-- ── 16 Billes néon (STATIQUES) ────────────────────────────────────────────────
local BEAD_PALETTE = {
    Color3.fromRGB(255,  40,  40), Color3.fromRGB(255, 140,   0),
    Color3.fromRGB(255, 245,   0), Color3.fromRGB( 60, 255,  80),
    Color3.fromRGB(  0, 170, 255), Color3.fromRGB(170,   0, 255),
    Color3.fromRGB(255,   0, 180), Color3.fromRGB(255, 255, 255),
}
local N_BEADS  = 16
local BEAD_R   = WHEEL_RADIUS + 2.1
local BEAD_Z   = WHEEL_CENTER.Z + 0.5   -- côté joueur = +Z (nord)
local neonBeads = {}

for i = 1, N_BEADS do
    local a    = math.rad((i - 1) * (360 / N_BEADS))
    local bead = Instance.new("Part")
    bead.Shape      = Enum.PartType.Ball; bead.Size = Vector3.new(0.55, 0.55, 0.55)
    bead.Position   = Vector3.new(
        WHEEL_CENTER.X + math.cos(a) * BEAD_R,
        WHEEL_CENTER.Y + math.sin(a) * BEAD_R,
        BEAD_Z)
    bead.Anchored   = true   -- STATIQUE ✓
    bead.Material   = Enum.Material.Neon
    bead.Color      = BEAD_PALETTE[((i - 1) % #BEAD_PALETTE) + 1]
    bead.CanCollide = false; bead.CastShadow = false
    bead.Parent     = wheelFolder
    neonBeads[i]    = bead
end

-- ── Dôme central (STATIQUE — ClickDetector ici, visible et cliquable) ─────────
local dome          = Instance.new("Part")
dome.Name           = "Dome"
dome.Shape          = Enum.PartType.Ball; dome.Size = Vector3.new(2.6, 2.6, 2.6)
dome.Position       = WHEEL_CENTER + Vector3.new(0, 0, 0.7)   -- côté joueur = +Z
dome.Anchored       = true   -- STATIQUE ✓
dome.Material       = Enum.Material.SmoothPlastic
dome.Color          = Color3.fromRGB(255, 220, 50); dome.Reflectance = 0.6
dome.CanCollide     = false; dome.CastShadow = false
dome.Parent         = wheelFolder

-- Lumière omnidirectionnelle (nuit) — portée suffisante pour éclairer toute la roue
local domeLight         = Instance.new("PointLight")
domeLight.Color         = Color3.fromRGB(255, 215, 0)
domeLight.Brightness    = 5; domeLight.Range = 30; domeLight.Parent = dome

-- SpotLight principal vers le NORD (+Z) : éclaire les joueurs dans les galeries (Z>0)
-- Dome sans rotation → NormalId.Back = local +Z = world +Z (nord, vers joueurs) ✓
local spotMain          = Instance.new("SpotLight")
spotMain.Color          = Color3.fromRGB(255, 240, 200)
spotMain.Brightness     = 7; spotMain.Range = 80; spotMain.Angle = 60
spotMain.Face           = Enum.NormalId.Back
spotMain.Parent         = dome

-- SpotLight secondaire vers le SUD (-Z) : contre-éclairage depuis l'arrière
local spotBack          = Instance.new("SpotLight")
spotBack.Color          = Color3.fromRGB(200, 220, 255)
spotBack.Brightness     = 3; spotBack.Range = 40; spotBack.Angle = 45
spotBack.Face           = Enum.NormalId.Front   -- -Z (sud, arrière de la roue)
spotBack.Parent         = dome

-- ── Pointeur (STATIQUE) ────────────────────────────────────────────────────────
local POINTER_CY = WHEEL_CENTER.Y + WHEEL_RADIUS + 2.2
local PTR_Z      = WHEEL_CENTER.Z + 0.5   -- côté joueur = +Z (nord)

local pShaft        = Instance.new("Part")
pShaft.Size         = Vector3.new(0.35, 2.2, 0.45)
pShaft.CFrame       = CFrame.new(WHEEL_CENTER.X, POINTER_CY + 1.6, PTR_Z)
pShaft.Anchored     = true   -- STATIQUE ✓
pShaft.Material     = Enum.Material.Neon
pShaft.Color        = Color3.fromRGB(255, 90, 0)
pShaft.CanCollide   = false; pShaft.CastShadow = false; pShaft.Parent = wheelFolder

local pointer       = Instance.new("WedgePart")
pointer.Size        = Vector3.new(0.65, 1.8, 1.3)
pointer.CFrame      = CFrame.new(WHEEL_CENTER.X, POINTER_CY, PTR_Z)
                   * CFrame.Angles(0, 0, math.rad(180))
pointer.Anchored    = true   -- STATIQUE ✓
pointer.Material    = Enum.Material.Neon
pointer.Color       = Color3.fromRGB(255, 30, 30)
pointer.CanCollide  = false; pointer.CastShadow = false; pointer.Parent = wheelFolder

local pointerLight        = Instance.new("PointLight")
pointerLight.Color        = Color3.fromRGB(255, 60, 0)
pointerLight.Brightness   = 2.5; pointerLight.Range = 7; pointerLight.Parent = pointer

-- ── ClickDetector sur le Dôme (visible, or, cliquable) ────────────────────────
local clickDetector = Instance.new("ClickDetector")
clickDetector.MaxActivationDistance = 40   -- agrandi avec le rayon de la roue
clickDetector.Parent = dome

-- ══════════════════════════════════════════════════════════════════════════════
-- SONS
-- ══════════════════════════════════════════════════════════════════════════════
local soundPart         = Instance.new("Part")
soundPart.Size          = Vector3.new(0.1, 0.1, 0.1)
soundPart.Position      = WHEEL_CENTER
soundPart.Anchored      = true; soundPart.Transparency = 1; soundPart.CanCollide = false
soundPart.Parent        = wheelFolder

local tickSound         = Instance.new("Sound")
tickSound.SoundId       = "rbxassetid://6026984224"
tickSound.Volume        = 0.35; tickSound.RollOffMaxDistance = 35; tickSound.Parent = soundPart

local winSound          = Instance.new("Sound")
winSound.SoundId        = "rbxassetid://5153734135"
winSound.Volume         = 0.9;  winSound.RollOffMaxDistance = 50;  winSound.Parent = soundPart

local fanfareSound      = Instance.new("Sound")
fanfareSound.SoundId    = "rbxassetid://3205426741"
fanfareSound.Volume     = 1.0;  fanfareSound.RollOffMaxDistance = 60; fanfareSound.Parent = soundPart

-- ══════════════════════════════════════════════════════════════════════════════
-- SURFACE GUI (sur WheelDisk — tourne avec le Pivot)
-- Face = NormalId.Right → face plate du cylindre orientée vers le joueur ✓
-- ══════════════════════════════════════════════════════════════════════════════
local surfGui           = Instance.new("SurfaceGui")
surfGui.Name            = "WheelGui"
surfGui.Face            = Enum.NormalId.Right
surfGui.CanvasSize      = Vector2.new(512, 512)
surfGui.SizingMode      = Enum.SurfaceGuiSizingMode.FixedSize
surfGui.AlwaysOnTop     = false
surfGui.ZOffset         = 0.5
surfGui.Parent          = wheelDisk

local C  = 256   -- centre du canvas (512×512)

-- Fond
local bgFull            = Instance.new("Frame")
bgFull.Size             = UDim2.new(1, 0, 1, 0)
bgFull.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
bgFull.BorderSizePixel  = 0; bgFull.ZIndex = 1; bgFull.Parent = surfGui

-- 12 Secteurs colorés (rectangle ancré au centre, rotation par angle de segment)
local SH = 244
local SW = math.ceil(2 * SH * math.tan(math.rad(15)))  -- ≈ 131 px

for i = 1, N_SEGMENTS do
    local seg             = SEGMENTS[i]
    local midAngle        = (i - 1) * SEG_ANGLE
    local sec             = Instance.new("Frame")
    sec.Size              = UDim2.new(0, SW, 0, SH)
    sec.AnchorPoint       = Vector2.new(0.5, 1)
    sec.Position          = UDim2.new(0, C, 0, C)
    sec.BackgroundColor3  = RARITY_COLORS[seg.rarity]
    sec.BorderSizePixel   = 0; sec.Rotation = midAngle; sec.ZIndex = 2
    sec.Parent            = surfGui
end

-- Lignes séparatrices blanches
for i = 1, N_SEGMENTS do
    local lineAngle       = (i - 1) * SEG_ANGLE - SEG_ANGLE / 2
    local line            = Instance.new("Frame")
    line.Size             = UDim2.new(0, 3, 0, SH + 10)
    line.AnchorPoint      = Vector2.new(0.5, 1)
    line.Position         = UDim2.new(0, C, 0, C)
    line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    line.BorderSizePixel  = 0; line.Rotation = lineAngle; line.ZIndex = 3
    line.Parent           = surfGui
end

-- Icônes mèmes
local IR = 158; local IS = 70

for i = 1, N_SEGMENTS do
    local seg    = SEGMENTS[i]
    local aRad   = math.rad((i - 1) * SEG_ANGLE)
    local cx     = C + IR * math.sin(aRad)
    local cy     = C - IR * math.cos(aRad)
    local isLeg  = seg.rarity == "LEGENDARY"
    local isEpic = seg.rarity == "EPIC"

    local badge             = Instance.new("Frame")
    badge.Size              = UDim2.new(0, IS + 14, 0, IS + 14)
    badge.AnchorPoint       = Vector2.new(0.5, 0.5)
    badge.Position          = UDim2.new(0, cx, 0, cy)
    badge.BackgroundColor3  = Color3.fromRGB(10, 10, 16)
    badge.BorderSizePixel   = 0; badge.ZIndex = 4; badge.Parent = surfGui
    Instance.new("UICorner", badge).CornerRadius = UDim.new(0.5, 0)

    local stroke            = Instance.new("UIStroke")
    stroke.Color            = isLeg  and Color3.fromRGB(255, 215,   0) or
                              isEpic and Color3.fromRGB(200, 100, 255) or
                                         Color3.fromRGB(220, 220, 220)
    stroke.Thickness        = isLeg and 4 or 2; stroke.Parent = badge

    local img               = Instance.new("ImageLabel")
    img.Size                = UDim2.new(0, IS, 0, IS)
    img.AnchorPoint         = Vector2.new(0.5, 0.5)
    img.Position            = UDim2.new(0.5, 0, 0.44, 0)
    img.BackgroundColor3    = Color3.fromRGB(12, 12, 16)
    img.Image               = seg.item.imageId ~= 0 and ("rbxassetid://" .. seg.item.imageId) or ""
    img.ScaleType           = Enum.ScaleType.Fit; img.ZIndex = 5; img.Parent = badge
    Instance.new("UICorner", img).CornerRadius = UDim.new(0.5, 0)

    local lbl               = Instance.new("TextLabel")
    lbl.Size                = UDim2.new(0, IS + 14, 0, 15)
    lbl.AnchorPoint         = Vector2.new(0.5, 0)
    lbl.Position            = UDim2.new(0.5, 0, 1, 2)
    lbl.BackgroundTransparency = 1
    lbl.Text                = seg.item.name
    lbl.TextColor3          = Color3.new(1, 1, 1); lbl.Font = Enum.Font.GothamBold
    lbl.TextScaled          = true; lbl.TextStrokeTransparency = 0.4
    lbl.ZIndex              = 5; lbl.Parent = badge
end

-- Bouton SPIN central
local centerBg              = Instance.new("Frame")
centerBg.Size               = UDim2.new(0, 96, 0, 96)
centerBg.AnchorPoint        = Vector2.new(0.5, 0.5)
centerBg.Position           = UDim2.new(0.5, 0, 0.5, 0)
centerBg.BackgroundColor3   = Color3.fromRGB(14, 14, 20)
centerBg.BorderSizePixel    = 0; centerBg.ZIndex = 6; centerBg.Parent = surfGui
Instance.new("UICorner", centerBg).CornerRadius = UDim.new(0.5, 0)
local cs = Instance.new("UIStroke")
cs.Color = Color3.fromRGB(255, 215, 0); cs.Thickness = 4; cs.Parent = centerBg
local centerLbl             = Instance.new("TextLabel")
centerLbl.Size              = UDim2.new(1, 0, 1, 0)
centerLbl.BackgroundTransparency = 1
centerLbl.Text              = "SPIN\n" .. SPIN_COST .. " G"
centerLbl.TextColor3        = Color3.fromRGB(255, 230, 0); centerLbl.Font = Enum.Font.GothamBlack
centerLbl.TextScaled        = true; centerLbl.ZIndex = 7; centerLbl.Parent = centerBg

-- ══════════════════════════════════════════════════════════════════════════════
-- BILLES : VAGUE DE COULEURS
-- ══════════════════════════════════════════════════════════════════════════════
local beadSpinning = false
task.spawn(function()
    local NP = #BEAD_PALETTE
    while true do
        task.wait(0.07)
        local spd   = beadSpinning and 6 or 2
        local phase = (tick() * spd) % NP
        for bi, bead in ipairs(neonBeads) do
            bead.Color = BEAD_PALETTE[math.floor((phase + bi * (NP / N_BEADS)) % NP) + 1]
        end
    end
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- LOGIQUE
-- ══════════════════════════════════════════════════════════════════════════════
local wheelLocked: boolean              = false
local spinCooldowns: {[number]: number} = {}

local function getCoins(player: Player): number
    local ls    = player:FindFirstChild("leaderstats")
    local coins = ls and ls:FindFirstChild("Brainrot Coins")
    return coins and coins.Value or 0
end

-- ── Helpers : tick sonore & vibration pointeur ────────────────────────────────
local lastSegTick = -1

local function applyAngle(angle: number)
    pivot.CFrame = getPivotCF(angle)
    local seg = math.floor((angle % 360) / SEG_ANGLE) % N_SEGMENTS
    if seg ~= lastSegTick then
        lastSegTick = seg
        tickSound:Play()
    end
end

local function resetPointer()
    pointer.CFrame = CFrame.new(WHEEL_CENTER.X, POINTER_CY, PTR_Z)
                   * CFrame.Angles(0, 0, math.rad(180))
    pShaft.CFrame  = CFrame.new(WHEEL_CENTER.X, POINTER_CY + 1.6, PTR_Z)
end

-- ── ANIMATION (deux phases) ───────────────────────────────────────────────────
--
-- Phase 1 : Spin rapide constant (Heartbeat manuel, FULL_ROTATIONS tours)
-- Phase 2 : TweenService QuartOut sur NumberValue → décélération vers le segment
--
local function animateWheel(fromDeg: number, finalDeg: number, winRarity: string)
    beadSpinning = true
    lastSegTick  = -1

    -- ── Phase 1 : rotation constante ─────────────────────────────────────────
    local phase1Start      = tick()
    local phase1TotalDelta = FULL_ROTATIONS * 360  -- degrés parcourus en phase 1
    local phase1EndDeg     = fromDeg + phase1TotalDelta

    local conn1 = RunService.Heartbeat:Connect(function()
        local t = math.min((tick() - phase1Start) / PHASE1_DURATION, 1)
        applyAngle(fromDeg + t * phase1TotalDelta)
    end)

    -- ── Phase 2 : TweenService QuartOut ──────────────────────────────────────
    task.delay(PHASE1_DURATION, function()
        conn1:Disconnect()

        local numVal    = Instance.new("NumberValue")
        numVal.Value    = phase1EndDeg

        local tween = TweenService:Create(
            numVal,
            TweenInfo.new(PHASE2_DURATION, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            { Value = finalDeg }
        )

        local phase2Start = tick()
        local conn2 = RunService.Heartbeat:Connect(function()
            applyAngle(numVal.Value)

            -- Vibration pointeur (s'atténue avec la décélération)
            local elapsed  = tick() - phase2Start
            local progress = math.min(elapsed / PHASE2_DURATION, 1)
            local bobY     = math.sin(elapsed * 20) * (1 - progress) * 0.24
            pointer.CFrame = CFrame.new(WHEEL_CENTER.X, POINTER_CY + bobY, PTR_Z)
                           * CFrame.Angles(0, 0, math.rad(180))
            pShaft.CFrame  = CFrame.new(WHEEL_CENTER.X, POINTER_CY + bobY + 1.6, PTR_Z)
        end)

        tween.Completed:Connect(function()
            conn2:Disconnect()
            numVal:Destroy()
            beadSpinning = false

            pivot.CFrame = getPivotCF(finalDeg)
            pivot:SetAttribute("SpinAngle", finalDeg)
            resetPointer()

            if winRarity == "LEGENDARY" or winRarity == "EPIC" then
                fanfareSound:Play()
                if winRarity == "LEGENDARY" then
                    local sp        = Instance.new("Sparkles")
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
    end)
end

-- ── Gestion du clic (sur le Dôme doré) ────────────────────────────────────────
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

    -- Tirage pondéré
    local winRarity    = pickRarity()
    local winItem      = pickItem(winRarity)
    local segsOfRarity = SEGS_BY_RARITY[winRarity]
    local winSegIdx    = segsOfRarity[math.random(1, #segsOfRarity)]

    -- Calcul de l'angle final (après les 5 tours de phase 1)
    local currentAngle = pivot:GetAttribute("SpinAngle") or 0
    local phase1End    = currentAngle + FULL_ROTATIONS * 360
    local winAngle     = (winSegIdx - 1) * SEG_ANGLE
    local phase1Mod    = phase1End % 360
    local needed       = (winAngle - phase1Mod + 360) % 360
    if needed < 5 then needed = needed + 360 end
    local finalDeg     = phase1End + needed

    -- Inventaire + galerie
    DataManager.AddItem(player, { Id = winItem.itemId, Name = winItem.name, Rarity = winRarity })
    if _G.BrainrotGallery_Refresh then
        task.spawn(_G.BrainrotGallery_Refresh, player)
    end
    local updated = DataManager.GetData(player)
    if updated then UpdateClientData:FireClient(player, updated) end

    print(string.format("[WheelSystem] %s → %s '%s' | seg%d | %.1f°→%.1f°",
        player.Name, winRarity, winItem.name, winSegIdx, currentAngle, finalDeg))

    SpinResult:FireClient(player, {
        success    = true,
        winSegment = winSegIdx,
        memeName   = winItem.name,
        memeRarity = winRarity,
        imageId    = winItem.imageId,
        duration   = SPIN_DURATION,
    })

    animateWheel(currentAngle, finalDeg, winRarity)
end)

print(string.format(
    "[WheelSystem] v5 PIVOT pret | pos (0,18,-20) derriere fontaine | face +Z nord | phase1=%.1fs + phase2=%.1fs QuartOut | COMMON %d%% RARE %d%% EPIC %d%% LEG %d%%",
    PHASE1_DURATION, PHASE2_DURATION,
    RARITY_WEIGHTS[1].weight, RARITY_WEIGHTS[2].weight,
    RARITY_WEIGHTS[3].weight, RARITY_WEIGHTS[4].weight))

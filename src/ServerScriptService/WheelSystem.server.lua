--!strict
-- WheelSystem.server.lua — 12 SEGMENTS · POOL SYSTEM · v3 PIVOT
--
-- DIAGNOSTIC ROTATION (cylindre Roblox) :
--   PartType.Cylinder : axe de HAUTEUR = X (Size.X = épaisseur du disque)
--   Faces plates circulaires = NormalId.Right (+X local) et NormalId.Left (-X local)
--
-- ORIENTATION CHOISIE :
--   CFrame.Angles(0, -90°, 0)  → local +X pointe vers world -Z (vers le joueur) ✓
--   SurfaceGui Face = NormalId.Right  → sur la face plate visible ✓
--
-- SPIN CORRECT (pas de balancement) :
--   Pivoter autour de l'axe du cylindre = pivoter autour de local X
--   → pivot.CFrame * CFrame.Angles(delta, 0, 0)  ← rotation disque de casino ✓

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
    COMMON    = Color3.fromRGB(160, 162, 168),   -- gris métal
    RARE      = Color3.fromRGB(  0, 130, 255),   -- bleu néon
    EPIC      = Color3.fromRGB(155,   0, 255),   -- violet néon
    LEGENDARY = Color3.fromRGB(255, 190,   0),   -- doré jackpot
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

-- ══════════════════════════════════════════════════════════════════════════════
-- DISPOSITION DES 12 SEGMENTS (visuels sur le disque)
-- ══════════════════════════════════════════════════════════════════════════════
local SEGMENTS = {
    { rarity = "COMMON",    item = POOL.COMMON[1]    },  --  1  Skibidi Toilet
    { rarity = "COMMON",    item = POOL.COMMON[4]    },  --  2  Maxwell Cat
    { rarity = "RARE",      item = POOL.RARE[1]      },  --  3  Tralalero ✦
    { rarity = "COMMON",    item = POOL.COMMON[2]    },  --  4  Noobini Pizzanini
    { rarity = "COMMON",    item = POOL.COMMON[3]    },  --  5  Pipi Corni
    { rarity = "LEGENDARY", item = POOL.LEGENDARY[1] },  --  6  Strawberry Elephant ★★
    { rarity = "COMMON",    item = POOL.COMMON[4]    },  --  7  Maxwell Cat
    { rarity = "RARE",      item = POOL.RARE[2]      },  --  8  Doge ✦
    { rarity = "COMMON",    item = POOL.COMMON[1]    },  --  9  Skibidi Toilet
    { rarity = "EPIC",      item = POOL.EPIC[1]      },  -- 10  Br Br Patapim ★
    { rarity = "COMMON",    item = POOL.COMMON[3]    },  -- 11  Pipi Corni
    { rarity = "RARE",      item = POOL.RARE[1]      },  -- 12  Tralalero ✦
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
-- BASE_CF : cylindre couché, face plate (+X local) vers le joueur (world -Z)
-- spinCF  : tourne autour de local X = axe du disque = world -Z (spin de casino)
-- ══════════════════════════════════════════════════════════════════════════════
local BASE_CF = CFrame.new(WHEEL_CENTER) * CFrame.Angles(0, math.rad(-90), 0)

local function getPivotCF(deg: number): CFrame
    -- 1. Base orientation (face vers joueur)
    -- 2. Rotation autour de l'axe X local (= spin disque de casino)
    return CFrame.new(WHEEL_CENTER)
        * CFrame.Angles(0, math.rad(-90), 0)
        * CFrame.Angles(math.rad(deg), 0, 0)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- CONSTRUCTION PHYSIQUE
-- ══════════════════════════════════════════════════════════════════════════════
local wheelFolder = Instance.new("Folder")
wheelFolder.Name   = "BrainrotWheel"
wheelFolder.Parent = Workspace

-- ── Poteau ────────────────────────────────────────────────────────────────────
local post = Instance.new("Part")
post.Name     = "WheelPost"; post.Size = Vector3.new(1.5, 14, 1.5)
post.Position = Vector3.new(WHEEL_CENTER.X, 7, WHEEL_CENTER.Z + 0.9)
post.Anchored = true; post.Material = Enum.Material.Metal
post.Color    = Color3.fromRGB(45, 45, 50); post.Parent = wheelFolder

-- ── PIVOT (invisible, ancré, tourne seul) ────────────────────────────────────
local pivot = Instance.new("Part")
pivot.Name         = "Pivot"
pivot.Shape        = Enum.PartType.Cylinder
pivot.Size         = Vector3.new(0.3, WHEEL_RADIUS * 2, WHEEL_RADIUS * 2)
pivot.CFrame       = BASE_CF
pivot.Anchored     = true
pivot.Transparency = 1
pivot.CanCollide   = false
pivot.CastShadow   = false
pivot.Parent       = wheelFolder
pivot:SetAttribute("SpinAngle", 0)

-- ── Disque visuel (soudé au Pivot, tourne avec lui) ──────────────────────────
local wheelDisk = Instance.new("Part")
wheelDisk.Name       = "WheelDisk"
wheelDisk.Shape      = Enum.PartType.Cylinder
wheelDisk.Size       = Vector3.new(0.82, WHEEL_RADIUS * 2, WHEEL_RADIUS * 2)
wheelDisk.CFrame     = BASE_CF
wheelDisk.Anchored   = false
wheelDisk.CanCollide = false
wheelDisk.CastShadow = false
wheelDisk.Material   = Enum.Material.SmoothPlastic
wheelDisk.Color      = Color3.fromRGB(18, 18, 24)
wheelDisk.Parent     = wheelFolder

local weld       = Instance.new("WeldConstraint")
weld.Part0       = pivot
weld.Part1       = wheelDisk
weld.Parent      = pivot

-- ── Jante chrome (statique) ───────────────────────────────────────────────────
local chromeRim = Instance.new("Part")
chromeRim.Shape       = Enum.PartType.Cylinder
chromeRim.Size        = Vector3.new(0.7, WHEEL_RADIUS * 2 + 2.2, WHEEL_RADIUS * 2 + 2.2)
chromeRim.CFrame      = BASE_CF; chromeRim.Anchored = true
chromeRim.Material    = Enum.Material.Metal
chromeRim.Color       = Color3.fromRGB(210, 215, 222); chromeRim.Reflectance = 0.45
chromeRim.CanCollide  = false; chromeRim.CastShadow = false; chromeRim.Parent = wheelFolder

-- ── Anneau néon doré (bordure lumineuse, statique) ───────────────────────────
local neonRing = Instance.new("Part")
neonRing.Shape      = Enum.PartType.Cylinder
neonRing.Size       = Vector3.new(0.22, WHEEL_RADIUS * 2 + 3.2, WHEEL_RADIUS * 2 + 3.2)
neonRing.CFrame     = BASE_CF; neonRing.Anchored = true
neonRing.Material   = Enum.Material.Neon
neonRing.Color      = Color3.fromRGB(255, 215, 0)
neonRing.CanCollide = false; neonRing.CastShadow = false; neonRing.Parent = wheelFolder

-- ── 16 Billes néon arc-en-ciel (statiques, dans le plan XY) ──────────────────
local BEAD_PALETTE = {
    Color3.fromRGB(255,  40,  40), Color3.fromRGB(255, 140,   0),
    Color3.fromRGB(255, 245,   0), Color3.fromRGB( 60, 255,  80),
    Color3.fromRGB(  0, 170, 255), Color3.fromRGB(170,   0, 255),
    Color3.fromRGB(255,   0, 180), Color3.fromRGB(255, 255, 255),
}
local N_BEADS  = 16
local BEAD_R   = WHEEL_RADIUS + 2.1
-- Z légèrement devant le disque (côté joueur = Z < 55)
local BEAD_Z   = WHEEL_CENTER.Z - 0.5
local neonBeads = {}

for i = 1, N_BEADS do
    local a    = math.rad((i - 1) * (360 / N_BEADS))
    local bead = Instance.new("Part")
    bead.Shape = Enum.PartType.Ball; bead.Size = Vector3.new(0.55, 0.55, 0.55)
    bead.Position = Vector3.new(
        WHEEL_CENTER.X + math.cos(a) * BEAD_R,
        WHEEL_CENTER.Y + math.sin(a) * BEAD_R,
        BEAD_Z)
    bead.Anchored   = true; bead.Material = Enum.Material.Neon
    bead.Color      = BEAD_PALETTE[((i - 1) % #BEAD_PALETTE) + 1]
    bead.CanCollide = false; bead.CastShadow = false; bead.Parent = wheelFolder
    neonBeads[i]    = bead
end

-- ── Dôme central brillant (statique, devant le disque) ───────────────────────
local dome = Instance.new("Part")
dome.Shape    = Enum.PartType.Ball; dome.Size = Vector3.new(2.6, 2.6, 2.6)
-- devant la face du disque (côté joueur)
dome.Position = WHEEL_CENTER + Vector3.new(0, 0, -0.7)
dome.Anchored = true; dome.Material = Enum.Material.SmoothPlastic
dome.Color    = Color3.fromRGB(255, 220, 50); dome.Reflectance = 0.6
dome.CanCollide = false; dome.CastShadow = false; dome.Parent = wheelFolder

local domeLight = Instance.new("PointLight")
domeLight.Color      = Color3.fromRGB(255, 215, 0)
domeLight.Brightness = 2.0; domeLight.Range = 12; domeLight.Parent = dome

-- ── Pointeur stylisé : shaft orange + pointe rouge (statique) ────────────────
local POINTER_CY = WHEEL_CENTER.Y + WHEEL_RADIUS + 2.2
local PTR_Z      = WHEEL_CENTER.Z - 0.5   -- devant le disque (côté joueur)

local pShaft = Instance.new("Part")
pShaft.Size   = Vector3.new(0.35, 2.2, 0.45)
pShaft.CFrame = CFrame.new(WHEEL_CENTER.X, POINTER_CY + 1.6, PTR_Z)
pShaft.Anchored = true; pShaft.Material = Enum.Material.Neon
pShaft.Color    = Color3.fromRGB(255, 90, 0)
pShaft.CanCollide = false; pShaft.CastShadow = false; pShaft.Parent = wheelFolder

local pointer = Instance.new("WedgePart")
pointer.Size   = Vector3.new(0.65, 1.8, 1.3)
pointer.CFrame = CFrame.new(WHEEL_CENTER.X, POINTER_CY, PTR_Z)
             * CFrame.Angles(0, 0, math.rad(180))
pointer.Anchored = true; pointer.Material = Enum.Material.Neon
pointer.Color    = Color3.fromRGB(255, 30, 30)
pointer.CanCollide = false; pointer.CastShadow = false; pointer.Parent = wheelFolder

local pointerLight = Instance.new("PointLight")
pointerLight.Color      = Color3.fromRGB(255, 60, 0)
pointerLight.Brightness = 2.5; pointerLight.Range = 7; pointerLight.Parent = pointer

-- ── ClickDetector sur le Pivot ────────────────────────────────────────────────
local clickDetector = Instance.new("ClickDetector")
clickDetector.MaxActivationDistance = 30
clickDetector.Parent = pivot

-- ══════════════════════════════════════════════════════════════════════════════
-- SONS
-- ══════════════════════════════════════════════════════════════════════════════
local soundPart = Instance.new("Part")
soundPart.Size        = Vector3.new(0.1, 0.1, 0.1)
soundPart.Position    = WHEEL_CENTER
soundPart.Anchored    = true; soundPart.Transparency = 1; soundPart.CanCollide = false
soundPart.Parent      = wheelFolder

local tickSound = Instance.new("Sound")
tickSound.SoundId            = "rbxassetid://6026984224"
tickSound.Volume             = 0.35; tickSound.RollOffMaxDistance = 35
tickSound.Parent             = soundPart

local winSound = Instance.new("Sound")
winSound.SoundId             = "rbxassetid://5153734135"
winSound.Volume              = 0.9;  winSound.RollOffMaxDistance = 50
winSound.Parent              = soundPart

local fanfareSound = Instance.new("Sound")
fanfareSound.SoundId         = "rbxassetid://3205426741"
fanfareSound.Volume          = 1.0;  fanfareSound.RollOffMaxDistance = 60
fanfareSound.Parent          = soundPart

-- ══════════════════════════════════════════════════════════════════════════════
-- SURFACE GUI — Face plate (NormalId.Right) → regarde le joueur
-- Canvas 512×512, centre (256, 256)
-- Secteurs colorés + icônes mèmes + bouton SPIN
-- ══════════════════════════════════════════════════════════════════════════════
local surfGui = Instance.new("SurfaceGui")
surfGui.Name        = "WheelGui"
surfGui.Face        = Enum.NormalId.Right   -- face plate côté joueur ✓
surfGui.CanvasSize  = Vector2.new(512, 512)
surfGui.SizingMode  = Enum.SurfaceGuiSizingMode.FixedSize
surfGui.AlwaysOnTop = false
surfGui.ZOffset     = 0.5
surfGui.Parent      = wheelDisk   -- soudé au Pivot, tourne avec lui

local CANVAS = 512
local C      = 256   -- centre du canvas

-- Fond noir de base
local bgFull = Instance.new("Frame")
bgFull.Size                = UDim2.new(1, 0, 1, 0)
bgFull.BackgroundColor3    = Color3.fromRGB(10, 10, 14)
bgFull.BorderSizePixel     = 0
bgFull.ZIndex              = 1
bgFull.Parent              = surfGui

-- ── Secteurs colorés (30° chacun, rectangle rotatif depuis le centre) ─────────
-- Hauteur = du centre jusqu'au bord : 244px
-- Largeur  = 2 × hauteur × tan(15°) ≈ 131px (couvre exactement 30°)
local SH = 244   -- sector height
local SW = math.ceil(2 * SH * math.tan(math.rad(15)))   -- ≈ 131

for i = 1, N_SEGMENTS do
    local seg      = SEGMENTS[i]
    local midAngle = (i - 1) * SEG_ANGLE     -- angle du milieu du secteur
    local rarColor = RARITY_COLORS[seg.rarity]

    local sec           = Instance.new("Frame")
    sec.Size            = UDim2.new(0, SW, 0, SH)
    sec.AnchorPoint     = Vector2.new(0.5, 1)     -- pivot en bas au centre
    sec.Position        = UDim2.new(0, C, 0, C)  -- depuis le centre du canvas
    sec.BackgroundColor3 = rarColor
    sec.BorderSizePixel = 0
    sec.Rotation        = midAngle
    sec.ZIndex          = 2
    sec.Parent          = surfGui
end

-- ── Lignes de séparation blanches (1 par segment, 3px) ────────────────────────
for i = 1, N_SEGMENTS do
    local lineAngle = (i - 1) * SEG_ANGLE - SEG_ANGLE / 2

    local line           = Instance.new("Frame")
    line.Size            = UDim2.new(0, 3, 0, SH + 10)
    line.AnchorPoint     = Vector2.new(0.5, 1)
    line.Position        = UDim2.new(0, C, 0, C)
    line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    line.BorderSizePixel = 0
    line.Rotation        = lineAngle
    line.ZIndex          = 3
    line.Parent          = surfGui
end

-- ── Icônes des mèmes (cercles sur chaque segment) ─────────────────────────────
local IR = 158   -- rayon où placer le centre des icônes
local IS = 70    -- taille de l'icône

for i = 1, N_SEGMENTS do
    local seg      = SEGMENTS[i]
    local aRad     = math.rad((i - 1) * SEG_ANGLE)
    local cx       = C + IR * math.sin(aRad)
    local cy       = C - IR * math.cos(aRad)
    local isLeg    = seg.rarity == "LEGENDARY"
    local isEpic   = seg.rarity == "EPIC"

    -- Fond du badge (cercle sombre)
    local badge           = Instance.new("Frame")
    badge.Size            = UDim2.new(0, IS + 14, 0, IS + 14)
    badge.AnchorPoint     = Vector2.new(0.5, 0.5)
    badge.Position        = UDim2.new(0, cx, 0, cy)
    badge.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
    badge.BorderSizePixel = 0
    badge.ZIndex          = 4
    badge.Parent          = surfGui
    Instance.new("UICorner", badge).CornerRadius = UDim.new(0.5, 0)

    -- Contour de rareté
    local stroke       = Instance.new("UIStroke")
    stroke.Color       = isLeg  and Color3.fromRGB(255, 215,   0) or
                         isEpic and Color3.fromRGB(200, 100, 255) or
                                    Color3.fromRGB(220, 220, 220)
    stroke.Thickness   = isLeg and 4 or 2
    stroke.Parent      = badge

    -- Image du mème
    local img           = Instance.new("ImageLabel")
    img.Size            = UDim2.new(0, IS, 0, IS)
    img.AnchorPoint     = Vector2.new(0.5, 0.5)
    img.Position        = UDim2.new(0.5, 0, 0.44, 0)
    img.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
    img.Image           = seg.item.imageId ~= 0 and ("rbxassetid://" .. seg.item.imageId) or ""
    img.ScaleType       = Enum.ScaleType.Fit
    img.ZIndex          = 5
    img.Parent          = badge
    Instance.new("UICorner", img).CornerRadius = UDim.new(0.5, 0)

    -- Nom court sous l'icône
    local lbl               = Instance.new("TextLabel")
    lbl.Size                = UDim2.new(0, IS + 14, 0, 15)
    lbl.AnchorPoint         = Vector2.new(0.5, 0)
    lbl.Position            = UDim2.new(0.5, 0, 1, 2)
    lbl.BackgroundTransparency = 1
    lbl.Text                = seg.item.name
    lbl.TextColor3          = Color3.new(1, 1, 1)
    lbl.Font                = Enum.Font.GothamBold
    lbl.TextScaled          = true
    lbl.TextStrokeTransparency = 0.4
    lbl.ZIndex              = 5
    lbl.Parent              = badge
end

-- ── Centre : bouton SPIN ───────────────────────────────────────────────────────
local centerBg           = Instance.new("Frame")
centerBg.Size            = UDim2.new(0, 96, 0, 96)
centerBg.AnchorPoint     = Vector2.new(0.5, 0.5)
centerBg.Position        = UDim2.new(0.5, 0, 0.5, 0)
centerBg.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
centerBg.BorderSizePixel = 0
centerBg.ZIndex          = 6
centerBg.Parent          = surfGui
Instance.new("UICorner", centerBg).CornerRadius = UDim.new(0.5, 0)

local cs           = Instance.new("UIStroke")
cs.Color           = Color3.fromRGB(255, 215, 0); cs.Thickness = 4; cs.Parent = centerBg

local centerLbl            = Instance.new("TextLabel")
centerLbl.Size             = UDim2.new(1, 0, 1, 0)
centerLbl.BackgroundTransparency = 1
centerLbl.Text             = "SPIN\n" .. SPIN_COST .. " G"
centerLbl.TextColor3       = Color3.fromRGB(255, 230, 0)
centerLbl.Font             = Enum.Font.GothamBlack
centerLbl.TextScaled       = true
centerLbl.ZIndex           = 7
centerLbl.Parent           = centerBg

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
            local idx  = math.floor((phase + bi * (NP / N_BEADS)) % NP) + 1
            bead.Color = BEAD_PALETTE[idx]
        end
    end
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- LOGIQUE
-- ══════════════════════════════════════════════════════════════════════════════
local wheelLocked: boolean             = false
local spinCooldowns: {[number]: number} = {}

local function getCoins(player: Player): number
    local ls    = player:FindFirstChild("leaderstats")
    local coins = ls and ls:FindFirstChild("Brainrot Coins")
    return coins and coins.Value or 0
end

-- ── Animation : TweenService sur un NumberValue → Heartbeat applique le CFrame ─
-- TweenService ne peut pas faire plusieurs tours sur un CFrame (SLERP = chemin court).
-- Solution : tweener un NumberValue (degrés) et écrire pivot.CFrame chaque frame.
local function animateWheel(fromAngle: number, targetAngle: number, winRarity: string)
    local numVal = Instance.new("NumberValue")
    numVal.Value = fromAngle
    beadSpinning = true

    local tween = TweenService:Create(
        numVal,
        TweenInfo.new(SPIN_DURATION, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        { Value = targetAngle }
    )

    local lastSeg = -1
    local startT  = tick()

    -- Heartbeat : applique l'angle au Pivot + tick sonore + vibration pointeur
    local conn = RunService.Heartbeat:Connect(function()
        local angle = numVal.Value
        pivot.CFrame = getPivotCF(angle)

        -- Tick sonore à chaque changement de segment
        local seg = math.floor((angle % 360) / SEG_ANGLE) % N_SEGMENTS
        if seg ~= lastSeg then
            lastSeg = seg
            tickSound:Play()
        end

        -- Vibration du pointeur (atténuée avec la décélération)
        local elapsed  = tick() - startT
        local progress = math.min(elapsed / SPIN_DURATION, 1)
        local bobY     = math.sin(elapsed * 22) * (1 - progress) * 0.22
        pointer.CFrame = CFrame.new(WHEEL_CENTER.X, POINTER_CY + bobY, PTR_Z)
                       * CFrame.Angles(0, 0, math.rad(180))
        pShaft.CFrame  = CFrame.new(WHEEL_CENTER.X, POINTER_CY + bobY + 1.6, PTR_Z)
    end)

    -- Fin de l'animation
    tween.Completed:Connect(function()
        conn:Disconnect()
        numVal:Destroy()
        beadSpinning = false

        pivot.CFrame = getPivotCF(targetAngle)
        pivot:SetAttribute("SpinAngle", targetAngle)

        -- Remet le pointeur en position de repos
        pointer.CFrame = CFrame.new(WHEEL_CENTER.X, POINTER_CY, PTR_Z)
                       * CFrame.Angles(0, 0, math.rad(180))
        pShaft.CFrame  = CFrame.new(WHEEL_CENTER.X, POINTER_CY + 1.6, PTR_Z)

        -- Sons de victoire
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
end

-- ── Gestion du clic ───────────────────────────────────────────────────────────
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

    -- Calcul de l'angle cible
    local currentAngle = pivot:GetAttribute("SpinAngle") or 0
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

    -- Notifier le client (WheelClient attend data.duration avant d'afficher le résultat)
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
    "[WheelSystem] v3 PIVOT pret — COMMON %d%% | RARE %d%% | EPIC %d%% | LEGENDARY %d%%",
    RARITY_WEIGHTS[1].weight, RARITY_WEIGHTS[2].weight,
    RARITY_WEIGHTS[3].weight, RARITY_WEIGHTS[4].weight))

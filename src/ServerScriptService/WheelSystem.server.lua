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
--   ORIGINAL_CFRAME = CFrame.Angles(0, 180°, 0)  → local +X pointe vers world -X (fontaine) ✓
--   Spin    = CFrame.Angles(deg, 0, 0)   → rotation autour de local X = axe du disque ✓
--   SurfaceGui Face = NormalId.Right → face plate circulaire visible depuis la fontaine ✓

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
-- Fontaine centrale à X=0, Z=0 (WorldAssets). Roue reculée loin de la fontaine.
-- WHEEL_CENTER.X = +40 (40 studs à droite → large espace de circulation devant).
-- Z=0 → centrée sur l'allée centrale. Face du disque vers -X (fontaine) ✓
local WHEEL_CENTER     = Vector3.new(40, 18, 0)
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
-- CFrame.Angles(0, 180°, 0) → local +X pointe vers world -X (vers fontaine) ✓
-- Spin = CFrame.Angles(deg, 0, 0) → rotation autour de local X = axe du disque ✓
-- ══════════════════════════════════════════════════════════════════════════════
local ORIGINAL_CFRAME = CFrame.new(WHEEL_CENTER) * CFrame.Angles(0, math.rad(180), 0)

-- Retourne le CFrame du Pivot pour un angle de spin donné (en degrés, cumulatif).
-- Toutes les rotations TweenService sont relatives à ORIGINAL_CFRAME.
local function getPivotCF(deg: number): CFrame
    return ORIGINAL_CFRAME * CFrame.Angles(math.rad(deg), 0, 0)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- CONSTRUCTION PHYSIQUE
-- ══════════════════════════════════════════════════════════════════════════════
-- Nettoyage Total (Destruction de l'ancienne roue pour forcer la v5 physique)
local oldWheel = Workspace:FindFirstChild("BrainrotWheel")
if oldWheel then
    oldWheel:Destroy()
end

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
pedestal.Color      = Color3.fromRGB(180, 180, 180); pedestal.CastShadow = false
pedestal.Parent     = wheelFolder

-- Bras de liaison vertical (côté dos = +Z local = derrière le disque, invisible de face)
local ARM_H         = WHEEL_CENTER.Y - 2
local arm           = Instance.new("Part")
arm.Name            = "WheelArm"
arm.Size            = Vector3.new(1.4, ARM_H, 1.4)
arm.Position        = Vector3.new(WHEEL_CENTER.X + 1.2, 2 + ARM_H / 2, WHEEL_CENTER.Z)
arm.Anchored        = true; arm.Material = Enum.Material.Metal
arm.Color           = Color3.fromRGB(180, 180, 180); arm.CastShadow = false
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
wheelDisk.Size      = Vector3.new(0.82, WHEEL_RADIUS * 2 + 0.2, WHEEL_RADIUS * 2 + 0.2) -- slightly larger
wheelDisk.CFrame    = ORIGINAL_CFRAME
wheelDisk.Anchored     = false  -- NON ancré ✓ (suit le Pivot via WeldConstraint)
wheelDisk.CanCollide   = false
wheelDisk.CastShadow   = false
wheelDisk.Material     = Enum.Material.SmoothPlastic
wheelDisk.Color        = Color3.fromRGB(12, 12, 18) -- Dark rim
wheelDisk.Transparency = 0      -- visible : fond cylindrique parfait
wheelDisk.Parent       = wheelFolder

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
local BEAD_X   = WHEEL_CENTER.X - 0.5   -- côté fontaine = -X
local neonBeads = {}

for i = 1, N_BEADS do
    local a    = math.rad((i - 1) * (360 / N_BEADS))
    local bead = Instance.new("Part")
    bead.Shape      = Enum.PartType.Ball; bead.Size = Vector3.new(0.55, 0.55, 0.55)
    bead.Position   = Vector3.new(
        BEAD_X,
        WHEEL_CENTER.Y + math.sin(a) * BEAD_R,
        WHEEL_CENTER.Z + math.cos(a) * BEAD_R)
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
dome.Position       = WHEEL_CENTER + Vector3.new(-0.7, 0, 0)   -- côté fontaine = -X
dome.Anchored       = true   -- STATIQUE ✓
dome.Material       = Enum.Material.SmoothPlastic
dome.Color          = Color3.fromRGB(255, 220, 50); dome.Reflectance = 0.6
dome.CanCollide     = false; dome.CastShadow = false
dome.Parent         = wheelFolder

-- Lumière omnidirectionnelle (nuit) — portée suffisante pour éclairer toute la roue
local domeLight         = Instance.new("PointLight")
domeLight.Color         = Color3.fromRGB(255, 215, 0)
domeLight.Brightness    = 5; domeLight.Range = 30; domeLight.Parent = dome

-- SpotLight principal vers la FONTAINE (-X) : éclaire la roue depuis la fontaine ✓
-- Dome sans rotation → NormalId.Left = local -X = world -X (vers fontaine) ✓
local spotMain          = Instance.new("SpotLight")
spotMain.Color          = Color3.fromRGB(255, 240, 200)
spotMain.Brightness     = 7; spotMain.Range = 80; spotMain.Angle = 60
spotMain.Face           = Enum.NormalId.Left
spotMain.Parent         = dome

-- SpotLight secondaire opposé (+X) : contre-éclairage depuis l'arrière
local spotBack          = Instance.new("SpotLight")
spotBack.Color          = Color3.fromRGB(200, 220, 255)
spotBack.Brightness     = 3; spotBack.Range = 40; spotBack.Angle = 45
spotBack.Face           = Enum.NormalId.Right   -- +X (arrière de la roue)
spotBack.Parent         = dome

-- ── Pointeur (STATIQUE) ────────────────────────────────────────────────────────
local POINTER_CY = WHEEL_CENTER.Y + WHEEL_RADIUS + 2.2
local PTR_X      = WHEEL_CENTER.X - 0.5   -- côté fontaine = -X

local pShaft        = Instance.new("Part")
pShaft.Size         = Vector3.new(0.45, 2.2, 0.35)
pShaft.CFrame       = CFrame.new(PTR_X, POINTER_CY + 1.6, WHEEL_CENTER.Z)
pShaft.Anchored     = true   -- STATIQUE ✓
pShaft.Material     = Enum.Material.Neon
pShaft.Color        = Color3.fromRGB(255, 90, 0)
pShaft.CanCollide   = false; pShaft.CastShadow = false; pShaft.Parent = wheelFolder

local pointer       = Instance.new("WedgePart")
pointer.Size        = Vector3.new(1.3, 1.8, 0.65)
pointer.CFrame      = CFrame.new(PTR_X, POINTER_CY, WHEEL_CENTER.Z)
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
-- DISQUE PHYSIQUE : 12 Parts radiales colorées + séparateurs néon + hub central
-- Chaque Part est soudée au Pivot → tourne avec lui automatiquement.
-- Pas de SurfaceGui global (= carré noir visible) : chaque segment a le sien.
-- ══════════════════════════════════════════════════════════════════════════════
local SEG_T = 0.95                                                    -- épaisseur axiale
local SEG_L = WHEEL_RADIUS                                            -- longueur radiale
local SEG_W = 2 * WHEEL_RADIUS * math.sin(math.rad(SEG_ANGLE / 2))   -- largeur chord ≈ 5.18

for i = 1, N_SEGMENTS do
    local segData  = SEGMENTS[i]
    local midRad   = math.rad((i - 1) * SEG_ANGLE)

    -- ── GEOMÉTRIE : Une slice 30° = 2 WedgeParts (15° chacun) en miroir
    -- Size: X=épaisseur, Y=rayon, Z=largeur (rayon * tan(15°))
    local WEDGE_Z = WHEEL_RADIUS * math.tan(math.rad(SEG_ANGLE / 2))
    local wSize   = Vector3.new(SEG_T, WHEEL_RADIUS, WEDGE_Z)
    local col     = RARITY_COLORS[segData.rarity]

    local sliceCF = ORIGINAL_CFRAME * CFrame.Angles(midRad, 0, 0)

    -- Moitié Droite (WedgePart)
    local wRight          = Instance.new("WedgePart")
    wRight.Name           = "SegRight" .. i
    wRight.Size           = wSize
    -- 90° corner de WedgePart est en bas/arrière. On la place au centre exact.
    wRight.CFrame         = sliceCF * CFrame.new(0, WHEEL_RADIUS / 2, -wSize.Z / 2)
    wRight.Color          = col
    wRight.Material       = Enum.Material.Neon   -- Couleurs vives exigées
    wRight.Anchored       = false; wRight.CanCollide = false; wRight.CastShadow = false
    wRight.Parent         = wheelFolder
    local swR = Instance.new("WeldConstraint"); swR.Part0 = pivot; swR.Part1 = wRight; swR.Parent = pivot

    -- Moitié Gauche (WedgePart miroir : rotation 180° autour de Y local pour flipper Z)
    local wLeft           = Instance.new("WedgePart")
    wLeft.Name            = "SegLeft" .. i
    wLeft.Size            = wSize
    wLeft.CFrame          = sliceCF * CFrame.Angles(0, math.rad(180), 0) * CFrame.new(0, WHEEL_RADIUS / 2, -wSize.Z / 2)
    wLeft.Color           = col
    wLeft.Material        = Enum.Material.Neon
    wLeft.Anchored        = false; wLeft.CanCollide = false; wLeft.CastShadow = false
    wLeft.Parent          = wheelFolder
    local swL = Instance.new("WeldConstraint"); swL.Part0 = pivot; swL.Part1 = wLeft; swL.Parent = pivot

    -- ── SurfaceGui texte sur la face fontaine (NormalId.Right du Cylinder/Wedge) ────────────
    -- On crée une Part Bloc invisible très fine à l'avant pour porter le UI (sinon le Wedge casse le SurfaceGui)
    local uiPart          = Instance.new("Part")
    uiPart.Name           = "UiPart" .. i
    uiPart.Size           = Vector3.new(0.05, WHEEL_RADIUS, 2 * WEDGE_Z)
    uiPart.CFrame         = sliceCF * CFrame.new(SEG_T / 2 + 0.02, WHEEL_RADIUS / 2, 0)
    uiPart.Transparency   = 1
    uiPart.Anchored       = false; uiPart.CanCollide = false; uiPart.CastShadow = false
    uiPart.Parent         = wheelFolder
    local swUI = Instance.new("WeldConstraint"); swUI.Part0 = pivot; swUI.Part1 = uiPart; swUI.Parent = pivot

    local sg            = Instance.new("SurfaceGui")
    sg.Name             = "SegGui" .. i
    sg.Face             = Enum.NormalId.Right
    sg.CanvasSize       = Vector2.new(256, 512)
    sg.SizingMode       = Enum.SurfaceGuiSizingMode.FixedSize
    sg.AlwaysOnTop      = false
    sg.ZOffset          = 0.1
    sg.Parent           = uiPart

    -- ── Séparateur néon blanc (bord de segment) ────────────────────────────
    local sepRad = math.rad((i - 1) * SEG_ANGLE - SEG_ANGLE / 2)
    local sepCF  = ORIGINAL_CFRAME
        * CFrame.Angles(sepRad, 0, 0)
        * CFrame.new(0, SEG_L / 2, 0)

    local sep           = Instance.new("Part")
    sep.Name            = "Sep" .. i
    sep.Size            = Vector3.new(SEG_T + 0.05, SEG_L + 0.05, 0.1)
    sep.CFrame          = sepCF
    sep.Color           = Color3.fromRGB(255, 255, 255)
    sep.Material        = Enum.Material.Neon
    sep.Anchored        = false
    sep.CanCollide      = false
    sep.CastShadow      = false
    sep.Parent          = wheelFolder

    local ssw = Instance.new("WeldConstraint")
    ssw.Part0 = pivot; ssw.Part1 = sep; ssw.Parent = pivot

    -- ── SurfaceGui texte sur la face fontaine (NormalId.Right) ────────────
    local sg            = Instance.new("SurfaceGui")
    sg.Name             = "SegGui" .. i
    sg.Face             = Enum.NormalId.Right
    sg.CanvasSize       = Vector2.new(256, 512)
    sg.SizingMode       = Enum.SurfaceGuiSizingMode.FixedSize
    sg.AlwaysOnTop      = false
    sg.ZOffset          = 0.05
    sg.Parent           = segPart

    local lbl                   = Instance.new("TextLabel")
    lbl.Size                    = UDim2.new(1, -6, 0.55, 0)
    lbl.Position                = UDim2.new(0, 3, 0.05, 0)
    lbl.BackgroundTransparency  = 1
    lbl.Text                    = string.upper(segData.item.name)
    lbl.TextColor3              = Color3.new(1, 1, 1)
    lbl.Font                    = Enum.Font.LuckiestGuy
    lbl.TextScaled              = true
    lbl.TextStrokeTransparency  = 0
    lbl.TextStrokeColor3        = Color3.new(0, 0, 0)
    lbl.ZIndex                  = 2
    lbl.Parent                  = sg

    if segData.rarity == "LEGENDARY" then
        local star                  = Instance.new("TextLabel")
        star.Size                   = UDim2.new(1, 0, 0.22, 0)
        star.Position               = UDim2.new(0, 0, 0.63, 0)
        star.BackgroundTransparency = 1
        star.Text                   = "★ ★ ★"
        star.TextColor3             = Color3.fromRGB(255, 240, 60)
        star.Font                   = Enum.Font.GothamBlack
        star.TextScaled             = true
        star.ZIndex                 = 2
        star.Parent                 = sg
    end
end

-- ── Hub central (Part cylindrique soudée au Pivot) ────────────────────────────
local hubPart           = Instance.new("Part")
hubPart.Name            = "HubCenter"
hubPart.Shape           = Enum.PartType.Cylinder
hubPart.Size            = Vector3.new(SEG_T + 0.1, 3.6, 3.6)
hubPart.CFrame          = ORIGINAL_CFRAME
hubPart.Color           = Color3.fromRGB(180, 180, 180)
hubPart.Material        = Enum.Material.SmoothPlastic
hubPart.Reflectance     = 0.25
hubPart.Anchored        = false
hubPart.CanCollide      = false
hubPart.CastShadow      = false
hubPart.Parent          = wheelFolder

local hw = Instance.new("WeldConstraint")
hw.Part0 = pivot; hw.Part1 = hubPart; hw.Parent = pivot

local hubGui            = Instance.new("SurfaceGui")
hubGui.Face             = Enum.NormalId.Right
hubGui.CanvasSize       = Vector2.new(200, 200)
hubGui.SizingMode       = Enum.SurfaceGuiSizingMode.FixedSize
hubGui.AlwaysOnTop      = false
hubGui.ZOffset          = 0.1
hubGui.Parent           = hubPart

local hubLbl                    = Instance.new("TextLabel")
hubLbl.Size                     = UDim2.new(1, 0, 1, 0)
hubLbl.BackgroundTransparency   = 1
hubLbl.Text                     = "SPIN\n" .. SPIN_COST .. "G"
hubLbl.TextColor3               = Color3.fromRGB(255, 230, 0)
hubLbl.Font                     = Enum.Font.GothamBlack
hubLbl.TextScaled               = true
hubLbl.TextStrokeTransparency   = 0
hubLbl.TextStrokeColor3         = Color3.new(0, 0, 0)
hubLbl.ZIndex                   = 2
hubLbl.Parent                   = hubGui


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
    pointer.CFrame = CFrame.new(PTR_X, POINTER_CY, WHEEL_CENTER.Z)
                   * CFrame.Angles(0, 0, math.rad(180))
    pShaft.CFrame  = CFrame.new(PTR_X, POINTER_CY + 1.6, WHEEL_CENTER.Z)
end

-- ── L'animation 3D a été retirée : le client s'occupe de l'UI 2D ───────────────

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

    -- Calcul de l'angle pour la logique pure (non utilisé en 3D mais transmis au besoin)
    local winAngle = (360 - ((winSegIdx - 1) * SEG_ANGLE)) % 360

    -- Inventaire + galerie
    DataManager.AddItem(player, { Id = winItem.itemId, Name = winItem.name, Rarity = winRarity })
    if _G.BrainrotGallery_Refresh then
        task.spawn(_G.BrainrotGallery_Refresh, player)
    end
    local updated = DataManager.GetData(player)
    if updated then UpdateClientData:FireClient(player, updated) end

    print(string.format("[WheelSystem] %s → %s '%s' | seg%d",
        player.Name, winRarity, winItem.name, winSegIdx))

    SpinResult:FireClient(player, {
        success    = true,
        segments   = SEGMENTS,
        winSegment = winSegIdx,
        memeName   = winItem.name,
        memeRarity = winRarity,
        imageId    = winItem.imageId,
        duration   = SPIN_DURATION,
        rotations  = FULL_ROTATIONS
    })

    -- Déverrouillage après l'animation 2D
    task.delay(SPIN_DURATION + 1, function()
        wheelLocked = false
    end)
end)

print(string.format(
    "[WheelSystem] v5 PIVOT pret | pos (0,18,-20) derriere fontaine | face +Z nord | phase1=%.1fs + phase2=%.1fs QuartOut | COMMON %d%% RARE %d%% EPIC %d%% LEG %d%%",
    PHASE1_DURATION, PHASE2_DURATION,
    RARITY_WEIGHTS[1].weight, RARITY_WEIGHTS[2].weight,
    RARITY_WEIGHTS[3].weight, RARITY_WEIGHTS[4].weight))

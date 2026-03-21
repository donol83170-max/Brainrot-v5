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
local RequestSpin      = Events:FindFirstChild("RequestSpin")
if not RequestSpin then
    RequestSpin = Instance.new("RemoteEvent")
    RequestSpin.Name = "RequestSpin"
    RequestSpin.Parent = Events
end

-- ══════════════════════════════════════════════════════════════════════════════
-- CONFIG
-- ══════════════════════════════════════════════════════════════════════════════
local N_SEGMENTS       = 16
local SEG_ANGLE        = 360 / N_SEGMENTS   -- 22.5° par segment
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
    COMMON    = Color3.fromRGB(  0, 255,   0),  -- VERT (table officielle)
    RARE      = Color3.fromRGB(  0, 130, 255),  -- BLEU
    EPIC      = Color3.fromRGB(255,   0, 255),  -- VIOLET
    LEGENDARY = Color3.fromRGB(255, 215,   0),  -- DORÉ
}

-- ══════════════════════════════════════════════════════════════════════════════
-- POOLS DE RARETÉ
-- ══════════════════════════════════════════════════════════════════════════════
local POOL = {
    -- ── COMMON (60%) — 8 items ────────────────────────────────────────────────
    COMMON = {
        { itemId = "BallerinaCapp",    imageId = 0, name = "Ballerina Cappuccina"      },
        { itemId = "BombardiroCroc",   imageId = 0, name = "Bombardiro Crocodilo"      },
        { itemId = "BombombiniGus",    imageId = 0, name = "Bombombini Gusini"         },
        { itemId = "CappuccinoAss",    imageId = 0, name = "Cappuccino Assassino"      },
        { itemId = "LirilaLarila",     imageId = 0, name = "Lirili Larila"             },
        { itemId = "SixSeven",         imageId = 0, name = "Six Seven"                 },
        { itemId = "Tralalero",        imageId = 0, name = "Tralalero Tralala"         },
        { itemId = "TrippiTroppi",     imageId = 0, name = "Trippi Troppi"             },
    },
    -- ── RARE (25%) — 4 items ─────────────────────────────────────────────────
    RARE = {
        { itemId = "BrBrPatapim",      imageId = 0, name = "Brr Brr Patapim"          },
        { itemId = "GalaxyWOrL",       imageId = 0, name = "Galaxy W Or L"            },
        { itemId = "GoldChimpanzini",  imageId = 0, name = "Gold Chimpanzini Bananini" },
        { itemId = "GoldLosTral",      imageId = 0, name = "Gold Los Tralaleritos"    },
    },
    -- ── EPIC (14%) — 2 items ─────────────────────────────────────────────────
    EPIC = {
        { itemId = "DiamondSixSeven",  imageId = 0, name = "Diamond Six Seven"        },
        { itemId = "DiamondTungSahur", imageId = 0, name = "Diamond Tung Sahur"       },
    },
    -- ── LEGENDARY (1%) — 2 items ─────────────────────────────────────────────
    LEGENDARY = {
        { itemId = "DragonCannell",    imageId = 0, name = "Dragon Cannelloni"        },
        { itemId = "StrawberryEleph",  imageId = 0, name = "Strawberry Elephant"      },
    },
}

local RARITY_WEIGHTS = {
    { rarity = "COMMON",    weight = 60 },
    { rarity = "RARE",      weight = 25 },
    { rarity = "EPIC",      weight = 14 },
    { rarity = "LEGENDARY", weight = 1  },
}

-- 16 segments — distribution visuelle équilibrée sur la roue
-- COMMON×8, RARE×4, EPIC×2, LEGENDARY×2
local SEGMENTS = {
    { rarity = "COMMON",    item = POOL.COMMON[1]    },  --  1 Ballerina Cappuccina
    { rarity = "COMMON",    item = POOL.COMMON[2]    },  --  2 Bombardiro Crocodilo
    { rarity = "RARE",      item = POOL.RARE[1]      },  --  3 Brr Brr Patapim
    { rarity = "COMMON",    item = POOL.COMMON[3]    },  --  4 Bombombini Gusini
    { rarity = "COMMON",    item = POOL.COMMON[4]    },  --  5 Cappuccino Assassino
    { rarity = "LEGENDARY", item = POOL.LEGENDARY[1] },  --  6 Dragon Cannelloni
    { rarity = "COMMON",    item = POOL.COMMON[5]    },  --  7 Lirili Larila
    { rarity = "RARE",      item = POOL.RARE[2]      },  --  8 Galaxy W Or L
    { rarity = "COMMON",    item = POOL.COMMON[6]    },  --  9 Six Seven
    { rarity = "EPIC",      item = POOL.EPIC[1]      },  -- 10 Diamond Six Seven
    { rarity = "COMMON",    item = POOL.COMMON[7]    },  -- 11 Tralalero Tralala
    { rarity = "RARE",      item = POOL.RARE[3]      },  -- 12 Gold Chimpanzini Bananini
    { rarity = "COMMON",    item = POOL.COMMON[8]    },  -- 13 Trippi Troppi
    { rarity = "EPIC",      item = POOL.EPIC[2]      },  -- 14 Diamond Tung Sahur
    { rarity = "LEGENDARY", item = POOL.LEGENDARY[2] },  -- 15 Strawberry Elephant
    { rarity = "RARE",      item = POOL.RARE[4]      },  -- 16 Gold Los Tralaleritos
}

local SEGS_BY_RARITY: {[string]: {number}} = { COMMON={}, RARE={}, EPIC={}, LEGENDARY={} }
assert(#SEGMENTS == N_SEGMENTS, "SEGMENTS count mismatch")
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

-- ── Borne de Casino (Slot Machine) ────────────────────────────────────────────────
local MACHINE_X = WHEEL_CENTER.X
local MACHINE_Z = WHEEL_CENTER.Z
local SCALE = 1.05 -- Agrandissement de 5%

-- Socle rectangulaire principal (Métal Gris -> Peinture Rouge)
local machineBase       = Instance.new("Part")
machineBase.Name        = "MachineBase"
machineBase.Size        = Vector3.new(6 * SCALE, 12 * SCALE, 8 * SCALE) 
machineBase.Position    = Vector3.new(MACHINE_X, 6 * SCALE, MACHINE_Z)
machineBase.Anchored    = true
machineBase.Material    = Enum.Material.SmoothPlastic
machineBase.Color       = Color3.fromRGB(200, 0, 0)
machineBase.Parent      = wheelFolder

-- Dégradé de Rouge "High Quality Paint" avec SurfaceGuis
local function applyGradientToFace(part, face)
    local sg = Instance.new("SurfaceGui")
    sg.Face = face
    sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    sg.PixelsPerStud = 50
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = part
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    frame.BorderSizePixel = 0
    frame.Parent = sg
    
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 0, 0)),   -- Rouge profond
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 25, 25))  -- Rouge écarlate brillant
    })
    grad.Rotation = -90 -- Bas vers le haut
    grad.Parent = frame
end
applyGradientToFace(machineBase, Enum.NormalId.Left)   -- Face avant (-X local est Left)
applyGradientToFace(machineBase, Enum.NormalId.Right)  -- Dos
applyGradientToFace(machineBase, Enum.NormalId.Front)  -- Côté
applyGradientToFace(machineBase, Enum.NormalId.Back)   -- Côté

-- Lumières Néon sur les bords (Or brillant fixe)
local neonLeft = Instance.new("Part")
neonLeft.Name = "NeonLeft"
neonLeft.Size = Vector3.new(6.1 * SCALE, 12.2 * SCALE, 0.4 * SCALE)
neonLeft.Position = Vector3.new(MACHINE_X, 6 * SCALE, MACHINE_Z - 3.8 * SCALE)
neonLeft.Anchored = true; neonLeft.Material = Enum.Material.Neon
neonLeft.Color = Color3.fromRGB(255, 215, 0); neonLeft.Parent = wheelFolder

local neonRight = Instance.new("Part")
neonRight.Name = "NeonRight"
neonRight.Size = Vector3.new(6.1 * SCALE, 12.2 * SCALE, 0.4 * SCALE)
neonRight.Position = Vector3.new(MACHINE_X, 6 * SCALE, MACHINE_Z + 3.8 * SCALE)
neonRight.Anchored = true; neonRight.Material = Enum.Material.Neon
neonRight.Color = Color3.fromRGB(255, 215, 0); neonRight.Parent = wheelFolder

-- Cadre doré de l'écran
local screenBorder = Instance.new("Part")
screenBorder.Name = "ScreenBorder"
screenBorder.Size = Vector3.new(0.6 * SCALE, 6.4 * SCALE, 7.4 * SCALE)
screenBorder.CFrame = CFrame.new(MACHINE_X - 3.05 * SCALE, 9 * SCALE, MACHINE_Z) * CFrame.Angles(0, 0, math.rad(-15))
screenBorder.Anchored = true
screenBorder.Material = Enum.Material.Metal
screenBorder.Color = Color3.fromRGB(255, 215, 0)
screenBorder.Parent = wheelFolder

-- Écran incliné noir
local screenPart        = Instance.new("Part")
screenPart.Name         = "ScreenPart"
screenPart.Size         = Vector3.new(0.65 * SCALE, 6 * SCALE, 7 * SCALE)
screenPart.CFrame       = CFrame.new(MACHINE_X - 3.1 * SCALE, 9 * SCALE, MACHINE_Z) * CFrame.Angles(0, 0, math.rad(-15))
screenPart.Anchored     = true
screenPart.Material     = Enum.Material.SmoothPlastic
screenPart.Color        = Color3.fromRGB(15, 15, 15)
screenPart.Parent       = wheelFolder

-- SurfaceGui sur l'écran (Face = Left)
local screenGui         = Instance.new("SurfaceGui")
screenGui.Face          = Enum.NormalId.Left
screenGui.CanvasSize    = Vector2.new(800 * SCALE, 600 * SCALE)
screenGui.Parent        = screenPart

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, 0, 1, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "SPIN TO WIN\nBRAINROT"
titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
titleText.Font = Enum.Font.LuckiestGuy
titleText.TextScaled = true
titleText.TextStrokeTransparency = 0
titleText.TextStrokeColor3 = Color3.new(0, 0, 0)
titleText.Parent = screenGui

-- Levier doré sur la face avant (-X), en bas à droite (+Z du point de vue face avant)
local leverBaseCF = CFrame.new(MACHINE_X - 3.2 * SCALE, 5.5 * SCALE, MACHINE_Z + 2.5 * SCALE) 
                  * CFrame.Angles(0, math.rad(-90), 0) 
                  * CFrame.Angles(math.rad(30), 0, 0)

local leverArm        = Instance.new("Part")
leverArm.Shape        = Enum.PartType.Cylinder
leverArm.Size         = Vector3.new(0.4 * SCALE, 3 * SCALE, 0.4 * SCALE)
leverArm.Anchored     = true
leverArm.Material     = Enum.Material.Metal
leverArm.Color        = Color3.fromRGB(255, 215, 0)
leverArm.Parent       = wheelFolder

local leverBall       = Instance.new("Part")
leverBall.Shape       = Enum.PartType.Ball
leverBall.Size        = Vector3.new(1.2 * SCALE, 1.2 * SCALE, 1.2 * SCALE)
leverBall.Anchored    = true
leverBall.Material    = Enum.Material.SmoothPlastic
leverBall.Color       = Color3.fromRGB(255, 40, 40)
leverBall.Parent      = wheelFolder

-- Fonction de mise à jour du levier
local function updateLever(angleDeg)
    -- Levier pivote via l'axe X local. Une augmentation de angleDeg bascule le levier vers le bas.
    local pivotCF = leverBaseCF * CFrame.Angles(math.rad(angleDeg), 0, 0)
    leverArm.CFrame = pivotCF * CFrame.new(0, 1.5 * SCALE, 0) 
    leverBall.CFrame = pivotCF * CFrame.new(0, 3 * SCALE, 0)
end
updateLever(0) -- Position repos (déjà incliné de 30° par leverBaseCF)

-- ClickDetector sur la boule rouge à l'avant
local clickDetector = Instance.new("ClickDetector")
clickDetector.MaxActivationDistance = 40
clickDetector.Parent = leverBall

-- ClickDetector sur l'écran (même effet que le levier, distance réduite)
local screenClickDetector = Instance.new("ClickDetector")
screenClickDetector.MaxActivationDistance = 15
screenClickDetector.Parent = screenPart

local tickSound = Instance.new("Sound")
tickSound.SoundId = "rbxassetid://6026984224"
tickSound.Volume = 0.5
tickSound.Parent = machineBase

-- ══════════════════════════════════════════════════════════════════════════════
-- SLOTS — 6 SOCLES D'EXPOSITION (à côté de la machine)
-- ══════════════════════════════════════════════════════════════════════════════
local MAX_SLOTS      = 6
local SLOT_FLOOR_Y   = 0
local SLOT_OFFSETS_Z: {number} = { -18, -30, -43, 18, 30, 43 }

local PEDESTAL_H     = 3
local PEDESTAL_TOP_H = 0.5
local PEDESTAL_W     = 3.5
local PEDESTAL_TOP_W = 4
local PEDESTAL_SURF_Y = SLOT_FLOOR_Y + PEDESTAL_H + PEDESTAL_TOP_H  -- = 3.5

for i, dz in ipairs(SLOT_OFFSETS_Z) do
    local cx = MACHINE_X
    local cz = MACHINE_Z + dz

    local col              = Instance.new("Part")
    col.Name               = "SlotPedestal_" .. i
    col.Size               = Vector3.new(PEDESTAL_W, PEDESTAL_H, PEDESTAL_W)
    col.CFrame             = CFrame.new(cx, SLOT_FLOOR_Y + PEDESTAL_H / 2, cz)
    col.Anchored           = true
    col.CanCollide         = true
    col.Material           = Enum.Material.SmoothPlastic
    col.Color              = Color3.fromRGB(160, 10, 10)
    col.TopSurface         = Enum.SurfaceType.Smooth
    col.BottomSurface      = Enum.SurfaceType.Smooth
    col.Parent             = wheelFolder

    local plateau          = Instance.new("Part")
    plateau.Name           = "SlotPlateTop_" .. i
    plateau.Size           = Vector3.new(PEDESTAL_TOP_W, PEDESTAL_TOP_H, PEDESTAL_TOP_W)
    plateau.CFrame         = CFrame.new(cx, PEDESTAL_SURF_Y - PEDESTAL_TOP_H / 2, cz)
    plateau.Anchored       = true
    plateau.CanCollide     = false
    plateau.Material       = Enum.Material.Metal
    plateau.Color          = Color3.fromRGB(255, 215, 0)
    plateau.TopSurface     = Enum.SurfaceType.Smooth
    plateau.BottomSurface  = Enum.SurfaceType.Smooth
    plateau.Parent         = wheelFolder

    local bb               = Instance.new("BillboardGui")
    bb.Size                = UDim2.new(0, 44, 0, 26)
    bb.StudsOffset         = Vector3.new(0, 3, 0)
    bb.Adornee             = plateau
    bb.AlwaysOnTop         = false
    bb.MaxDistance         = 28
    bb.Parent              = wheelFolder

    local txt                      = Instance.new("TextLabel")
    txt.Size                       = UDim2.new(1, 0, 1, 0)
    txt.BackgroundTransparency     = 1
    txt.Text                       = tostring(i)
    txt.TextColor3                 = Color3.fromRGB(255, 255, 255)
    txt.Font                       = Enum.Font.GothamBlack
    txt.TextScaled                 = true
    txt.TextStrokeTransparency     = 0.4
    txt.TextStrokeColor3           = Color3.new(0, 0, 0)
    txt.Parent                     = bb
end
print(string.format("[WheelSystem] %d socles d'exposition créés", MAX_SLOTS))

-- ══════════════════════════════════════════════════════════════════════════════
-- MUR BACKDROP (derrière la machine, style Carpet en damier bleu)
-- ══════════════════════════════════════════════════════════════════════════════
do
    local WALL_X     = MACHINE_X + 3.2 * SCALE + 15.3   -- dos machine + 15 studs de clearance
    local WALL_Z_MIN = MACHINE_Z - 110
    local WALL_Z_MAX = MACHINE_Z + 78
    local WALL_Y_MIN = -0.2
    local WALL_Y_MAX = 28

    local COL_BLUE_LIGHT = Color3.fromRGB(0, 162, 255)
    local COL_BLUE_DARK  = Color3.fromRGB(0,  85, 255)

    -- Carpet est un MeshPart direct dans ReplicatedStorage
    local t = ReplicatedStorage:WaitForChild("Carpet", 10) :: Instance?
    local carpetTemplate: BasePart? = nil
    if t and (t :: Instance):IsA("BasePart") then
        carpetTemplate = t :: BasePart
    end
    if not carpetTemplate then
        -- Fallback : tuile plate 4×0.4×4
        local p = Instance.new("Part")
        p.Name          = "Carpet_Fallback"
        p.Size          = Vector3.new(4, 0.4, 4)
        p.Anchored      = true
        p.CanCollide    = false
        p.Material      = Enum.Material.SmoothPlastic
        p.TopSurface    = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        p.CastShadow    = false
        carpetTemplate  = p
    end

    do
        local template = carpetTemplate :: BasePart
        local tX = template.Size.X  -- 4
        local tY = template.Size.Y  -- 0.4 (épaisseur → profondeur du mur)
        local tZ = template.Size.Z  -- 4

        -- Rotation 90° autour de Z : l'épaisseur (Y) devient la profondeur du mur
        local wallRot = CFrame.Angles(0, 0, math.rad(90))

        local wallFolder_      = Instance.new("Folder")
        wallFolder_.Name       = "CasinoBackdrop"
        wallFolder_.Parent     = wheelFolder

        local nZ = math.ceil((WALL_Z_MAX - WALL_Z_MIN) / tZ)
        local nY = math.ceil((WALL_Y_MAX - WALL_Y_MIN) / tX)

        for iy = 0, nY - 1 do
            for iz = 0, nZ - 1 do
                local tileZ = WALL_Z_MIN + (iz + 0.5) * tZ
                local tileY = WALL_Y_MIN + tX / 2 + iy * tX

                local col = if (iy + iz) % 2 == 0 then COL_BLUE_LIGHT else COL_BLUE_DARK

                local tile = template:Clone() :: BasePart
                tile.Anchored      = true
                tile.CanCollide    = false
                tile.CanTouch      = false
                tile.CanQuery      = false
                tile.Massless      = true
                tile.CastShadow    = false
                tile.Color         = col
                tile.CFrame        = CFrame.new(WALL_X, tileY, tileZ) * wallRot

                for _, ch in ipairs(tile:GetChildren()) do
                    if ch:IsA("Texture") or ch:IsA("Decal") then
                        (ch :: Texture).Color3 = col
                    end
                end

                tile.Parent = wallFolder_
            end
        end
        print(string.format("[WheelSystem] Backdrop bleu : %d×%d = %d tuiles", nY, nZ, nY * nZ))
    end
end

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

-- ── Fonction commune de tirage ──────────────────────────────────────────────
local function ActionSpin(player: Player)
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
    -- On choisit D'ABORD le segment (ce qui s'affiche sur la machine),
    -- puis on dérive l'item DEPUIS ce segment. Garantit que popup = case arrêtée.
    local winRarity    = pickRarity()
    local segsOfRarity = SEGS_BY_RARITY[winRarity]
    local winSegIdx    = segsOfRarity[math.random(1, #segsOfRarity)]
    local winItem      = SEGMENTS[winSegIdx].item   -- dérivé du segment ✓

    -- Calcul de l'angle pour la logique pure (non utilisé en 3D mais transmis au besoin)
    local winAngle = (360 - ((winSegIdx - 1) * SEG_ANGLE)) % 360

    -- Inventaire + galerie
    DataManager.AddItem(player, { Id = winItem.itemId, Name = winItem.name, Rarity = winRarity })
    if _G.BrainrotGallery_Refresh then
        task.spawn(_G.BrainrotGallery_Refresh, player)
    end

    -- VFX + badge si LÉGENDAIRE
    if winRarity == "LEGENDARY" then
        local ldEvent = Events:FindFirstChild("LegendaryDrop")
        if ldEvent then
            ldEvent:FireAllClients(player, winItem.name)
        end
        if _G.CheckLegendaryBadge then
            task.spawn(_G.CheckLegendaryBadge, player, winItem.name)
        end
    end
    local updated = DataManager.GetData(player)
    if updated then UpdateClientData:FireClient(player, updated) end

    print(string.format("[WheelSystem] %s → %s '%s' | seg%d",
        player.Name, winRarity, winItem.name, winSegIdx))

    local angleVal = Instance.new("NumberValue")
    angleVal.Value = 0
    local conn = RunService.Heartbeat:Connect(function()
        updateLever(angleVal.Value)
    end)

    -- Tween du levier vers le bas (ex: +60 degrés pour basculer en bas)
    local tweenDown = TweenService:Create(angleVal, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = 60 })
    local tweenUp   = TweenService:Create(angleVal, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 0 })

    tweenDown.Completed:Connect(function()
        tickSound:Play()
        tweenUp:Play()

        -- Envoi du résultat pour déclencher la machine à sous UI pendant que le levier remonte
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
    end)

    tweenUp.Completed:Connect(function()
        conn:Disconnect()
        angleVal:Destroy()
        
        -- Déverrouillage après la durée de la spin 2D
        task.delay(SPIN_DURATION - 0.7, function()
            wheelLocked = false
        end)
    end)

    tweenDown:Play()
end

-- Connexions
clickDetector.MouseClick:Connect(ActionSpin)
screenClickDetector.MouseClick:Connect(ActionSpin)
RequestSpin.OnServerEvent:Connect(ActionSpin)

print(string.format(
    "[WheelSystem] v5 PIVOT pret | pos (0,18,-20) derriere fontaine | face +Z nord | phase1=%.1fs + phase2=%.1fs QuartOut | COMMON %d%% RARE %d%% EPIC %d%% LEG %d%%",
    PHASE1_DURATION, PHASE2_DURATION,
    RARITY_WEIGHTS[1].weight, RARITY_WEIGHTS[2].weight,
    RARITY_WEIGHTS[3].weight, RARITY_WEIGHTS[4].weight))

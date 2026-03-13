--!strict
-- WheelSystem.server.lua — MULTI-ROLL SYSTEM
--
-- ARCHITECTURE DES DOSSIERS :
--   Workspace/
--     CasinoMachine/          ← structure FIXE, générée une seule fois au démarrage
--       MachineBase, Wheel, Lever, Screen, Pedestals, RentrerBtn …
--       MiniClones/           ← sous-dossier VOLATILE : contient uniquement les
--                                clones des Brainrots gagnés, jamais rien d'autre
--
-- RÈGLE ABSOLUE :
--   • ClearAllChildren / Destroy ne s'appliquent QUE sur MiniClones.
--   • CasinoMachine lui-même n'est jamais vidé ni détruit pendant le jeu.
--
-- FLUX :
--   Spin → clone dans MiniClones, positionné sur le slot libre.
--   Rentrer → items → galerie joueur, puis MiniClones:ClearAllChildren().

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService          = game:GetService("RunService")
local TweenService        = game:GetService("TweenService")
local Workspace           = game:GetService("Workspace")

local DataManager = require(ServerScriptService:WaitForChild("DataManager"))
local SpawnFX     = require(ServerScriptService:WaitForChild("SpawnFX"))

local Events           = ReplicatedStorage:WaitForChild("Events")
local SpinResult       = Events:WaitForChild("SpinResult")
local UpdateClientData = Events:WaitForChild("UpdateClientData")

local function getOrCreateEvent(name: string): RemoteEvent
    local e = Events:FindFirstChild(name)
    if not e then
        e        = Instance.new("RemoteEvent")
        e.Name   = name
        e.Parent = Events
    end
    return e :: RemoteEvent
end

local RequestSpin   = getOrCreateEvent("RequestSpin")
local MachineUpdate = getOrCreateEvent("MachineUpdate")

-- ══════════════════════════════════════════════════════════════════════════════
-- CONFIG
-- ══════════════════════════════════════════════════════════════════════════════
local N_SEGMENTS      = 16
local SEG_ANGLE       = 360 / N_SEGMENTS   -- 22.5° par segment
local SPIN_COST       = 20
local FULL_ROTATIONS  = 5
local PHASE1_DURATION = 3.5
local PHASE2_DURATION = 2.0
local SPIN_DURATION   = PHASE1_DURATION + PHASE2_DURATION  -- 5.5 s

local WHEEL_CENTER  = Vector3.new(40, 18, 0)
local MACHINE_X     = WHEEL_CENTER.X
local MACHINE_Z     = WHEEL_CENTER.Z
local SCALE         = 1.05

local RARITY_COLORS = {
    COMMON          = Color3.fromRGB(  0, 255,   0),
    RARE            = Color3.fromRGB(  0, 130, 255),
    EPIC            = Color3.fromRGB(255,   0, 255),
    LEGENDARY       = Color3.fromRGB(255, 215,   0),
    ULTRA_LEGENDARY = Color3.fromRGB(255,  50,  50),
}

-- ══════════════════════════════════════════════════════════════════════════════
-- POOLS DE RARETÉ
-- ══════════════════════════════════════════════════════════════════════════════
local POOL = {
    COMMON = {
        { itemId = "BallerinaCapp",   imageId = 0, name = "Ballerina Cappuccina" },
        { itemId = "BombardiroCroc",  imageId = 0, name = "Bombardiro Crocodilo" },
        { itemId = "BombombiniGus",   imageId = 0, name = "Bombombini Gusini"    },
        { itemId = "CappuccinoAss",   imageId = 0, name = "Cappuccino Assassino" },
        { itemId = "LirilaLarila",    imageId = 0, name = "Lirilì Larilà"        },
        { itemId = "Tralalero",       imageId = 0, name = "Tralalero Tralala"    },
        { itemId = "TrippiTroppi",    imageId = 0, name = "Trippi Troppi"        },
    },
    RARE = {
        { itemId = "BrBrPatapim",     imageId = 0, name = "Brr Brr Patapim"      },
        { itemId = "ChimpanziniBan",  imageId = 0, name = "Chimpanzini Bananini" },
        { itemId = "Los67",           imageId = 0, name = "Los 67"               },
        { itemId = "LosTralaleritos", imageId = 0, name = "Los Tralaleritos"     },
    },
    EPIC = {
        { itemId = "TungTungSahur",   imageId = 0, name = "Tung Tung Tung Sahur" },
        { itemId = "WOrL",            imageId = 0, name = "W or L"               },
    },
    LEGENDARY = {
        { itemId = "Item67",          imageId = 0, name = "67"                   },
    },
    ULTRA_LEGENDARY = {
        { itemId = "DragonCannell",   imageId = 0, name = "Dragon Cannelloni"    },
        { itemId = "StrawberryEleph", imageId = 0, name = "Strawberry Elephant"  },
    },
}

local RARITY_WEIGHTS = {
    { rarity = "COMMON",          weight = 595 },
    { rarity = "RARE",            weight = 250 },
    { rarity = "EPIC",            weight = 140 },
    { rarity = "LEGENDARY",       weight =  10 },
    { rarity = "ULTRA_LEGENDARY", weight =   5 },
}

local SEGMENTS = {
    { rarity = "COMMON",          item = POOL.COMMON[1]          },
    { rarity = "COMMON",          item = POOL.COMMON[2]          },
    { rarity = "RARE",            item = POOL.RARE[1]            },
    { rarity = "COMMON",          item = POOL.COMMON[3]          },
    { rarity = "COMMON",          item = POOL.COMMON[4]          },
    { rarity = "ULTRA_LEGENDARY", item = POOL.ULTRA_LEGENDARY[1] },
    { rarity = "COMMON",          item = POOL.COMMON[5]          },
    { rarity = "RARE",            item = POOL.RARE[2]            },
    { rarity = "COMMON",          item = POOL.COMMON[6]          },
    { rarity = "EPIC",            item = POOL.EPIC[1]            },
    { rarity = "COMMON",          item = POOL.COMMON[7]          },
    { rarity = "RARE",            item = POOL.RARE[3]            },
    { rarity = "LEGENDARY",       item = POOL.LEGENDARY[1]       },
    { rarity = "EPIC",            item = POOL.EPIC[2]            },
    { rarity = "ULTRA_LEGENDARY", item = POOL.ULTRA_LEGENDARY[2] },
    { rarity = "RARE",            item = POOL.RARE[4]            },
}
assert(#SEGMENTS == N_SEGMENTS, "SEGMENTS count mismatch")

local SEGS_BY_RARITY: {[string]: {number}} = {
    COMMON={}, RARE={}, EPIC={}, LEGENDARY={}, ULTRA_LEGENDARY={}
}
for idx, seg in ipairs(SEGMENTS) do
    table.insert(SEGS_BY_RARITY[seg.rarity], idx)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- TIRAGE PONDÉRÉ
-- ══════════════════════════════════════════════════════════════════════════════
math.randomseed(os.clock() * 1000)

local function pickRarity(): string
    local roll = math.random(1, 1000)
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
-- CONSTRUCTION PHYSIQUE — STRUCTURE FIXE
-- Générée UNE SEULE FOIS au démarrage du serveur.
-- Jamais modifiée, vidée ou détruite pendant le jeu.
-- ══════════════════════════════════════════════════════════════════════════════

-- Supprime l'ancienne instance si le serveur redémarre (Studio Play)
local oldCasino = Workspace:FindFirstChild("CasinoMachine")
if oldCasino then oldCasino:Destroy() end

-- ── Dossier racine ────────────────────────────────────────────────────────────
local casinoFolder   = Instance.new("Folder")
casinoFolder.Name    = "CasinoMachine"
casinoFolder.Parent  = Workspace

-- ── Sous-dossier VOLATILE pour les mini-clones ────────────────────────────────
-- SEUL endroit où ClearAllChildren est autorisé.
local miniClonesFolder   = Instance.new("Folder")
miniClonesFolder.Name    = "MiniClones"
miniClonesFolder.Parent  = casinoFolder

-- ── Machine (socle principal) ─────────────────────────────────────────────────
local machineBase          = Instance.new("Part")
machineBase.Name           = "MachineBase"
machineBase.Size           = Vector3.new(6 * SCALE, 12 * SCALE, 8 * SCALE)
machineBase.Position       = Vector3.new(MACHINE_X, 6 * SCALE, MACHINE_Z)
machineBase.Anchored       = true
machineBase.Material       = Enum.Material.SmoothPlastic
machineBase.Color          = Color3.fromRGB(200, 0, 0)
machineBase.TopSurface     = Enum.SurfaceType.Smooth
machineBase.BottomSurface  = Enum.SurfaceType.Smooth
machineBase.Parent         = casinoFolder

local function applyGradientToFace(part: BasePart, face: Enum.NormalId)
    local sg          = Instance.new("SurfaceGui")
    sg.Face           = face
    sg.SizingMode     = Enum.SurfaceGuiSizingMode.PixelsPerStud
    sg.PixelsPerStud  = 50
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent         = part

    local frame                = Instance.new("Frame")
    frame.Size                 = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3     = Color3.fromRGB(255, 255, 255)
    frame.BorderSizePixel      = 0
    frame.Parent               = sg

    local grad    = Instance.new("UIGradient")
    grad.Color    = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 0, 0)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 25, 25)),
    })
    grad.Rotation = -90
    grad.Parent   = frame
end
applyGradientToFace(machineBase, Enum.NormalId.Left)
applyGradientToFace(machineBase, Enum.NormalId.Right)
applyGradientToFace(machineBase, Enum.NormalId.Front)
applyGradientToFace(machineBase, Enum.NormalId.Back)

local neonLeft          = Instance.new("Part")
neonLeft.Name           = "NeonLeft"
neonLeft.Size           = Vector3.new(6.1 * SCALE, 12.2 * SCALE, 0.4 * SCALE)
neonLeft.Position       = Vector3.new(MACHINE_X, 6 * SCALE, MACHINE_Z - 3.8 * SCALE)
neonLeft.Anchored       = true
neonLeft.Material       = Enum.Material.Neon
neonLeft.Color          = Color3.fromRGB(255, 215, 0)
neonLeft.Parent         = casinoFolder

local neonRight         = Instance.new("Part")
neonRight.Name          = "NeonRight"
neonRight.Size          = Vector3.new(6.1 * SCALE, 12.2 * SCALE, 0.4 * SCALE)
neonRight.Position      = Vector3.new(MACHINE_X, 6 * SCALE, MACHINE_Z + 3.8 * SCALE)
neonRight.Anchored      = true
neonRight.Material      = Enum.Material.Neon
neonRight.Color         = Color3.fromRGB(255, 215, 0)
neonRight.Parent        = casinoFolder

local screenBorder      = Instance.new("Part")
screenBorder.Name       = "ScreenBorder"
screenBorder.Size       = Vector3.new(0.6 * SCALE, 6.4 * SCALE, 7.4 * SCALE)
screenBorder.CFrame     = CFrame.new(MACHINE_X - 3.05 * SCALE, 9 * SCALE, MACHINE_Z)
                        * CFrame.Angles(0, 0, math.rad(-15))
screenBorder.Anchored   = true
screenBorder.Material   = Enum.Material.Metal
screenBorder.Color      = Color3.fromRGB(255, 215, 0)
screenBorder.Parent     = casinoFolder

local screenPart        = Instance.new("Part")
screenPart.Name         = "ScreenPart"
screenPart.Size         = Vector3.new(0.65 * SCALE, 6 * SCALE, 7 * SCALE)
screenPart.CFrame       = CFrame.new(MACHINE_X - 3.1 * SCALE, 9 * SCALE, MACHINE_Z)
                        * CFrame.Angles(0, 0, math.rad(-15))
screenPart.Anchored     = true
screenPart.Material     = Enum.Material.SmoothPlastic
screenPart.Color        = Color3.fromRGB(15, 15, 15)
screenPart.Parent       = casinoFolder

local screenGui         = Instance.new("SurfaceGui")
screenGui.Face          = Enum.NormalId.Left
screenGui.CanvasSize    = Vector2.new(800 * SCALE, 600 * SCALE)
screenGui.Parent        = screenPart

local titleText                      = Instance.new("TextLabel")
titleText.Size                       = UDim2.new(1, 0, 1, 0)
titleText.BackgroundTransparency     = 1
titleText.Text                       = "SPIN TO WIN\nBRAINROT"
titleText.TextColor3                 = Color3.fromRGB(255, 255, 255)
titleText.Font                       = Enum.Font.LuckiestGuy
titleText.TextScaled                 = true
titleText.TextStrokeTransparency     = 0
titleText.TextStrokeColor3           = Color3.new(0, 0, 0)
titleText.Parent                     = screenGui

-- ── Levier ────────────────────────────────────────────────────────────────────
local leverBaseCF = CFrame.new(MACHINE_X - 3.2 * SCALE, 5.5 * SCALE, MACHINE_Z + 2.5 * SCALE)
                  * CFrame.Angles(0, math.rad(-90), 0)
                  * CFrame.Angles(math.rad(30), 0, 0)

local leverArm        = Instance.new("Part")
leverArm.Name         = "LeverArm"
leverArm.Shape        = Enum.PartType.Cylinder
leverArm.Size         = Vector3.new(0.4 * SCALE, 3 * SCALE, 0.4 * SCALE)
leverArm.Anchored     = true
leverArm.Material     = Enum.Material.Metal
leverArm.Color        = Color3.fromRGB(255, 215, 0)
leverArm.Parent       = casinoFolder

local leverBall       = Instance.new("Part")
leverBall.Name        = "LeverBall"
leverBall.Shape       = Enum.PartType.Ball
leverBall.Size        = Vector3.new(1.2 * SCALE, 1.2 * SCALE, 1.2 * SCALE)
leverBall.Anchored    = true
leverBall.Material    = Enum.Material.SmoothPlastic
leverBall.Color       = Color3.fromRGB(255, 40, 40)
leverBall.Parent      = casinoFolder

local function updateLever(angleDeg: number)
    local pivotCF    = leverBaseCF * CFrame.Angles(math.rad(angleDeg), 0, 0)
    leverArm.CFrame  = pivotCF * CFrame.new(0, 1.5 * SCALE, 0)
    leverBall.CFrame = pivotCF * CFrame.new(0, 3 * SCALE, 0)
end
updateLever(0)

local clickDetector                   = Instance.new("ClickDetector")
clickDetector.MaxActivationDistance   = 40
clickDetector.Parent                  = leverBall

local screenClickDetector                   = Instance.new("ClickDetector")
screenClickDetector.MaxActivationDistance   = 15
screenClickDetector.Parent                  = screenPart

local tickSound         = Instance.new("Sound")
tickSound.SoundId       = "rbxassetid://6026984224"
tickSound.Volume        = 0.5
tickSound.Parent        = machineBase

-- ══════════════════════════════════════════════════════════════════════════════
-- SLOTS — 6 SOCLES D'EXPOSITION
-- Tous enfants directs de casinoFolder.
-- Les mini-clones NE sont PAS leurs enfants — ils vont dans miniClonesFolder.
-- ══════════════════════════════════════════════════════════════════════════════
local MAX_SLOTS      = 6
local SLOT_FLOOR_Y   = 0
local SLOT_OFFSETS_Z: {number} = { -18, -30, -43, 18, 30, 43 }

local PEDESTAL_H     = 3
local PEDESTAL_TOP_H = 0.5
local PEDESTAL_W     = 3.5
local PEDESTAL_TOP_W = 4
local PEDESTAL_SURF_Y = SLOT_FLOOR_Y + PEDESTAL_H + PEDESTAL_TOP_H  -- = 3.5

-- Positions monde du dessus de chaque socle (où se posent les mini-clones)
local SLOT_WORLD_POS: {Vector3} = {}
for i, dz in ipairs(SLOT_OFFSETS_Z) do
    SLOT_WORLD_POS[i] = Vector3.new(MACHINE_X, PEDESTAL_SURF_Y, MACHINE_Z + dz)
end

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
    col.Parent             = casinoFolder

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
    plateau.Parent         = casinoFolder

    local bb               = Instance.new("BillboardGui")
    bb.Size                = UDim2.new(0, 44, 0, 26)
    bb.StudsOffset         = Vector3.new(0, 3, 0)
    bb.Adornee             = plateau
    bb.AlwaysOnTop         = false
    bb.MaxDistance         = 28
    bb.Parent              = casinoFolder

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

-- ══════════════════════════════════════════════════════════════════════════════
-- MUR BACKDROP (derrière la machine, style Carpet en damier bleu)
-- ══════════════════════════════════════════════════════════════════════════════
do
    -- La face "écran" de la machine est sur -X → le dos est sur +X.
    -- Le mur est positionné juste derrière le dos de la machine.
    local WALL_X     = MACHINE_X + 3.2 * SCALE + 0.3  -- derrière le dos de la machine
    local WALL_Z_MIN = MACHINE_Z - 52                  -- couvre tous les slots (±43)
    local WALL_Z_MAX = MACHINE_Z + 52
    local WALL_Y_MIN = 0
    local WALL_Y_MAX = 26                              -- hauteur imposante

    local COL_BLUE_LIGHT = Color3.fromRGB(0, 162, 255)
    local COL_BLUE_DARK  = Color3.fromRGB(0,  85, 255)

    -- Carpet MeshPart (4 × 0.4 × 4) dans ReplicatedStorage.Blocks
    local blocks          = ReplicatedStorage:FindFirstChild("Blocks")
    local carpetTemplate  = blocks and blocks:FindFirstChild("Carpet") :: BasePart?

    if carpetTemplate and carpetTemplate:IsA("BasePart") then
        local tX = carpetTemplate.Size.X  -- 4
        local tY = carpetTemplate.Size.Y  -- 0.4 (épaisseur → devient la profondeur du mur)
        local tZ = carpetTemplate.Size.Z  -- 4

        -- Rotation 90° autour de Z : l'épaisseur (Y) devient la dimension X (profondeur du mur)
        --   résultat en world space : tY studs en X, tX studs en Y, tZ studs en Z
        local wallRot = CFrame.Angles(0, 0, math.rad(90))

        local wallFolder      = Instance.new("Folder")
        wallFolder.Name       = "CasinoBackdrop"
        wallFolder.Parent     = casinoFolder

        -- Tiles en Y (hauteur) × Z (largeur)
        local nZ = math.ceil((WALL_Z_MAX - WALL_Z_MIN) / tZ)
        local nY = math.ceil((WALL_Y_MAX - WALL_Y_MIN) / tX)   -- après rotation, tX = hauteur tuile

        for iy = 0, nY - 1 do
            for iz = 0, nZ - 1 do
                local tileZ = WALL_Z_MIN + (iz + 0.5) * tZ
                local tileY = WALL_Y_MIN + tX / 2 + iy * tX  -- centré sur la case

                local col = if (iy + iz) % 2 == 0 then COL_BLUE_LIGHT else COL_BLUE_DARK

                local tile = carpetTemplate:Clone() :: BasePart
                tile.Anchored      = true
                tile.CanCollide    = false
                tile.CanTouch      = false
                tile.CanQuery      = false
                tile.Massless      = true
                tile.CastShadow    = false
                tile.Color         = col
                tile.CFrame        = CFrame.new(WALL_X, tileY, tileZ) * wallRot

                -- Colorier aussi les Textures/Decals enfants
                for _, ch in ipairs(tile:GetChildren()) do
                    if ch:IsA("Texture") or ch:IsA("Decal") then
                        (ch :: Texture).Color3 = col
                    end
                end

                tile.Parent = wallFolder
            end
        end
        print(string.format("[WheelSystem] Backdrop : %d×%d = %d tuiles Carpet", nY, nZ, nY * nZ))
    else
        warn("[WheelSystem] Backdrop : Blocks.Carpet introuvable — mur ignoré")
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- DONNÉES PAR JOUEUR — file d'attente machine
-- ══════════════════════════════════════════════════════════════════════════════
type PendingEntry = { item: {itemId: string, name: string}, rarity: string }
local pendingItems: {[number]: {PendingEntry}} = {}

-- Table de correspondance slotIndex → clone dans miniClonesFolder
-- (référence uniquement ; la vérité physique reste dans miniClonesFolder)
local machineClones: {[number]: Instance} = {}

-- ── Nettoyage sécurisé ────────────────────────────────────────────────────────
-- SEULE fonction autorisée à détruire des objets liés à la machine.
-- Elle ne touche QUE miniClonesFolder — jamais casinoFolder lui-même.
local function clearMachineClones()
    miniClonesFolder:ClearAllChildren()   -- supprime tous les mini-clones
    table.clear(machineClones)            -- réinitialise la table de références
end

-- ── Auras de rareté ──────────────────────────────────────────────────────────
-- Aura style "KI de Sangoku" — flammes qui montent du centre du modèle.
-- AuraAnchor invisible parentée dans le Model → suit les PivotTo (idle spin compris).
local function applyAura(clone: Model, rarity: string)
    if rarity ~= "EPIC" and rarity ~= "LEGENDARY" and rarity ~= "ULTRA_LEGENDARY" then
        return
    end

    -- Part invisible au centre géométrique du modèle
    local anchor          = Instance.new("Part")
    anchor.Name           = "AuraAnchor"
    anchor.Size           = Vector3.new(0.1, 0.1, 0.1)
    anchor.Anchored       = true
    anchor.CanCollide     = false
    anchor.CanTouch       = false
    anchor.CanQuery       = false
    anchor.Massless       = true
    anchor.CastShadow     = false
    anchor.Transparency   = 1
    anchor.CFrame         = clone:GetPivot()
    anchor.Parent         = clone

    local col: Color3
    local rate: number
    local lightBrightness: number
    local lightRange: number

    if rarity == "EPIC" then
        col             = Color3.fromRGB(170, 0, 255)
        rate            = 35
        lightBrightness = 5
        lightRange      = 16
    else  -- LEGENDARY / ULTRA_LEGENDARY
        col             = Color3.fromRGB(255, 200, 0)
        rate            = 55
        lightBrightness = 8
        lightRange      = 22
    end

    -- ── ParticleEmitter KI (flammes verticales) ──────────────────────────────
    local pt               = Instance.new("ParticleEmitter")
    pt.Texture             = "rbxassetid://299324419"   -- flamme / trait vertical
    pt.Color               = ColorSequence.new(col)
    pt.LightEmission       = 1
    pt.LightInfluence      = 0
    pt.ZOffset             = 1
    pt.Size                = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(0.4, 2.5),
        NumberSequenceKeypoint.new(1, 0),
    })
    pt.Transparency        = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(0.6, 0.3),
        NumberSequenceKeypoint.new(1, 1),
    })
    pt.Speed               = NumberRange.new(5, 10)
    pt.Acceleration        = Vector3.new(0, 20, 0)   -- monte rapidement
    pt.Lifetime            = NumberRange.new(0.6, 1.2)
    pt.Rate                = rate
    pt.VelocitySpread      = 360                     -- entoure le modèle
    pt.RotSpeed            = NumberRange.new(-90, 90)
    pt.Rotation            = NumberRange.new(0, 360)
    pt.LockedToPart        = true
    pt.Enabled             = true
    pt.Parent              = anchor

    -- ── Lumière pulsée ───────────────────────────────────────────────────────
    local light            = Instance.new("PointLight")
    light.Color            = col
    light.Brightness       = lightBrightness
    light.Range            = lightRange
    light.Parent           = anchor
end

-- Pré-déclaration pour permettre la référence mutuelle avec attachSlotPrompts.
local refreshMachineClones: (userId: number) -> ()

-- ── Placement d'un mini-clone sur un socle ────────────────────────────────────
-- Le clone est parenté dans miniClonesFolder, PAS dans casinoFolder.
local function spawnMiniCloneAtSlot(slotIdx: number, itemName: string): Instance?
    local modelsFolder = ReplicatedStorage:FindFirstChild("BrainrotModels")
    if not modelsFolder then return nil end

    local template = modelsFolder:FindFirstChild(itemName)
    if not template or not template:IsA("Model") then return nil end

    local clone = (template :: Model):Clone() :: Model

    for _, p in ipairs(clone:GetDescendants()) do
        if p:IsA("BasePart") then
            local bp      = p :: BasePart
            bp.CanCollide = false
            bp.CanTouch   = false
            bp.CanQuery   = false
            bp.Massless   = true
            bp.Anchored   = true
            bp.CastShadow = false
        end
    end

    -- ▶ Parent EN PREMIER — GetBoundingBox exige que le modèle soit dans le DataModel
    clone.Parent = miniClonesFolder

    -- ── Scale proportionnel (12 studs max) ───────────────────────────────────
    pcall(function()
        local _, size = clone:GetBoundingBox()
        local maxDim  = math.max(size.X, size.Y, size.Z)
        if maxDim > 0 then
            clone:ScaleTo(clone:GetScale() * (12 / maxDim))
        end
    end)

    -- ── Orientation : copie la rotation de la machine (pas de LookAt) ──────────
    local spawnPos = SLOT_WORLD_POS[slotIdx]
    clone:PivotTo(CFrame.new(spawnPos) * machineBase.CFrame.Rotation)

    -- ── Idle spin : rotation continue sur l'axe Y (effet showroom) ──────────
    task.spawn(function()
        while clone and clone.Parent do
            clone:PivotTo(clone:GetPivot() * CFrame.Angles(0, math.rad(1), 0))
            task.wait(0.03)
        end
    end)

    return clone
end

-- ── Prompts d'interaction sur chaque mini-clone ──────────────────────────────
-- Deux ProximityPrompts attachés au PrimaryPart du clone :
--   E (Porter)          → CarryManager + retrait du slot
--   F (Envoyer à Base)  → DataManager + galerie + retrait du slot
-- Les prompts meurent avec le clone lors du clearMachineClones().
local function attachSlotPrompts(slotIdx: number, clone: Model, userId: number, entry: PendingEntry)
    local anchor: BasePart? = clone.PrimaryPart
        or clone:FindFirstChildWhichIsA("BasePart", true) :: BasePart?
    if not anchor then return end

    local itemName = entry.item.name
    local itemId   = entry.item.itemId
    local rarity   = entry.rarity

    -- ── Prompt "Porter" (E) ───────────────────────────────────────────────────
    local ppCarry                    = Instance.new("ProximityPrompt")
    ppCarry.ActionText               = "Porter"
    ppCarry.ObjectText               = itemName
    ppCarry.KeyboardKeyCode          = Enum.KeyCode.E
    ppCarry.HoldDuration             = 0.5
    ppCarry.MaxActivationDistance    = 12
    ppCarry.RequiresLineOfSight      = false
    ppCarry.Parent                   = anchor

    ppCarry.Triggered:Connect(function(triggerPlayer: Player)
        if triggerPlayer.UserId ~= userId then return end
        local userPending = pendingItems[userId]
        if not userPending or not userPending[slotIdx] then return end

        table.remove(userPending, slotIdx)
        refreshMachineClones(userId)
        MachineUpdate:FireClient(triggerPlayer, { count = #userPending, max = MAX_SLOTS })

        if _G.CarryManager_StartCarry then
            _G.CarryManager_StartCarry(triggerPlayer, entry.item, rarity)
        end

        print(string.format("[WheelSystem] %s → Porter '%s' (%s) depuis slot %d",
            triggerPlayer.Name, itemName, rarity, slotIdx))
    end)

    -- ── Prompt "Envoyer à la Base" (F) ───────────────────────────────────────
    local ppSend                     = Instance.new("ProximityPrompt")
    ppSend.ActionText                = "Envoyer à la Base"
    ppSend.ObjectText                = itemName
    ppSend.KeyboardKeyCode           = Enum.KeyCode.F
    ppSend.HoldDuration              = 0.5
    ppSend.MaxActivationDistance     = 12
    ppSend.RequiresLineOfSight       = false
    ppSend.UIOffset                  = Vector2.new(0, 60)
    ppSend.Parent                    = anchor

    ppSend.Triggered:Connect(function(triggerPlayer: Player)
        if triggerPlayer.UserId ~= userId then return end
        local userPending = pendingItems[userId]
        if not userPending or not userPending[slotIdx] then return end

        -- Destruction immédiate et explicite du clone de ce slot
        local specificClone = machineClones[slotIdx]
        if specificClone and specificClone.Parent then
            specificClone:Destroy()
            machineClones[slotIdx] = nil :: any
        end

        table.remove(userPending, slotIdx)
        refreshMachineClones(userId)
        MachineUpdate:FireClient(triggerPlayer, { count = #userPending, max = MAX_SLOTS })

        -- Sauvegarde inventaire
        DataManager.AddItem(triggerPlayer, { Id = itemId, Name = itemName, Rarity = rarity })

        -- Placement galerie + VFX
        if _G.BrainrotGallery_GetEmptyPedestalTops and _G.BrainrotGallery_ForcePlace then
            local emptySlots = _G.BrainrotGallery_GetEmptyPedestalTops(triggerPlayer) :: {[number]: BasePart}
            local firstIdx, firstTop = next(emptySlots)
            if firstIdx then
                _G.BrainrotGallery_ForcePlace(triggerPlayer, firstIdx, {
                    Id     = itemId,
                    Name   = itemName,
                    Rarity = rarity,
                })
                SpawnFX.Play(firstTop, rarity, triggerPlayer)
            end
        end

        -- Mise à jour client
        local updated = DataManager.GetData(triggerPlayer)
        if updated then UpdateClientData:FireClient(triggerPlayer, updated) end

        print(string.format("[WheelSystem] %s → Envoyé à la Base '%s' (%s) depuis slot %d",
            triggerPlayer.Name, itemName, rarity, slotIdx))
    end)
end

-- Reconstruit les clones depuis la file d'attente de l'userId.
refreshMachineClones = function(userId: number)
    clearMachineClones()
    local items = pendingItems[userId] or {}
    for i, entry in ipairs(items) do
        local clone = spawnMiniCloneAtSlot(i, entry.item.name)
        if clone then
            machineClones[i] = clone :: Instance
            attachSlotPrompts(i, clone :: Model, userId, entry)
            applyAura(clone :: Model, entry.rarity)
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- LOGIQUE DE SPIN
-- ══════════════════════════════════════════════════════════════════════════════
local wheelLocked: boolean              = false
local spinCooldowns: {[number]: number} = {}

local ORIGINAL_CFRAME = CFrame.new(WHEEL_CENTER) * CFrame.Angles(0, math.rad(180), 0)

local function getCoins(player: Player): number
    local ls    = player:FindFirstChild("leaderstats")
    local coins = ls and ls:FindFirstChild("Brainrot Coins")
    return coins and (coins :: IntValue).Value or 0
end

local function ActionSpin(player: Player)
    if wheelLocked then return end

    -- 1. Capacité machine (par joueur, AVANT déduction)
    local userPending = pendingItems[player.UserId] or {}
    if #userPending >= MAX_SLOTS then
        SpinResult:FireClient(player, { success = false, reason = "machine_full" })
        return
    end

    -- 2. Anti-spam
    local now = tick()
    if spinCooldowns[player.UserId] and (now - spinCooldowns[player.UserId]) < SPIN_DURATION + 1 then
        return
    end

    -- 3. Coins
    if getCoins(player) < SPIN_COST then
        SpinResult:FireClient(player, { success = false, reason = "coins" })
        return
    end

    local data = DataManager.GetData(player)
    if not data then return end

    -- 4. Déduction + verrou
    DataManager.SpendGold(player, SPIN_COST)
    spinCooldowns[player.UserId] = now
    wheelLocked = true

    -- 5. Tirage
    local winRarity    = pickRarity()
    local segsOfRarity = SEGS_BY_RARITY[winRarity]
    local winSegIdx    = segsOfRarity[math.random(1, #segsOfRarity)]
    local winItem      = SEGMENTS[winSegIdx].item

    -- 6. Ajout dans la file d'attente (le clone apparaît APRÈS la fin du spin)
    table.insert(userPending, { item = winItem, rarity = winRarity })
    pendingItems[player.UserId] = userPending

    -- Compteur UI immédiat (le modèle reste caché jusqu'à la révélation)
    MachineUpdate:FireClient(player, { count = #userPending, max = MAX_SLOTS })

    -- Badge légendaire
    if winRarity == "LEGENDARY" or winRarity == "ULTRA_LEGENDARY" then
        local ldEvent = Events:FindFirstChild("LegendaryDrop")
        if ldEvent then ldEvent:FireAllClients(player, winItem.name) end
        if _G.CheckLegendaryBadge then
            task.spawn(_G.CheckLegendaryBadge, player, winItem.name)
        end
    end

    print(string.format("[WheelSystem] %s → slot %d/%d : %s '%s' | seg%d",
        player.Name, #userPending, MAX_SLOTS, winRarity, winItem.name, winSegIdx))

    -- 7. Animation levier
    local angleVal   = Instance.new("NumberValue")
    angleVal.Value   = 0
    local conn       = RunService.Heartbeat:Connect(function()
        updateLever(angleVal.Value)
    end)

    local tweenDown = TweenService:Create(angleVal,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Value = 60 })
    local tweenUp   = TweenService:Create(angleVal,
        TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Value = 0 })

    tweenDown.Completed:Connect(function()
        tickSound:Play()
        tweenUp:Play()

        SpinResult:FireClient(player, {
            success    = true,
            segments   = SEGMENTS,
            winSegment = winSegIdx,
            memeName   = winItem.name,
            memeRarity = winRarity,
            imageId    = winItem.imageId,
            duration   = SPIN_DURATION,
            rotations  = FULL_ROTATIONS,
        })

        task.delay(SPIN_DURATION + 1.5, function()
            local updated = DataManager.GetData(player)
            if updated then UpdateClientData:FireClient(player, updated) end
            -- Révélation du modèle sur le socle une fois la roue arrêtée
            if pendingItems[player.UserId] then
                refreshMachineClones(player.UserId)
            end
        end)
    end)

    tweenUp.Completed:Connect(function()
        conn:Disconnect()
        angleVal:Destroy()
        task.delay(SPIN_DURATION - 0.7, function()
            wheelLocked = false
        end)
    end)

    tweenDown:Play()
end

clickDetector.MouseClick:Connect(ActionSpin)
screenClickDetector.MouseClick:Connect(ActionSpin)
RequestSpin.OnServerEvent:Connect(ActionSpin)


-- ══════════════════════════════════════════════════════════════════════════════
-- DÉCONNEXION
-- ══════════════════════════════════════════════════════════════════════════════
Players.PlayerRemoving:Connect(function(player: Player)
    pendingItems[player.UserId]  = nil
    spinCooldowns[player.UserId] = nil
end)

print(string.format(
    "[WheelSystem] Pret | CasinoMachine generee | %d socles | MiniClones isole | COMMON %.1f%% RARE %.1f%% EPIC %.1f%% LEG %.1f%% ULTRA %.1f%%",
    MAX_SLOTS,
    RARITY_WEIGHTS[1].weight / 10, RARITY_WEIGHTS[2].weight / 10,
    RARITY_WEIGHTS[3].weight / 10, RARITY_WEIGHTS[4].weight / 10,
    RARITY_WEIGHTS[5].weight / 10))

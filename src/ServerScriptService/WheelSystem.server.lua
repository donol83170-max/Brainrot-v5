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
local SPIN_COST       = 20
local FULL_ROTATIONS  = 5
local PHASE1_DURATION = 3.5
local PHASE2_DURATION = 2.0
local SPIN_DURATION   = PHASE1_DURATION + PHASE2_DURATION  -- 5.5 s

local WHEEL_CENTER  = Vector3.new(40, 18, 0)
local MACHINE_X     = WHEEL_CENTER.X
local MACHINE_Z     = WHEEL_CENTER.Z
local SCALE         = 1.05

-- ══════════════════════════════════════════════════════════════════════════════
-- CHARGEMENT DYNAMIQUE — TOUS les brainrots des packs
-- ══════════════════════════════════════════════════════════════════════════════
local ALL_ITEMS: {{itemId: string, name: string, imageId: number}} = {}

local BRAINROT_SOURCES = {
    "Brainrots",
    "BrainrotPack",
    "Brainrot pack1",
    "BrainrotModels",
}

-- Attendre que BrainrotModelsSetup fusionne les dossiers
task.wait(2)

-- ── DIAGNOSTIC : lister tout le contenu de ReplicatedStorage ────────────────
print("[WheelSystem] === DIAGNOSTIC ReplicatedStorage ===")
for _, child in ipairs(ReplicatedStorage:GetChildren()) do
    local count = #child:GetChildren()
    print(string.format("  → '%s' (%s) [%d enfants]", child.Name, child.ClassName, count))
end
print("[WheelSystem] === FIN DIAGNOSTIC ===")

local seen: {[string]: boolean} = {}
for _, sourceName in ipairs(BRAINROT_SOURCES) do
    local source = ReplicatedStorage:FindFirstChild(sourceName)
    if not source then
        warn(string.format("[WheelSystem] Source '%s' introuvable", sourceName))
        continue
    end
    print(string.format("[WheelSystem] Scan de '%s' (%s, %d enfants)...",
        sourceName, source.ClassName, #source:GetChildren()))

    local function scanContainer(container: Instance, depth: number)
        for _, child in ipairs(container:GetChildren()) do
            local isModel = child:IsA("Model")
            local childCount = #child:GetChildren()
            -- Un Model avec beaucoup d'enfants Model est un CONTENEUR, pas un brainrot
            local isContainer = (child:IsA("Folder")) or (isModel and childCount >= 5)
            if isContainer then
                scanContainer(child, depth + 1)
            elseif isModel and not seen[child.Name] then
                seen[child.Name] = true
                table.insert(ALL_ITEMS, {
                    itemId  = child.Name,
                    name    = child.Name,
                    imageId = 0,
                })
            end
        end
    end
    scanContainer(source, 0)
end

-- Fallback si aucun modèle trouvé
if #ALL_ITEMS == 0 then
    warn("[WheelSystem] AUCUN brainrot trouvé dans les sources ! Scan de TOUT ReplicatedStorage...")
    for _, child in ipairs(ReplicatedStorage:GetDescendants()) do
        if child:IsA("Model") and not seen[child.Name] then
            -- Ignorer les conteneurs (5+ enfants) et la base joueur
            local childCount = #child:GetChildren()
            local lowerName = string.lower(child.Name)
            if childCount < 5 and not string.find(lowerName, "base") then
                seen[child.Name] = true
                table.insert(ALL_ITEMS, {
                    itemId  = child.Name,
                    name    = child.Name,
                    imageId = 0,
                })
            end
        end
    end
end

if #ALL_ITEMS == 0 then
    warn("[WheelSystem] TOUJOURS AUCUN brainrot ! Ajout placeholder.")
    table.insert(ALL_ITEMS, { itemId = "Unknown", name = "???", imageId = 0 })
end

-- Trier par nom pour un ordre stable sur la roue
table.sort(ALL_ITEMS, function(a, b) return a.name < b.name end)

local N_SEGMENTS = #ALL_ITEMS
local SEG_ANGLE  = 360 / N_SEGMENTS

-- Construire SEGMENTS (format attendu par le client)
local SEGMENTS = {}
for i, item in ipairs(ALL_ITEMS) do
    SEGMENTS[i] = { rarity = "COMMON", item = item }
end

print(string.format("[WheelSystem] === %d brainrots chargés : ===", N_SEGMENTS))
for i, item in ipairs(ALL_ITEMS) do
    print(string.format("[WheelSystem]   [%d] %s", i, item.name))
end

-- ══════════════════════════════════════════════════════════════════════════════
-- TIRAGE — probabilité égale, pas de rareté
-- ══════════════════════════════════════════════════════════════════════════════
math.randomseed(os.clock() * 1000)

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

local PEDESTAL_H     = 4.5    -- Agrandi (+50%)
local PEDESTAL_TOP_H = 0.75   -- Agrandi (+50%)
local PEDESTAL_W     = 5.25   -- Agrandi (+50%)
local PEDESTAL_TOP_W = 6      -- Agrandi (+50%)
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
    -- +15 studs de recul supplémentaires : les Brainrots de 12 studs tournent librement.
    local WALL_X     = MACHINE_X + 3.2 * SCALE + 15.3   -- dos machine + 15 studs de clearance
    -- Z étendu de -110 jusqu'à 78 : bord sud du trottoir de l'avenue.
    local WALL_Z_MIN = MACHINE_Z - 110
    local WALL_Z_MAX = MACHINE_Z + 78
    -- Y légèrement sous le sol pour supprimer tout scintillement (Z-fighting).
    local WALL_Y_MIN = -0.2
    local WALL_Y_MAX = 28                              -- hauteur imposante

    local COL_BLUE_LIGHT = Color3.fromRGB(0, 162, 255)
    local COL_BLUE_DARK  = Color3.fromRGB(0,  85, 255)

    -- Carpet est un MeshPart direct dans ReplicatedStorage.
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
        local tY = template.Size.Y  -- 0.4 (épaisseur → devient la profondeur du mur)
        local tZ = template.Size.Z  -- 4

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

                local tile = template:Clone() :: BasePart
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
        print(string.format("[WheelSystem] Backdrop : %d×%d = %d tuiles", nY, nZ, nY * nZ))
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
local function spawnMiniCloneAtSlot(slotIdx: number, itemName: string, itemId: string?): Instance?
    print(string.format("[WheelSystem] spawnMiniCloneAtSlot(%d, '%s', '%s') — DÉBUT",
        slotIdx, itemName, tostring(itemId)))

    -- ── Recherche RÉCURSIVE dans tout ReplicatedStorage ──────────────────────
    -- On cherche par nom exact (FindFirstChild récursif)
    local template: Instance? = nil

    -- Méthode 1 : FindFirstChild récursif dans les sources connues
    local SEARCH_FOLDERS = {
        ReplicatedStorage:FindFirstChild("Brainrots"),
        ReplicatedStorage:FindFirstChild("BrainrotPack"),
        ReplicatedStorage:FindFirstChild("Brainrot pack1"),
        ReplicatedStorage:FindFirstChild("BrainrotModels"),
    }

    local searchNames = { itemName }
    if itemId and itemId ~= "" and itemId ~= itemName then
        table.insert(searchNames, itemId)
    end

    for _, folder in ipairs(SEARCH_FOLDERS) do
        if not folder then continue end
        for _, tryName in ipairs(searchNames) do
            -- FindFirstChild(name, true) = recherche récursive native
            local found = folder:FindFirstChild(tryName, true)
            if found and found:IsA("Model") then
                template = found
                print(string.format("[WheelSystem]   TROUVÉ '%s' dans %s", tryName, folder.Name))
                break
            end
        end
        if template then break end
    end

    -- Méthode 2 : fallback sur TOUT ReplicatedStorage
    if not template then
        for _, tryName in ipairs(searchNames) do
            local found = ReplicatedStorage:FindFirstChild(tryName, true)
            if found and found:IsA("Model") then
                template = found
                print(string.format("[WheelSystem]   TROUVÉ (fallback global) '%s' → %s", tryName, found:GetFullName()))
                break
            end
        end
    end

    if not template then
        warn(string.format("[WheelSystem] ❌ INTROUVABLE : '%s' (itemId='%s') — aucun Model de ce nom dans ReplicatedStorage",
            itemName, tostring(itemId)))
        return nil
    end

    -- ── Clonage ──────────────────────────────────────────────────────────────
    local clone = (template :: Model):Clone() :: Model
    print(string.format("[WheelSystem]   Clone créé : '%s' (%d descendants)", clone.Name, #clone:GetDescendants()))

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

    -- ▶ Parent dans miniClonesFolder (Workspace) — OBLIGATOIRE pour que le modèle soit visible
    clone.Parent = miniClonesFolder
    print(string.format("[WheelSystem]   Parent → %s", miniClonesFolder:GetFullName()))

    -- ── Scale proportionnel (9 studs max) ────────────────────────────────────
    local scaleOk, scaleErr = pcall(function()
        local _, size = clone:GetBoundingBox()
        local maxDim  = math.max(size.X, size.Y, size.Z)
        print(string.format("[WheelSystem]   BoundingBox = (%.1f, %.1f, %.1f) max=%.1f", size.X, size.Y, size.Z, maxDim))
        if maxDim > 0 then
            clone:ScaleTo(clone:GetScale() * (9 / maxDim))
        end
    end)
    if not scaleOk then
        warn("[WheelSystem]   Scale ERREUR : " .. tostring(scaleErr))
    end

    -- ── Redresser si couché (plus grande dim ≠ Y) ──────────────────────────
    pcall(function()
        local _, size = clone:GetBoundingBox()
        if size.X >= size.Y and size.X >= size.Z then
            clone:PivotTo(clone:GetPivot() * CFrame.Angles(0, 0, math.rad(90)))
        elseif size.Z >= size.Y and size.Z >= size.X then
            clone:PivotTo(clone:GetPivot() * CFrame.Angles(math.rad(-90), 0, 0))
        end
    end)

    -- ── Position sur le socle ────────────────────────────────────────────────
    local spawnPos = SLOT_WORLD_POS[slotIdx]
    if not spawnPos then
        warn(string.format("[WheelSystem]   ❌ SLOT_WORLD_POS[%d] est nil ! MAX_SLOTS=%d", slotIdx, MAX_SLOTS))
        clone:Destroy()
        return nil
    end

    clone:PivotTo(CFrame.new(spawnPos) * machineBase.CFrame.Rotation)
    local finalPos = clone:GetPivot().Position
    print(string.format("[WheelSystem]   ✅ Positionné slot %d → (%.1f, %.1f, %.1f)",
        slotIdx, finalPos.X, finalPos.Y, finalPos.Z))

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

    -- ── Prompt "Téléporter à la Base" (F) ─────────────────────────────────────
    -- Envoie le brainrot à la galerie ET téléporte le joueur à sa base
    local ppTeleport                     = Instance.new("ProximityPrompt")
    ppTeleport.ActionText                = "Envoyer dans la Base"
    ppTeleport.ObjectText                = itemName
    ppTeleport.KeyboardKeyCode           = Enum.KeyCode.F
    ppTeleport.HoldDuration              = 0.5
    ppTeleport.MaxActivationDistance     = 12
    ppTeleport.RequiresLineOfSight       = false
    ppTeleport.UIOffset                  = Vector2.new(0, 60)
    ppTeleport.Parent                    = anchor

    ppTeleport.Triggered:Connect(function(triggerPlayer: Player)
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
        local placedSlotIdx: number? = nil
        local hookExists = _G.BrainrotGallery_GetEmptyPedestalTops and _G.BrainrotGallery_ForcePlace
        print(string.format("[WheelSystem] F pressé — hooks existent: %s", tostring(hookExists ~= nil)))

        if hookExists then
            local emptySlots = _G.BrainrotGallery_GetEmptyPedestalTops(triggerPlayer) :: {[number]: BasePart}
            local emptyCount = 0
            for _ in pairs(emptySlots) do emptyCount += 1 end
            print(string.format("[WheelSystem] Socles vides dans la base : %d", emptyCount))

            local firstIdx, firstTop = next(emptySlots)
            if firstIdx then
                placedSlotIdx = firstIdx
                print(string.format("[WheelSystem] Placement sur socle %d — item='%s'", firstIdx, itemName))
                _G.BrainrotGallery_ForcePlace(triggerPlayer, firstIdx, {
                    Id     = itemId,
                    Name   = itemName,
                    Rarity = rarity,
                })
                SpawnFX.Play(firstTop, rarity, triggerPlayer)
            else
                warn("[WheelSystem] ❌ Aucun socle vide dans la base ! Le brainrot est sauvé dans l'inventaire uniquement.")
            end
        else
            warn("[WheelSystem] ❌ Hooks BrainrotGallery NON DISPONIBLES — BrainrotGallery n'a pas démarré ?")
        end

        -- Mise à jour client
        local updated = DataManager.GetData(triggerPlayer)
        if updated then UpdateClientData:FireClient(triggerPlayer, updated) end

        -- Le brainrot est envoyé dans la base, le joueur reste à la machine
        if placedSlotIdx then
            print(string.format("[WheelSystem] ✅ Brainrot '%s' envoyé sur socle %d de la base", itemName, placedSlotIdx))
        else
            warn("[WheelSystem] Pas de placement — aucun socle vide dans la base")
        end

        print(string.format("[WheelSystem] %s → '%s' envoyé à la base depuis slot machine %d",
            triggerPlayer.Name, itemName, slotIdx))
    end)
end

-- Reconstruit les clones depuis la file d'attente de l'userId.
refreshMachineClones = function(userId: number)
    clearMachineClones()
    local items = pendingItems[userId] or {}
    print(string.format("[WheelSystem] refreshMachineClones(userId=%d) — %d items en attente", userId, #items))
    for i, entry in ipairs(items) do
        print(string.format("[WheelSystem]   Item %d : name='%s' itemId='%s'", i, entry.item.name, entry.item.itemId))
        local clone = spawnMiniCloneAtSlot(i, entry.item.name, entry.item.itemId)
        if clone then
            machineClones[i] = clone :: Instance
            attachSlotPrompts(i, clone :: Model, userId, entry)
            applyAura(clone :: Model, entry.rarity)
            print(string.format("[WheelSystem]   ✅ Clone %d placé avec succès", i))
        else
            warn(string.format("[WheelSystem]   ❌ Clone %d ÉCHOUÉ pour '%s'", i, entry.item.name))
        end
    end
    print(string.format("[WheelSystem] refreshMachineClones terminé — %d clones actifs dans MiniClones", #miniClonesFolder:GetChildren()))
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

    -- 5. Tirage — probabilité égale parmi tous les brainrots
    local winSegIdx    = math.random(1, N_SEGMENTS)
    local winItem      = SEGMENTS[winSegIdx].item
    local winRarity    = "COMMON"

    -- 6. Ajout dans la file d'attente (le clone apparaît APRÈS la fin du spin)
    table.insert(userPending, { item = winItem, rarity = winRarity })
    pendingItems[player.UserId] = userPending

    -- Compteur UI immédiat (le modèle reste caché jusqu'à la révélation)
    MachineUpdate:FireClient(player, { count = #userPending, max = MAX_SLOTS })

    print(string.format("[WheelSystem] %s → slot %d/%d : '%s' | seg%d/%d",
        player.Name, #userPending, MAX_SLOTS, winItem.name, winSegIdx, N_SEGMENTS))

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
    "[WheelSystem] Pret | CasinoMachine generee | %d socles | MiniClones isole | %d brainrots | proba egale",
    MAX_SLOTS, N_SEGMENTS))

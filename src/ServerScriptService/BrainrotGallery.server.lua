--!strict
-- BrainrotGallery.server.lua v3
-- Boulevard à deux côtés :
--   - Plots impairs  → côté NORD (Z = START_Z, galerie va vers +Z)
--   - Plots pairs    → côté SUD  (Z = START_Z_SOUTH, galerie va vers -Z)
-- Les deux rangées se font face à travers l'avenue centrale.

local Workspace           = game:GetService("Workspace")
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService        = game:GetService("TweenService")
local RunService          = game:GetService("RunService")

local DataManager   = require(ServerScriptService:WaitForChild("DataManager"))
local LootTables    = require(ReplicatedStorage:WaitForChild("LootTables"))
local BrainrotData  = require(ReplicatedStorage:WaitForChild("BrainrotData"))
local LegoRenderer  = require(ReplicatedStorage:WaitForChild("LegoRenderer"))

print("--- DIAGNOSTIC BRAINROT --- BrainrotGallery.server.lua démarre")

-- Dossier des modèles 3D (placeholders ou vrais modèles Toolbox)
-- BrainrotModelsSetup.server.lua le crée au démarrage → WaitForChild safe
local brainrotModelsFolder: Folder? = nil
task.spawn(function()
    task.wait(2)   -- laisse les modèles Toolbox finir de charger
    brainrotModelsFolder = ReplicatedStorage:WaitForChild("BrainrotModels", 20) :: Folder?
    if brainrotModelsFolder then
        local children = (brainrotModelsFolder :: Folder):GetChildren()
        print(string.format("[BrainrotGallery] BrainrotModels trouvé — %d enfants", #children))
        for _, child in ipairs(children) do
            print(string.format("  [BrainrotModels] '%s' (%s)", child.Name, child.ClassName))
        end
    else
        warn("[BrainrotGallery] BrainrotModels INTROUVABLE après 20s — vérifie le chemin ReplicatedStorage.BrainrotModels")
    end
end)

-- ── Récolte physique ──────────────────────────────────────────────────────────
-- [plotIndex][slotIndex] = {rate, accumulated, label, particles, sound, lastTouch}
local allAccumulators: {[number]: {[number]: any}} = {}
local totalHarvested:  {[number]: number}          = {}  -- session, par userId

local eventsFolder  = ReplicatedStorage:WaitForChild("Events")
local HarvestResult = eventsFolder:WaitForChild("HarvestResult")

-- ══════════════════════════════════════════════════════════════════════════════
-- NETTOYAGE AU DÉMARRAGE — supprime les bases orphelines/fantômes
-- ══════════════════════════════════════════════════════════════════════════════
for _, item in ipairs(Workspace:GetDescendants()) do
    if item.Name:find("BrainrotGallery_") or item.Name:find("Base_") then
        item:Destroy()
    end
end
print("[BrainrotGallery] Nettoyage des bases orphelines effectué.")

-- ══════════════════════════════════════════════════════════════════════════════
-- DOSSIER MAP
-- ══════════════════════════════════════════════════════════════════════════════
local mapFolder = Workspace:FindFirstChild("Map") or Instance.new("Folder")
if mapFolder.Parent ~= Workspace then
    mapFolder.Name   = "Map"
    mapFolder.Parent = Workspace
end

-- Sous-dossier dédié aux galeries des joueurs
local galleriesFolder = mapFolder:FindFirstChild("Galleries") or Instance.new("Folder")
if galleriesFolder.Parent ~= mapFolder then
    galleriesFolder.Name   = "Galleries"
    galleriesFolder.Parent = mapFolder
end

-- ══════════════════════════════════════════════════════════════════════════════
-- COULEURS
-- ══════════════════════════════════════════════════════════════════════════════
local COL_GOLD       = Color3.fromRGB(255, 215,   0)
local COL_PLAQUE     = Color3.fromRGB( 20,  20,  25)

local RARITY_PRIORITY: {[string]: number} = {ULTRA_LEGENDARY=6, ULTRA=5, LEGENDARY=4, MYTHIC=3, EPIC=3, RARE=2, COMMON=1, NORMAL=1}
-- Puissance générée par mème exposé (×1000 multiplicateur)
local POWER_PER_RARITY: {[string]: number} = {NORMAL=1000, COMMON=2000, RARE=5000, EPIC=15000, MYTHIC=10000, LEGENDARY=25000, ULTRA=50000, ULTRA_LEGENDARY=75000}
local RARITY_COLOR: {[string]: Color3} = {
    NORMAL          = Color3.fromRGB(163, 162, 165),
    COMMON          = Color3.fromRGB(120, 122, 126),
    RARE            = Color3.fromRGB(  0, 162, 255),
    EPIC            = Color3.fromRGB(255,   0, 255),
    MYTHIC          = Color3.fromRGB(170,   0, 255),
    LEGENDARY       = Color3.fromRGB(255, 170,   0),
    ULTRA           = Color3.fromRGB(255,   0, 127),
    ULTRA_LEGENDARY = Color3.fromRGB(255,  50,  50),
}

-- ══════════════════════════════════════════════════════════════════════════════
-- ITEM LOOKUP
-- ══════════════════════════════════════════════════════════════════════════════
local itemLookup: {[string]: {Name: string, Rarity: string}} = {}
for _, wheel in pairs(LootTables.Wheels) do
    for _, item in ipairs(wheel.Items) do
        if not itemLookup[item.Id] then
            itemLookup[item.Id] = {Name = item.Name, Rarity = item.Rarity}
        end
    end
end

-- Images gérées dans ReplicatedStorage/BrainrotData.lua (plus de table locale)

-- ══════════════════════════════════════════════════════════════════════════════
-- DIMENSIONS DE LA GALERIE
-- ══════════════════════════════════════════════════════════════════════════════
local NUM_SIDES   = 8          -- Socles de chaque côté (8×2 = 16 au total)
local PLACE_GAP   = 28         -- Espacement Z entre les socles (agrandi)
local SIDE_DIST   = 26         -- Distance X du centre au socle (reculé)
local CORRIDOR_W  = 64         -- Largeur du couloir (X) (massivement élargi)
local WALL_H      = 20         -- Hauteur des murs
local WALL_T      = 2          -- Épaisseur des murs
local FLOOR_Y     = 1          -- Y du sol
local GALLERY_LEN = (NUM_SIDES + 1) * PLACE_GAP  -- 144 studs

-- ── Placement des bases le long de l'avenue (axe X) ────────────────────────
local GRASS_LEVEL  = 0.5    -- Altitude du sol (Y)
local ESPACEMENT_X = 130    -- Espacement entre bases le long de l'avenue (axe X)
local FRONT_Z      = 195    -- Rangée nord — juste au-delà du bord nord avenue
local SOUTH_Z      = 25     -- Rangée sud  — juste au-delà du bord sud  avenue
-- ── Références avenue ────────────────────────────────────────────────────────
local START_Z       = 142   -- Bord nord de l'avenue
local START_Z_SOUTH =  78   -- Bord sud  de l'avenue

-- ══════════════════════════════════════════════════════════════════════════════
-- SYSTÈME DE PARCELLES — limité à 8 (4 de chaque côté)
-- ══════════════════════════════════════════════════════════════════════════════
local PLOT_STEP = CORRIDOR_W + 8   -- 52 studs entre galeries (axe X)
local MAX_PLOTS = 8

local nextPlotIndex                      = 1
local plotAssignments: {[number]: number} = {}  -- [userId] = plotIndex

-- Retourne (offsetX, baseEntranceZ, zDir) pour un plotIndex donné
local function getPlotParams(plotIndex: number): (number, number, number)
    local isNorth = (plotIndex % 2 == 1)
    local rank    = math.ceil(plotIndex / 2)  -- rang au sein du côté (1, 2, 3...)

    local offsetX: number
    if rank == 1 then
        offsetX = 0
    else
        local n = math.ceil((rank - 1) / 2)
        offsetX = ((rank - 1) % 2 == 1) and (n * PLOT_STEP) or (-n * PLOT_STEP)
    end

    local baseZ = isNorth and START_Z or START_Z_SOUTH
    local zDir  = isNorth and 1 or -1
    return offsetX, baseZ, zDir
end

-- État par parcelle
type PedestalRef = {top: Part, nameLabel: TextLabel, decal: Decal, powerLabel: TextLabel}
type PlotState = {
    folder       : Folder,
    pedestalRefs : {[number]: PedestalRef},
    displayParts : {[number]: any},
    signLabelRef : TextLabel?,
}
local plotState: {[number]: PlotState} = {}

-- ══════════════════════════════════════════════════════════════════════════════
-- TEXTE FLOTTANT DE RÉCOLTE
-- ══════════════════════════════════════════════════════════════════════════════
local FLOAT_TWEEN = TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function showFloatingText(worldPos: Vector3, amount: number)
    -- Part invisible ancré au point de récolte
    local anchor = Instance.new("Part")
    anchor.Name        = "HarvestFloat"
    anchor.Size        = Vector3.new(0.1, 0.1, 0.1)
    anchor.CFrame      = CFrame.new(worldPos)
    anchor.Anchored    = true
    anchor.CanCollide  = false
    anchor.Transparency = 1
    anchor.CastShadow  = false
    anchor.Parent      = Workspace

    local bb = Instance.new("BillboardGui")
    bb.Size        = UDim2.new(0, 160, 0, 44)
    bb.StudsOffset = Vector3.new(0, 1.5, 0)
    bb.AlwaysOnTop = false
    bb.MaxDistance = 40
    bb.Parent      = anchor

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = "+" .. amount .. " ⚡"
    lbl.TextColor3             = Color3.fromRGB(255, 225, 0)
    lbl.Font                   = Enum.Font.GothamBlack
    lbl.TextScaled             = true
    lbl.TextStrokeTransparency = 0
    lbl.TextStrokeColor3       = Color3.new(0, 0, 0)
    lbl.Parent                 = bb

    -- Monte de 5 studs en 1.5s
    TweenService:Create(anchor, FLOAT_TWEEN,
        { CFrame = CFrame.new(worldPos + Vector3.new(0, 5, 0)) }
    ):Play()
    -- Disparaît progressivement
    TweenService:Create(lbl, FLOAT_TWEEN,
        { TextTransparency = 1, TextStrokeTransparency = 1 }
    ):Play()

    task.delay(1.6, function() anchor:Destroy() end)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- CONSTRUCTEUR DE GALERIE
-- ══════════════════════════════════════════════════════════════════════════════
local function buildGallery(player: Player, plotIndex: number): PlotState
    local playerName = player.Name
    local userId     = player.UserId

    -- Côté nord/sud de l'avenue et colonne le long de X
    local isNorth = (plotIndex % 2 == 1)
    local slotCol = math.floor((plotIndex - 1) / 2)  -- 0,0,1,1,2,2,3,3

    -- Bases réparties est-ouest (axe X), une rangée de chaque côté de l'avenue
    local targetX       = (slotCol - 1.5) * ESPACEMENT_X   -- centré sur X=0
    local targetZ       = isNorth and FRONT_Z or SOUTH_Z
    local offsetX       = targetX
    local baseEntranceZ = targetZ
    local zDir          = isNorth and -1 or 1  -- nord ouvre vers l'avenue (-Z), sud vers +Z

    local function worldZ(localZ: number): number
        return baseEntranceZ + zDir * (localZ - START_Z)
    end

    -- ── MARQUEUR DE DIAGNOSTIC INCONDITIONNEL ────────────────────────────────
    -- Cube magenta + label visible même si le prefab est absent
    do
        local dbgCube = Instance.new("Part")
        dbgCube.Name         = "DiagMarker_" .. plotIndex
        dbgCube.Size         = Vector3.new(6, 6, 6)
        dbgCube.CFrame       = CFrame.new(targetX, GRASS_LEVEL + 30, targetZ)
        dbgCube.Anchored     = true
        dbgCube.CanCollide   = false
        dbgCube.Transparency = 0
        dbgCube.Color        = Color3.fromRGB(255, 0, 255)
        dbgCube.Material     = Enum.Material.Neon
        dbgCube.Parent       = galleriesFolder

        local dbgBb = Instance.new("BillboardGui")
        dbgBb.Adornee     = dbgCube
        dbgBb.Size        = UDim2.new(0, 220, 0, 90)
        dbgBb.StudsOffset = Vector3.new(0, 7, 0)
        dbgBb.AlwaysOnTop = true
        dbgBb.MaxDistance = 3000
        dbgBb.Parent      = dbgCube

        local dbgLbl = Instance.new("TextLabel")
        dbgLbl.Size                   = UDim2.new(1, 0, 1, 0)
        dbgLbl.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
        dbgLbl.BackgroundTransparency = 0.2
        dbgLbl.Text                   = string.format("BASE %d\nX=%.0f Z=%.0f", plotIndex, targetX, targetZ)
        dbgLbl.TextColor3             = Color3.fromRGB(255, 255, 0)
        dbgLbl.Font                   = Enum.Font.GothamBlack
        dbgLbl.TextScaled             = true
        dbgLbl.Parent                 = dbgBb

        print(string.format("[BrainrotGallery] DIAG BASE %d → X=%.0f Z=%.0f (nord=%s col=%d)",
            plotIndex, targetX, targetZ, tostring(isNorth), slotCol))
    end

    -- ══════════════════════════════════════════════════════════════════════
    -- CLONAGE DU PREFAB "Steal A Brainrot Base"
    -- GetBoundingBox appliqué UNIQUEMENT sur le Model cloné, jamais sur folder.
    -- ══════════════════════════════════════════════════════════════════════

    -- Recherche du prefab base : tous les noms possibles
    local BASE_NAMES = { "Base1", "base", "base1", "BrainrotBase", "Steal A Brainrot Base" }
    local basePrefab: Instance? = nil

    -- 1. Recherche directe au premier niveau
    for _, tryName in ipairs(BASE_NAMES) do
        basePrefab = ReplicatedStorage:FindFirstChild(tryName)
        if basePrefab then break end
    end

    -- 2. Recherche récursive
    if not basePrefab then
        for _, tryName in ipairs(BASE_NAMES) do
            basePrefab = ReplicatedStorage:FindFirstChild(tryName, true)
            if basePrefab then
                print(string.format("[BrainrotGallery] Prefab '%s' trouvé en profondeur → %s", tryName, basePrefab:GetFullName()))
                break
            end
        end
    end

    if not basePrefab then
        warn("[BrainrotGallery] ERREUR : Impossible de trouver le prefab base dans ReplicatedStorage !")
        warn("[BrainrotGallery] Contenu de ReplicatedStorage :")
        for _, child in ipairs(ReplicatedStorage:GetChildren()) do
            warn(string.format("  → '%s' (%s) [%d enfants]", child.Name, child.ClassName, #child:GetChildren()))
        end
    end

    local baseClone: Model? = nil
    if basePrefab then
        local raw = basePrefab:Clone()

        -- Garantir un Model (PivotTo + GetBoundingBox exigent un Model)
        local mdl: Model
        if raw:IsA("Model") then
            mdl = raw :: Model
        else
            warn(string.format("[BrainrotGallery] Prefab est un %s → emballage dans un Model", raw.ClassName))
            mdl = Instance.new("Model")
            mdl.Name = raw.Name
            raw.Parent = mdl
            local bp = mdl:FindFirstChildWhichIsA("BasePart", true)
            if bp then mdl.PrimaryPart = bp :: BasePart end
        end
        mdl.Name = "BrainrotGallery_" .. tostring(userId)

        -- Mesurage robuste : GetBoundingBox donne centre ET taille du Model
        -- On calcule l'écart entre le pivot actuel et le bas du bounding box
        -- pour que le bas touche exactement GRASS_LEVEL, peu importe où est le pivot.
        local bbCF, bbSize = mdl:GetBoundingBox()
        local currentPivotY  = mdl:GetPivot().Position.Y
        local bbBottomY      = bbCF.Position.Y - bbSize.Y / 2
        local pivotToBottom  = currentPivotY - bbBottomY   -- offset pivot → bas

        -- Bases le long de l'avenue :
        local targetY = GRASS_LEVEL + pivotToBottom
        -- Rotation : entrée face à l'avenue (nord → regarde sud, sud → regarde nord)
        local rot = isNorth and math.rad(180) or math.rad(0)

        mdl:PivotTo(CFrame.new(targetX, targetY, targetZ) * CFrame.Angles(0, rot, 0))

        for _, v in ipairs(mdl:GetDescendants()) do
            if v:IsA("BasePart") then (v :: BasePart).Anchored = true end
        end
        mdl.Parent = galleriesFolder

        -- Numéro flottant au-dessus de la base (debug visuel)
        local anchor = Instance.new("Part")
        anchor.Name         = "DebugAnchor_" .. plotIndex
        anchor.Size         = Vector3.new(4, 4, 4)
        anchor.CFrame       = CFrame.new(targetX, targetY + bbSize.Y / 2 + 20, targetZ)
        anchor.Anchored     = true
        anchor.CanCollide   = false
        anchor.Transparency = 0
        anchor.Color        = Color3.fromRGB(255, 0, 0)
        anchor.Material     = Enum.Material.Neon
        anchor.Parent       = galleriesFolder

        local bb = Instance.new("BillboardGui")
        bb.Name        = "DebugBB_" .. plotIndex
        bb.Adornee     = anchor
        bb.Size        = UDim2.new(0, 200, 0, 80)
        bb.StudsOffset = Vector3.new(0, 6, 0)
        bb.AlwaysOnTop = true
        bb.MaxDistance = 2000
        bb.Parent      = anchor

        local lbl = Instance.new("TextLabel")
        lbl.Size                   = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
        lbl.BackgroundTransparency = 0
        lbl.Text                   = "BASE " .. plotIndex
        lbl.TextColor3             = Color3.fromRGB(255, 255, 0)
        lbl.Font                   = Enum.Font.GothamBlack
        lbl.TextScaled             = true
        lbl.Parent                 = bb

        print(string.format(
            "[BrainrotGallery] Base '%s' pour %s — X=%.0f Y=%.1f Z=%.0f | size=(%.0f,%.0f,%.0f) pivotOffset=%.1f",
            playerName, playerName, targetX, targetY, targetZ, bbSize.X, bbSize.Y, bbSize.Z, pivotToBottom))

        baseClone = mdl
    end

    -- Folder de travail : le clone Model, ou un Folder vide en dernier recours
    local folder: Instance
    if baseClone then
        folder = baseClone :: Model
    else
        local fallback = Instance.new("Folder")
        fallback.Name   = "BrainrotGallery_" .. tostring(userId)
        fallback.Parent = mapFolder
        folder = fallback
        warn("[BrainrotGallery] Fallback folder vide pour " .. playerName)
    end

    -- ══════════════════════════════════════════════════════════════════════
    -- SCAN DYNAMIQUE DES SOCLES DANS LE PREFAB
    -- Cherche toutes les Parts dont le nom contient "PedestalTop", "Pedestal",
    -- "Stand", "Podium", "Display" ou similaire.
    -- Si aucun trouvé, utilise toutes les BaseParts de petite taille comme socles.
    -- ══════════════════════════════════════════════════════════════════════
    local pedestalRefs: {[number]: PedestalRef} = {}

    -- Diagnostic : lister tous les descendants du prefab
    print(string.format("[BrainrotGallery] DIAGNOSTIC — Contenu du prefab pour %s (%d descendants) :", playerName, #folder:GetDescendants()))
    for _, v in pairs(folder:GetDescendants()) do
        if v:IsA("BasePart") then
            local bp = v :: BasePart
            print(string.format("  [Part] '%s' size=(%.1f,%.1f,%.1f) pos=(%.1f,%.1f,%.1f)",
                v.Name, bp.Size.X, bp.Size.Y, bp.Size.Z, bp.Position.X, bp.Position.Y, bp.Position.Z))
        end
    end

    -- Trouver tous les "PedestalTop" / "Pedestal" / "Stand" / "Podium" / "Display" dans le clone
    local PEDESTAL_KEYWORDS = { "pedestaltop", "pedestal", "stand", "podium", "display", "socle", "plate" }
    local pedestalTops: {BasePart} = {}
    for _, v in pairs(folder:GetDescendants()) do
        if v:IsA("BasePart") then
            local lowerName = string.lower(v.Name)
            for _, kw in ipairs(PEDESTAL_KEYWORDS) do
                if string.find(lowerName, kw) then
                    table.insert(pedestalTops, v :: BasePart)
                    break
                end
            end
        end
    end

    -- Fallback : si aucun socle trouvé par nom, prendre les petites parts plates (Y < 3, surface > 4)
    if #pedestalTops == 0 then
        print("[BrainrotGallery] Aucun socle trouvé par mot-clé — fallback sur petites parts plates")
        for _, v in pairs(folder:GetDescendants()) do
            if v:IsA("BasePart") then
                local bp = v :: BasePart
                -- Petite part plate : hauteur faible, surface raisonnable
                if bp.Size.Y <= 3 and bp.Size.X >= 2 and bp.Size.Z >= 2 and bp.Size.X <= 12 and bp.Size.Z <= 12 then
                    table.insert(pedestalTops, bp)
                end
            end
        end
        print(string.format("[BrainrotGallery] Fallback : %d parts plates trouvées", #pedestalTops))
    end

    -- Trier par Z puis par X (gauche avant droite)
    table.sort(pedestalTops, function(a, b)
        if math.abs(a.Position.Z - b.Position.Z) > 2 then
            return a.Position.Z < b.Position.Z
        end
        return a.Position.X < b.Position.X
    end)

    print(string.format("[BrainrotGallery] %d PedestalTop trouvés dans le prefab pour %s",
        #pedestalTops, playerName))

    for slotIndex, topPart in ipairs(pedestalTops) do
        -- Créer un nameLabel basique sur le socle
        local sGui = Instance.new("SurfaceGui")
        sGui.Name        = "NamePlaque"
        sGui.Face        = Enum.NormalId.Top
        sGui.CanvasSize  = Vector2.new(350, 60)
        sGui.SizingMode  = Enum.SurfaceGuiSizingMode.FixedSize
        sGui.AlwaysOnTop = false
        sGui.Parent      = topPart

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size                   = UDim2.new(1, 0, 1, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text                   = "Slot " .. slotIndex
        nameLabel.TextColor3             = COL_GOLD
        nameLabel.Font                   = Enum.Font.GothamBold
        nameLabel.TextSize               = 22
        nameLabel.TextXAlignment         = Enum.TextXAlignment.Center
        nameLabel.TextYAlignment         = Enum.TextYAlignment.Center
        nameLabel.TextStrokeTransparency = 0.6
        nameLabel.TextStrokeColor3       = Color3.new(0, 0, 0)
        nameLabel.Parent                 = sGui

        -- Decal placeholder (pour l'image si on en a besoin)
        local decal = Instance.new("Decal")
        decal.Name    = "MemeDisplay"
        decal.Texture = ""
        decal.Parent  = topPart

        -- Power label billboard
        local powerBb = Instance.new("BillboardGui")
        powerBb.Size        = UDim2.new(0, 120, 0, 26)
        powerBb.StudsOffset = Vector3.new(0, 6, 0)
        powerBb.Adornee     = topPart
        powerBb.AlwaysOnTop = false
        powerBb.MaxDistance = 35
        powerBb.Parent      = folder

        local powerLbl = Instance.new("TextLabel")
        powerLbl.Size                   = UDim2.new(1, 0, 1, 0)
        powerLbl.BackgroundTransparency = 1
        powerLbl.Text                   = ""
        powerLbl.TextColor3             = Color3.fromRGB(100, 220, 255)
        powerLbl.Font                   = Enum.Font.GothamBold
        powerLbl.TextScaled             = true
        powerLbl.TextStrokeTransparency = 0.3
        powerLbl.TextStrokeColor3       = Color3.new(0, 0, 0)
        powerLbl.Parent                 = powerBb

        pedestalRefs[slotIndex] = {top = topPart, nameLabel = nameLabel, decal = decal, powerLabel = powerLbl}
    end

    -- ══════════════════════════════════════════════════════════════════════
    -- ZONES DE RÉCOLTE (créées dynamiquement à côté de chaque socle)
    -- ══════════════════════════════════════════════════════════════════════
    if not allAccumulators[plotIndex] then
        allAccumulators[plotIndex] = {}
    end

    for slotIndex, refs in pairs(pedestalRefs) do
        local topPart = refs.top
        local platePos = topPart.Position - Vector3.new(0, topPart.Position.Y - FLOOR_Y - 0.2, 0)

        local plate = Instance.new("Part")
        plate.Name      = "CollectorPlate_" .. slotIndex
        plate.Size      = Vector3.new(10, 0.2, 10)
        plate.Position  = Vector3.new(topPart.Position.X, FLOOR_Y + 0.2, topPart.Position.Z)
        plate.Anchored  = true
        plate.CanCollide = false
        plate.Material  = Enum.Material.Neon
        plate.Color     = Color3.fromRGB(0, 200, 80)
        plate.CastShadow = false
        plate.Parent    = folder

        -- Particules
        local particles = Instance.new("ParticleEmitter")
        particles.Texture       = "rbxassetid://243160943"
        particles.LightEmission = 0.9
        particles.Color         = ColorSequence.new(Color3.fromRGB(255, 215, 0))
        particles.Size          = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.6),
            NumberSequenceKeypoint.new(1, 0),
        })
        particles.Speed         = NumberRange.new(8, 16)
        particles.Lifetime      = NumberRange.new(0.5, 1.0)
        particles.Rate          = 0
        particles.VelocitySpread = 55
        particles.Enabled       = false
        particles.Parent        = plate

        -- Son
        local harvestSound = Instance.new("Sound")
        harvestSound.SoundId   = "rbxassetid://5153734135"
        harvestSound.Volume    = 0.7
        harvestSound.RollOffMaxDistance = 30
        harvestSound.Parent    = plate

        -- Label au-dessus de la zone
        local harvestBb = Instance.new("BillboardGui")
        harvestBb.Size        = UDim2.new(0, 120, 0, 30)
        harvestBb.StudsOffset = Vector3.new(0, 2.2, 0)
        harvestBb.Adornee     = plate
        harvestBb.AlwaysOnTop = false
        harvestBb.MaxDistance = 30
        harvestBb.Parent      = folder

        local harvestLbl = Instance.new("TextLabel")
        harvestLbl.Size                   = UDim2.new(1, 0, 1, 0)
        harvestLbl.BackgroundTransparency = 1
        harvestLbl.Text                   = "0 ⚡"
        harvestLbl.TextColor3             = Color3.fromRGB(255, 220, 0)
        harvestLbl.Font                   = Enum.Font.GothamBold
        harvestLbl.TextScaled             = true
        harvestLbl.TextStrokeTransparency = 0.3
        harvestLbl.TextStrokeColor3       = Color3.new(0, 0, 0)
        harvestLbl.Parent                 = harvestBb

        local accRef = {
            rate        = 0,
            accumulated = 0,
            label       = harvestLbl,
            particles   = particles,
            sound       = harvestSound,
            lastTouch   = 0,
        }
        allAccumulators[plotIndex][slotIndex] = accRef

        -- Récolte au toucher (propriétaire uniquement)
        plate.Touched:Connect(function(hit)
            if not hit.Parent then return end
            local humanoid = hit.Parent:FindFirstChildOfClass("Humanoid")
            if not humanoid then return end
            local pl = Players:GetPlayerFromCharacter(hit.Parent)
            if not pl then return end
            if plotAssignments[pl.UserId] ~= plotIndex then return end

            local now = tick()
            if now - accRef.lastTouch < 1 then return end
            accRef.lastTouch = now

            local amount = math.floor(accRef.accumulated)
            if amount <= 0 then return end

            accRef.accumulated = 0
            accRef.label.Text  = "0 ⚡"

            local ls = pl:FindFirstChild("leaderstats")
            local pv = ls and ls:FindFirstChild("⚡ Power")
            if pv then pv.Value = pv.Value + amount end

            DataManager.AddPower(pl, amount)

            totalHarvested[pl.UserId] = (totalHarvested[pl.UserId] or 0) + amount
            HarvestResult:FireClient(pl, amount, totalHarvested[pl.UserId])

            showFloatingText(plate.Position + Vector3.new(0, 0.5, 0), amount)

            accRef.particles:Emit(30)
            accRef.sound:Play()
            plate.Color = Color3.fromRGB(255, 255, 100)
            task.delay(0.3, function()
                plate.Color = Color3.fromRGB(255, 215, 0)
            end)
        end)
    end

    -- Helper mp pour le reste (enseigne, etc.) qui en a encore besoin
    local function mp(
        name    : string,
        size    : Vector3,
        localPos: Vector3,
        color   : Color3,
        material: Enum.Material,
        topSurf : Enum.SurfaceType?
    ): Part
        local p = Instance.new("Part")
        p.Name          = name
        p.Size          = size
        p.Position      = Vector3.new(localPos.X + offsetX, localPos.Y, worldZ(localPos.Z))
        p.Anchored      = true
        p.CanCollide    = true
        p.Color         = color
        p.Material      = material
        p.Reflectance   = 0
        p.CastShadow    = false
        p.TopSurface    = topSurf or Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        p.Parent        = folder
        return p
    end

    -- ══════════════════════════════════════════════════════════════════════
    -- ANCIENNE CONSTRUCTION PROCÉDURALE SUPPRIMÉE (remplacée par le prefab)
    -- Les sections 1-4 (sol, plafond, murs, socles) sont dans le prefab cloné.
    -- ══════════════════════════════════════════════════════════════════════

    -- ── 6. ENSEIGNE (GallerySignPlaque — CRITIQUE pour le client) ───────────
    local signPlaque = mp("GallerySignPlaque",
        Vector3.new(CORRIDOR_W - 4, 5, 3),
        Vector3.new(0, FLOOR_Y + WALL_H - 2, START_Z - 6),
        COL_PLAQUE, Enum.Material.SmoothPlastic)
    signPlaque.CanCollide = false

    local signRim = mp("GallerySignRim",
        Vector3.new(CORRIDOR_W - 2, 5.5, 0.4),
        Vector3.new(0, FLOOR_Y + WALL_H - 2, START_Z - 4.3),
        COL_GOLD, Enum.Material.Metal)
    signRim.CanCollide = false

    local signSGui = Instance.new("SurfaceGui")
    signSGui.Name           = "GallerySignGui"
    signSGui.Face           = zDir == 1 and Enum.NormalId.Front or Enum.NormalId.Back
    signSGui.CanvasSize     = Vector2.new(520, 100)
    signSGui.SizingMode     = Enum.SurfaceGuiSizingMode.FixedSize
    signSGui.LightInfluence = 0
    signSGui.AlwaysOnTop    = false
    signSGui.ZOffset        = 1
    signSGui.Parent         = signPlaque

    local signLabel = Instance.new("TextLabel")
    signLabel.Name                   = "GallerySignLabel"
    signLabel.Size                   = UDim2.new(1, 0, 1, 0)
    signLabel.BackgroundColor3       = Color3.fromRGB(0, 0, 255)
    signLabel.BackgroundTransparency = 0.1
    signLabel.Text                   = "★  BASE DE " .. string.upper(playerName) .. "  ★"
    signLabel.TextColor3             = Color3.fromRGB(255, 255, 255)
    signLabel.Font                   = Enum.Font.GothamBlack
    signLabel.TextScaled             = true
    signLabel.TextStrokeTransparency = 0
    signLabel.TextStrokeColor3       = Color3.new(0, 0, 0)
    signLabel.Parent                 = signSGui

    Instance.new("UICorner", signLabel).CornerRadius = UDim.new(0, 8)

    -- ── 7. LAMPADAIRES D'ENTRÉE ─────────────────────────────────────────────
    do
        local LAMP_POLE_COLOR = Color3.fromRGB(50, 50, 55)
        local LAMP_BULB_COLOR = Color3.fromRGB(255, 220, 120)
        local poleH = 16

        for _, side in ipairs({-1, 1}) do
            local sLbl = side == -1 and "L" or "R"
            local lx   = side * (CORRIDOR_W / 2 + 1)
            local lz   = START_Z - 4

            mp("EntryPole_" .. sLbl,
                Vector3.new(1, poleH, 1),
                Vector3.new(lx, FLOOR_Y + poleH / 2, lz),
                LAMP_POLE_COLOR, Enum.Material.Metal).CanCollide = false

            mp("EntryLampCap_" .. sLbl,
                Vector3.new(2.8, 0.5, 2.8),
                Vector3.new(lx, FLOOR_Y + poleH + 0.25, lz),
                LAMP_POLE_COLOR, Enum.Material.Metal).CanCollide = false

            local bulb = mp("EntryLampBulb_" .. sLbl,
                Vector3.new(2, 1.5, 2),
                Vector3.new(lx, FLOOR_Y + poleH - 0.5, lz),
                LAMP_BULB_COLOR, Enum.Material.SmoothPlastic)
            bulb.CanCollide = false

            local light = Instance.new("PointLight")
            light.Color      = LAMP_BULB_COLOR
            light.Brightness = 3
            light.Range      = 22
            light.Shadows    = true
            light.Parent     = bulb
        end
    end

    -- ── 8. LUMIÈRES DE PLAFOND ──────────────────────────────────────────────
    for j = 1, NUM_SIDES do
        local lightZ    = START_Z + j * PLACE_GAP
        local lightPart = mp("CeilingLight_" .. j,
            Vector3.new(1.5, 0.3, 1.5),
            Vector3.new(0, FLOOR_Y + WALL_H - 0.5, lightZ),
            Color3.fromRGB(255, 255, 240), Enum.Material.SmoothPlastic)
        lightPart.CanCollide = false

        local pt = Instance.new("PointLight")
        pt.Brightness = 1.5
        pt.Range      = 16
        pt.Color      = Color3.fromRGB(255, 245, 210)
        pt.Shadows    = false
        pt.Parent     = lightPart
    end

    -- ── 9. LUMIÈRES D'AMBIANCE ──────────────────────────────────────────────
    local edgeX = CORRIDOR_W / 2 - WALL_T - 4
    local midY  = FLOOR_Y + WALL_H / 2

    local ambPositions = {
        Vector3.new(-edgeX, midY, worldZ(START_Z + 2)),
        Vector3.new( edgeX, midY, worldZ(START_Z + 2)),
        Vector3.new(-edgeX, midY, worldZ(START_Z + GALLERY_LEN + 2)),
        Vector3.new( edgeX, midY, worldZ(START_Z + GALLERY_LEN + 2)),
        Vector3.new(-edgeX, midY, worldZ(START_Z + GALLERY_LEN * 0.33)),
        Vector3.new( edgeX, midY, worldZ(START_Z + GALLERY_LEN * 0.33)),
        Vector3.new(-edgeX, midY, worldZ(START_Z + GALLERY_LEN * 0.66)),
        Vector3.new( edgeX, midY, worldZ(START_Z + GALLERY_LEN * 0.66)),
    }

    for k, pos in ipairs(ambPositions) do
        local amb = Instance.new("Part")
        amb.Name         = "AmbientLight_" .. k
        amb.Size         = Vector3.new(0.2, 0.2, 0.2)
        amb.Position     = Vector3.new(pos.X + offsetX, pos.Y, pos.Z)
        amb.Anchored     = true
        amb.CanCollide   = false
        amb.Transparency = 1
        amb.CastShadow   = false
        amb.Parent       = folder

        local pl = Instance.new("PointLight")
        pl.Color      = Color3.fromRGB(255, 255, 255)
        pl.Brightness = 3.5
        pl.Range      = 25
        pl.Shadows    = false
        pl.Parent     = amb
    end

    -- Ancrage final de toutes les BaseParts
    for _, v in pairs(folder:GetDescendants()) do
        if v:IsA("BasePart") then (v :: BasePart).Anchored = true end
    end

    local side_lbl = zDir == 1 and "Nord" or "Sud"
    print(string.format("[BrainrotGallery] Galerie #%d (%s) → %s | X=%d | Z_entree=%d",
        plotIndex, side_lbl, playerName, offsetX, baseEntranceZ))

    return {
        folder       = folder,
        pedestalRefs = pedestalRefs,
        displayParts = {},
        signLabelRef = signLabel,
    }
end

-- ══════════════════════════════════════════════════════════════════════════════
-- FIGURINES — modèle 3D depuis BrainrotModels, sinon cube de couleur
-- ══════════════════════════════════════════════════════════════════════════════
local TARGET_SIZE      = 12.5 -- dimension max cible (studs) — réduit de 50%

-- Noms de parts à cacher (hitbox / cubes blancs)
local HITBOX_NAMES: {[string]: boolean} = {
    HumanoidRootPart = true, Root = true, Hitbox = true,
    CollisionBox = true, Handle = true,
}

-- Rotation continue Heartbeat
local SPIN_SPEED = 1.2  -- rad/s
local spinningFigurines: {{instance: Instance, center: Vector3}} = {}


local function addFigurineEffects(root: BasePart, rarityColor: Color3, rarity: string)
    local isHigh = rarity == "EPIC" or rarity == "LEGENDARY" or rarity == "ULTRA" or rarity == "ULTRA_LEGENDARY"

    if isHigh then
        local light      = Instance.new("PointLight")
        light.Color      = rarityColor
        light.Brightness = if rarity == "ULTRA_LEGENDARY" then 3 else 1.5
        light.Range      = if rarity == "ULTRA_LEGENDARY" then 12 else 7
        light.Parent     = root
    end

    -- Aura VIOLET mouvante pour EPIC
    if rarity == "EPIC" then
        local pt               = Instance.new("ParticleEmitter")
        pt.Texture             = "rbxassetid://299324419"
        pt.Color               = ColorSequence.new(Color3.fromRGB(170, 0, 255))
        pt.LightEmission       = 1
        pt.LightInfluence      = 0
        pt.Size                = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.3),
            NumberSequenceKeypoint.new(0.5, 1.2),
            NumberSequenceKeypoint.new(1, 0),
        })
        pt.Transparency        = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.2),
            NumberSequenceKeypoint.new(0.6, 0.4),
            NumberSequenceKeypoint.new(1, 1),
        })
        pt.Speed               = NumberRange.new(2, 5)
        pt.Acceleration        = Vector3.new(0, 8, 0)
        pt.Lifetime            = NumberRange.new(0.5, 1.0)
        pt.Rate                = 25
        pt.LockedToPart        = true
        pt.Enabled             = true
        pt.Parent              = root
    end

    -- Aura JAUNE/OR intense pour LEGENDARY + ULTRA_LEGENDARY
    if rarity == "LEGENDARY" or rarity == "ULTRA_LEGENDARY" then
        local pt               = Instance.new("ParticleEmitter")
        pt.Texture             = "rbxassetid://299324419"
        pt.Color               = ColorSequence.new(Color3.fromRGB(255, 200, 0))
        pt.LightEmission       = 1
        pt.LightInfluence      = 0
        pt.Size                = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.4),
            NumberSequenceKeypoint.new(0.4, 1.8),
            NumberSequenceKeypoint.new(1, 0),
        })
        pt.Transparency        = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.1),
            NumberSequenceKeypoint.new(0.6, 0.3),
            NumberSequenceKeypoint.new(1, 1),
        })
        pt.Speed               = NumberRange.new(4, 8)
        pt.Acceleration        = Vector3.new(0, 15, 0)
        pt.Lifetime            = NumberRange.new(0.6, 1.2)
        pt.Rate                = if rarity == "ULTRA_LEGENDARY" then 50 else 35
        pt.LockedToPart        = true
        pt.Enabled             = true
        pt.Parent              = root
    end

    if rarity == "ULTRA" or rarity == "ULTRA_LEGENDARY" then
        local sp        = Instance.new("Sparkles")
        sp.SparkleColor = rarityColor
        sp.Parent       = root
    end
end

local function addFigurineBillboard(adornee: Instance, offsetY: number,
                                    itemName: string, rarityColor: Color3)
    local bb = Instance.new("BillboardGui")
    bb.Size        = UDim2.new(0, 200, 0, 38)
    bb.StudsOffset = Vector3.new(0, offsetY, 0)
    bb.AlwaysOnTop = false
    bb.MaxDistance = 40
    bb.Adornee     = adornee
    bb.Parent      = adornee

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = itemName
    lbl.TextColor3             = rarityColor
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextScaled             = true
    lbl.TextStrokeTransparency = 0.3
    lbl.TextStrokeColor3       = Color3.new(0, 0, 0)
    lbl.Parent                 = bb
end

-- Recherche insensible à la casse dans BrainrotModels.
-- Accepte TOUT type d'Instance (Model, MeshPart, Part, Folder, etc.)
-- Si plusieurs enfants ont le même nom, préfère le plus riche en descendants.
-- Retourne l'Instance trouvée, ou nil si vraiment absente.
local function findBrainrotModel(name: string): Instance?
    if not brainrotModelsFolder then
        warn("[BrainrotGallery] findBrainrotModel: brainrotModelsFolder est nil — modèles pas encore chargés")
        return nil
    end
    local lowerName = string.lower(name)
    local best: Instance? = nil
    local bestCount = -1

    -- Construit la liste des candidats : enfants directs + enfants de sous-conteneurs
    -- (gère le cas où tous les modèles sont regroupés dans un seul .rbxm ex: "Brainrots")
    local candidates: {Instance} = {}
    for _, child in ipairs((brainrotModelsFolder :: Folder):GetChildren()) do
        table.insert(candidates, child)
        if child:IsA("Model") or child:IsA("Folder") then
            for _, grandchild in ipairs(child:GetChildren()) do
                table.insert(candidates, grandchild)
            end
        end
    end

    for _, child in ipairs(candidates) do
        local childLower = string.lower(child.Name)
        if childLower == lowerName then
            local n = #child:GetDescendants()
            if n > bestCount then
                bestCount = n
                best      = child
            end
        end
    end

    if not best then
        warn(string.format("[BrainrotGallery] Modèle '%s' introuvable dans BrainrotModels (ni direct ni sous-conteneur).", name))
    end
    return best
end

local function createFigurine(state: PlotState, slotIndex: number, itemData: any)
    -- Détruire l'ancienne figurine
    if state.displayParts[slotIndex] then
        -- Retirer de la rotation
        for idx = #spinningFigurines, 1, -1 do
            if spinningFigurines[idx].instance == state.displayParts[slotIndex] then
                table.remove(spinningFigurines, idx)
                break
            end
        end
        (state.displayParts[slotIndex] :: Instance):Destroy()
        state.displayParts[slotIndex] = nil
    end
    if not itemData then return end

    local refs = state.pedestalRefs[slotIndex]
    if not refs then return end

    local topPart     = refs.top
    local rarityColor = RARITY_COLOR[itemData.Rarity] or RARITY_COLOR.NORMAL

    -- Y absolu du dessus du socle
    local socleTopY = topPart.Position.Y + topPart.Size.Y / 2
    local socleX    = topPart.Position.X
    local socleZ    = topPart.Position.Z

    local template = findBrainrotModel(itemData.Name)

    if template then
        local clone = template:Clone()
        clone.Name   = "Figurine_" .. slotIndex
        clone.Parent = state.folder  -- parent AVANT PivotTo/ScaleTo

        -- ════════════════════════════════════════════════════════════════════
        -- A. ANCRAGE + HITBOX INVISIBLE
        -- ════════════════════════════════════════════════════════════════════
        local primaryPart: BasePart? = clone:IsA("Model") and (clone :: Model).PrimaryPart or nil

        if clone:IsA("BasePart") then
            (clone :: BasePart).Anchored   = true;
            (clone :: BasePart).CanCollide = false
        end
        for _, part in ipairs(clone:GetDescendants()) do
            if part:IsA("BasePart") then
                local bp = part :: BasePart
                bp.Anchored   = true
                bp.CanCollide = false
                -- Cacher les hitbox / cubes blancs
                if HITBOX_NAMES[bp.Name] or bp == primaryPart then
                    bp.Transparency = 1
                end
            end
        end

        -- ════════════════════════════════════════════════════════════════════
        -- B. GARANTIR UN PRIMARY PART (visible de préférence)
        -- ════════════════════════════════════════════════════════════════════
        if clone:IsA("Model") then
            local mdl = clone :: Model
            if not mdl.PrimaryPart or (mdl.PrimaryPart :: BasePart).Transparency >= 1 then
                local bestBp: BasePart? = nil
                local bestVol = 0
                for _, p in ipairs(mdl:GetDescendants()) do
                    if p:IsA("BasePart") and (p :: BasePart).Transparency < 1 then
                        local s = (p :: BasePart).Size
                        local vol = s.X * s.Y * s.Z
                        if vol > bestVol then bestVol = vol; bestBp = p :: BasePart end
                    end
                end
                if not bestBp then
                    bestBp = mdl:FindFirstChildWhichIsA("BasePart", true) :: BasePart?
                end
                if bestBp then mdl.PrimaryPart = bestBp end
            end
        end

        -- ════════════════════════════════════════════════════════════════════
        -- C/D/E. PLACEMENT DEBOUT — redresse le modèle si couché
        -- ════════════════════════════════════════════════════════════════════
        local placedY = socleTopY  -- fallback = dessus du socle

        if clone:IsA("Model") then
            local mdl = clone :: Model

            -- 1. SCALE PROPORTIONNEL
            pcall(function()
                local _, size = mdl:GetBoundingBox()
                local maxDim = math.max(size.X, size.Y, size.Z)
                if maxDim > 0 then
                    mdl:ScaleTo(mdl:GetScale() * (TARGET_SIZE / maxDim))
                end
            end)

            -- 2. REDRESSER : si la plus grande dimension n'est PAS Y, rotation corrective
            local bbCF, size = mdl:GetBoundingBox()
            local correctionRot = CFrame.new()
            if size.X >= size.Y and size.X >= size.Z then
                -- Couché sur X → rotation Z +90° pour mettre X vertical
                correctionRot = CFrame.Angles(0, 0, math.rad(90))
            elseif size.Z >= size.Y and size.Z >= size.X then
                -- Couché sur Z → rotation X -90° pour mettre Z vertical
                correctionRot = CFrame.Angles(math.rad(-90), 0, 0)
            end
            -- Recalculer la taille après redressement
            mdl:PivotTo(bbCF * correctionRot)
            local _, newSize = mdl:GetBoundingBox()

            -- 3. POSITION : centré sur le socle, posé dessus
            placedY = socleTopY + (newSize.Y / 2)

            -- 4. ROTATION FACE
            local yRot = (slotIndex % 2 == 1) and math.rad(90) or math.rad(-90)

            -- 5. APPLICATION FINALE
            mdl:PivotTo(CFrame.new(socleX, placedY, socleZ) * CFrame.Angles(0, yRot, 0) * correctionRot)

        elseif clone:IsA("BasePart") then
            local bp = clone :: BasePart
            local maxDim = math.max(bp.Size.X, bp.Size.Y, bp.Size.Z)
            if maxDim > 0.01 then
                bp.Size = bp.Size * (TARGET_SIZE / maxDim)
            end
            -- Redresser BasePart si couché
            local correctionRot = CFrame.new()
            if bp.Size.X >= bp.Size.Y and bp.Size.X >= bp.Size.Z then
                correctionRot = CFrame.Angles(0, 0, math.rad(90))
            elseif bp.Size.Z >= bp.Size.Y and bp.Size.Z >= bp.Size.X then
                correctionRot = CFrame.Angles(math.rad(-90), 0, 0)
            end
            placedY = socleTopY + (bp.Size.Y / 2)
            local yRot = (slotIndex % 2 == 1) and math.rad(90) or math.rad(-90)
            bp.CFrame = CFrame.new(socleX, placedY, socleZ) * CFrame.Angles(0, yRot, 0) * correctionRot
        end

        -- ════════════════════════════════════════════════════════════════════
        -- E. EFFETS VISUELS (aura, lumière, sparkles, billboard)
        -- ════════════════════════════════════════════════════════════════════
        local pp: BasePart? = nil
        if clone:IsA("BasePart") then
            pp = clone :: BasePart
        elseif clone:IsA("Model") then
            local mdl = clone :: Model
            pp = mdl.PrimaryPart or mdl:FindFirstChildOfClass("BasePart") :: BasePart?
        else
            pp = clone:FindFirstChildWhichIsA("BasePart", true) :: BasePart?
        end
        if pp then
            addFigurineEffects(pp :: BasePart, rarityColor, itemData.Rarity)
            addFigurineBillboard(pp :: BasePart, 8, itemData.Name, rarityColor)
        end

        state.displayParts[slotIndex] = clone

        -- Enregistrer pour rotation continue
        table.insert(spinningFigurines, {
            instance = clone,
            center   = Vector3.new(socleX, placedY, socleZ),
        })

        print(string.format("[BrainrotGallery] Figurine '%s' (%s) posée sur slot %d — 12 studs",
            itemData.Name, clone.ClassName, slotIndex))

    else
        warn(string.format("[BrainrotGallery] Modèle manquant pour : '%s' (slot %d) — socle vide.",
            itemData.Name, slotIndex))
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- MISE À JOUR DE LA GALERIE
-- ══════════════════════════════════════════════════════════════════════════════
local function refreshGallery(player: Player)
    local plotIndex = plotAssignments[player.UserId]
    if not plotIndex then return end
    local state = plotState[plotIndex]
    if not state then return end

    local data = nil
    for _ = 1, 20 do
        data = DataManager.GetData(player)
        if data then break end
        task.wait(0.5)
    end

    if not data then
        print("[BrainrotGallery] Aucune donnee pour " .. player.Name .. " — socles vides")
        return
    end

    -- ── DIAGNOSTIC : inventaire brut ────────────────────────────────────────
    local invCount = 0
    for _ in pairs(data.Inventory) do invCount += 1 end
    print(string.format("[BrainrotGallery] Inventaire de %s : %d item(s)", player.Name, invCount))
    for itemId, invItem in pairs(data.Inventory) do
        local info = itemLookup[itemId]
        if info then
            -- FIX 3 : afficher si le nom stocké diffère du nom LootTables
            if invItem.Name ~= info.Name then
                warn(string.format("  ⚠ '%s' désync : stocké='%s' / LootTables='%s' → on utilise stocké",
                    itemId, tostring(invItem.Name), info.Name))
            else
                print(string.format("  ✓ '%s' (x%d) → Name='%s' Rarity='%s'",
                    itemId, invItem.Count or 0, invItem.Name, invItem.Rarity or info.Rarity))
            end
        else
            warn(string.format("  ✗ '%s' (x%d) → INCONNU dans itemLookup (item d'un ancien système)",
                itemId, invItem.Count or 0))
        end
    end
    -- ── Fin diagnostic ───────────────────────────────────────────────────────

    local ownedItems: {{Name: string, Rarity: string, Priority: number, Id: string}} = {}
    for itemId, invItem in pairs(data.Inventory) do
        -- FIX 3 : utilise en priorité le nom stocké dans l'inventaire (DataStore),
        -- qui correspond exactement à ce qui a été gagné via WheelSystem.
        -- itemLookup ne sert qu'à la rareté si elle manque dans le stockage.
        local info = itemLookup[itemId]
        local itemName   = (invItem.Name   and invItem.Name   ~= "") and invItem.Name   or (info and info.Name)
        local itemRarity = (invItem.Rarity and invItem.Rarity ~= "") and invItem.Rarity or (info and info.Rarity)
        if itemName and itemRarity and (invItem.Count or 0) > 0 then
            table.insert(ownedItems, {
                Id       = itemId,
                Name     = itemName,
                Rarity   = itemRarity,
                Priority = RARITY_PRIORITY[itemRarity] or 0,
            })
        end
    end

    table.sort(ownedItems, function(a, b)
        if a.Priority ~= b.Priority then return a.Priority > b.Priority end
        return a.Name < b.Name
    end)

    local lockedId   = BrainrotData.LockedImageId
    local fallbackId = BrainrotData.FallbackImageId

    local totalPower = 0

    -- Boucler sur le nombre réel de socles dans la base (ex: 10 socles dans Base1)
    local maxSlots = 0
    for idx in pairs(state.pedestalRefs) do
        if idx > maxSlots then maxSlots = idx end
    end
    if maxSlots == 0 then maxSlots = NUM_SIDES * 2 end  -- fallback ancien système

    for slotIndex = 1, maxSlots do
        local item = ownedItems[slotIndex]
        local refs = state.pedestalRefs[slotIndex]
        if refs then
            if item then
                -- Slot débloqué : image réelle si dispo, sinon fallback (jamais carré gris)
                refs.nameLabel.Text       = item.Name
                refs.nameLabel.TextColor3 = RARITY_COLOR[item.Rarity] or COL_GOLD
                createFigurine(state, slotIndex, item)
                local imgId = BrainrotData.GetImageId(item.Id)
                refs.decal.Texture = "rbxassetid://" .. imgId

                -- Puissance de ce slot
                local pps = POWER_PER_RARITY[item.Rarity] or 1
                totalPower += pps
                refs.powerLabel.Text       = "+" .. pps .. "⚡/s"
                refs.powerLabel.TextColor3 = RARITY_COLOR[item.Rarity] or Color3.fromRGB(100, 220, 255)

                -- Met à jour le taux d'accumulation de la plaque
                local acc = allAccumulators[plotIndex] and allAccumulators[plotIndex][slotIndex]
                if acc then
                    acc.rate = pps
                    -- Active le néon de la plaque selon la rareté
                    acc.label.TextColor3 = RARITY_COLOR[item.Rarity] or Color3.fromRGB(0, 255, 100)
                end
            else
                -- Slot vide : image "Locked" si disponible, sinon vide
                refs.nameLabel.Text       = "???  Slot " .. slotIndex
                refs.nameLabel.TextColor3 = Color3.fromRGB(80, 80, 90)
                createFigurine(state, slotIndex, nil)
                refs.decal.Texture = lockedId ~= 0
                    and ("rbxassetid://" .. lockedId) or ""
                refs.powerLabel.Text = ""

                -- Coupe l'accumulation de la plaque
                local acc = allAccumulators[plotIndex] and allAccumulators[plotIndex][slotIndex]
                if acc then acc.rate = 0 end
            end
        end
    end

    -- Mise à jour instantanée du revenu passif
    if _G.EconomyManager_SetPower then
        _G.EconomyManager_SetPower(player, totalPower)
    end

    print("[BrainrotGallery] Galerie #" .. plotIndex .. " maj pour " .. player.Name
        .. " (" .. #ownedItems .. " items, " .. totalPower .. "⚡/s)")

    -- Hook quêtes : signaler le dépôt au QuestManager
    if _G.QuestManager_OnDeposit then
        task.spawn(_G.QuestManager_OnDeposit, player)
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- AVENUE CENTRALE
-- Route entre les deux rangées de galeries (Z=70 à Z=150, soit 80 studs).
-- ══════════════════════════════════════════════════════════════════════════════
do
    local AVENUE_HALF_LEN = (MAX_PLOTS / 2 + 2) * PLOT_STEP + CORRIDOR_W / 2
    local AVENUE_SOUTH_Z  = START_Z_SOUTH          -- 70
    local AVENUE_NORTH_Z  = START_Z                -- 150
    local AVENUE_DEPTH    = AVENUE_NORTH_Z - AVENUE_SOUTH_Z  -- 80
    local AVENUE_CZ       = (AVENUE_SOUTH_Z + AVENUE_NORTH_Z) / 2  -- 110

    local roadPart = Instance.new("Part")
    roadPart.Name          = "CityAvenue"
    roadPart.Size          = Vector3.new(AVENUE_HALF_LEN * 2, 1, AVENUE_DEPTH)
    roadPart.Position      = Vector3.new(0, FLOOR_Y - 0.5, AVENUE_CZ)
    roadPart.Anchored      = true
    roadPart.CanCollide    = true
    roadPart.Color         = Color3.fromRGB(80, 78, 74)
    roadPart.Material      = Enum.Material.Concrete
    roadPart.Reflectance   = 0
    roadPart.TopSurface    = Enum.SurfaceType.Smooth
    roadPart.BottomSurface = Enum.SurfaceType.Smooth
    roadPart.Parent        = mapFolder

    local centerMark = Instance.new("Part")
    centerMark.Name          = "AvenueCenter"
    centerMark.Size          = Vector3.new(1, 0.1, AVENUE_DEPTH)
    centerMark.Position      = Vector3.new(0, FLOOR_Y + 0.05, AVENUE_CZ)
    centerMark.Anchored      = true
    centerMark.CanCollide    = false
    centerMark.Color         = Color3.fromRGB(255, 215, 0)
    centerMark.Material      = Enum.Material.SmoothPlastic
    centerMark.Reflectance   = 0
    centerMark.TopSurface    = Enum.SurfaceType.Smooth
    centerMark.BottomSurface = Enum.SurfaceType.Smooth
    centerMark.Parent        = mapFolder

    -- Trottoirs : béton légèrement surélevé au bord de chaque rangée de galeries
    for _, side in ipairs({-1, 1}) do
        local curbZ = side == -1 and AVENUE_SOUTH_Z or AVENUE_NORTH_Z
        local curb  = Instance.new("Part")
        curb.Name          = "AvenueCurb_" .. (side == -1 and "S" or "N")
        curb.Size          = Vector3.new(AVENUE_HALF_LEN * 2, 0.4, 1.5)
        curb.Position      = Vector3.new(0, FLOOR_Y + 0.2, curbZ)
        curb.Anchored      = true
        curb.CanCollide    = true
        curb.Color         = Color3.fromRGB(190, 188, 182)
        curb.Material      = Enum.Material.Concrete
        curb.Reflectance   = 0
        curb.Parent        = mapFolder
    end
end

-- (StreamingEnabled configuré manuellement dans Studio)

-- ══════════════════════════════════════════════════════════════════════════════
-- GESTION DES JOUEURS
-- ══════════════════════════════════════════════════════════════════════════════

-- Téléporte devant l'entrée de la parcelle (côté route)
local function teleportToPlot(character: Model, plotIndex: number)
    local isNorth = (plotIndex % 2 == 1)
    local slotCol = math.floor((plotIndex - 1) / 2)
    local plotX   = (slotCol - 1.5) * ESPACEMENT_X
    local plotZ   = isNorth and FRONT_Z or SOUTH_Z
    -- Spawn sur l'avenue, face à l'entrée de sa base
    local spawnZ  = isNorth and (START_Z + 10) or (START_Z_SOUTH - 10)
    local spawnPos = Vector3.new(plotX, GRASS_LEVEL + 5, spawnZ)
    local hrp = character:WaitForChild("HumanoidRootPart", 10)
    if hrp then
        hrp.CFrame = CFrame.new(spawnPos)
    end
end

-- Mettre à true pour forcer un cube de test sur le slot 1 (indépendant de l'inventaire)
local DIAGNOSTIC_FORCE_SLOT1 = false  -- DÉSACTIVÉ : plus de cube magenta de test

local function onPlayerAdded(player: Player)
    if plotAssignments[player.UserId] then return end

    if nextPlotIndex > MAX_PLOTS then
        warn("[BrainrotGallery] Limite de " .. MAX_PLOTS .. " parcelles atteinte !")
        return
    end

    local plotIndex = nextPlotIndex
    nextPlotIndex  += 1
    plotAssignments[player.UserId] = plotIndex

    local ok, errOrState = pcall(buildGallery, player, plotIndex)
    if not ok then
        warn(string.format("[BrainrotGallery] CRASH buildGallery pour %s (plot #%d) : %s",
            player.Name, plotIndex, tostring(errOrState)))
        return
    end
    local state = errOrState :: PlotState
    plotState[plotIndex] = state
    print("[BrainrotGallery] Base generee pour : " .. player.Name .. " (plot #" .. plotIndex .. ")")

    -- ── Test de positionnement forcé sur le slot 1 ───────────────────────────
    if DIAGNOSTIC_FORCE_SLOT1 then
        task.spawn(function()
            task.wait(1)   -- attendre que buildGallery termine
            local refs = state.pedestalRefs[1]
            if refs and refs.top then
                local top = refs.top
                local testCube = Instance.new("Part")
                testCube.Name        = "DiagnosticCube_Slot1"
                testCube.Size        = Vector3.new(2, 2, 2)
                testCube.CFrame      = top.CFrame * CFrame.new(0, top.Size.Y / 2 + 1, 0)
                testCube.Anchored    = true
                testCube.CanCollide  = false
                testCube.Color       = Color3.fromRGB(255, 0, 255)
                testCube.Material    = Enum.Material.Neon
                testCube.Parent      = state.folder
                print("[BrainrotGallery] DIAG: cube magenta posé sur slot 1 — si visible, le positionnement fonctionne")
            else
                warn("[BrainrotGallery] DIAG: refs.top introuvable pour slot 1 !")
            end
        end)
    end
    -- ── Fin test ─────────────────────────────────────────────────────────────

    player.CharacterAdded:Connect(function(character)
        task.wait(2)
        teleportToPlot(character, plotIndex)
    end)
    if player.Character then
        teleportToPlot(player.Character, plotIndex)
    end

    -- FIX 1 : attendre que brainrotModelsFolder soit chargé avant le premier refresh
    task.spawn(function()
        if not brainrotModelsFolder then
            brainrotModelsFolder = ReplicatedStorage:WaitForChild("BrainrotModels", 25) :: Folder?
            if brainrotModelsFolder then
                print(string.format("[BrainrotGallery] BrainrotModels chargé (%d enfants) avant refresh de %s",
                    #(brainrotModelsFolder :: Folder):GetChildren(), player.Name))
            else
                warn("[BrainrotGallery] BrainrotModels introuvable — refresh sans modèles 3D")
            end
        end
        refreshGallery(player)
    end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, p)
end

print("[BrainrotGallery] Boulevard 2 cotes pret. Max " .. MAX_PLOTS .. " joueurs.")

-- ── Boucle d'accumulation (1 tick/s) ─────────────────────────────────────────
-- Incrémente chaque accRef.accumulated selon son taux, met à jour le label.
task.spawn(function()
    while true do
        task.wait(1)
        for _, slotMap in pairs(allAccumulators) do
            for _, acc in pairs(slotMap) do
                if acc.rate > 0 then
                    acc.accumulated += acc.rate
                    acc.label.Text = math.floor(acc.accumulated) .. " ⚡"
                end
            end
        end
    end
end)

-- Nettoyage session joueur
Players.PlayerRemoving:Connect(function(player)
    totalHarvested[player.UserId] = nil
end)

-- Le futur système de roues appellera refreshGallery via ce hook global.
_G.BrainrotGallery_Refresh = refreshGallery
print("[BrainrotGallery] Hook _G.BrainrotGallery_Refresh expose pour le nouveau systeme de roues.")

-- ── Hook : socles vides du joueur (pour WheelSystem / CarryManager) ──────────
-- Retourne {slotIndex → topPart} pour chaque socle vide.
_G.BrainrotGallery_GetEmptyPedestalTops = function(player: Player): {[number]: BasePart}
    local plotIndex = plotAssignments[player.UserId]
    if not plotIndex then return {} end
    local state = plotState[plotIndex]
    if not state then return {} end

    local result: {[number]: BasePart} = {}
    for slotIdx, refs in pairs(state.pedestalRefs) do
        if not state.displayParts[slotIdx] then
            result[slotIdx] = refs.top
        end
    end
    return result
end

-- ── Hook : placement direct d'un item sur un socle précis ────────────────────
-- Appelé par WheelSystem après le spin pour poser le brainrot gagné.
_G.BrainrotGallery_ForcePlace = function(player: Player, slotIndex: number, item: {Id: string, Name: string, Rarity: string})
    local plotIndex = plotAssignments[player.UserId]
    if not plotIndex then return end
    local state = plotState[plotIndex]
    if not state then return end

    createFigurine(state, slotIndex, item)

    local refs = state.pedestalRefs[slotIndex]
    if refs then
        local pps = POWER_PER_RARITY[item.Rarity] or 1
        refs.powerLabel.Text       = "+" .. pps .. "⚡/s"
        refs.powerLabel.TextColor3 = RARITY_COLOR[item.Rarity] or COL_GOLD
        refs.nameLabel.Text        = item.Name
        refs.nameLabel.TextColor3  = RARITY_COLOR[item.Rarity] or COL_GOLD

        -- Activer l'accumulation de puissance sur la plaque de récolte
        local acc = allAccumulators[plotIndex] and allAccumulators[plotIndex][slotIndex]
        if acc then
            acc.rate = pps
            acc.label.TextColor3 = RARITY_COLOR[item.Rarity] or Color3.fromRGB(0, 255, 100)
        end
    end

    -- Hook QuestManager
    if _G.QuestManager_OnDeposit then
        task.spawn(_G.QuestManager_OnDeposit, player)
    end

    print(string.format("[BrainrotGallery] ForcePlace: %s dépôt '%s' (%s) sur slot %d — power=%d⚡/s",
        player.Name, item.Name, item.Rarity, slotIndex, POWER_PER_RARITY[item.Rarity] or 1))
end
-- ── Hook : téléporter un joueur sur le socle de sa base ─────────────────────
-- Appelé par WheelSystem (touche F). Si slotIndex est fourni, TP sur ce socle précis.
-- Sinon, TP devant la base (fallback).
_G.BrainrotGallery_TeleportToPlot = function(character: Model, userId: number, slotIndex: number?)
    local plotIndex = plotAssignments[userId]
    if not plotIndex then return end

    local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then return end

    -- Si un slotIndex est précisé, TP directement sur le socle correspondant
    if slotIndex then
        local state = plotState[plotIndex]
        if state then
            local refs = state.pedestalRefs[slotIndex]
            if refs and refs.top then
                local topPart = refs.top :: BasePart
                -- Poser le joueur juste au-dessus du socle, face au centre de la base
                local pos = topPart.Position + Vector3.new(0, 5, 0)
                local hrpPart = hrp :: BasePart
                hrpPart.CFrame = CFrame.new(pos)
                return
            end
        end
    end

    -- Fallback : devant la base
    teleportToPlot(character, plotIndex)
end

print("[BrainrotGallery] Hooks GetEmptyPedestalTops + ForcePlace + TeleportToPlot exposes.")

-- ── Rotation continue Heartbeat ─────────────────────────────────────────────
RunService.Heartbeat:Connect(function(dt: number)
    local angle = SPIN_SPEED * dt
    for idx = #spinningFigurines, 1, -1 do
        local entry = spinningFigurines[idx]
        local inst  = entry.instance
        if not inst or not inst.Parent then
            table.remove(spinningFigurines, idx)
            continue
        end
        local center = entry.center :: Vector3
        if inst:IsA("Model") then
            local mdl = inst :: Model
            if mdl.PrimaryPart then
                local cf      = mdl:GetPivot()
                local rotOnly = cf - cf.Position
                mdl:PivotTo(CFrame.new(center) * CFrame.Angles(0, angle, 0) * rotOnly)
            end
        elseif inst:IsA("BasePart") then
            local bp      = inst :: BasePart
            local cf      = bp.CFrame
            local rotOnly = cf - cf.Position
            bp.CFrame = CFrame.new(center) * CFrame.Angles(0, angle, 0) * rotOnly
        end
    end
end)
print("[BrainrotGallery] Rotation Heartbeat active — " .. SPIN_SPEED .. " rad/s")

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

local DataManager   = require(ServerScriptService:WaitForChild("DataManager"))
local LootTables    = require(ReplicatedStorage:WaitForChild("LootTables"))
local BrainrotData  = require(ReplicatedStorage:WaitForChild("BrainrotData"))

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
-- DOSSIER MAP
-- ══════════════════════════════════════════════════════════════════════════════
local mapFolder = Workspace:FindFirstChild("Map") or Instance.new("Folder")
if mapFolder.Parent ~= Workspace then
    mapFolder.Name   = "Map"
    mapFolder.Parent = Workspace
end

-- ══════════════════════════════════════════════════════════════════════════════
-- COULEURS
-- ══════════════════════════════════════════════════════════════════════════════
local COL_FLOOR      = Color3.fromRGB( 50,  50,  50)
local COL_RED_LINE   = Color3.fromRGB(196,  40,  28)
local COL_WALL_MID   = Color3.fromRGB( 27,  42,  31)
local COL_WALL_LIGHT = Color3.fromRGB( 27,  42,  31)
local COL_GOLD       = Color3.fromRGB(255, 215,   0)
local COL_PLAQUE     = Color3.fromRGB( 20,  20,  25)

local PEDESTAL_BASE_SHADES: {Color3} = {
    Color3.fromRGB(232, 232, 232),
    Color3.fromRGB(220, 220, 220),
    Color3.fromRGB(208, 208, 208),
    Color3.fromRGB(196, 196, 196),
    Color3.fromRGB(184, 184, 184),
    Color3.fromRGB(172, 172, 172),
    Color3.fromRGB(160, 160, 160),
    Color3.fromRGB(148, 148, 148),
}
local PEDESTAL_TOP_SHADES: {Color3} = {
    Color3.fromRGB(248, 248, 248),
    Color3.fromRGB(236, 236, 236),
    Color3.fromRGB(224, 224, 224),
    Color3.fromRGB(212, 212, 212),
    Color3.fromRGB(200, 200, 200),
    Color3.fromRGB(188, 188, 188),
    Color3.fromRGB(176, 176, 176),
    Color3.fromRGB(164, 164, 164),
}

local RARITY_PRIORITY: {[string]: number} = {ULTRA=5, LEGENDARY=4, MYTHIC=3, RARE=2, NORMAL=1}
-- Puissance générée par mème exposé (Coins/s ajoutés au revenu passif)
local POWER_PER_RARITY: {[string]: number} = {NORMAL=1, COMMON=2, RARE=5, EPIC=15, MYTHIC=10, LEGENDARY=25, ULTRA=50}
local RARITY_COLOR: {[string]: Color3} = {
    NORMAL    = Color3.fromRGB(163, 162, 165),
    COMMON    = Color3.fromRGB(120, 122, 126),
    RARE      = Color3.fromRGB(  0, 162, 255),
    EPIC      = Color3.fromRGB(255,   0, 255),
    MYTHIC    = Color3.fromRGB(170,   0, 255),
    LEGENDARY = Color3.fromRGB(255, 170,   0),
    ULTRA     = Color3.fromRGB(255,   0, 127),
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
-- CORRECTIONS D'ORIENTATION PAR MODÈLE
-- ══════════════════════════════════════════════════════════════════════════════
-- Ajoute ici les modèles qui ne sont pas droits sur leur socle.
-- La clé est le Name exact du brainrot (tel que dans LootTables).
-- Les angles sont en DEGRÉS et s'appliquent APRÈS l'orientation de base.
--   x = inclinaison avant/arrière
--   y = rotation sur soi-même (gauche/droite)
--   z = inclinaison côté (roulis)
--
-- Exemple :
--   ["Ballerina Cappuccina"] = { x = 0, y = 180, z = 0 },  -- retourner face à l'autre sens
--   ["Bombardiro Crocodilo"] = { x = 90, y = 0,   z = 0 },  -- couché → debout
--
local MODEL_ORIENTATION_CORRECTIONS: {[string]: {x: number, y: number, z: number}} = {
    -- z = 90 annule le -90° de base (modèles Toolbox déjà debouts en Roblox Y-up)
    -- Ajuste y si le modèle est dos au couloir (essaie 180)
    -- Ajuste x si le modèle est couché vers l'avant/arrière (essaie 90 ou -90)
    ["Ballerina Cappuccina"]      = { x = 0, y = 0, z = 90 },
    ["Bombardiro Crocodilo"]      = { x = 0, y = 0, z = 90 },
    ["Bombombini Gusini"]         = { x = 0, y = 0, z = 90 },
    ["Cappuccino Assassino"]      = { x = 0, y = 0, z = 90 },
    ["Lirili Larila"]             = { x = 0, y = 0, z = 90 },
    ["Six Seven"]                 = { x = 0, y = 0, z = 90 },
    ["Tralalero Tralala"]         = { x = 0, y = 0, z = 90 },
    ["Trippi Troppi"]             = { x = 0, y = 0, z = 90 },
    ["Brr Brr Patapim"]           = { x = 0, y = 0, z = 90 },
    ["Galaxy W Or L"]             = { x = 0, y = 0, z = 90 },
    ["Gold Chimpanzini Bananini"] = { x = 0, y = 0, z = 90 },
    ["Gold Los Tralaleritos"]     = { x = 0, y = 0, z = 90 },
    ["Diamond Six Seven"]         = { x = 0, y = 0, z = 90 },
    ["Diamond Tung Sahur"]        = { x = 0, y = 0, z = 90 },
    ["Dragon Cannelloni"]         = { x = 0, y = 0, z = 90 },
    ["Strawberry Elephant"]       = { x = 0, y = 0, z = 90 },
}

-- ══════════════════════════════════════════════════════════════════════════════
-- DIMENSIONS DE LA GALERIE
-- ══════════════════════════════════════════════════════════════════════════════
local NUM_SIDES   = 8          -- Socles de chaque côté (8×2 = 16 au total)
local PLACE_GAP   = 16         -- Espacement Z entre les socles
local SIDE_DIST   = 16         -- Distance X du centre au socle
local CORRIDOR_W  = 44         -- Largeur du couloir (X)
local WALL_H      = 20         -- Hauteur des murs
local WALL_T      = 2          -- Épaisseur des murs
local FLOOR_Y     = 1          -- Y du sol
local GALLERY_LEN = (NUM_SIDES + 1) * PLACE_GAP  -- 144 studs

-- ── Entrées des deux rangées de galeries ──────────────────────────────────────
-- L'avenue est entre START_Z_SOUTH (bord sud) et START_Z (bord nord).
-- La route fait 80 studs de large (70 à 150).
local START_Z       = 142   -- Entrée côté NORD — Z = 110 + 32
local START_Z_SOUTH =  78   -- Entrée côté SUD  — Z = 110 - 32
-- Avenue = 64 studs de large (était 80), centre à Z = 110

local SLOT_NAMES: {string} = {
    [1]="??? Slot 1",[2]="??? Slot 2",[3]="??? Slot 3",[4]="??? Slot 4",
    [5]="??? Slot 5",[6]="??? Slot 6",[7]="??? Slot 7",[8]="??? Slot 8",
    [9]="??? Slot 9",[10]="??? Slot 10",[11]="??? Slot 11",[12]="??? Slot 12",
    [13]="??? Slot 13",[14]="??? Slot 14",[15]="??? Slot 15",[16]="??? Slot 16",
}

-- ══════════════════════════════════════════════════════════════════════════════
-- SYSTÈME DE PARCELLES
-- plotIndex impair  → côté nord (zDir=+1, baseZ=START_Z)
-- plotIndex pair    → côté sud  (zDir=-1, baseZ=START_Z_SOUTH)
-- Au sein de chaque côté, les galeries alternent +X / -X.
-- ══════════════════════════════════════════════════════════════════════════════
local PLOT_STEP = CORRIDOR_W + 8   -- 52 studs entre galeries (axe X)
local MAX_PLOTS = 40

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
    local offsetX, baseEntranceZ, zDir = getPlotParams(plotIndex)
    local playerName = player.Name
    local userId     = player.UserId

    -- worldZ : convertit un Z « local » (référencé sur START_Z nord) en monde réel
    -- • côté nord (zDir=+1) : worldZ(z) = z          (aucun changement)
    -- • côté sud  (zDir=-1) : worldZ(z) = 220 - z    (miroir autour de Z=110)
    local function worldZ(localZ: number): number
        return baseEntranceZ + zDir * (localZ - START_Z)
    end

    local folder = Instance.new("Folder")
    folder.Name   = "BrainrotGallery_" .. tostring(userId)
    folder.Parent = mapFolder

    -- Helper Part avec transform X+Z automatique
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
        p.TopSurface    = topSurf or Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        p.Parent        = folder
        return p
    end

    -- ── 1. SOL ────────────────────────────────────────────────────────────────
    -- Légèrement surélevé (+0.1) par rapport à l'avenue pour éviter le Z-fighting.
    mp("GalleryFloor",
        Vector3.new(CORRIDOR_W, 1, GALLERY_LEN + 8),
        Vector3.new(0, FLOOR_Y - 0.4, START_Z + GALLERY_LEN / 2),
        COL_FLOOR, Enum.Material.DiamondPlate, Enum.SurfaceType.Smooth)

    -- FLOOR_Y - 0.4 (centre sol) + 0.5 (demi-hauteur) = 1.1 (surface sol galerie)
    -- La ligne doit être AU-DESSUS : 1.1 + 0.05 = FLOOR_Y + 0.15
    mp("CenterLine",
        Vector3.new(1.5, 0.1, GALLERY_LEN + 8),
        Vector3.new(0, FLOOR_Y + 0.15, START_Z + GALLERY_LEN / 2),
        COL_RED_LINE, Enum.Material.SmoothPlastic, Enum.SurfaceType.Smooth)

    -- ── 2. MURS (SHOWROOM — BAIES VITRÉES) ──────────────────────────────────
    local FULL_WALL_LEN = GALLERY_LEN + 8
    local WALL_CZ       = START_Z + GALLERY_LEN / 2

    -- Palette showroom
    local COL_POST  = Color3.fromRGB(28, 30, 34)      -- métal anthracite quasi-noir
    local COL_GLASS = Color3.fromRGB(155, 200, 235)   -- verre bleuté lumineux
    local POST_W    = 1.8   -- largeur du montant perpendiculaire au mur (axe X)
    local POST_D    = 1.5   -- épaisseur du montant dans l'axe du couloir (axe Z)
    local RAIL_H    = 0.8   -- hauteur des rails horizontaux (traverse haut/bas)
    local GLASS_H   = WALL_H - RAIL_H * 2 - 0.2  -- hauteur libre entre les rails

    -- Positions Z locales (frame nord) des montants verticaux :
    --   • 1 poteau à l'entrée (START_Z)
    --   • 1 poteau entre chaque paire de cadres (i + 0.5) * PLACE_GAP
    --   • 1 poteau au fond (START_Z + GALLERY_LEN + 4)
    local postZList: {number} = {START_Z}
    for i = 0, NUM_SIDES do
        table.insert(postZList, START_Z + (i + 0.5) * PLACE_GAP)
    end
    table.insert(postZList, START_Z + GALLERY_LEN + 4)

    for _, wallSide in ipairs({-1, 1}) do
        local wallX = wallSide * (CORRIDOR_W / 2)
        local sTag  = wallSide == -1 and "L" or "R"

        -- Traverse basse (seuil métallique)
        local rb = mp("RailBot_" .. sTag,
            Vector3.new(POST_W, RAIL_H, FULL_WALL_LEN),
            Vector3.new(wallX, FLOOR_Y + RAIL_H / 2, WALL_CZ),
            COL_POST, Enum.Material.Metal)
        rb.CanCollide = true

        -- Traverse haute (linteau métallique)
        local rt = mp("RailTop_" .. sTag,
            Vector3.new(POST_W, RAIL_H, FULL_WALL_LEN),
            Vector3.new(wallX, FLOOR_Y + WALL_H - RAIL_H / 2, WALL_CZ),
            COL_POST, Enum.Material.Metal)
        rt.CanCollide = true

        -- Montants verticaux (colonnes)
        for pi, pz in ipairs(postZList) do
            local post = mp("Post_" .. sTag .. "_" .. pi,
                Vector3.new(POST_W, WALL_H, POST_D),
                Vector3.new(wallX, FLOOR_Y + WALL_H / 2, pz),
                COL_POST, Enum.Material.Metal)
            post.CanCollide = true
        end

        -- Panneaux de verre entre chaque paire de montants consécutifs
        for gi = 1, #postZList - 1 do
            local z1   = postZList[gi]
            local z2   = postZList[gi + 1]
            local gz   = (z1 + z2) / 2        -- centre du panneau (local Z)
            local gLen = z2 - z1 - POST_D     -- longueur nette (hors montants)

            if gLen > 0.5 then
                local panel = mp("Glass_" .. sTag .. "_" .. gi,
                    Vector3.new(0.3, GLASS_H, gLen),
                    Vector3.new(wallX, FLOOR_Y + WALL_H / 2, gz),
                    COL_GLASS, Enum.Material.Glass)
                panel.Transparency = 0.55
                panel.CastShadow   = false
                panel.CanCollide   = true
                panel.Reflectance  = 0.05
            end
        end
    end

    -- Mur du fond : béton peint moderne (opaque — point focal de la galerie)
    mp("WallBack",
        Vector3.new(CORRIDOR_W + POST_W * 2, WALL_H, WALL_T),
        Vector3.new(0, FLOOR_Y + WALL_H / 2, START_Z + GALLERY_LEN + 4),
        Color3.fromRGB(32, 34, 40), Enum.Material.SmoothPlastic)

    -- ── 3. PLAFOND ────────────────────────────────────────────────────────────
    local ceiling = mp("GalleryCeiling",
        Vector3.new(CORRIDOR_W, 1, GALLERY_LEN + 8),
        Vector3.new(0, FLOOR_Y + WALL_H + 0.5, WALL_CZ),
        Color3.fromRGB(40, 40, 40), Enum.Material.SmoothPlastic, Enum.SurfaceType.Studs)
    ceiling.Reflectance = 0

    -- Plafond centre à FLOOR_Y + WALL_H + 0.5, bottom à FLOOR_Y + WALL_H.
    -- La ligne doit être 0.05 SOUS le plafond pour éviter le Z-fighting.
    mp("CeilingRedLine",
        Vector3.new(1.5, 0.1, GALLERY_LEN + 8),
        Vector3.new(0, FLOOR_Y + WALL_H - 0.05, WALL_CZ),
        COL_RED_LINE, Enum.Material.SmoothPlastic)

    -- ── 4. SOCLES D'EXPOSITION ────────────────────────────────────────────────
    local pedestalRefs: {[number]: PedestalRef} = {}

    for i = 1, NUM_SIDES do
        local placeZ = START_Z + i * PLACE_GAP

        for _, side in ipairs({-1, 1}) do
            local sideLabel = side == -1 and "L" or "R"
            local baseX     = side * SIDE_DIST

            local base = mp("PedestalBase_" .. i .. sideLabel,
                Vector3.new(7, 1.5, 7),
                Vector3.new(baseX, FLOOR_Y + 0.75, placeZ),
                PEDESTAL_BASE_SHADES[i], Enum.Material.SmoothPlastic, Enum.SurfaceType.Studs)

            mp("PedestalMid_" .. i .. sideLabel,
                Vector3.new(5, 1, 5),
                Vector3.new(baseX, FLOOR_Y + 2, placeZ),
                PEDESTAL_BASE_SHADES[i], Enum.Material.SmoothPlastic, Enum.SurfaceType.Studs)

            local topPart = mp("PedestalTop_" .. i .. sideLabel,
                Vector3.new(6, 0.5, 6),
                Vector3.new(baseX, FLOOR_Y + 2.75, placeZ),
                PEDESTAL_TOP_SHADES[i], Enum.Material.SmoothPlastic, Enum.SurfaceType.Studs)

            local slotIndex = (i - 1) * 2 + (side == -1 and 1 or 2)

            local numBillboard = Instance.new("BillboardGui")
            numBillboard.Size        = UDim2.new(0, 60, 0, 30)
            numBillboard.StudsOffset = Vector3.new(0, 2, 0)
            numBillboard.Adornee     = base
            numBillboard.AlwaysOnTop = false
            numBillboard.Parent      = folder

            local numLabel = Instance.new("TextLabel")
            numLabel.Size                   = UDim2.new(1, 0, 1, 0)
            numLabel.BackgroundTransparency = 1
            numLabel.Text                   = "#" .. slotIndex
            numLabel.TextColor3             = Color3.fromRGB(50, 50, 60)
            numLabel.Font                   = Enum.Font.FredokaOne
            numLabel.TextSize               = 22
            numLabel.TextStrokeTransparency = 0.8
            numLabel.Parent                 = numBillboard

            -- Cadres en or
            local wallInnerX = side * (CORRIDOR_W / 2 - WALL_T - 0.05)
            local frameH  = 10
            local frameW  = 10
            local frameCY = FLOOR_Y + 9
            local bT      = 0.75

            local fTop = mp("GoldFrameTop_" .. i .. sideLabel,
                Vector3.new(0.15, bT, frameW),
                Vector3.new(wallInnerX, frameCY + (frameH - bT) / 2, placeZ),
                COL_GOLD, Enum.Material.Metal)
            fTop.CanCollide = false

            local fBot = mp("GoldFrameBot_" .. i .. sideLabel,
                Vector3.new(0.15, bT, frameW),
                Vector3.new(wallInnerX, frameCY - (frameH - bT) / 2, placeZ),
                COL_GOLD, Enum.Material.Metal)
            fBot.CanCollide = false

            local fLeft = mp("GoldFrameLeft_" .. i .. sideLabel,
                Vector3.new(0.15, frameH - bT * 2, bT),
                Vector3.new(wallInnerX, frameCY, placeZ - (frameW - bT) / 2),
                COL_GOLD, Enum.Material.Metal)
            fLeft.CanCollide = false

            local fRight = mp("GoldFrameRight_" .. i .. sideLabel,
                Vector3.new(0.15, frameH - bT * 2, bT),
                Vector3.new(wallInnerX, frameCY, placeZ + (frameW - bT) / 2),
                COL_GOLD, Enum.Material.Metal)
            fRight.CanCollide = false

            -- Plaque d'identification
            local slotName = SLOT_NAMES[slotIndex] or ("Slot " .. slotIndex)

            local plaque = mp("Plaque_" .. i .. sideLabel,
                Vector3.new(7, 0.3, 1.5),
                Vector3.new(baseX, FLOOR_Y + 1.7, placeZ),
                COL_PLAQUE, Enum.Material.SmoothPlastic)
            plaque.CanCollide = false

            local plaqueRim = mp("PlaqueRim_" .. i .. sideLabel,
                Vector3.new(7.3, 0.1, 1.8),
                Vector3.new(baseX, FLOOR_Y + 1.55, placeZ),
                COL_GOLD, Enum.Material.Metal)
            plaqueRim.CanCollide = false

            local sGui = Instance.new("SurfaceGui")
            sGui.Name        = "NamePlaque"
            sGui.Face        = Enum.NormalId.Top
            sGui.CanvasSize  = Vector2.new(350, 60)
            sGui.SizingMode  = Enum.SurfaceGuiSizingMode.FixedSize
            sGui.AlwaysOnTop = false
            sGui.Parent      = plaque

            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size                   = UDim2.new(1, 0, 1, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text                   = slotName
            nameLabel.TextColor3             = COL_GOLD
            nameLabel.Font                   = Enum.Font.GothamBold
            nameLabel.TextSize               = 22
            nameLabel.TextXAlignment         = Enum.TextXAlignment.Center
            nameLabel.TextYAlignment         = Enum.TextYAlignment.Center
            nameLabel.TextStrokeTransparency = 0.6
            nameLabel.TextStrokeColor3       = Color3.new(0, 0, 0)
            nameLabel.Parent                 = sGui

            -- Panneau image (fond du cadre)
            local innerH = frameH - bT * 2
            local innerW = frameW - bT * 2
            local imgPanel = mp("ImgPanel_" .. i .. sideLabel,
                Vector3.new(0.12, innerH, innerW),
                Vector3.new(wallInnerX, frameCY, placeZ),
                Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic)
            imgPanel.CanCollide = false

            local decal = Instance.new("Decal")
            decal.Name    = "MemeDisplay"
            decal.Texture = ""
            decal.Face    = side == -1 and Enum.NormalId.Right or Enum.NormalId.Left
            decal.Parent  = imgPanel

            -- Label de puissance flottant au-dessus du cadre doré
            local powerBb = Instance.new("BillboardGui")
            powerBb.Size        = UDim2.new(0, 120, 0, 26)
            powerBb.StudsOffset = Vector3.new(0, 6, 0)   -- 6 studs au-dessus du centre du cadre
            powerBb.Adornee     = imgPanel
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

            -- Spot au sol
            local floorSpotPart = mp("FloorSpot_" .. i .. sideLabel,
                Vector3.new(0.6, 0.3, 0.6),
                Vector3.new(baseX - side * 4, FLOOR_Y + 0.15, placeZ),
                Color3.fromRGB(30, 30, 30), Enum.Material.Metal)
            floorSpotPart.CanCollide = false

            local floorSpot = Instance.new("SpotLight")
            floorSpot.Face       = Enum.NormalId.Top
            floorSpot.Brightness = 1.5
            floorSpot.Range      = 8
            floorSpot.Angle      = 30
            floorSpot.Color      = Color3.fromRGB(255, 240, 200)
            floorSpot.Shadows    = true
            floorSpot.Parent     = floorSpotPart

            -- ── Plaque de récolte (Collector Plate) ──────────────────────────
            local plateX = side * (SIDE_DIST - 4)   -- 4 studs vers le centre
            local plate  = Instance.new("Part")
            plate.Name      = "CollectorPlate_" .. i .. sideLabel
            plate.Size      = Vector3.new(4, 0.2, 4)
            plate.Position  = Vector3.new(plateX + offsetX, FLOOR_Y + 0.2, worldZ(placeZ))
            plate.Anchored  = true
            plate.CanCollide = false   -- trigger zone : Touched fire sans bloquer le passage
            plate.Material  = Enum.Material.Neon
            plate.Color     = Color3.fromRGB(255, 215, 0)   -- jaune vif
            plate.CastShadow = false
            plate.Parent    = folder

            -- Label dynamique au-dessus de la plaque
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

            -- Particules de récolte (désactivées par défaut)
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

            -- Son de récolte
            local harvestSound = Instance.new("Sound")
            harvestSound.SoundId   = "rbxassetid://5153734135"
            harvestSound.Volume    = 0.7
            harvestSound.RollOffMaxDistance = 30
            harvestSound.Parent    = plate

            -- Référence accumulateur
            if not allAccumulators[plotIndex] then
                allAccumulators[plotIndex] = {}
            end
            local accRef = {
                rate        = 0,
                accumulated = 0,
                label       = harvestLbl,
                particles   = particles,
                sound       = harvestSound,
                lastTouch   = 0,
            }
            allAccumulators[plotIndex][slotIndex] = accRef

            -- Connexion Touched : récolte uniquement par le propriétaire
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

                -- Ajouter au leaderstat ⚡ Power (monnaie secondaire)
                local ls = pl:FindFirstChild("leaderstats")
                local pv = ls and ls:FindFirstChild("⚡ Power")
                if pv then pv.Value = pv.Value + amount end

                totalHarvested[pl.UserId] = (totalHarvested[pl.UserId] or 0) + amount
                HarvestResult:FireClient(pl, amount, totalHarvested[pl.UserId])

                -- Texte flottant 3D au-dessus de la plaque
                showFloatingText(plate.Position + Vector3.new(0, 0.5, 0), amount)

                -- Burst de particules jaunes + son
                accRef.particles:Emit(30)
                accRef.sound:Play()
                -- Éclat de la plaque : légère surbrillance temporaire
                plate.Color = Color3.fromRGB(255, 255, 100)
                task.delay(0.3, function()
                    plate.Color = Color3.fromRGB(255, 215, 0)
                end)
            end)
        end
    end

    -- ── 5. SEUIL D'ENTRÉE ────────────────────────────────────────────────────
    -- Petite marche noire qui fait la transition propre entre route (Y=1.0)
    -- et sol de galerie (Y=1.1). Épaisseur = 0.1, largeur = ouverture du couloir.
    local threshold = mp("EntryThreshold",
        Vector3.new(CORRIDOR_W, 0.1, 1),
        Vector3.new(0, FLOOR_Y + 0.05, START_Z - 0.5),
        Color3.fromRGB(15, 15, 15), Enum.Material.SmoothPlastic)
    threshold.CanCollide = false

    -- ── 6. ENSEIGNE ──────────────────────────────────────────────────────────
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
    -- Nord : face -Z (vers la route), Sud : face +Z (vers la route)
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
    signLabel.BackgroundColor3       = Color3.new(0, 0, 0)
    signLabel.BackgroundTransparency = 0.1
    signLabel.Text                   = "★  BASE DE " .. string.upper(playerName) .. "  ★"
    signLabel.TextColor3             = Color3.fromRGB(255, 230, 0)
    signLabel.Font                   = Enum.Font.GothamBlack
    signLabel.TextScaled             = true
    signLabel.TextStrokeTransparency = 0
    signLabel.TextStrokeColor3       = Color3.new(0, 0, 0)
    signLabel.Parent                 = signSGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent       = signLabel

    -- ── 6. LAMPADAIRES D'ENTRÉE ───────────────────────────────────────────────
    do
        local LAMP_POLE_COLOR = Color3.fromRGB(50, 50, 55)
        local LAMP_BULB_COLOR = Color3.fromRGB(255, 220, 120)
        local poleH = 16

        for _, side in ipairs({-1, 1}) do
            local sLbl = side == -1 and "L" or "R"
            local lx   = side * (CORRIDOR_W / 2 + 1)
            local lz   = START_Z - 4   -- worldZ() l'appliquera

            local pole = mp("EntryPole_" .. sLbl,
                Vector3.new(1, poleH, 1),
                Vector3.new(lx, FLOOR_Y + poleH / 2, lz),
                LAMP_POLE_COLOR, Enum.Material.Metal)
            pole.CanCollide = false

            local cap = mp("EntryLampCap_" .. sLbl,
                Vector3.new(2.8, 0.5, 2.8),
                Vector3.new(lx, FLOOR_Y + poleH + 0.25, lz),
                LAMP_POLE_COLOR, Enum.Material.Metal)
            cap.CanCollide = false

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

    -- ── 7. LUMIÈRES DE PLAFOND ────────────────────────────────────────────────
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

    -- ── 8. LUMIÈRES D'AMBIANCE ────────────────────────────────────────────────
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

        -- Lumière chaude principale
        local pl = Instance.new("PointLight")
        pl.Color      = Color3.fromRGB(255, 255, 255)
        pl.Brightness = 3.5
        pl.Range      = 25
        pl.Shadows    = false
        pl.Parent     = amb

        -- Lumière froide bleue simulant le reflet des baies vitrées
        local glassAmb = Instance.new("Part")
        glassAmb.Name         = "GlassAmbient_" .. k
        glassAmb.Size         = Vector3.new(0.2, 0.2, 0.2)
        glassAmb.Position     = Vector3.new(pos.X + offsetX, pos.Y, pos.Z)
        glassAmb.Anchored     = true
        glassAmb.CanCollide   = false
        glassAmb.Transparency = 1
        glassAmb.CastShadow   = false
        glassAmb.Parent       = folder

        local bl = Instance.new("PointLight")
        bl.Color      = Color3.fromRGB(155, 200, 255)
        bl.Brightness = 0.6
        bl.Range      = 12
        bl.Shadows    = false
        bl.Parent     = glassAmb
    end

    -- Force l'ancrage de toutes les BaseParts
    for _, v in pairs(folder:GetDescendants()) do
        if v:IsA("BasePart") then v.Anchored = true end
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
local MAX_FIGURINE_DIM = 3.5   -- taille max sur n'importe quel axe (studs)

local function addFigurineEffects(root: BasePart, rarityColor: Color3, rarity: string)
    local isHigh = rarity == "EPIC" or rarity == "LEGENDARY" or rarity == "ULTRA"
    if isHigh then
        local light      = Instance.new("PointLight")
        light.Color      = rarityColor
        light.Brightness = 1.5
        light.Range      = 7
        light.Parent     = root
    end
    if rarity == "ULTRA" then
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
    local foundButRejected = false

    for _, child in ipairs((brainrotModelsFolder :: Folder):GetChildren()) do
        local childLower = string.lower(child.Name)
        if childLower == lowerName then
            -- Correspondance de nom — on accepte TOUS les types
            local n = #child:GetDescendants()
            print(string.format("[BrainrotGallery] Candidat pour '%s' : '%s' (%s, %d descendants)",
                name, child.Name, child.ClassName, n))
            if n > bestCount then
                bestCount = n
                best      = child
            end
        else
            -- Avertir si nom similaire (aide à repérer les fautes de frappe)
            if string.find(childLower, lowerName, 1, true) or string.find(lowerName, childLower, 1, true) then
                warn(string.format("[BrainrotGallery] Nom similaire : cherché='%s' / trouvé='%s' (%s) — faute de frappe ?",
                    name, child.Name, child.ClassName))
            end
        end
    end

    if best then
        print(string.format("[BrainrotGallery] ✓ Sélectionné pour '%s' : '%s' (%s, %d descendants)",
            name, (best :: Instance).Name, (best :: Instance).ClassName, bestCount))
    else
        warn(string.format("[BrainrotGallery] ✗ RAISON DU REJET : aucun enfant de BrainrotModels ne correspond au nom '%s' (insensible à la casse). Liste des enfants :", name))
        for _, child in ipairs((brainrotModelsFolder :: Folder):GetChildren()) do
            warn(string.format("   → '%s' (%s)", child.Name, child.ClassName))
        end
    end
    return best
end

local function createFigurine(state: PlotState, slotIndex: number, itemData: any)
    -- Détruire l'ancienne figurine (cube ou modèle) avant tout remplacement
    if state.displayParts[slotIndex] then
        (state.displayParts[slotIndex] :: Instance):Destroy()
        state.displayParts[slotIndex] = nil
    end
    if not itemData then return end

    local refs = state.pedestalRefs[slotIndex]
    if not refs then return end

    local topPart     = refs.top
    local rarityColor = RARITY_COLOR[itemData.Rarity] or RARITY_COLOR.NORMAL

    -- CFrame du dessus du socle (surface sur laquelle le modèle est posé)
    local socleTopCF = topPart.CFrame * CFrame.new(0, topPart.Size.Y / 2, 0)

    -- ── Cherche le vrai asset (insensible à la casse, tout type accepté) ───────
    local template = findBrainrotModel(itemData.Name)

    if template then
        -- ── ASSET TOOLBOX (Model, MeshPart, Part, Folder…) ───────────────────
        local clone = template:Clone()
        clone.Name   = "Figurine_" .. slotIndex

        -- ★ PARENT EN PREMIER — le clone doit être dans le Workspace AVANT
        --   tout PivotTo / ScaleTo, sinon Roblox l'ignore (reste dans nil)
        clone.Parent = state.folder

        -- FIX Gravité : ancrer TOUS les BasePart (clone lui-même s'il en est un)
        if clone:IsA("BasePart") then
            (clone :: BasePart).Anchored   = true
            (clone :: BasePart).CanCollide = false
        end
        for _, part in pairs(clone:GetDescendants()) do
            if part:IsA("BasePart") then
                (part :: BasePart).Anchored   = true
                (part :: BasePart).CanCollide = false
            end
        end

        -- FIX Transparence : remettre à 0 les parts totalement invisibles
        if clone:IsA("BasePart") and (clone :: BasePart).Transparency >= 1 then
            (clone :: BasePart).Transparency = 0
        end
        for _, part in pairs(clone:GetDescendants()) do
            if part:IsA("BasePart") and (part :: BasePart).Transparency >= 1 then
                (part :: BasePart).Transparency = 0
                warn(string.format("[BrainrotGallery] Part '%s' dans '%s' était Transparency=1 — corrigé",
                    part.Name, itemData.Name))
            end
        end

        -- Auto-scaling : contenir dans MAX_FIGURINE_DIM studs, puis boost ×1.5
        if clone:IsA("Model") then
            local ok, rawBB = pcall(function() return select(2, clone:GetBoundingBox()) end)
            if ok and rawBB then
                local maxDim = math.max((rawBB :: Vector3).X, (rawBB :: Vector3).Y, (rawBB :: Vector3).Z)
                if maxDim > 0.01 and maxDim > MAX_FIGURINE_DIM then
                    pcall(function() (clone :: Model):ScaleTo(MAX_FIGURINE_DIM / maxDim) end)
                end
            end
            -- Boost visuel ×2.25 (taille finale sur le socle)
            pcall(function() (clone :: Model):ScaleTo((clone :: Model):GetScale() * 2.25) end)
        end

        -- ── Orientation : debout (axe Z) + face vers le couloir (axe Y) ──────
        -- Étape 1 — Redressement : rotation +90° sur Z = modèle debout
        --           (utilise Z et non X pour éviter de coucher sur le côté)
        -- Étape 2 — Face au couloir : rotation Y selon le côté du socle
        --   Slots impairs = côté gauche (X<0) → yRot = +90° (face vers +X = centre)
        --   Slots pairs   = côté droit  (X>0) → yRot = -90° (face vers -X = centre)
        -- Étape 3 — Correction individuelle (MODEL_ORIENTATION_CORRECTIONS)
        local yRot  = (slotIndex % 2 == 1) and math.rad(90) or math.rad(-90)
        local correction = MODEL_ORIENTATION_CORRECTIONS[itemData.Name]
        local correctionCF = correction
            and CFrame.Angles(math.rad(correction.x), math.rad(correction.y), math.rad(correction.z))
            or CFrame.identity
        local standCF = CFrame.Angles(0, 0, math.rad(-90)) * CFrame.Angles(0, yRot, 0) * correctionCF

        -- Position cible : 2 studs au-dessus du dessus du socle
        local targetPos = (socleTopCF * CFrame.new(0, 2, 0)).Position
        local targetCF  = CFrame.new(targetPos) * standCF

        if clone:IsA("Model") then
            local mdl = clone :: Model
            -- FIX PrimaryPart : garantir qu'un PrimaryPart existe avant PivotTo
            if not mdl.PrimaryPart then
                local bp = mdl:FindFirstChildWhichIsA("BasePart", true)
                if bp then
                    mdl.PrimaryPart = bp :: BasePart
                    warn(string.format("[BrainrotGallery] '%s' sans PrimaryPart — '%s' assigné automatiquement",
                        itemData.Name, (bp :: BasePart).Name))
                end
            end
            if mdl.PrimaryPart then
                mdl:PivotTo(targetCF)
            else
                mdl:MoveTo(targetPos)
                warn(string.format("[BrainrotGallery] '%s' sans aucun BasePart — MoveTo de secours", itemData.Name))
            end
        elseif clone:IsA("BasePart") then
            (clone :: BasePart).CFrame = targetCF
        else
            local bp = clone:FindFirstChildWhichIsA("BasePart", true)
            if bp then (bp :: BasePart).CFrame = targetCF end
        end

        -- Effets visuels sur le BasePart le plus pertinent
        local pp: BasePart? = if clone:IsA("BasePart") then clone :: BasePart
                              elseif clone:IsA("Model")  then (clone :: Model).PrimaryPart
                                                                or (clone :: Model):FindFirstChildOfClass("BasePart") :: BasePart?
                              else clone:FindFirstChildWhichIsA("BasePart", true) :: BasePart?
        if pp then
            addFigurineEffects(pp :: BasePart, rarityColor, itemData.Rarity)
            addFigurineBillboard(pp :: BasePart, 2.5, itemData.Name, rarityColor)
        end

        state.displayParts[slotIndex] = clone
        print(string.format("[BrainrotGallery] ✓ Asset '%s' (%s) posé sur slot %d",
            itemData.Name, clone.ClassName, slotIndex))

    else
        -- Modèle absent de BrainrotModels → socle laissé vide, rien généré.
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

    for slotIndex = 1, NUM_SIDES * 2 do
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
    local offsetX, baseEntranceZ, zDir = getPlotParams(plotIndex)
    -- 12 studs vers la route depuis l'entrée de la galerie
    local spawnPos = Vector3.new(offsetX, FLOOR_Y + 5, baseEntranceZ - zDir * 12)
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

    local state = buildGallery(player, plotIndex)
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
                    -- Cap à 9999 pour éviter des nombres absurdes
                    if acc.accumulated > 9999 then acc.accumulated = 9999 end
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

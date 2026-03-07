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

local DataManager   = require(ServerScriptService:WaitForChild("DataManager"))
local LootTables    = require(ReplicatedStorage:WaitForChild("LootTables"))
local BrainrotData  = require(ReplicatedStorage:WaitForChild("BrainrotData"))

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
    Color3.fromRGB(215, 215, 215),
    Color3.fromRGB(198, 198, 198),
    Color3.fromRGB(181, 181, 181),
    Color3.fromRGB(164, 164, 164),
}
local PEDESTAL_TOP_SHADES: {Color3} = {
    Color3.fromRGB(248, 248, 248),
    Color3.fromRGB(231, 231, 231),
    Color3.fromRGB(214, 214, 214),
    Color3.fromRGB(197, 197, 197),
    Color3.fromRGB(180, 180, 180),
}

local RARITY_PRIORITY: {[string]: number} = {ULTRA=5, LEGENDARY=4, MYTHIC=3, RARE=2, NORMAL=1}
-- Puissance générée par mème exposé (Coins/s ajoutés au revenu passif)
local POWER_PER_RARITY: {[string]: number} = {NORMAL=1, RARE=5, MYTHIC=10, LEGENDARY=25, ULTRA=50}
local RARITY_COLOR: {[string]: Color3} = {
    NORMAL    = Color3.fromRGB(163, 162, 165),
    RARE      = Color3.fromRGB(  0, 162, 255),
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
-- DIMENSIONS DE LA GALERIE
-- ══════════════════════════════════════════════════════════════════════════════
local NUM_SIDES   = 5          -- Socles de chaque côté
local PLACE_GAP   = 16         -- Espacement Z entre les socles
local SIDE_DIST   = 16         -- Distance X du centre au socle
local CORRIDOR_W  = 44         -- Largeur du couloir (X)
local WALL_H      = 20         -- Hauteur des murs
local WALL_T      = 2          -- Épaisseur des murs
local FLOOR_Y     = 1          -- Y du sol
local GALLERY_LEN = (NUM_SIDES + 1) * PLACE_GAP  -- 96 studs

-- ── Entrées des deux rangées de galeries ──────────────────────────────────────
-- L'avenue est entre START_Z_SOUTH (bord sud) et START_Z (bord nord).
-- La route fait 80 studs de large (70 à 150).
local START_Z       = 142   -- Entrée côté NORD — Z = 110 + 32
local START_Z_SOUTH =  78   -- Entrée côté SUD  — Z = 110 - 32
-- Avenue = 64 studs de large (était 80), centre à Z = 110

local SLOT_NAMES: {string} = {
    [1]="??? Slot 1",[2]="??? Slot 2",[3]="??? Slot 3",[4]="??? Slot 4",[5]="??? Slot 5",
    [6]="??? Slot 6",[7]="??? Slot 7",[8]="??? Slot 8",[9]="??? Slot 9",[10]="??? Slot 10",
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

    -- ── BALISE DEBUG : colonne néon rouge au-dessus du toit ──────────────────
    local ROOF_TOP    = FLOOR_Y + WALL_H + 0.5
    local beaconCentZ = worldZ(START_Z + GALLERY_LEN / 2)
    local beacon      = Instance.new("Part")
    beacon.Name         = "DEBUG_Beacon_" .. plotIndex
    beacon.Shape        = Enum.PartType.Cylinder
    beacon.Size         = Vector3.new(1000, 2, 2)
    beacon.CFrame       = CFrame.new(offsetX, ROOF_TOP + 500, beaconCentZ)
                        * CFrame.Angles(0, 0, math.pi / 2)
    beacon.Anchored     = true
    beacon.CanCollide   = false
    beacon.Material     = Enum.Material.Neon
    beacon.Color        = Color3.fromRGB(255, 0, 0)
    beacon.CastShadow   = false
    beacon.Parent       = folder

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
-- FIGURINES
-- ══════════════════════════════════════════════════════════════════════════════
local function createFigurine(state: PlotState, slotIndex: number, itemData: any)
    if state.displayParts[slotIndex] then
        (state.displayParts[slotIndex] :: Part):Destroy()
        state.displayParts[slotIndex] = nil
    end
    if not itemData then return end

    local refs = state.pedestalRefs[slotIndex]
    if not refs then return end

    local topPos       = refs.top.Position
    local rarityColor  = RARITY_COLOR[itemData.Rarity] or RARITY_COLOR.NORMAL
    local isHighRarity = itemData.Rarity == "ULTRA" or itemData.Rarity == "LEGENDARY"

    local fig = Instance.new("Part")
    fig.Name        = "Figurine_" .. slotIndex
    fig.Size        = Vector3.new(3, 4, 3)
    fig.Position    = topPos + Vector3.new(0, 2.25, 0)
    fig.Anchored    = true
    fig.CanCollide  = false
    fig.Color       = rarityColor
    fig.Material    = Enum.Material.SmoothPlastic
    fig.Reflectance = isHighRarity and 0.1 or 0
    fig.Parent      = state.folder

    if itemData.Rarity == "ULTRA" then
        local sparkles = Instance.new("Sparkles")
        sparkles.SparkleColor = rarityColor
        sparkles.Parent       = fig
    end

    if isHighRarity then
        local light = Instance.new("PointLight")
        light.Color      = rarityColor
        light.Brightness = 1.5
        light.Range      = 6
        light.Parent     = fig
    end

    local bb = Instance.new("BillboardGui")
    bb.Size        = UDim2.new(0, 160, 0, 36)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = false
    bb.MaxDistance = 40
    bb.Adornee     = fig
    bb.Parent      = fig

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = itemData.Name
    lbl.TextColor3             = rarityColor
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextScaled             = true
    lbl.TextStrokeTransparency = 0.3
    lbl.TextStrokeColor3       = Color3.new(0, 0, 0)
    lbl.Parent                 = bb

    state.displayParts[slotIndex] = fig
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

    local ownedItems: {{Name: string, Rarity: string, Priority: number, Id: string}} = {}
    for itemId, invItem in pairs(data.Inventory) do
        local info = itemLookup[itemId]
        if info and invItem.Count > 0 then
            table.insert(ownedItems, {
                Id       = itemId,
                Name     = info.Name,
                Rarity   = info.Rarity,
                Priority = RARITY_PRIORITY[info.Rarity] or 0,
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
            else
                -- Slot vide : image "Locked" si disponible, sinon vide
                refs.nameLabel.Text       = "???  Slot " .. slotIndex
                refs.nameLabel.TextColor3 = Color3.fromRGB(80, 80, 90)
                createFigurine(state, slotIndex, nil)
                refs.decal.Texture = lockedId ~= 0
                    and ("rbxassetid://" .. lockedId) or ""
                refs.powerLabel.Text = ""
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
    print("[BrainrotGallery] Base generee pour : " .. player.Name)

    player.CharacterAdded:Connect(function(character)
        task.wait(2)
        teleportToPlot(character, plotIndex)
    end)
    if player.Character then
        teleportToPlot(player.Character, plotIndex)
    end

    task.spawn(refreshGallery, player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, p)
end

print("[BrainrotGallery] Boulevard 2 cotes pret. Max " .. MAX_PLOTS .. " joueurs.")

-- Le futur système de roues appellera refreshGallery via ce hook global.
_G.BrainrotGallery_Refresh = refreshGallery
print("[BrainrotGallery] Hook _G.BrainrotGallery_Refresh expose pour le nouveau systeme de roues.")

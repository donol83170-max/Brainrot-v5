--!strict
-- BrainrotGallery.server.lua
-- Génère une galerie d'exposition style LEGO avec 10 socles (5 gauche + 5 droite)
-- Placé dans ServerScriptService, synchronisé par Rojo
-- Position : derrière le spawn (Z > 80), aligné sur l'axe central

local Workspace = game:GetService("Workspace")

-- ══════════════════════════════════════════════════════════════════════════════
-- DOSSIERS
-- ══════════════════════════════════════════════════════════════════════════════
local mapFolder = Workspace:FindFirstChild("Map") or Instance.new("Folder")
mapFolder.Name   = "Map"
mapFolder.Parent = Workspace

local galleryFolder = Instance.new("Folder")
galleryFolder.Name   = "BrainrotGallery"
galleryFolder.Parent = mapFolder

-- ══════════════════════════════════════════════════════════════════════════════
-- CONSTANTS
-- ══════════════════════════════════════════════════════════════════════════════

-- Couleurs
local COL_FLOOR      = Color3.fromRGB(163, 162, 165) -- Gris foncé (sol)
local COL_RED_LINE   = Color3.fromRGB(196,  40,  28) -- Bright Red (ligne centrale)
local COL_WALL_LIGHT = Color3.fromRGB(226, 226, 226) -- Gris clair (murs alternés)
local COL_WALL_MID   = Color3.fromRGB(175, 175, 175) -- Gris moyen (murs alternés)
local COL_PEDESTAL   = Color3.fromRGB(242, 243, 243) -- Blanc cassé (socles)
local COL_PEDESTAL_TOP = Color3.fromRGB(255, 255, 255)

-- Disposition
local NUM_SIDES   = 5          -- 5 socles de chaque côté
local PLACE_GAP   = 16         -- Distance entre chaque place (Z)
local SIDE_DIST   = 12         -- Distance du centre au socle (X)
local CORRIDOR_W  = 30         -- Largeur du couloir (X total)
local WALL_H      = 20         -- Hauteur des murs
local WALL_T      = 2          -- Épaisseur des murs

-- Point de départ : derrière le spawn (spawn à Z=80, galerie commence à Z=100)
local START_Z  = 110
local FLOOR_Y  = 0    -- Niveau du sol
local GALLERY_LEN = (NUM_SIDES + 1) * PLACE_GAP  -- Longueur totale du couloir

-- ══════════════════════════════════════════════════════════════════════════════
-- UTILITAIRES
-- ══════════════════════════════════════════════════════════════════════════════
local function makePart(name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material, topSurface: Enum.SurfaceType?): Part
    local p = Instance.new("Part")
    p.Name        = name
    p.Size        = size
    p.Position    = position
    p.Anchored    = true
    p.CanCollide  = true
    p.Color       = color
    p.Material    = material
    p.TopSurface  = topSurface or Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent      = galleryFolder
    return p
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 1. SOL DU COULOIR
-- ══════════════════════════════════════════════════════════════════════════════
makePart(
    "GalleryFloor",
    Vector3.new(CORRIDOR_W, 1, GALLERY_LEN + 8),
    Vector3.new(0, FLOOR_Y - 0.5, START_Z + GALLERY_LEN / 2),
    COL_FLOOR,
    Enum.Material.SmoothPlastic,
    Enum.SurfaceType.Studs  -- Style LEGO
)

-- Ligne rouge centrale au sol
makePart(
    "CenterLine",
    Vector3.new(1.5, 1.05, GALLERY_LEN + 8),
    Vector3.new(0, FLOOR_Y - 0.5, START_Z + GALLERY_LEN / 2),
    COL_RED_LINE,
    Enum.Material.SmoothPlastic,
    Enum.SurfaceType.Smooth
)

-- ══════════════════════════════════════════════════════════════════════════════
-- 2. MURS DU COULOIR (gauche et droite, alternance couleurs)
-- ══════════════════════════════════════════════════════════════════════════════
local WALL_SEGMENT_LEN = PLACE_GAP  -- Chaque segment de mur corresponds à une place

for i = 0, NUM_SIDES do
    local segZ    = START_Z + i * WALL_SEGMENT_LEN + WALL_SEGMENT_LEN / 2
    local wallCol = (i % 2 == 0) and COL_WALL_LIGHT or COL_WALL_MID

    -- Mur gauche
    makePart(
        "WallLeft_" .. i,
        Vector3.new(WALL_T, WALL_H, WALL_SEGMENT_LEN),
        Vector3.new(-(CORRIDOR_W / 2), FLOOR_Y + WALL_H / 2, segZ),
        wallCol,
        Enum.Material.SmoothPlastic
    )

    -- Mur droit
    makePart(
        "WallRight_" .. i,
        Vector3.new(WALL_T, WALL_H, WALL_SEGMENT_LEN),
        Vector3.new(CORRIDOR_W / 2, FLOOR_Y + WALL_H / 2, segZ),
        wallCol,
        Enum.Material.SmoothPlastic
    )
end

-- Mur de fond (ferme le couloir)
makePart(
    "WallBack",
    Vector3.new(CORRIDOR_W + WALL_T * 2, WALL_H, WALL_T),
    Vector3.new(0, FLOOR_Y + WALL_H / 2, START_Z + GALLERY_LEN + 4),
    COL_WALL_LIGHT,
    Enum.Material.SmoothPlastic
)

-- ══════════════════════════════════════════════════════════════════════════════
-- 3. PLAFOND (grille légère en LEGO)
-- ══════════════════════════════════════════════════════════════════════════════
makePart(
    "GalleryCeiling",
    Vector3.new(CORRIDOR_W, 1, GALLERY_LEN + 8),
    Vector3.new(0, FLOOR_Y + WALL_H + 0.5, START_Z + GALLERY_LEN / 2),
    COL_WALL_MID,
    Enum.Material.SmoothPlastic,
    Enum.SurfaceType.Studs
)

-- ══════════════════════════════════════════════════════════════════════════════
-- 4. SOCLES D'EXPOSITION (5 gauche + 5 droite)
-- ══════════════════════════════════════════════════════════════════════════════
for i = 1, NUM_SIDES do
    local placeZ = START_Z + i * PLACE_GAP

    for _, side in ipairs({ -1, 1 }) do -- -1 = gauche, +1 = droite
        local sideLabel = side == -1 and "L" or "R"
        local baseX = side * SIDE_DIST

        -- Base du socle (grande)
        local base = makePart(
            "PedestalBase_" .. i .. sideLabel,
            Vector3.new(7, 1.5, 7),
            Vector3.new(baseX, FLOOR_Y + 0.75, placeZ),
            COL_PEDESTAL,
            Enum.Material.SmoothPlastic,
            Enum.SurfaceType.Studs
        )

        -- Colonne intermédiaire
        makePart(
            "PedestalMid_" .. i .. sideLabel,
            Vector3.new(5, 1, 5),
            Vector3.new(baseX, FLOOR_Y + 2, placeZ),
            COL_PEDESTAL,
            Enum.Material.SmoothPlastic,
            Enum.SurfaceType.Studs
        )

        -- Plateau supérieur (où le modèle sera posé)
        makePart(
            "PedestalTop_" .. i .. sideLabel,
            Vector3.new(6, 0.5, 6),
            Vector3.new(baseX, FLOOR_Y + 2.75, placeZ),
            COL_PEDESTAL_TOP,
            Enum.Material.SmoothPlastic,
            Enum.SurfaceType.Studs
        )

        -- Numéro du socle (BillboardGui)
        local numBillboard = Instance.new("BillboardGui")
        numBillboard.Name         = "PlaceNumber"
        numBillboard.Size         = UDim2.new(0, 60, 0, 30)
        numBillboard.StudsOffset  = Vector3.new(0, 2, 0)
        numBillboard.Adornee      = base
        numBillboard.AlwaysOnTop  = false
        numBillboard.Parent       = galleryFolder

        local numLabel = Instance.new("TextLabel")
        numLabel.Size                   = UDim2.new(1, 0, 1, 0)
        numLabel.BackgroundTransparency = 1
        numLabel.Text                   = "#" .. ((i - 1) * 2 + (side == -1 and 1 or 2))
        numLabel.TextColor3             = Color3.fromRGB(50, 50, 60)
        numLabel.Font                   = Enum.Font.FredokaOne
        numLabel.TextSize               = 22
        numLabel.TextStrokeTransparency = 0.8
        numLabel.Parent                 = numBillboard

        -- Spot light au plafond pour chaque socle
        local spotLight = Instance.new("SpotLight")
        spotLight.Face       = Enum.NormalId.Bottom
        spotLight.Brightness = 3
        spotLight.Range      = 20
        spotLight.Angle      = 35
        spotLight.Color      = Color3.fromRGB(255, 240, 220) -- Lumière chaude
        spotLight.Shadows    = true
        spotLight.Parent = makePart(
            "SpotLightPart_" .. i .. sideLabel,
            Vector3.new(0.5, 0.5, 0.5),
            Vector3.new(baseX, FLOOR_Y + WALL_H - 1, placeZ),
            Color3.fromRGB(50, 50, 50),
            Enum.Material.Metal
        )
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 5. ENTRÉE DE LA GALERIE (arche décorative)
-- ══════════════════════════════════════════════════════════════════════════════
-- Pilier gauche d'entrée
makePart(
    "EntryPillarL",
    Vector3.new(3, WALL_H, 3),
    Vector3.new(-(CORRIDOR_W / 2) + 1.5, FLOOR_Y + WALL_H / 2, START_Z - 1),
    COL_WALL_MID,
    Enum.Material.SmoothPlastic
)
-- Pilier droit d'entrée
makePart(
    "EntryPillarR",
    Vector3.new(3, WALL_H, 3),
    Vector3.new(CORRIDOR_W / 2 - 1.5, FLOOR_Y + WALL_H / 2, START_Z - 1),
    COL_WALL_MID,
    Enum.Material.SmoothPlastic
)
-- Linteau (dessus de l'arche)
makePart(
    "EntryLintel",
    Vector3.new(CORRIDOR_W, 4, 3),
    Vector3.new(0, FLOOR_Y + WALL_H - 2, START_Z - 1),
    COL_RED_LINE,
    Enum.Material.SmoothPlastic
)

-- Enseigne "BRAINROT GALLERY"
local signGui = Instance.new("BillboardGui")
signGui.Name        = "GallerySign"
signGui.Size        = UDim2.new(0, 360, 0, 60)
signGui.StudsOffset = Vector3.new(0, 0, -1)
signGui.Adornee     = galleryFolder:FindFirstChild("EntryLintel") or Workspace
signGui.AlwaysOnTop = false
signGui.Parent      = galleryFolder

local signLabel = Instance.new("TextLabel")
signLabel.Size                   = UDim2.new(1, 0, 1, 0)
signLabel.BackgroundTransparency = 1
signLabel.Text                   = "✦  BRAINROT GALLERY  ✦"
signLabel.TextColor3             = Color3.new(1, 1, 1)
signLabel.Font                   = Enum.Font.FredokaOne
signLabel.TextSize               = 36
signLabel.TextStrokeTransparency = 0
signLabel.TextStrokeColor3       = Color3.fromRGB(80, 0, 0)
signLabel.Parent                 = signGui

print("🏛️ [BrainrotGallery] Galerie générée ! " .. (NUM_SIDES * 2) .. " socles prêts.")

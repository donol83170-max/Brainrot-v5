--!strict
-- BrainrotGallery.server.lua
-- Génère une galerie d'exposition style LEGO avec 10 socles (5 gauche + 5 droite)
-- Placé dans ServerScriptService, synchronisé par Rojo
-- Position : derrière le spawn (Z > 80), aligné sur l'axe central

local Workspace           = game:GetService("Workspace")
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataManager = require(ServerScriptService:WaitForChild("DataManager"))
local LootTables  = require(ReplicatedStorage:WaitForChild("LootTables"))

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
local COL_FLOOR      = Color3.fromRGB( 50,  50,  50) -- Gris anthracite (plus sombre, anti-éblouissement)
local COL_RED_LINE   = Color3.fromRGB(196,  40,  28) -- Bright Red (ligne centrale)
local COL_WALL_LIGHT = Color3.fromRGB(27, 42, 31)   -- Vert foncé LEGO
local COL_WALL_MID   = Color3.fromRGB(27, 42, 31)   -- Vert foncé LEGO
local COL_PEDESTAL   = Color3.fromRGB(232, 232, 232) -- (référence, remplacé par shades)
local COL_PEDESTAL_TOP = Color3.fromRGB(248, 248, 248) -- (référence)
local COL_GOLD       = Color3.fromRGB(255, 215,   0) -- Or (cadres)
local COL_PLAQUE     = Color3.fromRGB( 20,  20,  25) -- Noir profond (plaque texto)

-- Nuances de gris LEGO par rangée (Row 1 = plus clair → Row 5 = plus foncé)
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

-- Priorité et couleur par rareté (miroir de Constants.RARITIES)
local RARITY_PRIORITY: {[string]: number} = {ULTRA=5, LEGENDARY=4, MYTHIC=3, RARE=2, NORMAL=1}
local RARITY_COLOR: {[string]: Color3} = {
    NORMAL    = Color3.fromRGB(163, 162, 165),
    RARE      = Color3.fromRGB(  0, 162, 255),
    MYTHIC    = Color3.fromRGB(170,   0, 255),
    LEGENDARY = Color3.fromRGB(255, 170,   0),
    ULTRA     = Color3.fromRGB(255,   0, 127),
}

-- Lookup global : itemId -> {Name, Rarity}
local itemLookup: {[string]: {Name: string, Rarity: string}} = {}
for _, wheel in pairs(LootTables.Wheels) do
    for _, item in ipairs(wheel.Items) do
        if not itemLookup[item.Id] then
            itemLookup[item.Id] = {Name = item.Name, Rarity = item.Rarity}
        end
    end
end

-- ── TABLE D'IMAGES BRAINROT ──────────────────────────────────────────────────
-- Remplis les imageId avec les vrais asset IDs Roblox de tes Decals
-- (rbxassetid://XXXXXXX) — laisser à 0 = aucune image affichée
local BRAINROT_DATA: {[string]: number} = {
    -- Roue Noob
    BruhSound       = 0,
    NoobFace        = 0,
    DefaultPizza    = 0,
    MewingEmoji     = 0,
    BlueTie         = 0,
    SigmaSmile      = 0,
    GigachadJaw     = 0,
    PizzaTower      = 0,
    SkibidiHead     = 0,
    GoldenSigma     = 0,
    GalaxySigma     = 0,
    DiamondSkibidi  = 0,
    JokeCrafter     = 0,
    BrainrotKing    = 0,
    SkibidiGod      = 0,
    UltimateNoob    = 0,
    -- Roue Sigma
    CrunchyCookie   = 0,
    BasicRizzler    = 0,
    NpcFace         = 0,
    SigmaGrind      = 0,
    Rizzler500      = 0,
    BrainrotWave    = 0,
    SigmaKing       = 0,
    GlizzyGoblin    = 0,
    UltraRizzler    = 0,
    SigmaChad       = 0,
    OmegaSigma      = 0,
    DivineRizzler   = 0,
    ChadVibes       = 0,
    SigmaFlash      = 0,
    MegaRizzler     = 0,
    AbsoluteSigma   = 0,
    -- Roue Ultra
    CosmicNoob      = 0,
    VoidPizza       = 0,
    NebulaBruh      = 0,
    StarSigma       = 0,
    LunarSkibidi    = 0,
    GalacticMewing  = 0,
    NovaSigma       = 0,
    BlackHoleRizz   = 0,
    UniverseChad    = 0,
    CosmicSkibidi   = 0,
    AbsoluteGigachad = 0,
    TrueOmegaSigma  = 0,
    StarNoob        = 0,
    NebulaSigma     = 0,
    CelestialRizz   = 0,
    CosmicGigachad  = 0,
}

-- Références aux éléments de chaque socle (rempli pendant la construction)
local pedestalRefs: {[number]: {top: Part, nameLabel: TextLabel, decal: Decal}} = {}
-- Parts de figurines actuellement affichées sur les socles
local displayParts: {[number]: Part} = {}

-- ═══════════════════════════════════════════════════════════════════════════════
-- NOMS DES SLOTS (placeholder — modifie ici pour changer les noms exposés)
-- Ordre : L1, R1, L2, R2, L3, R3, L4, R4, L5, R5
-- ═══════════════════════════════════════════════════════════════════════════════
local SLOT_NAMES: {string} = {
    [1]  = "???  Slot 1",   -- L1 → première place gauche
    [2]  = "???  Slot 2",   -- R1 → première place droite
    [3]  = "???  Slot 3",
    [4]  = "???  Slot 4",
    [5]  = "???  Slot 5",
    [6]  = "???  Slot 6",
    [7]  = "???  Slot 7",
    [8]  = "???  Slot 8",
    [9]  = "???  Slot 9",
    [10] = "???  Slot 10",  -- R5 → dernière place droite
}

-- Disposition
local NUM_SIDES   = 5          -- 5 socles de chaque côté
local PLACE_GAP   = 16         -- Distance entre chaque place (Z)
local SIDE_DIST   = 16         -- Distance du centre au socle (X)
local CORRIDOR_W  = 44         -- Largeur du couloir (X total)
local WALL_H      = 20         -- Hauteur des murs
local WALL_T      = 2          -- Épaisseur des murs

-- Point de départ : derrière le spawn (spawn à Z=80, galerie commence à Z=100)
local START_Z  = 110
-- Niveau du sol : 0.5 au-dessus du sol principal (évite le Z-fighting)
local FLOOR_Y  = 1    -- Positionné 1 stud au-dessus du sol de WorldAssets (Y=0)
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
    p.Reflectance = 0          -- Aucun reflet sur aucune brique
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
    -- Centre du sol : assis sur Y=0 (sol principal), son dessus est à Y=1
    Vector3.new(0, FLOOR_Y - 0.5, START_Z + GALLERY_LEN / 2),
    COL_FLOOR,
    Enum.Material.SmoothPlastic,
    Enum.SurfaceType.Studs  -- Style LEGO
)

-- Ligne rouge centrale : posée à plat SUR le sol de la galerie (Y=1)
-- Très fine (0.1) pour ne pas gêner la marche
makePart(
    "CenterLine",
    Vector3.new(1.5, 0.1, GALLERY_LEN + 8),
    Vector3.new(0, FLOOR_Y + 0.05, START_Z + GALLERY_LEN / 2),
    COL_RED_LINE,
    Enum.Material.SmoothPlastic,
    Enum.SurfaceType.Smooth
)

-- ══════════════════════════════════════════════════════════════════════════════
-- 2. MURS DU COULOIR — 2 grandes dalles continues (toute la longueur)
-- ══════════════════════════════════════════════════════════════════════════════
local FULL_WALL_LEN = GALLERY_LEN + 8  -- Même longueur que le sol
local WALL_CZ = START_Z + GALLERY_LEN / 2

-- Mur gauche continu avec aspect LEGO (studs visibles sur le dessus)
makePart(
    "WallLeft",
    Vector3.new(WALL_T, WALL_H, FULL_WALL_LEN),
    Vector3.new(-(CORRIDOR_W / 2), FLOOR_Y + WALL_H / 2, WALL_CZ),
    COL_WALL_MID,
    Enum.Material.SmoothPlastic,
    Enum.SurfaceType.Studs
)

-- Mur droit continu
makePart(
    "WallRight",
    Vector3.new(WALL_T, WALL_H, FULL_WALL_LEN),
    Vector3.new(CORRIDOR_W / 2, FLOOR_Y + WALL_H / 2, WALL_CZ),
    COL_WALL_MID,
    Enum.Material.SmoothPlastic,
    Enum.SurfaceType.Studs
)

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
local ceiling = makePart(
    "GalleryCeiling",
    Vector3.new(CORRIDOR_W, 1, GALLERY_LEN + 8),
    Vector3.new(0, FLOOR_Y + WALL_H + 0.5, START_Z + GALLERY_LEN / 2),
    Color3.fromRGB(40, 40, 40),   -- Anthracite, symétrique avec le sol
    Enum.Material.SmoothPlastic,
    Enum.SurfaceType.Studs
)
ceiling.Reflectance = 0

-- Ligne rouge au plafond (miroir de celle du sol)
makePart(
    "CeilingRedLine",
    Vector3.new(1.5, 0.1, GALLERY_LEN + 8),
    Vector3.new(0, FLOOR_Y + WALL_H, START_Z + GALLERY_LEN / 2),
    COL_RED_LINE,
    Enum.Material.SmoothPlastic
)

-- ══════════════════════════════════════════════════════════════════════════════
-- 4. SOCLES D'EXPOSITION (5 gauche + 5 droite)
-- ══════════════════════════════════════════════════════════════════════════════
for i = 1, NUM_SIDES do
    local placeZ = START_Z + i * PLACE_GAP

    for _, side in ipairs({ -1, 1 }) do -- -1 = gauche, +1 = droite
        local sideLabel = side == -1 and "L" or "R"
        local baseX = side * SIDE_DIST

        -- Base du socle (grande) — nuance de gris selon la rangée
        local base = makePart(
            "PedestalBase_" .. i .. sideLabel,
            Vector3.new(7, 1.5, 7),
            Vector3.new(baseX, FLOOR_Y + 0.75, placeZ),
            PEDESTAL_BASE_SHADES[i],
            Enum.Material.SmoothPlastic,
            Enum.SurfaceType.Studs
        )

        -- Colonne intermédiaire
        makePart(
            "PedestalMid_" .. i .. sideLabel,
            Vector3.new(5, 1, 5),
            Vector3.new(baseX, FLOOR_Y + 2, placeZ),
            PEDESTAL_BASE_SHADES[i],
            Enum.Material.SmoothPlastic,
            Enum.SurfaceType.Studs
        )

        -- Plateau supérieur (où le modèle sera posé)
        local topPart = makePart(
            "PedestalTop_" .. i .. sideLabel,
            Vector3.new(6, 0.5, 6),
            Vector3.new(baseX, FLOOR_Y + 2.75, placeZ),
            PEDESTAL_TOP_SHADES[i],
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

        -- ── CADRE EN OR (4 bordures — style vrai cadre de tableau) ─────────────
        local wallInnerX = side * (CORRIDOR_W / 2 - WALL_T - 0.05)
        local frameH  = 10    -- Hauteur totale du cadre
        local frameW  = 10    -- Largeur totale (sens Z)
        local frameCY = FLOOR_Y + 9
        local bT      = 0.75  -- Épaisseur de chaque bordure

        -- Bordure haute
        local fTop = makePart("GoldFrameTop_"..i..sideLabel,
            Vector3.new(0.15, bT, frameW),
            Vector3.new(wallInnerX, frameCY + (frameH - bT) / 2, placeZ),
            COL_GOLD, Enum.Material.Metal)
        fTop.CanCollide = false

        -- Bordure basse
        local fBot = makePart("GoldFrameBot_"..i..sideLabel,
            Vector3.new(0.15, bT, frameW),
            Vector3.new(wallInnerX, frameCY - (frameH - bT) / 2, placeZ),
            COL_GOLD, Enum.Material.Metal)
        fBot.CanCollide = false

        -- Bordure gauche (sens Z : côté min)
        local fLeft = makePart("GoldFrameLeft_"..i..sideLabel,
            Vector3.new(0.15, frameH - bT * 2, bT),
            Vector3.new(wallInnerX, frameCY, placeZ - (frameW - bT) / 2),
            COL_GOLD, Enum.Material.Metal)
        fLeft.CanCollide = false

        -- Bordure droite (sens Z : côté max)
        local fRight = makePart("GoldFrameRight_"..i..sideLabel,
            Vector3.new(0.15, frameH - bT * 2, bT),
            Vector3.new(wallInnerX, frameCY, placeZ + (frameW - bT) / 2),
            COL_GOLD, Enum.Material.Metal)
        fRight.CanCollide = false

        -- ── PLAQUE D'IDENTIFICATION (au pied du socle) ──────────────────────────
        local slotIndex = (i - 1) * 2 + (side == -1 and 1 or 2)
        local slotName  = SLOT_NAMES[slotIndex] or ("Slot " .. slotIndex)

        -- Part noire plate, face côté couloir
        local plaque = makePart(
            "Plaque_" .. i .. sideLabel,
            Vector3.new(7, 0.3, 1.5),
            Vector3.new(baseX, FLOOR_Y + 1.55 + 0.15, placeZ),
            COL_PLAQUE,
            Enum.Material.SmoothPlastic
        )
        plaque.CanCollide = false
        -- Fine bordure dorée autour de la plaque (top rim)
        local plaqueRim = makePart(
            "PlaqueRim_" .. i .. sideLabel,
            Vector3.new(7.3, 0.1, 1.8),
            Vector3.new(baseX, FLOOR_Y + 1.55, placeZ),
            COL_GOLD,
            Enum.Material.Metal
        )
        plaqueRim.CanCollide = false

        -- SurfaceGui sur la face avant de la plaque (côté -Z = face au script d'entrée)
        local sGui = Instance.new("SurfaceGui")
        sGui.Name        = "NamePlaque"
        sGui.Face        = Enum.NormalId.Top   -- Visible du dessus / joueur debout
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

        -- ── PANNEAU IMAGE (fond du cadre, porte le Decal) ───────────────────────
        local innerH = frameH - bT * 2
        local innerW = frameW - bT * 2
        local imgPanel = makePart(
            "ImgPanel_" .. i .. sideLabel,
            Vector3.new(0.12, innerH, innerW),
            Vector3.new(wallInnerX, frameCY, placeZ),
            Color3.fromRGB(20, 20, 20),   -- Fond sombre (contraste image)
            Enum.Material.SmoothPlastic
        )
        imgPanel.CanCollide = false

        local decal = Instance.new("Decal")
        decal.Texture = ""   -- Vide par défaut, mis à jour par refreshGallery
        decal.Face    = side == -1 and Enum.NormalId.Right or Enum.NormalId.Left
        decal.Parent  = imgPanel

        -- Stocker la référence pour mise à jour dynamique
        pedestalRefs[slotIndex] = {top = topPart, nameLabel = nameLabel, decal = decal}

        -- ── SPOT AU SOL (orienté vers le haut — effet dramatique) ───────────────
        -- Petite Part noire au sol, juste devant le socle côté couloir
        local floorSpotPart = makePart(
            "FloorSpot_" .. i .. sideLabel,
            Vector3.new(0.6, 0.3, 0.6),
            -- Placé entre le socle et le centre du couloir, à la surface du sol
            Vector3.new(baseX - side * 4, FLOOR_Y + 0.15, placeZ),
            Color3.fromRGB(30, 30, 30),
            Enum.Material.Metal
        )
        floorSpotPart.CanCollide = false

        local floorSpot = Instance.new("SpotLight")
        floorSpot.Face       = Enum.NormalId.Top
        floorSpot.Brightness = 1.5
        floorSpot.Range      = 8     -- Zone socle uniquement
        floorSpot.Angle      = 30    -- Cône resserré = lumière nette
        floorSpot.Color      = Color3.fromRGB(255, 240, 200)
        floorSpot.Shadows    = true
        floorSpot.Parent     = floorSpotPart
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 5. ENTRÉE DE LA GALERIE (arche + enseigne physique)
-- ══════════════════════════════════════════════════════════════════════════════

-- ── ENSEIGNE PHYSIQUE "Base de [Joueur]" ──────────────────────────────────────
-- Plaque épaisse (Z=3) orientée par défaut : Front face = -Z = vers le spawn (Z=80)
-- Position : 6 studs DEVANT l'entrée de la galerie, en plein air
local signPlaque = makePart(
    "GallerySignPlaque",
    Vector3.new(CORRIDOR_W - 4, 5, 3),    -- Z=3 : épaisseur suffisante, pas de z-clip
    Vector3.new(0, FLOOR_Y + WALL_H - 2, START_Z - 6),
    COL_PLAQUE,
    Enum.Material.SmoothPlastic
)
signPlaque.CanCollide = false

-- Bordure dorée (derrière la plaque, côté galerie)
local signRim = makePart(
    "GallerySignRim",
    Vector3.new(CORRIDOR_W - 2, 5.5, 0.4),
    Vector3.new(0, FLOOR_Y + WALL_H - 2, START_Z - 4.3),
    COL_GOLD,
    Enum.Material.Metal
)
signRim.CanCollide = false

-- ── SurfaceGui — face FRONT (-Z) vers le spawn ───────────────────────────────
-- LightInfluence = 0 : TOUJOURS visible, même dans une galerie sombre
-- Le texte rouge est provisoire pour vérifier la visibilité ; le LocalScript
-- GallerySignClient le remplace par "BASE DE [Joueur]" en jaune.
local signSGui = Instance.new("SurfaceGui")
signSGui.Name           = "GallerySignGui"
signSGui.Face           = Enum.NormalId.Front  -- -Z = face vers le spawn
signSGui.CanvasSize     = Vector2.new(520, 100)
signSGui.SizingMode     = Enum.SurfaceGuiSizingMode.FixedSize
signSGui.LightInfluence = 0       -- CRITIQUE : indépendant de l'éclairage ambiant
signSGui.AlwaysOnTop    = false
signSGui.ZOffset        = 1
signSGui.Parent         = signPlaque

local signLabelRef: TextLabel

local signLabel = Instance.new("TextLabel")
signLabel.Name                   = "GallerySignLabel"
signLabel.Size                   = UDim2.new(1, 0, 1, 0)
signLabel.BackgroundColor3       = Color3.new(0, 0, 0)
signLabel.BackgroundTransparency = 0.1
signLabel.Text                   = "★  BASE BRAINROT  ★"
signLabel.TextColor3             = Color3.fromRGB(255, 0, 0)   -- ROUGE : debug visibilité
signLabel.Font                   = Enum.Font.GothamBlack
signLabel.TextScaled             = true
signLabel.TextStrokeTransparency = 0
signLabel.TextStrokeColor3       = Color3.new(0, 0, 0)
signLabel.Parent                 = signSGui
signLabelRef                     = signLabel

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent       = signLabel


-- ── LAMPADAIRES D'ENTRÉE — encadrement gauche/droit de la porte ──────────────
do
    local LAMP_POLE_COLOR = Color3.fromRGB(50, 50, 55)
    local LAMP_BULB_COLOR = Color3.fromRGB(255, 220, 120)
    local poleH = 16

    for _, side in ipairs({-1, 1}) do
        local sLbl = side == -1 and "L" or "R"
        -- X : juste à la face extérieure du mur (CORRIDOR_W/2 + 1)
        local lx   = side * (CORRIDOR_W / 2 + 1)
        -- Z : même plan que l'enseigne, clairement devant la galerie
        local lz   = START_Z - 4

        -- Poteau métal
        local pole = makePart("EntryPole_" .. sLbl,
            Vector3.new(1, poleH, 1),
            Vector3.new(lx, FLOOR_Y + poleH / 2, lz),
            LAMP_POLE_COLOR, Enum.Material.Metal)
        pole.CanCollide = false

        -- Capot plat au sommet
        local cap = makePart("EntryLampCap_" .. sLbl,
            Vector3.new(2.8, 0.5, 2.8),
            Vector3.new(lx, FLOOR_Y + poleH + 0.25, lz),
            LAMP_POLE_COLOR, Enum.Material.Metal)
        cap.CanCollide = false

        -- Ampoule (SmoothPlastic — pas Neon pour éviter le halo)
        local bulb = makePart("EntryLampBulb_" .. sLbl,
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

print("[BrainrotGallery] Galerie generee ! " .. (NUM_SIDES * 2) .. " socles prets.")

-- ══════════════════════════════════════════════════════════════════════════════
-- 6. ÉCLAIRAGE PLAFOND — PointLights réguliers pour une galerie bien éclairée
-- ══════════════════════════════════════════════════════════════════════════════
for j = 1, NUM_SIDES do
    local lightZ = START_Z + j * PLACE_GAP
    local lightPart = makePart(
        "CeilingLight_" .. j,
        Vector3.new(1.5, 0.3, 1.5),
        Vector3.new(0, FLOOR_Y + WALL_H - 0.5, lightZ),
        Color3.fromRGB(255, 255, 240),  -- Blanc chaud
        Enum.Material.SmoothPlastic     -- Pas Neon : évite le halo fantôme
    )
    lightPart.CanCollide = false
    local pt = Instance.new("PointLight")
    pt.Brightness = 1.2
    pt.Range      = 14    -- Zone immédiate uniquement — pas de bave hors murs
    pt.Color      = Color3.fromRGB(255, 240, 200)
    pt.Shadows    = false
    pt.Parent     = lightPart
end
print("[BrainrotGallery] Eclairage plafond ajoute")

-- ══════════════════════════════════════════════════════════════════════════════
-- 7. LUMIÈRES D'AMBIANCE — Coins + remplissage mi-mur
-- ══════════════════════════════════════════════════════════════════════════════
-- Blanc pur pour maximiser la réflexion sur les surfaces sombres
local AMB_COLOR      = Color3.fromRGB(255, 255, 255)
local AMB_BRIGHTNESS = 3.5
local AMB_RANGE      = 25

-- Décalé 4 studs depuis la face intérieure du mur → dans l'air libre, jamais dans la géo
local edgeX = CORRIDOR_W / 2 - WALL_T - 4   -- ≈ 16
local midY  = FLOOR_Y + WALL_H / 2            -- Mi-hauteur ≈ 11
local frontZ = START_Z + 2
local backZ  = START_Z + GALLERY_LEN + 2

local ambientPositions = {
    -- 4 coins principaux
    Vector3.new(-edgeX, midY, frontZ),
    Vector3.new( edgeX, midY, frontZ),
    Vector3.new(-edgeX, midY, backZ),
    Vector3.new( edgeX, midY, backZ),
    -- 4 remplissages au 1/3 et 2/3 de la galerie (chaque côté)
    Vector3.new(-edgeX, midY, START_Z + GALLERY_LEN * 0.33),
    Vector3.new( edgeX, midY, START_Z + GALLERY_LEN * 0.33),
    Vector3.new(-edgeX, midY, START_Z + GALLERY_LEN * 0.66),
    Vector3.new( edgeX, midY, START_Z + GALLERY_LEN * 0.66),
}

for k, pos in ipairs(ambientPositions) do
    local amb = Instance.new("Part")
    amb.Name        = "AmbientLight_" .. k
    amb.Size        = Vector3.new(0.2, 0.2, 0.2)
    amb.Position    = pos
    amb.Anchored    = true
    amb.CanCollide  = false
    amb.Transparency = 1   -- Invisible : source pure, pas de géométrie visible
    amb.CastShadow  = false
    amb.Parent      = galleryFolder

    local pl = Instance.new("PointLight")
    pl.Color      = AMB_COLOR
    pl.Brightness = AMB_BRIGHTNESS
    pl.Range      = AMB_RANGE
    pl.Shadows    = false  -- Pas d'ombres : débouche les recoins sans alourdir le rendu
    pl.Parent     = amb
end

print("[BrainrotGallery] 8 lumieres d'ambiance ajoutees")

-- ══════════════════════════════════════════════════════════════════════════════
-- 8. ENSEIGNE DYNAMIQUE + GALERIE RÉACTIVE à l'inventaire du joueur
-- ══════════════════════════════════════════════════════════════════════════════
local function updateSign(playerName: string)
    if signLabelRef then
        signLabelRef.Text = "★  BASE DE " .. string.upper(playerName) .. "  ★"
    end
end

-- Crée ou remplace la figurine d'un socle
local function createFigurine(slotIndex: number, itemData: {Name: string, Rarity: string}?)
    if displayParts[slotIndex] then
        displayParts[slotIndex]:Destroy()
        displayParts[slotIndex] = nil
    end
    if not itemData then return end

    local refs = pedestalRefs[slotIndex]
    if not refs then return end

    local topPos      = refs.top.Position
    local rarityColor = RARITY_COLOR[itemData.Rarity] or RARITY_COLOR.NORMAL
    local isHighRarity = itemData.Rarity == "ULTRA" or itemData.Rarity == "LEGENDARY"

    local fig = Instance.new("Part")
    fig.Name        = "Figurine_" .. slotIndex
    fig.Size        = Vector3.new(3, 4, 3)
    fig.Position    = topPos + Vector3.new(0, 2.25, 0)
    fig.Anchored    = true
    fig.CanCollide  = false
    fig.Color       = rarityColor
    fig.Material    = Enum.Material.SmoothPlastic  -- Pas Neon : évite le halo
    fig.Reflectance = isHighRarity and 0.1 or 0
    fig.Parent      = galleryFolder

    if itemData.Rarity == "ULTRA" then
        local sparkles = Instance.new("Sparkles")
        sparkles.SparkleColor = rarityColor
        sparkles.Parent       = fig
    end

    if isHighRarity then
        local light = Instance.new("PointLight")
        light.Color      = rarityColor
        light.Brightness = 1.5
        light.Range      = 6   -- Limité au socle
        light.Parent     = fig
    end

    -- BillboardGui avec le nom de l'item au-dessus de la figurine
    local bb = Instance.new("BillboardGui")
    bb.Size         = UDim2.new(0, 160, 0, 36)
    bb.StudsOffset  = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop  = false
    bb.MaxDistance  = 40
    bb.Adornee      = fig
    bb.Parent       = fig

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

    displayParts[slotIndex] = fig
end

-- Met à jour toute la galerie à partir des données du joueur
local function refreshGallery(player: Player)
    -- Polling : attend que DataManager ait chargé les données (max 10 sec)
    local data = nil
    for _ = 1, 20 do
        data = DataManager.GetData(player)
        if data then break end
        task.wait(0.5)
    end

    updateSign(player.Name)

    if not data then
        print("[BrainrotGallery] Aucune donnée pour " .. player.Name .. " — socles vides")
        return
    end

    -- Collecter les items possédés avec infos
    local ownedItems: {{Name: string, Rarity: string, Priority: number}} = {}
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

    -- Trier par rareté décroissante puis par nom
    table.sort(ownedItems, function(a, b)
        if a.Priority ~= b.Priority then return a.Priority > b.Priority end
        return a.Name < b.Name
    end)

    -- Mettre à jour chaque socle
    for slotIndex = 1, NUM_SIDES * 2 do
        local item = ownedItems[slotIndex]
        local refs = pedestalRefs[slotIndex]
        if refs then
            if item then
                refs.nameLabel.Text       = item.Name
                refs.nameLabel.TextColor3 = RARITY_COLOR[item.Rarity] or COL_GOLD
                createFigurine(slotIndex, item)
                -- Decal : cherche l'image correspondant à l'item dans BRAINROT_DATA
                local imgId = BRAINROT_DATA[item.Id or ""]
                if imgId and imgId ~= 0 then
                    refs.decal.Texture = "rbxassetid://" .. imgId
                else
                    refs.decal.Texture = ""
                end
            else
                refs.nameLabel.Text       = "???  Slot " .. slotIndex
                refs.nameLabel.TextColor3 = COL_GOLD
                createFigurine(slotIndex, nil)
                refs.decal.Texture = ""
            end
        end
    end

    print("[BrainrotGallery] Galerie mise a jour pour " .. player.Name
        .. " (" .. #ownedItems .. " items)")
end

-- Premier joueur qui rejoint (mode normal)
Players.PlayerAdded:Connect(function(player)
    task.spawn(refreshGallery, player)
end)
-- Cas Studio : joueur déjà connecté au démarrage du script
for _, p in ipairs(Players:GetPlayers()) do
    task.spawn(refreshGallery, p)
    break  -- Un seul propriétaire par base
end

--!strict
-- BrainrotGallery.server.lua
-- Génère une galerie d'exposition style LEGO avec 10 socles (5 gauche + 5 droite)
-- Placé dans ServerScriptService, synchronisé par Rojo
-- Position : derrière le spawn (Z > 80), aligné sur l'axe central

local Workspace = game:GetService("Workspace")
local Players   = game:GetService("Players")

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
local COL_GOLD       = Color3.fromRGB(255, 215,   0) -- Or (cadres)
local COL_PLAQUE     = Color3.fromRGB( 20,  20,  25) -- Noir profond (plaque texto)

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
local SIDE_DIST   = 12         -- Distance du centre au socle (X)
local CORRIDOR_W  = 30         -- Largeur du couloir (X total)
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

        -- ── CADRE EN OR PLAT (une seule Part fine plaquée contre le mur) ──────────
        -- Le mur intérieur est à X = side * (CORRIDOR_W/2 - WALL_T)
        -- Le cadre est flush contre cette face (0.05 stud devant pour le relief)
        local wallInnerX = side * (CORRIDOR_W / 2 - WALL_T - 0.05)
        local frameH  = 10   -- Hauteur visuelle du cadre
        local frameW  = 10   -- Largeur du cadre (sens Z)
        local frameCY = FLOOR_Y + 9  -- Centre vertical

        -- Un seul rectangle plat, très fin (0.1), plaque d'or sur le mur
        local frame = makePart(
            "GoldFrame_" .. i .. sideLabel,
            Vector3.new(0.1, frameH, frameW),
            Vector3.new(wallInnerX, frameCY, placeZ),
            COL_GOLD,
            Enum.Material.Metal
        )
        frame.CanCollide = false

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
        floorSpot.Brightness = 1.5   -- Réduit (5→1.5) : accent doux, pas de flash
        floorSpot.Range      = 12    -- Portée réduite, cible le cadre uniquement
        floorSpot.Angle      = 30    -- Cône resserré = lumière nette
        floorSpot.Color      = Color3.fromRGB(255, 240, 200)
        floorSpot.Shadows    = true
        floorSpot.Parent     = floorSpotPart
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 5. ENTRÉE DE LA GALERIE (arche + enseigne physique)
-- ══════════════════════════════════════════════════════════════════════════════

-- Pilier gauche d'entrée
makePart(
    "EntryPillarL",
    Vector3.new(3, WALL_H, 3),
    Vector3.new(-(CORRIDOR_W / 2) + 1.5, FLOOR_Y + WALL_H / 2, START_Z - 1),
    COL_WALL_MID,
    Enum.Material.SmoothPlastic,
    Enum.SurfaceType.Studs
)
-- Pilier droit d'entrée
makePart(
    "EntryPillarR",
    Vector3.new(3, WALL_H, 3),
    Vector3.new(CORRIDOR_W / 2 - 1.5, FLOOR_Y + WALL_H / 2, START_Z - 1),
    COL_WALL_MID,
    Enum.Material.SmoothPlastic,
    Enum.SurfaceType.Studs
)
-- Linteau rouge (dessus de l'arche)
makePart(
    "EntryLintel",
    Vector3.new(CORRIDOR_W, 4, 3),
    Vector3.new(0, FLOOR_Y + WALL_H - 2, START_Z - 1),
    COL_RED_LINE,
    Enum.Material.SmoothPlastic
)

-- ── ENSEIGNE PHYSIQUE "Base de [Joueur]" ──────────────────────────────────────
-- Plaque noire principale (large, style LEGO)
local signPlaque = makePart(
    "GallerySignPlaque",
    Vector3.new(CORRIDOR_W - 4, 5, 0.8),
    Vector3.new(0, FLOOR_Y + WALL_H - 2, START_Z - 2.6),
    COL_PLAQUE,
    Enum.Material.SmoothPlastic
)
signPlaque.CanCollide = false

-- Bordure dorée (légèrement plus grande)
local signRim = makePart(
    "GallerySignRim",
    Vector3.new(CORRIDOR_W - 2, 5.5, 0.4),
    Vector3.new(0, FLOOR_Y + WALL_H - 2, START_Z - 2.9),
    COL_GOLD,
    Enum.Material.Metal
)
signRim.CanCollide = false

-- SurfaceGui sur la face avant (-Z) de la plaque
-- Le texte "Base de {Joueur}" est mis à jour dynamiquement par GallerySign.client.lua
local signGui = Instance.new("SurfaceGui")
signGui.Name       = "GallerySignGui"
signGui.Face       = Enum.NormalId.Front   -- face vers l'entrée (-Z)
signGui.CanvasSize = Vector2.new(700, 120)
signGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
signGui.AlwaysOnTop = false
signGui.Parent     = signPlaque

local signLabel = Instance.new("TextLabel")
signLabel.Name                   = "GallerySignLabel"
signLabel.Size                   = UDim2.new(1, 0, 1, 0)
signLabel.BackgroundTransparency = 1
signLabel.Text                   = "★  BASE BRAINROT  ★"
signLabel.TextColor3             = COL_GOLD
signLabel.Font                   = Enum.Font.FredokaOne
signLabel.TextSize               = 58
signLabel.TextXAlignment         = Enum.TextXAlignment.Center
signLabel.TextYAlignment         = Enum.TextYAlignment.Center
signLabel.TextStrokeTransparency = 0.3
signLabel.TextStrokeColor3       = Color3.fromRGB(80, 10, 0)
signLabel.Parent                 = signGui


print("🏛️ [BrainrotGallery] Galerie générée ! " .. (NUM_SIDES * 2) .. " socles prêts.")

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
        Enum.Material.Neon
    )
    lightPart.CanCollide = false
    local pt = Instance.new("PointLight")
    pt.Brightness = 1.2   -- Réduit (5 → 1.2) : ambiance douce, pas éblouissant
    pt.Range      = CORRIDOR_W + 5  -- Portée réduite (pas besoin d'éclairer au-delà des murs)
    pt.Color      = Color3.fromRGB(255, 240, 200)
    pt.Shadows    = false
    pt.Parent     = lightPart
end
print("💡 [BrainrotGallery] Éclairage plafond ajouté")

-- ══════════════════════════════════════════════════════════════════════════════
-- 7. ENSEIGNE DYNAMIQUE — nom du joueur mis à jour côté SERVEUR
--    SurfaceGui étant répliqué, tous les clients voient le bon texte
-- ══════════════════════════════════════════════════════════════════════════════
local function updateSign(playerName: string)
    local plaque = galleryFolder:FindFirstChild("GallerySignPlaque")
    if not plaque then return end
    local gui = plaque:FindFirstChild("GallerySignGui")
    if not gui then return end
    local lbl = gui:FindFirstChild("GallerySignLabel")
    if lbl then
        lbl.Text = "★  BASE DE " .. string.upper(playerName) .. "  ★"
        print("🏷️ [BrainrotGallery] Enseigne : BASE DE " .. playerName)
    end
end

-- Premier joueur qui rejoint (en jeu normal)
Players.PlayerAdded:Connect(function(player)
    updateSign(player.Name)
end)
-- Cas Studio : joueur déjà présent au démarrage du script
for _, p in ipairs(Players:GetPlayers()) do
    updateSign(p.Name)
    break  -- Un seul propriétaire par base
end

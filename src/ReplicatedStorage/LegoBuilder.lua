--!strict
-- LegoBuilder.lua
-- ModuleScript — logique partagée pour la construction style Lego Classic
-- Placé dans ReplicatedStorage pour être require() côté serveur ET client.
--
-- DIMENSIONS DE RÉFÉRENCE (en studs Roblox, 1 stud = 1 unité Roblox)
--   Brique standard 2×4 : X=2, Y=1.2, Z=4
--   Plate 2×4          : X=2, Y=0.4, Z=4
--   Baseplate 32×32    : X=32, Y=1.2, Z=32   (plaque verte sol)
--
-- SYSTÈME DE GRILLE
--   Toutes les positions sont snappées au multiple de BRICK_W/BRICK_L/BRICK_H.
--   L'origine (0,0,0) est un coin de grille valide.

local LegoBuilder = {}

-- ══════════════════════════════════════════════════════════════════════════════
-- CONSTANTES PUBLIQUES
-- ══════════════════════════════════════════════════════════════════════════════

-- Dimensions d'une brique standard (studs)
LegoBuilder.BRICK_W  = 2    -- largeur  X (studs)
LegoBuilder.BRICK_L  = 4    -- longueur Z (studs)
LegoBuilder.BRICK_H  = 1.2  -- hauteur  Y (studs)

-- Hauteur d'une plate (1/3 de brique)
LegoBuilder.PLATE_H  = 0.4

-- Épaisseur de la baseplate
LegoBuilder.BASE_H   = 1.2

-- Taille d'une dalle de sol (baseplate tile) en studs
LegoBuilder.TILE_SZ  = 32

-- Couleur du sol classique (Munsell / LEGO Bright Green)
LegoBuilder.BASE_COLOR = Color3.fromRGB(75, 151, 74)

-- Palette primaires saturées LEGO Classic
LegoBuilder.PALETTE: {Color3} = {
    Color3.fromRGB(196,  40,  28),  -- Bright Red
    Color3.fromRGB( 13, 105, 172),  -- Bright Blue
    Color3.fromRGB(245, 205,  48),  -- Bright Yellow
    Color3.fromRGB(242, 243, 242),  -- White
    Color3.fromRGB( 75, 151,  74),  -- Bright Green
    Color3.fromRGB(254, 138,  24),  -- Bright Orange
    Color3.fromRGB( 90,  57, 152),  -- Medium Lilac
    Color3.fromRGB(  0, 143, 156),  -- Bright Cyan
}

-- ══════════════════════════════════════════════════════════════════════════════
-- UTILITAIRES INTERNES
-- ══════════════════════════════════════════════════════════════════════════════

-- Aligne une valeur sur une grille de taille `step`
local function snap(v: number, step: number): number
    return math.floor(v / step + 0.5) * step
end

-- Applique les surfaces Lego canoniques à une Part
local function setSurfaces(p: Part, isBase: boolean?)
    p.TopSurface    = Enum.SurfaceType.Studs
    p.BottomSurface = if isBase then Enum.SurfaceType.Inlet else Enum.SurfaceType.Inlet
    p.FrontSurface  = Enum.SurfaceType.Smooth
    p.BackSurface   = Enum.SurfaceType.Smooth
    p.LeftSurface   = Enum.SurfaceType.Smooth
    p.RightSurface  = Enum.SurfaceType.Smooth
end

-- Propriétés communes plastique ABS
local function setABS(p: Part, color: Color3)
    p.Material    = Enum.Material.SmoothPlastic
    p.Reflectance = 0.1
    p.Color       = color
    p.Anchored    = true
    p.CanCollide  = true
    p.CastShadow  = false   -- optim : les ombres sur 1000+ briques sont coûteuses
end

-- Choisit une couleur dans la palette
local function pickColor(palette: {Color3}, index: number?): Color3
    if index then
        return palette[((index - 1) % #palette) + 1]
    end
    return palette[math.random(1, #palette)]
end

-- ══════════════════════════════════════════════════════════════════════════════
-- BRIQUE INDIVIDUELLE
-- ══════════════════════════════════════════════════════════════════════════════

--[[
    Crée une brique Lego à la position donnée (coin inférieur-gauche-avant).
    sizeX, sizeZ : dimensions en studs (défaut BRICK_W × BRICK_L).
    sizeY        : hauteur en studs   (défaut BRICK_H).
    color        : Color3 (défaut couleur aléatoire de la palette).
    parent       : Instance destination.
    Retourne la Part créée.
]]
function LegoBuilder.createBrick(
    position : Vector3,
    sizeX    : number?,
    sizeZ    : number?,
    sizeY    : number?,
    color    : Color3?,
    parent   : Instance
): Part
    local w = sizeX or LegoBuilder.BRICK_W
    local l = sizeZ or LegoBuilder.BRICK_L
    local h = sizeY or LegoBuilder.BRICK_H

    local p        = Instance.new("Part") :: Part
    p.Name         = "LegoBrick"
    p.Size         = Vector3.new(w, h, l)
    -- position = coin bas-gauche-avant → centre = position + (w/2, h/2, l/2)
    p.CFrame       = CFrame.new(position + Vector3.new(w / 2, h / 2, l / 2))
    setABS(p, color or pickColor(LegoBuilder.PALETTE))
    setSurfaces(p)
    p.Parent       = parent
    return p
end

-- ══════════════════════════════════════════════════════════════════════════════
-- BASEPLATE
-- ══════════════════════════════════════════════════════════════════════════════

--[[
    Crée une dalle de sol (32×32 studs) dont le coin supérieur-gauche-avant
    est à (worldX, floorY, worldZ).  Le dessus de la dalle est à Y = floorY.
]]
function LegoBuilder.createBaseTile(
    worldX : number,
    worldZ : number,
    floorY : number,
    parent : Instance
): Part
    local s = LegoBuilder.TILE_SZ
    local h = LegoBuilder.BASE_H

    local p        = Instance.new("Part") :: Part
    p.Name         = "BaseTile"
    p.Size         = Vector3.new(s, h, s)
    -- Centre de la dalle : milieu XZ, milieu Y en dessous de floorY
    p.CFrame       = CFrame.new(worldX + s / 2, floorY - h / 2, worldZ + s / 2)
    setABS(p, LegoBuilder.BASE_COLOR)
    setSurfaces(p, true)
    p.Parent       = parent
    return p
end

--[[
    Génère une grille de dalles de sol couvrant un rectangle.
    originX, originZ : coin inférieur-gauche world (coin de grille).
    tilesX,  tilesZ  : nombre de dalles sur chaque axe.
    floorY           : Y du dessus du sol (surface sur laquelle les briques posent).
    parent           : Folder de destination dans Workspace.

    Yield entre chaque colonne pour ne pas saturer le thread principal.
]]
function LegoBuilder.buildBaseplate(
    originX : number,
    originZ : number,
    tilesX  : number,
    tilesZ  : number,
    floorY  : number,
    parent  : Instance
)
    local s = LegoBuilder.TILE_SZ
    for tx = 0, tilesX - 1 do
        for tz = 0, tilesZ - 1 do
            LegoBuilder.createBaseTile(
                originX + tx * s,
                originZ + tz * s,
                floorY,
                parent
            )
        end
        task.wait()     -- yield par colonne → moteur physique respire
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- CONVERSION PART → EMPILEMENT DE BRIQUES
-- ══════════════════════════════════════════════════════════════════════════════

--[[
    Options de la fonction convertPartToBricks :
    {
        brickW     : number?          -- largeur X des briques (défaut BRICK_W)
        brickL     : number?          -- longueur Z des briques (défaut BRICK_L)
        brickH     : number?          -- hauteur Y des briques (défaut BRICK_H)
        colorMode  : string?          -- "random" | "uniform" | "row" | "layer"
                                      --   random  → couleur aléatoire par brique
                                      --   uniform → une couleur pour toute la Part
                                      --   row     → même couleur sur toute une rangée Y
                                      --   layer   → même couleur sur chaque couche X
        palette    : {Color3}?        -- palette custom (défaut LegoBuilder.PALETTE)
        hideSource : boolean?         -- rend la Part source invisible (défaut true)
        parent     : Instance?        -- dossier de sortie (défaut part.Parent)
    }

    NOTE : la Part source est supposée non-pivotée (ou peu pivotée).
    Pour des Parts pivotées, multiplie les positions par la CFrame de la Part.
    Un yield est effectué entre chaque couche horizontale (Y) pour l'optimisation.

    Retourne le Folder contenant toutes les briques générées.
]]
export type ConvertOptions = {
    brickW     : number?,
    brickL     : number?,
    brickH     : number?,
    colorMode  : string?,
    palette    : {Color3}?,
    hideSource : boolean?,
    parent     : Instance?,
}

function LegoBuilder.convertPartToBricks(
    part    : BasePart,
    options : ConvertOptions?
): Folder
    local opt = options or {}

    local bW      = opt.brickW    or LegoBuilder.BRICK_W
    local bL      = opt.brickL    or LegoBuilder.BRICK_L
    local bH      = opt.brickH    or LegoBuilder.BRICK_H
    local mode    = opt.colorMode or "random"
    local palette = opt.palette   or LegoBuilder.PALETTE
    local hide    = if opt.hideSource == nil then true else opt.hideSource
    local dest    = opt.parent    or part.Parent

    -- Bounding box alignée sur les axes (AABB), en supposant la Part peu pivotée
    local cf   = part.CFrame
    local size = part.Size

    -- Coin bas-gauche-avant du AABB (world space)
    local originW = cf.Position - Vector3.new(size.X / 2, size.Y / 2, size.Z / 2)

    -- Snappe l'origine sur la grille de briques
    local gox = snap(originW.X, bW)
    local goy = snap(originW.Y, bH)
    local goz = snap(originW.Z, bL)

    -- Dimensions en nombre de briques (arrondi supérieur pour couvrir entièrement)
    local nX = math.max(1, math.ceil((originW.X + size.X - gox) / bW))
    local nY = math.max(1, math.ceil((originW.Y + size.Y - goy) / bH))
    local nZ = math.max(1, math.ceil((originW.Z + size.Z - goz) / bL))

    -- Folder de sortie
    local folder      = Instance.new("Folder")
    folder.Name       = "Lego_" .. part.Name
    folder.Parent     = dest

    -- Couleur uniforme si nécessaire
    local uniformColor: Color3? = if mode == "uniform" then pickColor(palette) else nil

    -- Masque la source
    if hide then
        part.Transparency = 1
        part.CastShadow   = false
    end

    -- Génération couche par couche (Y = bas vers haut)
    for iy = 0, nY - 1 do
        -- Couleur par rangée horizontale complète
        local layerColor: Color3? = if mode == "row" then pickColor(palette, iy + 1) else nil

        for ix = 0, nX - 1 do
            -- Couleur par colonne X
            local colColor: Color3? = if mode == "layer" then pickColor(palette, ix + 1) else nil

            for iz = 0, nZ - 1 do
                local brickPos = Vector3.new(
                    gox + ix * bW,
                    goy + iy * bH,
                    goz + iz * bL
                )
                local color = uniformColor or layerColor or colColor or pickColor(palette)
                LegoBuilder.createBrick(brickPos, bW, bL, bH, color, folder)
            end
        end

        task.wait()     -- yield par couche Y → évite timeout moteur sur gros volumes
    end

    return folder
end

-- ══════════════════════════════════════════════════════════════════════════════
-- MURS PRÉDÉFINIS (helpers rapides pour bâtiments)
-- ══════════════════════════════════════════════════════════════════════════════

--[[
    Génère un mur horizontal de briques de hauteur `rows`, longueur `cols` briques.
    anchorPos : Vector3 coin bas-gauche du mur (world space, snappé à la grille).
    axis      : "X" (mur le long de X) | "Z" (mur le long de Z).
    color     : Color3 uniforme, ou nil pour couleurs aléatoires.
]]
function LegoBuilder.buildWall(
    anchorPos : Vector3,
    cols      : number,
    rows      : number,
    brickW    : number?,
    brickL    : number?,
    axis      : string?,
    color     : Color3?,
    parent    : Instance
): Folder
    local bW = brickW or LegoBuilder.BRICK_W
    local bL = brickL or LegoBuilder.BRICK_L
    local bH = LegoBuilder.BRICK_H
    local ax = axis or "Z"

    local folder      = Instance.new("Folder")
    folder.Name       = "LegoWall"
    folder.Parent     = parent

    -- Snappe l'ancre sur la grille
    local ox = snap(anchorPos.X, bW)
    local oy = snap(anchorPos.Y, bH)
    local oz = snap(anchorPos.Z, bL)

    for row = 0, rows - 1 do
        -- Décale l'offset en quinconce (bond shift) pour les rangées paires/impaires
        -- → effet jointage Lego classique (les briques alternent d'un demi-pas)
        local shift = if (row % 2 == 1) then bW / 2 else 0

        for col = 0, cols - 1 do
            local brickPos: Vector3
            if ax == "X" then
                brickPos = Vector3.new(ox + col * bW + shift, oy + row * bH, oz)
            else
                brickPos = Vector3.new(ox + shift, oy + row * bH, oz + col * bL)
            end
            LegoBuilder.createBrick(brickPos, bW, bL, bH, color or pickColor(LegoBuilder.PALETTE), folder)
        end
    end

    return folder
end

-- ══════════════════════════════════════════════════════════════════════════════

return LegoBuilder

--!strict
-- LegoRenderer.lua  (ModuleScript — ReplicatedStorage)
-- Pavage EXCLUSIF via le MeshPart "Carpet" (ReplicatedStorage.Blocks.Carpet).
-- Aucun fallback procédural : si Carpet est absent, on ne génère rien.
--
-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  ✅ ÉTAT DE RÉFÉRENCE — SOL & AVENUE PARFAITS (commit: feat/floor-v1)  ║
-- ║  Si le sol bug à nouveau, reviens à ce fichier tel quel :               ║
-- ║                                                                          ║
-- ║  • GenerateFloor()  → pave toute la carte avec Carpet.Size.X/Z (4×4)   ║
-- ║  • 3 biomes par coordonnées monde (getBiome) :                          ║
-- ║      - Herbe     : COL_GRASS  vert  (75,151,75)  rotation 0°            ║
-- ║      - Avenue    : COL_ROAD   gris  (130,130,130) rotation 90° Y        ║
-- ║      - Zone Défi : COL_CHALL  jaune (255,235,0)   rotation 0°           ║
-- ║  • Avenue calée exactement sur les galeries BrainrotGallery :           ║
-- ║      AVENUE_Z_MIN = 78  (= START_Z_SOUTH)                               ║
-- ║      AVENUE_Z_MAX = 142 (= START_Z)                                     ║
-- ║  • Purge systématique avant chaque régénération (zéro Z-fighting)       ║
-- ║  • StudRenderer : UN seul appel GenerateFloor(-400→432, -400→432, 0.9) ║
-- ╚══════════════════════════════════════════════════════════════════════════╝
--
-- API publique :
--   LegoRenderer.GenerateFloor(parent, xMin, xMax, zMin, zMax, surfY?)  → Folder?
--   LegoRenderer.AutoStud(part, opts?)                                   → Folder?
--   LegoRenderer.GenerateChallengeFloor(parent, xMin, xMax, zMin, zMax, surfY?) → Folder?
--   LegoRenderer.AddBorders(part, opts?)                                 → Folder
--   LegoRenderer.ProcessStructure(model, opts?)

local LegoRenderer = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ── Constantes ────────────────────────────────────────────────────────────────
local BORDER_H    = 0.2
local YIELD_EVERY = 500

-- ── Seuil X du biome Défis ────────────────────────────────────────────────────
local CHALLENGE_ZONE_X = 56.0

-- ── Biome Avenue (route horizontale, bande le long de l'axe X) ────────────────
-- Calé exactement sur les entrées de galeries de BrainrotGallery :
--   START_Z_SOUTH = 78  → bord sud  (entrée galeries côté SUD)
--   START_Z       = 142 → bord nord (entrée galeries côté NORD)
-- La route touche au pixel près les deux rangées de galeries — aucun écart vert.
local AVENUE_Z_MIN = 78.0   -- bord sud  de l'avenue (= START_Z_SOUTH)
local AVENUE_Z_MAX = 142.0  -- bord nord de l'avenue (= START_Z)

-- ── Palettes de couleurs ───────────────────────────────────────────────────────
local COL_GRASS  = Color3.fromRGB( 75, 151,  75)   -- Vert herbe
local COL_ROAD   = Color3.fromRGB(130, 130, 130)   -- Gris route / avenue
local COL_CHALL  = Color3.fromRGB(255, 235,   0)   -- Jaune zone Défis

-- ── Cache du MeshPart Carpet ───────────────────────────────────────────────────
local _carpet: BasePart? = nil

-- Retourne le MeshPart Carpet ou nil si introuvable.
-- WaitForChild attend la réplication réseau côté client.
local function getCarpet(): BasePart?
    if _carpet then return _carpet end

    local blocks = ReplicatedStorage:WaitForChild("Blocks", 10) :: Instance?
    if not blocks then
        warn("[LegoRenderer] ReplicatedStorage.Blocks introuvable")
        return nil
    end

    local t = (blocks :: Instance):WaitForChild("Carpet", 10) :: Instance?
    if t and (t :: Instance):IsA("BasePart") then
        _carpet = t :: BasePart
        return _carpet
    end

    warn("[LegoRenderer] Blocks.Carpet absent ou non-BasePart — génération annulée")
    return nil
end

-- ── Détection de biome par coordonnées monde ──────────────────────────────────
local function isAvenueZone(worldZ: number): boolean
    return worldZ >= AVENUE_Z_MIN and worldZ <= AVENUE_Z_MAX
end

-- Retourne (couleur, estRoute) pour un point monde.
local function getBiome(worldX: number, worldZ: number): (Color3, boolean)
    -- 1. Zone Défi (derrière le mur bleu) — priorité maximale
    if worldX >= CHALLENGE_ZONE_X and worldZ >= -115 and worldZ <= 78 then
        return COL_CHALL, false
    end
    -- 2. Avenue (bande horizontale sur l'axe Z)
    if isAvenueZone(worldZ) then
        return COL_ROAD, true
    end
    -- 3. Herbe (partout ailleurs)
    return COL_GRASS, false
end

-- ── Appliquer la couleur au clone ET à ses Textures internes ──────────────────
local function applyColor(clone: BasePart, tint: Color3)
    clone.Color = tint
    for _, child in ipairs(clone:GetChildren()) do
        if child:IsA("Texture") then
            (child :: Texture).Color3 = tint
        end
    end
end

-- ── Propriétés physiques pour une tuile décorative ────────────────────────────
local function applyPhysics(bp: BasePart)
    bp.Anchored     = true
    bp.CanCollide   = false
    bp.CanTouch     = false
    bp.CanQuery     = false
    bp.Massless     = true
    bp.CastShadow   = false
end

-- ── Purge d'un ancien dossier (évite Z-fighting au régénération) ──────────────
local function purge(parent: Instance, name: string)
    local old = parent:FindFirstChild(name)
    if old then old:Destroy() end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- GenerateFloor — Pavage direct de toute la surface en Carpet MeshPart
--
-- Paramètres :
--   parent : dossier cible dans Workspace
--   xMin/xMax, zMin/zMax : bornes en studs monde
--   surfY : Y de la SURFACE supérieure des tuiles (défaut 0)
-- ══════════════════════════════════════════════════════════════════════════════
function LegoRenderer.GenerateFloor(
    parent : Instance,
    xMin   : number,
    xMax   : number,
    zMin   : number,
    zMax   : number,
    surfY  : number?
): Folder?
    local carpet = getCarpet()
    if not carpet then return nil end
    local bX = carpet.Size.X
    local bY = carpet.Size.Y
    local bZ = carpet.Size.Z

    local tileY = (surfY or 0) - bY / 2   -- centre Y pour face sup = surfY

    -- Purge initiale
    purge(parent, "LegoFloor")
    local folder = Instance.new("Folder")
    folder.Name   = "LegoFloor"
    folder.Parent = parent

    -- Boucle de pavage — pas = taille exacte du Carpet (aucun chevauchement)
    local nX    = math.ceil((xMax - xMin) / bX)
    local nZ    = math.ceil((zMax - zMin) / bZ)
    local count = 0

    -- Rotation route : 90° autour de Y pour que le motif Carpet se distingue
    local ROAD_ROT = CFrame.Angles(0, math.rad(90), 0)

    for ix = 0, nX - 1 do
        for iz = 0, nZ - 1 do
            local wx = xMin + (ix + 0.5) * bX
            local wz = zMin + (iz + 0.5) * bZ

            local tint, isRoad = getBiome(wx, wz)
            local baseCF = CFrame.new(wx, tileY, wz)

            local clone = (carpet :: BasePart):Clone() :: BasePart
            applyPhysics(clone)
            applyColor(clone, tint)
            -- Route → rotation 90° Y pour démarquer visuellement le motif Carpet
            clone.CFrame = if isRoad then baseCF * ROAD_ROT else baseCF
            clone.Parent = folder

            count += 1
            if count % YIELD_EVERY == 0 then task.wait() end
        end
    end

    print(string.format("[LegoRenderer] GenerateFloor %d×%d = %d tuiles (X %.0f→%.0f, Z %.0f→%.0f)",
        nX, nZ, count, xMin, xMax, zMin, zMax))
    return folder
end

-- ══════════════════════════════════════════════════════════════════════════════
-- AutoStud — tuile la face d'une BasePart existante
-- ══════════════════════════════════════════════════════════════════════════════
type Opts = {
    material : Enum.Material?,
    face     : string?,
}

function LegoRenderer.AutoStud(part: BasePart, opts: Opts?): Folder?
    local carpet = getCarpet()
    if not carpet then return nil end

    local o    = opts or {}
    local face = o.face or "Top"

    -- Purge d'un éventuel dossier précédent pour cette part
    purge(part.Parent or game.Workspace, "LegoTiles_" .. part.Name)

    local folder = Instance.new("Folder")
    folder.Name   = "LegoTiles_" .. part.Name
    folder.Parent = part.Parent

    local bX = carpet.Size.X
    local bY = carpet.Size.Y
    local bZ = carpet.Size.Z

    local cf = part.CFrame
    local sz = part.Size

    local surfW: number
    local surfL: number
    local offX = 0
    local offY = 0
    local offZ = 0

    if face == "Top" then
        surfW, surfL = sz.X, sz.Z
        offY =  sz.Y / 2 - bY / 2
    elseif face == "Bottom" then
        surfW, surfL = sz.X, sz.Z
        offY = -(sz.Y / 2 - bY / 2)
    elseif face == "Front" then
        surfW, surfL = sz.X, sz.Y
        offZ = -(sz.Z / 2 - bZ / 2)
    elseif face == "Back" then
        surfW, surfL = sz.X, sz.Y
        offZ =  sz.Z / 2 - bZ / 2
    elseif face == "Right" then
        surfW, surfL = sz.Z, sz.Y
        offX =  sz.X / 2 - bX / 2
    else  -- "Left"
        surfW, surfL = sz.Z, sz.Y
        offX = -(sz.X / 2 - bX / 2)
    end

    local nX     = math.max(1, math.ceil(surfW / bX)) + 1
    local nZ     = math.max(1, math.ceil(surfL / bZ)) + 1
    local startA = -(nX * bX) / 2 + bX / 2
    local startB = -(nZ * bZ) / 2 + bZ / 2
    local count  = 0

    for ix = 0, nX - 1 do
        for iz = 0, nZ - 1 do
            local da = startA + ix * bX
            local db = startB + iz * bZ

            local brickCF: CFrame
            if face == "Top" or face == "Bottom" then
                brickCF = cf * CFrame.new(da + offX, offY, db + offZ)
            elseif face == "Front" or face == "Back" then
                brickCF = cf * CFrame.new(da + offX, db, offZ)
            else
                brickCF = cf * CFrame.new(offX, db, da + offZ)
            end

            local wx = brickCF.Position.X
            local wz = brickCF.Position.Z

            -- Skip la zone jaune (gérée par GenerateChallengeFloor)
            if wx >= CHALLENGE_ZONE_X and wz >= -115 and wz <= 78 then
                continue
            end

            local tint, isRoad = getBiome(wx, wz)
            local clone = (carpet :: BasePart):Clone() :: BasePart
            applyPhysics(clone)
            applyColor(clone, tint)
            clone.CFrame = if isRoad
                then brickCF * CFrame.Angles(0, math.rad(90), 0)
                else brickCF
            clone.Parent = folder

            count += 1
            if count % YIELD_EVERY == 0 then task.wait() end
        end
    end

    print(string.format("[LegoRenderer] '%s' %s → %d×%d = %d tuiles",
        part.Name, face, nX, nZ, count))
    return folder
end

-- ══════════════════════════════════════════════════════════════════════════════
-- GenerateChallengeFloor — Zone Défi jaune (coordonnées monde directes)
-- ══════════════════════════════════════════════════════════════════════════════
function LegoRenderer.GenerateChallengeFloor(
    parent  : Instance,
    xMin    : number,
    xMax    : number,
    zMin    : number,
    zMax    : number,
    surfY   : number?
): Folder?
    local carpet = getCarpet()
    if not carpet then return nil end

    local bX    = carpet.Size.X
    local bY    = carpet.Size.Y
    local bZ    = carpet.Size.Z
    local tileY = (surfY or 0) - bY / 2

    purge(parent, "ChallengeTiles")
    local folder = Instance.new("Folder")
    folder.Name   = "ChallengeTiles"
    folder.Parent = parent

    local nX    = math.ceil((xMax - xMin) / bX)
    local nZ    = math.ceil((zMax - zMin) / bZ)
    local count = 0

    for ix = 0, nX - 1 do
        for iz = 0, nZ - 1 do
            local wx = xMin + (ix + 0.5) * bX
            local wz = zMin + (iz + 0.5) * bZ

            local clone = (carpet :: BasePart):Clone() :: BasePart
            applyPhysics(clone)
            applyColor(clone, COL_CHALL)
            clone.CFrame = CFrame.new(wx, tileY, wz)
            clone.Parent = folder

            count += 1
            if count % YIELD_EVERY == 0 then task.wait() end
        end
    end

    print(string.format("[LegoRenderer] ChallengeTiles %d×%d = %d tuiles jaunes",
        nX, nZ, count))
    return folder
end

-- ══════════════════════════════════════════════════════════════════════════════
-- AddBorders
-- ══════════════════════════════════════════════════════════════════════════════
type BorderOpts = {
    thickness : number?,
    color     : Color3?,
}

function LegoRenderer.AddBorders(part: BasePart, opts: BorderOpts?): Folder
    local o   = opts or {}
    local t   = o.thickness or 0.05
    local col = o.color or Color3.fromRGB(39, 70, 45)

    local cf  = part.CFrame
    local sz  = part.Size
    local ht  = t / 2
    local localY = sz.Y / 2 + BORDER_H / 2 + 0.05

    local defs: {{off: Vector3, size: Vector3, name: string}} = {
        { off  = Vector3.new( 0,               localY, -(sz.Z / 2 - ht) ),
          size = Vector3.new( sz.X,            BORDER_H, t              ),
          name = "Border_N" },
        { off  = Vector3.new( 0,               localY,  (sz.Z / 2 - ht) ),
          size = Vector3.new( sz.X,            BORDER_H, t              ),
          name = "Border_S" },
        { off  = Vector3.new( (sz.X / 2 - ht), localY,  0              ),
          size = Vector3.new( t,               BORDER_H, sz.Z - t * 2  ),
          name = "Border_E" },
        { off  = Vector3.new(-(sz.X / 2 - ht), localY,  0              ),
          size = Vector3.new( t,               BORDER_H, sz.Z - t * 2  ),
          name = "Border_W" },
    }

    local folder = Instance.new("Folder")
    folder.Name   = "LegoFrame_" .. part.Name
    folder.Parent = part.Parent

    for _, def in ipairs(defs) do
        local b             = Instance.new("Part") :: Part
        b.Name              = def.name
        b.Size              = def.size
        b.CFrame            = cf * CFrame.new(def.off)
        b.Anchored          = true
        b.CanCollide        = false
        b.CanTouch          = false
        b.CanQuery          = false
        b.Massless          = true
        b.CastShadow        = false
        b.Color             = col
        b.Material          = Enum.Material.SmoothPlastic
        b.Reflectance       = 0.06
        b.TopSurface        = Enum.SurfaceType.Smooth
        b.BottomSurface     = Enum.SurfaceType.Smooth
        b.Parent            = folder
    end

    return folder
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ProcessStructure
-- ══════════════════════════════════════════════════════════════════════════════
function LegoRenderer.ProcessStructure(model: Instance, opts: Opts?)
    for _, desc in ipairs(model:GetDescendants()) do
        if not desc:IsA("BasePart") then continue end
        local part = desc :: BasePart
        local sz   = part.Size
        if part.Transparency > 0.5 then continue end
        if sz.X < 0.5 or sz.Y < 0.5 or sz.Z < 0.5 then continue end

        local nm = string.upper(part.Name)
        local o  = opts and table.clone(opts) or {}
        if not o.face then
            o.face = if string.find(nm, "WALL") then "Front" else "Top"
        end
        task.spawn(function()
            LegoRenderer.AutoStud(part, o)
        end)
    end
end

return LegoRenderer

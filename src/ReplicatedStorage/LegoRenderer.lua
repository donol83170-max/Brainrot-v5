--!strict
-- LegoRenderer.lua  (ModuleScript — ReplicatedStorage)
-- Tile le sol en clonant le MeshPart "Carpet" depuis ReplicatedStorage.Blocks.
-- Utilisé UNIQUEMENT côté client (LocalScript StudRenderer) — zéro réplication réseau.
--
-- API :
--   LegoRenderer.AutoStud(part, opts?)                          → Folder
--   LegoRenderer.GenerateChallengeFloor(parent, xMin, xMax,    → Folder
--                                        zMin, zMax, groundY?)
--   LegoRenderer.AddBorders(part, opts?)                        → Folder
--   LegoRenderer.ProcessStructure(model, opts?)

local LegoRenderer = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ── Constantes ────────────────────────────────────────────────────────────────
local BORDER_H    = 0.2
local YIELD_EVERY = 500

-- ── Seuil X du biome Défis ────────────────────────────────────────────────────
-- Mur backdrop : MACHINE_X(40) + dos machine(3.36) + recul(15.3) ≈ 58.66
-- On aligne la frontière au bord du mur pour une transition nette.
local CHALLENGE_ZONE_X = 56.0

-- ── Palettes par zone ─────────────────────────────────────────────────────────
local COL_GRASS_LIGHT = Color3.fromRGB( 75, 151,  75)
local COL_GRASS_DARK  = Color3.fromRGB( 39, 106,  39)
local COL_ROAD_LIGHT  = Color3.fromRGB(130, 130, 130)
local COL_ROAD_DARK   = Color3.fromRGB(105, 105, 105)
local COL_CHALL_LIGHT = Color3.fromRGB(255, 235,   0)  -- Jaune vif
local COL_CHALL_DARK  = Color3.fromRGB(200, 180,   0)  -- Jaune foncé

-- ── MeshPart Carpet (lazy, mis en cache) ──────────────────────────────────────
local _carpet: BasePart? = nil

local function makeFallbackPart(): BasePart
    local p             = Instance.new("Part")
    p.Name              = "Carpet_Fallback"
    p.Size              = Vector3.new(4, 0.4, 4)
    p.Anchored          = true
    p.CanCollide        = false
    p.Material          = Enum.Material.SmoothPlastic
    p.TopSurface        = Enum.SurfaceType.Smooth
    p.BottomSurface     = Enum.SurfaceType.Smooth
    p.CastShadow        = false
    return p
end

local function getCarpet(): BasePart
    if _carpet then return _carpet end

    local blocks = ReplicatedStorage:WaitForChild("Blocks", 10)
    local t = blocks and blocks:WaitForChild("Carpet", 10)

    if t and t:IsA("BasePart") then
        _carpet = t :: BasePart
    else
        warn("[LegoRenderer] Blocks.Carpet absent — fallback procédural")
        _carpet = makeFallbackPart()
    end

    return _carpet :: BasePart
end

-- ── Détection de zone ─────────────────────────────────────────────────────────
local function isRoadZone(partName: string): boolean
    local nm = string.upper(partName)
    return string.find(nm, "AVENUE") ~= nil
        or string.find(nm, "ROAD")   ~= nil
        or string.find(nm, "STREET") ~= nil
end

local function getTileColor(worldX: number, worldZ: number, road: boolean): Color3
    -- ZONES VERTES FORCÉES (Fontaine & Machine)
    local isFountainOrTrade = false
    if math.sqrt(worldX^2 + worldZ^2) <= 22 then
        isFountainOrTrade = true
    elseif math.sqrt((worldX + 25)^2 + worldZ^2) <= 18 then
        isFountainOrTrade = true
    end

    -- Zone Jaune (X >= 56 et Z central)
    local isYellowZone = worldX >= CHALLENGE_ZONE_X and worldZ >= -115 and worldZ <= 115

    if isYellowZone then
        return COL_CHALL_LIGHT    -- Zone jaune
    elseif road and not isFountainOrTrade then
        return Color3.fromRGB(130, 130, 130)  -- Gris route
    else
        return Color3.fromRGB(75, 151, 75)    -- Vert herbe
    end
end

-- ── Helpers partagés ──────────────────────────────────────────────────────────
local function applyColor(clone: BasePart, tint: Color3)
    clone.Color = tint
    for _, child in ipairs(clone:GetChildren()) do
        if child:IsA("Texture") or child:IsA("Decal") then
            (child :: Texture).Color3 = tint
        end
    end
end

local function applyPhysics(bp: BasePart)
    bp.Anchored      = true
    bp.CanCollide    = false
    bp.CanTouch      = false
    bp.CanQuery      = false
    bp.Massless      = true
    bp.CastShadow    = false
end

-- ══════════════════════════════════════════════════════════════════════════════
-- AutoStud — tuile une BasePart existante
-- ══════════════════════════════════════════════════════════════════════════════
type Opts = {
    material : Enum.Material?,
    face     : string?,
}

function LegoRenderer.AutoStud(part: BasePart, opts: Opts?): Folder
    local o    = opts or {}
    local face = o.face or "Top"

    local folder    = Instance.new("Folder")
    folder.Name     = "LegoTiles_" .. part.Name
    folder.Parent   = part.Parent

    local blockTemplate = getCarpet()
    local bX = blockTemplate.Size.X
    local bY = blockTemplate.Size.Y
    local bZ = blockTemplate.Size.Z

    local isRoad = isRoadZone(part.Name)

    local cf  = part.CFrame
    local sz  = part.Size

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

    local nX = math.max(1, math.ceil(surfW / bX)) + 1
    local nZ = math.max(1, math.ceil(surfL / bZ)) + 1

    local startA = -(nX * bX) / 2 + bX / 2
    local startB = -(nZ * bZ) / 2 + bZ / 2

    local count = 0

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

            -- ── ANTI Z-FIGHTING : skip TOUT ce qui est derrière le mur (X >= 56) ──
            -- Cela laisse GenerateChallengeFloor gérer cette zone en une fois,
            -- évitant tout flickering avec les dalles GrassBase lentes.
            if wx >= CHALLENGE_ZONE_X then
                continue
            end

            local tint  = getTileColor(wx, brickCF.Position.Z, isRoad)
            local clone = blockTemplate:Clone() :: BasePart

            applyPhysics(clone)
            applyColor(clone, tint)
            clone.Parent = folder
            clone.CFrame = brickCF

            count += 1
            if count % YIELD_EVERY == 0 then task.wait() end
        end
    end

    print(string.format("[LegoRenderer] '%s' %s → %d×%d = %d tuiles",
        part.Name, face, nX, nZ, count))

    return folder
end

-- ══════════════════════════════════════════════════════════════════════════════
-- GenerateChallengeFloor
-- Pose les tuiles jaunes en coordonnées monde directement.
-- Indépendant des BaseParts GrassBase — garanti sans doublons ni Z-fighting.
--
-- Paramètres :
--   parent   : Instance — dossier parent (ex. Workspace)
--   xMin/xMax: bornes X en studs monde (ex. 58, 150)
--   zMin/zMax: bornes Z en studs monde (ex. -115, 115)
--   groundY  : hauteur du sol (Y de la SURFACE du sol, pas du centre). Défaut 0.
-- ══════════════════════════════════════════════════════════════════════════════
function LegoRenderer.GenerateChallengeFloor(
    parent   : Instance,
    xMin     : number,
    xMax     : number,
    zMin     : number,
    zMax     : number,
    groundY  : number?
): Folder
    local surfY = groundY or 0  -- Y de la surface (sommet des tuiles)

    local blockTemplate = getCarpet()
    local bX = blockTemplate.Size.X
    local bY = blockTemplate.Size.Y
    local bZ = blockTemplate.Size.Z

    -- Centre Y du tile : sa face supérieure doit être à surfY.
    local tileCenterY = surfY - bY / 2

    local folder      = Instance.new("Folder")
    folder.Name       = "ChallengeTiles"
    folder.Parent     = parent

    local nX = math.ceil((xMax - xMin) / bX)
    local nZ = math.ceil((zMax - zMin) / bZ)

    local count = 0
    for ix = 0, nX - 1 do
        for iz = 0, nZ - 1 do
            local wx = xMin + (ix + 0.5) * bX
            local wz = zMin + (iz + 0.5) * bZ

            local tint  = getTileColor(wx, wz, false)
            local clone = blockTemplate:Clone() :: BasePart

            applyPhysics(clone)
            applyColor(clone, tint)
            clone.CFrame  = CFrame.new(wx, tileCenterY, wz)
            clone.Parent  = folder

            count += 1
            if count % YIELD_EVERY == 0 then task.wait() end
        end
    end

    print(string.format("[LegoRenderer] ChallengeTiles %d×%d = %d tuiles jaunes (X %.0f→%.0f)",
        nX, nZ, count, xMin, xMax))

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

    local folder    = Instance.new("Folder")
    folder.Name     = "LegoFrame_" .. part.Name
    folder.Parent   = part.Parent

    for _, def in ipairs(defs) do
        local b              = Instance.new("Part") :: Part
        b.Name               = def.name
        b.Size               = def.size
        b.CFrame             = cf * CFrame.new(def.off)
        b.Anchored           = true
        b.CanCollide         = false
        b.CanTouch           = false
        b.CanQuery           = false
        b.Massless           = true
        b.CastShadow         = false
        b.Color              = col
        b.Material           = Enum.Material.SmoothPlastic
        b.Reflectance        = 0.06
        b.TopSurface         = Enum.SurfaceType.Smooth
        b.BottomSurface      = Enum.SurfaceType.Smooth
        b.Parent             = folder
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

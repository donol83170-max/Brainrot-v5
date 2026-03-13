--!strict
-- LegoRenderer.lua  (ModuleScript — ReplicatedStorage)
-- Tile le sol en clonant le MeshPart "Carpet" depuis ReplicatedStorage.Blocks.
-- Utilisé UNIQUEMENT côté client (LocalScript StudRenderer) — zéro réplication réseau.
--
-- API :
--   LegoRenderer.AutoStud(part, opts?)          → Folder
--   LegoRenderer.AddBorders(part, opts?)         → Folder
--   LegoRenderer.ProcessStructure(model, opts?)  → applique AutoStud sur tout le modèle

local LegoRenderer = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ── Constantes ────────────────────────────────────────────────────────────────
local BORDER_H    = 0.2
local YIELD_EVERY = 15

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

    local blocks = ReplicatedStorage:FindFirstChild("Blocks")
    local t = blocks and blocks:FindFirstChild("Carpet")

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

-- ── Applique couleur sur le clone et ses Textures enfants ─────────────────────
local function applyColor(clone: BasePart, tint: Color3)
    clone.Color = tint
    for _, child in ipairs(clone:GetChildren()) do
        if child:IsA("Texture") or child:IsA("Decal") then
            local tex = child :: Texture
            tex.Color3 = tint
        end
    end
end

-- ── Propriétés physiques (sans toucher à l'apparence) ─────────────────────────
local function applyPhysics(bp: BasePart)
    bp.Anchored      = true
    bp.CanCollide    = false
    bp.CanTouch      = false
    bp.CanQuery      = false
    bp.Massless      = true
    bp.CastShadow    = false
end

-- ══════════════════════════════════════════════════════════════════════════════
-- AutoStud — usine de tuiles
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

    -- ── Récupération et dimensions du Carpet (MeshPart) ───────────────────────
    local blockTemplate = getCarpet()
    local bX = blockTemplate.Size.X
    local bY = blockTemplate.Size.Y
    local bZ = blockTemplate.Size.Z

    -- ── Couleur unique selon zone ──────────────────────────────────────────────
    local tint: Color3
    if isRoadZone(part.Name) then
        tint = Color3.fromRGB(130, 130, 130)  -- Gris route
    else
        tint = Color3.fromRGB(75, 151, 75)    -- Vert herbe
    end

    -- ── Dimensions de la face et offset local ─────────────────────────────────
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

    -- ── Boucle principale ─────────────────────────────────────────────────────
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

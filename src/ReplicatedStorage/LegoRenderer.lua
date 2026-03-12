--!strict
-- LegoRenderer.lua  (ModuleScript — ReplicatedStorage)
-- Tile le sol en clonant GreenBlock ou GreyBlock depuis ReplicatedStorage.Blocks.
-- Utilisé UNIQUEMENT côté client (LocalScript StudRenderer) — zéro réplication réseau.
--
-- API :
--   LegoRenderer.AutoStud(part, opts?)          → Folder  (tuile la face de la Part)
--   LegoRenderer.AddBorders(part, opts?)         → Folder  (cadre 4 lisses ultra-fins)
--   LegoRenderer.ProcessStructure(model, opts?)  → applique AutoStud sur tout le modèle

local LegoRenderer = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ── Constantes ────────────────────────────────────────────────────────────────
local BORDER_H    = 0.2   -- hauteur des lisses de bordure
local YIELD_EVERY = 15    -- nombre de clones avant un task.wait() (respiration CPU)

-- ── Dossier Blocks (lazy, mis en cache) ───────────────────────────────────────
local _blocksFolder: Folder? = nil

local function getBlocksFolder(): Folder?
    if _blocksFolder then return _blocksFolder end
    local f = ReplicatedStorage:WaitForChild("Blocks", 10)
    if f and f:IsA("Folder") then
        _blocksFolder = f :: Folder
    else
        warn("[LegoRenderer] ReplicatedStorage.Blocks introuvable après 10s")
    end
    return _blocksFolder
end

-- ── Détection de zone ─────────────────────────────────────────────────────────
local function isRoadZone(partName: string): boolean
    local nm = string.upper(partName)
    return string.find(nm, "AVENUE") ~= nil
        or string.find(nm, "ROAD")   ~= nil
        or string.find(nm, "STREET") ~= nil
end

-- ── Sélection du bon modèle selon la zone ────────────────────────────────────
--   Route / Avenue → GreyBlock
--   Herbe / Autre  → GreenBlock
local function pickBlockTemplate(partName: string): Model?
    local blocks = getBlocksFolder()
    if not blocks then return nil end

    local blockName = if isRoadZone(partName) then "GreyBlock" else "GreenBlock"
    local t = blocks:FindFirstChild(blockName)

    if not t or not t:IsA("Model") then
        warn(string.format("[LegoRenderer] Blocks.%s introuvable", blockName))
        return nil
    end
    return t :: Model
end

-- ── Palette herbe (camaïeu de verts LEGO) ────────────────────────────────────
local GRASS_PALETTE = {
    Color3.fromRGB( 75, 151,  74),  -- Bright Green   (base)
    Color3.fromRGB( 39, 125,  34),  -- Dark Green
    Color3.fromRGB( 58, 125,  21),  -- Olive Green
    Color3.fromRGB( 83, 166,  48),  -- Medium Green
    Color3.fromRGB( 48, 108,  48),  -- Sea Green
    Color3.fromRGB(106, 174,  75),  -- Light Green
    Color3.fromRGB( 62, 143,  52),  -- Forest Green
}

-- ── Applique les propriétés physiques optimisées sur un BasePart ──────────────
local function applyProps(bp: BasePart, tintColor: Color3?)
    bp.Anchored      = true
    bp.CanCollide    = false
    bp.CanTouch      = false
    bp.CanQuery      = false
    bp.Massless      = true
    bp.CastShadow    = false
    if tintColor then
        bp.Color = tintColor
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- AutoStud — usine de tuiles
--
-- 1. Choisit GreenBlock ou GreyBlock selon isRoadZone(part.Name).
-- 2. Lit les dimensions réelles du bloc via :GetExtentsSize().
-- 3. Calcule nX / nZ (math.ceil → couverture totale, zéro fente).
-- 4. Boucle ix/iz → clone:PivotTo(cf * CFrame.new(dx, dy, dz)).
--    La multiplication par cf hérite automatiquement la rotation de la Part.
-- ══════════════════════════════════════════════════════════════════════════════
type Opts = {
    material : Enum.Material?,
    face     : string?,   -- "Top"|"Bottom"|"Front"|"Back"|"Left"|"Right"
}

function LegoRenderer.AutoStud(part: BasePart, opts: Opts?): Folder
    local o    = opts or {}
    local face = o.face or "Top"

    local folder    = Instance.new("Folder")
    folder.Name     = "LegoTiles_" .. part.Name
    folder.Parent   = part.Parent

    -- ── Choix du template ─────────────────────────────────────────────────────
    local blockTemplate = pickBlockTemplate(part.Name)
    if not blockTemplate then
        warn(string.format("[LegoRenderer] '%s' : bloc absent — ignoré", part.Name))
        return folder
    end

    -- ── Dimensions du bloc (GetExtentsSize = boîte englobante du Model) ───────
    local brickSize = blockTemplate:GetExtentsSize()
    local bX = brickSize.X
    local bY = brickSize.Y
    local bZ = brickSize.Z

    -- ── Dimensions de la face et offset local ─────────────────────────────────
    --
    -- surfW / surfL : largeur et longueur de la face à couvrir.
    -- offX/Y/Z      : décalage LOCAL depuis le centre de la Part jusqu'au centre
    --                 de la première couche de briques (demi-épaisseur Part +
    --                 demi-hauteur brique, dans la direction de la normale).
    --
    local cf  = part.CFrame
    local sz  = part.Size

    local surfW: number
    local surfL: number
    local offX = 0
    local offY = 0
    local offZ = 0

    if face == "Top" then
        surfW, surfL = sz.X, sz.Z
        offY = sz.Y / 2 + bY / 2
    elseif face == "Bottom" then
        surfW, surfL = sz.X, sz.Z
        offY = -(sz.Y / 2 + bY / 2)
    elseif face == "Front" then
        surfW, surfL = sz.X, sz.Y
        offZ = -(sz.Z / 2 + bZ / 2)
    elseif face == "Back" then
        surfW, surfL = sz.X, sz.Y
        offZ = sz.Z / 2 + bZ / 2
    elseif face == "Right" then
        surfW, surfL = sz.Z, sz.Y
        offX = sz.X / 2 + bX / 2
    else  -- "Left"
        surfW, surfL = sz.Z, sz.Y
        offX = -(sz.X / 2 + bX / 2)
    end

    -- ── Nombre de tuiles (ceil → couverture garantie, zéro fente aux bords) ───
    local nX = math.max(1, math.ceil(surfW / bX))
    local nZ = math.max(1, math.ceil(surfL / bZ))

    -- Coin de départ centré sur la surface
    local startA = -(nX * bX) / 2 + bX / 2
    local startB = -(nZ * bZ) / 2 + bZ / 2

    -- ── Color Jittering (herbe uniquement) ───────────────────────────────────
    local useGrassPalette = not isRoadZone(part.Name)

    -- ── Boucle principale ─────────────────────────────────────────────────────
    local count = 0

    for ix = 0, nX - 1 do
        for iz = 0, nZ - 1 do
            local da = startA + ix * bX
            local db = startB + iz * bZ

            -- CFrame LOCAL → monde (hérite la rotation de la Part)
            local brickCF: CFrame
            if face == "Top" or face == "Bottom" then
                -- Axe 1 = X local, Axe 2 = Z local
                brickCF = cf * CFrame.new(da + offX, offY, db + offZ)
            elseif face == "Front" or face == "Back" then
                -- Axe 1 = X local, Axe 2 = Y local (hauteur du mur)
                brickCF = cf * CFrame.new(da + offX, db, offZ)
            else  -- Right / Left
                -- Axe 1 = Z local, Axe 2 = Y local
                brickCF = cf * CFrame.new(offX, db, da + offZ)
            end

            -- Couleur aléatoire de la palette herbe (ou nil pour les routes)
            local tint: Color3? = if useGrassPalette
                then GRASS_PALETTE[math.random(1, #GRASS_PALETTE)]
                else nil

            local clone = blockTemplate:Clone()

            -- Applique les optimisations physiques (+ teinte) sur tous les BaseParts
            for _, p in ipairs(clone:GetDescendants()) do
                if p:IsA("BasePart") then applyProps(p :: BasePart, tint) end
            end
            if clone.PrimaryPart then applyProps(clone.PrimaryPart, tint) end

            clone.Parent = folder
            clone:PivotTo(brickCF)

            count += 1
            if count % YIELD_EVERY == 0 then task.wait() end
        end
    end

    print(string.format("[LegoRenderer] '%s' %s (%s) → %d×%d = %d blocs",
        part.Name, face,
        if isRoadZone(part.Name) then "GreyBlock" else "GreenBlock",
        nX, nZ, count))

    return folder
end

-- ══════════════════════════════════════════════════════════════════════════════
-- AddBorders — 4 lisses ultra-fines autour de la face supérieure (Instance.new)
-- Épaisseur 0.05 studs → micro-fente visuelle entre plaques.
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

    local localY = sz.Y / 2 + BORDER_H / 2 + 0.05  -- anti Z-fighting

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
-- ProcessStructure — applique AutoStud sur toutes les Parts qualifiées d'un modèle
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

--!strict
-- LegoRenderer.lua  (ModuleScript — ReplicatedStorage)
-- Tile le sol en clonant FloorBlock depuis ReplicatedStorage.Blocks.
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

-- ── Modèle unique FloorBlock (lazy, mis en cache) ─────────────────────────────
local _floorBlock: Model? = nil

-- Crée un Model procédural de secours (Part 32×1×32) quand Rojo a supprimé Blocks/
local function makeFallbackModel(): Model
    local m   = Instance.new("Model")
    m.Name    = "FloorBlock_Fallback"
    local p   = Instance.new("Part")
    p.Name    = "FloorBlock"
    p.Size    = Vector3.new(4, 0.4, 4)   -- taille raisonnable pour le tiling
    p.Anchored      = true
    p.CanCollide    = false
    p.Material      = Enum.Material.SmoothPlastic
    p.TopSurface    = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.CastShadow    = false
    p.Parent        = m
    m.PrimaryPart   = p
    return m
end

local function getFloorBlock(): Model
    if _floorBlock then return _floorBlock end

    -- Tentative 1 : chercher dans ReplicatedStorage.Blocks (sans bloquer longtemps)
    local blocks = ReplicatedStorage:FindFirstChild("Blocks")
    local t = blocks and blocks:FindFirstChild("FloorBlock")

    if t and t:IsA("Model") then
        _floorBlock = t :: Model
    else
        -- Fallback procédural : Rojo a supprimé le dossier ou le réseau n'a pas répliqué
        warn("[LegoRenderer] Blocks.FloorBlock absent — génération d'un bloc de secours procédural")
        _floorBlock = makeFallbackModel()
    end

    return _floorBlock :: Model
end

-- ── Détection de zone ─────────────────────────────────────────────────────────
local function isRoadZone(partName: string): boolean
    local nm = string.upper(partName)
    return string.find(nm, "AVENUE") ~= nil
        or string.find(nm, "ROAD")   ~= nil
        or string.find(nm, "STREET") ~= nil
end


-- ── Applique les propriétés physiques optimisées + couleur sur un BasePart ────
local function applyProps(bp: BasePart, tintColor: Color3)
    bp.Anchored      = true
    bp.CanCollide    = false
    bp.CanTouch      = false
    bp.CanQuery      = false
    bp.Massless      = true
    bp.CastShadow    = false
    bp.Color         = tintColor
end

-- ══════════════════════════════════════════════════════════════════════════════
-- AutoStud — usine de tuiles
--
-- 1. Clone FloorBlock (modèle unique pré-construit, déjà à la bonne taille).
-- 2. Lit les dimensions via :GetExtentsSize() — aucun ScaleTo nécessaire.
-- 3. Coloration dynamique : GRASS_PALETTE (herbe) ou ROAD_PALETTE (avenue).
-- 4. Boucle ix/iz → clone:PivotTo(cf * CFrame.new(dx, dy, dz)).
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

    -- ── Récupération du FloorBlock ─────────────────────────────────────────────
    local blockTemplate = getFloorBlock()  -- toujours non-nil (fallback procédural si besoin)

    -- ── Dimensions réelles du bloc (modèle déjà à la bonne taille) ───────────
    local brickSize = blockTemplate:GetExtentsSize()
    local bX = brickSize.X
    local bY = brickSize.Y
    local bZ = brickSize.Z

    -- ── Dimensions de la face et offset local ─────────────────────────────────
    -- offY = sz.Y/2 + bY/2 - EPS : bloc posé sur la surface, légèrement rentré
    -- pour éviter le Z-fighting avec la plaque invisible.
    local cf  = part.CFrame
    local sz  = part.Size

    local surfW: number
    local surfL: number
    local offX = 0
    local offY = 0
    local offZ = 0

    -- Affleurement exact : sommet du bloc = sommet de la plaque source invisible.
    -- offY = sz.Y/2 - bY/2 → centre du bloc est à une demi-hauteur de brique
    -- sous la surface supérieure de la plaque → le dessus affleure parfaitement.
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

    -- ── Nombre de tuiles (+1 de débordement → couverture garantie jusqu'aux bords) ─
    -- Le +1 sur chaque axe ajoute une rangée/colonne supplémentaire qui dépasse
    -- légèrement la plaque source. Jamais de marges vides, quel que soit le FloorBlock.
    local nX = math.max(1, math.ceil(surfW / bX)) + 1
    local nZ = math.max(1, math.ceil(surfL / bZ)) + 1

    -- Coin de départ centré sur la surface (inchangé : le débordement est symétrique)
    local startA = -(nX * bX) / 2 + bX / 2
    local startB = -(nZ * bZ) / 2 + bZ / 2

    local isGrass = not isRoadZone(part.Name)

    -- ── Boucle principale ─────────────────────────────────────────────────────
    local count = 0

    for ix = 0, nX - 1 do
        for iz = 0, nZ - 1 do
            local da = startA + ix * bX
            local db = startB + iz * bZ

            -- CFrame LOCAL → monde (hérite la rotation de la Part)
            local brickCF: CFrame
            if face == "Top" or face == "Bottom" then
                brickCF = cf * CFrame.new(da + offX, offY, db + offZ)
            elseif face == "Front" or face == "Back" then
                brickCF = cf * CFrame.new(da + offX, db, offZ)
            else  -- Right / Left
                brickCF = cf * CFrame.new(offX, db, da + offZ)
            end

            local gridX = math.floor(brickCF.Position.X / bX)
            local gridZ = math.floor(brickCF.Position.Z / bZ)
            local isDark = (gridX + gridZ) % 2 == 0

            local tint: Color3
            if isGrass then
                if isDark then
                    tint = Color3.fromRGB(39, 106, 39)   -- Vert Foncé
                else
                    tint = Color3.fromRGB(75, 151, 75)   -- Vert Clair
                end
            else
                if isDark then
                    tint = Color3.fromRGB(105, 105, 105) -- Gris Foncé
                else
                    tint = Color3.fromRGB(130, 130, 130) -- Gris Clair
                end
            end

            local clone = blockTemplate:Clone()

            -- Applique couleur + propriétés anti-lag (taille du clone inchangée)
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

    print(string.format("[LegoRenderer] '%s' %s → %d×%d = %d blocs",
        part.Name, face, nX, nZ, count))

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

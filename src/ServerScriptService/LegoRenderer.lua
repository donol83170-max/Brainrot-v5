--!strict
-- LegoRenderer.lua  (ModuleScript)
-- Applique des studs 3D LEGO sur n'importe quelle Part, même pivotée/inclinée.
-- Utilise le CFrame réel de la Part → fonctionne sur murs, toits, troncs, etc.
--
-- API :
--   LegoRenderer.AutoStud(part, opts?)              → Folder
--   LegoRenderer.AddBorders(part, opts?)             → Folder  (cadre 4 lisses)
--   LegoRenderer.ProcessStructure(model, opts?)      → applique sur tout le modèle

local LegoRenderer = {}

local Workspace = game:GetService("Workspace")

-- ── Constantes LEGO ───────────────────────────────────────────────────────────
local STUD_H     = 0.2   -- hauteur d'un stud
local STUD_D     = 0.6   -- diamètre d'un stud
local BULK_BATCH = 2000  -- taille max d'un lot BulkMoveTo

-- ── Espacement automatique (évite les floods de studs sur de grandes surfaces) ─
local function autoSpacing(area: number, maxStuds: number): number
    return math.max(1, math.ceil(math.sqrt(area / maxStuds)))
end

-- ── Color jittering ───────────────────────────────────────────────────────────
-- Calculé UNE SEULE FOIS à la création du stud, zéro coût au runtime.
-- 10 % plus sombres, 10 % plus clairs, 80 % micro-jitter ±8/255.
local RNG_J = Random.new()
local function jitterColor(base: Color3): Color3
    local roll = RNG_J:NextNumber()
    local br   = if roll < 0.10 then 0.84 elseif roll < 0.20 then 1.14 else 1.0
    local j    = 8 / 255
    return Color3.new(
        math.clamp(base.R * br + RNG_J:NextNumber() * (j * 2) - j, 0, 1),
        math.clamp(base.G * br + RNG_J:NextNumber() * (j * 2) - j, 0, 1),
        math.clamp(base.B * br + RNG_J:NextNumber() * (j * 2) - j, 0, 1)
    )
end

-- ── Fabrication d'un stud (sans position — BulkMoveTo le positionne) ──────────
local function makeStud(color: Color3, material: Enum.Material): Part
    local s         = Instance.new("Part") :: Part
    s.Name          = "S"
    s.Shape         = Enum.PartType.Cylinder
    s.Size          = Vector3.new(STUD_H, STUD_D, STUD_D)
    s.Anchored      = true
    s.CanCollide    = false
    s.CanTouch      = false
    s.CanQuery      = false
    s.Massless      = true
    s.CastShadow    = true   -- micro-ombres portées → rendu LEGO réaliste
    s.Color         = jitterColor(color)
    s.Material      = material
    s.Reflectance   = 0.08
    s.TopSurface    = Enum.SurfaceType.Smooth
    s.BottomSurface = Enum.SurfaceType.Smooth
    return s
end

-- ── BulkMoveTo : parent + déplace en un seul appel ───────────────────────────
local function flush(folder: Folder, parts: {BasePart}, cframes: {CFrame})
    if #parts == 0 then return end
    for _, p in ipairs(parts) do p.Parent = folder end
    Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
    task.wait()
end

-- ── Données de face basées sur le CFrame réel de la Part ─────────────────────
-- Retourne : normal, tangent1, tangent2, faceW, faceH
--   • normal    : vecteur sortant perpendiculaire à la face
--   • tangent1  : direction "largeur" sur la face
--   • tangent2  : direction "hauteur" sur la face
--   • faceW/H   : dimensions de la face en studs
-- Fonctionne quelle que soit la rotation de la Part.
local function getFaceData(cf: CFrame, sz: Vector3, face: string)
    local n: Vector3   -- normal sortant
    local t1: Vector3  -- tangent1 (largeur)
    local t2: Vector3  -- tangent2 (hauteur)
    local w: number
    local h: number

    if face == "Top" then
        n, t1, t2 = cf.UpVector, cf.RightVector, -cf.LookVector
        w, h = sz.X, sz.Z
    elseif face == "Bottom" then
        n, t1, t2 = -cf.UpVector, cf.RightVector, cf.LookVector
        w, h = sz.X, sz.Z
    elseif face == "Front" then
        n, t1, t2 = -cf.LookVector, cf.RightVector, cf.UpVector
        w, h = sz.X, sz.Y
    elseif face == "Back" then
        n, t1, t2 = cf.LookVector, -cf.RightVector, cf.UpVector
        w, h = sz.X, sz.Y
    elseif face == "Right" then
        n, t1, t2 = cf.RightVector, -cf.LookVector, cf.UpVector
        w, h = sz.Z, sz.Y
    else  -- "Left"
        n, t1, t2 = -cf.RightVector, cf.LookVector, cf.UpVector
        w, h = sz.Z, sz.Y
    end

    return n, t1, t2, w, h
end

-- ══════════════════════════════════════════════════════════════════════════════
-- AutoStud(part, opts?) — CŒUR DU MODULE
-- Couvre la face indiquée de la Part de studs 3D, en tenant compte
-- de sa rotation/inclinaison réelle via son CFrame.
-- ══════════════════════════════════════════════════════════════════════════════
type Opts = {
    spacing  : number?,
    color    : Color3?,
    material : Enum.Material?,
    face     : string?,   -- "Top"|"Bottom"|"Front"|"Back"|"Left"|"Right"
    maxStuds : number?,
}

function LegoRenderer.AutoStud(part: BasePart, opts: Opts?): Folder
    local o        = opts or {}
    local color    = o.color    or part.Color
    local material = o.material or part.Material
    local face     = o.face     or "Top"
    local maxStuds = o.maxStuds or 4000

    local cf = part.CFrame
    local sz = part.Size

    -- Données de face (normale + tangentes + dimensions) via CFrame réel
    local normal, t1, t2, faceW, faceH = getFaceData(cf, sz, face)

    local sp = o.spacing or autoSpacing(faceW * faceH, maxStuds)

    -- ── Marge de sécurité (padding) ──────────────────────────────────────────
    -- On réduit la zone de génération d'un RAYON de stud (STUD_D/2 = 0.3) de
    -- chaque côté → les studs ne débordent plus au-delà des bords de la plaque
    -- et restent strictement confinés à l'intérieur des bordures.
    local PAD  = STUD_D          -- = 0.6 (diamètre complet = 0.3 de chaque côté)
    local effW = math.max(sp, faceW - PAD)
    local effH = math.max(sp, faceH - PAD)
    local nx   = math.max(1, math.floor(effW / sp))
    local nz   = math.max(1, math.floor(effH / sp))

    -- Centre de la face + décalage STUD_H/2 pour que la base du stud soit sur la face
    local halfExtent = if face == "Top" or face == "Bottom" then sz.Y / 2
                       elseif face == "Front" or face == "Back" then sz.Z / 2
                       else sz.X / 2
    local faceCenter = cf.Position + normal * (halfExtent + STUD_H / 2)

    -- CFrame d'orientation du stud : axe X du cylindre = normale sortante
    -- CFrame.fromMatrix(pos, rightVec, upVec) :
    --   local X → rightVec = normal  (axe du cylindre = perpendiculaire à la face)
    --   local Y → upVec    = t1
    local studOrientation = CFrame.fromMatrix(Vector3.zero, normal, t1)

    -- Folder streaming-friendly (même parent que la Part)
    local folder   = Instance.new("Folder")
    folder.Name    = "LegoStuds_" .. part.Name
    folder.Parent  = part.Parent

    local parts  : {BasePart} = {}
    local cframes: {CFrame}   = {}

    -- Coin bas-gauche de la grille centrée sur la zone effective (padded)
    local startT1 = -(effW / 2) + sp * 0.5
    local startT2 = -(effH / 2) + sp * 0.5

    for ix = 0, nx - 1 do
        for iz = 0, nz - 1 do
            -- Position du stud = centre face + offset selon tangentes
            local offset = t1 * (startT1 + ix * sp) + t2 * (startT2 + iz * sp)
            local studPos = faceCenter + offset

            table.insert(parts,   makeStud(color, material))
            table.insert(cframes, CFrame.new(studPos) * studOrientation)

            if #parts >= BULK_BATCH then
                flush(folder, parts, cframes)
                table.clear(parts)
                table.clear(cframes)
            end
        end
    end
    flush(folder, parts, cframes)

    print(string.format("[LegoRenderer] '%s' face=%s sp=%d → %d studs",
        part.Name, face, sp, nx * nz))
    return folder
end

-- ══════════════════════════════════════════════════════════════════════════════
-- AddBorders(part, opts?) — Cadre en 4 lisses LEGO sur la face supérieure
--
-- Génère 4 Parts rectangulaires SmoothPlastic collées sur les arêtes de la
-- face Top de la Part. Fonctionne quelle que soit la rotation (CFrame réel).
--
-- Géométrie (coins sans chevauchement) :
--   Nord/Sud → pleine largeur (sz.X)          profondeur = thickness
--   Est/Ouest → profondeur intérieure (sz.Z - thickness×2)  largeur = thickness
--
-- Hauteur des lisses = STUD_H (0.2) → flush avec le sommet des studs.
-- ══════════════════════════════════════════════════════════════════════════════
type BorderOpts = {
    thickness : number?,  -- largeur du cadre en studs  (défaut 1.2)
    color     : Color3?,  -- couleur des lisses         (défaut gris anthracite)
}

function LegoRenderer.AddBorders(part: BasePart, opts: BorderOpts?): Folder
    local o   = opts or {}
    local t   = o.thickness or 1.2
    local col = o.color or Color3.fromRGB(39, 70, 45)   -- vert foncé LEGO (Dark Green)

    local BH = STUD_H   -- hauteur des lisses = hauteur d'un stud (0.2)
    local cf = part.CFrame
    local sz = part.Size

    -- ── Offset local Y : positionne le centre de la lisse sur la face supérieure
    -- La face top est à sz.Y/2 en local Y ; on monte de BH/2 pour que la base
    -- de la lisse soit sur la surface de la Part, + 0.05 de micro-décalage
    -- pour éviter le Z-fighting (coplanarité avec la plaque sous-jacente).
    local localY = sz.Y / 2 + BH / 2 + 0.05  -- +0.05 anti Z-fighting
    local ht     = t / 2  -- demi-épaisseur

    -- ── Définitions des 4 lisses (offsets en coordonnées LOCALES de la Part)
    -- Rappel Roblox : local +X = RightVector, +Y = UpVector, -Z = LookVector (avant)
    local defs: {{off: Vector3, size: Vector3, name: string}} = {
        -- Nord (+LookVector) — pleine largeur, pas de recoupement aux coins
        { off  = Vector3.new( 0,                  localY, -(sz.Z / 2 - ht) ),
          size = Vector3.new( sz.X,               BH,      t               ),
          name = "Border_N" },

        -- Sud (-LookVector) — pleine largeur
        { off  = Vector3.new( 0,                  localY,  (sz.Z / 2 - ht) ),
          size = Vector3.new( sz.X,               BH,      t               ),
          name = "Border_S" },

        -- Est (+RightVector) — profondeur intérieure (évite les coins doubles)
        { off  = Vector3.new( (sz.X / 2 - ht),   localY,  0               ),
          size = Vector3.new( t,                  BH,      sz.Z - t * 2    ),
          name = "Border_E" },

        -- Ouest (-RightVector) — profondeur intérieure
        { off  = Vector3.new(-(sz.X / 2 - ht),   localY,  0               ),
          size = Vector3.new( t,                  BH,      sz.Z - t * 2    ),
          name = "Border_W" },
    }

    local folder   = Instance.new("Folder")
    folder.Name    = "LegoFrame_" .. part.Name
    folder.Parent  = part.Parent

    for _, def in ipairs(defs) do
        local b             = Instance.new("Part") :: Part
        b.Name              = def.name
        b.Size              = def.size
        -- cf * CFrame.new(localOffset) → applique l'offset dans le repère LOCAL
        -- de la Part, donc la rotation de la Part est automatiquement héritée.
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
-- ProcessStructure(model, opts?) — applique AutoStud sur toutes les Parts
-- du modèle en tâche de fond, avec détection automatique de la face selon le nom.
--
-- Règles de détection (insensible à la casse) :
--   "Wall"                   → face "Front"  (studs sur le côté visible)
--   "Roof" / "Ceiling"       → face "Top"
--   "Floor" / "Road" / "Avenue" / "Trunk" / autre → face "Top"
--
-- Parts ignorées : Transparency > 0.5, taille < 0.5 sur n'importe quel axe.
-- ══════════════════════════════════════════════════════════════════════════════
function LegoRenderer.ProcessStructure(model: Instance, opts: Opts?)
    for _, desc in ipairs(model:GetDescendants()) do
        if not desc:IsA("BasePart") then continue end

        local part = desc :: BasePart
        local sz   = part.Size

        -- Ignore les Parts quasi-invisibles ou trop petites pour avoir des studs
        if part.Transparency > 0.5 then continue end
        if sz.X < 0.5 or sz.Y < 0.5 or sz.Z < 0.5 then continue end

        local nm = string.upper(part.Name)
        local o  = opts and table.clone(opts) or {}

        -- Détection de la face
        if not o.face then
            if string.find(nm, "WALL") then
                o.face = "Front"
            else
                o.face = "Top"
            end
        end

        -- Plafond de studs adapté à la surface (grandes Parts = moins dense)
        if not o.maxStuds then
            local faceArea = if o.face == "Front" or o.face == "Back" then sz.X * sz.Y
                             elseif o.face == "Left" or o.face == "Right" then sz.Z * sz.Y
                             else sz.X * sz.Z
            o.maxStuds = if faceArea > 200 then 1500 else 4000
        end

        -- Lire la couleur ET le matériau de CETTE Part (pas une valeur globale forcée)
        if not o.color then
            o.color = part.Color
        end
        if not o.material then
            o.material = part.Material
        end

        task.spawn(function()
            LegoRenderer.AutoStud(part, o)
        end)
    end
end

return LegoRenderer

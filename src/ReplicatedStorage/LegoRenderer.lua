--!strict
-- LegoRenderer.lua  (ModuleScript — ReplicatedStorage)
-- Pavage EXCLUSIF via le MeshPart "Carpet" (ReplicatedStorage.Blocks.Carpet).
-- Aucun fallback procédural : si Carpet est absent, on ne génère rien.

local LegoRenderer = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ── Constantes ────────────────────────────────────────────────────────────────
local BORDER_H    = 0.2
local YIELD_EVERY = 500
local SURFACE_OFFSET = 0.02  -- Évite le Z-fighting en décalant légèrement les tuiles

-- ── Seuil X du biome Défis ────────────────────────────────────────────────────
local CHALLENGE_ZONE_X = 56.0

-- ── Biome Avenue ──────────────────────────────────────────────────────────────
local AVENUE_Z_MIN = 78.0
local AVENUE_Z_MAX = 142.0

-- ── Palettes de couleurs ───────────────────────────────────────────────────────
local COL_GRASS  = Color3.fromRGB( 75, 151,  75)
local COL_ROAD   = Color3.fromRGB(130, 130, 130)
local COL_CHALL  = Color3.fromRGB(255, 235,   0)

-- ── Cache du MeshPart Carpet ───────────────────────────────────────────────────
local _carpet: BasePart? = nil

local function getCarpet(): BasePart?
    if _carpet then return _carpet end
    local blocks = ReplicatedStorage:FindFirstChild("Blocks")
    if blocks then
        local t = blocks:FindFirstChild("Carpet")
        if t and t:IsA("BasePart") then
            _carpet = t :: BasePart
            return _carpet
        end
    end
    local direct = ReplicatedStorage:FindFirstChild("Carpet")
    if direct and direct:IsA("BasePart") then
        _carpet = direct :: BasePart
        return _carpet
    end
    local t = ReplicatedStorage:WaitForChild("Carpet", 5)
    if t and t:IsA("BasePart") then
        _carpet = t :: BasePart
        return _carpet
    end
    return nil
end

local function getBiome(worldX: number, worldZ: number): (Color3, boolean)
    if worldX >= CHALLENGE_ZONE_X and worldZ >= -115 and worldZ <= 78 then
        return COL_CHALL, false
    end
    if worldZ >= AVENUE_Z_MIN and worldZ <= AVENUE_Z_MAX then
        return COL_ROAD, true
    end
    return COL_GRASS, false
end

local function applyColor(clone: BasePart, tint: Color3)
    clone.Color = tint
    for _, child in ipairs(clone:GetChildren()) do
        if child:IsA("Texture") then
            (child :: Texture).Color3 = tint
        end
    end
end

local function applyPhysics(bp: BasePart, canCollide: boolean?)
    bp.Anchored     = true
    bp.CanCollide   = if canCollide ~= nil then canCollide else false
    bp.CanTouch     = false
    bp.CanQuery     = false
    bp.Massless     = true
    bp.CastShadow   = false
end

local function purge(parent: Instance, name: string)
    local old = parent:FindFirstChild(name)
    if old then old:Destroy() end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- GenerateFloor
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
    local bX, bY, bZ = carpet.Size.X, carpet.Size.Y, carpet.Size.Z
    local tileY = (surfY or 0) - bY / 2 + SURFACE_OFFSET

    purge(parent, "LegoFloor")
    local folder = Instance.new("Folder")
    folder.Name   = "LegoFloor"
    folder.Parent = parent

    local nX    = math.ceil((xMax - xMin) / bX)
    local nZ    = math.ceil((zMax - zMin) / bZ)
    local count = 0
    local ROAD_ROT = CFrame.Angles(0, math.rad(90), 0)

    for ix = 0, nX - 1 do
        for iz = 0, nZ - 1 do
            local wx = xMin + (ix + 0.5) * bX
            local wz = zMin + (iz + 0.5) * bZ
            local tint, isRoad = getBiome(wx, wz)
            local baseCF = CFrame.new(wx, tileY, wz)

            local clone = (carpet :: BasePart):Clone() :: BasePart
            applyPhysics(clone, true) -- Collision sur le sol principal
            applyColor(clone, tint)
            clone.CFrame = if isRoad then baseCF * ROAD_ROT else baseCF
            clone.Parent = folder

            count += 1
            if count % YIELD_EVERY == 0 then task.wait() end
        end
    end
    return folder
end

-- ══════════════════════════════════════════════════════════════════════════════
-- AutoStud
-- ══════════════════════════════════════════════════════════════════════════════
type Opts = {
    face         : string?,
    usePartColor : boolean?,
    canCollide   : boolean?,
    castShadow   : boolean?,
    skipCheck    : ((pos: Vector3) -> boolean)?, -- Fonction optionnelle pour ignorer des zones
}

function LegoRenderer.AutoStud(part: BasePart, opts: Opts?): Folder?
    local carpet = getCarpet()
    if not carpet then return nil end
    local o    = opts or {}
    local face = o.face or "Top"
    local shadow = if o.castShadow ~= nil then o.castShadow else false -- Par défaut OFF pour les tuiles

    local folderName = "LegoTiles_" .. part.Name
    purge(part, folderName)

    local folder  = Instance.new("Folder")
    folder.Name    = folderName
    folder.Parent  = part

    local bX, bY, bZ = carpet.Size.X, carpet.Size.Y, carpet.Size.Z
    local cf, sz     = part.CFrame, part.Size

    local surfW, surfL = 0, 0
    local offX, offY, offZ = 0, 0, 0

    local multiplier = 1
    if face == "Top" then
        surfW, surfL = sz.X, sz.Z
        offY =  sz.Y / 2 - bY / 2 + SURFACE_OFFSET
    elseif face == "Bottom" then
        surfW, surfL = sz.X, sz.Z
        offY = -(sz.Y / 2 - bY / 2 + SURFACE_OFFSET)
    elseif face == "Front" then
        surfW, surfL = sz.X, sz.Y
        offZ = -(sz.Z / 2 - bZ / 2 + SURFACE_OFFSET)
    elseif face == "Back" then
        surfW, surfL = sz.X, sz.Y
        offZ =  sz.Z / 2 - bZ / 2 + SURFACE_OFFSET
    elseif face == "Right" then
        surfW, surfL = sz.Z, sz.Y
        offX =  sz.X / 2 - bX / 2 + SURFACE_OFFSET
    else  -- "Left"
        surfW, surfL = sz.Z, sz.Y
        offX = -(sz.X / 2 - bX / 2 + SURFACE_OFFSET)
    end

    -- Pour les petites pièces (socles), si on dépasse trop, on réduit le nombre de tuiles
    local nX = math.ceil(surfW / bX)
    local nZ = math.ceil(surfL / bZ)
    
    -- Si la part est petite (< 10 studs) et que math.ceil dépasse de plus de 15%, on passe en floor
    if surfW < 10 and (nX * bX) > surfW * 1.15 then nX = math.max(1, math.floor(surfW / bX)) end
    if surfL < 10 and (nZ * bZ) > surfL * 1.15 then nZ = math.max(1, math.floor(surfL / bZ)) end

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

            -- Vérification skipZone
            if o.skipCheck and o.skipCheck(brickCF.Position) then continue end

            local tint: Color3
            local isRoad: boolean = false
            if o.usePartColor then
                tint = part.Color
            else
                tint, isRoad = getBiome(brickCF.Position.X, brickCF.Position.Z)
            end

            local clone = (carpet :: BasePart):Clone() :: BasePart
            applyPhysics(clone, o.canCollide)
            applyColor(clone, tint)
            clone.CastShadow = shadow
            
            -- Scaling de sécurité pour les petites parts (socles) pour éviter que le Lego dépasse du socle
            local finalSize = clone.Size
            if nX == 1 and surfW < bX then
                finalSize = Vector3.new(surfW, finalSize.Y, finalSize.Z)
            end
            if nZ == 1 and surfL < bZ then
                finalSize = Vector3.new(finalSize.X, finalSize.Y, surfL)
            end
            if finalSize ~= clone.Size then
                clone.Size = finalSize
            end

            clone.CFrame = if isRoad
                then brickCF * CFrame.Angles(0, math.rad(90), 0)
                else brickCF
            clone.Parent = folder

            count += 1
            if count % YIELD_EVERY == 0 then task.wait() end
        end
    end
    return folder
end

function LegoRenderer.Decorate(part: BasePart, face: string?, opts: Opts?)
    task.spawn(function()
        local o = opts or {}
        LegoRenderer.AutoStud(part, {
            face         = face or "Top",
            usePartColor = true,
            canCollide   = if o.canCollide ~= nil then o.canCollide else true, -- Par défaut collision ON pour déco
            skipCheck    = o.skipCheck
        })
    end)
end

function LegoRenderer.ProcessStructure(model: Instance, opts: Opts?)
    for _, desc in ipairs(model:GetDescendants()) do
        if not desc:IsA("BasePart") then continue end
        local part = desc :: BasePart
        if part.Transparency > 0.5 then continue end
        if part.Size.X < 2 or part.Size.Z < 2 then continue end
        
        local nm = string.upper(part.Name)
        local f: string = "Top"
        if string.find(nm, "CEILING") or string.find(nm, "ROOF") then
            f = "Bottom"
        elseif string.find(nm, "WALL") then
            f = "Front"
        end

        LegoRenderer.Decorate(part, f, opts)
    end
end

function LegoRenderer.GenerateChallengeFloor(parent: Instance, xMin: number, xMax: number, zMin: number, zMax: number, surfY: number?): Folder?
    local carpet = getCarpet()
    if not carpet then return nil end
    local bX, bY, bZ = carpet.Size.X, carpet.Size.Y, carpet.Size.Z
    local tileY = (surfY or 0) - bY / 2 + SURFACE_OFFSET

    purge(parent, "ChallengeTiles")
    local folder = Instance.new("Folder")
    folder.Name   = "ChallengeTiles"
    folder.Parent = parent

    local nX = math.ceil((xMax - xMin) / bX)
    local nZ = math.ceil((zMax - zMin) / bZ)
    local count = 0

    for ix = 0, nX - 1 do
        for iz = 0, nZ - 1 do
            local wx = xMin + (ix + 0.5) * bX
            local wz = zMin + (iz + 0.5) * bZ
            local clone = (carpet :: BasePart):Clone() :: BasePart
            applyPhysics(clone, true)
            applyColor(clone, COL_CHALL)
            clone.CFrame = CFrame.new(wx, tileY, wz)
            clone.Parent = folder
            count += 1
            if count % YIELD_EVERY == 0 then task.wait() end
        end
    end
    return folder
end

function LegoRenderer.AddBorders(part: BasePart, opts: {thickness: number?, color: Color3?}?): Folder
    local o   = opts or {}
    local t   = o.thickness or 0.05
    local col = o.color or Color3.fromRGB(39, 70, 45)
    local cf, sz = part.CFrame, part.Size
    local ht = t / 2
    local localY = sz.Y / 2 + BORDER_H / 2 + 0.05
    local defs = {
        { off = Vector3.new(0, localY, -(sz.Z/2-ht)), size = Vector3.new(sz.X, BORDER_H, t), name = "Border_N" },
        { off = Vector3.new(0, localY, (sz.Z/2-ht)),  size = Vector3.new(sz.X, BORDER_H, t), name = "Border_S" },
        { off = Vector3.new((sz.X/2-ht), localY, 0),  size = Vector3.new(t, BORDER_H, sz.Z-t*2), name = "Border_E" },
        { off = Vector3.new(-(sz.X/2-ht), localY, 0), size = Vector3.new(t, BORDER_H, sz.Z-t*2), name = "Border_W" },
    }
    local folder = Instance.new("Folder")
    folder.Name = "LegoFrame_" .. part.Name
    folder.Parent = part.Parent
    for _, def in ipairs(defs) do
        local b = Instance.new("Part")
        b.Name, b.Size, b.CFrame, b.Anchored, b.CanCollide, b.Color = def.name, def.size, cf * CFrame.new(def.off), true, false, col
        b.Material, b.CastShadow, b.Parent = Enum.Material.SmoothPlastic, false, folder
    end
    return folder
end

return LegoRenderer

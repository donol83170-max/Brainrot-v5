--!strict
-- LevelGenerator.server.lua
-- Génère le décor du monde : montagnes, bâtiments, arbres et lampadaires
-- Placé dans ServerScriptService, synchronisé par Rojo

local Workspace = game:GetService("Workspace")

-- ══════════════════════════════════════════════════════════════════════════════
-- DOSSIERS
-- ══════════════════════════════════════════════════════════════════════════════
-- Réutilise le dossier Map existant (créé par BrainrotGallery) ou le crée
local mapFolder = Workspace:FindFirstChild("Map")
if not mapFolder then
    mapFolder = Instance.new("Folder")
    mapFolder.Name   = "Map"
    mapFolder.Parent = Workspace
end

local envFolder = Instance.new("Folder")
envFolder.Name = "Environment"
envFolder.Parent = mapFolder

local mountainsFolder = Instance.new("Folder")
mountainsFolder.Name = "Mountains"
mountainsFolder.Parent = envFolder

local buildingsFolder = Instance.new("Folder")
buildingsFolder.Name = "Buildings"
buildingsFolder.Parent = envFolder

local treesFolder = Instance.new("Folder")
treesFolder.Name = "Trees"
treesFolder.Parent = envFolder

local lightsFolder = Instance.new("Folder")
lightsFolder.Name = "Lights"
lightsFolder.Parent = envFolder

-- ══════════════════════════════════════════════════════════════════════════════
-- UTILITAIRES
-- ══════════════════════════════════════════════════════════════════════════════
local RNG = Random.new(42) -- Seed fixe pour des résultats reproductibles

local function pick(tbl)
	return tbl[RNG:NextInteger(1, #tbl)]
end

local function randRange(min: number, max: number): number
	return RNG:NextNumber() * (max - min) + min
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 1. MONTAGNES
-- ══════════════════════════════════════════════════════════════════════════════
local MOUNTAIN_COLORS = {
	Color3.fromRGB(120, 110, 100), -- Gris rocheux
	Color3.fromRGB(90, 85, 75),    -- Gris foncé
	Color3.fromRGB(140, 130, 115), -- Beige roche
	Color3.fromRGB(100, 95, 80),   -- Brun ardoise
}

local MOUNTAIN_MATERIALS = { Enum.Material.Rock, Enum.Material.Slate, Enum.Material.Basalt }

local MOUNTAINS = {
	{ pos = Vector3.new(-200, 30, -180), size = Vector3.new(120, 80, 100) },
	{ pos = Vector3.new(-80, 45, -200),  size = Vector3.new(100, 110, 90) },
	{ pos = Vector3.new(60, 35, -190),   size = Vector3.new(110, 90, 95) },
	{ pos = Vector3.new(200, 50, -170),  size = Vector3.new(130, 120, 110) },
	{ pos = Vector3.new(-250, 25, -100), size = Vector3.new(90, 60, 80) },
	{ pos = Vector3.new(260, 30, -120),  size = Vector3.new(100, 70, 85) },
}

for i, data in ipairs(MOUNTAINS) do
	local mountain = Instance.new("Part")
	mountain.Name      = "Mountain_" .. i
	mountain.Size      = data.size
	mountain.Position  = data.pos
	mountain.Anchored  = true
	mountain.CanCollide = true
	mountain.Color     = pick(MOUNTAIN_COLORS)
	mountain.Material  = pick(MOUNTAIN_MATERIALS)
	mountain.TopSurface = Enum.SurfaceType.Smooth
	mountain.BottomSurface = Enum.SurfaceType.Smooth
	mountain.Parent    = mountainsFolder
end

-- Pics secondaires (plus petits, autour des gros)
for i = 1, 8 do
	local baseMount = MOUNTAINS[RNG:NextInteger(1, #MOUNTAINS)]
	local offset = Vector3.new(randRange(-40, 40), randRange(-10, 5), randRange(-30, 30))
	local peak = Instance.new("Part")
	peak.Name      = "Peak_" .. i
	peak.Size      = Vector3.new(randRange(30, 60), randRange(20, 50), randRange(25, 50))
	peak.Position  = baseMount.pos + offset
	peak.Anchored  = true
	peak.CanCollide = true
	peak.Color     = pick(MOUNTAIN_COLORS)
	peak.Material  = pick(MOUNTAIN_MATERIALS)
	peak.TopSurface = Enum.SurfaceType.Smooth
	peak.BottomSurface = Enum.SurfaceType.Smooth
	peak.Parent    = mountainsFolder
end

print("🏔️ [LevelGenerator] Montagnes générées")

-- ══════════════════════════════════════════════════════════════════════════════
-- 2. BÂTIMENTS
-- ══════════════════════════════════════════════════════════════════════════════
local WALL_COLORS = {
	Color3.fromRGB(200, 180, 160), -- Beige
	Color3.fromRGB(180, 170, 155), -- Taupe
	Color3.fromRGB(220, 210, 195), -- Crème
	Color3.fromRGB(160, 150, 140), -- Gris chaud
	Color3.fromRGB(190, 175, 155), -- Sable
	Color3.fromRGB(170, 160, 150), -- Pierre
}

local ROOF_COLORS = {
	Color3.fromRGB(140, 50, 40),   -- Rouge tuile
	Color3.fromRGB(80, 60, 45),    -- Brun foncé
	Color3.fromRGB(100, 100, 100), -- Gris ardoise
	Color3.fromRGB(120, 45, 35),   -- Terre cuite
}

local WINDOW_COLOR = Color3.fromRGB(255, 220, 100) -- Jaune chaud (lumière)

type BuildingConfig = {
	x: number,
	z: number,
	floors: number,
	width: number,
	depth: number,
}

local BUILDING_CONFIGS: {BuildingConfig} = {
	-- Côté gauche (X < -100)
	{ x = -160, z = -40, floors = 2, width = 20, depth = 16 },
	{ x = -140, z = 30,  floors = 3, width = 18, depth = 14 },
	{ x = -180, z = 60,  floors = 1, width = 24, depth = 20 },
	{ x = -130, z = -80, floors = 2, width = 16, depth = 16 },
	-- Côté droit (X > 100)
	{ x = 150,  z = -30, floors = 3, width = 20, depth = 18 },
	{ x = 170,  z = 40,  floors = 2, width = 22, depth = 16 },
	{ x = 130,  z = 70,  floors = 1, width = 18, depth = 18 },
	{ x = 190,  z = -70, floors = 2, width = 16, depth = 14 },
}

local FLOOR_HEIGHT = 12

local function createBuilding(config: BuildingConfig, index: number)
	local buildingFolder = Instance.new("Folder")
	buildingFolder.Name = "Building_" .. index
	buildingFolder.Parent = buildingsFolder

	local wallColor = pick(WALL_COLORS)
	local roofColor = pick(ROOF_COLORS)
	local totalH = config.floors * FLOOR_HEIGHT

	-- Murs (un seul Part pour la performance)
	local walls = Instance.new("Part")
	walls.Name      = "Walls"
	walls.Size      = Vector3.new(config.width, totalH, config.depth)
	walls.Position  = Vector3.new(config.x, totalH / 2, config.z)
	walls.Anchored  = true
	walls.Color     = wallColor
	walls.Material  = Enum.Material.SmoothPlastic
	walls.TopSurface = Enum.SurfaceType.Smooth
	walls.BottomSurface = Enum.SurfaceType.Smooth
	walls.Parent    = buildingFolder

	-- Toit en pente (WedgePart)
	local roof = Instance.new("WedgePart")
	roof.Name      = "Roof"
	roof.Size      = Vector3.new(config.width + 2, 6, config.depth + 2)
	roof.CFrame    = CFrame.new(config.x, totalH + 3, config.z)
	roof.Anchored  = true
	roof.Color     = roofColor
	roof.Material  = Enum.Material.SmoothPlastic
	roof.TopSurface = Enum.SurfaceType.Smooth
	roof.BottomSurface = Enum.SurfaceType.Smooth
	roof.Parent    = buildingFolder

	-- Fenêtres (2 par étage, face avant et arrière)
	for floor = 1, config.floors do
		local floorY = (floor - 0.5) * FLOOR_HEIGHT
		for _, side in ipairs({-1, 1}) do
			local win = Instance.new("Part")
			win.Name      = "Window"
			win.Size      = Vector3.new(4, 4, 0.5)
			win.Position  = Vector3.new(config.x, floorY, config.z + side * (config.depth / 2 + 0.3))
			win.Anchored  = true
			win.CanCollide = false
			win.Color     = WINDOW_COLOR
			win.Material  = Enum.Material.Neon
			win.Transparency = 0.3
			win.Parent    = buildingFolder
		end
	end

	-- Porte (rez-de-chaussée, face avant)
	local door = Instance.new("Part")
	door.Name      = "Door"
	door.Size      = Vector3.new(5, 8, 0.5)
	door.Position  = Vector3.new(config.x, 4, config.z + config.depth / 2 + 0.3)
	door.Anchored  = true
	door.CanCollide = false
	door.Color     = Color3.fromRGB(80, 50, 30)
	door.Material  = Enum.Material.Wood
	door.Parent    = buildingFolder
end

for i, config in ipairs(BUILDING_CONFIGS) do
	createBuilding(config, i)
end

print("🏠 [LevelGenerator] Bâtiments générés")

-- ══════════════════════════════════════════════════════════════════════════════
-- 3. ARBRES
-- ══════════════════════════════════════════════════════════════════════════════
local TRUNK_COLOR  = Color3.fromRGB(101, 67, 33)
local LEAF_COLORS  = {
	Color3.fromRGB(60, 130, 50),   -- Vert foncé
	Color3.fromRGB(80, 150, 60),   -- Vert moyen
	Color3.fromRGB(50, 110, 40),   -- Vert forêt
	Color3.fromRGB(90, 160, 70),   -- Vert clair
}

local function createTree(x: number, z: number, index: number)
	local treeFolder = Instance.new("Model")
	treeFolder.Name = "Tree_" .. index

	local trunkH = randRange(8, 14)
	local leafSize = randRange(8, 14)

	-- Tronc
	local trunk = Instance.new("Part")
	trunk.Name      = "Trunk"
	trunk.Shape     = Enum.PartType.Cylinder
	trunk.Size      = Vector3.new(trunkH, 2.5, 2.5)
	trunk.CFrame    = CFrame.new(x, trunkH / 2, z) * CFrame.Angles(0, 0, math.rad(90))
	trunk.Anchored  = true
	trunk.CanCollide = false
	trunk.Color     = TRUNK_COLOR
	trunk.Material  = Enum.Material.Wood
	trunk.Parent    = treeFolder

	-- Feuillage
	local leaves = Instance.new("Part")
	leaves.Name      = "Leaves"
	leaves.Shape     = Enum.PartType.Ball
	leaves.Size      = Vector3.new(leafSize, leafSize, leafSize)
	leaves.Position  = Vector3.new(x, trunkH + leafSize / 3, z)
	leaves.Anchored  = true
	leaves.CanCollide = false
	leaves.Color     = pick(LEAF_COLORS)
	leaves.Material  = Enum.Material.Grass
	leaves.Parent    = treeFolder

	treeFolder.Parent = treesFolder
end

-- Placement aléatoire des arbres (évite la zone des roues au centre)
local treeIndex = 0
for _ = 1, 20 do
	local tx = randRange(-280, 280)
	local tz = randRange(-150, 180)

	-- Éviter la zone centrale des roues (-90 < x < 90, -30 < z < 30)
	if math.abs(tx) > 90 or math.abs(tz) > 30 then
		treeIndex += 1
		createTree(tx, tz, treeIndex)
	end
end

print("🌲 [LevelGenerator] Arbres générés : " .. treeIndex)

-- ══════════════════════════════════════════════════════════════════════════════
-- 4. LAMPADAIRES
-- ══════════════════════════════════════════════════════════════════════════════
local POLE_COLOR  = Color3.fromRGB(60, 60, 65)
local LAMP_COLOR  = Color3.fromRGB(255, 230, 150)

local LAMPPOST_POSITIONS = {
	Vector3.new(-100, 0, 0),
	Vector3.new(-100, 0, 50),
	Vector3.new(-100, 0, -50),
	Vector3.new(100, 0, 0),
	Vector3.new(100, 0, 50),
	Vector3.new(100, 0, -50),
	Vector3.new(0, 0, -80),
}

local function createLamppost(pos: Vector3, index: number)
	local lampFolder = Instance.new("Model")
	lampFolder.Name = "Lamp_" .. index

	local poleH = 16

	-- Poteau
	local pole = Instance.new("Part")
	pole.Name      = "Pole"
	pole.Shape     = Enum.PartType.Cylinder
	pole.Size      = Vector3.new(poleH, 1, 1)
	pole.CFrame    = CFrame.new(pos.X, poleH / 2, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
	pole.Anchored  = true
	pole.CanCollide = false
	pole.Color     = POLE_COLOR
	pole.Material  = Enum.Material.Metal
	pole.Parent    = lampFolder

	-- Ampoule
	local bulb = Instance.new("Part")
	bulb.Name      = "Bulb"
	bulb.Shape     = Enum.PartType.Ball
	bulb.Size      = Vector3.new(3, 3, 3)
	bulb.Position  = Vector3.new(pos.X, poleH + 1.5, pos.Z)
	bulb.Anchored  = true
	bulb.CanCollide = false
	bulb.Color     = LAMP_COLOR
	bulb.Material  = Enum.Material.Neon
	bulb.Transparency = 0.1
	bulb.Parent    = lampFolder

	-- Lumière
	local light = Instance.new("PointLight")
	light.Color     = LAMP_COLOR
	light.Brightness = 0.75
	light.Range      = 30
	light.Shadows    = true
	light.Parent     = bulb

	lampFolder.Parent = lightsFolder
end

for i, pos in ipairs(LAMPPOST_POSITIONS) do
	createLamppost(pos, i)
end

print("💡 [LevelGenerator] Lampadaires générés")

-- ══════════════════════════════════════════════════════════════════════════════
-- 5. AMBIANCE (Lighting)
-- ══════════════════════════════════════════════════════════════════════════════
local Lighting = game:GetService("Lighting")
Lighting.ClockTime     = 14        -- Après-midi ensoleillé
Lighting.GeographicLatitude = 40
Lighting.Brightness    = 2
Lighting.OutdoorAmbient = Color3.fromRGB(128, 140, 160)
Lighting.Ambient        = Color3.fromRGB(50, 50, 60)

-- Bloom : très faible pour éviter le halo sur les néons
local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
bloom.Intensity  = 0.1   -- Quasi invisible (défaut Roblox ≈ 1.0)
bloom.Size       = 14    -- Taille réduite
bloom.Threshold  = 0.95  -- Ne touche que les surfaces vraiment saturées
bloom.Parent     = Lighting

-- Atmosphère
local atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atmo.Density   = 0.3
atmo.Offset    = 0.2
atmo.Color     = Color3.fromRGB(200, 210, 230)
atmo.Decay     = Color3.fromRGB(120, 140, 180)
atmo.Glare     = 0.2
atmo.Haze      = 1.5
atmo.Parent    = Lighting

print("✨ [LevelGenerator] Ambiance configurée")

-- ══════════════════════════════════════════════════════════════════════════════
-- 6. SOL — plaques de base (visuelles sans collision)
-- Le rendu LEGO (GreenBlock / GreyBlock) est géré côté CLIENT par StudRenderer.
-- ══════════════════════════════════════════════════════════════════════════════

local LEGO_GREEN = Color3.fromRGB(75, 151, 75)
local DIRT_BROWN = Color3.fromRGB(170, 85, 0)
local PLATE_H    = 0.8

-- ── Baseplate Roblox → cachée ─────────────────────────────────────────────────
local existingBase = Workspace:FindFirstChild("Baseplate")
if existingBase and existingBase:IsA("BasePart") then
    (existingBase :: BasePart).Transparency = 1
    (existingBase :: BasePart).CanCollide   = false
end

-- ── Sol de collision global (invisible) ──────────────────────────────────────
-- PLATE_H = 0.8 → grass center Y = 0.5, grass top Y = 0.9
-- CollisionFloor top doit coïncider avec la top surface de l'herbe → center Y = 0.4
local GRASS_TOP_Y = 0.1 + PLATE_H  -- = 0.9  (0.1 offset + plaque complète)

local collisionFloor = Instance.new("Part")
collisionFloor.Name         = "CollisionFloor"
collisionFloor.Size         = Vector3.new(700, 1, 700)
collisionFloor.CFrame       = CFrame.new(0, GRASS_TOP_Y - 0.5, 0)  -- top exactement à GRASS_TOP_Y
collisionFloor.Anchored     = true
collisionFloor.CanCollide   = true
collisionFloor.Locked       = true
collisionFloor.Transparency = 1
collisionFloor.CastShadow   = false
collisionFloor.Parent       = envFolder

-- ── SpawnLocation positionné sur la surface visible ──────────────────────────
local spawnLoc = Instance.new("SpawnLocation")
spawnLoc.Name         = "SpawnLocation"
spawnLoc.Size         = Vector3.new(6, 1, 6)
-- Base du SpawnLocation = face supérieure du CollisionFloor
spawnLoc.CFrame       = CFrame.new(0, GRASS_TOP_Y + 0.5, 0)
spawnLoc.Anchored     = true
spawnLoc.CanCollide   = true
spawnLoc.Neutral      = true     -- tous les joueurs peuvent spawner ici
spawnLoc.Duration     = 0
spawnLoc.Transparency = 1        -- invisible : la texture verte sert de repère visuel
spawnLoc.Parent       = envFolder

-- ── Dalles de base (visuelles, sans collision) ────────────────────────────────
-- Grille 7×7 de plaques 32×32 — LegoRenderer ajoute les studs en tâche de fond
task.spawn(function()
    local TILE  = 32
    local RANGE = 12   -- ±12 → couvre toute la map

    local legoRoot = Instance.new("Folder")
    legoRoot.Name  = "LegoGround_3D"
    legoRoot.Parent= envFolder

    for tx = -RANGE, RANGE do
        local colFolder = Instance.new("Folder")
        colFolder.Name  = "Col_" .. tx
        colFolder.Parent= legoRoot

        for tz = -RANGE, RANGE do
            local cx = tx * TILE + TILE / 2
            local cz = tz * TILE + TILE / 2
            local plateY = 0.1 + PLATE_H / 2  -- top à Y ≈ 0.5

            -- Bordure terre
            local dirt = Instance.new("Part")
            dirt.Name  = "Dirt_" .. tx .. "_" .. tz
            dirt.Size  = Vector3.new(TILE + 3, PLATE_H, TILE + 3)
            dirt.CFrame= CFrame.new(cx, plateY - PLATE_H, cz)
            dirt.Anchored=true ; dirt.CanCollide=false ; dirt.Locked=true
            dirt.Color = DIRT_BROWN ; dirt.Material=Enum.Material.SmoothPlastic
            dirt.TopSurface=Enum.SurfaceType.Smooth
            dirt.BottomSurface=Enum.SurfaceType.Smooth
            dirt.CastShadow=false ; dirt.Parent=colFolder

            -- Plaque verte
            local base = Instance.new("Part")
            base.Name  = "GrassBase_" .. tx .. "_" .. tz
            base.Size  = Vector3.new(TILE, PLATE_H, TILE)
            base.CFrame= CFrame.new(cx, plateY, cz)
            base.Anchored=true ; base.CanCollide=false ; base.Locked=true
            base.Color = LEGO_GREEN ; base.Material=Enum.Material.SmoothPlastic
            base.Reflectance=0.1
            base.TopSurface=Enum.SurfaceType.Smooth
            base.BottomSurface=Enum.SurfaceType.Smooth
            base.CastShadow=false ; base.Parent=colFolder
        end
        task.wait() -- 1 yield per row instead of per tile
    end

    print(string.format(
        "[LevelGenerator] Sol — %d plaques de base générées (rendu LEGO côté client)",
        (RANGE * 2 + 1) ^ 2
    ))
end)

print("🌍 [LevelGenerator] Génération du monde terminée !")


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
-- 2. BÂTIMENTS — DÉSACTIVÉ (terrain nu pour les bases des joueurs)
-- ══════════════════════════════════════════════════════════════════════════════
-- print("🏠 [LevelGenerator] Bâtiments désactivés")

-- ══════════════════════════════════════════════════════════════════════════════
-- 3. ARBRES — DÉSACTIVÉ (terrain nu pour les bases des joueurs)
-- ══════════════════════════════════════════════════════════════════════════════
-- print("🌲 [LevelGenerator] Arbres désactivés")

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
	light.Brightness = 1.5
	light.Range      = 40
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
-- 6. SOL LEGO — Grille de dalles vertes avec Studs apparents
-- ══════════════════════════════════════════════════════════════════════════════
local legoGround = Instance.new("Folder")
legoGround.Name   = "LegoGround"
legoGround.Parent = envFolder

local TILE_W  = 50   -- Largeur d'une tuile (studs)
local TILE_D  = 50   -- Profondeur d'une tuile
local TILE_H  = 1    -- Épaisseur (1 stud)
local GRID_CX = 0    -- Centre X de la grille
local GRID_CZ = 0    -- Centre Z de la grille

-- Couleurs alternées pour l'effet LEGO classique
local LEGO_COLORS = {
    Color3.fromRGB( 75, 151,  74), -- Vert vif LEGO (Bright Green)
    Color3.fromRGB( 88, 166,  86), -- Vert moyen
    Color3.fromRGB( 63, 137,  61), -- Vert foncé
}

-- 12 colonnes × 8 rangées = 600 × 400 studs couverts
local COLS = 12
local ROWS = 8

for row = 0, ROWS - 1 do
    for col = 0, COLS - 1 do
        local tileX = GRID_CX + (col - COLS / 2 + 0.5) * TILE_W
        local tileZ = GRID_CZ + (row - ROWS / 2 + 0.5) * TILE_D
        local colorIdx = ((row + col) % #LEGO_COLORS) + 1

        local tile = Instance.new("Part")
        tile.Name       = "Tile_" .. row .. "_" .. col
        tile.Size       = Vector3.new(TILE_W, TILE_H, TILE_D)
        tile.Position   = Vector3.new(tileX, 0.5, tileZ) -- même niveau que l'avenue (top = 1)
        tile.Anchored   = true
        tile.CanCollide = true   -- Sol marchable
        tile.Color      = LEGO_COLORS[colorIdx]
        tile.Material   = Enum.Material.SmoothPlastic
        tile.TopSurface = Enum.SurfaceType.Studs  -- ← STYLE LEGO
        tile.BottomSurface = Enum.SurfaceType.Smooth
        tile.Parent     = legoGround
    end
end
print("🟩 [LevelGenerator] Sol LEGO généré (" .. (COLS * ROWS) .. " tuiles)")

print("🌍 [LevelGenerator] Génération du monde terminée !")


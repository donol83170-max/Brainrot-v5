local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LootTables = require(ReplicatedStorage:WaitForChild("LootTables"))
local Constants  = require(ReplicatedStorage:WaitForChild("Constants"))
local InsertService = game:GetService("InsertService")

-- ── Résolveur Decal → Image (partagé entre les 3 roues) ────────────────────────
local decalCache = {}
local function getTrueImageId(decalId)
    if decalCache[decalId] then return decalCache[decalId] end
    local success, model = pcall(function()
        return InsertService:LoadAsset(decalId)
    end)
    if success and model then
        local decal = model:FindFirstChildWhichIsA("Decal")
        if decal then
            decalCache[decalId] = decal.Texture
            model:Destroy()
            return decalCache[decalId]
        end
        model:Destroy()
    end
    return nil
end

local DECAL_IDS = {
    [1] = 110862613756982, -- Roue Noob
    [2] = 82741196283644,  -- Roue Sigma
    [3] = 107234711297922, -- Roue Ultra
}

local WHEEL_BLUE = Color3.fromRGB(30, 100, 220)


-- ── Sol herbe ──────────────────────────────────────────────────────────────────
local ground = Instance.new("Part")
ground.Name      = "GrassGround"
ground.Size      = Vector3.new(600, 1, 400)
ground.Position  = Vector3.new(0, -0.5, 0)
ground.Anchored  = true
ground.Material  = Enum.Material.Grass
ground.Color     = Color3.fromRGB(106, 127, 63)
ground.Parent    = Workspace

-- ── Dossier parent ─────────────────────────────────────────────────────────────
local assetsFolder = Instance.new("Folder")
assetsFolder.Name   = "WheelAssets"
assetsFolder.Parent = Workspace

-- ── Fonction de construction d'une roue ────────────────────────────────────────
local function createPhysicalWheel(origin, wheelIndex)
    local wheelData = LootTables.Wheels[wheelIndex]
    if not wheelData then return end

    local BROWN      = Color3.fromRGB(101, 67, 33)
    local DARK_BROWN = Color3.fromRGB(70, 45, 20)
    local GOLD       = Color3.fromRGB(255, 215, 0)

    local folder = Instance.new("Folder")
    folder.Name   = "Wheel" .. wheelIndex
    folder:SetAttribute("WheelIndex", wheelIndex)
    folder.Parent = assetsFolder

    local ox, oy, oz = origin.X, origin.Y, origin.Z

    -- Poteau central unique (Mis à l'arrière : Z-1 pour être caché derrière la roue)
    local mainPost = Instance.new("Part")
    mainPost.Name     = "MainPost"
    mainPost.Size     = Vector3.new(2, 12, 2)
    mainPost.Position = Vector3.new(ox, oy + 6, oz - 1)
    mainPost.Anchored = true
    mainPost.Color    = BROWN
    mainPost.Material = Enum.Material.Wood
    mainPost.Parent   = folder

    -- ── BillboardGui (Labels 3D) ───────────────────────────────────────────────
    local bbgui = Instance.new("BillboardGui")
    bbgui.Name            = "InfoGui"
    bbgui.Size            = UDim2.new(0, 240, 0, 100)
    bbgui.StudsOffset     = Vector3.new(0, 15, 0)
    bbgui.Adornee         = mainPost
    bbgui.AlwaysOnTop     = false
    bbgui.Parent          = folder

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size                   = UDim2.new(1, 0, 0.5, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text                   = string.upper(wheelData.Name)
    nameLabel.TextColor3             = Color3.new(1, 1, 1)
    nameLabel.Font                   = Enum.Font.FredokaOne
    nameLabel.TextSize               = 40
    nameLabel.TextStrokeTransparency = 0
    nameLabel.Parent                 = bbgui

    local icon = (wheelData.Currency == "Gold") and "💰" or "🎟️"
    local costLabel = Instance.new("TextLabel")
    costLabel.Size                   = UDim2.new(1, 0, 0.5, 0)
    costLabel.Position               = UDim2.new(0, 0, 0.5, 0)
    costLabel.BackgroundTransparency = 1
    costLabel.Text                   = wheelData.Cost .. " " .. icon
    costLabel.TextColor3             = (wheelData.Currency == "Gold") and GOLD or Color3.fromRGB(100, 200, 255)
    costLabel.Font                   = Enum.Font.FredokaOne
    costLabel.TextSize               = 32
    costLabel.TextStrokeTransparency = 0
    costLabel.Parent                 = bbgui

    local WHEEL_BLUE = Color3.fromRGB(30, 100, 220)
    local LIGHT_BLUE_NEON = Color3.fromRGB(100, 200, 255)

    -- Roue principale (cylindre bleu)
    local wheel = Instance.new("Part")
    wheel.Name        = "PhysicalWheel"
    wheel.Shape       = Enum.PartType.Cylinder
    wheel.Size        = Vector3.new(0.8, 12, 12)
    wheel.Position    = Vector3.new(ox, oy + 10, oz)
    wheel.Orientation = Vector3.new(0, 90, 0)
    wheel.Anchored    = true
    wheel.Color       = WHEEL_BLUE
    wheel.Material    = Enum.Material.SmoothPlastic
    wheel.Parent      = folder

    -- Jante néon
    local rim = Instance.new("Part")
    rim.Name        = "WheelRim"
    rim.Shape       = Enum.PartType.Cylinder
    rim.Size        = Vector3.new(0.35, 13, 13)
    rim.Position    = Vector3.new(ox, oy + 10, oz)
    rim.Orientation = Vector3.new(0, 90, 0)
    rim.Anchored    = true
    rim.Color       = LIGHT_BLUE_NEON
    rim.Material    = Enum.Material.Neon
    rim.CastShadow  = false
    rim.CanCollide  = false
    rim.Parent      = folder

    -- Axe (reculé un peu vers le poteau)
    local axle = Instance.new("Part")
    axle.Name        = "WheelAxle"
    axle.Shape       = Enum.PartType.Cylinder
    axle.Size        = Vector3.new(1, 1, 1)
    axle.Position    = Vector3.new(ox, oy + 10, oz - 0.5)
    axle.Orientation = Vector3.new(0, 90, 0)
    axle.Anchored    = true
    axle.Color       = Color3.fromRGB(100, 100, 110)
    axle.Material    = Enum.Material.Metal
    axle.Parent      = folder

    -- Pointeur rouge au sommet (fixé en haut de l'axe ou juste au-dessus de la roue)
    local pointer = Instance.new("WedgePart")
    pointer.Name       = "Pointer"
    pointer.Size       = Vector3.new(0.5, 2.5, 1.4)
    pointer.Position   = Vector3.new(ox, oy + 16.5, oz)
    pointer.Anchored   = true
    pointer.Color      = Color3.fromRGB(210, 40, 40)
    pointer.Material   = Enum.Material.Neon
    pointer.CastShadow = false
    pointer.Parent     = folder

    -- Confettis (Désactivés par défaut)
    local confetti = Instance.new("ParticleEmitter")
    confetti.Name = "Confetti"
    confetti.Texture = "rbxassetid://5860882143" -- Texture confetti générique
    confetti.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
        ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
        ColorSequenceKeypoint.new(0.66, Color3.fromRGB(0, 0, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 0))
    })
    confetti.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(1, 0.2)
    })
    confetti.Speed = NumberRange.new(20, 30)
    confetti.SpreadAngle = Vector2.new(45, 45)
    confetti.Acceleration = Vector3.new(0, -30, 0)
    confetti.Lifetime = NumberRange.new(2, 4)
    confetti.Rate = 0
    confetti.Enabled = false
    confetti.Parent = pointer

    -- Trail sur la jante
    local att0 = Instance.new("Attachment", wheel)
    att0.Position = Vector3.new(0, 6, 0)
    local att1 = Instance.new("Attachment", wheel)
    att1.Position = Vector3.new(0, -6, 0)
    local trail = Instance.new("Trail")
    trail.Attachment0  = att0
    trail.Attachment1  = att1
    trail.Lifetime     = 0.4
    trail.Color        = ColorSequence.new(Color3.fromRGB(255, 200, 0))
    trail.Transparency = NumberSequence.new(0.4, 1)
    trail.Parent       = wheel

    -- ClickDetector
    local clickDetector = Instance.new("ClickDetector")
    clickDetector.MaxActivationDistance = 25
    clickDetector.Parent = wheel

    -- ── Pointeur (Flèche) en haut de la roue ───────────────────────────────────
    local pointer = Instance.new("Part")
    pointer.Name = "Pointer"
    pointer.Size = Vector3.new(3, 3, 3)
    pointer.Anchored = true
    pointer.CanCollide = false
    pointer.Color = Color3.fromRGB(255, 0, 0) -- Rouge plus vif
    pointer.Material = Enum.Material.Neon
    
    -- Positionnement en haut (Y + 6.7) et légèrement en avant (X + 1.2)
    pointer.CFrame = wheel.CFrame * CFrame.new(1.2, 6.7, 0) * CFrame.Angles(0, 0, math.rad(45))
    
    -- Création d'une forme de pointe plus grosse
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.FileMesh
    mesh.MeshId = "rbxassetid://1033714"
    mesh.Scale = Vector3.new(2.5, 2.5, 2.5) -- Augmenté (1.5 -> 2.5)
    mesh.Parent = pointer
    
    pointer.Parent = wheel

    -- ── SurfaceGui pour les segments 3D ──────────────────────────────────────────
    local surfaceGui = Instance.new("SurfaceGui")
    surfaceGui.Name = "WheelDisplay"
    surfaceGui.Face = Enum.NormalId.Left -- Face circulaire orientée vers le joueur
    surfaceGui.CanvasSize = Vector2.new(1024, 1024)
    surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    surfaceGui.AlwaysOnTop = false
    surfaceGui.ZOffset = 1
    surfaceGui.LightInfluence = 1
    surfaceGui.Parent = wheel

    -- Résolution de la texture et application (Méthode validée par l'utilisateur)
    local wheelFace = Instance.new("ImageLabel")
    wheelFace.Name = "WheelFace"
    wheelFace.Size = UDim2.new(1.1, 0, 1.1, 0) -- Agrandit pour remplir tout le cercle
    wheelFace.AnchorPoint = Vector2.new(0.5, 0.5)
    wheelFace.Position = UDim2.new(0.5, 0, 0.5, 0)
    wheelFace.BackgroundTransparency = 0
    wheelFace.BackgroundColor3 = WHEEL_BLUE
    wheelFace.ScaleType = Enum.ScaleType.Stretch
    Instance.new("UICorner", wheelFace).CornerRadius = UDim.new(0.5, 0)
    wheelFace.Parent = surfaceGui

    local decalId = DECAL_IDS[wheelIndex]
    if decalId then
        task.spawn(function()
            local texture = getTrueImageId(decalId)
            if texture then
                wheelFace.Image = texture
                wheelFace.BackgroundTransparency = 1
                -- Passer l'ID résolu au Client pour l'UI
                folder:SetAttribute("ResolvedImageId", texture)
                print("✅ [WorldAssets] Roue " .. wheelIndex .. " → " .. texture)
            else
                print("⚠️ [WorldAssets] Texture introuvable pour roue " .. wheelIndex)
            end
        end)
    end


    print(string.format("🏗️ [WorldAssets] Roue %d construite en (%d, %d, %d)", wheelIndex, ox, oy, oz))
end

-- ══════════════════════════════════════════════════════════════════════════════
-- FONTAINE CENTRALE
-- ══════════════════════════════════════════════════════════════════════════════
local fountainFolder = Instance.new("Folder")
fountainFolder.Name = "Fountain"
fountainFolder.Parent = assetsFolder

-- Bassin extérieur (marbre)
local basin = Instance.new("Part")
basin.Name        = "Basin"
basin.Shape       = Enum.PartType.Cylinder
basin.Size        = Vector3.new(2, 20, 20) -- Hauteur 2, Ø20
basin.CFrame      = CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(90))
basin.Anchored    = true
basin.Color       = Color3.fromRGB(200, 195, 185) -- Marbre clair
basin.Material    = Enum.Material.Marble
basin.Parent      = fountainFolder

-- Eau intérieure (transparent)
local water = Instance.new("Part")
water.Name        = "Water"
water.Shape       = Enum.PartType.Cylinder
water.Size        = Vector3.new(1.5, 18, 18) -- Légèrement plus petit que le bassin
water.CFrame      = CFrame.new(0, 1.3, 0) * CFrame.Angles(0, 0, math.rad(90))
water.Anchored    = true
water.CanCollide  = false
water.Color       = Color3.fromRGB(60, 150, 220) -- Bleu eau
water.Material    = Enum.Material.Glass
water.Transparency = 0.4
water.Parent      = fountainFolder

-- Pilier central
local pillar = Instance.new("Part")
pillar.Name       = "Pillar"
pillar.Shape      = Enum.PartType.Cylinder
pillar.Size       = Vector3.new(10, 3, 3) -- Hauteur 10, Ø3
pillar.CFrame     = CFrame.new(0, 6, 0) * CFrame.Angles(0, 0, math.rad(90))
pillar.Anchored   = true
pillar.Color      = Color3.fromRGB(210, 205, 195)
pillar.Material   = Enum.Material.Marble
pillar.Parent     = fountainFolder

-- Sphère dorée décorative au sommet
local sphere = Instance.new("Part")
sphere.Name       = "GoldenSphere"
sphere.Shape      = Enum.PartType.Ball
sphere.Size       = Vector3.new(3, 3, 3)
sphere.Position   = Vector3.new(0, 12.5, 0)
sphere.Anchored   = true
sphere.CanCollide = false
sphere.Color      = Color3.fromRGB(255, 215, 0) -- Or
sphere.Material   = Enum.Material.Neon
sphere.Parent     = fountainFolder

-- Particules d'eau (jaillit vers le haut puis retombe)
local waterEmitter = Instance.new("ParticleEmitter")
waterEmitter.Name         = "WaterSpray"
waterEmitter.Texture      = "rbxassetid://241685484" -- Particule blanche douce
waterEmitter.Color        = ColorSequence.new(Color3.fromRGB(180, 220, 255))
waterEmitter.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.3),
    NumberSequenceKeypoint.new(0.5, 0.5),
    NumberSequenceKeypoint.new(1, 1),
})
waterEmitter.Size = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.3),
    NumberSequenceKeypoint.new(0.5, 0.8),
    NumberSequenceKeypoint.new(1, 0.1),
})
waterEmitter.Speed        = NumberRange.new(8, 14)
waterEmitter.SpreadAngle  = Vector2.new(15, 15)
waterEmitter.Acceleration = Vector3.new(0, -20, 0) -- Gravité pour retomber
waterEmitter.Lifetime     = NumberRange.new(1, 2)
waterEmitter.Rate         = 40
waterEmitter.RotSpeed     = NumberRange.new(-30, 30)
waterEmitter.Enabled      = true
waterEmitter.Parent       = sphere

-- Deuxième couche (gouttelettes tombantes)
local drips = Instance.new("ParticleEmitter")
drips.Name         = "WaterDrips"
drips.Texture      = "rbxassetid://241685484"
drips.Color        = ColorSequence.new(Color3.fromRGB(120, 180, 240))
drips.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.2),
    NumberSequenceKeypoint.new(1, 0.9),
})
drips.Size = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.2),
    NumberSequenceKeypoint.new(1, 0.5),
})
drips.Speed        = NumberRange.new(1, 4)
drips.SpreadAngle  = Vector2.new(180, 180)
drips.Acceleration = Vector3.new(0, -15, 0)
drips.Lifetime     = NumberRange.new(0.8, 1.5)
drips.Rate         = 25
drips.Enabled      = true
drips.Parent       = sphere

-- Lumière ambiante de la fontaine
local fountainLight = Instance.new("PointLight")
fountainLight.Color      = Color3.fromRGB(150, 200, 255)
fountainLight.Brightness = 1
fountainLight.Range      = 30
fountainLight.Parent     = sphere

print("⛲ [WorldAssets] Fontaine centrale créée")

-- ══════════════════════════════════════════════════════════════════════════════
-- CRÉATION DES 3 ROUES (en arc face au spawn)
-- ══════════════════════════════════════════════════════════════════════════════
-- Le spawn sera à Z=45, les roues forment un arc à Z négatif face au spawn
local WHEEL_RADIUS = 35 -- Distance du centre
local SPAWN_POS = Vector3.new(0, 0.5, 80)

-- Positions directes pour plus de contrôle sur le placement
-- Roue Noob devant la fontaine, Sigma et Ultra entre les bâtiments (gauche/droite)
local WHEEL_POSITIONS = {
    { pos = Vector3.new(0, 0, 35),    index = 1 }, -- Roue Noob (devant la fontaine, face au spawn)
    { pos = Vector3.new(-110, 0, 0),  index = 2 }, -- Roue Sigma (gauche, entre les bâtiments)
    { pos = Vector3.new(110, 0, 0),   index = 3 }, -- Roue Ultra (droite, entre les bâtiments)
}

for _, layout in ipairs(WHEEL_POSITIONS) do
    createPhysicalWheel(layout.pos, layout.index)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- SPAWN INVISIBLE (face à la fontaine)
-- ══════════════════════════════════════════════════════════════════════════════
-- Nettoyage des anciens spawns
for _, obj in ipairs(Workspace:GetChildren()) do
    if obj:IsA("SpawnLocation") then
        obj:Destroy()
    end
end

local spawn = Instance.new("SpawnLocation")
spawn.Name         = "MainSpawn"
spawn.Size         = Vector3.new(12, 1, 12)
spawn.Anchored     = true
spawn.Transparency = 1           -- COMPLÈTEMENT INVISIBLE
spawn.CanCollide   = false       -- On ne marche pas "sur" le spawn
spawn.Enabled      = true
spawn.Neutral      = true
spawn.Duration     = 0           -- Pas de temps de respawn forcé

-- Regarde vers la galerie (entrée à Z ≈ 110, spawn à Z=80)
spawn.CFrame = CFrame.lookAt(SPAWN_POS, Vector3.new(0, 0.5, 110))
spawn.Parent = Workspace

-- Supprimer le Decal bleu par défaut que Roblox ajoute automatiquement
task.defer(function()
    for _, child in ipairs(spawn:GetChildren()) do
        if child:IsA("Decal") then
            child:Destroy()
        end
    end
end)

print("🚩 [WorldAssets] Spawn invisible configuré à (0, 0.5, 45) face à la fontaine")


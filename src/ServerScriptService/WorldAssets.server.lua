local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LootTables = require(ReplicatedStorage:WaitForChild("LootTables"))

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

    -- Base Platform
    local base = Instance.new("Part")
    base.Name     = "WheelBase"
    base.Size     = Vector3.new(20, 1.2, 9)
    base.Position = Vector3.new(ox, oy + 0.6, oz)
    base.Anchored = true
    base.Color    = BROWN
    base.Material = Enum.Material.Wood
    base.Parent   = folder

    -- Pieds
    for _, zOff in ipairs({ -3.5, 3.5 }) do
        for _, xOff in ipairs({ -9, 9 }) do
            local foot = Instance.new("Part")
            foot.Size     = Vector3.new(1.2, 2.5, 1.2)
            foot.Position = Vector3.new(ox + xOff, oy - 0.65, oz + zOff)
            foot.Anchored = true
            foot.Color    = DARK_BROWN
            foot.Material = Enum.Material.Wood
            foot.Parent   = folder
        end
    end

    -- Poteaux verticaux
    local function makePost(xOff)
        local post = Instance.new("Part")
        post.Name     = (xOff < 0) and "LeftPost" or "RightPost"
        post.Size     = Vector3.new(1.6, 18, 1.6)
        post.Position = Vector3.new(ox + xOff, oy + 9.2, oz)
        post.Anchored = true
        post.Color    = BROWN
        post.Material = Enum.Material.Wood
        post.Parent   = folder
    end
    makePost(-7.5)
    makePost( 7.5)

    -- Barre du haut
    local topBar = Instance.new("Part")
    topBar.Name     = "TopBar"
    topBar.Size     = Vector3.new(17.2, 1.6, 1.6)
    topBar.Position = Vector3.new(ox, oy + 18.2, oz)
    topBar.Anchored = true
    topBar.Color    = BROWN
    topBar.Material = Enum.Material.Wood
    topBar.Parent   = folder

    -- ── BillboardGui (Labels 3D) ───────────────────────────────────────────────
    local bbgui = Instance.new("BillboardGui")
    bbgui.Name            = "InfoGui"
    bbgui.Size            = UDim2.new(0, 200, 0, 100)
    bbgui.StudsOffset     = Vector3.new(0, 4, 0) -- Flotte au-dessus de la TopBar
    bbgui.Adornee         = topBar
    bbgui.AlwaysOnTop     = false -- Pour que ça reste derrière les murs si besoin, plus immersif
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

    -- Barrières décoratives
    for _, yOff in ipairs({ 4, 8, 12 }) do
        local rail = Instance.new("Part")
        rail.Size     = Vector3.new(17.2, 0.6, 0.6)
        rail.Position = Vector3.new(ox, oy + yOff, oz + 3.8)
        rail.Anchored = true
        rail.Color    = DARK_BROWN
        rail.Material = Enum.Material.Wood
        rail.Parent   = folder
    end

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

    -- Moyeu central
    local hub = Instance.new("Part")
    hub.Name        = "WheelHub"
    hub.Shape       = Enum.PartType.Cylinder
    hub.Size        = Vector3.new(1, 2.8, 2.8)
    hub.Position    = Vector3.new(ox, oy + 10, oz)
    hub.Orientation = Vector3.new(0, 90, 0)
    hub.Anchored    = true
    hub.Color       = Color3.new(1, 1, 1)
    hub.Material    = Enum.Material.SmoothPlastic
    hub.Parent      = folder

    -- Axe
    local axle = Instance.new("Part")
    axle.Name        = "WheelAxle"
    axle.Shape       = Enum.PartType.Cylinder
    axle.Size        = Vector3.new(15.5, 1, 1)
    axle.Position    = Vector3.new(ox, oy + 10, oz)
    axle.Orientation = Vector3.new(0, 90, 0)
    axle.Anchored    = true
    axle.Color       = Color3.fromRGB(100, 100, 110)
    axle.Material    = Enum.Material.Metal
    axle.Parent      = folder

    -- Pointeur rouge au sommet
    local pointer = Instance.new("WedgePart")
    pointer.Name       = "Pointer"
    pointer.Size       = Vector3.new(0.5, 2.5, 1.4)
    pointer.Position   = Vector3.new(ox, oy + 17.2, oz)
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

    print(string.format("🏗️ [WorldAssets] Roue %d construite en (%d, %d, %d)", wheelIndex, ox, oy, oz))
end

-- ── Création des 3 roues ───────────────────────────────────────────────────────
createPhysicalWheel(Vector3.new(  0, 0, 0), 1)   -- Roue Noob   (centre)
createPhysicalWheel(Vector3.new(-70, 0, 0), 2)   -- Roue Sigma  (gauche)
createPhysicalWheel(Vector3.new( 70, 0, 0), 3)   -- Roue Ultra  (droite)

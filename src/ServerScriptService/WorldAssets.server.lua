-- WorldAssets.server.lua
-- Crée la structure physique du monde (stand en bois + roue dorée)

local Workspace = game:GetService("Workspace")

local function createPhysicalWheel()
    local folder = Instance.new("Folder")
    folder.Name = "WheelAssets"
    folder.Parent = Workspace

    local BROWN      = Color3.fromRGB(101, 67, 33)
    local DARK_BROWN = Color3.fromRGB(70, 45, 20)
    local GOLD       = Color3.fromRGB(255, 215, 0)
    local GOLD_NEON  = Color3.fromRGB(255, 230, 60)

    -- ── Base Platform ─────────────────────────────────────────────────────────
    local base = Instance.new("Part")
    base.Name       = "WheelBase"
    base.Size       = Vector3.new(20, 1.2, 9)
    base.Position   = Vector3.new(0, 0.6, 0)
    base.Anchored   = true
    base.Color      = BROWN
    base.Material   = Enum.Material.Wood
    base.Parent     = folder

    -- Pieds avant / arrière
    for _, zOff in ipairs({ -3.5, 3.5 }) do
        for _, xOff in ipairs({ -9, 9 }) do
            local foot = Instance.new("Part")
            foot.Size     = Vector3.new(1.2, 2.5, 1.2)
            foot.Position = Vector3.new(xOff, -0.65, zOff)
            foot.Anchored = true
            foot.Color    = DARK_BROWN
            foot.Material = Enum.Material.Wood
            foot.Parent   = folder
        end
    end

    -- ── Poteaux verticaux ─────────────────────────────────────────────────────
    local function makePost(x)
        local post = Instance.new("Part")
        post.Name     = (x < 0) and "LeftPost" or "RightPost"
        post.Size     = Vector3.new(1.6, 18, 1.6)
        post.Position = Vector3.new(x, 9.2, 0)
        post.Anchored = true
        post.Color    = BROWN
        post.Material = Enum.Material.Wood
        post.Parent   = folder
        return post
    end
    makePost(-7.5)
    makePost( 7.5)

    -- ── Barre du haut ─────────────────────────────────────────────────────────
    local topBar = Instance.new("Part")
    topBar.Name     = "TopBar"
    topBar.Size     = Vector3.new(17.2, 1.6, 1.6)
    topBar.Position = Vector3.new(0, 18.2, 0)
    topBar.Anchored = true
    topBar.Color    = BROWN
    topBar.Material = Enum.Material.Wood
    topBar.Parent   = folder

    -- ── Barrières décoratives ─────────────────────────────────────────────────
    for _, yOff in ipairs({ 4, 8, 12 }) do
        local rail = Instance.new("Part")
        rail.Size     = Vector3.new(17.2, 0.6, 0.6)
        rail.Position = Vector3.new(0, yOff, 3.8)
        rail.Anchored = true
        rail.Color    = DARK_BROWN
        rail.Material = Enum.Material.Wood
        rail.Parent   = folder
    end

    -- ── Roue principale (cylindre doré) ───────────────────────────────────────
    local wheel = Instance.new("Part")
    wheel.Name        = "PhysicalWheel"
    wheel.Shape       = Enum.PartType.Cylinder
    wheel.Size        = Vector3.new(0.8, 12, 12)
    wheel.Position    = Vector3.new(0, 10, 0)
    wheel.Orientation = Vector3.new(0, 90, 0)
    wheel.Anchored    = true
    wheel.Color       = GOLD
    wheel.Material    = Enum.Material.SmoothPlastic
    wheel.Parent      = folder

    -- Jante dorée néon (anneau extérieur)
    local rim = Instance.new("Part")
    rim.Name        = "WheelRim"
    rim.Shape       = Enum.PartType.Cylinder
    rim.Size        = Vector3.new(0.35, 13, 13)
    rim.Position    = Vector3.new(0, 10, 0)
    rim.Orientation = Vector3.new(0, 90, 0)
    rim.Anchored    = true
    rim.Color       = GOLD_NEON
    rim.Material    = Enum.Material.Neon
    rim.CastShadow  = false
    rim.CanCollide  = false
    rim.Parent      = folder

    -- Moyeu central (blanc)
    local hub = Instance.new("Part")
    hub.Name        = "WheelHub"
    hub.Shape       = Enum.PartType.Cylinder
    hub.Size        = Vector3.new(1, 2.8, 2.8)
    hub.Position    = Vector3.new(0, 10, 0)
    hub.Orientation = Vector3.new(0, 90, 0)
    hub.Anchored    = true
    hub.Color       = Color3.new(1, 1, 1)
    hub.Material    = Enum.Material.SmoothPlastic
    hub.Parent      = folder

    -- Axe (connecte la roue aux poteaux)
    local axle = Instance.new("Part")
    axle.Name        = "WheelAxle"
    axle.Shape       = Enum.PartType.Cylinder
    axle.Size        = Vector3.new(15.5, 1, 1)
    axle.Position    = Vector3.new(0, 10, 0)
    axle.Orientation = Vector3.new(0, 90, 0)
    axle.Anchored    = true
    axle.Color       = Color3.fromRGB(100, 100, 110)
    axle.Material    = Enum.Material.Metal
    axle.Parent      = folder

    -- ── Pointeur (indicateur rouge au sommet) ─────────────────────────────────
    local pointer = Instance.new("WedgePart")
    pointer.Name      = "Pointer"
    pointer.Size      = Vector3.new(0.5, 2.5, 1.4)
    pointer.Position  = Vector3.new(0, 17.2, 0)
    pointer.Anchored  = true
    pointer.Color     = Color3.fromRGB(210, 40, 40)
    pointer.Material  = Enum.Material.Neon
    pointer.CastShadow = false
    pointer.Parent    = folder

    -- ── Trail sur la jante (effet visuel lors de la rotation) ─────────────────
    local att0 = Instance.new("Attachment", wheel)
    att0.Position = Vector3.new(0, 6, 0)
    local att1 = Instance.new("Attachment", wheel)
    att1.Position = Vector3.new(0, -6, 0)

    local trail = Instance.new("Trail")
    trail.Attachment0   = att0
    trail.Attachment1   = att1
    trail.Lifetime      = 0.4
    trail.Color         = ColorSequence.new(Color3.fromRGB(255, 200, 0))
    trail.Transparency  = NumberSequence.new(0.4, 1)
    trail.Parent        = wheel

    -- ── ClickDetector ─────────────────────────────────────────────────────────
    local clickDetector = Instance.new("ClickDetector")
    clickDetector.MaxActivationDistance = 25
    clickDetector.Parent = wheel

    print("🏗️ [WorldAssets] Roue physique construite !")
end

createPhysicalWheel()

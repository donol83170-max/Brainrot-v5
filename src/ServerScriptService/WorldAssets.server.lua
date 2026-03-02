-- WorldAssets.server.lua
-- Crée et gère les objets physiques du monde (Roue, Plateformes, etc.)

local Workspace = game:GetService("Workspace")

local function createPhysicalWheel()
    local folder = Instance.new("Folder")
    folder.Name = "WheelAssets"
    folder.Parent = Workspace

    -- Le Poteau Vertical (Support AVANT)
    local post = Instance.new("Part")
    post.Name = "WheelPost"
    post.Size = Vector3.new(1.5, 15, 1.5)
    post.Position = Vector3.new(0, 7.5, -1.5) -- Totalement devant la roue
    post.Anchored = true
    post.Color = Color3.fromRGB(180, 160, 0) -- Jaune foncé
    post.Material = Enum.Material.Metal
    post.Parent = folder

    -- La Roue (Spinner)
    local wheel = Instance.new("Part")
    wheel.Name = "PhysicalWheel"
    wheel.Shape = Enum.PartType.Cylinder
    wheel.Size = Vector3.new(0.5, 12, 12)
    wheel.Position = Vector3.new(0, 10, 0) -- Origine
    wheel.Orientation = Vector3.new(0, 90, 0) -- Rotation Y: fait pointer la face vers -Z
    wheel.Anchored = true
    wheel.Color = Color3.fromRGB(0, 0, 255) -- Bleu normal
    wheel.Material = Enum.Material.Neon
    wheel.Parent = folder

    -- Un ClickDetector pour l'interaction
    local clickDetector = Instance.new("ClickDetector")
    clickDetector.MaxActivationDistance = 20
    clickDetector.Parent = wheel

    -- Décoration (Centre de la roue)
    local center = Instance.new("Part")
    center.Name = "WheelCenter"
    center.Size = Vector3.new(0.2, 3, 3) -- Plat
    center.Shape = Enum.PartType.Cylinder
    center.Position = Vector3.new(0, 10, -0.26) -- Collé sur la face avant (-Z)
    center.Orientation = Vector3.new(0, 90, 0)
    center.Anchored = true
    center.Color = Color3.fromRGB(255, 255, 255)
    center.Material = Enum.Material.SmoothPlastic
    center.Parent = folder

    -- L'Axe (Petit raccord entre roue et poteau avant)
    local axle = Instance.new("Part")
    axle.Name = "WheelAxle"
    axle.Shape = Enum.PartType.Cylinder
    axle.Size = Vector3.new(0.6, 1.2, 1.2)
    axle.Position = Vector3.new(0, 10, -0.5) -- Rempli l'espace entre le poteau (-0.75) et la moitie de l'axe(-0.25)
    axle.Orientation = Vector3.new(0, 90, 0)
    axle.Anchored = true
    axle.Color = Color3.fromRGB(100, 100, 110)
    axle.Material = Enum.Material.Metal
    axle.Parent = folder

    -- Un sillage pour le style
    local trailAtt0 = Instance.new("Attachment", wheel)
    trailAtt0.Position = Vector3.new(0, 6, 0) -- Plus loin (rayon de 6)
    local trailAtt1 = Instance.new("Attachment", wheel)
    trailAtt1.Position = Vector3.new(0, -6, 0)
    
    local trail = Instance.new("Trail")
    trail.Attachment0 = trailAtt0
    trail.Attachment1 = trailAtt1
    trail.Lifetime = 0.5
    trail.Color = ColorSequence.new(Color3.fromRGB(170, 0, 255))
    trail.Transparency = NumberSequence.new(0.5, 1)
    trail.Parent = wheel

    print("🏗️ [WorldAssets] Roue physique construite à l'origine !")
end

createPhysicalWheel()

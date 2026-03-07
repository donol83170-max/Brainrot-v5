-- WorldAssets.server.lua
-- Génère les éléments statiques du monde : sol, fontaine, spawn.
-- Les roues ont été retirées — elles seront refaites proprement dans un nouveau script.

local Workspace = game:GetService("Workspace")

-- ── Sol herbe ──────────────────────────────────────────────────────────────────
local ground = Instance.new("Part")
ground.Name      = "GrassGround"
ground.Size      = Vector3.new(600, 1, 400)
ground.Position  = Vector3.new(0, -0.5, 0)
ground.Anchored  = true
ground.Material  = Enum.Material.Grass
ground.Color     = Color3.fromRGB(106, 127, 63)
ground.Parent    = Workspace

-- ── Fontaine centrale ──────────────────────────────────────────────────────────
local fountainFolder = Instance.new("Folder")
fountainFolder.Name   = "Fountain"
fountainFolder.Parent = Workspace

local basin = Instance.new("Part")
basin.Name     = "Basin"
basin.Shape    = Enum.PartType.Cylinder
basin.Size     = Vector3.new(2, 20, 20)
basin.CFrame   = CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(90))
basin.Anchored = true
basin.Color    = Color3.fromRGB(200, 195, 185)
basin.Material = Enum.Material.Marble
basin.Parent   = fountainFolder

local water = Instance.new("Part")
water.Name         = "Water"
water.Shape        = Enum.PartType.Cylinder
water.Size         = Vector3.new(1.5, 18, 18)
water.CFrame       = CFrame.new(0, 1.3, 0) * CFrame.Angles(0, 0, math.rad(90))
water.Anchored     = true
water.CanCollide   = false
water.Color        = Color3.fromRGB(60, 150, 220)
water.Material     = Enum.Material.Glass
water.Transparency = 0.4
water.Parent       = fountainFolder

local pillar = Instance.new("Part")
pillar.Name     = "Pillar"
pillar.Shape    = Enum.PartType.Cylinder
pillar.Size     = Vector3.new(10, 3, 3)
pillar.CFrame   = CFrame.new(0, 6, 0) * CFrame.Angles(0, 0, math.rad(90))
pillar.Anchored = true
pillar.Color    = Color3.fromRGB(210, 205, 195)
pillar.Material = Enum.Material.Marble
pillar.Parent   = fountainFolder

local sphere = Instance.new("Part")
sphere.Name       = "GoldenSphere"
sphere.Shape      = Enum.PartType.Ball
sphere.Size       = Vector3.new(3, 3, 3)
sphere.Position   = Vector3.new(0, 12.5, 0)
sphere.Anchored   = true
sphere.CanCollide = false
sphere.Color      = Color3.fromRGB(255, 215, 0)
sphere.Material   = Enum.Material.Neon
sphere.Parent     = fountainFolder

local waterEmitter = Instance.new("ParticleEmitter")
waterEmitter.Texture      = "rbxassetid://241685484"
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
waterEmitter.Acceleration = Vector3.new(0, -20, 0)
waterEmitter.Lifetime     = NumberRange.new(1, 2)
waterEmitter.Rate         = 40
waterEmitter.Enabled      = true
waterEmitter.Parent       = sphere

local fountainLight = Instance.new("PointLight")
fountainLight.Color      = Color3.fromRGB(150, 200, 255)
fountainLight.Brightness = 1
fountainLight.Range      = 30
fountainLight.Parent     = sphere

print("[WorldAssets] Fontaine creee")

-- ── SpawnLocation (centre de l'avenue, face aux galeries) ─────────────────────
for _, obj in ipairs(Workspace:GetChildren()) do
    if obj:IsA("SpawnLocation") then obj:Destroy() end
end

local spawn = Instance.new("SpawnLocation")
spawn.Name         = "MainSpawn"
spawn.Size         = Vector3.new(12, 1, 12)
spawn.Anchored     = true
spawn.Transparency = 1
spawn.CanCollide   = false
spawn.Enabled      = true
spawn.Neutral      = true
spawn.Duration     = 0
spawn.CFrame       = CFrame.lookAt(Vector3.new(0, 1, 110), Vector3.new(0, 1, 142))
spawn.Parent       = Workspace

task.defer(function()
    for _, child in ipairs(spawn:GetChildren()) do
        if child:IsA("Decal") then child:Destroy() end
    end
end)

print("[WorldAssets] Spawn configure au centre de l'avenue (Z=110)")
print("[WorldAssets] Pret — roues a ajouter dans un nouveau script dedie")

-- BrainrotModelsSetup.server.lua
-- Génère les modèles placeholder dans ReplicatedStorage/BrainrotModels.
-- Si un vrai modèle 3D avec le même nom existe déjà, il N'EST PAS écrasé.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:FindFirstChild("BrainrotModels")
if not folder then
    folder        = Instance.new("Folder")
    folder.Name   = "BrainrotModels"
    folder.Parent = ReplicatedStorage
end

-- TABLE OFFICIELLE — nom exact (= clé findBrainrotModel) + couleur rareté
local ITEMS = {
    -- ── COMMON (vert) ──────────────────────────────────────────────────────
    { name = "Ballerina Cappuccina",       color = Color3.fromRGB(  0, 200,  60) },
    { name = "Bombardiro Crocodilo",       color = Color3.fromRGB(  0, 200,  60) },
    { name = "Bombombini Gusini",          color = Color3.fromRGB(  0, 200,  60) },
    { name = "Cappuccino Assassino",       color = Color3.fromRGB(  0, 200,  60) },
    { name = "Lirili Larila",              color = Color3.fromRGB(  0, 200,  60) },
    { name = "Six Seven",                  color = Color3.fromRGB(  0, 200,  60) },
    { name = "Tralalero Tralala",          color = Color3.fromRGB(  0, 200,  60) },
    { name = "Trippi Troppi",              color = Color3.fromRGB(  0, 200,  60) },
    -- ── RARE (bleu) ────────────────────────────────────────────────────────
    { name = "Brr Brr Patapim",            color = Color3.fromRGB(  0, 130, 255) },
    { name = "Galaxy W Or L",              color = Color3.fromRGB(  0, 130, 255) },
    { name = "Gold Chimpanzini Bananini",  color = Color3.fromRGB(  0, 130, 255) },
    { name = "Gold Los Tralaleritos",      color = Color3.fromRGB(  0, 130, 255) },
    -- ── EPIC (violet) ──────────────────────────────────────────────────────
    { name = "Diamond Six Seven",          color = Color3.fromRGB(255,   0, 255) },
    { name = "Diamond Tung Sahur",         color = Color3.fromRGB(255,   0, 255) },
    -- ── LEGENDARY (doré) ───────────────────────────────────────────────────
    { name = "Dragon Cannelloni",          color = Color3.fromRGB(255, 215,   0) },
    { name = "Strawberry Elephant",        color = Color3.fromRGB(255, 215,   0) },
}

local created = 0
for _, entry in ipairs(ITEMS) do
    -- Ne jamais écraser un vrai modèle déjà présent
    if not folder:FindFirstChild(entry.name) then
        local model       = Instance.new("Model")
        model.Name        = entry.name

        local part = Instance.new("Part")
        part.Name          = "Body"
        part.Size          = Vector3.new(2.8, 3.5, 2.8)
        part.Anchored      = true
        part.CanCollide    = false
        part.Color         = entry.color
        part.Material      = Enum.Material.SmoothPlastic
        part.TopSurface    = Enum.SurfaceType.Smooth
        part.BottomSurface = Enum.SurfaceType.Smooth
        part.CastShadow    = true
        part.Parent        = model

        local sg             = Instance.new("SurfaceGui")
        sg.Face              = Enum.NormalId.Front
        sg.SizingMode        = Enum.SurfaceGuiSizingMode.PixelsPerStud
        sg.PixelsPerStud     = 50
        sg.Parent            = part

        local lbl                    = Instance.new("TextLabel")
        lbl.Size                     = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency   = 0.3
        lbl.BackgroundColor3         = Color3.new(0, 0, 0)
        lbl.Text                     = entry.name
        lbl.TextColor3               = Color3.new(1, 1, 1)
        lbl.Font                     = Enum.Font.GothamBold
        lbl.TextScaled               = true
        lbl.TextStrokeTransparency   = 0
        lbl.Parent                   = sg

        model.PrimaryPart = part
        model.Parent      = folder
        created          += 1
    end
end

print(string.format("[BrainrotModels] %d placeholder(s) créé(s) — %d modèle(s) au total",
    created, #folder:GetChildren()))

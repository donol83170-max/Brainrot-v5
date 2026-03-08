-- BrainrotModelsSetup.server.lua
-- Génère les placeholders dans ReplicatedStorage/BrainrotModels.
--
-- INSTRUCTIONS POUR REMPLACER UN PLACEHOLDER :
--   1. Dans la Toolbox Roblox, trouve le vrai modèle (ex: "Br Br Patapim").
--   2. Glisse-le dans ReplicatedStorage > BrainrotModels.
--   3. Renomme-le EXACTEMENT comme le placeholder (ex: "Br Br Patapim").
--   4. Supprime le placeholder cube de même nom.
--   5. Le script BrainrotGallery le détectera automatiquement au prochain spawn.
--
-- NOTE : le script NE remplace PAS un modèle existant (safe à re-exécuter).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Créer le dossier s'il n'existe pas
local folder = ReplicatedStorage:FindFirstChild("BrainrotModels")
if not folder then
    folder        = Instance.new("Folder")
    folder.Name   = "BrainrotModels"
    folder.Parent = ReplicatedStorage
end

-- TABLE OFFICIELLE — Nom affiché (= clé de lookup) + couleur rareté (placeholder)
local ITEMS = {
    -- ── COMMUN (vert) ──────────────────────────────────────────────────────────
    { name = "Skibidi Toilet",      color = Color3.fromRGB(  0, 200,  60) },
    { name = "Bombardini Gusini",   color = Color3.fromRGB(  0, 200,  60) },
    { name = "Lirilì Larilà",       color = Color3.fromRGB(  0, 200,  60) },
    { name = "Noobini Pizzanini",   color = Color3.fromRGB(  0, 200,  60) },
    -- ── RARE (bleu) ────────────────────────────────────────────────────────────
    { name = "Tralalero Tralala",   color = Color3.fromRGB(  0, 130, 255) },
    { name = "Doge",                color = Color3.fromRGB(  0, 130, 255) },
    -- ── ÉPIQUE (violet) ────────────────────────────────────────────────────────
    { name = "Br Br Patapim",       color = Color3.fromRGB(255,   0, 255) },
    -- ── LÉGENDAIRE (doré) ──────────────────────────────────────────────────────
    { name = "Strawberry Elephant", color = Color3.fromRGB(255, 215,   0) },
}

local created = 0
for _, entry in ipairs(ITEMS) do
    -- Ne pas écraser un vrai modèle déjà présent
    if not folder:FindFirstChild(entry.name) then
        local model       = Instance.new("Model")
        model.Name        = entry.name

        local part             = Instance.new("Part")
        part.Name              = "Body"
        part.Size              = Vector3.new(2.8, 3.5, 2.8)
        part.Anchored          = true
        part.CanCollide        = false
        part.Color             = entry.color
        part.Material          = Enum.Material.SmoothPlastic
        part.TopSurface        = Enum.SurfaceType.Smooth
        part.BottomSurface     = Enum.SurfaceType.Smooth
        part.CastShadow        = true
        part.Parent            = model

        -- Label sur la face avant du cube (aide visuelle en Studio)
        local sg        = Instance.new("SurfaceGui")
        sg.Face         = Enum.NormalId.Front
        sg.SizingMode   = Enum.SurfaceGuiSizingMode.PixelsPerStud
        sg.PixelsPerStud = 50
        sg.Parent       = part
        local lbl       = Instance.new("TextLabel")
        lbl.Size                   = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 0.3
        lbl.BackgroundColor3       = Color3.new(0, 0, 0)
        lbl.Text                   = entry.name
        lbl.TextColor3             = Color3.new(1, 1, 1)
        lbl.Font                   = Enum.Font.GothamBold
        lbl.TextScaled             = true
        lbl.TextStrokeTransparency = 0
        lbl.Parent                 = sg

        model.PrimaryPart = part
        model.Parent      = folder
        created          += 1
    end
end

print(string.format("[BrainrotModels] Dossier prêt — %d placeholders créés, %d modèles au total",
    created, #folder:GetChildren()))

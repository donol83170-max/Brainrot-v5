-- BrainrotModelsSetup.server.lua
-- Fusionne les modèles de "Brainrots" (Brainrots.rbxm) et "BrainrotPack" (BrainrotPack.rbxm)
-- dans un dossier unifié "BrainrotModels" pour compatibilité avec WheelSystem et BrainrotGallery.
-- Les fichiers .rbxm sources restent intacts dans ReplicatedStorage ($ignoreUnknownInstances).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Créer ou récupérer le dossier unifié
local folder = ReplicatedStorage:FindFirstChild("BrainrotModels")
if not folder then
    folder        = Instance.new("Folder")
    folder.Name   = "BrainrotModels"
    folder.Parent = ReplicatedStorage
end

-- Sources de modèles : .rbxm synchronisés par Rojo + anciens dossiers Studio
local SOURCE_FOLDERS = {
    "Brainrots",        -- BrainrotModels/Brainrots.rbxm (via sous-dossier Rojo)
    "BrainrotPack",     -- BrainrotPack.rbxm (racine ReplicatedStorage)
    "Brainrot pack1",   -- Ancien dossier Studio (préservé par $ignoreUnknownInstances)
}

local totalImported = 0

for _, sourceName in ipairs(SOURCE_FOLDERS) do
    local source = ReplicatedStorage:FindFirstChild(sourceName)
    if source then
        for _, model in ipairs(source:GetChildren()) do
            -- Éviter les doublons : si un modèle du même nom existe déjà, on skip
            if not folder:FindFirstChild(model.Name) then
                local cloned = model:Clone()
                cloned.Parent = folder
                totalImported += 1
            end
        end
        print(string.format("[BrainrotModels] Source '%s' importée (%d modèles).",
            sourceName, #source:GetChildren()))
    else
        warn(string.format("[BrainrotModels] Source '%s' introuvable dans ReplicatedStorage.", sourceName))
    end
end

print(string.format("[BrainrotModels] Dossier unifié prêt — %d modèle(s) total.",
    #folder:GetChildren()))

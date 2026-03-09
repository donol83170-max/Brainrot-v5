-- BrainrotModelsSetup.server.lua
-- Garantit uniquement que le dossier ReplicatedStorage.BrainrotModels existe.
-- NE crée AUCUN contenu — les modèles sont placés manuellement par le joueur.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:FindFirstChild("BrainrotModels")
if not folder then
    folder        = Instance.new("Folder")
    folder.Name   = "BrainrotModels"
    folder.Parent = ReplicatedStorage
    print("[BrainrotModels] Dossier créé (vide) — place tes modèles 3D manuellement.")
else
    print(string.format("[BrainrotModels] Dossier existant — %d modèle(s) détecté(s).",
        #folder:GetChildren()))
end

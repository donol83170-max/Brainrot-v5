-- GallerySign.client.lua
-- Met à jour l'enseigne de la galerie avec le nom du joueur local
-- Placé dans StarterPlayerScripts, synchronisé par Rojo

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

-- Attendre que la galerie soit générée
local function findSignLabel()
    local map = Workspace:WaitForChild("Map", 15)
    if not map then return end
    local gallery = map:WaitForChild("BrainrotGallery", 15)
    if not gallery then return end
    local plaque = gallery:WaitForChild("GallerySignPlaque", 15)
    if not plaque then return end
    local gui = plaque:WaitForChild("GallerySignGui", 10)
    if not gui then return end
    local label = gui:WaitForChild("PlayerNameLabel", 10)
    if label then
        label.Text = "✦  Base de " .. player.Name .. "  ✦"
        print("🏷️ [GallerySign] Enseigne mise à jour : Base de " .. player.Name)
    end
end

task.spawn(findSignLabel)

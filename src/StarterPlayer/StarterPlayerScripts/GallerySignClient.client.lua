-- GallerySignClient.client.lua
-- Trouve la galerie du joueur local (identifiée par son UserId) et met à jour l'enseigne.
-- Sécurité : le serveur a déjà écrit le bon texte ; ce script confirme la couleur jaune finale.

local Players   = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player     = Players.LocalPlayer
local playerName = player.Name

local map = Workspace:WaitForChild("Map", 15)
if not map then
    warn("[GallerySign] Map introuvable")
    return
end

-- Chaque galerie est nommée BrainrotGallery_<userId>
local galleryName = "BrainrotGallery_" .. tostring(player.UserId)
local gallery = map:WaitForChild(galleryName, 30)
if not gallery then
    warn("[GallerySign] Galerie introuvable : " .. galleryName)
    return
end

local signPlaque = gallery:WaitForChild("GallerySignPlaque", 15)
if not signPlaque then
    warn("[GallerySign] GallerySignPlaque introuvable dans " .. galleryName)
    return
end

-- Petit délai pour laisser le serveur finir l'initialisation
task.wait(0.5)

local text    = "★  BASE DE " .. string.upper(playerName) .. "  ★"
local updated = 0

for _, gui in ipairs(signPlaque:GetChildren()) do
    if gui:IsA("SurfaceGui") then
        local lbl = gui:FindFirstChildWhichIsA("TextLabel")
        if lbl then
            lbl.Text       = text
            lbl.TextColor3 = Color3.fromRGB(255, 230, 0)
            updated        += 1
        end
    end
end

if updated > 0 then
    print("[GallerySign] Enseigne mise a jour (" .. updated .. " GUI) : " .. text)
else
    warn("[GallerySign] Aucun SurfaceGui trouve sur GallerySignPlaque")
end

-- GallerySignClient.client.lua
-- Met à jour l'enseigne de la galerie avec le nom du joueur local.
-- Un LocalScript est plus fiable qu'un script serveur : LocalPlayer est toujours disponible.

local Players   = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player     = Players.LocalPlayer
local playerName = player.Name

-- Attendre que le serveur ait généré la galerie (max 15 sec)
local map = Workspace:WaitForChild("Map", 15)
if not map then
    warn("[GallerySign] Map introuvable")
    return
end

local gallery = map:WaitForChild("BrainrotGallery", 15)
if not gallery then
    warn("[GallerySign] BrainrotGallery introuvable")
    return
end

local signPlaque = gallery:WaitForChild("GallerySignPlaque", 15)
if not signPlaque then
    warn("[GallerySign] GallerySignPlaque introuvable")
    return
end

-- Petit délai pour laisser le serveur finir d'initialiser les SurfaceGui
task.wait(0.5)

local text = "★  BASE DE " .. string.upper(playerName) .. "  ★"

-- Mettre à jour tous les SurfaceGui de la plaque (Front et éventuellement Back)
local updated = 0
for _, gui in ipairs(signPlaque:GetChildren()) do
    if gui:IsA("SurfaceGui") then
        local lbl = gui:FindFirstChildWhichIsA("TextLabel")
        if lbl then
            lbl.Text       = text
            lbl.TextColor3 = Color3.fromRGB(255, 230, 0)  -- Jaune final (retire le rouge de debug)
            updated += 1
        end
    end
end

if updated > 0 then
    print("[GallerySign] Enseigne mise a jour (" .. updated .. " GUI) : " .. text)
else
    warn("[GallerySign] Aucun SurfaceGui trouve sur GallerySignPlaque")
end

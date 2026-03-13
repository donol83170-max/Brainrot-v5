--!strict
-- EconomyManager.server.lua
-- Leaderstats "Brainrot Coins" + "⚡ Power".
-- Revenu passif : boucle 1s qui lit model:GetAttribute("PPS") sur les Brainrots posés.

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace           = game:GetService("Workspace")

local DataManager = require(ServerScriptService:WaitForChild("DataManager"))

-- ── Références NumberValue par userId ────────────────────────────────────────
-- NumberValue (double 64 bits) : supporte jusqu'à ~9 quadrillions sans overflow.
-- IntValue (32 bits) plafonnait à 2 147 483 647 (~2.1 milliards).
local coinsValues: {[number]: NumberValue} = {}
local powerValues: {[number]: NumberValue} = {}

-- ── Création des leaderstats ─────────────────────────────────────────────────
local function createLeaderstats(player: Player)
    local leaderstats = Instance.new("Folder")
    leaderstats.Name   = "leaderstats"
    leaderstats.Parent = player

    local coins = Instance.new("NumberValue")
    coins.Name   = "Brainrot Coins"
    coins.Value  = 0
    coins.Parent = leaderstats

    local power = Instance.new("NumberValue")
    power.Name   = "⚡ Power"
    power.Value  = 0
    power.Parent = leaderstats

    coinsValues[player.UserId] = coins
    powerValues[player.UserId] = power
end

-- ── Lecture PPS depuis les modèles posés dans la galerie du joueur ────────────
-- La galerie est un Folder nommé "BrainrotGallery_{userId}" dans Workspace.Map.
-- Seuls les enfants directs avec l'Attribute "PPS" sont comptabilisés.
local function getPlayerPPS(player: Player): number
    local mapFolder = Workspace:FindFirstChild("Map")
    if not mapFolder then return 0 end

    local galleryFolder = mapFolder:FindFirstChild("BrainrotGallery_" .. player.UserId)
    if not galleryFolder then return 0 end

    local total = 0
    for _, child in ipairs(galleryFolder:GetChildren()) do
        -- Seuls les modèles Brainrot portent l'Attribute PPS (pas les murs/sols)
        total += (child:GetAttribute("PPS") or 0)
    end
    return total
end

-- ── Synchronise les Coins depuis le cache DataManager ───────────────────────
local function syncCoins(player: Player)
    local coinsVal = coinsValues[player.UserId]
    if not coinsVal then return end
    local data = DataManager.GetData(player)
    if data then
        coinsVal.Value = data.Stats.Gold
    end
end

-- ── Stub no-op pour rétro-compat (BrainrotGallery appelle encore _G.EconomyManager_SetPower) ─
-- La vraie récolte est désormais faite par la boucle 1s via les Attributes PPS.
_G.EconomyManager_SetPower = function(_player: Player, _pps: number) end

-- ── Connexion joueur ─────────────────────────────────────────────────────────
local Events           = ReplicatedStorage:WaitForChild("Events")
local UpdateClientData = Events:WaitForChild("UpdateClientData")

local function onPlayerAdded(player: Player)
    createLeaderstats(player)

    -- Attend que DataManager charge les données (max 10 s)
    for _ = 1, 20 do
        local data = DataManager.GetData(player)
        if data then
            local cv = coinsValues[player.UserId]
            if cv then cv.Value = data.Stats.Gold end
            -- Restaure la Puissance totale cumulée des sessions précédentes
            local pv = powerValues[player.UserId]
            if pv then pv.Value = data.Stats.PowerTotal or 0 end
            break
        end
        task.wait(0.5)
    end
end

local function onPlayerRemoving(player: Player)
    coinsValues[player.UserId] = nil
    powerValues[player.UserId] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, p in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, p)
end

-- ── Boucle de récolte : toutes les secondes ──────────────────────────────────
-- Pour chaque joueur : lit model:GetAttribute("PPS") sur les Brainrots posés
-- dans sa galerie → ajoute le total aux Coins + met à jour le leaderstat Power.
task.spawn(function()
    while true do
        task.wait(1)
        for _, player in ipairs(Players:GetPlayers()) do
            local pps = getPlayerPPS(player)
            if pps > 0 then
                -- +1s de revenu en Coins
                DataManager.AddGold(player, pps)
                syncCoins(player)

                -- Leaderstat ⚡ Power = puissance totale cumulée (persistante)
                local pv = powerValues[player.UserId]
                if pv then pv.Value = DataManager.GetPowerTotal(player) or pv.Value end

                -- Pousse la mise à jour client toutes les 5s pour ne pas spammer
                -- (le tick de 1s est local — pas besoin de FireClient à chaque fois)
            end
        end
    end
end)

-- ── Sync client & leaderstats toutes les 5s ──────────────────────────────────
task.spawn(function()
    while true do
        task.wait(5)
        for _, player in ipairs(Players:GetPlayers()) do
            syncCoins(player)
            local updated = DataManager.GetData(player)
            if updated then
                UpdateClientData:FireClient(player, updated)
            end
        end
    end
end)

print("[EconomyManager] Pret — récolte PPS par Attributes, tick 1s")

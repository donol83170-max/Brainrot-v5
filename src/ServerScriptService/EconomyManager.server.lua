--!strict
-- EconomyManager.server.lua
-- Leaderstats "Brainrot Coins" + "⚡ Power".
-- Le revenu passif est désormais basé sur la PowerPerSecond calculée par BrainrotGallery.

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataManager = require(ServerScriptService:WaitForChild("DataManager"))

local INCOME_INTERVAL = 5   -- secondes entre chaque tick (gain = PPS * 5)

-- ── Références IntValue par userId ───────────────────────────────────────────
local coinsValues: {[number]: IntValue} = {}
local powerValues: {[number]: IntValue} = {}
-- Puissance par joueur (mise à jour par BrainrotGallery via _G.EconomyManager_SetPower)
local playerPPS: {[number]: number} = {}

-- ── Création des leaderstats ─────────────────────────────────────────────────
local function createLeaderstats(player: Player)
    local leaderstats = Instance.new("Folder")
    leaderstats.Name   = "leaderstats"
    leaderstats.Parent = player

    local coins = Instance.new("IntValue")
    coins.Name   = "Brainrot Coins"
    coins.Value  = 0
    coins.Parent = leaderstats

    local power = Instance.new("IntValue")
    power.Name   = "⚡ Power"
    power.Value  = 0
    power.Parent = leaderstats

    coinsValues[player.UserId] = coins
    powerValues[player.UserId] = power
    playerPPS[player.UserId]   = 0
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

-- ── API publique : BrainrotGallery met à jour la puissance du joueur ─────────
-- Appelé à chaque refreshGallery (ex : après un spin, à l'arrivée).
-- Met à jour le taux de génération (utilisé pour le revenu passif en Coins).
-- NE modifie PAS le leaderstat ⚡ Power — celui-ci est réservé au total récolté.
_G.EconomyManager_SetPower = function(player: Player, pps: number)
    local uid = player.UserId
    playerPPS[uid] = pps
    print(string.format("[EconomyManager] PPS %s → %d⚡/s (Coins: +%d/%ds)",
        player.Name, pps, pps * INCOME_INTERVAL, INCOME_INTERVAL))
end

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
            -- Restaurer la puissance sauvegardée
            local pv = powerValues[player.UserId]
            if pv then pv.Value = data.Stats.TotalPower or 0 end
            break
        end
        task.wait(0.5)
    end
end

local function onPlayerRemoving(player: Player)
    coinsValues[player.UserId] = nil
    powerValues[player.UserId] = nil
    playerPPS[player.UserId]   = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, p in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, p)
end

-- ── Revenu passif : toutes les INCOME_INTERVAL secondes ─────────────────────
-- Gain = playerPPS * INCOME_INTERVAL  (0 Power = 0 gain, pas de cadeau gratuit)
task.spawn(function()
    while true do
        task.wait(INCOME_INTERVAL)
        for _, player in ipairs(Players:GetPlayers()) do
            local pps  = playerPPS[player.UserId] or 0
            local gain = pps * INCOME_INTERVAL
            if gain > 0 then
                DataManager.AddGold(player, gain)
                syncCoins(player)
                local updated = DataManager.GetData(player)
                if updated then
                    UpdateClientData:FireClient(player, updated)
                end
                print(string.format("[EconomyManager] +%d Coins → %s  (%d⚡/s × %ds)",
                    gain, player.Name, pps, INCOME_INTERVAL))
            end
        end
    end
end)

-- ── Sync leaderstats rapide (reflète les dépenses de spin) ──────────────────
task.spawn(function()
    while true do
        task.wait(5)
        for _, player in ipairs(Players:GetPlayers()) do
            syncCoins(player)
        end
    end
end)

print(string.format("[EconomyManager] Pret — revenu: Power x %ds, interval: %ds",
    INCOME_INTERVAL, INCOME_INTERVAL))

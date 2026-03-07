--!strict
-- EconomyManager.server.lua
-- Crée les leaderstats "Brainrot Coins" et distribue le revenu passif.

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataManager = require(ServerScriptService:WaitForChild("DataManager"))

local PASSIVE_AMOUNT   = 10   -- Coins gagnés
local PASSIVE_INTERVAL = 60   -- secondes entre chaque gain

-- Référence IntValue par userId (pour la mise à jour rapide)
local coinsValues: {[number]: IntValue} = {}

-- ── Création des leaderstats ─────────────────────────────────────────────────
local function createLeaderstats(player: Player): IntValue
    local leaderstats = Instance.new("Folder")
    leaderstats.Name   = "leaderstats"
    leaderstats.Parent = player

    local coins = Instance.new("IntValue")
    coins.Name   = "Brainrot Coins"
    coins.Value  = 0
    coins.Parent = leaderstats

    coinsValues[player.UserId] = coins
    return coins
end

-- ── Synchronise la valeur leaderstats depuis le cache DataManager ────────────
local function syncCoins(player: Player)
    local coinsVal = coinsValues[player.UserId]
    if not coinsVal then return end
    local data = DataManager.GetData(player)
    if data then
        coinsVal.Value = data.Stats.Gold
    end
end

-- ── Connexion joueur ─────────────────────────────────────────────────────────
local Events           = ReplicatedStorage:WaitForChild("Events")
local UpdateClientData = Events:WaitForChild("UpdateClientData")

local function onPlayerAdded(player: Player)
    local coinsVal = createLeaderstats(player)

    -- Attend que DataManager charge les données (max 10 s)
    for _ = 1, 20 do
        local data = DataManager.GetData(player)
        if data then
            coinsVal.Value = data.Stats.Gold
            break
        end
        task.wait(0.5)
    end
end

local function onPlayerRemoving(player: Player)
    coinsValues[player.UserId] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, p in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, p)
end

-- ── Revenu passif : +PASSIVE_AMOUNT coins toutes les PASSIVE_INTERVAL s ─────
task.spawn(function()
    while true do
        task.wait(PASSIVE_INTERVAL)
        for _, player in ipairs(Players:GetPlayers()) do
            local data = DataManager.GetData(player)
            if data then
                DataManager.AddGold(player, PASSIVE_AMOUNT)
                syncCoins(player)
                -- Notifie le client (HUD)
                local updated = DataManager.GetData(player)
                if updated then
                    UpdateClientData:FireClient(player, updated)
                end
                print(string.format("[EconomyManager] +%d Brainrot Coins → %s (total : %d)",
                    PASSIVE_AMOUNT, player.Name, data.Stats.Gold))
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

print(string.format("[EconomyManager] Revenu passif actif : +%d Coins toutes les %ds",
    PASSIVE_AMOUNT, PASSIVE_INTERVAL))

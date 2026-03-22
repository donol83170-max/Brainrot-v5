-- DataManager.lua
-- Gère la sauvegarde et le chargement des données (Gold, XP, Inventaire)

local DataManager = {}

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Constants"))

local DATASTORE_NAME = "Brainrot_v3" -- v3 : 10 000 Gold de départ
local playerDataStore

-- Protection contre les erreurs si l'API n'est pas activée dans Studio
local success, err = pcall(function()
	playerDataStore = DataStoreService:GetDataStore(DATASTORE_NAME)
end)

if not success then
	warn("⚠️ [DataManager] Impossible d'accéder au DataStore. API désactivée ? " .. tostring(err))
end

local playerCache = {}

-- Fonction pour obtenir les données par défaut
function DataManager.CreateDefaultData()
    return {
        Stats = {
            Gold = Constants.STARTING_STATS.GOLD,
            XP = Constants.STARTING_STATS.XP,
            Level = 1,
            Tickets = Constants.STARTING_STATS.TICKETS,
            TotalPower = 0,
        },
        Inventory = {},
        Collection = {}
    }
end

-- Charger les données
function DataManager.LoadData(player)
    if not playerDataStore then 
		playerCache[player.UserId] = DataManager.CreateDefaultData()
		warn("📡 [DataManager] Mode hors-ligne pour " .. player.Name)
		return 
	end

    local success, data = pcall(function()
        return playerDataStore:GetAsync(tostring(player.UserId))
    end)

    if success then
        local loaded = data or DataManager.CreateDefaultData()
        -- Migration : ajouter TotalPower si absent (anciennes sauvegardes)
        if loaded.Stats and loaded.Stats.TotalPower == nil then
            loaded.Stats.TotalPower = 0
        end
        playerCache[player.UserId] = loaded
        print("💾 Données chargées pour " .. player.Name)
    else
        warn("❌ Erreur DataStore (Load) pour " .. player.Name .. ": " .. tostring(data))
        playerCache[player.UserId] = DataManager.CreateDefaultData() -- Backup par défaut en cas d'erreur
    end
end

-- Sauvegarder les données
function DataManager.SaveData(player)
    local data = playerCache[player.UserId]
    if not data or not playerDataStore then return end

    local success, err = pcall(function()
        playerDataStore:SetAsync(tostring(player.UserId), data)
    end)

    if success then
        print("💾 Données sauvegardées pour " .. player.Name)
    else
        warn("❌ ÉCHEC SAUVEGARDE pour " .. player.Name .. ": " .. tostring(err))
    end
end

-- Getters
function DataManager.GetData(player)
    return playerCache[player.UserId]
end

-- Update Gold
function DataManager.AddGold(player, amount)
    local data = playerCache[player.UserId]
    if data then
        data.Stats.Gold += amount
    end
end

-- Update Power (accumulé depuis les plaques de récolte)
function DataManager.AddPower(player, amount)
    local data = playerCache[player.UserId]
    if data then
        data.Stats.TotalPower = (data.Stats.TotalPower or 0) + amount
    end
end

function DataManager.GetPower(player)
    local data = playerCache[player.UserId]
    return data and (data.Stats.TotalPower or 0) or 0
end

-- Ajouter un item à l'inventaire
function DataManager.AddItem(player, item)
	local data = playerCache[player.UserId]
	if not data then return end

	-- On utilise l'ID de l'item comme clé
	if not data.Inventory[item.Id] then
		data.Inventory[item.Id] = {
			Id = item.Id,
			Name = item.Name,
			Rarity = item.Rarity,
			Count = 1
		}
	else
		data.Inventory[item.Id].Count += 1
	end

	-- Ajouter à la collection si c'est la première fois
	data.Collection[item.Id] = true

	print("🎒 [Inventory] " .. player.Name .. " a reçu : " .. item.Name)
end

-- Dépenser des tickets
function DataManager.SpendTicket(player, amount)
    amount = amount or 1
    local data = playerCache[player.UserId]
    if not data then return false end
    if data.Stats.Tickets < amount then return false end
    data.Stats.Tickets -= amount
    return true
end

-- Dépenser de l'Or
function DataManager.SpendGold(player, amount)
    local data = playerCache[player.UserId]
    if not data then return false end
    if data.Stats.Gold < amount then return false end
    data.Stats.Gold -= amount
    return true
end

-- Retirer un item
function DataManager.RemoveItem(player, itemId)
	local data = playerCache[player.UserId]
	if not data or not data.Inventory[itemId] then return false end

	data.Inventory[itemId].Count -= 1
	if data.Inventory[itemId].Count <= 0 then
		data.Inventory[itemId] = nil
	end

	return true
end

-- Cleanup on leave
function DataManager.ClearCache(player)
    playerCache[player.UserId] = nil
end

return DataManager

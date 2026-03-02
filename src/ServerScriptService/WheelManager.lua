-- WheelManager.lua
-- Calcule les résultats des spins et gère les récompenses

local WheelManager = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage:WaitForChild("Constants"))
local LootTables = require(ReplicatedStorage:WaitForChild("LootTables"))
local DataManager = require(ServerScriptService:WaitForChild("DataManager"))

-- Fonction pour choisir une rareté selon les poids
local function pickRarity()
    local roll = math.random(1, 1000) / 10 -- Supporte les décimales (ex: 2%)
    local cumulative = 0

    local sortedRarities = {
        Constants.RARITIES.NORMAL,
        Constants.RARITIES.RARE,
        Constants.RARITIES.MYTHIC,
        Constants.RARITIES.LEGENDARY,
        Constants.RARITIES.ULTRA
    }

    for _, rarity in ipairs(sortedRarities) do
        cumulative += rarity.Weight
        if roll <= cumulative then
            return rarity.Name
        end
    end
    return "NORMAL"
end

-- Spin une roue spécifique
function WheelManager.Spin(player, wheelId, retryCount)
    retryCount = retryCount or 0
    if retryCount > 5 then
        warn("⚠️ [WheelManager] Trop de tentatives de spin, retour d'un item par défaut.")
        return LootTables.Wheels[1].Items[1]
    end

    local wheel = LootTables.Wheels[wheelId]
    if not wheel then 
        warn("⚠️ [WheelManager] Roue ID " .. tostring(wheelId) .. " non trouvée.")
        return nil 
    end

    local chosenRarityName = pickRarity()
    print("🎯 [Spin] Rareté choisie : " .. tostring(chosenRarityName))

    -- Filtrer les items de la roue par cette rareté
    local possibleItems = {}
    for _, item in ipairs(wheel.Items) do
        if string.upper(item.Rarity) == string.upper(chosenRarityName) then
            table.insert(possibleItems, item)
        end
    end

    -- Si aucun item (erreur config), on réessaie
    if #possibleItems == 0 then
        warn("⚠️ [WheelManager] Aucun item trouvé pour la rareté : " .. tostring(chosenRarityName))
        return WheelManager.Spin(player, wheelId, retryCount + 1)
    end

    local finalItem = possibleItems[math.random(1, #possibleItems)]

    -- Ajouter à l'inventaire via DataManager
    DataManager.AddItem(player, finalItem)

    print("🎰 " .. player.Name .. " a gagné : " .. finalItem.Name .. " (" .. finalItem.Rarity .. ")")
    return finalItem
end

return WheelManager

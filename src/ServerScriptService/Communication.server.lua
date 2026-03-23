-- Communication.server.lua
-- Gère uniquement les RemoteEvents non-liés aux roues (données joueur, vente).
-- Le système de spin sera câblé dans le nouveau script de roues.

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataManager = require(ServerScriptService:WaitForChild("DataManager"))
local Constants   = require(ReplicatedStorage:WaitForChild("Constants"))

-- Dossier Events
local EventsFolder = ReplicatedStorage:FindFirstChild("Events") or Instance.new("Folder")
EventsFolder.Name   = "Events"
EventsFolder.Parent = ReplicatedStorage

local function getOrCreate(name, className)
    local obj = EventsFolder:FindFirstChild(name)
    if not obj then
        obj        = Instance.new(className)
        obj.Name   = name
        obj.Parent = EventsFolder
    end
    return obj
end

local UpdateClientData = getOrCreate("UpdateClientData",  "RemoteEvent")
local SellRequest      = getOrCreate("SellRequest",       "RemoteEvent")
local SellResult       = getOrCreate("SellResult",        "RemoteEvent")
local SellAllRequest   = getOrCreate("SellAllRequest",    "RemoteEvent")
local SellAllResult    = getOrCreate("SellAllResult",     "RemoteEvent")
-- Réservés pour le futur système de roues (créés ici pour que les clients ne crashent pas)
getOrCreate("SpinRequest",    "RemoteEvent")
getOrCreate("SpinResult",     "RemoteEvent")
getOrCreate("HarvestResult",  "RemoteEvent")

local GetPlayerData    = getOrCreate("GetPlayerData", "RemoteFunction")

-- ── Fournit les données complètes au client ────────────────────────────────────
GetPlayerData.OnServerInvoke = function(player)
    return DataManager.GetData(player)
end

-- ── Vente d'un item ────────────────────────────────────────────────────────────
SellRequest.OnServerEvent:Connect(function(player, itemId)
    -- Bloquer la vente si l'item est actuellement déposé dans la machine à échange
    if _G.IsItemInTrade and _G.IsItemInTrade(player, itemId) then
        warn(string.format("[Communication] %s tente de vendre '%s' mais il est en trade — bloqué",
            player.Name, tostring(itemId)))
        return
    end

    local data = DataManager.GetData(player)
    if not data or not data.Inventory[itemId] then return end

    local item      = data.Inventory[itemId]
    local sellValue = Constants.SELL_VALUES[string.upper(item.Rarity)] or 0

    DataManager.RemoveItem(player, itemId)
    DataManager.AddGold(player, sellValue)

    print(string.format("[Communication] %s a vendu %s pour %d Coins",
        player.Name, item.Name, sellValue))

    local updatedData = DataManager.GetData(player)
    if updatedData then
        UpdateClientData:FireClient(player, updatedData)
        SellResult:FireClient(player, itemId, sellValue)
    end
end)

-- ── Vente groupée (Zone de Vente, touche V) ────────────────────────────────────
SellAllRequest.OnServerEvent:Connect(function(player)
    local data = DataManager.GetData(player)
    if not data or not data.Inventory then return end

    -- Collecter les items à vendre (copie pour éviter de modifier en cours d'itération)
    local toSell = {}
    for itemId, item in pairs(data.Inventory) do
        if item.Count and item.Count > 0 then
            table.insert(toSell, { id = itemId, rarity = item.Rarity, count = item.Count, name = item.Name })
        end
    end

    if #toSell == 0 then
        SellAllResult:FireClient(player, 0, 0)
        return
    end

    local totalGold = 0
    local totalItems = 0
    for _, entry in ipairs(toSell) do
        local value = Constants.SELL_VALUES[string.upper(entry.rarity)] or 0
        -- Retirer toutes les copies de cet item
        for _ = 1, entry.count do
            DataManager.RemoveItem(player, entry.id)
        end
        DataManager.AddGold(player, value * entry.count)
        totalGold  += value * entry.count
        totalItems += entry.count
    end

    print(string.format("[Communication] %s a tout vendu : %d items → +%d Coins",
        player.Name, totalItems, totalGold))

    local updated = DataManager.GetData(player)
    if updated then UpdateClientData:FireClient(player, updated) end
    SellAllResult:FireClient(player, totalItems, totalGold)
end)

print("[Communication] Pret (vente, données joueur, events)")

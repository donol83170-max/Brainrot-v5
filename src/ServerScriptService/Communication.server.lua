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

print("[Communication] Pret (spin desactive — en attente du nouveau systeme)")

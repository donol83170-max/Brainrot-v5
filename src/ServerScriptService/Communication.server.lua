-- Communication.server.lua
print("🚀 [Communication] DÉMARRAGE DU SCRIPT")
-- Initialise les RemoteEvents dans ReplicatedStorage

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Dossier pour les events
local EventsFolder = ReplicatedStorage:FindFirstChild("Events") or Instance.new("Folder", ReplicatedStorage)
EventsFolder.Name = "Events"

-- Création des events si ils n'existent pas
local function getOrCreateEvent(name)
	local event = EventsFolder:FindFirstChild(name)
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = EventsFolder
	end
	return event
end

local SpinRequest = getOrCreateEvent("SpinRequest")
local SpinResult = getOrCreateEvent("SpinResult")
local UpdateClientData = getOrCreateEvent("UpdateClientData")
local SellRequest = getOrCreateEvent("SellRequest")
local SellResult = getOrCreateEvent("SellResult")

local GetPlayerData = EventsFolder:FindFirstChild("GetPlayerData") or Instance.new("RemoteFunction")
GetPlayerData.Name = "GetPlayerData"
GetPlayerData.Parent = EventsFolder

-- Liaison avec le WheelManager et DataManager
local WheelManager = require(ServerScriptService:WaitForChild("WheelManager"))
local DataManager = require(ServerScriptService:WaitForChild("DataManager"))
local Constants = require(ReplicatedStorage:WaitForChild("Constants"))

-- Cooldown tracking
local lastSpinTime = {}

SpinRequest.OnServerEvent:Connect(function(player, wheelId)
	print("📡 [Server] Requête de spin reçue de " .. player.Name)

	-- Cooldown check
	local now = tick()
	local lastSpin = lastSpinTime[player.UserId] or 0
	if (now - lastSpin) < Constants.COOLDOWNS.FREE_SPIN then
		local remaining = math.ceil(Constants.COOLDOWNS.FREE_SPIN - (now - lastSpin))
		print("⏱️ [Server] Cooldown actif pour " .. player.Name .. " (" .. remaining .. "s restantes)")
		return
	end

	-- Ticket check
	if not DataManager.SpendTicket(player) then
		print("🎟️ [Server] Pas assez de tickets pour " .. player.Name)
		return
	end

	lastSpinTime[player.UserId] = now

	local result = WheelManager.Spin(player, wheelId or 1)
	if result then
		print("🎰 [Server] Envoi du résultat à " .. player.Name .. " : " .. result.Name)
		SpinResult:FireClient(player, result)
		-- Sync les données complètes vers le client
		local data = DataManager.GetData(player)
		if data then
			UpdateClientData:FireClient(player, data)
		end
	else
		print("⚠️ [Server] Erreur lors du spin pour " .. player.Name)
	end
end)

-- Fournit les données complètes du joueur au client (appelé au démarrage)
GetPlayerData.OnServerInvoke = function(player)
	return DataManager.GetData(player)
end

-- Vente d'un item
SellRequest.OnServerEvent:Connect(function(player, itemId)
	local data = DataManager.GetData(player)
	if not data or not data.Inventory[itemId] then return end

	local item = data.Inventory[itemId]
	local sellValue = Constants.SELL_VALUES[string.upper(item.Rarity)] or 0

	DataManager.RemoveItem(player, itemId)
	DataManager.AddGold(player, sellValue)

	print("💰 [Server] " .. player.Name .. " a vendu " .. item.Name .. " pour " .. sellValue .. " gold")

	local updatedData = DataManager.GetData(player)
	if updatedData then
		UpdateClientData:FireClient(player, updatedData)
		SellResult:FireClient(player, itemId, sellValue)
	end
end)

print("📡 [Communication] RemoteEvents prêts !")

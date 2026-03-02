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

-- Liaison avec le WheelManager
local WheelManager = require(ServerScriptService:WaitForChild("WheelManager"))

SpinRequest.OnServerEvent:Connect(function(player, wheelId)
	print("📡 [Server] Requête de spin reçue de " .. player.Name)
	-- Sécurité
	-- TODO: Cooldown check
	
	local result = WheelManager.Spin(player, wheelId or 1)
	if result then
		print("🎰 [Server] Envoi du résultat à " .. player.Name .. " : " .. result.Name)
		SpinResult:FireClient(player, result)
	else
		print("⚠️ [Server] Erreur lors du spin pour " .. player.Name)
	end
end)

print("📡 [Communication] RemoteEvents prêts !")

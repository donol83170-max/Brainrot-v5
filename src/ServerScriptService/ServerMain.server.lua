-- Init.server.lua
-- Point d'entrée principal du serveur pour 'Wheel a Brainrot'

print("-----------------------------------------")
print("🔥 [Init] SERVEUR EN COURS D'EXECUTION")
print("-----------------------------------------")

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Modules
local DataManager = require(ServerScriptService:WaitForChild("DataManager"))

-- Initialisation des systèmes
local function onPlayerAdded(player)
    print("Welcome to Brainrot, " .. player.Name .. "!")
    DataManager.LoadData(player)
    
    -- Augmente la vitesse (Vitesse de base = 16, x2 = 32)
    player.CharacterAdded:Connect(function(character)
        local humanoid = character:WaitForChild("Humanoid") :: Humanoid
        humanoid.WalkSpeed = 32
    end)
end

local function onPlayerRemoving(player)
    DataManager.SaveData(player)
    DataManager.ClearCache(player)
end

game.Players.PlayerAdded:Connect(onPlayerAdded)
game.Players.PlayerRemoving:Connect(onPlayerRemoving)

-- BindToClose pour sauvegarder si le serveur ferme
game:BindToClose(function()
    for _, player in ipairs(game.Players:GetPlayers()) do
        DataManager.SaveData(player)
    end
end)

print("✅ [Wheel a Brainrot] Serveur prêt !")

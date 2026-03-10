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
    
    -- Vitesse : spawn à 16, crescendo sur 3s jusqu'à +80% du défaut (28.8)
    player.CharacterAdded:Connect(function(character)
        local humanoid = character:WaitForChild("Humanoid") :: Humanoid
        local START_SPEED  = 32
        local TARGET_SPEED = 48
        local DURATION     = 3      -- secondes
        humanoid.WalkSpeed = START_SPEED
        task.spawn(function()
            local elapsed = 0
            local STEP    = 0.05
            while elapsed < DURATION do
                task.wait(STEP)
                elapsed += STEP
                local t = math.min(elapsed / DURATION, 1)
                if not humanoid or not humanoid.Parent then return end
                humanoid.WalkSpeed = START_SPEED + (TARGET_SPEED - START_SPEED) * t
            end
            humanoid.WalkSpeed = TARGET_SPEED
        end)
    end)
end

local function onPlayerRemoving(player)
    DataManager.SaveData(player)
    DataManager.ClearCache(player)
end

game.Players.PlayerAdded:Connect(onPlayerAdded)
game.Players.PlayerRemoving:Connect(onPlayerRemoving)

-- BindToClose : sauvegardes en parallèle, on attend qu'elles se terminent
game:BindToClose(function()
    local pending = 0
    for _, player in ipairs(game.Players:GetPlayers()) do
        pending += 1
        task.spawn(function()
            DataManager.SaveData(player)
            pending -= 1
        end)
    end
    local deadline = tick() + 25
    repeat task.wait(0.1) until pending == 0 or tick() > deadline
end)

-- Auto-sauvegarde périodique toutes les 60 s
-- (protège contre les arrêts brusques en Studio ou les crashs serveur)
task.spawn(function()
    while true do
        task.wait(60)
        for _, player in ipairs(game.Players:GetPlayers()) do
            task.spawn(function() DataManager.SaveData(player) end)
        end
    end
end)

print("✅ [Wheel a Brainrot] Serveur prêt !")

-- HUDController.client.lua
-- Affiche les stats du joueur en temps réel (Gold, Tickets)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Events = ReplicatedStorage:WaitForChild("Events")

local UpdateClientData = Events:WaitForChild("UpdateClientData")
local GetPlayerData = Events:WaitForChild("GetPlayerData")

-- Construction du HUD
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Name = "StatsFrame"
frame.Size = UDim2.new(0, 220, 0, 90)
frame.Position = UDim2.new(0, 20, 0, 20)
frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
frame.BackgroundTransparency = 0.25
frame.BorderSizePixel = 0
frame.Parent = screenGui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

local goldLabel = Instance.new("TextLabel")
goldLabel.Name = "GoldLabel"
goldLabel.Size = UDim2.new(1, -20, 0, 38)
goldLabel.Position = UDim2.new(0, 10, 0, 8)
goldLabel.BackgroundTransparency = 1
goldLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
goldLabel.Font = Enum.Font.GothamBold
goldLabel.TextSize = 22
goldLabel.TextXAlignment = Enum.TextXAlignment.Left
goldLabel.Text = "💰  0"
goldLabel.Parent = frame

local ticketLabel = Instance.new("TextLabel")
ticketLabel.Name = "TicketLabel"
ticketLabel.Size = UDim2.new(1, -20, 0, 38)
ticketLabel.Position = UDim2.new(0, 10, 0, 46)
ticketLabel.BackgroundTransparency = 1
ticketLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
ticketLabel.Font = Enum.Font.GothamBold
ticketLabel.TextSize = 22
ticketLabel.TextXAlignment = Enum.TextXAlignment.Left
ticketLabel.Text = "🎟️  ..."
ticketLabel.Parent = frame

local function refreshHUD(data)
	if not data or not data.Stats then return end
	goldLabel.Text = "💰  " .. tostring(data.Stats.Gold)
	ticketLabel.Text = "🎟️  " .. tostring(data.Stats.Tickets)
end

-- Chargement initial
task.spawn(function()
	local data = GetPlayerData:InvokeServer()
	refreshHUD(data)
end)

-- Mise à jour en temps réel
UpdateClientData.OnClientEvent:Connect(function(data)
	refreshHUD(data)
end)

print("🖥️ [HUD] Prêt !")

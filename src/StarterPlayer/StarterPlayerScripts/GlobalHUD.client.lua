-- GlobalHUD.client.lua
-- Gère l'affichage permanent des stats du joueur (Or, Tickets, Niveau)
print("💻 [GlobalHUD] Initialisation de l'interface principale...")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Events = ReplicatedStorage:WaitForChild("Events")

local UpdateClientData = Events:WaitForChild("UpdateClientData")
local GetPlayerData = Events:WaitForChild("GetPlayerData")

-- Création du ScreenGui principal
local hudScreen = Instance.new("ScreenGui")
hudScreen.Name = "GlobalHUD"
hudScreen.ResetOnSpawn = false
hudScreen.IgnoreGuiInset = true
hudScreen.Parent = playerGui

-- == 1. CONTENEUR TOP DROITE (MONNAIES) ==
local currencyContainer = Instance.new("Frame")
currencyContainer.Name = "CurrencyContainer"
currencyContainer.Size = UDim2.new(0, 300, 0, 120)
currencyContainer.Position = UDim2.new(1, -320, 0, 20)
currencyContainer.BackgroundTransparency = 1
currencyContainer.Parent = hudScreen

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 10)
layout.Parent = currencyContainer

-- Fonction utilitaire pour créer des "Pill" design (arrondis)
local function createPill(name, color, iconText, defaultAmount, order)
    local pill = Instance.new("Frame")
    pill.Name = name
    pill.Size = UDim2.new(0, 200, 0, 40)
    pill.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    pill.LayoutOrder = order
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0)
    corner.Parent = pill
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = 2
    stroke.Parent = pill
    
    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(0, 40, 1, 0)
    icon.BackgroundTransparency = 1
    icon.Text = iconText
    icon.TextSize = 24
    icon.Parent = pill
    
    local amount = Instance.new("TextLabel")
    amount.Name = "Amount"
    amount.Size = UDim2.new(1, -50, 1, 0)
    amount.Position = UDim2.new(0, 40, 0, 0)
    amount.BackgroundTransparency = 1
    amount.Text = tostring(defaultAmount)
    amount.TextColor3 = Color3.new(1, 1, 1)
    amount.Font = Enum.Font.GothamBold
    amount.TextSize = 20
    amount.TextXAlignment = Enum.TextXAlignment.Right
    amount.Parent = pill
    
    return pill
end

local goldPill = createPill("GoldPill", Color3.fromRGB(255, 215, 0), "💰", 0, 1)
goldPill.Parent = currencyContainer

local ticketPill = createPill("TicketPill", Color3.fromRGB(0, 255, 150), "🎟️", 5, 2)
ticketPill.Parent = currencyContainer

-- == 2. BOUTON INVENTAIRE (BAS CENTRE) ==
local invButton = Instance.new("TextButton")
invButton.Name = "InventoryButton"
invButton.Size = UDim2.new(0, 250, 0, 60)
invButton.Position = UDim2.new(0.5, -125, 1, -80)
invButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
invButton.Text = "🎒 INVENTAIRE"
invButton.TextColor3 = Color3.new(1, 1, 1)
invButton.Font = Enum.Font.GothamBlack
invButton.TextSize = 24
invButton.Parent = hudScreen

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0.2, 0)
btnCorner.Parent = invButton

-- Effet de Hover sur le bouton
invButton.MouseEnter:Connect(function()
    TweenService:Create(invButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(0, 180, 255), Size = UDim2.new(0, 260, 0, 65), Position = UDim2.new(0.5, -130, 1, -82)}):Play()
end)

invButton.MouseLeave:Connect(function()
    TweenService:Create(invButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(0, 150, 255), Size = UDim2.new(0, 250, 0, 60), Position = UDim2.new(0.5, -125, 1, -80)}):Play()
end)

local function refreshHUD(data)
    if not data or not data.Stats then return end
    if goldPill:FindFirstChild("Amount") then
        goldPill.Amount.Text = tostring(data.Stats.Gold)
    end
    if ticketPill:FindFirstChild("Amount") then
        ticketPill.Amount.Text = tostring(data.Stats.Tickets)
    end
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

print("💻 [GlobalHUD] Interface HUD générée avec succès !")

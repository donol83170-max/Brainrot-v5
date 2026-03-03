-- InventoryController.client.lua
-- Grille d'inventaire avec vente d'items (touche E pour ouvrir/fermer)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Events = ReplicatedStorage:WaitForChild("Events")
local Constants = require(ReplicatedStorage:WaitForChild("Constants"))

local UpdateClientData = Events:WaitForChild("UpdateClientData")
local GetPlayerData = Events:WaitForChild("GetPlayerData")
local SellRequest = Events:WaitForChild("SellRequest")
local SellResult = Events:WaitForChild("SellResult")

local inventory = {} -- cache local des items

-- ========== CONSTRUCTION UI ==========

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "InventoryUI"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.Parent = playerGui

-- Fond sombre
local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.new(1, 0, 1, 0)
backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
backdrop.BackgroundTransparency = 0.5
backdrop.BorderSizePixel = 0
backdrop.Parent = screenGui

-- Fenêtre principale
local window = Instance.new("Frame")
window.Name = "Window"
window.Size = UDim2.new(0, 680, 0, 520)
window.Position = UDim2.new(0.5, -340, 0.5, -260)
window.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
window.BorderSizePixel = 0
window.Parent = screenGui
Instance.new("UICorner", window).CornerRadius = UDim.new(0, 16)

-- Titre
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 50)
title.Position = UDim2.new(0, 20, 0, 0)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBlack
title.TextSize = 28
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "🎒 INVENTAIRE"
title.Parent = window

-- Indication fermeture
local closeHint = Instance.new("TextLabel")
closeHint.Size = UDim2.new(0, 100, 0, 50)
closeHint.Position = UDim2.new(1, -120, 0, 0)
closeHint.BackgroundTransparency = 1
closeHint.TextColor3 = Color3.fromRGB(130, 130, 150)
closeHint.Font = Enum.Font.Gotham
closeHint.TextSize = 16
closeHint.Text = "[E] Fermer"
closeHint.Parent = window

-- Séparateur
local divider = Instance.new("Frame")
divider.Size = UDim2.new(1, -40, 0, 2)
divider.Position = UDim2.new(0, 20, 0, 52)
divider.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
divider.BorderSizePixel = 0
divider.Parent = window

-- ScrollingFrame pour les items
local scroll = Instance.new("ScrollingFrame")
scroll.Name = "ItemList"
scroll.Size = UDim2.new(1, -40, 1, -80)
scroll.Position = UDim2.new(0, 20, 0, 62)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 6
scroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0) -- mis à jour dynamiquement
scroll.Parent = window

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.Name
listLayout.Padding = UDim.new(0, 6)
listLayout.Parent = scroll

-- ========== RENDU DES ITEMS ==========

local RARITY_ORDER = { ULTRA = 1, LEGENDARY = 2, MYTHIC = 3, RARE = 4, NORMAL = 5 }

local function buildItemRow(itemId, item)
	local rarityInfo = Constants.RARITIES[string.upper(item.Rarity)] or Constants.RARITIES.NORMAL
	local sellValue = Constants.SELL_VALUES[string.upper(item.Rarity)] or 0

	local row = Instance.new("Frame")
	row.Name = string.format("%d_%s", RARITY_ORDER[string.upper(item.Rarity)] or 9, itemId)
	row.Size = UDim2.new(1, 0, 0, 56)
	row.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
	row.BorderSizePixel = 0
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

	-- Barre de couleur rareté
	local colorBar = Instance.new("Frame")
	colorBar.Size = UDim2.new(0, 5, 1, 0)
	colorBar.BackgroundColor3 = rarityInfo.Color
	colorBar.BorderSizePixel = 0
	colorBar.Parent = row
	Instance.new("UICorner", colorBar).CornerRadius = UDim.new(0, 4)

	-- Nom de l'item
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0.45, 0, 1, 0)
	nameLabel.Position = UDim2.new(0, 18, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 18
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = item.Name
	nameLabel.Parent = row

	-- Rareté
	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Size = UDim2.new(0.2, 0, 1, 0)
	rarityLabel.Position = UDim2.new(0.45, 0, 0, 0)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.TextColor3 = rarityInfo.Color
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.TextSize = 15
	rarityLabel.Text = string.upper(item.Rarity)
	rarityLabel.Parent = row

	-- Quantité
	local countLabel = Instance.new("TextLabel")
	countLabel.Size = UDim2.new(0.1, 0, 1, 0)
	countLabel.Position = UDim2.new(0.65, 0, 0, 0)
	countLabel.BackgroundTransparency = 1
	countLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
	countLabel.Font = Enum.Font.Gotham
	countLabel.TextSize = 16
	countLabel.Text = "x" .. tostring(item.Count)
	countLabel.Parent = row

	-- Bouton vendre
	local sellBtn = Instance.new("TextButton")
	sellBtn.Size = UDim2.new(0, 130, 0, 36)
	sellBtn.Position = UDim2.new(1, -145, 0.5, -18)
	sellBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
	sellBtn.TextColor3 = Color3.new(1, 1, 1)
	sellBtn.Font = Enum.Font.GothamBold
	sellBtn.TextSize = 15
	sellBtn.Text = "Vendre  💰 " .. tostring(sellValue)
	sellBtn.BorderSizePixel = 0
	sellBtn.Parent = row
	Instance.new("UICorner", sellBtn).CornerRadius = UDim.new(0, 8)

	sellBtn.MouseButton1Click:Connect(function()
		sellBtn.Active = false
		sellBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		sellBtn.Text = "..."
		SellRequest:FireServer(itemId)
	end)

	return row
end

local function refreshInventory()
	-- Supprimer les anciens rows
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	local count = 0
	for itemId, item in pairs(inventory) do
		if item.Count and item.Count > 0 then
			local row = buildItemRow(itemId, item)
			row.Parent = scroll
			count += 1
		end
	end

	-- Ajuster la taille du canvas
	scroll.CanvasSize = UDim2.new(0, 0, 0, count * 62)

	-- Message si vide
	if count == 0 then
		local emptyLabel = Instance.new("TextLabel")
		emptyLabel.Size = UDim2.new(1, 0, 0, 60)
		emptyLabel.BackgroundTransparency = 1
		emptyLabel.TextColor3 = Color3.fromRGB(120, 120, 140)
		emptyLabel.Font = Enum.Font.Gotham
		emptyLabel.TextSize = 18
		emptyLabel.Text = "Aucun item. Lance la roue !"
		emptyLabel.Parent = scroll
	end
end

-- ========== TOGGLE INVENTAIRE ==========

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.E then
		screenGui.Enabled = not screenGui.Enabled
		if screenGui.Enabled then
			refreshInventory()
		end
	end
end)

-- ========== SYNCHRONISATION DONNÉES ==========

local function applyData(data)
	if not data or not data.Inventory then return end
	inventory = data.Inventory
	if screenGui.Enabled then
		refreshInventory()
	end
end

-- Chargement initial
task.spawn(function()
	local data = GetPlayerData:InvokeServer()
	applyData(data)
end)

-- Mises à jour serveur (après spin ou vente)
UpdateClientData.OnClientEvent:Connect(function(data)
	applyData(data)
end)

-- Retour de vente : refresh immédiat si fenêtre ouverte
SellResult.OnClientEvent:Connect(function(itemId, goldEarned)
	print("💰 [Inventaire] Vendu pour " .. tostring(goldEarned) .. " gold")
	if screenGui.Enabled then
		refreshInventory()
	end
end)

print("🎒 [InventoryController] Prêt !")

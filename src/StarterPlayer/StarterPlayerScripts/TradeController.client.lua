-- TradeController.client.lua
-- Interface client de la Machine à Échange + VFX Légendaire.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Events        = ReplicatedStorage:WaitForChild("Events")
local TradeJoin     = Events:WaitForChild("TradeJoin")
local TradeDeposit  = Events:WaitForChild("TradeDeposit")
local TradeConfirm  = Events:WaitForChild("TradeConfirm")
local TradeCancel   = Events:WaitForChild("TradeCancel")
local TradeUpdate   = Events:WaitForChild("TradeUpdate")
local TradeResult   = Events:WaitForChild("TradeResult")
local LegendaryDrop = Events:WaitForChild("LegendaryDrop")
local GetPlayerData = Events:WaitForChild("GetPlayerData")

local mySlot   = nil :: string?   -- "A" ou "B"
local inventory = {} :: {[string]: any}

-- ══════════════════════════════════════════════════════════════════════════════
-- VFX LÉGENDAIRE — déclenché par le serveur pour tout le monde
-- ══════════════════════════════════════════════════════════════════════════════
LegendaryDrop.OnClientEvent:Connect(function(winner: Player, itemName: string)
    -- Message doré dans le chat
    local ok = pcall(function()
        game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", {
            Text     = "★ " .. winner.Name .. " a obtenu le LÉGENDAIRE [" .. itemName .. "] ! ★",
            Color    = Color3.fromRGB(255, 215, 0),
            Font     = Enum.Font.GothamBlack,
            TextSize = 18,
        })
    end)
    if not ok then
        warn("[TradeController] ChatMakeSystemMessage non disponible")
    end

    -- Particules dorées sur le personnage du gagnant
    local char = winner.Character or winner.CharacterAdded:Wait()
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Lueur de fond (PointLight temporaire)
    local light = Instance.new("PointLight")
    light.Brightness = 5
    light.Range      = 20
    light.Color      = Color3.fromRGB(255, 215, 0)
    light.Parent     = hrp

    -- ParticleEmitter — explosion de paillettes dorées
    local emitter = Instance.new("ParticleEmitter")
    emitter.Texture      = "rbxassetid://243160943"
    emitter.Color        = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 100)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 215, 0)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 170, 0)),
    })
    emitter.LightEmission = 1
    emitter.Size         = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1.2),
        NumberSequenceKeypoint.new(1, 0),
    })
    emitter.Speed        = NumberRange.new(18, 40)
    emitter.Lifetime     = NumberRange.new(1.2, 2.5)
    emitter.Rate         = 300
    emitter.Rotation     = NumberRange.new(0, 360)
    emitter.RotSpeed     = NumberRange.new(-200, 200)
    emitter.SpreadAngle  = Vector2.new(70, 70)
    emitter.Acceleration = Vector3.new(0, -10, 0)
    emitter.Parent       = hrp

    -- Burst de 2 secondes puis extinction
    task.delay(2, function()
        emitter.Enabled = false
        TweenService:Create(light, TweenInfo.new(1), { Brightness = 0 }):Play()
        task.delay(1.5, function()
            emitter:Destroy()
            light:Destroy()
        end)
    end)
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- INTERFACE DE TRADE
-- ══════════════════════════════════════════════════════════════════════════════
local tradeGui = Instance.new("ScreenGui")
tradeGui.Name         = "TradeUI"
tradeGui.ResetOnSpawn = false
tradeGui.Enabled      = false
tradeGui.Parent       = playerGui

-- Fenêtre principale
local window = Instance.new("Frame")
window.Name             = "TradeWindow"
window.Size             = UDim2.new(0, 600, 0, 520)
window.AnchorPoint      = Vector2.new(0.5, 0.5)
window.Position         = UDim2.new(0.5, 0, 0.5, 0)
window.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
window.BorderSizePixel  = 0
window.Parent           = tradeGui
Instance.new("UICorner", window).CornerRadius = UDim.new(0, 14)
local wStroke = Instance.new("UIStroke", window)
wStroke.Color     = Color3.fromRGB(255, 215, 0)
wStroke.Thickness = 2

-- Titre
local titleLbl = Instance.new("TextLabel")
titleLbl.Size                   = UDim2.new(1, -20, 0, 48)
titleLbl.Position               = UDim2.new(0, 10, 0, 8)
titleLbl.BackgroundTransparency = 1
titleLbl.Text                   = "⇄  MACHINE À ÉCHANGE"
titleLbl.TextColor3             = Color3.fromRGB(255, 215, 0)
titleLbl.Font                   = Enum.Font.GothamBlack
titleLbl.TextScaled             = true
titleLbl.Parent                 = window

-- Divider
local div = Instance.new("Frame")
div.Size             = UDim2.new(1, -30, 0, 2)
div.Position         = UDim2.new(0, 15, 0, 58)
div.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
div.BorderSizePixel  = 0
div.Parent           = window

-- Statut Joueur A
local panelA = Instance.new("Frame")
panelA.Name             = "PanelA"
panelA.Size             = UDim2.new(0.45, -10, 0, 120)
panelA.Position         = UDim2.new(0, 15, 0, 68)
panelA.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
panelA.BorderSizePixel  = 0
panelA.Parent           = window
Instance.new("UICorner", panelA).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", panelA).Color = Color3.fromRGB(80, 80, 120)

local lblA = Instance.new("TextLabel")
lblA.Name                   = "StatusA"
lblA.Size                   = UDim2.new(1, -10, 1, 0)
lblA.Position               = UDim2.new(0, 5, 0, 0)
lblA.BackgroundTransparency = 1
lblA.Text                   = "JOUEUR A\n—\n(vide)"
lblA.TextColor3             = Color3.new(1,1,1)
lblA.Font                   = Enum.Font.GothamBold
lblA.TextSize               = 16
lblA.TextXAlignment         = Enum.TextXAlignment.Center
lblA.Parent                 = panelA

-- Statut Joueur B
local panelB = Instance.new("Frame")
panelB.Name             = "PanelB"
panelB.Size             = UDim2.new(0.45, -10, 0, 120)
panelB.Position         = UDim2.new(0.55, 0, 0, 68)
panelB.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
panelB.BorderSizePixel  = 0
panelB.Parent           = window
Instance.new("UICorner", panelB).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", panelB).Color = Color3.fromRGB(80, 80, 120)

local lblB = Instance.new("TextLabel")
lblB.Name                   = "StatusB"
lblB.Size                   = UDim2.new(1, -10, 1, 0)
lblB.Position               = UDim2.new(0, 5, 0, 0)
lblB.BackgroundTransparency = 1
lblB.Text                   = "JOUEUR B\n—\n(vide)"
lblB.TextColor3             = Color3.new(1,1,1)
lblB.Font                   = Enum.Font.GothamBold
lblB.TextSize               = 16
lblB.TextXAlignment         = Enum.TextXAlignment.Center
lblB.Parent                 = panelB

-- Sélection d'item (ScrollingFrame)
local selectTitle = Instance.new("TextLabel")
selectTitle.Size                   = UDim2.new(1, -30, 0, 32)
selectTitle.Position               = UDim2.new(0, 15, 0, 200)
selectTitle.BackgroundTransparency = 1
selectTitle.Text                   = "Choisis l'item à proposer :"
selectTitle.TextColor3             = Color3.fromRGB(200, 200, 220)
selectTitle.Font                   = Enum.Font.GothamBold
selectTitle.TextSize               = 18
selectTitle.TextXAlignment         = Enum.TextXAlignment.Left
selectTitle.Parent                 = window

local scroll = Instance.new("ScrollingFrame")
scroll.Name                = "ItemPicker"
scroll.Size                = UDim2.new(1, -30, 0, 200)
scroll.Position            = UDim2.new(0, 15, 0, 234)
scroll.BackgroundColor3    = Color3.fromRGB(18, 18, 26)
scroll.BorderSizePixel     = 0
scroll.ScrollBarThickness  = 5
scroll.ScrollBarImageColor3 = Color3.fromRGB(80,80,100)
scroll.CanvasSize          = UDim2.new(0, 0, 0, 0)
scroll.Parent              = window
Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 8)

local scrollLayout = Instance.new("UIListLayout")
scrollLayout.SortOrder = Enum.SortOrder.Name
scrollLayout.Padding   = UDim.new(0, 4)
scrollLayout.Parent    = scroll

-- Boutons Valider / Annuler
local confirmBtn = Instance.new("TextButton")
confirmBtn.Size             = UDim2.new(0.45, -10, 0, 44)
confirmBtn.Position         = UDim2.new(0, 15, 1, -58)
confirmBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 70)
confirmBtn.Text             = "✓  Valider (levier)"
confirmBtn.TextColor3       = Color3.new(1,1,1)
confirmBtn.Font             = Enum.Font.GothamBlack
confirmBtn.TextSize         = 18
confirmBtn.BorderSizePixel  = 0
confirmBtn.Parent           = window
Instance.new("UICorner", confirmBtn).CornerRadius = UDim.new(0, 8)

local cancelBtn = Instance.new("TextButton")
cancelBtn.Size             = UDim2.new(0.45, -10, 0, 44)
cancelBtn.Position         = UDim2.new(0.55, 0, 1, -58)
cancelBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
cancelBtn.Text             = "✗  Annuler"
cancelBtn.TextColor3       = Color3.new(1,1,1)
cancelBtn.Font             = Enum.Font.GothamBlack
cancelBtn.TextSize         = 18
cancelBtn.BorderSizePixel  = 0
cancelBtn.Parent           = window
Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 8)

local RARITY_COLORS = {
    COMMON    = Color3.fromRGB(  0, 255,   0),
    RARE      = Color3.fromRGB(  0, 130, 255),
    EPIC      = Color3.fromRGB(255,   0, 255),
    LEGENDARY = Color3.fromRGB(255, 215,   0),
}
local function rarityColor(r: string): Color3
    return RARITY_COLORS[string.upper(r or "")] or Color3.fromRGB(160, 160, 160)
end

local selectedItemId: string? = nil

local function buildItemRows()
    for _, c in ipairs(scroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    selectedItemId = nil
    local count = 0
    for itemId, item in pairs(inventory) do
        if (item.Count or 0) > 0 then
            count += 1
            local row = Instance.new("Frame")
            row.Name             = itemId
            row.Size             = UDim2.new(1, 0, 0, 48)
            row.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
            row.BorderSizePixel  = 0
            row.Parent           = scroll
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

            local bar = Instance.new("Frame")
            bar.Size             = UDim2.new(0, 5, 1, 0)
            bar.BackgroundColor3 = rarityColor(item.Rarity or "")
            bar.BorderSizePixel  = 0
            bar.Parent           = row
            Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 4)

            local nameLbl = Instance.new("TextLabel")
            nameLbl.Size                   = UDim2.new(0.55, 0, 1, 0)
            nameLbl.Position               = UDim2.new(0, 14, 0, 0)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Text                   = item.Name or itemId
            nameLbl.TextColor3             = Color3.new(1,1,1)
            nameLbl.Font                   = Enum.Font.GothamBold
            nameLbl.TextSize               = 16
            nameLbl.TextXAlignment         = Enum.TextXAlignment.Left
            nameLbl.Parent                 = row

            local rarLbl = Instance.new("TextLabel")
            rarLbl.Size                   = UDim2.new(0.25, 0, 1, 0)
            rarLbl.Position               = UDim2.new(0.57, 0, 0, 0)
            rarLbl.BackgroundTransparency = 1
            rarLbl.Text                   = string.upper(item.Rarity or "")
            rarLbl.TextColor3             = rarityColor(item.Rarity or "")
            rarLbl.Font                   = Enum.Font.GothamBold
            rarLbl.TextSize               = 14
            rarLbl.Parent                 = row

            local selBtn = Instance.new("TextButton")
            selBtn.Size             = UDim2.new(0, 90, 0, 32)
            selBtn.Position         = UDim2.new(1, -98, 0.5, -16)
            selBtn.BackgroundColor3 = Color3.fromRGB(40, 80, 160)
            selBtn.Text             = "Proposer"
            selBtn.TextColor3       = Color3.new(1,1,1)
            selBtn.Font             = Enum.Font.GothamBold
            selBtn.TextSize         = 14
            selBtn.BorderSizePixel  = 0
            selBtn.Parent           = row
            Instance.new("UICorner", selBtn).CornerRadius = UDim.new(0, 6)

            local capturedId = itemId
            selBtn.MouseButton1Click:Connect(function()
                selectedItemId = capturedId
                -- Highlight sélection
                for _, c2 in ipairs(scroll:GetChildren()) do
                    if c2:IsA("Frame") then
                        c2.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
                    end
                end
                row.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
                TradeDeposit:FireServer(capturedId)
            end)
        end
    end
    scroll.CanvasSize = UDim2.new(0, 0, 0, count * 52)
end

-- ── Mise à jour de l'UI depuis les données serveur ────────────────────────────
local function updatePanels(mySlotLocal: string?, state: any)
    local a = state.slotA
    local b = state.slotB

    -- Panel A
    local textA = "JOUEUR A\n"
    textA = textA .. (a.playerName or "(vide)") .. "\n"
    if a.itemName then textA = textA .. "→ " .. a.itemName end
    if a.confirmed then textA = textA .. "  ✓" end
    lblA.Text       = textA
    panelA.BackgroundColor3 = a.confirmed
        and Color3.fromRGB(20, 50, 25)
        or  Color3.fromRGB(22, 22, 30)

    -- Panel B
    local textB = "JOUEUR B\n"
    textB = textB .. (b.playerName or "(vide)") .. "\n"
    if b.itemName then textB = textB .. "→ " .. b.itemName end
    if b.confirmed then textB = textB .. "  ✓" end
    lblB.Text       = textB
    panelB.BackgroundColor3 = b.confirmed
        and Color3.fromRGB(20, 50, 25)
        or  Color3.fromRGB(22, 22, 30)
end

-- ── Réception des mises à jour serveur ───────────────────────────────────────
TradeUpdate.OnClientEvent:Connect(function(slot: string, state: any)
    mySlot = slot
    tradeGui.Enabled = true
    updatePanels(slot, state)
end)

-- ── Résultat de l'échange ─────────────────────────────────────────────────────
TradeResult.OnClientEvent:Connect(function(success: boolean, message: string)
    tradeGui.Enabled = false
    mySlot           = nil
    selectedItemId   = nil

    -- Notification
    local notifGui = Instance.new("ScreenGui")
    notifGui.Name         = "TradeNotif"
    notifGui.ResetOnSpawn = false
    notifGui.Parent       = playerGui

    local frame = Instance.new("Frame")
    frame.Size             = UDim2.new(0, 380, 0, 60)
    frame.AnchorPoint      = Vector2.new(0.5, 0)
    frame.Position         = UDim2.new(0.5, 0, 0.08, 0)
    frame.BackgroundColor3 = success
        and Color3.fromRGB(0, 140, 60)
        or  Color3.fromRGB(170, 30, 30)
    frame.BorderSizePixel  = 0
    frame.Parent           = notifGui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0.2, 0)

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, -16, 1, 0)
    lbl.Position               = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = (success and "✓ " or "✗ ") .. (message or "")
    lbl.TextColor3             = Color3.new(1,1,1)
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextScaled             = true
    lbl.Parent                 = frame

    frame.Position = UDim2.new(0.5, 0, -0.02, 0)
    TweenService:Create(frame,
        TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, 0, 0.08, 0) }):Play()

    task.delay(3, function()
        if notifGui.Parent then notifGui:Destroy() end
    end)
end)

-- ── Boutons ───────────────────────────────────────────────────────────────────
confirmBtn.MouseButton1Click:Connect(function()
    TradeConfirm:FireServer()
end)

cancelBtn.MouseButton1Click:Connect(function()
    TradeCancel:FireServer()
    tradeGui.Enabled = false
    mySlot           = nil
end)

-- ── Ouvrir l'UI quand le joueur rejoint un compartiment ──────────────────────
-- (déclenché aussi via ClickDetector → handleJoin server → TradeUpdate → client)
-- On expose aussi une fonction pour que d'autres scripts puissent l'ouvrir.

local function openTradeUI()
    -- Rafraîchir l'inventaire local avant affichage
    task.spawn(function()
        local data = GetPlayerData:InvokeServer()
        if data and data.Inventory then
            inventory = data.Inventory
            buildItemRows()
        end
    end)
    tradeGui.Enabled = true
end

-- Synchro inventaire en temps réel
local UpdateClientData = Events:WaitForChild("UpdateClientData")
UpdateClientData.OnClientEvent:Connect(function(data)
    if data and data.Inventory then
        inventory = data.Inventory
        if tradeGui.Enabled then
            buildItemRows()
        end
    end
end)

-- Chargement initial
task.spawn(function()
    local data = GetPlayerData:InvokeServer()
    if data and data.Inventory then
        inventory = data.Inventory
    end
end)

print("[TradeController] Prêt — VFX Légendaire + interface Trade actifs")

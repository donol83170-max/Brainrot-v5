--!strict
-- CarryClient.client.lua  (LocalScript — StarterPlayerScripts)
-- MachineHUD : affiche l'état des 6 socles de la machine casino.
-- Se met à jour via le RemoteEvent "MachineUpdate" (server → client).
--
-- UI :
--   Bandeau centré en haut avec :
--     • 6 pastilles de slot (vert = occupé, gris = vide)
--     • Compteur "X / 6"
--     • Sous-titre d'instruction

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Events        = ReplicatedStorage:WaitForChild("Events")
local MachineUpdate = Events:WaitForChild("MachineUpdate") :: RemoteEvent

-- ── Couleurs par rareté (pour usage futur si on envoie les items complets) ──
local RARITY_COLORS = {
    COMMON          = Color3.fromRGB(  0, 230,  80),
    RARE            = Color3.fromRGB( 80, 160, 255),
    EPIC            = Color3.fromRGB(200,   0, 255),
    LEGENDARY       = Color3.fromRGB(255, 210,   0),
    ULTRA_LEGENDARY = Color3.fromRGB(255,  60,  60),
}

-- ── Constantes de slots ───────────────────────────────────────────────────────
local MAX_SLOTS  = 6
local SLOT_SIZE  = 28   -- diamètre pastille (pixels)
local SLOT_GAP   = 8    -- espace entre pastilles

-- ── UI ────────────────────────────────────────────────────────────────────────
local sg              = Instance.new("ScreenGui")
sg.Name               = "MachineHUD"
sg.ResetOnSpawn       = false
sg.IgnoreGuiInset     = true
sg.Parent             = playerGui

-- Calcul de la largeur du panel pour loger les 6 pastilles + marges
local PANEL_W = MAX_SLOTS * (SLOT_SIZE + SLOT_GAP) - SLOT_GAP + 120  -- 120px de marge pour le texte

-- Panel principal (centré en haut, caché initialement)
local panel                      = Instance.new("Frame")
panel.Name                       = "MachinePanel"
panel.Size                       = UDim2.new(0, PANEL_W, 0, 90)
panel.AnchorPoint                = Vector2.new(0.5, 0)
panel.Position                   = UDim2.new(0.5, 0, 0, -120)  -- caché
panel.BackgroundColor3           = Color3.fromRGB(10, 10, 14)
panel.BackgroundTransparency     = 0.07
panel.BorderSizePixel            = 0
panel.Parent                     = sg
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)

-- Bordure (couleur dynamique)
local stroke          = Instance.new("UIStroke")
stroke.Thickness      = 2.5
stroke.Color          = Color3.fromRGB(0, 220, 80)
stroke.Parent         = panel

-- Titre : compteur "X / 6 Brainrots"
local counterLbl                    = Instance.new("TextLabel")
counterLbl.Name                     = "CounterLabel"
counterLbl.Size                     = UDim2.new(1, -16, 0, 30)
counterLbl.Position                 = UDim2.new(0, 8, 0, 6)
counterLbl.BackgroundTransparency   = 1
counterLbl.Text                     = "0 / 6  Brainrots en attente"
counterLbl.TextColor3               = Color3.fromRGB(255, 255, 255)
counterLbl.Font                     = Enum.Font.GothamBold
counterLbl.TextSize                 = 17
counterLbl.TextXAlignment           = Enum.TextXAlignment.Center
counterLbl.Parent                   = panel

-- Sous-titre instruction
local subLbl                        = Instance.new("TextLabel")
subLbl.Name                         = "SubLabel"
subLbl.Size                         = UDim2.new(1, -16, 0, 18)
subLbl.Position                     = UDim2.new(0, 8, 0, 36)
subLbl.BackgroundTransparency       = 1
subLbl.Text                         = "Approche du bouton vert  →  Rentrer à la Base"
subLbl.TextColor3                   = Color3.fromRGB(180, 180, 180)
subLbl.Font                         = Enum.Font.Gotham
subLbl.TextSize                     = 12
subLbl.TextXAlignment               = Enum.TextXAlignment.Center
subLbl.Parent                       = panel

-- 6 pastilles de slot (ligne centrée en bas du panel)
local slotDots: {Frame} = {}
local totalSlotsW = MAX_SLOTS * (SLOT_SIZE + SLOT_GAP) - SLOT_GAP
local slotsStartX = (PANEL_W - totalSlotsW) / 2

for i = 1, MAX_SLOTS do
    local dot                = Instance.new("Frame")
    dot.Name                 = "SlotDot_" .. i
    dot.Size                 = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
    dot.Position             = UDim2.new(0,
        slotsStartX + (i - 1) * (SLOT_SIZE + SLOT_GAP),
        0, 56)
    dot.BackgroundColor3     = Color3.fromRGB(35, 35, 45)   -- vide = gris foncé
    dot.BorderSizePixel      = 0
    dot.Parent               = panel
    Instance.new("UICorner", dot).CornerRadius = UDim.new(0.5, 0)

    -- Numéro discret à l'intérieur
    local numTxt                    = Instance.new("TextLabel")
    numTxt.Size                     = UDim2.new(1, 0, 1, 0)
    numTxt.BackgroundTransparency   = 1
    numTxt.Text                     = tostring(i)
    numTxt.TextColor3               = Color3.fromRGB(80, 80, 90)
    numTxt.Font                     = Enum.Font.GothamBold
    numTxt.TextScaled               = true
    numTxt.Parent                   = dot

    slotDots[i] = dot
end

-- ── Animations ────────────────────────────────────────────────────────────────
local SHOW_POS = UDim2.new(0.5, 0, 0, 16)
local HIDE_POS = UDim2.new(0.5, 0, 0, -120)

local COL_SLOT_EMPTY = Color3.fromRGB(35, 35, 45)
local COL_SLOT_FULL  = Color3.fromRGB(0, 220, 80)

local function showPanel(count: number, maxSlots: number)
    -- Mise à jour du texte
    counterLbl.Text = count .. " / " .. maxSlots .. "  Brainrots en attente"

    -- Mise à jour des pastilles
    for i = 1, maxSlots do
        local dot   = slotDots[i]
        local filled = i <= count
        dot.BackgroundColor3 = filled and COL_SLOT_FULL or COL_SLOT_EMPTY
        -- Numéro : visible seulement sur les slots vides
        local numTxt = dot:FindFirstChildOfClass("TextLabel")
        if numTxt then
            numTxt.TextColor3 = filled
                and Color3.fromRGB(0, 0, 0)
                or  Color3.fromRGB(80, 80, 90)
        end
    end

    -- Couleur bordure : rouge si plein, vert sinon
    if count >= maxSlots then
        stroke.Color       = Color3.fromRGB(255, 60, 0)
        subLbl.Text        = "⚠  Capacité maximale ! Rentrez vos Brainrots à la base."
        subLbl.TextColor3  = Color3.fromRGB(255, 100, 60)
    else
        stroke.Color       = Color3.fromRGB(0, 220, 80)
        subLbl.Text        = "Approche du bouton vert  →  Rentrer à la Base"
        subLbl.TextColor3  = Color3.fromRGB(180, 180, 180)
    end

    TweenService:Create(panel,
        TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = SHOW_POS }):Play()
end

local function hidePanel()
    TweenService:Create(panel,
        TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Position = HIDE_POS }):Play()
end

-- ── Écoute du RemoteEvent ─────────────────────────────────────────────────────
-- data = { count: number, max: number }  quand des items sont en attente
-- data = { count = 0 }                   quand la machine est vidée
MachineUpdate.OnClientEvent:Connect(function(data: any)
    if data and data.count and data.count > 0 then
        showPanel(data.count, data.max or MAX_SLOTS)
    else
        hidePanel()
    end
end)

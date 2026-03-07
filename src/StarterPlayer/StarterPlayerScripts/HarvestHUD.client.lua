-- HarvestHUD.client.lua
-- Affiche "Puissance Totale : X" en bas à gauche.
-- Se met à jour à chaque récolte sur une plaque.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Events        = ReplicatedStorage:WaitForChild("Events")
local HarvestResult = Events:WaitForChild("HarvestResult")

-- ── UI ───────────────────────────────────────────────────────────────────────
local sg = Instance.new("ScreenGui")
sg.Name           = "HarvestHUD"
sg.ResetOnSpawn   = false
sg.IgnoreGuiInset = true
sg.Parent         = playerGui

local panel = Instance.new("Frame")
panel.Size                   = UDim2.new(0, 260, 0, 56)
panel.AnchorPoint            = Vector2.new(0, 1)
panel.Position               = UDim2.new(0, 16, 1, -16)
panel.BackgroundColor3       = Color3.fromRGB(8, 20, 12)
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel        = 0
panel.Parent                 = sg

Instance.new("UICorner", panel).CornerRadius = UDim.new(0.18, 0)

local stroke = Instance.new("UIStroke")
stroke.Color     = Color3.fromRGB(0, 200, 80)
stroke.Thickness = 2
stroke.Parent    = panel

local lbl = Instance.new("TextLabel")
lbl.Size                   = UDim2.new(1, -14, 1, 0)
lbl.Position               = UDim2.new(0, 7, 0, 0)
lbl.BackgroundTransparency = 1
lbl.Text                   = "Puissance Totale : 0"
lbl.TextColor3             = Color3.fromRGB(0, 230, 90)
lbl.Font                   = Enum.Font.GothamBold
lbl.TextScaled             = true
lbl.TextXAlignment         = Enum.TextXAlignment.Left
lbl.TextStrokeTransparency = 0.5
lbl.TextStrokeColor3       = Color3.new(0, 0, 0)
lbl.Parent                 = panel

-- ── Toast "+N ⚡" qui monte et disparaît ─────────────────────────────────────
local function showToast(amount: number)
    local toast = Instance.new("TextLabel")
    toast.Size                   = UDim2.new(0, 180, 0, 34)
    toast.AnchorPoint            = Vector2.new(0, 1)
    toast.Position               = UDim2.new(0, 16, 1, -80)
    toast.BackgroundTransparency = 1
    toast.Text                   = "+" .. amount .. " ⚡"
    toast.TextColor3             = Color3.fromRGB(80, 255, 140)
    toast.Font                   = Enum.Font.GothamBlack
    toast.TextScaled             = true
    toast.TextStrokeTransparency = 0.3
    toast.TextStrokeColor3       = Color3.new(0, 0, 0)
    toast.Parent                 = sg

    TweenService:Create(toast,
        TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Position = UDim2.new(0, 16, 1, -150), TextTransparency = 1, TextStrokeTransparency = 1 }
    ):Play()

    task.delay(1.2, function() toast:Destroy() end)
end

-- ── Réception des récoltes ───────────────────────────────────────────────────
local COL_FLASH  = Color3.fromRGB(120, 255, 170)
local COL_NORMAL = Color3.fromRGB(0, 230, 90)

HarvestResult.OnClientEvent:Connect(function(amount: number, total: number)
    lbl.Text = "Puissance Totale : " .. total

    -- Flash vert clair
    lbl.TextColor3 = COL_FLASH
    TweenService:Create(lbl,
        TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { TextColor3 = COL_NORMAL }
    ):Play()

    showToast(amount)
end)

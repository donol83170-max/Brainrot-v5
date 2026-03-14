-- HarvestHUD.client.lua
-- Affiche "PUISSANCE :X ⚡" en bas à gauche.
-- Se met à jour à chaque récolte sur une plaque jaune.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Events        = ReplicatedStorage:WaitForChild("Events")
local HarvestResult = Events:WaitForChild("HarvestResult")

-- ── Formatage : 350 → "350"  |  1500 → "1.5K"  |  2 500 000 → "2.5M" ─────────
local function fmt(n: number): string
    n = math.floor(n)
    if n >= 1_000_000_000 then
        return string.format("%.2fB", n / 1_000_000_000)
    elseif n >= 1_000_000 then
        return string.format("%.2fM", n / 1_000_000)
    elseif n >= 1_000 then
        return string.format("%.1fK", n / 1_000)
    else
        return tostring(n)
    end
end

-- ── UI ───────────────────────────────────────────────────────────────────────
local sg = Instance.new("ScreenGui")
sg.Name           = "HarvestHUD"
sg.ResetOnSpawn   = false
sg.IgnoreGuiInset = true
sg.Parent         = playerGui

local panel = Instance.new("Frame")
panel.Size                   = UDim2.new(0, 310, 0, 56)
panel.AnchorPoint            = Vector2.new(0, 1)
panel.Position               = UDim2.new(0, 16, 1, -16)
panel.BackgroundColor3       = Color3.fromRGB(6, 18, 10)
panel.BackgroundTransparency = 0.12
panel.BorderSizePixel        = 0
panel.Parent                 = sg

Instance.new("UICorner", panel).CornerRadius = UDim.new(0.15, 0)

local stroke = Instance.new("UIStroke")
stroke.Color     = Color3.fromRGB(20, 160, 60)
stroke.Thickness = 2
stroke.Parent    = panel

local lbl = Instance.new("TextLabel")
lbl.Size                   = UDim2.new(1, -14, 1, 0)
lbl.Position               = UDim2.new(0, 7, 0, 0)
lbl.BackgroundTransparency = 1
lbl.Text                   = "PUISSANCE :0 ⚡"
lbl.TextColor3             = Color3.fromRGB(20, 200, 70)
lbl.Font                   = Enum.Font.GothamBold
lbl.TextScaled             = true
lbl.TextXAlignment         = Enum.TextXAlignment.Left
lbl.TextStrokeTransparency = 0.5
lbl.TextStrokeColor3       = Color3.new(0, 0, 0)
lbl.Parent                 = panel

-- ── Toast "+N ⚡" animé (monte et disparaît) ──────────────────────────────────
local function showToast(amount: number)
    local toast = Instance.new("TextLabel")
    toast.Size                   = UDim2.new(0, 200, 0, 36)
    toast.AnchorPoint            = Vector2.new(0, 1)
    toast.Position               = UDim2.new(0, 16, 1, -80)
    toast.BackgroundTransparency = 1
    toast.Text                   = "+" .. fmt(amount) .. " ⚡"
    toast.TextColor3             = Color3.fromRGB(255, 225, 30)
    toast.Font                   = Enum.Font.GothamBlack
    toast.TextScaled             = true
    toast.TextStrokeTransparency = 0.25
    toast.TextStrokeColor3       = Color3.new(0, 0, 0)
    toast.Parent                 = sg

    TweenService:Create(toast,
        TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Position = UDim2.new(0, 16, 1, -155), TextTransparency = 1, TextStrokeTransparency = 1 }
    ):Play()

    task.delay(1.3, function() toast:Destroy() end)
end

-- ── Couleurs de flash ─────────────────────────────────────────────────────────
local COL_FLASH  = Color3.fromRGB(100, 255, 140)
local COL_NORMAL = Color3.fromRGB(20, 200, 70)

-- ── Réception des récoltes ───────────────────────────────────────────────────
HarvestResult.OnClientEvent:Connect(function(amount: number, total: number)
    lbl.Text = "PUISSANCE :" .. fmt(total) .. " ⚡"

    -- Flash vert clair bref
    lbl.TextColor3 = COL_FLASH
    TweenService:Create(lbl,
        TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { TextColor3 = COL_NORMAL }
    ):Play()

    showToast(amount)
end)

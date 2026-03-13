--!strict
-- QuestHUD.client.lua  (LocalScript — StarterPlayerScripts)
-- Affiche les notifications de quête / parkour envoyées par QuestManager.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player = Players.LocalPlayer

local Events    = ReplicatedStorage:WaitForChild("Events")
local QuestHint = Events:WaitForChild("QuestHint") :: RemoteEvent

-- ── Interface ─────────────────────────────────────────────────────────────────
local playerGui = player:WaitForChild("PlayerGui")

local gui           = Instance.new("ScreenGui")
gui.Name            = "QuestHUD"
gui.ResetOnSpawn    = false
gui.IgnoreGuiInset  = false
gui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
gui.Parent          = playerGui

local frame                        = Instance.new("Frame")
frame.Name                         = "HintFrame"
frame.Size                         = UDim2.new(0, 420, 0, 52)
frame.AnchorPoint                  = Vector2.new(0.5, 0)
frame.Position                     = UDim2.new(0.5, 0, 0, 90)
frame.BackgroundColor3             = Color3.fromRGB(15, 15, 35)
frame.BackgroundTransparency       = 0.15
frame.BorderSizePixel              = 0
frame.Visible                      = false
frame.Parent                       = gui

local corner         = Instance.new("UICorner")
corner.CornerRadius  = UDim.new(0, 12)
corner.Parent        = frame

local stroke               = Instance.new("UIStroke")
stroke.Color               = Color3.fromRGB(255, 220, 80)
stroke.Thickness           = 2
stroke.Transparency        = 0.3
stroke.Parent              = frame

local label                        = Instance.new("TextLabel")
label.Size                         = UDim2.new(1, -24, 1, 0)
label.Position                     = UDim2.new(0, 12, 0, 0)
label.BackgroundTransparency       = 1
label.Text                         = ""
label.TextColor3                   = Color3.fromRGB(255, 220, 80)
label.Font                         = Enum.Font.GothamBold
label.TextScaled                   = true
label.TextStrokeTransparency       = 0.4
label.TextStrokeColor3             = Color3.new(0, 0, 0)
label.Parent                       = frame

-- ── Gestion affichage ─────────────────────────────────────────────────────────
local hideThread: thread? = nil

local fadeIn  = TweenService:Create(frame, TweenInfo.new(0.2), { BackgroundTransparency = 0.15 })
local fadeOut = TweenService:Create(frame, TweenInfo.new(0.3), { BackgroundTransparency = 1 })

fadeOut.Completed:Connect(function()
    frame.Visible = false
    frame.BackgroundTransparency = 0.15
end)

QuestHint.OnClientEvent:Connect(function(msg: string, col: Color3?)
    if hideThread then
        task.cancel(hideThread)
        hideThread = nil
    end

    label.Text       = msg
    label.TextColor3 = col or Color3.fromRGB(255, 220, 80)
    stroke.Color     = col or Color3.fromRGB(255, 220, 80)

    frame.BackgroundTransparency = 1
    frame.Visible  = true
    fadeIn:Play()

    hideThread = task.delay(4, function()
        fadeOut:Play()
        hideThread = nil
    end)
end)

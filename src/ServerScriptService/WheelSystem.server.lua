--!strict
-- WheelSystem.server.lua — 12 SEGMENTS · POOL SYSTEM · v4 PIVOT CHIRURGICAL
--
-- RÈGLE DE PHYSIQUE (critique) :
--   SEUL le Pivot est Anchored = true.
--   WheelDisk : Anchored = false + WeldConstraint → suit le Pivot.
--   Toutes les pièces statiques (jante, billes, dôme) : Anchored = true, NON soudées.
--
-- ROTATION CASINO (deux phases) :
--   Phase 1 — Spin rapide (constante)  : RunService.Heartbeat, N tours complets.
--   Phase 2 — Décélération (QuartOut)  : TweenService sur NumberValue → Heartbeat.
--   Résultat : départ rapide → ralentissement réaliste → arrêt précis sur le segment.
--
-- AXEL DU CYLINDRE ROBLOX = X  (Size.X = épaisseur du disque)
--   ORIGINAL_CFRAME = CFrame.Angles(0, 180°, 0)  → local +X pointe vers world -X (fontaine) ✓
--   Spin    = CFrame.Angles(deg, 0, 0)   → rotation autour de local X = axe du disque ✓
--   SurfaceGui Face = NormalId.Right → face plate circulaire visible depuis la fontaine ✓

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService          = game:GetService("RunService")
local TweenService        = game:GetService("TweenService")
local Workspace           = game:GetService("Workspace")

local DataManager = require(ServerScriptService:WaitForChild("DataManager"))

local Events           = ReplicatedStorage:WaitForChild("Events")
local SpinResult       = Events:WaitForChild("SpinResult")
local UpdateClientData = Events:WaitForChild("UpdateClientData")
local RequestSpin      = Events:FindFirstChild("RequestSpin")
if not RequestSpin then
    RequestSpin = Instance.new("RemoteEvent")
    RequestSpin.Name = "RequestSpin"
    RequestSpin.Parent = Events
end

-- ══════════════════════════════════════════════════════════════════════════════
-- CONFIG
-- ══════════════════════════════════════════════════════════════════════════════
local N_SEGMENTS       = 12
local SEG_ANGLE        = 360 / N_SEGMENTS   -- 30° par segment
local SPIN_COST        = 20
local FULL_ROTATIONS   = 5     -- tours complets en phase 1
local PHASE1_DURATION  = 3.5   -- secondes — spin rapide constant
local PHASE2_DURATION  = 2.0   -- secondes — TweenService QuartOut (décélération)
local SPIN_DURATION    = PHASE1_DURATION + PHASE2_DURATION   -- 5.5 s au total
-- ── Position & taille ────────────────────────────────────────────────────────
-- Fontaine centrale à X=0, Z=0 (WorldAssets). Roue reculée loin de la fontaine.
-- WHEEL_CENTER.X = +40 (40 studs à droite → large espace de circulation devant).
-- Z=0 → centrée sur l'allée centrale. Face du disque vers -X (fontaine) ✓
local WHEEL_CENTER     = Vector3.new(40, 18, 0)
local WHEEL_RADIUS     = 10   -- agrandi pour la visibilité depuis les galeries

local RARITY_COLORS = {
    COMMON    = Color3.fromRGB(160, 162, 168),
    RARE      = Color3.fromRGB(  0, 130, 255),
    EPIC      = Color3.fromRGB(255,   0, 255),
    LEGENDARY = Color3.fromRGB(255, 190,   0),
}

-- ══════════════════════════════════════════════════════════════════════════════
-- POOLS DE RARETÉ
-- ══════════════════════════════════════════════════════════════════════════════
local POOL = {
    COMMON = {
        { itemId = "SkibidiHead",     imageId = 15263881432, name = "Skibidi Toilet"       },
        { itemId = "NoobiniPizza",    imageId = 0,           name = "Noobini Pizzanini"    },
        { itemId = "PipiCorni",       imageId = 0,           name = "Pipi Corni"           },
        { itemId = "MaxwellCat",      imageId = 12501659970, name = "Maxwell Cat"          },
    },
    RARE = {
        { itemId = "Tralalero",       imageId = 0,           name = "Tralalero Tralala"    },
        { itemId = "DogeMeme",        imageId = 0,           name = "Doge"                 },
    },
    EPIC = {
        { itemId = "BrBrPatapim",     imageId = 0,           name = "Br Br Patapim"        },
        { itemId = "CappuccinoAss",   imageId = 0,           name = "Cappuccino Assassino" },
    },
    LEGENDARY = {
        { itemId = "StrawberryEleph", imageId = 0,           name = "Strawberry Elephant"  },
        { itemId = "DragonCannell",   imageId = 0,           name = "Dragon Cannelloni"    },
    },
}

local RARITY_WEIGHTS = {
    { rarity = "COMMON",    weight = 60 },
    { rarity = "RARE",      weight = 25 },
    { rarity = "EPIC",      weight = 12 },
    { rarity = "LEGENDARY", weight = 3  },
}

local SEGMENTS = {
    { rarity = "COMMON",    item = POOL.COMMON[1]    },  --  1
    { rarity = "COMMON",    item = POOL.COMMON[4]    },  --  2
    { rarity = "RARE",      item = POOL.RARE[1]      },  --  3
    { rarity = "COMMON",    item = POOL.COMMON[2]    },  --  4
    { rarity = "COMMON",    item = POOL.COMMON[3]    },  --  5
    { rarity = "LEGENDARY", item = POOL.LEGENDARY[1] },  --  6
    { rarity = "COMMON",    item = POOL.COMMON[4]    },  --  7
    { rarity = "RARE",      item = POOL.RARE[2]      },  --  8
    { rarity = "COMMON",    item = POOL.COMMON[1]    },  --  9
    { rarity = "EPIC",      item = POOL.EPIC[1]      },  -- 10
    { rarity = "COMMON",    item = POOL.COMMON[3]    },  -- 11
    { rarity = "RARE",      item = POOL.RARE[1]      },  -- 12
}

local SEGS_BY_RARITY: {[string]: {number}} = { COMMON={}, RARE={}, EPIC={}, LEGENDARY={} }
for idx, seg in ipairs(SEGMENTS) do
    table.insert(SEGS_BY_RARITY[seg.rarity], idx)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- TIRAGE PONDÉRÉ
-- ══════════════════════════════════════════════════════════════════════════════
math.randomseed(os.clock() * 1000)

local function pickRarity(): string
    local roll = math.random(1, 100)
    local cum  = 0
    for _, entry in ipairs(RARITY_WEIGHTS) do
        cum += entry.weight
        if roll <= cum then return entry.rarity end
    end
    return "COMMON"
end

local function pickItem(rarity: string)
    local pool = POOL[rarity]
    return pool[math.random(1, #pool)]
end

-- ══════════════════════════════════════════════════════════════════════════════
-- CFRAME HELPERS
-- ORIGINAL_CFRAME = point d'ancrage fixe de toutes les rotations.
-- CFrame.Angles(0, 180°, 0) → local +X pointe vers world -X (vers fontaine) ✓
-- Spin = CFrame.Angles(deg, 0, 0) → rotation autour de local X = axe du disque ✓
-- ══════════════════════════════════════════════════════════════════════════════
local ORIGINAL_CFRAME = CFrame.new(WHEEL_CENTER) * CFrame.Angles(0, math.rad(180), 0)

-- Retourne le CFrame du Pivot pour un angle de spin donné (en degrés, cumulatif).
-- Toutes les rotations TweenService sont relatives à ORIGINAL_CFRAME.
local function getPivotCF(deg: number): CFrame
    return ORIGINAL_CFRAME * CFrame.Angles(math.rad(deg), 0, 0)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- CONSTRUCTION PHYSIQUE
-- ══════════════════════════════════════════════════════════════════════════════
-- Nettoyage Total (Destruction de l'ancienne roue pour forcer la v5 physique)
local oldWheel = Workspace:FindFirstChild("BrainrotWheel")
if oldWheel then
    oldWheel:Destroy()
end

local wheelFolder       = Instance.new("Folder")
wheelFolder.Name        = "BrainrotWheel"
wheelFolder.Parent      = Workspace

-- ── Borne de Casino (Slot Machine) ────────────────────────────────────────────────
local MACHINE_X = WHEEL_CENTER.X
local MACHINE_Z = WHEEL_CENTER.Z
local SCALE = 1.05 -- Agrandissement de 5%

-- Socle rectangulaire principal (Métal Gris -> Peinture Rouge)
local machineBase       = Instance.new("Part")
machineBase.Name        = "MachineBase"
machineBase.Size        = Vector3.new(6 * SCALE, 12 * SCALE, 8 * SCALE) 
machineBase.Position    = Vector3.new(MACHINE_X, 6 * SCALE, MACHINE_Z)
machineBase.Anchored    = true
machineBase.Material    = Enum.Material.SmoothPlastic
machineBase.Color       = Color3.fromRGB(200, 0, 0)
machineBase.Parent      = wheelFolder

-- Dégradé de Rouge "High Quality Paint" avec SurfaceGuis
local function applyGradientToFace(part, face)
    local sg = Instance.new("SurfaceGui")
    sg.Face = face
    sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    sg.PixelsPerStud = 50
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = part
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    frame.BorderSizePixel = 0
    frame.Parent = sg
    
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 0, 0)),   -- Rouge profond
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 25, 25))  -- Rouge écarlate brillant
    })
    grad.Rotation = -90 -- Bas vers le haut
    grad.Parent = frame
end
applyGradientToFace(machineBase, Enum.NormalId.Left)   -- Face avant (-X local est Left)
applyGradientToFace(machineBase, Enum.NormalId.Right)  -- Dos
applyGradientToFace(machineBase, Enum.NormalId.Front)  -- Côté
applyGradientToFace(machineBase, Enum.NormalId.Back)   -- Côté

-- Lumières Néon sur les bords (Or brillant fixe)
local neonLeft = Instance.new("Part")
neonLeft.Name = "NeonLeft"
neonLeft.Size = Vector3.new(6.1 * SCALE, 12.2 * SCALE, 0.4 * SCALE)
neonLeft.Position = Vector3.new(MACHINE_X, 6 * SCALE, MACHINE_Z - 3.8 * SCALE)
neonLeft.Anchored = true; neonLeft.Material = Enum.Material.Neon
neonLeft.Color = Color3.fromRGB(255, 215, 0); neonLeft.Parent = wheelFolder

local neonRight = Instance.new("Part")
neonRight.Name = "NeonRight"
neonRight.Size = Vector3.new(6.1 * SCALE, 12.2 * SCALE, 0.4 * SCALE)
neonRight.Position = Vector3.new(MACHINE_X, 6 * SCALE, MACHINE_Z + 3.8 * SCALE)
neonRight.Anchored = true; neonRight.Material = Enum.Material.Neon
neonRight.Color = Color3.fromRGB(255, 215, 0); neonRight.Parent = wheelFolder

-- Cadre doré de l'écran
local screenBorder = Instance.new("Part")
screenBorder.Name = "ScreenBorder"
screenBorder.Size = Vector3.new(0.6 * SCALE, 6.4 * SCALE, 7.4 * SCALE)
screenBorder.CFrame = CFrame.new(MACHINE_X - 3.05 * SCALE, 9 * SCALE, MACHINE_Z) * CFrame.Angles(0, 0, math.rad(-15))
screenBorder.Anchored = true
screenBorder.Material = Enum.Material.Metal
screenBorder.Color = Color3.fromRGB(255, 215, 0)
screenBorder.Parent = wheelFolder

-- Écran incliné noir
local screenPart        = Instance.new("Part")
screenPart.Name         = "ScreenPart"
screenPart.Size         = Vector3.new(0.65 * SCALE, 6 * SCALE, 7 * SCALE)
screenPart.CFrame       = CFrame.new(MACHINE_X - 3.1 * SCALE, 9 * SCALE, MACHINE_Z) * CFrame.Angles(0, 0, math.rad(-15))
screenPart.Anchored     = true
screenPart.Material     = Enum.Material.SmoothPlastic
screenPart.Color        = Color3.fromRGB(15, 15, 15)
screenPart.Parent       = wheelFolder

-- SurfaceGui sur l'écran (Face = Left)
local screenGui         = Instance.new("SurfaceGui")
screenGui.Face          = Enum.NormalId.Left
screenGui.CanvasSize    = Vector2.new(800 * SCALE, 600 * SCALE)
screenGui.Parent        = screenPart

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, 0, 1, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "SPIN TO WIN\nBRAINROT"
titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
titleText.Font = Enum.Font.LuckiestGuy
titleText.TextScaled = true
titleText.TextStrokeTransparency = 0
titleText.TextStrokeColor3 = Color3.new(0, 0, 0)
titleText.Parent = screenGui

-- Levier doré sur la face avant (-X), en bas à droite (+Z du point de vue face avant)
local leverBaseCF = CFrame.new(MACHINE_X - 3.2 * SCALE, 5.5 * SCALE, MACHINE_Z + 2.5 * SCALE) 
                  * CFrame.Angles(0, math.rad(-90), 0) 
                  * CFrame.Angles(math.rad(30), 0, 0)

local leverArm        = Instance.new("Part")
leverArm.Shape        = Enum.PartType.Cylinder
leverArm.Size         = Vector3.new(0.4 * SCALE, 3 * SCALE, 0.4 * SCALE)
leverArm.Anchored     = true
leverArm.Material     = Enum.Material.Metal
leverArm.Color        = Color3.fromRGB(255, 215, 0)
leverArm.Parent       = wheelFolder

local leverBall       = Instance.new("Part")
leverBall.Shape       = Enum.PartType.Ball
leverBall.Size        = Vector3.new(1.2 * SCALE, 1.2 * SCALE, 1.2 * SCALE)
leverBall.Anchored    = true
leverBall.Material    = Enum.Material.SmoothPlastic
leverBall.Color       = Color3.fromRGB(255, 40, 40)
leverBall.Parent      = wheelFolder

-- Fonction de mise à jour du levier
local function updateLever(angleDeg)
    -- Levier pivote via l'axe X local. Une augmentation de angleDeg bascule le levier vers le bas.
    local pivotCF = leverBaseCF * CFrame.Angles(math.rad(angleDeg), 0, 0)
    leverArm.CFrame = pivotCF * CFrame.new(0, 1.5 * SCALE, 0) 
    leverBall.CFrame = pivotCF * CFrame.new(0, 3 * SCALE, 0)
end
updateLever(0) -- Position repos (déjà incliné de 30° par leverBaseCF)

-- ClickDetector sur la boule rouge à l'avant
local clickDetector = Instance.new("ClickDetector")
clickDetector.MaxActivationDistance = 40
clickDetector.Parent = leverBall

local tickSound = Instance.new("Sound")
tickSound.SoundId = "rbxassetid://6026984224"
tickSound.Volume = 0.5
tickSound.Parent = machineBase

-- ══════════════════════════════════════════════════════════════════════════════
-- LOGIQUE
-- ══════════════════════════════════════════════════════════════════════════════
local wheelLocked: boolean              = false
local spinCooldowns: {[number]: number} = {}

local function getCoins(player: Player): number
    local ls    = player:FindFirstChild("leaderstats")
    local coins = ls and ls:FindFirstChild("Brainrot Coins")
    return coins and coins.Value or 0
end

-- ── Fonction commune de tirage ──────────────────────────────────────────────
local function ActionSpin(player: Player)
    if wheelLocked then return end

    local now = tick()
    if spinCooldowns[player.UserId] and (now - spinCooldowns[player.UserId]) < SPIN_DURATION + 1 then
        return
    end

    if getCoins(player) < SPIN_COST then
        SpinResult:FireClient(player, { success = false, reason = "coins" })
        return
    end

    local data = DataManager.GetData(player)
    if not data then return end

    DataManager.SpendGold(player, SPIN_COST)
    spinCooldowns[player.UserId] = now
    wheelLocked = true

    -- Tirage pondéré
    local winRarity    = pickRarity()
    local winItem      = pickItem(winRarity)
    local segsOfRarity = SEGS_BY_RARITY[winRarity]
    local winSegIdx    = segsOfRarity[math.random(1, #segsOfRarity)]

    -- Calcul de l'angle pour la logique pure (non utilisé en 3D mais transmis au besoin)
    local winAngle = (360 - ((winSegIdx - 1) * SEG_ANGLE)) % 360

    -- Inventaire + galerie
    DataManager.AddItem(player, { Id = winItem.itemId, Name = winItem.name, Rarity = winRarity })
    if _G.BrainrotGallery_Refresh then
        task.spawn(_G.BrainrotGallery_Refresh, player)
    end
    local updated = DataManager.GetData(player)
    if updated then UpdateClientData:FireClient(player, updated) end

    print(string.format("[WheelSystem] %s → %s '%s' | seg%d",
        player.Name, winRarity, winItem.name, winSegIdx))

    local angleVal = Instance.new("NumberValue")
    angleVal.Value = 0
    local conn = RunService.Heartbeat:Connect(function()
        updateLever(angleVal.Value)
    end)

    -- Tween du levier vers le bas (ex: +60 degrés pour basculer en bas)
    local tweenDown = TweenService:Create(angleVal, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = 60 })
    local tweenUp   = TweenService:Create(angleVal, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 0 })

    tweenDown.Completed:Connect(function()
        tickSound:Play()
        tweenUp:Play()

        -- Envoi du résultat pour déclencher la machine à sous UI pendant que le levier remonte
        SpinResult:FireClient(player, {
            success    = true,
            segments   = SEGMENTS,
            winSegment = winSegIdx,
            memeName   = winItem.name,
            memeRarity = winRarity,
            imageId    = winItem.imageId,
            duration   = SPIN_DURATION,
            rotations  = FULL_ROTATIONS
        })
    end)

    tweenUp.Completed:Connect(function()
        conn:Disconnect()
        angleVal:Destroy()
        
        -- Déverrouillage après la durée de la spin 2D
        task.delay(SPIN_DURATION - 0.7, function()
            wheelLocked = false
        end)
    end)

    tweenDown:Play()
end

-- Connexions
clickDetector.MouseClick:Connect(ActionSpin)
RequestSpin.OnServerEvent:Connect(ActionSpin)

print(string.format(
    "[WheelSystem] v5 PIVOT pret | pos (0,18,-20) derriere fontaine | face +Z nord | phase1=%.1fs + phase2=%.1fs QuartOut | COMMON %d%% RARE %d%% EPIC %d%% LEG %d%%",
    PHASE1_DURATION, PHASE2_DURATION,
    RARITY_WEIGHTS[1].weight, RARITY_WEIGHTS[2].weight,
    RARITY_WEIGHTS[3].weight, RARITY_WEIGHTS[4].weight))

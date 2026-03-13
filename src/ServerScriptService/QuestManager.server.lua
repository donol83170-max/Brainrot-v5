--!strict
-- QuestManager.server.lua
-- PNJ de défi (3 dépôts) + Zone Parkour (10 plateformes, récompense en haut).
--
-- Hooks exposés :
--   _G.QuestManager_OnDeposit(player)  ← appelé par BrainrotGallery.ForcePlace
--
-- RemoteEvent créée : Events.QuestHint  ← reçue par QuestHUD.client.lua

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace         = game:GetService("Workspace")

local DataManager = require(ServerScriptService:WaitForChild("DataManager"))

-- ── RemoteEvent "QuestHint" ────────────────────────────────────────────────
local Events = ReplicatedStorage:WaitForChild("Events")
local QuestHint: RemoteEvent
do
    local ex = Events:FindFirstChild("QuestHint")
    if ex then
        QuestHint = ex :: RemoteEvent
    else
        QuestHint          = Instance.new("RemoteEvent")
        QuestHint.Name     = "QuestHint"
        QuestHint.Parent   = Events
    end
end

-- ── Constantes ────────────────────────────────────────────────────────────
local QUEST_TARGET         = 3    -- dépôts requis
local QUEST_REWARD_COINS   = 500
local PARKOUR_REWARD_COINS = 200
local PARKOUR_COOLDOWN     = 300  -- secondes (5 min)

-- Machine casino : WHEEL_CENTER = (40, ?, 0). Sol à Y=0.
local NPC_X, NPC_Z  = 60, 5        -- PNJ : à droite de la machine, légèrement devant
local PARK_START    = Vector3.new(62, 1, -15)  -- début parkour (derrière le PNJ)

-- ── État par joueur ─────────────────────────────────────────────────────────
local depositCount:     {[number]: number}  = {}
local questComplete:    {[number]: boolean} = {}
local parkourCooldown:  {[number]: number}  = {}  -- os.time() fin cooldown

-- ── Helper ───────────────────────────────────────────────────────────────────
local function notify(player: Player, msg: string, col: Color3?)
    QuestHint:FireClient(player, msg, col or Color3.fromRGB(255, 220, 80))
end

local UpdateClientData = Events:WaitForChild("UpdateClientData") :: RemoteEvent

local function syncClient(player: Player)
    local data = DataManager.GetData(player)
    if data then UpdateClientData:FireClient(player, data) end
end

-- ── Dossier racine ────────────────────────────────────────────────────────────
local questRoot        = Instance.new("Folder")
questRoot.Name         = "QuestZone"
questRoot.Parent       = Workspace

-- ════════════════════════════════════════════════════════════════════════════
-- CONSTRUCTEUR DE PARTS (helper interne)
-- ════════════════════════════════════════════════════════════════════════════
local function mkPart(
    parent  : Instance,
    name    : string,
    size    : Vector3,
    pos     : Vector3,
    col     : Color3,
    neon    : boolean?,
    collide : boolean?
): Part
    local p = Instance.new("Part")
    p.Name            = name
    p.Size            = size
    p.Position        = pos
    p.Anchored        = true
    p.CanCollide      = if collide == true then true else false
    p.CanTouch        = false
    p.CanQuery        = false
    p.CastShadow      = false
    p.Color           = col
    p.Material        = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
    p.TopSurface      = Enum.SurfaceType.Smooth
    p.BottomSurface   = Enum.SurfaceType.Smooth
    p.Parent          = parent
    return p
end

-- ════════════════════════════════════════════════════════════════════════════
-- PNJ LEGO (modèle simple par assemblage de Parts)
-- ════════════════════════════════════════════════════════════════════════════
local SKIN  = Color3.fromRGB(255, 220, 150)
local BLUE  = Color3.fromRGB(50,  100, 220)
local BLACK = Color3.fromRGB(20,   20,  20)

local npcFolder = Instance.new("Model")
npcFolder.Name  = "QuestNPC"
npcFolder.Parent = questRoot

local NY = 0   -- Y sol
-- Corps
local torso  = mkPart(npcFolder, "Torso",    Vector3.new(2, 3, 1),   Vector3.new(NPC_X,   NY+3.5, NPC_Z), BLUE)
mkPart(npcFolder, "Legs",     Vector3.new(2, 2, 1),   Vector3.new(NPC_X,   NY+1,   NPC_Z), BLUE)
mkPart(npcFolder, "Head",     Vector3.new(2, 2, 2),   Vector3.new(NPC_X,   NY+5.5, NPC_Z), SKIN)
mkPart(npcFolder, "ArmLeft",  Vector3.new(1, 2.5, 1), Vector3.new(NPC_X-1.5, NY+3.5, NPC_Z), SKIN)
mkPart(npcFolder, "ArmRight", Vector3.new(1, 2.5, 1), Vector3.new(NPC_X+1.5, NY+3.5, NPC_Z), SKIN)
-- Yeux (petites Parts neon sur la face -Z du visage)
mkPart(npcFolder, "EyeL", Vector3.new(0.35, 0.35, 0.05), Vector3.new(NPC_X-0.4, NY+5.7, NPC_Z-1.025), BLACK, true)
mkPart(npcFolder, "EyeR", Vector3.new(0.35, 0.35, 0.05), Vector3.new(NPC_X+0.4, NY+5.7, NPC_Z-1.025), BLACK, true)
npcFolder.PrimaryPart = torso

-- Lumière dorée (s'allume quand le défi est terminé)
local npcGlow        = Instance.new("PointLight")
npcGlow.Color        = Color3.fromRGB(255, 200, 0)
npcGlow.Brightness   = 0
npcGlow.Range        = 16
npcGlow.Parent       = torso

-- ── Billboard "!" au-dessus du PNJ ────────────────────────────────────────
local npcBb         = Instance.new("BillboardGui")
npcBb.Size          = UDim2.new(0, 50, 0, 60)
npcBb.StudsOffset   = Vector3.new(0, 3.5, 0)
npcBb.Adornee       = torso
npcBb.AlwaysOnTop   = false
npcBb.MaxDistance   = 60
npcBb.Parent        = npcFolder

local questSign                      = Instance.new("TextLabel")
questSign.Size                       = UDim2.new(1, 0, 1, 0)
questSign.BackgroundTransparency     = 1
questSign.Text                       = "!"
questSign.TextColor3                 = Color3.fromRGB(255, 220, 0)
questSign.Font                       = Enum.Font.GothamBlack
questSign.TextScaled                 = true
questSign.TextStrokeTransparency     = 0
questSign.TextStrokeColor3           = Color3.new(0, 0, 0)
questSign.Parent                     = npcBb

-- ── ProximityPrompt sur le PNJ ────────────────────────────────────────────
local npcPrompt                    = Instance.new("ProximityPrompt")
npcPrompt.ActionText               = "Parler"
npcPrompt.ObjectText               = "PNJ Défi"
npcPrompt.HoldDuration             = 0
npcPrompt.MaxActivationDistance    = 8
npcPrompt.RequiresLineOfSight      = false
npcPrompt.Parent                   = torso

-- Socle décoratif devant le PNJ (récompense cosmétique)
local rewardBase = mkPart(questRoot, "QuestRewardBase",
    Vector3.new(3, 0.5, 3), Vector3.new(NPC_X, NY+0.25, NPC_Z-3),
    Color3.fromRGB(255, 215, 0), true)

local rewardGlow       = Instance.new("PointLight")
rewardGlow.Color       = Color3.fromRGB(255, 215, 0)
rewardGlow.Brightness  = 0
rewardGlow.Range       = 10
rewardGlow.Parent      = rewardBase

-- ── Hook dépôt Brainrot ───────────────────────────────────────────────────
_G.QuestManager_OnDeposit = function(player: Player)
    local uid = player.UserId
    if questComplete[uid] then return end   -- attente collecte récompense

    depositCount[uid] = (depositCount[uid] or 0) + 1
    local n = depositCount[uid]

    notify(player,
        string.format("🎯 Défi : %d/%d Brainrots déposés !", n, QUEST_TARGET),
        Color3.fromRGB(100, 200, 255))

    if n >= QUEST_TARGET then
        questComplete[uid] = true
        -- Allumer le PNJ et le socle
        npcGlow.Brightness   = 5
        rewardGlow.Brightness = 6
        questSign.Text       = "✓"
        questSign.TextColor3 = Color3.fromRGB(50, 255, 100)
        notify(player,
            "✅ Défi terminé ! Parle au PNJ pour ta récompense.",
            Color3.fromRGB(50, 255, 100))
    end
end

-- ── Interaction PNJ ───────────────────────────────────────────────────────
npcPrompt.Triggered:Connect(function(player: Player)
    local uid = player.UserId
    local n   = depositCount[uid] or 0

    if not questComplete[uid] then
        notify(player,
            string.format("🎯 Défi : Dépose %d Brainrots dans ta galerie ! (%d/%d)",
                QUEST_TARGET, n, QUEST_TARGET))
        return
    end

    -- ── Donne la récompense ────────────────────────────────────────────────
    questComplete[uid]  = false
    depositCount[uid]   = 0

    DataManager.AddGold(player, QUEST_REWARD_COINS)
    syncClient(player)

    -- Spawn sphère cosmétique sur le socle (disparaît après 8 s)
    local sphere         = Instance.new("Part")
    sphere.Shape         = Enum.PartType.Ball
    sphere.Size          = Vector3.new(2, 2, 2)
    sphere.Color         = Color3.fromRGB(255, 215, 0)
    sphere.Material      = Enum.Material.Neon
    sphere.Anchored      = true
    sphere.CanCollide    = false
    sphere.CanTouch      = false
    sphere.CanQuery      = false
    sphere.CastShadow    = false
    sphere.Position      = rewardBase.Position + Vector3.new(0, 1.5, 0)
    sphere.Parent        = questRoot

    local sl             = Instance.new("PointLight")
    sl.Color             = Color3.fromRGB(255, 215, 0)
    sl.Brightness        = 10
    sl.Range             = 20
    sl.Parent            = sphere

    task.delay(8, function()
        if sphere.Parent then sphere:Destroy() end
    end)

    -- Réinitialise le visuel NPC
    npcGlow.Brightness    = 0
    rewardGlow.Brightness = 0
    questSign.Text        = "!"
    questSign.TextColor3  = Color3.fromRGB(255, 220, 0)

    notify(player,
        string.format("🏆 Récompense : +%d Coins ! Nouveau défi disponible.",
            QUEST_REWARD_COINS),
        Color3.fromRGB(255, 215, 0))
end)

-- ════════════════════════════════════════════════════════════════════════════
-- ZONE PARKOUR — 10 plateformes montantes, récompense au sommet
-- ════════════════════════════════════════════════════════════════════════════
type PlatDef = { dx: number, dz: number, dy: number }
local PLATFORM_DEFS: {PlatDef} = {
    { dx =  0,  dz =  0,  dy =  0 },   -- 1 - départ
    { dx = 10,  dz =  5,  dy =  6 },   -- 2
    { dx = 20,  dz = -3,  dy = 12 },   -- 3
    { dx = 30,  dz =  7,  dy = 18 },   -- 4
    { dx = 40,  dz = -2,  dy = 24 },   -- 5
    { dx = 50,  dz =  6,  dy = 30 },   -- 6
    { dx = 60,  dz = -5,  dy = 36 },   -- 7
    { dx = 70,  dz =  4,  dy = 42 },   -- 8
    { dx = 80,  dz = -1,  dy = 48 },   -- 9
    { dx = 90,  dz =  0,  dy = 54 },   -- 10 - sommet 🏆
}

local carpetBlocks = ReplicatedStorage:FindFirstChild("Blocks")
local carpetTpl: BasePart? = (carpetBlocks and carpetBlocks:FindFirstChild("Carpet")) :: BasePart?

local parkourFolder      = Instance.new("Folder")
parkourFolder.Name       = "ParkourZone"
parkourFolder.Parent     = questRoot

for idx, def in ipairs(PLATFORM_DEFS) do
    local isTop  = (idx == #PLATFORM_DEFS)
    local platPos = PARK_START + Vector3.new(def.dx, def.dy, def.dz)
    local platCol = if isTop then Color3.fromRGB(255, 215, 0) else Color3.fromRGB(60, 140, 60)

    local plat: BasePart
    if carpetTpl then
        plat       = carpetTpl:Clone() :: BasePart
        plat.Size  = Vector3.new(8, 1, 8)
        plat.Color = platCol
        for _, ch in ipairs(plat:GetChildren()) do
            if ch:IsA("Texture") or ch:IsA("Decal") then
                (ch :: Texture).Color3 = platCol
            end
        end
    else
        plat          = Instance.new("Part")
        plat.Size     = Vector3.new(8, 1, 8)
        plat.Color    = platCol
        plat.Material = Enum.Material.SmoothPlastic
    end

    plat.Name         = "ParkourPlat_" .. idx
    plat.Anchored     = true
    plat.CanCollide   = true     -- les joueurs peuvent marcher dessus
    plat.CanTouch     = false
    plat.CanQuery     = false
    plat.CastShadow   = false
    plat.Position     = platPos
    plat.Parent       = parkourFolder

    -- Label numéro / trophée
    local bb             = Instance.new("BillboardGui")
    bb.Size              = UDim2.new(0, 40, 0, 40)
    bb.StudsOffset       = Vector3.new(0, 1.5, 0)
    bb.Adornee           = plat
    bb.AlwaysOnTop       = false
    bb.MaxDistance       = 40
    bb.Parent            = parkourFolder

    local lbl                       = Instance.new("TextLabel")
    lbl.Size                        = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency      = 1
    lbl.Text                        = if isTop then "🏆" else tostring(idx)
    lbl.TextColor3                  = Color3.fromRGB(255, 255, 255)
    lbl.Font                        = Enum.Font.GothamBlack
    lbl.TextScaled                  = true
    lbl.TextStrokeTransparency      = 0
    lbl.TextStrokeColor3            = Color3.new(0, 0, 0)
    lbl.Parent                      = bb

    if isTop then
        -- Lumière dorée au sommet
        local topLight       = Instance.new("PointLight")
        topLight.Color       = Color3.fromRGB(255, 215, 0)
        topLight.Brightness  = 6
        topLight.Range       = 22
        topLight.Parent      = plat

        -- Socle de récompense parkour
        local topBase = mkPart(parkourFolder, "ParkourTopBase",
            Vector3.new(3, 0.6, 3), platPos + Vector3.new(0, 1.3, 0),
            Color3.fromRGB(255, 215, 0), true)

        local parkourPrompt                 = Instance.new("ProximityPrompt")
        parkourPrompt.ActionText            = "Récompense"
        parkourPrompt.ObjectText            = "🏆 Parkour (5 min cooldown)"
        parkourPrompt.HoldDuration          = 0.5
        parkourPrompt.MaxActivationDistance = 5
        parkourPrompt.RequiresLineOfSight   = false
        parkourPrompt.Parent               = topBase

        parkourPrompt.Triggered:Connect(function(player: Player)
            local uid = player.UserId
            local now = os.time()
            local cd  = parkourCooldown[uid] or 0

            if now < cd then
                local rem  = cd - now
                local mins = math.floor(rem / 60)
                local secs = rem % 60
                notify(player,
                    string.format("⏳ Cooldown : encore %d min %02d s", mins, secs),
                    Color3.fromRGB(255, 100, 100))
                return
            end

            parkourCooldown[uid] = now + PARKOUR_COOLDOWN
            DataManager.AddGold(player, PARKOUR_REWARD_COINS)
            syncClient(player)

            notify(player,
                string.format("🏆 Parkour terminé ! +%d Coins ! (cooldown 5 min)",
                    PARKOUR_REWARD_COINS),
                Color3.fromRGB(255, 215, 0))
        end)
    end
end

-- ── Nettoyage déconnexion ─────────────────────────────────────────────────
Players.PlayerRemoving:Connect(function(player: Player)
    local uid = player.UserId
    depositCount[uid]    = nil
    questComplete[uid]   = nil
    parkourCooldown[uid] = nil
end)

print("[QuestManager] Prêt — NPC Défi + Parkour 10 niveaux initialisés.")

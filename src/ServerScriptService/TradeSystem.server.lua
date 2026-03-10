--!strict
-- TradeSystem.server.lua
-- Machine à Échange physique — Compartiment A (gauche) / B (droite) + leviers.
-- Un seul échange actif à la fois (machine partagée, accessible à tous les joueurs).

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace           = game:GetService("Workspace")
local BadgeService        = game:GetService("BadgeService")

local DataManager = require(ServerScriptService:WaitForChild("DataManager"))

local Events = ReplicatedStorage:WaitForChild("Events")
local function getOrCreate(name, className)
    local obj = Events:FindFirstChild(name)
    if not obj then
        obj        = Instance.new(className)
        obj.Name   = name
        obj.Parent = Events
    end
    return obj
end

local TradeJoin     = getOrCreate("TradeJoin",    "RemoteEvent")
local TradeDeposit  = getOrCreate("TradeDeposit", "RemoteEvent")
local TradeConfirm  = getOrCreate("TradeConfirm", "RemoteEvent")
local TradeCancel   = getOrCreate("TradeCancel",  "RemoteEvent")
local TradeUpdate   = getOrCreate("TradeUpdate",  "RemoteEvent")
local TradeResult   = getOrCreate("TradeResult",  "RemoteEvent")
local LegendaryDrop = getOrCreate("LegendaryDrop","RemoteEvent")

-- ── Badges ────────────────────────────────────────────────────────────────────
-- Un badge distinct par item légendaire.
-- 0 = non configuré → aucune erreur, le badge est simplement ignoré.
local LEGENDARY_BADGES: {[string]: number} = {
    ["Dragon Cannelloni"]   = 1216737457718835,
    ["Strawberry Elephant"] = 848333503023627,
}

local function awardBadge(player: Player, badgeId: number)
    if not badgeId or badgeId == 0 then return end
    task.spawn(function()
        local ok, has = pcall(BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, badgeId)
        if ok and not has then
            pcall(BadgeService.AwardBadge, BadgeService, player.UserId, badgeId)
        end
    end)
end

-- Exposé pour WheelSystem : attribue le badge correspondant à l'item légendaire gagné.
-- itemName : nom exact de l'item (ex. "Dragon Cannelloni")
function _G.CheckLegendaryBadge(player: Player, itemName: string)
    local badgeId = LEGENDARY_BADGES[itemName]
    if badgeId then
        awardBadge(player, badgeId)
    else
        warn(string.format("[TradeSystem] Pas de badge configuré pour '%s'", tostring(itemName)))
    end
end

-- ── Dossier des modèles 3D (pour affichage dans les compartiments) ─────────────
local brainrotModels: Folder? = nil
task.spawn(function()
    brainrotModels = ReplicatedStorage:WaitForChild("BrainrotModels", 20) :: Folder?
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- CONSTRUCTION 3D DE LA MACHINE
-- Position : (-25, 0, 0) — à gauche de la fontaine centrale
-- ══════════════════════════════════════════════════════════════════════════════
local MX, MY, MZ = -25, 0, 0   -- centre de la machine

local mapFolder = Workspace:FindFirstChild("Map") or (function()
    local f = Instance.new("Folder"); f.Name = "Map"; f.Parent = Workspace; return f
end)()

local machineFolder = Instance.new("Folder")
machineFolder.Name   = "TradeMachine"
machineFolder.Parent = mapFolder

local COL_CHASSIS = Color3.fromRGB(30, 32, 38)
local COL_GOLD    = Color3.fromRGB(255, 215, 0)
local COL_GLASS   = Color3.fromRGB(100, 190, 255)
local COL_GREEN   = Color3.fromRGB(0, 220, 80)
local COL_RED     = Color3.fromRGB(220, 50, 50)
local COL_YELLOW  = Color3.fromRGB(255, 200, 0)

local function mp(name, size, pos, color, mat, canCollide)
    local p = Instance.new("Part")
    p.Name          = name
    p.Size          = size
    p.Position      = pos
    p.Anchored      = true
    p.CanCollide    = canCollide ~= false
    p.Color         = color
    p.Material      = mat or Enum.Material.SmoothPlastic
    p.TopSurface    = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.CastShadow    = true
    p.Parent        = machineFolder
    return p
end

-- Socle principal
mp("TradeBase",
    Vector3.new(24, 1.5, 10),
    Vector3.new(MX, MY + 0.75, MZ),
    COL_CHASSIS, Enum.Material.Metal)

-- Corniche or
mp("TradeCorniche",
    Vector3.new(24.4, 0.3, 10.4),
    Vector3.new(MX, MY + 1.65, MZ),
    COL_GOLD, Enum.Material.Metal)

-- Compartiment A (gauche, X-8)
local slotAPart = mp("SlotA_Platform",
    Vector3.new(8, 0.4, 8),
    Vector3.new(MX - 8, MY + 1.95, MZ),
    Color3.fromRGB(20, 22, 28), Enum.Material.SmoothPlastic)

-- Bords neon slot A (couleur = état)
local neonA = mp("NeonA",
    Vector3.new(8.4, 0.15, 8.4),
    Vector3.new(MX - 8, MY + 2.18, MZ),
    COL_GREEN, Enum.Material.Neon, false)
neonA.Transparency = 0.3

-- Compartiment B (droite, X+8)
local slotBPart = mp("SlotB_Platform",
    Vector3.new(8, 0.4, 8),
    Vector3.new(MX + 8, MY + 1.95, MZ),
    Color3.fromRGB(20, 22, 28), Enum.Material.SmoothPlastic)

local neonB = mp("NeonB",
    Vector3.new(8.4, 0.15, 8.4),
    Vector3.new(MX + 8, MY + 2.18, MZ),
    COL_GREEN, Enum.Material.Neon, false)
neonB.Transparency = 0.3

-- Console centrale (surélevée)
mp("Console",
    Vector3.new(6, 5, 8),
    Vector3.new(MX, MY + 4, MZ),
    COL_CHASSIS, Enum.Material.Metal)
mp("ConsoleFace",
    Vector3.new(0.3, 4, 7),
    Vector3.new(MX - 3.2, MY + 4, MZ),
    Color3.fromRGB(15, 15, 20), Enum.Material.SmoothPlastic, false)

-- Enseigne Trade
local signPart = mp("TradeSign",
    Vector3.new(6, 2, 7.5),
    Vector3.new(MX, MY + 7.5, MZ),
    COL_CHASSIS, Enum.Material.Metal)
local signSGui = Instance.new("SurfaceGui")
signSGui.Face      = Enum.NormalId.Left
signSGui.CanvasSize = Vector2.new(300, 80)
signSGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
signSGui.LightInfluence = 0
signSGui.Parent    = signPart
local signLbl = Instance.new("TextLabel")
signLbl.Size = UDim2.new(1, 0, 1, 0)
signLbl.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
signLbl.BackgroundTransparency = 0.1
signLbl.Text = "⇄  MACHINE À ÉCHANGE"
signLbl.TextColor3 = COL_GOLD
signLbl.Font = Enum.Font.GothamBlack
signLbl.TextScaled = true
signLbl.TextStrokeTransparency = 0
signLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
signLbl.Parent = signSGui
Instance.new("UICorner", signLbl).CornerRadius = UDim.new(0, 6)

-- Labels "JOUEUR A / B"
for _, info in ipairs({ {MX-8, "A"}, {MX+8, "B"} }) do
    local px = info[1]
    local lbl = info[2]
    local labelPart = mp("SlotLabel_"..lbl,
        Vector3.new(0.2, 1, 4),
        Vector3.new(px, MY + 2.8, MZ),
        Color3.fromRGB(10,10,10), Enum.Material.SmoothPlastic, false)
    local sg = Instance.new("SurfaceGui")
    sg.Face = Enum.NormalId.Left
    sg.CanvasSize = Vector2.new(200, 60)
    sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    sg.LightInfluence = 0
    sg.Parent = labelPart
    local tl = Instance.new("TextLabel")
    tl.Size = UDim2.new(1,0,1,0)
    tl.BackgroundTransparency = 1
    tl.Text = "JOUEUR " .. lbl
    tl.TextColor3 = COL_GOLD
    tl.Font = Enum.Font.GothamBlack
    tl.TextScaled = true
    tl.TextStrokeTransparency = 0
    tl.TextStrokeColor3 = Color3.new(0,0,0)
    tl.Parent = sg
end

-- Levier A (validation joueur A) — sur la face gauche de la console
local leverBallA = mp("LeverBallA",
    Vector3.new(1.2, 1.2, 1.2),
    Vector3.new(MX - 2.5, MY + 5.5, MZ - 2),
    Color3.fromRGB(0, 200, 80), Enum.Material.SmoothPlastic)
leverBallA.Shape = Enum.PartType.Ball
mp("LeverArmA", Vector3.new(0.3, 2, 0.3),
    Vector3.new(MX - 2.5, MY + 4.5, MZ - 2),
    COL_GOLD, Enum.Material.Metal)

-- Levier B (validation joueur B) — sur la face droite de la console
local leverBallB = mp("LeverBallB",
    Vector3.new(1.2, 1.2, 1.2),
    Vector3.new(MX + 2.5, MY + 5.5, MZ - 2),
    Color3.fromRGB(0, 200, 80), Enum.Material.SmoothPlastic)
leverBallB.Shape = Enum.PartType.Ball
mp("LeverArmB", Vector3.new(0.3, 2, 0.3),
    Vector3.new(MX + 2.5, MY + 4.5, MZ - 2),
    COL_GOLD, Enum.Material.Metal)

-- ClickDetectors
local cdSlotA = Instance.new("ClickDetector")
cdSlotA.MaxActivationDistance = 12
cdSlotA.Parent = slotAPart

local cdSlotB = Instance.new("ClickDetector")
cdSlotB.MaxActivationDistance = 12
cdSlotB.Parent = slotBPart

local cdLeverA = Instance.new("ClickDetector")
cdLeverA.MaxActivationDistance = 10
cdLeverA.Parent = leverBallA

local cdLeverB = Instance.new("ClickDetector")
cdLeverB.MaxActivationDistance = 10
cdLeverB.Parent = leverBallB

-- BillboardGui de statut (au-dessus de la console)
local statusBb = Instance.new("BillboardGui")
statusBb.Size        = UDim2.new(0, 280, 0, 80)
statusBb.StudsOffset = Vector3.new(0, 5, 0)
statusBb.Adornee     = Instance.new("Part") -- remplacé ci-dessous
statusBb.AlwaysOnTop = false
statusBb.MaxDistance = 50
statusBb.Parent      = machineFolder

-- Crée une anchor invisible au-dessus de la console
local statusAnchor = mp("StatusAnchor",
    Vector3.new(0.1, 0.1, 0.1),
    Vector3.new(MX, MY + 9, MZ),
    Color3.new(0,0,0), Enum.Material.SmoothPlastic, false)
statusAnchor.Transparency = 1
statusBb.Adornee = statusAnchor

local statusLbl = Instance.new("TextLabel")
statusLbl.Size                   = UDim2.new(1, 0, 1, 0)
statusLbl.BackgroundColor3       = Color3.fromRGB(10, 10, 14)
statusLbl.BackgroundTransparency = 0.2
statusLbl.Text                   = "En attente de joueurs..."
statusLbl.TextColor3             = Color3.fromRGB(200, 200, 220)
statusLbl.Font                   = Enum.Font.GothamBold
statusLbl.TextScaled             = true
statusLbl.TextStrokeTransparency = 0.5
statusLbl.TextStrokeColor3       = Color3.new(0, 0, 0)
statusLbl.Parent                 = statusBb
Instance.new("UICorner", statusLbl).CornerRadius = UDim.new(0.12, 0)

-- ══════════════════════════════════════════════════════════════════════════════
-- ÉTAT DU TRADE
-- ══════════════════════════════════════════════════════════════════════════════
type TradeSlot = {
    player     : Player?,
    itemId     : string?,
    itemName   : string?,
    confirmed  : boolean,
    displayModel : Model?,
}

local tradeA: TradeSlot = { player=nil, itemId=nil, itemName=nil, confirmed=false, displayModel=nil }
local tradeB: TradeSlot = { player=nil, itemId=nil, itemName=nil, confirmed=false, displayModel=nil }

-- ── Verrou de vente — appelé par Communication.server.lua ────────────────────
-- Retourne true si l'item est actuellement déposé dans la machine à échange.
function _G.IsItemInTrade(player: Player, itemId: string): boolean
    if tradeA.player == player and tradeA.itemId == itemId then return true end
    if tradeB.player == player and tradeB.itemId == itemId then return true end
    return false
end

local MAX_FIGURINE_DIM = 3

-- Positions au-dessus des compartiments (centre de l'espace de display)
local DISPLAY_POS_A = Vector3.new(MX - 8, MY + 4.5, MZ)
local DISPLAY_POS_B = Vector3.new(MX + 8, MY + 4.5, MZ)

local function clearDisplayModel(slot: TradeSlot)
    if slot.displayModel then
        pcall(function() slot.displayModel:Destroy() end)
        slot.displayModel = nil
    end
end

local function spawnDisplayModel(slot: TradeSlot, pos: Vector3)
    clearDisplayModel(slot)
    if not slot.itemName then return end

    local template = brainrotModels and (brainrotModels :: Folder):FindFirstChild(slot.itemName)
    local clone: Model

    if template and template:IsA("Model") then
        clone = template:Clone()
        -- Auto-scale
        local ok, rawBB = pcall(function() return select(2, clone:GetBoundingBox()) end)
        if ok and rawBB then
            local maxDim = math.max(rawBB.X, rawBB.Y, rawBB.Z)
            if maxDim > MAX_FIGURINE_DIM then
                pcall(function() clone:ScaleTo(MAX_FIGURINE_DIM / maxDim) end)
            end
        end
        local _, scaledBB = clone:GetBoundingBox()
        local sizeY = scaledBB and scaledBB.Y or MAX_FIGURINE_DIM
        clone:PivotTo(CFrame.new(pos + Vector3.new(0, sizeY / 2, 0)))
    else
        -- Fallback : cube coloré
        clone = Instance.new("Model")
        clone.Name = slot.itemName or "???"
        local part = Instance.new("Part")
        part.Size     = Vector3.new(2, 2, 2)
        part.Anchored = true
        part.CanCollide = false
        part.Color    = Color3.fromRGB(100, 100, 120)
        part.Material = Enum.Material.SmoothPlastic
        part.Position = pos + Vector3.new(0, 1, 0)
        part.Parent   = clone
        clone.PrimaryPart = part
    end

    -- Label flottant
    local bb = Instance.new("BillboardGui")
    bb.Size        = UDim2.new(0, 160, 0, 36)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = false
    bb.MaxDistance = 30
    bb.Adornee     = clone.PrimaryPart
    bb.Parent      = clone
    local tl = Instance.new("TextLabel")
    tl.Size = UDim2.new(1,0,1,0)
    tl.BackgroundTransparency = 0.3
    tl.BackgroundColor3 = Color3.fromRGB(10,10,14)
    tl.Text = slot.itemName or "???"
    tl.TextColor3 = Color3.new(1,1,1)
    tl.Font = Enum.Font.GothamBold
    tl.TextScaled = true
    tl.Parent = bb
    Instance.new("UICorner", tl).CornerRadius = UDim.new(0.3,0)

    clone.Parent     = machineFolder
    slot.displayModel = clone
end

-- ── Mise à jour des visuels (néons + status label) ───────────────────────────
local function updateVisuals()
    -- Néon slot A
    if tradeA.player then
        neonA.Color = tradeA.confirmed and COL_GREEN or COL_YELLOW
    else
        neonA.Color = COL_GREEN
    end
    -- Néon slot B
    if tradeB.player then
        neonB.Color = tradeB.confirmed and COL_GREEN or COL_YELLOW
    else
        neonB.Color = COL_GREEN
    end

    -- Levier A couleur
    leverBallA.Color = tradeA.confirmed and COL_GREEN or COL_RED

    -- Levier B couleur
    leverBallB.Color = tradeB.confirmed and COL_GREEN or COL_RED

    -- Texte statut
    local lines = {}
    if tradeA.player then
        local s = (tradeA.player :: Player).Name
        if tradeA.itemName then s = s .. " → " .. tradeA.itemName end
        if tradeA.confirmed then s = s .. " ✓" end
        table.insert(lines, "[A] " .. s)
    else
        table.insert(lines, "[A] En attente...")
    end
    if tradeB.player then
        local s = (tradeB.player :: Player).Name
        if tradeB.itemName then s = s .. " → " .. tradeB.itemName end
        if tradeB.confirmed then s = s .. " ✓" end
        table.insert(lines, "[B] " .. s)
    else
        table.insert(lines, "[B] En attente...")
    end
    statusLbl.Text = table.concat(lines, "\n")
end

-- ── Broadcast l'état du trade aux deux participants ──────────────────────────
local function broadcastState()
    local payload = {
        slotA = {
            playerName = tradeA.player and (tradeA.player :: Player).Name or nil,
            itemName   = tradeA.itemName,
            confirmed  = tradeA.confirmed,
        },
        slotB = {
            playerName = tradeB.player and (tradeB.player :: Player).Name or nil,
            itemName   = tradeB.itemName,
            confirmed  = tradeB.confirmed,
        },
    }
    if tradeA.player then TradeUpdate:FireClient(tradeA.player :: Player, "A", payload) end
    if tradeB.player then TradeUpdate:FireClient(tradeB.player :: Player, "B", payload) end
    updateVisuals()
end

-- ── Reset complet ─────────────────────────────────────────────────────────────
local function resetTrade(reason: string?)
    if tradeA.player then TradeResult:FireClient(tradeA.player :: Player, false, reason or "Échange annulé") end
    if tradeB.player then TradeResult:FireClient(tradeB.player :: Player, false, reason or "Échange annulé") end
    clearDisplayModel(tradeA)
    clearDisplayModel(tradeB)
    tradeA = { player=nil, itemId=nil, itemName=nil, confirmed=false, displayModel=nil }
    tradeB = { player=nil, itemId=nil, itemName=nil, confirmed=false, displayModel=nil }
    updateVisuals()
end

-- ── Exécution de l'échange ────────────────────────────────────────────────────
local function executeTrade()
    local pA = tradeA.player :: Player
    local pB = tradeB.player :: Player
    local idA = tradeA.itemId :: string
    local idB = tradeB.itemId :: string

    local dataA = DataManager.GetData(pA)
    local dataB = DataManager.GetData(pB)

    -- Vérification finale : les items sont-ils toujours dans les inventaires ?
    if not dataA or not dataA.Inventory[idA] then
        resetTrade("Item de " .. pA.Name .. " introuvable")
        return
    end
    if not dataB or not dataB.Inventory[idB] then
        resetTrade("Item de " .. pB.Name .. " introuvable")
        return
    end

    local itemDataA = dataA.Inventory[idA]
    local itemDataB = dataB.Inventory[idB]

    -- Retirer les items
    DataManager.RemoveItem(pA, idA)
    DataManager.RemoveItem(pB, idB)

    -- Donner les items croisés
    DataManager.AddItem(pA, { Id = idB, Name = itemDataB.Name, Rarity = itemDataB.Rarity })
    DataManager.AddItem(pB, { Id = idA, Name = itemDataA.Name, Rarity = itemDataA.Rarity })

    -- Notifier + mettre à jour HUD
    local Events2 = ReplicatedStorage:FindFirstChild("Events")
    local UpdateClientData = Events2 and Events2:FindFirstChild("UpdateClientData")
    if UpdateClientData then
        local updA = DataManager.GetData(pA)
        local updB = DataManager.GetData(pB)
        if updA then UpdateClientData:FireClient(pA, updA) end
        if updB then UpdateClientData:FireClient(pB, updB) end
    end

    -- Rafraîchir les galeries
    if _G.BrainrotGallery_Refresh then
        task.spawn(_G.BrainrotGallery_Refresh, pA)
        task.spawn(_G.BrainrotGallery_Refresh, pB)
    end

    print(string.format("[Trade] %s (%s) ↔ %s (%s) — SUCCÈS",
        pA.Name, itemDataA.Name, pB.Name, itemDataB.Name))

    TradeResult:FireClient(pA, true, "Tu as reçu : " .. itemDataB.Name)
    TradeResult:FireClient(pB, true, "Tu as reçu : " .. itemDataA.Name)

    -- Badge si un légendaire change de mains via trade
    if string.upper(tostring(itemDataB.Rarity or "")) == "LEGENDARY" then
        _G.CheckLegendaryBadge(pA, itemDataB.Name)
    end
    if string.upper(tostring(itemDataA.Rarity or "")) == "LEGENDARY" then
        _G.CheckLegendaryBadge(pB, itemDataA.Name)
    end

    clearDisplayModel(tradeA)
    clearDisplayModel(tradeB)
    tradeA = { player=nil, itemId=nil, itemName=nil, confirmed=false, displayModel=nil }
    tradeB = { player=nil, itemId=nil, itemName=nil, confirmed=false, displayModel=nil }
    updateVisuals()
end

-- ══════════════════════════════════════════════════════════════════════════════
-- HANDLERS SERVEUR
-- ══════════════════════════════════════════════════════════════════════════════

-- Rejoindre un compartiment via ClickDetector
local function handleJoin(player: Player, slot: string)
    if slot == "A" then
        if tradeA.player then return end
        if tradeB.player == player then return end -- déjà dans B
        tradeA.player    = player
        tradeA.itemId    = nil
        tradeA.itemName  = nil
        tradeA.confirmed = false
    elseif slot == "B" then
        if tradeB.player then return end
        if tradeA.player == player then return end
        tradeB.player    = player
        tradeB.itemId    = nil
        tradeB.itemName  = nil
        tradeB.confirmed = false
    end
    broadcastState()
end

cdSlotA.MouseClick:Connect(function(player) handleJoin(player, "A") end)
cdSlotB.MouseClick:Connect(function(player) handleJoin(player, "B") end)
TradeJoin.OnServerEvent:Connect(handleJoin)

-- Déposer un item
TradeDeposit.OnServerEvent:Connect(function(player: Player, itemId: string)
    local slot: TradeSlot?
    local displayPos: Vector3

    if tradeA.player == player then
        slot = tradeA
        displayPos = DISPLAY_POS_A
    elseif tradeB.player == player then
        slot = tradeB
        displayPos = DISPLAY_POS_B
    else
        return
    end

    -- Vérifier ownership
    local data = DataManager.GetData(player)
    if not data or not data.Inventory[itemId] then return end
    local item = data.Inventory[itemId]
    if not item or (item.Count or 0) <= 0 then return end

    -- Annuler confirmation si changement d'item
    if slot then
        slot.itemId    = itemId
        slot.itemName  = item.Name
        slot.confirmed = false
        spawnDisplayModel(slot, displayPos)
    end

    broadcastState()
end)

-- Confirmer (levier)
local function handleConfirm(player: Player)
    if tradeA.player == player then
        if not tradeA.itemId then return end
        tradeA.confirmed = true
    elseif tradeB.player == player then
        if not tradeB.itemId then return end
        tradeB.confirmed = true
    else
        return
    end
    broadcastState()

    if tradeA.confirmed and tradeB.confirmed then
        task.wait(0.5)
        executeTrade()
    end
end

cdLeverA.MouseClick:Connect(handleConfirm)
cdLeverB.MouseClick:Connect(handleConfirm)
TradeConfirm.OnServerEvent:Connect(handleConfirm)

-- Annuler / quitter
TradeCancel.OnServerEvent:Connect(function(player: Player)
    if tradeA.player == player or tradeB.player == player then
        resetTrade(player.Name .. " a annulé l'échange")
    end
end)

-- Nettoyage si le joueur quitte le jeu
Players.PlayerRemoving:Connect(function(player: Player)
    if tradeA.player == player or tradeB.player == player then
        resetTrade(player.Name .. " a quitté le jeu")
    end
end)

-- Initialisation des visuels
updateVisuals()
print("[TradeSystem] Machine à Échange opérationnelle à (" .. MX .. ", 0, " .. MZ .. ")")

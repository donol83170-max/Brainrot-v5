--!strict
-- CarryManager.server.lua
-- Gère le cycle "Porter → Poser" d'un Brainrot après un spin gagnant.
--
-- Flux :
--   1. WheelSystem appelle _G.CarryManager_StartCarry(player, item, rarity)
--   2. Un clone miniature est soudé au-dessus de la tête du joueur (WeldConstraint).
--   3. Des ProximityPrompts apparaissent sur les socles vides de la galerie du joueur.
--   4. Le joueur active un prompt → dépôt : DataManager + ForcePlace + SpawnFX.

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace           = game:GetService("Workspace")

local DataManager = require(ServerScriptService:WaitForChild("DataManager"))
local SpawnFX     = require(ServerScriptService:WaitForChild("SpawnFX"))

local Events           = ReplicatedStorage:WaitForChild("Events")
local CarryUpdateEvent = Events:WaitForChild("CarryUpdate")       :: RemoteEvent
local UpdateClientData = Events:WaitForChild("UpdateClientData")  :: RemoteEvent

-- ⚠️  Remplace cet ID par ton animation "bras levés" uploadée sur Roblox Studio.
--     Exemple de workflow : importe une animation R15 depuis Moon Animator,
--     publie-la et colle l'ID ici.
local CARRY_ANIM_ID = "rbxassetid://507770453"

-- ── État par joueur ───────────────────────────────────────────────────────────
type CarryState = {
    item      : { itemId: string, name: string },
    rarity    : string,
    clone     : Model?,
    prompts   : {ProximityPrompt},
    animTrack : AnimationTrack?,
}
local carried: {[number]: CarryState} = {}

-- ── Animation de portage ──────────────────────────────────────────────────────
local function startCarryAnim(player: Player): AnimationTrack?
    local char = player.Character
    if not char then return nil end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return nil end

    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then return nil end

    local ok, result = pcall(function(): AnimationTrack
        local anim        = Instance.new("Animation")
        anim.AnimationId  = CARRY_ANIM_ID
        local track       = animator:LoadAnimation(anim)
        track.Priority    = Enum.AnimationPriority.Action
        track.Looped      = true
        track:Play(0.3)   -- fondu d'entrée 0.3 s
        return track
    end)

    return if ok then result :: AnimationTrack else nil
end

-- ── Helpers ───────────────────────────────────────────────────────────────────

-- Crée un clone miniature de l'item et le soude au-dessus de la tête du joueur.
local function attachCarryClone(player: Player, itemName: string): Model?
    local modelsFolder = ReplicatedStorage:FindFirstChild("BrainrotModels")
    if not modelsFolder then return nil end

    local template = modelsFolder:FindFirstChild(itemName)
    if not template or not template:IsA("Model") then return nil end

    local clone = template:Clone() :: Model

    -- Réduction à 35 % de la taille originale
    pcall(function() clone:ScaleTo(clone:GetScale() * 0.35) end)

    -- Désactiver collisions/queries sur toutes les parts (ghost)
    for _, p in ipairs(clone:GetDescendants()) do
        if p:IsA("BasePart") then
            local bp = p :: BasePart
            bp.CanCollide  = false
            bp.CanTouch    = false
            bp.CanQuery    = false
            bp.Massless    = true
            bp.CastShadow  = false
            bp.Anchored    = false   -- obligatoire pour le WeldConstraint
        end
    end

    local character = player.Character
    if not character then clone:Destroy() ; return nil end

    local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then clone:Destroy() ; return nil end

    local primaryPart = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart", true) :: BasePart?
    if not primaryPart then clone:Destroy() ; return nil end

    -- Positionner le clone AVANT le weld (le WeldConstraint fige la transformation)
    clone:PivotTo(hrp.CFrame * CFrame.new(0, 4.5, 0))
    clone.Parent = Workspace

    -- Souder au HumanoidRootPart → suit le joueur automatiquement
    local weld    = Instance.new("WeldConstraint")
    weld.Part0    = hrp
    weld.Part1    = primaryPart
    weld.Parent   = primaryPart

    return clone
end

-- Crée les ProximityPrompts sur les socles vides et retourne la liste pour cleanup.
local function createPrompts(
    player  : Player,
    item    : { itemId: string, name: string },
    rarity  : string,
    onPlace : (slotIndex: number, topPart: BasePart) -> ()
): {ProximityPrompt}

    local prompts: {ProximityPrompt} = {}

    if not _G.BrainrotGallery_GetEmptyPedestalTops then return prompts end
    local emptySlots = _G.BrainrotGallery_GetEmptyPedestalTops(player) :: {[number]: BasePart}

    for slotIndex, topPart in pairs(emptySlots) do
        local pp = Instance.new("ProximityPrompt")
        pp.ActionText             = "Poser ici"
        pp.ObjectText             = item.name
        pp.MaxActivationDistance  = 12
        pp.RequiresLineOfSight    = false
        pp.HoldDuration           = 0
        pp.UIOffset               = Vector2.new(0, 30)
        pp.Enabled                = true
        pp.Parent                 = topPart

        -- Triggered est côté serveur pour sécurité
        pp.Triggered:Connect(function(triggerPlayer: Player)
            if triggerPlayer ~= player then return end
            if not carried[player.UserId] then return end  -- déjà posé ?
            onPlace(slotIndex, topPart)
        end)

        table.insert(prompts, pp)
    end

    return prompts
end

-- ── Arrêt du carry (supprime clone + prompts + animation) ─────────────────────
local function stopCarry(player: Player)
    local uid   = player.UserId
    local state = carried[uid]
    if not state then return end

    -- Arrêt de l'animation bras levés (fondu de sortie 0.3 s)
    if state.animTrack then
        pcall(function() (state.animTrack :: AnimationTrack):Stop(0.3) end)
    end

    if state.clone then
        state.clone:Destroy()
    end
    for _, pp in ipairs(state.prompts) do
        if pp and pp.Parent then pp:Destroy() end
    end

    carried[uid] = nil
    CarryUpdateEvent:FireClient(player, nil)  -- cache le HUD client
end

-- ── Placement sur le socle ────────────────────────────────────────────────────
local function doPlace(player: Player, slotIndex: number, topPart: BasePart)
    local uid   = player.UserId
    local state = carried[uid]
    if not state then return end

    local item   = state.item
    local rarity = state.rarity

    -- 1. Retrait du carry (clone + prompts) avant le placement visuel
    stopCarry(player)

    -- 2. Sauvegarde en inventaire
    DataManager.AddItem(player, { Id = item.itemId, Name = item.name, Rarity = rarity })

    -- 3. Placement visuel sur le socle (définit aussi l'Attribute PPS)
    if _G.BrainrotGallery_ForcePlace then
        _G.BrainrotGallery_ForcePlace(player, slotIndex, { Id = item.itemId, Name = item.name, Rarity = rarity })
    end

    -- 4. Apothéose : effets VFX sur le socle + camera shake pour le joueur
    SpawnFX.Play(topPart, rarity, player)

    -- 5. Mise à jour du client (inventaire + coins)
    local updated = DataManager.GetData(player)
    if updated then UpdateClientData:FireClient(player, updated) end

    print(string.format("[CarryManager] %s → posé '%s' (%s) sur slot %d",
        player.Name, item.name, rarity, slotIndex))
end

-- ── Démarrage du carry ────────────────────────────────────────────────────────
-- Appelé par WheelSystem juste après la fin du spin.
_G.CarryManager_StartCarry = function(
    player : Player,
    item   : { itemId: string, name: string },
    rarity : string
)
    local uid = player.UserId

    -- Remplace un éventuel carry précédent proprement
    if carried[uid] then stopCarry(player) end

    -- Clone visuel soudé au joueur
    local clone = attachCarryClone(player, item.name)

    -- Animation bras levés (démarre immédiatement)
    local animTrack = startCarryAnim(player)

    -- Création des prompts (ferme sur player/item/rarity pour doPlace)
    local prompts = createPrompts(player, item, rarity, function(slotIndex, topPart)
        doPlace(player, slotIndex, topPart)
    end)

    carried[uid] = {
        item      = item,
        rarity    = rarity,
        clone     = clone,
        prompts   = prompts,
        animTrack = animTrack,
    }

    -- Informe le client (affiche le HUD de transport)
    CarryUpdateEvent:FireClient(player, {
        name   = item.name,
        rarity = rarity,
        nSlots = #prompts,
    })

    print(string.format("[CarryManager] %s transporte '%s' (%s) — %d socles disponibles",
        player.Name, item.name, rarity, #prompts))
end

-- ── Nettoyage déconnexion ─────────────────────────────────────────────────────
Players.PlayerRemoving:Connect(function(player: Player)
    if carried[player.UserId] then
        stopCarry(player)
    end
end)

print("[CarryManager] Prêt — hook _G.CarryManager_StartCarry exposé.")

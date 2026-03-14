-- ParadeManager.server.lua
-- !! DÉSACTIVÉ TEMPORAIREMENT — retirer le `return` ci-dessous pour réactiver !!
do return end

-- Brainrots sauvages défilent en file indienne le long de l'avenue (axe X, Z=110).
-- Source  : ReplicatedStorage.WildBrainrots
-- Cible   : Workspace.Parade
--
-- Chaque Brainrot spawne à l'Ouest (START_X), marche vers l'Est (END_X),
-- et est détruit dès qu'il atteint la destination → zéro fuite mémoire.
--
-- Deux modes détectés automatiquement :
--   • Modèle AVEC Humanoid  → Humanoid:MoveTo       (marche physique)
--   • Modèle SANS Humanoid  → TweenService Linear   (glissement ancré)

local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

-- ══════════════════════════════════════════════════════════════════════════════
-- CONFIG
-- ══════════════════════════════════════════════════════════════════════════════

local SPAWN_INTERVAL  = 8     -- secondes entre deux spawns
local WALK_SPEED      = 6     -- studs/s (Humanoid WalkSpeed)
local SLIDE_SPEED     = 6     -- studs/s (Tween)
local SLIDE_Y_OFFSET  = 0.5   -- offset Y au-dessus du sol pour objets statiques
local FLOOR_Y         = 1     -- Y du sol de l'avenue
local MOVE_TIMEOUT    = 120   -- timeout sécurité Humanoid (s)

-- ── Axe de la parade : Ouest → Est le long de l'avenue principale ──────────
local AVENUE_Z = 110   -- Z fixe de l'avenue (entre les deux rangées de galeries)
local START_X  = -200  -- point de spawn (Ouest)
local END_X    =  200  -- point de destruction (Est)

-- Direction constante de marche (+X)
local FACING = Vector3.new(1, 0, 0)

-- ══════════════════════════════════════════════════════════════════════════════
-- DOSSIER WORKSPACE
-- ══════════════════════════════════════════════════════════════════════════════

local paradeFolder: Folder
do
    local e = Workspace:FindFirstChild("Parade")
    if e and e:IsA("Folder") then
        paradeFolder = e :: Folder
    else
        local f  = Instance.new("Folder")
        f.Name   = "Parade"
        f.Parent = Workspace
        paradeFolder = f
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- OPTIMISATION PHYSIQUE  (pattern WeldConstraint, identique à RoamingNPCSystem)
-- Un seul BasePart (root) actif ; toutes les autres parts soudées + fantômes.
-- Coût physique réduit au minimum : un seul corps par NPC.
-- ══════════════════════════════════════════════════════════════════════════════

local function optimizeModel(model: Model): BasePart?
    local root: BasePart? = model.PrimaryPart
                         or model:FindFirstChild("HumanoidRootPart") :: BasePart?
                         or model:FindFirstChildWhichIsA("BasePart", true) :: BasePart?
    if not root then
        local rp        = Instance.new("Part")
        rp.Name         = "HumanoidRootPart"
        rp.Size         = Vector3.new(2, 2, 2)
        rp.Transparency = 1
        rp.CanCollide   = false
        rp.CastShadow   = false
        rp.Parent       = model
        root            = rp
    end
    model.PrimaryPart = root :: BasePart

    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") and part ~= root then
            part.Anchored   = false
            part.CanCollide = false
            part.Massless   = true
            part.CanQuery   = false
            part.CanTouch   = false
            -- WeldConstraint si absent
            local welded = false
            for _, c in ipairs(part:GetChildren()) do
                if c:IsA("WeldConstraint") or c:IsA("Weld") then
                    welded = true ; break
                end
            end
            if not welded then
                local wc  = Instance.new("WeldConstraint")
                wc.Part0  = root :: BasePart
                wc.Part1  = part :: BasePart
                wc.Parent = root :: BasePart
            end
        end
    end

    return root :: BasePart
end

-- ══════════════════════════════════════════════════════════════════════════════
-- CAS 1 : DÉFILÉ AVEC HUMANOID — marche physique jusqu'à END_X, puis Destroy
-- ══════════════════════════════════════════════════════════════════════════════

local function marchHumanoid(model: Model, humanoid: Humanoid, root: BasePart)
    task.spawn(function()
        humanoid.MaxHealth  = 1e9
        humanoid.Health     = 1e9
        humanoid.WalkSpeed  = WALK_SPEED
        humanoid.JumpPower  = 0
        humanoid.AutoRotate = true
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead,        false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,     false)

        -- Conserver le Z actuel du root (léger jitter appliqué lors du spawn)
        local destZ = root.Position.Z
        humanoid:MoveTo(Vector3.new(END_X, FLOOR_Y, destZ))

        local arrived = false
        local conn: RBXScriptConnection
        conn = humanoid.MoveToFinished:Connect(function(_: boolean)
            arrived = true
            conn:Disconnect()
        end)

        -- Attente avec timeout (évite un Brainrot bloqué indéfiniment)
        local elapsed = 0
        while not arrived and elapsed < MOVE_TIMEOUT and model.Parent ~= nil do
            task.wait(0.5)
            elapsed += 0.5
        end
        if not arrived then pcall(function() conn:Disconnect() end) end

        -- Destruction garantie à l'arrivée (ou timeout)
        if model.Parent ~= nil then model:Destroy() end
    end)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- CAS 2 : DÉFILÉ SANS HUMANOID — Tween Linear sur root.CFrame, puis Destroy
--
-- root est Anchored ; TweenService anime root.CFrame directement.
-- Les WeldConstraints propagent le mouvement côté moteur physique —
-- zéro signal Lua par frame, zéro overhead scripteur.
-- ══════════════════════════════════════════════════════════════════════════════

local function marchTween(model: Model, root: BasePart)
    task.spawn(function()
        local startPos = root.Position
        local endPos   = Vector3.new(END_X, startPos.Y, startPos.Z)

        -- Orienter face à la destination (+X) avant le départ
        root.CFrame  = CFrame.lookAt(startPos, startPos + FACING)
        local endCF  = CFrame.lookAt(endPos,   endPos   + FACING)

        local dist     = (endPos - startPos).Magnitude
        local duration = math.max(dist / SLIDE_SPEED, 0.5)

        local tween = TweenService:Create(root,
            TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
            { CFrame = endCF })
        tween:Play()
        tween.Completed:Wait()
        tween:Destroy()

        -- Destruction garantie à l'arrivée
        if model.Parent ~= nil then model:Destroy() end
    end)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- SPAWN D'UN BRAINROT EN PARADE
-- ══════════════════════════════════════════════════════════════════════════════

local RNG = Random.new()

local function spawnParader(templates: {Model})
    local template = templates[RNG:NextInteger(1, #templates)]
    local clone    = template:Clone()

    -- Parent EN PREMIER : PivotTo est ignoré sur un modèle non parenté (règle Roblox)
    clone.Parent = paradeFolder

    -- Légère variation Z (±1.5) pour éviter la superposition exacte si deux
    -- Brainrots spawneraient au même instant
    local zOff = RNG:NextNumber(-1.5, 1.5)

    clone:PivotTo(CFrame.lookAt(
        Vector3.new(START_X, FLOOR_Y, AVENUE_Z + zOff),
        Vector3.new(START_X + 1, FLOOR_Y, AVENUE_Z + zOff)
    ))

    local root = optimizeModel(clone)
    if not root then
        warn(string.format("[Parade] '%s' : aucun BasePart — ignoré", template.Name))
        clone:Destroy()
        return
    end

    local humanoid: Humanoid? = clone:FindFirstChildWhichIsA("Humanoid", true) :: Humanoid?

    if humanoid then
        -- ── Mode Humanoid : physique standard, non-ancré ───────────────────
        root.Anchored   = false
        root.CanCollide = true
        root.CustomPhysicalProperties = PhysicalProperties.new(50, 0.5, 0, 1, 1)
        marchHumanoid(clone, humanoid :: Humanoid, root)
        print(string.format("[Parade] '%s' HUMANOID  X=%d→%d  Z=%.1f",
            template.Name, START_X, END_X, AVENUE_Z + zOff))
    else
        -- ── Mode Tween : root ancré, TweenService + WeldConstraints ────────
        root.Anchored   = true
        root.CanCollide = false
        -- Repositionner le root à la bonne hauteur (demi-hauteur + offset sol)
        local floorY = FLOOR_Y + root.Size.Y / 2 + SLIDE_Y_OFFSET
        root.CFrame  = CFrame.lookAt(
            Vector3.new(START_X, floorY, AVENUE_Z + zOff),
            Vector3.new(START_X + 1, floorY, AVENUE_Z + zOff)
        )
        marchTween(clone, root)
        print(string.format("[Parade] '%s' TWEEN     X=%d→%d  Z=%.1f",
            template.Name, START_X, END_X, AVENUE_Z + zOff))
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- BOUCLE DE SPAWN INFINIE
-- ══════════════════════════════════════════════════════════════════════════════

task.spawn(function()
    task.wait(3)  -- laisser le serveur finir son initialisation

    local sourceFolder = ReplicatedStorage:WaitForChild("WildBrainrots", 20) :: Folder?
    if not sourceFolder then
        warn("[Parade] ReplicatedStorage.WildBrainrots introuvable après 20s — système désactivé")
        return
    end

    local templates: {Model} = {}
    for _, t in ipairs(sourceFolder:GetChildren()) do
        if t:IsA("Model") then
            table.insert(templates, t :: Model)
        end
    end

    if #templates == 0 then
        warn("[Parade] Aucun Model dans WildBrainrots — rien à défiler")
        return
    end

    print(string.format("[Parade] Démarrage — %d template(s) | X: %d → %d | Z=%.0f | intervalle=%ds",
        #templates, START_X, END_X, AVENUE_Z, SPAWN_INTERVAL))

    -- Premier spawn immédiat, puis intervalle régulier
    spawnParader(templates)

    while true do
        task.wait(SPAWN_INTERVAL)
        spawnParader(templates)
    end
end)

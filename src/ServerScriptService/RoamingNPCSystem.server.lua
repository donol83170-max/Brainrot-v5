-- RoamingNPCSystem.server.lua
-- Brainrots sauvages dans la zone publique (boulevard + fontaine).
-- Source  : ReplicatedStorage.WildBrainrots
-- Cible   : Workspace.WildNPCs
--
-- Deux modes de déplacement détectés automatiquement :
--   • Cas 1 — Modèle AVEC Humanoid  → Humanoid:MoveTo()  (marche physique)
--   • Cas 2 — Modèle SANS Humanoid  → TweenService       (glissement absurde ancré)

local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

-- ══════════════════════════════════════════════════════════════════════════════
-- CONFIG
-- ══════════════════════════════════════════════════════════════════════════════

local NPC_COUNT      = 10   -- PNJ simultanés
local WALK_SPEED     = 8    -- studs/s (mode Humanoid)
local SLIDE_SPEED    = 6    -- studs/s (mode Tween)
local SLIDE_Y_OFFSET = 0.5  -- studs au-dessus du sol pour les objets glissants
local WAIT_MIN       = 2    -- pause min après arrivée (s)
local WAIT_MAX       = 5    -- pause max après arrivée (s)
local MOVE_TIMEOUT   = 12   -- timeout Humanoid:MoveTo (s)
local SPAWN_Y        = 4    -- hauteur de spawn (les physiques posent l'objet ensuite)
local FLOOR_Y        = 1    -- Y du sol de l'avenue

-- Zone publique sécurisée — fontaine Z=110, galeries à Z=78 (sud) et Z=142 (nord)
local ZONE_CX = 0
local ZONE_CZ = 110
local ZONE_HX = 28   -- demi-largeur X (boulevard)
local ZONE_HZ = 22   -- demi-profondeur Z (marge de 8 studs avant les galeries)

-- ══════════════════════════════════════════════════════════════════════════════
-- DOSSIER WORKSPACE
-- ══════════════════════════════════════════════════════════════════════════════

local wildNPCsFolder: Folder
do
    local existing = Workspace:FindFirstChild("WildNPCs")
    if existing and existing:IsA("Folder") then
        wildNPCsFolder = existing :: Folder
    else
        local f = Instance.new("Folder")
        f.Name   = "WildNPCs"
        f.Parent = Workspace
        wildNPCsFolder = f
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- UTILITAIRES
-- ══════════════════════════════════════════════════════════════════════════════

local function randomRoamPos(): Vector3
    local x = ZONE_CX + (math.random() * 2 - 1) * ZONE_HX
    local z = ZONE_CZ + (math.random() * 2 - 1) * ZONE_HZ
    return Vector3.new(x, FLOOR_Y, z)
end

-- CFrame orientée vers la cible, Y conservé (pas d'inclinaison)
local function lookAtFlat(from: Vector3, to: Vector3): CFrame
    local dir = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
    if dir.Magnitude < 0.01 then
        return CFrame.new(from)
    end
    return CFrame.lookAt(from, from + dir)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- CAS 1 : PRÉPARATION DU PNJ AVEC HUMANOID
-- Soude toutes les parts au root, dédesancre le root, configure le Humanoid.
-- ══════════════════════════════════════════════════════════════════════════════

local function prepareHumanoidNPC(model: Model, humanoid: Humanoid): BasePart?
    -- Trouver ou désigner le HumanoidRootPart
    local rootPart: BasePart? = model:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not rootPart then
        local candidate: BasePart? = model.PrimaryPart
                                  or model:FindFirstChildWhichIsA("BasePart", true) :: BasePart?
        if not candidate then
            -- Crée un root invisible de secours
            local rp = Instance.new("Part")
            rp.Name         = "HumanoidRootPart"
            rp.Size         = Vector3.new(2, 2, 1)
            rp.Transparency = 1
            rp.CanCollide   = false
            rp.Parent       = model
            candidate = rp
        end
        candidate.Name = "HumanoidRootPart"
        rootPart = candidate
    end

    if not model.PrimaryPart then
        model.PrimaryPart = rootPart
    end

    -- Souder toutes les autres BasePart au root (elles suivront la physique)
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") and part ~= rootPart then
            local alreadyWelded = false
            for _, child in ipairs(part:GetChildren()) do
                if child:IsA("WeldConstraint") or child:IsA("Weld") then
                    alreadyWelded = true ; break
                end
            end
            if not alreadyWelded then
                local wc   = Instance.new("WeldConstraint")
                wc.Part0   = rootPart :: BasePart
                wc.Part1   = part :: BasePart
                wc.Parent  = rootPart :: BasePart
            end
            part.Anchored = false
        end
    end

    rootPart.Anchored   = false
    rootPart.CanCollide = true
    -- Masse élevée : difficile à pousser par les joueurs
    rootPart.CustomPhysicalProperties = PhysicalProperties.new(50, 0.5, 0, 1, 1)

    -- Config Humanoid
    humanoid.MaxHealth = 1e9
    humanoid.Health    = 1e9
    humanoid.WalkSpeed = WALK_SPEED
    humanoid.JumpPower = 0
    humanoid.AutoRotate = true
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead,        false)
    humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,     false)

    return rootPart
end

-- ══════════════════════════════════════════════════════════════════════════════
-- CAS 2 : PRÉPARATION DE L'OBJET INANIMÉ (SANS HUMANOID)
-- Tout est ancré ; TweenService déplacera le PrimaryPart.CFrame.
-- ══════════════════════════════════════════════════════════════════════════════

local function prepareStaticNPC(model: Model): BasePart?
    -- Désigner un PrimaryPart si absent
    local root: BasePart? = model.PrimaryPart
                         or model:FindFirstChildWhichIsA("BasePart", true) :: BasePart?
    if not root then
        warn(string.format("[WildNPC][Tween] '%s' n'a aucun BasePart — ignoré", model.Name))
        return nil
    end

    if not model.PrimaryPart then
        model.PrimaryPart = root
    end

    -- Ancrer TOUTES les parts (le Tween s'occupera du mouvement via PivotTo)
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored   = true
            part.CanCollide = false
        end
    end
    root.Anchored   = true
    root.CanCollide = false

    return root
end

-- ══════════════════════════════════════════════════════════════════════════════
-- CAS 1 : BOUCLE DE PATROUILLE AVEC HUMANOID
-- ══════════════════════════════════════════════════════════════════════════════

local function roamHumanoid(model: Model, humanoid: Humanoid)
    task.spawn(function()
        while model.Parent ~= nil and humanoid.Parent ~= nil do
            local target = randomRoamPos()
            humanoid:MoveTo(target)

            -- Attendre MoveToFinished ou timeout
            local done = false
            local conn: RBXScriptConnection
            conn = humanoid.MoveToFinished:Connect(function(_: boolean)
                done = true
                conn:Disconnect()
            end)

            local elapsed = 0
            while not done and elapsed < MOVE_TIMEOUT do
                task.wait(0.5)
                elapsed += 0.5
            end
            if not done then pcall(function() conn:Disconnect() end) end

            -- Pause aléatoire avant la prochaine destination
            task.wait(WAIT_MIN + math.random() * (WAIT_MAX - WAIT_MIN))
        end
    end)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- CAS 2 : BOUCLE DE GLISSEMENT ABSURDE (TWEEN, SANS HUMANOID)
-- Utilise un CFrameValue intermédiaire pour piloter model:PivotTo() via Tween.
-- ══════════════════════════════════════════════════════════════════════════════

local function roamTween(model: Model)
    task.spawn(function()
        while model.Parent ~= nil do
            local currentPivot = model:GetPivot()
            local targetPos    = randomRoamPos() + Vector3.new(0, SLIDE_Y_OFFSET, 0)

            -- Durée proportionnelle à la distance (vitesse constante)
            local dist     = (targetPos - currentPivot.Position).Magnitude
            local duration = math.max(dist / SLIDE_SPEED, 0.5)

            -- CFrame cible : position au sol + orientation face à la destination
            local targetCF = lookAtFlat(targetPos, targetPos + (targetPos - currentPivot.Position))

            -- Intermédiaire CFrameValue (seul type twenable pour piloter PivotTo)
            local cfv = Instance.new("CFrameValue")
            cfv.Value  = currentPivot
            cfv.Parent = model

            -- Connexion Changed → PivotTo synchrone avec le tween
            local conn = cfv.Changed:Connect(function(cf: CFrame)
                if model.Parent then
                    model:PivotTo(cf)
                end
            end)

            local tween = TweenService:Create(
                cfv,
                TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                { Value = targetCF }
            )
            tween:Play()
            tween.Completed:Wait()

            -- Nettoyage
            conn:Disconnect()
            cfv:Destroy()

            -- Pause aléatoire sur place
            task.wait(WAIT_MIN + math.random() * (WAIT_MAX - WAIT_MIN))
        end
    end)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- INVINCIBILITÉ (uniquement pour les PNJ à Humanoid)
-- ══════════════════════════════════════════════════════════════════════════════

local function watchInvincibility(humanoid: Humanoid)
    task.spawn(function()
        while humanoid.Parent ~= nil do
            if humanoid.Health < humanoid.MaxHealth * 0.99 then
                humanoid.Health = humanoid.MaxHealth
            end
            task.wait(0.5)
        end
    end)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- SPAWN
-- ══════════════════════════════════════════════════════════════════════════════

local function spawnAllNPCs(sourceFolder: Folder)
    -- Filtrer les Model valides
    local templates: {Model} = {}
    for _, t in ipairs(sourceFolder:GetChildren()) do
        if t:IsA("Model") then
            table.insert(templates, t :: Model)
        else
            warn(string.format("[WildNPC] '%s' (%s) ignoré — doit être un Model", t.Name, t.ClassName))
        end
    end

    if #templates == 0 then
        warn("[WildNPC] Aucun Model dans WildBrainrots — rien à spawner")
        return
    end

    print(string.format("[WildNPC] Spawn de %d PNJ depuis %d template(s)…", NPC_COUNT, #templates))

    for i = 1, NPC_COUNT do
        local template = templates[((i - 1) % #templates) + 1]
        local clone    = template:Clone()

        -- Spawn légèrement au-dessus du sol (gravité ou tween ajusteront)
        local spawnPos = randomRoamPos() + Vector3.new(0, SPAWN_Y, 0)
        clone:PivotTo(CFrame.new(spawnPos))
        clone.Parent = wildNPCsFolder

        -- ── Détection automatique du mode ────────────────────────────────────
        local humanoid: Humanoid? = clone:FindFirstChildWhichIsA("Humanoid", true) :: Humanoid?

        if humanoid then
            -- ── CAS 1 : Personnage avec Humanoid ─────────────────────────────
            local root = prepareHumanoidNPC(clone, humanoid :: Humanoid)
            if root then
                roamHumanoid(clone, humanoid :: Humanoid)
                watchInvincibility(humanoid :: Humanoid)
                print(string.format("[WildNPC] #%d '%s' → mode HUMANOID spawné à (%.0f,%.0f,%.0f)",
                    i, template.Name, spawnPos.X, spawnPos.Y, spawnPos.Z))
            else
                warn(string.format("[WildNPC] #%d '%s' : root introuvable après prepareHumanoidNPC", i, template.Name))
            end
        else
            -- ── CAS 2 : Objet inanimé → Tween glissant ───────────────────────
            local root = prepareStaticNPC(clone)
            if root then
                roamTween(clone)
                print(string.format("[WildNPC] #%d '%s' → mode TWEEN spawné à (%.0f,%.0f,%.0f)",
                    i, template.Name, spawnPos.X, spawnPos.Y, spawnPos.Z))
            else
                warn(string.format("[WildNPC] #%d '%s' : impossible de préparer (aucun BasePart)", i, template.Name))
            end
        end

        task.wait(0.2) -- petit délai inter-spawn pour ne pas surcharger
    end

    print(string.format("[WildNPC] %d PNJ actifs | zone Z=%.0f±%.0f X=%.0f±%.0f",
        NPC_COUNT, ZONE_CZ, ZONE_HZ, ZONE_CX, ZONE_HX))
end

-- ══════════════════════════════════════════════════════════════════════════════
-- DÉMARRAGE
-- ══════════════════════════════════════════════════════════════════════════════

task.spawn(function()
    task.wait(2) -- laisse ReplicatedStorage se peupler

    local folder = ReplicatedStorage:WaitForChild("WildBrainrots", 20) :: Folder?
    if not folder then
        warn("[WildNPC] ReplicatedStorage.WildBrainrots introuvable après 20s — système désactivé")
        return
    end

    local children = folder:GetChildren()
    print(string.format("[WildNPC] WildBrainrots chargé — %d enfant(s) :", #children))
    for _, c in ipairs(children) do
        print(string.format("   → '%s' (%s)", c.Name, c.ClassName))
    end

    spawnAllNPCs(folder :: Folder)
end)

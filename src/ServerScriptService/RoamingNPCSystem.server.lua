-- RoamingNPCSystem.server.lua
-- !! DÉSACTIVÉ TEMPORAIREMENT — retirer le `return` ci-dessous pour réactiver !!
do return end

-- Brainrots sauvages dans la zone publique (boulevard + fontaine).
-- Source  : ReplicatedStorage.WildBrainrots
-- Cible   : Workspace.WildNPCs
--
-- Deux modes de déplacement détectés automatiquement :
--   • Cas 1 — Modèle AVEC Humanoid  → Humanoid:MoveTo()  (marche physique)
--   • Cas 2 — Modèle SANS Humanoid  → TweenService       (glissement ancré)

local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

-- ══════════════════════════════════════════════════════════════════════════════
-- CONFIG MOUVEMENT
-- ══════════════════════════════════════════════════════════════════════════════

local NPC_COUNT      = 10   -- PNJ simultanés
local WALK_SPEED     = 8    -- studs/s (mode Humanoid)
local SLIDE_SPEED    = 6    -- studs/s (mode Tween)
local SLIDE_Y_OFFSET = 0.5  -- studs au-dessus du sol pour les objets glissants
local WAIT_MIN       = 2    -- pause min après arrivée (s)
local WAIT_MAX       = 5    -- pause max après arrivée (s)
local MOVE_TIMEOUT   = 12   -- timeout Humanoid:MoveTo (s)
local SPAWN_Y        = 4    -- hauteur de spawn (physique pose ensuite)
local FLOOR_Y        = 1    -- Y du sol de l'avenue

-- ══════════════════════════════════════════════════════════════════════════════
-- ZONE DE ROAMING PRINCIPALE
-- Couvre toute la longueur de l'avenue : casino (Z≈-20) jusqu'aux entrées galeries
-- Z=110 ± 90 → de Z=-30 à Z=150  /  X ± 45 → boulevard complet
-- Les zones interdites (blacklist) gèrent les exclusions fines.
-- ══════════════════════════════════════════════════════════════════════════════

local ZONE_CX = 0
local ZONE_CZ = 60    -- centre décalé vers le sud pour couvrir casino + avenue
local ZONE_HX = 45    -- demi-largeur X (boulevard large)
local ZONE_HZ = 90    -- demi-profondeur Z → de Z=-30 à Z=150

-- ══════════════════════════════════════════════════════════════════════════════
-- ZONES D'EXCLUSION (BLACKLIST)
-- Format : { cx, cz, rx, rz }
--   → AABB centré en (cx, cz) avec demi-dimensions (rx, rz)
--   → Un point est interdit si |pos.X - cx| < rx ET |pos.Z - cz| < rz
--
-- ⚙ GALERIES : calculées depuis BrainrotGallery (CORRIDOR_W=44, PLOT_STEP=52)
--   Entrée nord Z=142, entrée sud Z=78, plots à offsetX = 0, ±52, ±104…
--   Marge de sécurité : +18 studs côté avenue
--
-- ⚙ CASINO / SPAWN / ÉCHANGE : ajuster (cx, cz) selon la carte réelle
-- ══════════════════════════════════════════════════════════════════════════════

local FORBIDDEN_ZONES: {{cx: number, cz: number, rx: number, rz: number}} = {

    -- ── Entrées galeries NORD (Z = 142, galerie va vers +Z) ─────────────────
    -- Marge côté boulevard : de Z=126 à Z=166 (±20 autour de 146)
    { cx =    0, cz = 146, rx = 28, rz = 20 },  -- plot 1  (offsetX=0)
    { cx =   52, cz = 146, rx = 28, rz = 20 },  -- plot 3  (offsetX=+52)
    { cx =  -52, cz = 146, rx = 28, rz = 20 },  -- plot 5  (offsetX=-52)
    { cx =  104, cz = 146, rx = 28, rz = 20 },  -- plot 7  (offsetX=+104)
    { cx = -104, cz = 146, rx = 28, rz = 20 },  -- plot 9  (offsetX=-104)

    -- ── Entrées galeries SUD (Z = 78, galerie va vers -Z) ───────────────────
    -- Marge côté boulevard : de Z=58 à Z=98 (±20 autour de 74)
    { cx =    0, cz =  74, rx = 28, rz = 20 },  -- plot 2  (offsetX=0)
    { cx =   52, cz =  74, rx = 28, rz = 20 },  -- plot 4  (offsetX=+52)
    { cx =  -52, cz =  74, rx = 28, rz = 20 },  -- plot 6  (offsetX=-52)
    { cx =  104, cz =  74, rx = 28, rz = 20 },  -- plot 8  (offsetX=+104)
    { cx = -104, cz =  74, rx = 28, rz = 20 },  -- plot 10 (offsetX=-104)

    -- ── Casino / Roue de spin ────────────────────────────────────────────────
    { cx =   0, cz = -20, rx = 15, rz = 15 },

    -- ── Machine d'Échange ────────────────────────────────────────────────────
    { cx = -25, cz =   0, rx = 10, rz = 10 },

    -- ── Machine (X=40, Z=0) ──────────────────────────────────────────────────
    { cx =  40, cz =   0, rx = 12, rz = 12 },

    -- ── Zone Spawn (départ joueurs) ──────────────────────────────────────────
    { cx =   0, cz = 110, rx = 10, rz = 10 },
}

-- Distance minimale entre deux NPCs (évite les regroupements)
local MIN_NPC_DIST   = 10
-- Nombre max de tentatives pour trouver une destination valide
local MAX_DEST_TRIES = 15

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
-- RAYCAST SOL
-- ══════════════════════════════════════════════════════════════════════════════

-- Paramètres raycast : exclut les PNJ eux-mêmes pour ne toucher que le décor
local RC_PARAMS = RaycastParams.new()
RC_PARAMS.FilterType = Enum.RaycastFilterType.Exclude
RC_PARAMS.FilterDescendantsInstances = {wildNPCsFolder}

-- Retourne le Y exact du sol à (x, z) + demi-hauteur du root + offset de glissement
local function findFloorY(x: number, z: number, halfHeight: number): number
    local origin    = Vector3.new(x, 500, z)
    local direction = Vector3.new(0, -1000, 0)
    local result    = Workspace:Raycast(origin, direction, RC_PARAMS)
    if result then
        return result.Position.Y + halfHeight + SLIDE_Y_OFFSET
    end
    return FLOOR_Y + halfHeight + SLIDE_Y_OFFSET  -- fallback si aucun sol trouvé
end

-- ══════════════════════════════════════════════════════════════════════════════
-- UTILITAIRES : GÉNÉRATION DE DESTINATION
-- ══════════════════════════════════════════════════════════════════════════════

-- Génère un point brut dans la zone de roaming principale
local function randomRoamPos(): Vector3
    local x = ZONE_CX + (math.random() * 2 - 1) * ZONE_HX
    local z = ZONE_CZ + (math.random() * 2 - 1) * ZONE_HZ
    return Vector3.new(x, FLOOR_Y, z)
end

-- Valide qu'une position n'est dans aucune zone interdite
-- et qu'elle est à plus de MIN_NPC_DIST studs de chaque NPC actif
local function isValidDestination(pos: Vector3): boolean
    -- Vérification blacklist zones
    for _, zone in ipairs(FORBIDDEN_ZONES) do
        if math.abs(pos.X - zone.cx) < zone.rx
        and math.abs(pos.Z - zone.cz) < zone.rz then
            return false
        end
    end
    -- Vérification distanciation sociale entre NPCs
    for _, npc in ipairs(wildNPCsFolder:GetChildren()) do
        if npc:IsA("Model") then
            local root: BasePart? = npc.PrimaryPart
                                 or npc:FindFirstChildWhichIsA("BasePart", true) :: BasePart?
            if root then
                local dx = pos.X - root.Position.X
                local dz = pos.Z - root.Position.Z
                if (dx * dx + dz * dz) < MIN_NPC_DIST * MIN_NPC_DIST then
                    return false
                end
            end
        end
    end
    return true
end

-- Génère une destination valide avec recalcul si elle tombe en zone interdite
local function safeRoamPos(): Vector3
    for _ = 1, MAX_DEST_TRIES do
        local pos = randomRoamPos()
        if isValidDestination(pos) then
            return pos
        end
    end
    -- Fallback garanti : centre de l'avenue, toujours valide
    warn("[WildNPC] safeRoamPos: aucune destination valide trouvée — retour au centre")
    return Vector3.new(ZONE_CX, FLOOR_Y, ZONE_CZ)
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
-- OPTIMISATION PHYSIQUE COMMUNE AUX DEUX MODES
-- • Un seul BasePart (root) simulé par le moteur
-- • Toutes les autres parts : soudées au root + mode fantôme (zéro coût physique)
-- ══════════════════════════════════════════════════════════════════════════════

local function optimizeModel(model: Model): BasePart?
    -- Trouver ou créer un root (hitbox invisible)
    local root: BasePart? = model.PrimaryPart
                         or model:FindFirstChild("HumanoidRootPart") :: BasePart?
                         or model:FindFirstChildWhichIsA("BasePart", true) :: BasePart?
    if not root then
        local rp          = Instance.new("Part")
        rp.Name           = "HumanoidRootPart"
        rp.Size           = Vector3.new(2, 2, 2)
        rp.Transparency   = 1
        rp.CanCollide     = false
        rp.CastShadow     = false
        rp.Parent         = model
        root              = rp
    end
    model.PrimaryPart = root :: BasePart

    -- Souder toutes les autres parts au root + mode fantôme
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") and part ~= root then
            -- Fantôme : zéro collision, zéro masse, zéro raycasting
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
-- CAS 1 : PRÉPARATION DU PNJ AVEC HUMANOID
-- ══════════════════════════════════════════════════════════════════════════════

local function prepareHumanoidNPC(model: Model, humanoid: Humanoid): BasePart?
    local root = optimizeModel(model)
    if not root then return nil end

    -- Root non-ancré : la physique Humanoid prend le relai
    root.Anchored   = false
    root.CanCollide = true
    root.CustomPhysicalProperties = PhysicalProperties.new(50, 0.5, 0, 1, 1)
    if not model:FindFirstChild("HumanoidRootPart") then
        root.Name = "HumanoidRootPart"
    end

    humanoid.MaxHealth  = 1e9
    humanoid.Health     = 1e9
    humanoid.WalkSpeed  = WALK_SPEED
    humanoid.JumpPower  = 0
    humanoid.AutoRotate = true
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead,        false)
    humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,     false)

    return root
end

-- ══════════════════════════════════════════════════════════════════════════════
-- CAS 2 : PRÉPARATION DE L'OBJET INANIMÉ (SANS HUMANOID)
-- ══════════════════════════════════════════════════════════════════════════════

local function prepareStaticNPC(model: Model): BasePart?
    local root = optimizeModel(model)
    if not root then
        warn(string.format("[WildNPC][Tween] '%s' n'a aucun BasePart — ignoré", model.Name))
        return nil
    end
    -- Root ancré : TweenService animera root.CFrame directement
    -- Les WeldConstraints propagent le mouvement aux autres parts (moteur, pas script)
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
            local target = safeRoamPos()
            humanoid:MoveTo(target)

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

            task.wait(WAIT_MIN + math.random() * (WAIT_MAX - WAIT_MIN))
        end
    end)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- CAS 2 : BOUCLE DE GLISSEMENT (TWEEN, SANS HUMANOID)
-- Tween direct sur root.CFrame (root est Anchored).
-- Les WeldConstraints propagent le mouvement à toutes les parts côté moteur —
-- zéro signal Lua, zéro PivotTo, zéro overhead scripteur par frame.
-- ══════════════════════════════════════════════════════════════════════════════

local function roamTween(model: Model, root: BasePart)
    task.spawn(function()
        while model.Parent ~= nil and root.Parent ~= nil do
            local currentPos = root.CFrame.Position

            -- Destination XZ valide + Y exact du sol via Raycast
            local raw       = safeRoamPos()
            local floorY    = findFloorY(raw.X, raw.Z, root.Size.Y / 2)
            local targetPos = Vector3.new(raw.X, floorY, raw.Z)

            local dist     = (targetPos - currentPos).Magnitude
            local duration = math.max(dist / SLIDE_SPEED, 0.5)

            -- CFrame orienté face au sens du déplacement, Y plat (pas d'inclinaison)
            local dir      = Vector3.new(raw.X - currentPos.X, 0, raw.Z - currentPos.Z)
            local targetCF = if dir.Magnitude > 0.01
                                then CFrame.new(targetPos, targetPos + dir)
                                else CFrame.new(targetPos)

            local tween = TweenService:Create(
                root,
                TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                { CFrame = targetCF }
            )
            tween:Play()
            tween.Completed:Wait()
            tween:Destroy()

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

        -- Parent EN PREMIER : PivotTo est ignoré par Roblox sur un modèle non parenté
        clone.Parent = wildNPCsFolder
        local spawnPos = safeRoamPos() + Vector3.new(0, SPAWN_Y, 0)
        clone:PivotTo(CFrame.new(spawnPos))

        local humanoid: Humanoid? = clone:FindFirstChildWhichIsA("Humanoid", true) :: Humanoid?

        if humanoid then
            local root = prepareHumanoidNPC(clone, humanoid :: Humanoid)
            if root then
                roamHumanoid(clone, humanoid :: Humanoid)
                watchInvincibility(humanoid :: Humanoid)
                print(string.format("[WildNPC] #%d '%s' → HUMANOID (%.0f, %.0f)",
                    i, template.Name, spawnPos.X, spawnPos.Z))
            else
                warn(string.format("[WildNPC] #%d '%s' : root introuvable", i, template.Name))
            end
        else
            local root = prepareStaticNPC(clone)
            if root then
                roamTween(clone, root)
                print(string.format("[WildNPC] #%d '%s' → TWEEN (%.0f, %.0f)",
                    i, template.Name, spawnPos.X, spawnPos.Z))
            else
                warn(string.format("[WildNPC] #%d '%s' : aucun BasePart", i, template.Name))
            end
        end

        task.wait(0.2)
    end

    print(string.format("[WildNPC] %d PNJ actifs | zone X=%.0f±%.0f  Z=%.0f±%.0f | %d zones interdites",
        NPC_COUNT, ZONE_CX, ZONE_HX, ZONE_CZ, ZONE_HZ, #FORBIDDEN_ZONES))
end

-- ══════════════════════════════════════════════════════════════════════════════
-- DÉMARRAGE
-- ══════════════════════════════════════════════════════════════════════════════

task.spawn(function()
    task.wait(2)

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

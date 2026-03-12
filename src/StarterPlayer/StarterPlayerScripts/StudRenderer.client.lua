--!strict
-- StudRenderer.client.lua  (LocalScript — StarterPlayerScripts)
--
-- Rendu LEGO 100 % côté client — zéro réplication réseau.
-- Cible : Workspace/Map/Environment/LegoGround_3D  (créé par LevelGenerator)
--
-- Flux :
--   1. Attend Map → Environment → LegoGround_3D (généré côté serveur).
--   2. Collecte toutes les dalles qualifiées (GrassBase_* et surfaces Avenue/Road).
--   3. Boucle toutes les SCAN_INTERVAL s : charge à < LOAD_DIST, cache à > UNLOAD_DIST.
--
-- SYSTÈME DE CACHE (zéro Destroy pendant le jeu) :
--   • studFolders[part] = dossier actuellement visible dans Workspace.
--   • chunkCache[part]  = dossier généré mais masqué (Parent = nil).
--   → Revenir sur ses pas est instantané : on remet juste le Parent.
--   → Destroy() uniquement si la dalle source disparaît (scan de purge).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")

local LegoRenderer = require(ReplicatedStorage:WaitForChild("LegoRenderer"))

local player = Players.LocalPlayer

-- ══════════════════════════════════════════════════════════════════════════════
-- CONFIG
-- ══════════════════════════════════════════════════════════════════════════════
local LOAD_DIST        = 120   -- affiche le chunk si la dalle est à < 120 studs
local UNLOAD_DIST      = 150   -- cache si à > 150 studs (hysteresis)
local SCAN_INTERVAL    = 0.5   -- fréquence de la boucle de culling (s)
local MAX_NEW_PER_CYCLE = 3    -- nouvelles générations max par cycle
local SPAWN_SMOOTH_WAIT = 0.1  -- pause entre chaque lancement de génération

-- ══════════════════════════════════════════════════════════════════════════════
-- ÉTAT
-- ══════════════════════════════════════════════════════════════════════════════
-- studFolders : dossier VISIBLE (parent dans Workspace)
local studFolders: {[BasePart]: Folder}  = {}
-- chunkCache  : dossier généré mais CACHÉ (parent = nil)
local chunkCache:  {[BasePart]: Folder}  = {}
-- rendering   : verrou pour éviter les doublons de génération
local rendering:   {[BasePart]: boolean} = {}
local qualifiedParts: {BasePart}         = {}

-- ══════════════════════════════════════════════════════════════════════════════
-- QUALIFICATION D'UNE PART
-- ══════════════════════════════════════════════════════════════════════════════
local function qualifies(part: BasePart): boolean
    if part.Transparency > 0.5 then return false end
    local sz = part.Size
    if sz.X < 4 or sz.Z < 4 then return false end
    local nm = string.upper(part.Name)
    return string.find(nm, "GRASSBASE") ~= nil
        or string.find(nm, "AVENUE")   ~= nil
        or string.find(nm, "ROAD")     ~= nil
        or string.find(nm, "STREET")   ~= nil
end

local function detectFace(part: BasePart): string
    if string.find(string.upper(part.Name), "WALL") then return "Front" end
    return "Top"
end

-- ══════════════════════════════════════════════════════════════════════════════
-- SCAN — remplit qualifiedParts depuis le dossier LegoGround_3D
-- ══════════════════════════════════════════════════════════════════════════════
local _groundFolder: Instance? = nil

local function scanParts()
    table.clear(qualifiedParts)
    local root = _groundFolder
    if not root then return end

    for _, desc in ipairs(root:GetDescendants()) do
        if desc:IsA("BasePart") and desc.Parent ~= nil then
            if qualifies(desc :: BasePart) then
                table.insert(qualifiedParts, desc :: BasePart)
            end
        end
    end

    -- Purger les entrées orphelines (dalles supprimées depuis le dernier scan)
    for part in pairs(studFolders) do
        if part.Parent == nil then
            local f = studFolders[part]
            if f then f:Destroy() end
            studFolders[part] = nil :: any
        end
    end
    for part in pairs(chunkCache) do
        if part.Parent == nil then
            local f = chunkCache[part]
            if f then f:Destroy() end
            chunkCache[part] = nil :: any
        end
    end

    print(string.format("[StudRenderer] Scan : %d dalles qualifiées", #qualifiedParts))
end

-- ══════════════════════════════════════════════════════════════════════════════
-- SHOW / HIDE — avec cache
-- ══════════════════════════════════════════════════════════════════════════════

-- Affiche le chunk d'une dalle :
--   • Si dans le cache → restaure le Parent (instantané, 0 lag).
--   • Sinon → génère via LegoRenderer.AutoStud et stocke dans studFolders.
local function showChunk(part: BasePart)
    if rendering[part] or studFolders[part] then return end

    -- ── Cas cache hit : réactivation instantanée ──────────────────────────
    local cached = chunkCache[part]
    if cached then
        cached.Parent     = part.Parent
        studFolders[part] = cached
        chunkCache[part]  = nil :: any
        return
    end

    -- ── Cas cache miss : première génération (async) ──────────────────────
    rendering[part] = true

    task.spawn(function()
        if part.Parent == nil then
            rendering[part] = nil :: any
            return
        end

        local ok, result = pcall(function()
            return LegoRenderer.AutoStud(part, { face = detectFace(part) })
        end)

        rendering[part] = nil :: any

        if ok and result ~= nil then
            local folder = result :: Folder
            if folder.Parent ~= nil then
                studFolders[part] = folder
            end
        elseif not ok then
            warn(string.format("[StudRenderer] Erreur '%s': %s", part.Name, tostring(result)))
        end
    end)
end

-- Cache le chunk d'une dalle : Parent → nil, entrée dans chunkCache.
-- Aucun Destroy() → retour instantané si le joueur revient.
local function hideChunk(part: BasePart)
    local folder = studFolders[part]
    if not folder then return end

    folder.Parent    = nil        -- retire du Workspace sans détruire
    chunkCache[part] = folder     -- mémorise pour réactivation future
    studFolders[part] = nil :: any
end

-- ══════════════════════════════════════════════════════════════════════════════
-- BOUCLE DE CULLING
-- ══════════════════════════════════════════════════════════════════════════════
local function cullLoop()
    local lastRescan = 0

    while true do
        task.wait(SCAN_INTERVAL)

        -- Rescan toutes les 60 s
        if (os.clock() - lastRescan) >= 60 then
            scanParts()
            lastRescan = os.clock()
        end

        -- Position de référence : HumanoidRootPart, fallback caméra
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
        local origin = if root
            then root.Position
            else Workspace.CurrentCamera.CFrame.Position

        type Entry = { part: BasePart, dist: number }
        local toShow: {Entry} = {}

        for _, part in ipairs(qualifiedParts) do
            if part.Parent == nil then continue end
            local dist = (part.Position - origin).Magnitude

            if dist < LOAD_DIST then
                -- Besoin d'afficher — seulement si pas déjà visible
                if not studFolders[part] and not rendering[part] then
                    table.insert(toShow, { part = part, dist = dist })
                end
            elseif dist > UNLOAD_DIST then
                -- Trop loin → cacher (pas détruire)
                hideChunk(part)
            end
        end

        -- Trier par distance (plus proche = priorité)
        table.sort(toShow, function(a, b) return a.dist < b.dist end)

        -- Lancement lissé : pause entre chaque chunk pour éviter les spikes
        local launched = 0
        for _, entry in ipairs(toShow) do
            if launched >= MAX_NEW_PER_CYCLE then break end
            showChunk(entry.part)
            launched += 1
            task.wait(SPAWN_SMOOTH_WAIT)   -- respiration entre chaque lancement
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- DÉMARRAGE — suit le chemin Map/Environment/LegoGround_3D
-- ══════════════════════════════════════════════════════════════════════════════
task.spawn(function()
    if not player.Character then
        player.CharacterAdded:Wait()
    end

    local mapFolder = Workspace:WaitForChild("Map", 30)
    if not mapFolder then
        warn("[StudRenderer] Workspace.Map introuvable après 30s — rendu annulé")
        return
    end

    local envFolder = mapFolder:WaitForChild("Environment", 20)
    if not envFolder then
        warn("[StudRenderer] Map.Environment introuvable — rendu annulé")
        return
    end

    local groundFolder = envFolder:WaitForChild("LegoGround_3D", 30)
    if not groundFolder then
        warn("[StudRenderer] LegoGround_3D introuvable après 30s — rendu annulé")
        return
    end

    -- Laisser le task.spawn serveur finir de peupler les dalles
    task.wait(3)

    _groundFolder = groundFolder
    scanParts()

    if #qualifiedParts == 0 then
        warn("[StudRenderer] Aucune dalle GrassBase trouvée dans LegoGround_3D")
        return
    end

    print(string.format(
        "[StudRenderer] Démarrage | LOAD=%d UNLOAD=%d | %d dalles | cache actif",
        LOAD_DIST, UNLOAD_DIST, #qualifiedParts))

    cullLoop()
end)

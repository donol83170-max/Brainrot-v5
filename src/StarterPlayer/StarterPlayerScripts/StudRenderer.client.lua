--!strict
-- StudRenderer.client.lua  (LocalScript — StarterPlayerScripts)
--
-- Rendu LEGO 100 % côté client — zéro réplication réseau.
-- Recherche universelle via workspace:GetDescendants() — ne se bloque jamais.
--
-- SYSTÈME DE CACHE :
--   chunkCache[part] = { folder = Folder, visible = boolean }
--   • Première visite  → LegoRenderer.AutoStud() + stockage dans le cache.
--   • Retour en zone   → folder.Parent restauré (instantané, 0 clone).
--   • Hors zone        → folder.Parent = nil (0 Destroy).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")

local LegoRenderer = require(ReplicatedStorage:WaitForChild("LegoRenderer", 30))

local player = Players.LocalPlayer

-- ══════════════════════════════════════════════════════════════════════════════
-- CONFIG
-- ══════════════════════════════════════════════════════════════════════════════
local LOAD_DIST   = 50000  -- toute la map est toujours chargée
local UNLOAD_DIST = 60000  -- désactivé en pratique (jamais atteint)
local LOOP_WAIT   = 2      -- boucle de maintien allégée (2 s)

-- ══════════════════════════════════════════════════════════════════════════════
-- CACHE
-- ══════════════════════════════════════════════════════════════════════════════
type CacheEntry = { folder: Folder, visible: boolean }
local chunkCache: { [BasePart]: CacheEntry } = {}
local generating: { [BasePart]: boolean }    = {}

-- ══════════════════════════════════════════════════════════════════════════════
-- RECHERCHE UNIVERSELLE — scan complet du Workspace
-- ══════════════════════════════════════════════════════════════════════════════


-- ══════════════════════════════════════════════════════════════════════════════
-- POSITION DE RÉFÉRENCE
-- ══════════════════════════════════════════════════════════════════════════════
local function getOrigin(): Vector3
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    return if root then root.Position else Workspace.CurrentCamera.CFrame.Position
end

-- ══════════════════════════════════════════════════════════════════════════════
-- SHOW / HIDE
-- ══════════════════════════════════════════════════════════════════════════════
local function getFace(part: BasePart): string
    if string.find(string.upper(part.Name), "WALL") then return "Front" end
    return "Top"
end

-- Affiche un chunk : cache hit = reparent instantané / cache miss = génération async
local function showChunk(part: BasePart)
    if generating[part] then return end

    local entry = chunkCache[part]

    -- ── Cache hit visible : rien à faire ──────────────────────────────────
    if entry and entry.visible then return end

    -- ── Cache hit caché : restauration instantanée ────────────────────────
    if entry and not entry.visible then
        -- Vérifier que le dossier n'est pas déjà dans le Workspace
        -- (sécurité si Parent a été modifié hors du cache)
        if entry.folder.Parent == nil then
            entry.folder.Parent = part.Parent
        end
        entry.visible = true
        return
    end

    -- ── Vérification : le dossier existe peut-être déjà dans le Workspace ─
    -- (cas d'un double appel pendant la génération async)
    if part.Parent then
        local existing = part.Parent:FindFirstChild("LegoTiles_" .. part.Name)
        if existing and existing:IsA("Folder") then
            chunkCache[part] = { folder = existing :: Folder, visible = true }
            return
        end
    end

    -- ── Verrou anti-doublon strict ─────────────────────────────────────────
    -- Vérification physique dans le Workspace : si "LegoTiles_<name>" existe déjà,
    -- on ne génère pas un second clone superposé.
    if part.Parent then
        local existing = part.Parent:FindFirstChild("LegoTiles_" .. part.Name)
        if existing and existing:IsA("Folder") then
            chunkCache[part] = { folder = existing :: Folder, visible = true }
            return
        end
    end

    -- ── Cache miss : première génération ──────────────────────────────────
    generating[part] = true
    task.spawn(function()
        if part.Parent == nil then
            generating[part] = nil :: any
            return
        end

        local ok, result = pcall(function()
            return LegoRenderer.AutoStud(part, { face = getFace(part) })
        end)

        generating[part] = nil :: any

        if ok and result ~= nil then
            local folder = result :: Folder
            if folder.Parent ~= nil then
                chunkCache[part] = { folder = folder, visible = true }
                -- Supprimer la dalle source côté client : le FloorBlock prend le relais.
                -- Aucun impact réseau (LocalScript) — élimine toute superposition résiduelle.
                pcall(function() part:Destroy() end)
            end
        else
            warn(string.format("[StudRenderer] Erreur '%s': %s",
                part.Name, tostring(result)))
        end
    end)
end

-- Cache un chunk sans le détruire — garde-fou : ne cache que si visible
local function hideChunk(part: BasePart)
    local entry = chunkCache[part]
    if not entry then return end
    if not entry.visible then return end          -- déjà caché, rien à faire
    if entry.folder.Parent == nil then            -- déjà orphelin
        entry.visible = false
        return
    end
    entry.folder.Parent = nil
    entry.visible = false
end

local function processBasePart(inst: Instance)
    if not inst:IsA("BasePart") then return end
    local sz = inst.Size
    if sz.X < 4 or sz.Z < 4 then return end
    
    local nm = string.upper(inst.Name)
    if string.find(nm, "GRASSBASE") or string.find(nm, "AVENUE")
        or string.find(nm, "ROAD") or string.find(nm, "STREET") then
        
        local bp = inst :: BasePart
        bp.Transparency = 1
        bp.CastShadow   = false
        bp.Material     = Enum.Material.SmoothPlastic
        bp.Color        = Color3.new(0, 0, 0)
        
        showChunk(bp)
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- DÉMARRAGE
-- ══════════════════════════════════════════════════════════════════════════════
task.spawn(function()
    -- Attendre que le personnage soit chargé
    if not player.Character then
        player.CharacterAdded:Wait()
    end
    task.wait(1)   -- laisser le serveur peupler la map

    -- ── Détection dynamique des plaques (fix : plaques lentes à pop) ───────
    Workspace.DescendantAdded:Connect(processBasePart)

    -- Scan initial pour ce qui est déjà là
    for _, inst in ipairs(Workspace:GetDescendants()) do
        processBasePart(inst)
    end


    -- ── Sol jaune du biome Défis (derrière le mur bleu, X ≥ 58) ─────────────
    -- Généré une seule fois, indépendamment des GrassBase (zone sans dalles).
    -- AutoStud skip ces positions (continue si X≥58 et !isRoad) → zéro doublon.
    -- Paramètres calés sur le mur backdrop : X 58→150, Z ±115, Y surface = 0.
    task.spawn(function()
        LegoRenderer.GenerateChallengeFloor(
            Workspace,   -- parent
            56.0, 400.0, -- X : pied du mur bleu jusqu'au bout de la map
            -400, 400,   -- Z : toute la largeur pour éviter les trous verts
            1.0          -- groundY : 1.0 pour être sûr d'écraser tout grésillement
        )
    end)

    -- ── Surveillance constante (sécurité) ─────────────────────────────────
    while true do
        task.wait(5)
        -- Si une plaque a été rajoutée sans être détectée (rare)
        for _, inst in ipairs(Workspace:GetDescendants()) do
            if inst:IsA("BasePart") and not chunkCache[inst] then
                processBasePart(inst)
            end
        end
    end
end)

--!strict
-- StudRenderer.client.lua  (LocalScript — StarterPlayerScripts)
--
-- Rendu LEGO 100 % côté client — zéro réplication réseau.
--
-- Stratégie :
--   1. Masquer toutes les dalles GrassBase / Avenue / Road (Transparency = 1).
--   2. Lancer LegoRenderer.GenerateFloor() UNE SEULE FOIS pour couvrir
--      toute la carte avec le MeshPart Carpet (biomes auto par coordonnées).
--   3. La zone Défi (X ≥ 56) est incluse dans ce même appel — getBiomeColor()
--      retourne automatiquement le jaune dans ce secteur.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")

local LegoRenderer = require(ReplicatedStorage:WaitForChild("LegoRenderer", 30))

local player = Players.LocalPlayer

-- ══════════════════════════════════════════════════════════════════════════════
-- DÉMARRAGE
-- ══════════════════════════════════════════════════════════════════════════════
task.spawn(function()
    -- Attendre le personnage
    if not player.Character then
        player.CharacterAdded:Wait()
    end
    task.wait(1)   -- laisser le serveur terminer la génération de la map

    -- ── Masquer les dalles de base (elles seront couvertes par les Carpet) ──
    -- Elles restent en mémoire mais invisibles ; la collision est portée
    -- par le CollisionFloor invisible créé dans LevelGenerator.
    local function hideBasePlates()
        for _, inst in ipairs(Workspace:GetDescendants()) do
            if not inst:IsA("BasePart") then continue end
            local nm = string.upper(inst.Name)
            if  string.find(nm, "GRASSBASE")
             or string.find(nm, "AVENUE")
             or string.find(nm, "ROAD")
             or string.find(nm, "STREET") then
                local bp = inst :: BasePart
                bp.Transparency = 1
                bp.CastShadow   = false
            end
        end
    end

    hideBasePlates()

    -- Écoute les nouvelles dalles qui popent après le scan initial
    Workspace.DescendantAdded:Connect(function(inst: Instance)
        if not inst:IsA("BasePart") then return end
        local nm = string.upper(inst.Name)
        if  string.find(nm, "GRASSBASE")
         or string.find(nm, "AVENUE")
         or string.find(nm, "ROAD")
         or string.find(nm, "STREET") then
            (inst :: BasePart).Transparency = 1
            (inst :: BasePart).CastShadow   = false
        end
    end)

    -- ── Génération du sol complet en une passe ────────────────────────────
    -- Bounds calées sur la grille LevelGenerator : tx/tz ∈ [-12, 12], TILE=32.
    -- X : (-12×32) - 16 = -400  →  (12×32) + 16 + 32 = 432  (marge d'1 tuile)
    -- Z : idem
    -- surfY = 0.9 = top des GrassBase (center=0.5, height=0.8 → top=0.9).
    LegoRenderer.GenerateFloor(
        Workspace,
        -400, 432,   -- X : toute la carte + marge
        -400, 432,   -- Z : toute la carte + marge
        0.9          -- surfY : face supérieure des tuiles Carpet
    )
end)

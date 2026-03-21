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
    -- Masque TOUS les sols "natifs" : GrassBase (claude branch), GrassGround
    -- (WorldAssets), Tile_X_Y (LevelGenerator LegoGround), Avenue, Road, Street.
    -- Les tuiles Carpet générées ci-dessous les remplacent visuellement.
    local function shouldHide(nm: string): boolean
        return string.find(nm, "GRASSBASE")  ~= nil
            or string.find(nm, "GRASSGROUND") ~= nil
            or string.find(nm, "AVENUE")      ~= nil
            or string.find(nm, "ROAD")        ~= nil
            or string.find(nm, "STREET")      ~= nil
            or string.find(nm, "TILE_")       ~= nil  -- LegoGround de LevelGenerator
    end

    local function hideBasePlates()
        for _, inst in ipairs(Workspace:GetDescendants()) do
            if not inst:IsA("BasePart") then continue end
            if shouldHide(string.upper(inst.Name)) then
                local bp = inst :: BasePart
                bp.Transparency = 1
                bp.CastShadow   = false
            end
        end
    end

    hideBasePlates()

    Workspace.DescendantAdded:Connect(function(inst: Instance)
        if not inst:IsA("BasePart") then return end
        if shouldHide(string.upper(inst.Name)) then
            (inst :: BasePart).Transparency = 1
            (inst :: BasePart).CastShadow   = false
        end
    end)

    -- ── Génération du sol complet en une passe ────────────────────────────
    -- surfY = 0.9 (top du GrassGround = 0, mais on garde 0.9 pour rester
    -- au niveau de la galerie BrainrotGallery dont FLOOR_Y = 1).
    LegoRenderer.GenerateFloor(
        Workspace,
        -400, 432,   -- X : toute la carte + marge
        -400, 432,   -- Z : toute la carte + marge
        0.9          -- surfY : face supérieure des tuiles Carpet
    )
end)

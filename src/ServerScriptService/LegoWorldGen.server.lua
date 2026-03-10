--!strict
-- LegoWorldGen.server.lua
-- Script serveur — Orchestrateur du monde style Lego Classic / Vintage Studs.
-- Compatible avec l'organisation Rojo (ServerScriptService).
--
-- ┌─────────────────────────────────────────────────────────────────────────┐
-- │  MODE D'EMPLOI                                                           │
-- │                                                                          │
-- │  1. BASEPLATE                                                            │
-- │     Génère automatiquement le sol en dalles vertes 32×32 studs.          │
-- │     Configure la zone via CFG.baseplate.*.                               │
-- │                                                                          │
-- │  2. CONVERSION AUTOMATIQUE                                               │
-- │     Place des Parts dans Workspace > LegoMarkers.                        │
-- │     Ce script les détecte et les remplace par des empilements de         │
-- │     briques Lego alignées sur la grille.                                 │
-- │     → La Part source est rendue invisible (conservation de la collision)  │
-- │                                                                          │
-- │  3. MURS / BÂTIMENTS SCRIPTÉS                                            │
-- │     Modifie la section "BÂTIMENTS SCRIPTÉS" pour générer des murs ou    │
-- │     des structures directement en code (ex : maison, tour, arche).       │
-- │                                                                          │
-- │  OPTIMISATION                                                            │
-- │     - CastShadow désactivé sur chaque brique (économie GPU majeure)      │
-- │     - task.wait() entre chaque couche pour éviter le freeze serveur      │
-- │     - Briques regroupées dans des Folders → nettoyage facile             │
-- │     - StreamingEnabled compatible : les Folders sont dans Workspace       │
-- └─────────────────────────────────────────────────────────────────────────┘

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local LegoBuilder = require(ReplicatedStorage:WaitForChild("LegoBuilder"))

-- ══════════════════════════════════════════════════════════════════════════════
-- CONFIGURATION CENTRALE
-- ══════════════════════════════════════════════════════════════════════════════

local CFG = {

    -- ── Baseplate ──────────────────────────────────────────────────────────
    baseplate = {
        enabled  = true,
        -- Coin supérieur-gauche-avant de la zone à couvrir (world space)
        originX  = -192,        -- axe X : de -192 à +192 → 384 studs (12 tiles)
        originZ  = -192,        -- axe Z : de -192 à +192 → 384 studs (12 tiles)
        tilesX   = 12,          -- 12 × 32 = 384 studs de large
        tilesZ   = 12,          -- 12 × 32 = 384 studs de long
        floorY   = 0,           -- Y du DESSUS du sol (= là où posent les briques)
    },

    -- ── Conversion automatique des Parts marqueurs ─────────────────────────
    convert = {
        enabled      = true,
        folder       = "LegoMarkers",  -- nom du dossier dans Workspace
        brickW       = 2,              -- largeur X des briques en studs
        brickL       = 4,              -- longueur Z des briques en studs
        brickH       = 1.2,            -- hauteur Y des briques en studs
        -- Modes de couleur disponibles :
        --   "random"  → couleur aléatoire par brique
        --   "uniform" → une seule couleur par Part
        --   "row"     → même teinte sur toute la couche Y (aspect bandes horizontales)
        --   "layer"   → même teinte sur chaque colonne X  (aspect bandes verticales)
        colorMode    = "row",
    },

    -- ── Murs scriptés (exemples) ───────────────────────────────────────────
    -- Passe à enabled = true pour générer ces bâtiments d'exemple.
    exampleBuildings = {
        enabled = false,    -- mettre à true pour activer
        -- Position de départ (coin bas-gauche) de la "maison démo"
        houseOriginX = 10,
        houseOriginZ = 10,
        houseFloorY  = 0,
    },
}

-- ══════════════════════════════════════════════════════════════════════════════
-- DOSSIERS WORKSPACE
-- ══════════════════════════════════════════════════════════════════════════════

local function getOrCreate(parent: Instance, name: string): Folder
    local existing = parent:FindFirstChild(name)
    if existing and existing:IsA("Folder") then
        return existing :: Folder
    end
    local f      = Instance.new("Folder")
    f.Name       = name
    f.Parent     = parent
    return f
end

local legoRoot = getOrCreate(Workspace, "LegoWorld")   -- conteneur racine Lego

-- ══════════════════════════════════════════════════════════════════════════════
-- ÉTAPE 1 — BASEPLATE
-- ══════════════════════════════════════════════════════════════════════════════

if CFG.baseplate.enabled then
    local bp = CFG.baseplate
    print(string.format(
        "[LegoWorldGen] Baseplate : %d×%d tiles (%d×%d studs)…",
        bp.tilesX, bp.tilesZ,
        bp.tilesX * LegoBuilder.TILE_SZ,
        bp.tilesZ * LegoBuilder.TILE_SZ
    ))

    local bpFolder = getOrCreate(legoRoot, "Baseplate")

    LegoBuilder.buildBaseplate(
        bp.originX,
        bp.originZ,
        bp.tilesX,
        bp.tilesZ,
        bp.floorY,
        bpFolder
    )

    print(string.format(
        "[LegoWorldGen] Baseplate OK — %d dalles générées.",
        bp.tilesX * bp.tilesZ
    ))
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ÉTAPE 2 — CONVERSION AUTOMATIQUE DES MARQUEURS
-- ══════════════════════════════════════════════════════════════════════════════
--[[
    Comment utiliser LegoMarkers :
    ─────────────────────────────
    1. Dans Roblox Studio, crée un Folder "LegoMarkers" dans Workspace.
    2. Ajoute des Parts dedans. Chaque Part représente le volume d'un bâtiment :
         - Taille    : correspond à la taille globale du bâtiment
         - Position  : centre du bâtiment dans le monde
         - Couleur   : ignorée (la palette du CFG s'applique)
    3. Lance le jeu → les Parts sont converties en briques Lego individuelles.

    Exemple rapide en Studio :
      Part  Name="MaisonA"  Size=(32,12,16)  Position=(0,6,0)
      → génère 2×12 briques de large, 10 couches, 1×4 briques de profondeur.
]]

if CFG.convert.enabled then
    local cv = CFG.convert
    local markersFolder = Workspace:FindFirstChild(cv.folder)

    if markersFolder and markersFolder:IsA("Folder") then
        local bricksFolder = getOrCreate(legoRoot, "ConvertedBricks")
        local parts: {BasePart} = {}

        for _, child in markersFolder:GetChildren() do
            if child:IsA("BasePart") then
                table.insert(parts, child :: BasePart)
            end
        end

        print(string.format(
            "[LegoWorldGen] Conversion de %d Part(s) en briques Lego…",
            #parts
        ))

        for i, part in ipairs(parts) do
            print(string.format("  [%d/%d] %s — taille %s",
                i, #parts, part.Name, tostring(part.Size)))

            LegoBuilder.convertPartToBricks(part, {
                brickW     = cv.brickW,
                brickL     = cv.brickL,
                brickH     = cv.brickH,
                colorMode  = cv.colorMode,
                hideSource = true,
                parent     = bricksFolder,
            })
        end

        print("[LegoWorldGen] Conversion terminée.")
    else
        print(string.format(
            "[LegoWorldGen] Dossier '%s' absent de Workspace. " ..
            "Crée-le et ajoute des Parts pour activer la conversion automatique.",
            cv.folder
        ))
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ÉTAPE 3 — BÂTIMENTS SCRIPTÉS (exemples)
-- ══════════════════════════════════════════════════════════════════════════════
--[[
    Modifie cette section pour générer des structures directement en code.
    Chaque appel à LegoBuilder.buildWall() produit un mur avec effet
    de quinconce automatique (bond-shift classique Lego).
]]

if CFG.exampleBuildings.enabled then
    local ex     = CFG.exampleBuildings
    local bF     = getOrCreate(legoRoot, "ExampleBuildings")
    local palette= LegoBuilder.PALETTE

    -- Dimensions de la maison démo (en nombre de briques)
    local wallCols   = 8   -- 8 briques de long × BRICK_W studs
    local wallRows   = 6   -- 6 rangs de hauteur × BRICK_H studs
    local bW = LegoBuilder.BRICK_W
    local bL = LegoBuilder.BRICK_L
    local bH = LegoBuilder.BRICK_H

    local ox = ex.houseOriginX
    local oy = ex.houseFloorY
    local oz = ex.houseOriginZ

    -- ── Mur Avant (le long de X, côté Z=oz) ────────────────────────────────
    LegoBuilder.buildWall(
        Vector3.new(ox, oy, oz),
        wallCols, wallRows,
        bW, bL,
        "X",
        palette[1],         -- Bright Red
        bF
    )

    -- ── Mur Arrière (le long de X, côté Z=oz + profondeur) ─────────────────
    local depth = wallCols * bL
    LegoBuilder.buildWall(
        Vector3.new(ox, oy, oz + depth),
        wallCols, wallRows,
        bW, bL,
        "X",
        palette[1],         -- Bright Red
        bF
    )

    -- ── Mur Gauche (le long de Z, côté X=ox) ───────────────────────────────
    LegoBuilder.buildWall(
        Vector3.new(ox, oy, oz),
        wallCols, wallRows,
        bW, bL,
        "Z",
        palette[2],         -- Bright Blue
        bF
    )

    -- ── Mur Droit (le long de Z, côté X=ox + largeur) ──────────────────────
    local width = wallCols * bW
    LegoBuilder.buildWall(
        Vector3.new(ox + width, oy, oz),
        wallCols, wallRows,
        bW, bL,
        "Z",
        palette[2],         -- Bright Blue
        bF
    )

    -- ── Sol intérieur (une seule épaisseur de briques plates) ───────────────
    for ix = 0, wallCols - 1 do
        for iz = 0, wallCols - 1 do
            LegoBuilder.createBrick(
                Vector3.new(ox + ix * bW, oy, oz + iz * bL),
                bW, bL, LegoBuilder.PLATE_H,
                palette[3],     -- Bright Yellow
                bF
            )
        end
    end

    print("[LegoWorldGen] Bâtiment exemple généré.")
end

-- ══════════════════════════════════════════════════════════════════════════════

print("[LegoWorldGen] Prêt — monde Lego initialisé.")

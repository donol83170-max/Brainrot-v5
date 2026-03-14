--!strict
-- BrainrotRNG.lua  (ModuleScript — ServerScriptService)
-- Tirage au sort pondéré sur 1000 + spawn du modèle 3D avec attribut PPS.
--
-- API :
--   BrainrotRNG.Roll()                                       → RollResult
--   BrainrotRNG.SpawnBrainrot(name, rarity, pps, socle)     → Model?

local BrainrotRNG = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

-- ── Couleurs par rareté (partagées avec WheelSystem / UI) ────────────────────
BrainrotRNG.RarityColors = {
    COMMON          = Color3.fromRGB(  0, 255,   0),  -- Vert
    RARE            = Color3.fromRGB(  0, 130, 255),  -- Bleu
    EPIC            = Color3.fromRGB(255,   0, 255),  -- Violet
    LEGENDARY       = Color3.fromRGB(255, 215,   0),  -- Doré
    ULTRA_LEGENDARY = Color3.fromRGB(255,  50,  50),  -- Rouge écarlate
}

-- ── Table des raretés ─────────────────────────────────────────────────────────
-- weight : sur 1000  (1000 = 100 %)
-- ppsMin / ppsMax : puissance par seconde générée par un modèle de cette rareté
-- items : { id = itemId (clé BrainrotModels), name = nom affiché }
local RARITY_TABLE: {{
    rarity : string,
    weight : number,
    ppsMin : number,
    ppsMax : number,
    items  : {{id: string, name: string}},
}} = {
    {
        rarity = "COMMON",
        weight = 595,   -- 59.5 %
        ppsMin = 100,
        ppsMax = 500,
        items  = {
            { id = "BallerinaCapp",  name = "Ballerina Cappuccina" },
            { id = "BombardiroCroc", name = "Bombardiro Crocodilo" },
            { id = "BombombiniGus",  name = "Bombombini Gusini"    },
            { id = "CappuccinoAss",  name = "Cappuccino Assassino" },
            { id = "LirilaLarila",   name = "Lirilì Larilà"        },
            { id = "Tralalero",      name = "Tralalero Tralala"    },
            { id = "TrippiTroppi",   name = "Trippi Troppi"        },
        },
    },
    {
        rarity = "RARE",
        weight = 250,   -- 25 %
        ppsMin = 1_500,
        ppsMax = 4_000,
        items  = {
            { id = "BrBrPatapim",     name = "Brr Brr Patapim"     },
            { id = "ChimpanziniBan",  name = "Chimpanzini Bananini" },
            { id = "Los67",           name = "Los 67"               },
            { id = "LosTralaleritos", name = "Los Tralaleritos"     },
        },
    },
    {
        rarity = "EPIC",
        weight = 140,   -- 14 %
        ppsMin = 10_000,
        ppsMax = 25_000,
        items  = {
            { id = "TungTungSahur", name = "Tung Tung Tung Sahur" },
            { id = "WOrL",          name = "W or L"               },
        },
    },
    {
        rarity = "LEGENDARY",
        weight = 10,    -- 1 %
        ppsMin = 100_000,
        ppsMax = 250_000,
        items  = {
            { id = "Item67", name = "67" },
        },
    },
    {
        rarity = "ULTRA_LEGENDARY",
        weight = 5,     -- 0.5 %
        ppsMin = 1_000_000,
        ppsMax = 2_500_000,
        items  = {
            { id = "DragonCannell",   name = "Dragon Cannelloni"  },
            { id = "StrawberryEleph", name = "Strawberry Elephant" },
        },
    },
}

-- ── Types ─────────────────────────────────────────────────────────────────────
export type RollResult = {
    rarity : string,
    itemId : string,
    name   : string,
    pps    : number,
}

-- ── Roll() ────────────────────────────────────────────────────────────────────
-- Tire une rareté (pondérée sur 1000), choisit un item aléatoire dans ce tier,
-- puis calcule un PPS aléatoire dans la fourchette de la rareté.
-- Retourne une RollResult.
function BrainrotRNG.Roll(): RollResult
    local roll = math.random(1, 1000)
    local cum  = 0

    for _, entry in ipairs(RARITY_TABLE) do
        cum += entry.weight
        if roll <= cum then
            local picked = entry.items[math.random(1, #entry.items)]
            local pps    = math.random(entry.ppsMin, entry.ppsMax)
            return {
                rarity = entry.rarity,
                itemId = picked.id,
                name   = picked.name,
                pps    = pps,
            }
        end
    end

    -- Fallback (ne devrait jamais arriver si la somme des poids == 1000)
    local fallback = RARITY_TABLE[1]
    local picked   = fallback.items[1]
    return {
        rarity = fallback.rarity,
        itemId = picked.id,
        name   = picked.name,
        pps    = fallback.ppsMin,
    }
end

-- ── SpawnBrainrot() ───────────────────────────────────────────────────────────
-- Clone le modèle 3D depuis ReplicatedStorage.BrainrotModels,
-- attache les attributs PPS et Rarity, puis le pose sur le socle donné.
--
-- Paramètres :
--   brainrotName — nom exact de l'enfant dans BrainrotModels (ex : "Ballerina Cappuccina")
--   rarity       — tier du modèle (ex : "COMMON")
--   ppsValue     — valeur PPS calculée par Roll()
--   soclePart    — BasePart servant de support (CollectorPlate, sol, etc.)
--
-- Retourne le Model cloné, ou nil si le modèle est introuvable.
function BrainrotRNG.SpawnBrainrot(
    brainrotName : string,
    rarity       : string,
    ppsValue     : number,
    soclePart    : BasePart
): Model?
    local modelsFolder = ReplicatedStorage:FindFirstChild("BrainrotModels")
    if not modelsFolder then
        warn("[BrainrotRNG] ReplicatedStorage.BrainrotModels introuvable")
        return nil
    end

    local template = modelsFolder:FindFirstChild(brainrotName)
    if not template then
        warn("[BrainrotRNG] Modèle introuvable : " .. brainrotName)
        return nil
    end

    local model = template:Clone() :: Model

    -- ── Attributs (lisibles depuis n'importe quel script via :GetAttribute) ──
    model:SetAttribute("PPS",    ppsValue)
    model:SetAttribute("Rarity", rarity)

    -- ── Positionnement sur la face supérieure du socle ────────────────────────
    local socleTopY = soclePart.Position.Y + soclePart.Size.Y / 2
    local spawnCF   = CFrame.new(soclePart.Position.X, socleTopY, soclePart.Position.Z)

    if model.PrimaryPart then
        model:PivotTo(spawnCF)
    else
        model:MoveTo(spawnCF.Position)
    end

    model.Parent = Workspace

    print(string.format("[BrainrotRNG] Spawned '%s' | %s | PPS = %d",
        brainrotName, rarity, ppsValue))

    return model
end

-- ── Helper : PPS formaté pour affichage UI ────────────────────────────────────
-- Exemples : 350 → "350/s"  |  1 500 → "1.5K/s"  |  2 500 000 → "2.5M/s"
function BrainrotRNG.FormatPPS(pps: number): string
    if pps >= 1_000_000 then
        return string.format("%.1fM/s", pps / 1_000_000)
    elseif pps >= 1_000 then
        return string.format("%.1fK/s", pps / 1_000)
    else
        return string.format("%d/s", pps)
    end
end

return BrainrotRNG

-- BrainrotData.lua
-- Source unique pour les images des mèmes dans les cadres de galerie.
-- IDs réels vérifiés marqués ✅ — les autres attendent un upload.

local BrainrotData = {}

-- ── Textures spéciales ────────────────────────────────────────────────────────
-- Affiché pour les items POSSÉDÉS qui n'ont pas encore d'image dédiée
BrainrotData.FallbackImageId = 7033571616

-- Affiché dans les cadres VIDES (slot non débloqué)
-- TODO : remplacer par un vrai asset "?" ou cadenas
BrainrotData.LockedImageId = 0

-- ── Retourne l'ImageId d'un item (fallback si l'item n'a pas d'image) ─────────
function BrainrotData.GetImageId(itemId: string): number
    local entry = BrainrotData.Items[itemId]
    if not entry then return BrainrotData.FallbackImageId end
    return entry.ImageId ~= 0 and entry.ImageId or BrainrotData.FallbackImageId
end

-- ── Table des items ───────────────────────────────────────────────────────────
-- ✅  = ID réel vérifié   |   0 = à renseigner après upload
BrainrotData.Items = {

    -- ── Roue Noob ─────────────────────────────────────────────────────────────
    BruhSound       = { ImageId = 0 },
    NoobFace        = { ImageId = 0 },
    DefaultPizza    = { ImageId = 0 },
    MewingEmoji     = { ImageId = 0 },
    BlueTie         = { ImageId = 0 },
    SigmaSmile      = { ImageId = 0 },
    GigachadJaw     = { ImageId = 9841004128  },  -- ✅ GigaChad
    PizzaTower      = { ImageId = 0 },
    SkibidiHead     = { ImageId = 15263881432 },  -- ✅ Skibidi Toilet
    GoldenSigma     = { ImageId = 0 },
    GalaxySigma     = { ImageId = 0 },
    DiamondSkibidi  = { ImageId = 15263881432 },  -- ✅ Skibidi Toilet (variante)
    JokeCrafter     = { ImageId = 0 },
    BrainrotKing    = { ImageId = 12501659970 },  -- ✅ Maxwell the Cat
    SkibidiGod      = { ImageId = 15263881432 },  -- ✅ Skibidi Toilet (god tier)
    UltimateNoob    = { ImageId = 0 },

    -- ── Roue Sigma ────────────────────────────────────────────────────────────
    CrunchyCookie   = { ImageId = 0 },
    BasicRizzler    = { ImageId = 0 },
    NpcFace         = { ImageId = 14751493032 },  -- ✅ Smurf Cat
    SigmaGrind      = { ImageId = 0 },
    Rizzler500      = { ImageId = 0 },
    BrainrotWave    = { ImageId = 0 },
    SigmaKing       = { ImageId = 0 },
    GlizzyGoblin    = { ImageId = 0 },
    UltraRizzler    = { ImageId = 0 },
    SigmaChad       = { ImageId = 9841004128  },  -- ✅ GigaChad
    OmegaSigma      = { ImageId = 0 },
    DivineRizzler   = { ImageId = 0 },
    ChadVibes       = { ImageId = 12501659970 },  -- ✅ Maxwell the Cat
    SigmaFlash      = { ImageId = 0 },
    MegaRizzler     = { ImageId = 0 },
    AbsoluteSigma   = { ImageId = 0 },

    -- ── Roue Ultra ────────────────────────────────────────────────────────────
    CosmicNoob      = { ImageId = 15234232386 },  -- ✅ Pomni (Amazing Digital Circus)
    VoidPizza       = { ImageId = 0 },
    NebulaBruh      = { ImageId = 0 },
    StarSigma       = { ImageId = 0 },
    LunarSkibidi    = { ImageId = 15263881432 },  -- ✅ Skibidi Toilet
    GalacticMewing  = { ImageId = 14751493032 },  -- ✅ Smurf Cat
    NovaSigma       = { ImageId = 0 },
    BlackHoleRizz   = { ImageId = 0 },
    UniverseChad    = { ImageId = 9841004128  },  -- ✅ GigaChad
    CosmicSkibidi   = { ImageId = 15263881432 },  -- ✅ Skibidi Toilet
    AbsoluteGigachad = { ImageId = 9841004128 },  -- ✅ GigaChad
    TrueOmegaSigma  = { ImageId = 12501659970 },  -- ✅ Maxwell the Cat
    StarNoob        = { ImageId = 0 },
    NebulaSigma     = { ImageId = 0 },
    CelestialRizz   = { ImageId = 15234232386 },  -- ✅ Pomni
    CosmicGigachad  = { ImageId = 9841004128  },  -- ✅ GigaChad
}

return BrainrotData

-- LootTables.lua
-- Définit les objets disponibles dans chaque roue

local LootTables = {}

LootTables.Wheels = {

    -- ── Roue 1 : Roue Noob (centre, position 0,0,0) ───────────────────────────
    [1] = {
        Name = "Roue Noob",
        Items = {
            -- NORMAL (60%) — segments 1, 2, 3
            { Id = "BruhSound",    Name = "Son Bruh",         Rarity = "NORMAL",    SegmentId = 1  },
            { Id = "NoobFace",     Name = "Tête de Noob",     Rarity = "NORMAL",    SegmentId = 2  },
            { Id = "DefaultPizza", Name = "Pizza Froide",      Rarity = "NORMAL",    SegmentId = 3  },

            -- RARE (20%) — segments 4, 5, 6
            { Id = "MewingEmoji",  Name = "Emoji Mewing",      Rarity = "RARE",      SegmentId = 4  },
            { Id = "BlueTie",      Name = "Cravate Bleue",     Rarity = "RARE",      SegmentId = 5  },
            { Id = "SigmaSmile",   Name = "Sourire Sigma",     Rarity = "RARE",      SegmentId = 6  },

            -- MYTHIC (10%) — segments 7, 8
            { Id = "GigachadJaw",  Name = "Mâchoire Gigachad", Rarity = "MYTHIC",    SegmentId = 7  },
            { Id = "PizzaTower",   Name = "Tour de Pizza",     Rarity = "MYTHIC",    SegmentId = 8  },

            -- LEGENDARY (8%) — segments 9, 10
            { Id = "SkibidiHead",  Name = "Tête Skibidi",      Rarity = "LEGENDARY", SegmentId = 9  },
            { Id = "GoldenSigma",  Name = "Sigma d'Or",        Rarity = "LEGENDARY", SegmentId = 10 },

            -- ULTRA (2%) — segments 11, 12
            { Id = "GalaxySigma",    Name = "Sigma Galactique", Rarity = "ULTRA",    SegmentId = 11 },
            { Id = "DiamondSkibidi", Name = "Skibidi Diamant",  Rarity = "ULTRA",    SegmentId = 12 },
        }
    },

    -- ── Roue 2 : Roue Sigma (gauche, position -70,0,0) ────────────────────────
    [2] = {
        Name = "Roue Sigma",
        Items = {
            -- NORMAL (60%) — segments 1, 2, 3
            { Id = "CrunchyCookie", Name = "Cookie Croustillant", Rarity = "NORMAL",    SegmentId = 1  },
            { Id = "BasicRizzler",  Name = "Rizzler Basique",     Rarity = "NORMAL",    SegmentId = 2  },
            { Id = "NpcFace",       Name = "Tête de PNJ",         Rarity = "NORMAL",    SegmentId = 3  },

            -- RARE (20%) — segments 4, 5, 6
            { Id = "SigmaGrind",    Name = "Grind Sigma",         Rarity = "RARE",      SegmentId = 4  },
            { Id = "Rizzler500",    Name = "Rizzler 500",         Rarity = "RARE",      SegmentId = 5  },
            { Id = "BrainrotWave",  Name = "Vague Brainrot",      Rarity = "RARE",      SegmentId = 6  },

            -- MYTHIC (10%) — segments 7, 8
            { Id = "SigmaKing",     Name = "Roi Sigma",           Rarity = "MYTHIC",    SegmentId = 7  },
            { Id = "GlizzyGoblin",  Name = "Gobelin Glizzy",      Rarity = "MYTHIC",    SegmentId = 8  },

            -- LEGENDARY (8%) — segments 9, 10
            { Id = "UltraRizzler",  Name = "Rizzler Ultra",       Rarity = "LEGENDARY", SegmentId = 9  },
            { Id = "SigmaChad",     Name = "Sigma Chad",          Rarity = "LEGENDARY", SegmentId = 10 },

            -- ULTRA (2%) — segments 11, 12
            { Id = "OmegaSigma",    Name = "Omega Sigma",         Rarity = "ULTRA",     SegmentId = 11 },
            { Id = "DivineRizzler", Name = "Rizzler Divin",       Rarity = "ULTRA",     SegmentId = 12 },
        }
    },

    -- ── Roue 3 : Roue Ultra (droite, position 70,0,0) ─────────────────────────
    [3] = {
        Name = "Roue Ultra",
        Items = {
            -- NORMAL (60%) — segments 1, 2, 3
            { Id = "CosmicNoob",   Name = "Noob Cosmique",      Rarity = "NORMAL",    SegmentId = 1  },
            { Id = "VoidPizza",    Name = "Pizza du Vide",       Rarity = "NORMAL",    SegmentId = 2  },
            { Id = "NebulaBruh",   Name = "Bruh Nébuleux",      Rarity = "NORMAL",    SegmentId = 3  },

            -- RARE (20%) — segments 4, 5, 6
            { Id = "StarSigma",      Name = "Sigma Stellaire",   Rarity = "RARE",      SegmentId = 4  },
            { Id = "LunarSkibidi",   Name = "Skibidi Lunaire",   Rarity = "RARE",      SegmentId = 5  },
            { Id = "GalacticMewing", Name = "Mewing Galactique", Rarity = "RARE",      SegmentId = 6  },

            -- MYTHIC (10%) — segments 7, 8
            { Id = "NovaSigma",     Name = "Nova Sigma",         Rarity = "MYTHIC",    SegmentId = 7  },
            { Id = "BlackHoleRizz", Name = "Rizz Trou Noir",     Rarity = "MYTHIC",    SegmentId = 8  },

            -- LEGENDARY (8%) — segments 9, 10
            { Id = "UniverseChad",   Name = "Chad de l'Univers", Rarity = "LEGENDARY", SegmentId = 9  },
            { Id = "CosmicSkibidi",  Name = "Skibidi Cosmique",  Rarity = "LEGENDARY", SegmentId = 10 },

            -- ULTRA (2%) — segments 11, 12
            { Id = "AbsoluteGigachad", Name = "Gigachad Absolu",    Rarity = "ULTRA",  SegmentId = 11 },
            { Id = "TrueOmegaSigma",   Name = "Vrai Omega Sigma",   Rarity = "ULTRA",  SegmentId = 12 },
        }
    },
}

return LootTables

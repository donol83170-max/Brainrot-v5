-- LootTables.lua
-- Définit les objets disponibles dans chaque roue

local LootTables = {}

LootTables.Wheels = {

    -- ── Roue 1 : Roue Noob (centre, position 0,0,0) ───────────────────────────
    [1] = {
        Name = "Roue Noob",
        Cost = 20,
        Currency = "Gold",
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

            -- ULTRA (2%) — segment 11
            { Id = "GalaxySigma",    Name = "Sigma Galactique", Rarity = "ULTRA",    SegmentId = 11 },

            -- NORMAL (60%) — segments 12, 13 (extra)
            { Id = "DiamondSkibidi", Name = "Skibidi Diamant",  Rarity = "NORMAL",   SegmentId = 12 },
            { Id = "JokeCrafter",    Name = "Joke Crafter",     Rarity = "NORMAL",   SegmentId = 13 },

            -- RARE (20%) — segment 14 (extra)
            { Id = "BrainrotKing",   Name = "Roi Brainrot",     Rarity = "RARE",     SegmentId = 14 },

            -- MYTHIC (10%) — segment 15 (extra)
            { Id = "SkibidiGod",     Name = "Dieu Skibidi",     Rarity = "MYTHIC",   SegmentId = 15 },

            -- ULTRA (2%) — segment 16 (extra)
            { Id = "UltimateNoob",   Name = "Noob Ultime",      Rarity = "ULTRA",    SegmentId = 16 },
        }
    },

    -- ── Roue 2 : Roue Sigma (gauche, position -70,0,0) ────────────────────────
    [2] = {
        Name = "Roue Sigma",
        Cost = 100,
        Currency = "Gold",
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

            -- ULTRA (2%) — segment 11
            { Id = "OmegaSigma",    Name = "Omega Sigma",         Rarity = "ULTRA",     SegmentId = 11 },

            -- NORMAL (60%) — segments 12, 13 (extra)
            { Id = "DivineRizzler", Name = "Rizzler Divin",        Rarity = "NORMAL",    SegmentId = 12 },
            { Id = "ChadVibes",     Name = "Chad Vibes",           Rarity = "NORMAL",    SegmentId = 13 },

            -- RARE (20%) — segment 14 (extra)
            { Id = "SigmaFlash",    Name = "Sigma Flash",          Rarity = "RARE",      SegmentId = 14 },

            -- MYTHIC (10%) — segment 15 (extra)
            { Id = "MegaRizzler",   Name = "Méga Rizzler",         Rarity = "MYTHIC",    SegmentId = 15 },

            -- ULTRA (2%) — segment 16 (extra)
            { Id = "AbsoluteSigma", Name = "Sigma Absolu",         Rarity = "ULTRA",     SegmentId = 16 },
        }
    },

    -- ── Roue 3 : Roue Ultra (droite, position 70,0,0) ─────────────────────────
    [3] = {
        Name = "Roue Ultra",
        Cost = 500,
        Currency = "Gold",
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

            -- ULTRA (2%) — segment 11
            { Id = "AbsoluteGigachad", Name = "Gigachad Absolu",    Rarity = "ULTRA",  SegmentId = 11 },

            -- NORMAL (60%) — segments 12, 13 (extra)
            { Id = "TrueOmegaSigma",   Name = "Vrai Omega Sigma",   Rarity = "NORMAL", SegmentId = 12 },
            { Id = "StarNoob",         Name = "Noob Étoile",        Rarity = "NORMAL", SegmentId = 13 },

            -- RARE (20%) — segment 14 (extra)
            { Id = "NebulaSigma",      Name = "Sigma Nébuleux",     Rarity = "RARE",   SegmentId = 14 },

            -- MYTHIC (10%) — segment 15 (extra)
            { Id = "CelestialRizz",    Name = "Rizz Céleste",       Rarity = "MYTHIC", SegmentId = 15 },

            -- ULTRA (2%) — segment 16 (extra)
            { Id = "CosmicGigachad",   Name = "Gigachad Cosmique",  Rarity = "ULTRA",  SegmentId = 16 },
        }
    },
    -- ── Roue 4 : Roue Brainrot v2.0 (16 segments — Pool system) ──────────────
    -- IDs synchronisés avec WheelSystem.server.lua (POOL table)
    [4] = {
        Name = "Roue Brainrot",
        Cost = 20,
        Currency = "Gold",
        Items = {
            -- COMMON (60%) — 8 items uniques
            { Id = "SkibidiHead",    Name = "Skibidi Toilet",                 Rarity = "COMMON",    SegmentId = 1  },
            { Id = "LVaccaSaturno",  Name = "La Vacca Saturno Saturnita",     Rarity = "COMMON",    SegmentId = 2  },
            { Id = "BallerinaCapp",  Name = "Ballerina Cappuccina",           Rarity = "COMMON",    SegmentId = 4  },
            { Id = "NoobiniPizza",   Name = "Noobini Pizzanini",              Rarity = "COMMON",    SegmentId = 5  },
            { Id = "NuclearoDino",   Name = "Nuclearo Dinossauro",            Rarity = "COMMON",    SegmentId = 7  },
            { Id = "LirilaLarila",   Name = "Lirilì Larilà",                  Rarity = "COMMON",    SegmentId = 9  },
            { Id = "BombombiniGus",  Name = "Bombombini Gusini",              Rarity = "COMMON",    SegmentId = 11 },
            { Id = "CappuccinoAss",  Name = "Cappuccino Assassino",           Rarity = "COMMON",    SegmentId = 13 },

            -- RARE (25%) — 4 items uniques
            { Id = "Tralalero",      Name = "Tralalero Tralala",              Rarity = "RARE",      SegmentId = 3  },
            { Id = "TrippiTroppi",   Name = "Trippi Troppi",                  Rarity = "RARE",      SegmentId = 8  },
            { Id = "BombardiroCroc", Name = "Bombardiro Crocodilo",           Rarity = "RARE",      SegmentId = 12 },
            { Id = "LosTaTasitos",   Name = "Los Ta ta Tasitos dicen Sahur",  Rarity = "RARE",      SegmentId = 16 },

            -- EPIC (14%) — 2 items
            { Id = "BrBrPatapim",    Name = "Br Br Patapim",                  Rarity = "EPIC",      SegmentId = 10 },
            { Id = "TungTungSahur",  Name = "Tung Tung Tung Sahur",           Rarity = "EPIC",      SegmentId = 14 },

            -- LEGENDARY (1%) — 2 items
            { Id = "StrawberryEleph", Name = "Strawberry Elephant",           Rarity = "LEGENDARY", SegmentId = 6  },
            { Id = "DragonCannell",   Name = "Dragon Cannelloni",             Rarity = "LEGENDARY", SegmentId = 15 },
        }
    },
}

return LootTables

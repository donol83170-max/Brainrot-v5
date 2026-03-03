-- LootTables.lua
-- Définit les objets disponibles dans chaque roue

local LootTables = {}

LootTables.Wheels = {
    [1] = { -- Roue de départ
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
    }
}

return LootTables

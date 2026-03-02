-- LootTables.lua
-- Définit les objets disponibles dans chaque roue

local LootTables = {}

LootTables.Wheels = {
    [1] = { -- Roue de départ
        Name = "Roue Noob",
        Items = {
            -- NORMAL (60%)
            { Id = "BruhSound", Name = "Son Bruh", Rarity = "NORMAL" },
            { Id = "NoobFace", Name = "Tête de Noob", Rarity = "NORMAL" },
            { Id = "DefaultPizza", Name = "Pizza Froide", Rarity = "NORMAL" },

            -- RARE (20%)
            { Id = "MewingEmoji", Name = "Emoji Mewing", Rarity = "RARE" },
            { Id = "BlueTie", Name = "Cravate Bleue", Rarity = "RARE" },
            { Id = "SigmaSmile", Name = "Sourire Sigma", Rarity = "RARE" },

            -- MYTHIC (10%)
            { Id = "GigachadJaw", Name = "Mâchoire Gigachad", Rarity = "MYTHIC" },
            { Id = "PizzaTower", Name = "Tour de Pizza", Rarity = "MYTHIC" },

            -- LEGENDARY (8%)
            { Id = "SkibidiHead", Name = "Tête Skibidi", Rarity = "LEGENDARY" },
            { Id = "GoldenSigma", Name = "Sigma d'Or", Rarity = "LEGENDARY" },

            -- ULTRA (2%)
            { Id = "GalaxySigma", Name = "Sigma Galactique", Rarity = "ULTRA" },
            { Id = "DiamondSkibidi", Name = "Skibidi Diamant", Rarity = "ULTRA" },
        }
    }
}

return LootTables

-- Constants.lua
-- Centralisation des constantes du jeu

local Constants = {}

Constants.RARITIES = {
    NORMAL = { Name = "NORMAL", Weight = 60, Color = Color3.fromRGB(163, 162, 165) },
    RARE = { Name = "RARE", Weight = 20, Color = Color3.fromRGB(0, 162, 255) },
    MYTHIC = { Name = "MYTHIC", Weight = 10, Color = Color3.fromRGB(170, 0, 255) },
    LEGENDARY = { Name = "LEGENDARY", Weight = 8, Color = Color3.fromRGB(255, 170, 0) },
    ULTRA = { Name = "ULTRA", Weight = 2, Color = Color3.fromRGB(255, 0, 127) } -- Arc-en-ciel plus tard
}

Constants.COOLDOWNS = {
    FREE_SPIN = 5, -- secondes
}

Constants.STARTING_STATS = {
    GOLD = 300,   -- Assez pour 1 spin Noob (50) + 1 spin Sigma (250)
    XP = 0,
    TICKETS = 1,  -- 1 spin Ultra
}

Constants.SELL_VALUES = {
    NORMAL    = 10,
    RARE      = 50,
    MYTHIC    = 150,
    LEGENDARY = 500,
    ULTRA     = 2000,
}

return Constants

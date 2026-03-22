-- Constants.lua
-- Centralisation des constantes du jeu

local Constants = {}

Constants.RARITIES = {
    NORMAL    = { Name = "NORMAL",    Weight =  0, Color = Color3.fromRGB(163, 162, 165) },
    COMMON    = { Name = "COMMON",    Weight = 60, Color = Color3.fromRGB(  0, 255,   0) },  -- VERT
    RARE      = { Name = "RARE",      Weight = 25, Color = Color3.fromRGB(  0, 130, 255) },  -- BLEU
    EPIC      = { Name = "EPIC",      Weight = 14, Color = Color3.fromRGB(255,   0, 255) },  -- VIOLET
    MYTHIC    = { Name = "MYTHIC",    Weight =  0, Color = Color3.fromRGB(170,   0, 255) },
    LEGENDARY = { Name = "LEGENDARY", Weight =  1, Color = Color3.fromRGB(255, 215,   0) },  -- DORÉ
    ULTRA     = { Name = "ULTRA",     Weight =  0, Color = Color3.fromRGB(255,   0, 127) },
}

Constants.COOLDOWNS = {
    FREE_SPIN = 5, -- secondes
}

Constants.STARTING_STATS = {
    GOLD = 10000, -- Capital de départ généreux
    XP = 0,
    TICKETS = 0,
}

Constants.SELL_VALUES = {
    NORMAL    = 5,
    COMMON    = 5,
    RARE      = 15,
    EPIC      = 50,
    MYTHIC    = 50,
    LEGENDARY = 200,
    ULTRA     = 200,
}

return Constants

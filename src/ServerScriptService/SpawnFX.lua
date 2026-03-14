--!strict
-- SpawnFX.lua  (ModuleScript — ServerScriptService)
-- Effets visuels + sonores au spawn d'un Brainrot sur un socle.
-- Tout ce qui est créé est nettoyé par Debris:AddItem — rien ne reste.
--
-- API :
--   SpawnFX.Play(soclePart, rarity, player?)
--     soclePart : BasePart — CollectorPlate ou PrimaryPart du modèle
--     rarity    : string   — "COMMON" | "RARE" | "EPIC" | "LEGENDARY" | "ULTRA_LEGENDARY"
--     player    : Player?  — si fourni, shake seulement pour lui ; sinon FireAllClients

local SpawnFX = {}

local Debris            = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ── RemoteEvent Camera Shake (créé ici, écouté par SpawnFXClient) ─────────────
local Events: Folder = ReplicatedStorage:WaitForChild("Events", 10) :: Folder
local ShakeEvent: RemoteEvent = (function(): RemoteEvent
    local existing = Events:FindFirstChild("SpawnFXShake")
    if existing then return existing :: RemoteEvent end
    local re = Instance.new("RemoteEvent")
    re.Name   = "SpawnFXShake"
    re.Parent = Events
    return re
end)()

-- ── Helpers séquences ─────────────────────────────────────────────────────────
local function cs(c1: Color3, c2: Color3): ColorSequence
    return ColorSequence.new({
        ColorSequenceKeypoint.new(0, c1),
        ColorSequenceKeypoint.new(1, c2),
    })
end

local function ns(a: number, peak: number, z: number): NumberSequence
    return NumberSequence.new({
        NumberSequenceKeypoint.new(0,   a),
        NumberSequenceKeypoint.new(0.4, peak),
        NumberSequenceKeypoint.new(1,   z),
    })
end

local function transparency(fadeIn: number, hold: number): NumberSequence
    return NumberSequence.new({
        NumberSequenceKeypoint.new(0,        fadeIn),
        NumberSequenceKeypoint.new(0.15,     0),
        NumberSequenceKeypoint.new(hold,     0.1),
        NumberSequenceKeypoint.new(1,        1),
    })
end

-- ── Table de configuration par rareté ────────────────────────────────────────
type FxCfg = {
    col1    : Color3,   -- couleur début particule
    col2    : Color3,   -- couleur fin particule
    count   : number,   -- nombre de particules émises (burst)
    speed   : number,   -- vitesse max particules
    life    : number,   -- durée de vie max particules (s)
    size    : number,   -- taille max particules
    lCol    : Color3,   -- couleur PointLight
    lBright : number,   -- intensité PointLight
    lRange  : number,   -- portée PointLight
    soundId : string,   -- rbxassetid://...
    vol     : number,   -- volume son
    pitch   : number,   -- vitesse de lecture (pitch)
    shake   : number,   -- intensité shake [0..1] — 0 = pas de shake
    cleanup : number,   -- durée avant Debris cleanup (s)
}

local CFG: {[string]: FxCfg} = {

    COMMON = {
        col1  = Color3.fromRGB( 80, 230,  80),
        col2  = Color3.fromRGB(200, 255, 200),
        count = 22,   speed = 8,  life = 1.2, size = 0.5,
        lCol    = Color3.fromRGB(100, 255, 100),
        lBright = 1.5, lRange = 12,
        soundId = "rbxassetid://131961136",  -- explosion classique (pitch haut)
        vol = 0.35, pitch = 1.6,
        shake   = 0,
        cleanup = 3,
    },

    RARE = {
        col1  = Color3.fromRGB( 30, 130, 255),
        col2  = Color3.fromRGB(160, 220, 255),
        count = 55,   speed = 14, life = 1.7, size = 0.8,
        lCol    = Color3.fromRGB( 50, 140, 255),
        lBright = 3, lRange = 22,
        soundId = "rbxassetid://131961136",
        vol = 0.6, pitch = 1.1,
        shake   = 0.18,
        cleanup = 3.5,
    },

    EPIC = {
        col1  = Color3.fromRGB(200,   0, 255),
        col2  = Color3.fromRGB(255, 120, 255),
        count = 100,  speed = 20, life = 2.0, size = 1.1,
        lCol    = Color3.fromRGB(200,   0, 255),
        lBright = 5, lRange = 32,
        soundId = "rbxassetid://131961136",
        vol = 0.8, pitch = 0.85,
        shake   = 0.38,
        cleanup = 4,
    },

    LEGENDARY = {
        col1  = Color3.fromRGB(255, 215,   0),
        col2  = Color3.fromRGB(255, 100,   0),
        count = 180,  speed = 28, life = 2.6, size = 1.6,
        lCol    = Color3.fromRGB(255, 200,   0),
        lBright = 7, lRange = 50,
        soundId = "rbxassetid://131961136",
        vol = 1.0, pitch = 0.7,
        shake   = 0.65,
        cleanup = 5,
    },

    ULTRA_LEGENDARY = {
        col1  = Color3.fromRGB(255,  50,  50),
        col2  = Color3.fromRGB(255, 215,   0),
        count = 300,  speed = 40, life = 3.2, size = 2.2,
        lCol    = Color3.fromRGB(255,  70,  70),
        lBright = 10, lRange = 70,
        soundId = "rbxassetid://131961136",
        vol = 1.0, pitch = 0.55,
        shake   = 1.0,
        cleanup = 5,
    },
}
-- Rétro-compat raretés legacy
CFG.NORMAL = CFG.COMMON
CFG.MYTHIC = CFG.EPIC
CFG.ULTRA  = CFG.LEGENDARY

-- ── Play ──────────────────────────────────────────────────────────────────────
function SpawnFX.Play(soclePart: BasePart, rarity: string, player: Player?)
    local c = CFG[rarity] or CFG.COMMON

    -- ── Attachment central (support de tout) ─────────────────────────────────
    local att = Instance.new("Attachment")
    att.Parent = soclePart
    Debris:AddItem(att, c.cleanup)

    -- ── ParticleEmitter — couche principale (burst coloré) ───────────────────
    local burst = Instance.new("ParticleEmitter")
    burst.Color          = cs(c.col1, c.col2)
    burst.LightEmission  = 0.9
    burst.LightInfluence = 0.05
    burst.Size           = ns(0.1, c.size, 0)
    burst.Transparency   = transparency(0.3, 0.6)
    burst.Lifetime       = NumberRange.new(c.life * 0.6, c.life)
    burst.Speed          = NumberRange.new(c.speed * 0.5, c.speed)
    burst.SpreadAngle    = Vector2.new(70, 70)
    burst.Rotation       = NumberRange.new(0, 360)
    burst.RotSpeed       = NumberRange.new(-200, 200)
    burst.Rate           = 0
    burst.Parent         = att
    burst:Emit(c.count)
    Debris:AddItem(burst, c.cleanup)

    -- ── ParticleEmitter — couche étincelles blanches (RARE+) ─────────────────
    if c.count >= 55 then
        local sparks = Instance.new("ParticleEmitter")
        sparks.Color          = ColorSequence.new(Color3.new(1, 1, 1))
        sparks.LightEmission  = 1
        sparks.LightInfluence = 0
        sparks.Size           = NumberSequence.new(0.12)
        sparks.Transparency   = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        })
        sparks.Lifetime       = NumberRange.new(c.life * 0.8, c.life * 1.2)
        sparks.Speed          = NumberRange.new(c.speed * 0.3, c.speed * 0.6)
        sparks.SpreadAngle    = Vector2.new(20, 20)
        sparks.Rate           = 0
        sparks.Parent         = att
        sparks:Emit(math.floor(c.count * 0.25))
        Debris:AddItem(sparks, c.cleanup)
    end

    -- ── Deuxième burst vers le haut (EPIC+) — effet fontaine ─────────────────
    if c.count >= 100 then
        local fountain = Instance.new("ParticleEmitter")
        fountain.Color          = cs(c.col2, c.col1)
        fountain.LightEmission  = 0.8
        fountain.LightInfluence = 0.1
        fountain.Size           = ns(0.05, c.size * 0.6, 0)
        fountain.Transparency   = transparency(0.1, 0.5)
        fountain.Lifetime       = NumberRange.new(c.life * 1.0, c.life * 1.5)
        fountain.Speed          = NumberRange.new(c.speed * 0.6, c.speed * 0.9)
        fountain.SpreadAngle    = Vector2.new(12, 12)
        fountain.Rotation       = NumberRange.new(0, 360)
        fountain.Rate           = 0
        fountain.Parent         = att
        fountain:Emit(math.floor(c.count * 0.4))
        Debris:AddItem(fountain, c.cleanup)
    end

    -- ── PointLight — flash lumineux ───────────────────────────────────────────
    local light = Instance.new("PointLight")
    light.Color      = c.lCol
    light.Brightness = c.lBright
    light.Range      = c.lRange
    light.Shadows    = true
    light.Parent     = soclePart
    Debris:AddItem(light, c.cleanup)

    -- ── Son d'explosion ───────────────────────────────────────────────────────
    local snd = Instance.new("Sound")
    snd.SoundId             = c.soundId
    snd.Volume              = c.vol
    snd.PlaybackSpeed       = c.pitch
    snd.RollOffMaxDistance  = 90
    snd.RollOffMode         = Enum.RollOffMode.InverseTapered
    snd.Parent              = soclePart
    snd:Play()
    Debris:AddItem(snd, c.cleanup)

    -- ── Camera Shake (client) ─────────────────────────────────────────────────
    if c.shake > 0 then
        if player then
            ShakeEvent:FireClient(player, c.shake)
        else
            ShakeEvent:FireAllClients(c.shake)
        end
    end

    print(string.format("[SpawnFX] %s | %d particules | shake=%.2f | cleanup=%.1fs",
        rarity, c.count, c.shake, c.cleanup))
end

return SpawnFX

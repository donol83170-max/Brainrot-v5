--!strict
-- SpawnFXClient.client.lua  (LocalScript — StarterPlayerScripts)
-- Reçoit le signal SpawnFXShake et applique un Camera Shake au joueur local.
--
-- Méthode : Humanoid.CameraOffset — propre, réversible, aucun risque de casser
-- les animations ou le streaming. L'offset est annulé automatiquement à la fin.

local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer

-- ── Attente des events ────────────────────────────────────────────────────────
local Events     = ReplicatedStorage:WaitForChild("Events")
local ShakeEvent = Events:WaitForChild("SpawnFXShake") :: RemoteEvent

-- ── État du shake actif ───────────────────────────────────────────────────────
-- Plusieurs shakes peuvent se superposer (ex : plusieurs joueurs spinent en même
-- temps). On garde le plus fort via currentIntensity.
local currentIntensity = 0
local shakeConn: RBXScriptConnection? = nil

-- ── Shake ─────────────────────────────────────────────────────────────────────
local function startShake(intensity: number)
    -- Booste l'intensité si un shake est déjà en cours (pas de reset brutal)
    currentIntensity = math.max(currentIntensity, intensity)

    -- Un seul loop actif à la fois
    if shakeConn then return end

    local FREQ      = 20          -- oscillations par seconde
    local DURATION  = 0.5 + intensity * 0.9  -- [0.5s → 1.4s]
    local MAGNITUDE = intensity * 0.55        -- amplitude max en studs

    local elapsed = 0

    shakeConn = RunService.RenderStepped:Connect(function(dt: number)
        local character = localPlayer.Character
        if not character then return end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end

        elapsed += dt

        -- Durée adaptative : on utilise l'intensité courante
        local totalDuration = 0.5 + currentIntensity * 0.9
        local t = elapsed / totalDuration

        if t >= 1 then
            humanoid.CameraOffset = Vector3.zero
            currentIntensity = 0
            if shakeConn then
                shakeConn:Disconnect()
                shakeConn = nil
            end
            return
        end

        -- Enveloppe de décroissance : rapide au début, s'estompe doucement
        local decay     = (1 - t) ^ 1.8
        local amplitude = currentIntensity * MAGNITUDE * decay

        -- Deux fréquences légèrement décalées → sensation organique
        local angle = elapsed * FREQ * math.pi * 2
        local ox = math.sin(angle * 1.0) * amplitude
        local oy = math.cos(angle * 0.7) * amplitude * 0.45

        humanoid.CameraOffset = Vector3.new(ox, oy, 0)
    end)
end

-- ── Écoute du RemoteEvent ─────────────────────────────────────────────────────
ShakeEvent.OnClientEvent:Connect(function(intensity: number)
    -- Sécurité : on clampe l'intensité pour ne jamais dépasser 1
    local safe = math.clamp(intensity, 0, 1)
    if safe > 0 then
        startShake(safe)
    end
end)

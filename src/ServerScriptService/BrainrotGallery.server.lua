--!strict
-- BrainrotGallery.server.lua v2
-- Système multi-parcelles : chaque joueur reçoit sa propre galerie sur l'Avenue Brainrot.
-- Les galeries sont alignées le long de l'axe X, toutes orientées face à -Z (vers la route).

local Workspace           = game:GetService("Workspace")
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataManager = require(ServerScriptService:WaitForChild("DataManager"))
local LootTables  = require(ReplicatedStorage:WaitForChild("LootTables"))

-- ══════════════════════════════════════════════════════════════════════════════
-- DOSSIER MAP
-- ══════════════════════════════════════════════════════════════════════════════
local mapFolder = Workspace:FindFirstChild("Map") or Instance.new("Folder")
if mapFolder.Parent ~= Workspace then
    mapFolder.Name   = "Map"
    mapFolder.Parent = Workspace
end

-- ══════════════════════════════════════════════════════════════════════════════
-- COULEURS
-- ══════════════════════════════════════════════════════════════════════════════
local COL_FLOOR      = Color3.fromRGB( 50,  50,  50)
local COL_RED_LINE   = Color3.fromRGB(196,  40,  28)
local COL_WALL_MID   = Color3.fromRGB( 27,  42,  31)
local COL_WALL_LIGHT = Color3.fromRGB( 27,  42,  31)
local COL_GOLD       = Color3.fromRGB(255, 215,   0)
local COL_PLAQUE     = Color3.fromRGB( 20,  20,  25)

local PEDESTAL_BASE_SHADES: {Color3} = {
    Color3.fromRGB(232, 232, 232),
    Color3.fromRGB(215, 215, 215),
    Color3.fromRGB(198, 198, 198),
    Color3.fromRGB(181, 181, 181),
    Color3.fromRGB(164, 164, 164),
}
local PEDESTAL_TOP_SHADES: {Color3} = {
    Color3.fromRGB(248, 248, 248),
    Color3.fromRGB(231, 231, 231),
    Color3.fromRGB(214, 214, 214),
    Color3.fromRGB(197, 197, 197),
    Color3.fromRGB(180, 180, 180),
}

local RARITY_PRIORITY: {[string]: number} = {ULTRA=5, LEGENDARY=4, MYTHIC=3, RARE=2, NORMAL=1}
local RARITY_COLOR: {[string]: Color3} = {
    NORMAL    = Color3.fromRGB(163, 162, 165),
    RARE      = Color3.fromRGB(  0, 162, 255),
    MYTHIC    = Color3.fromRGB(170,   0, 255),
    LEGENDARY = Color3.fromRGB(255, 170,   0),
    ULTRA     = Color3.fromRGB(255,   0, 127),
}

-- ══════════════════════════════════════════════════════════════════════════════
-- ITEM LOOKUP
-- ══════════════════════════════════════════════════════════════════════════════
local itemLookup: {[string]: {Name: string, Rarity: string}} = {}
for _, wheel in pairs(LootTables.Wheels) do
    for _, item in ipairs(wheel.Items) do
        if not itemLookup[item.Id] then
            itemLookup[item.Id] = {Name = item.Name, Rarity = item.Rarity}
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- TABLE D'IMAGES BRAINROT
-- (rbxassetid://XXXXXXX — laisser à 0 = aucune image affichée)
-- ══════════════════════════════════════════════════════════════════════════════
local BRAINROT_DATA: {[string]: number} = {
    -- Roue Noob
    BruhSound       = 0,
    NoobFace        = 0,
    DefaultPizza    = 0,
    MewingEmoji     = 0,
    BlueTie         = 0,
    SigmaSmile      = 0,
    GigachadJaw     = 0,
    PizzaTower      = 0,
    SkibidiHead     = 0,
    GoldenSigma     = 0,
    GalaxySigma     = 0,
    DiamondSkibidi  = 0,
    JokeCrafter     = 0,
    BrainrotKing    = 0,
    SkibidiGod      = 0,
    UltimateNoob    = 0,
    -- Roue Sigma
    CrunchyCookie   = 0,
    BasicRizzler    = 0,
    NpcFace         = 0,
    SigmaGrind      = 0,
    Rizzler500      = 0,
    BrainrotWave    = 0,
    SigmaKing       = 0,
    GlizzyGoblin    = 0,
    UltraRizzler    = 0,
    SigmaChad       = 0,
    OmegaSigma      = 0,
    DivineRizzler   = 0,
    ChadVibes       = 0,
    SigmaFlash      = 0,
    MegaRizzler     = 0,
    AbsoluteSigma   = 0,
    -- Roue Ultra
    CosmicNoob      = 0,
    VoidPizza       = 0,
    NebulaBruh      = 0,
    StarSigma       = 0,
    LunarSkibidi    = 0,
    GalacticMewing  = 0,
    NovaSigma       = 0,
    BlackHoleRizz   = 0,
    UniverseChad    = 0,
    CosmicSkibidi   = 0,
    AbsoluteGigachad = 0,
    TrueOmegaSigma  = 0,
    StarNoob        = 0,
    NebulaSigma     = 0,
    CelestialRizz   = 0,
    CosmicGigachad  = 0,
}

-- ══════════════════════════════════════════════════════════════════════════════
-- DIMENSIONS DE LA GALERIE
-- ══════════════════════════════════════════════════════════════════════════════
local NUM_SIDES   = 5          -- Socles de chaque côté
local PLACE_GAP   = 16         -- Espacement Z entre les socles
local SIDE_DIST   = 16         -- Distance X du centre au socle
local CORRIDOR_W  = 44         -- Largeur du couloir (X)
local WALL_H      = 20         -- Hauteur des murs
local WALL_T      = 2          -- Épaisseur des murs
local START_Z     = 110        -- Z de début de la galerie
local FLOOR_Y     = 1          -- Y du sol de la galerie
local GALLERY_LEN = (NUM_SIDES + 1) * PLACE_GAP  -- 96 studs de long

local SLOT_NAMES: {string} = {
    [1]  = "???  Slot 1",
    [2]  = "???  Slot 2",
    [3]  = "???  Slot 3",
    [4]  = "???  Slot 4",
    [5]  = "???  Slot 5",
    [6]  = "???  Slot 6",
    [7]  = "???  Slot 7",
    [8]  = "???  Slot 8",
    [9]  = "???  Slot 9",
    [10] = "???  Slot 10",
}

-- ══════════════════════════════════════════════════════════════════════════════
-- SYSTÈME DE PARCELLES (PLOTS)
-- Disposition : 1→X=0, 2→X=+STEP, 3→X=-STEP, 4→X=+2*STEP, ...
-- Les galeries s'alignent de chaque côté de l'avenue centrale (axe Z).
-- ══════════════════════════════════════════════════════════════════════════════
local PLOT_STEP   = CORRIDOR_W + 8   -- 52 studs entre les centres de galerie (axe X)
local MAX_PLOTS   = 40

local nextPlotIndex                    = 1
local plotAssignments: {[number]: number} = {}  -- [userId] = plotIndex

local function getPlotOffsetX(plotIndex: number): number
    if plotIndex == 1 then return 0 end
    local n = math.ceil((plotIndex - 1) / 2)
    if (plotIndex - 1) % 2 == 1 then
        return n * PLOT_STEP    -- Droite : +STEP, +2*STEP, ...
    else
        return -n * PLOT_STEP   -- Gauche : -STEP, -2*STEP, ...
    end
end

-- État par parcelle
type PedestalRef = {top: Part, nameLabel: TextLabel, decal: Decal}
type PlotState = {
    folder       : Folder,
    pedestalRefs : {[number]: PedestalRef},
    displayParts : {[number]: any},
    signLabelRef : TextLabel?,
}
local plotState: {[number]: PlotState} = {}

-- ══════════════════════════════════════════════════════════════════════════════
-- CONSTRUCTEUR DE GALERIE (par parcelle)
-- ══════════════════════════════════════════════════════════════════════════════
local function buildGallery(player: Player, plotIndex: number): PlotState
    local offsetX    = getPlotOffsetX(plotIndex)
    local playerName = player.Name
    local userId     = player.UserId

    -- Dossier unique par joueur (identifié par userId côté client)
    local folder = Instance.new("Folder")
    folder.Name   = "BrainrotGallery_" .. tostring(userId)
    folder.Parent = mapFolder

    -- Helper : crée une Part avec offset X automatique, parentée au dossier de la parcelle
    local function mp(
        name    : string,
        size    : Vector3,
        localPos: Vector3,
        color   : Color3,
        material: Enum.Material,
        topSurf : Enum.SurfaceType?
    ): Part
        local p = Instance.new("Part")
        p.Name          = name
        p.Size          = size
        p.Position      = Vector3.new(localPos.X + offsetX, localPos.Y, localPos.Z)
        p.Anchored      = true
        p.CanCollide    = true
        p.Color         = color
        p.Material      = material
        p.Reflectance   = 0
        p.TopSurface    = topSurf or Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        p.Parent        = folder
        return p
    end

    -- ── 1. SOL ────────────────────────────────────────────────────────────────
    mp("GalleryFloor",
        Vector3.new(CORRIDOR_W, 1, GALLERY_LEN + 8),
        Vector3.new(0, FLOOR_Y - 0.5, START_Z + GALLERY_LEN / 2),
        COL_FLOOR, Enum.Material.SmoothPlastic, Enum.SurfaceType.Studs)

    mp("CenterLine",
        Vector3.new(1.5, 0.1, GALLERY_LEN + 8),
        Vector3.new(0, FLOOR_Y + 0.05, START_Z + GALLERY_LEN / 2),
        COL_RED_LINE, Enum.Material.SmoothPlastic, Enum.SurfaceType.Smooth)

    -- ── 2. MURS ───────────────────────────────────────────────────────────────
    local FULL_WALL_LEN = GALLERY_LEN + 8
    local WALL_CZ       = START_Z + GALLERY_LEN / 2

    mp("WallLeft",
        Vector3.new(WALL_T, WALL_H, FULL_WALL_LEN),
        Vector3.new(-(CORRIDOR_W / 2), FLOOR_Y + WALL_H / 2, WALL_CZ),
        COL_WALL_MID, Enum.Material.SmoothPlastic, Enum.SurfaceType.Studs)

    mp("WallRight",
        Vector3.new(WALL_T, WALL_H, FULL_WALL_LEN),
        Vector3.new(CORRIDOR_W / 2, FLOOR_Y + WALL_H / 2, WALL_CZ),
        COL_WALL_MID, Enum.Material.SmoothPlastic, Enum.SurfaceType.Studs)

    mp("WallBack",
        Vector3.new(CORRIDOR_W + WALL_T * 2, WALL_H, WALL_T),
        Vector3.new(0, FLOOR_Y + WALL_H / 2, START_Z + GALLERY_LEN + 4),
        COL_WALL_LIGHT, Enum.Material.SmoothPlastic)

    -- ── 3. PLAFOND ────────────────────────────────────────────────────────────
    local ceiling = mp("GalleryCeiling",
        Vector3.new(CORRIDOR_W, 1, GALLERY_LEN + 8),
        Vector3.new(0, FLOOR_Y + WALL_H + 0.5, START_Z + GALLERY_LEN / 2),
        Color3.fromRGB(40, 40, 40), Enum.Material.SmoothPlastic, Enum.SurfaceType.Studs)
    ceiling.Reflectance = 0

    mp("CeilingRedLine",
        Vector3.new(1.5, 0.1, GALLERY_LEN + 8),
        Vector3.new(0, FLOOR_Y + WALL_H, START_Z + GALLERY_LEN / 2),
        COL_RED_LINE, Enum.Material.SmoothPlastic)

    -- ── 4. SOCLES D'EXPOSITION ────────────────────────────────────────────────
    local pedestalRefs: {[number]: PedestalRef} = {}

    for i = 1, NUM_SIDES do
        local placeZ = START_Z + i * PLACE_GAP

        for _, side in ipairs({-1, 1}) do
            local sideLabel = side == -1 and "L" or "R"
            local baseX     = side * SIDE_DIST

            local base = mp("PedestalBase_" .. i .. sideLabel,
                Vector3.new(7, 1.5, 7),
                Vector3.new(baseX, FLOOR_Y + 0.75, placeZ),
                PEDESTAL_BASE_SHADES[i], Enum.Material.SmoothPlastic, Enum.SurfaceType.Studs)

            mp("PedestalMid_" .. i .. sideLabel,
                Vector3.new(5, 1, 5),
                Vector3.new(baseX, FLOOR_Y + 2, placeZ),
                PEDESTAL_BASE_SHADES[i], Enum.Material.SmoothPlastic, Enum.SurfaceType.Studs)

            local topPart = mp("PedestalTop_" .. i .. sideLabel,
                Vector3.new(6, 0.5, 6),
                Vector3.new(baseX, FLOOR_Y + 2.75, placeZ),
                PEDESTAL_TOP_SHADES[i], Enum.Material.SmoothPlastic, Enum.SurfaceType.Studs)

            -- Numéro de la place (BillboardGui sur le socle)
            local slotIndex = (i - 1) * 2 + (side == -1 and 1 or 2)

            local numBillboard = Instance.new("BillboardGui")
            numBillboard.Size        = UDim2.new(0, 60, 0, 30)
            numBillboard.StudsOffset = Vector3.new(0, 2, 0)
            numBillboard.Adornee     = base
            numBillboard.AlwaysOnTop = false
            numBillboard.Parent      = folder

            local numLabel = Instance.new("TextLabel")
            numLabel.Size                   = UDim2.new(1, 0, 1, 0)
            numLabel.BackgroundTransparency = 1
            numLabel.Text                   = "#" .. slotIndex
            numLabel.TextColor3             = Color3.fromRGB(50, 50, 60)
            numLabel.Font                   = Enum.Font.FredokaOne
            numLabel.TextSize               = 22
            numLabel.TextStrokeTransparency = 0.8
            numLabel.Parent                 = numBillboard

            -- ── Cadres en or (4 bordures) ────────────────────────────────────
            local wallInnerX = side * (CORRIDOR_W / 2 - WALL_T - 0.05)
            local frameH  = 10
            local frameW  = 10
            local frameCY = FLOOR_Y + 9
            local bT      = 0.75

            local fTop = mp("GoldFrameTop_" .. i .. sideLabel,
                Vector3.new(0.15, bT, frameW),
                Vector3.new(wallInnerX, frameCY + (frameH - bT) / 2, placeZ),
                COL_GOLD, Enum.Material.Metal)
            fTop.CanCollide = false

            local fBot = mp("GoldFrameBot_" .. i .. sideLabel,
                Vector3.new(0.15, bT, frameW),
                Vector3.new(wallInnerX, frameCY - (frameH - bT) / 2, placeZ),
                COL_GOLD, Enum.Material.Metal)
            fBot.CanCollide = false

            local fLeft = mp("GoldFrameLeft_" .. i .. sideLabel,
                Vector3.new(0.15, frameH - bT * 2, bT),
                Vector3.new(wallInnerX, frameCY, placeZ - (frameW - bT) / 2),
                COL_GOLD, Enum.Material.Metal)
            fLeft.CanCollide = false

            local fRight = mp("GoldFrameRight_" .. i .. sideLabel,
                Vector3.new(0.15, frameH - bT * 2, bT),
                Vector3.new(wallInnerX, frameCY, placeZ + (frameW - bT) / 2),
                COL_GOLD, Enum.Material.Metal)
            fRight.CanCollide = false

            -- ── Plaque d'identification ───────────────────────────────────────
            local slotName = SLOT_NAMES[slotIndex] or ("Slot " .. slotIndex)

            local plaque = mp("Plaque_" .. i .. sideLabel,
                Vector3.new(7, 0.3, 1.5),
                Vector3.new(baseX, FLOOR_Y + 1.7, placeZ),
                COL_PLAQUE, Enum.Material.SmoothPlastic)
            plaque.CanCollide = false

            local plaqueRim = mp("PlaqueRim_" .. i .. sideLabel,
                Vector3.new(7.3, 0.1, 1.8),
                Vector3.new(baseX, FLOOR_Y + 1.55, placeZ),
                COL_GOLD, Enum.Material.Metal)
            plaqueRim.CanCollide = false

            local sGui = Instance.new("SurfaceGui")
            sGui.Name        = "NamePlaque"
            sGui.Face        = Enum.NormalId.Top
            sGui.CanvasSize  = Vector2.new(350, 60)
            sGui.SizingMode  = Enum.SurfaceGuiSizingMode.FixedSize
            sGui.AlwaysOnTop = false
            sGui.Parent      = plaque

            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size                   = UDim2.new(1, 0, 1, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text                   = slotName
            nameLabel.TextColor3             = COL_GOLD
            nameLabel.Font                   = Enum.Font.GothamBold
            nameLabel.TextSize               = 22
            nameLabel.TextXAlignment         = Enum.TextXAlignment.Center
            nameLabel.TextYAlignment         = Enum.TextYAlignment.Center
            nameLabel.TextStrokeTransparency = 0.6
            nameLabel.TextStrokeColor3       = Color3.new(0, 0, 0)
            nameLabel.Parent                 = sGui

            -- ── Panneau image (fond du cadre) ─────────────────────────────────
            local innerH = frameH - bT * 2
            local innerW = frameW - bT * 2
            local imgPanel = mp("ImgPanel_" .. i .. sideLabel,
                Vector3.new(0.12, innerH, innerW),
                Vector3.new(wallInnerX, frameCY, placeZ),
                Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic)
            imgPanel.CanCollide = false

            local decal = Instance.new("Decal")
            decal.Texture = ""
            decal.Face    = side == -1 and Enum.NormalId.Right or Enum.NormalId.Left
            decal.Parent  = imgPanel

            pedestalRefs[slotIndex] = {top = topPart, nameLabel = nameLabel, decal = decal}

            -- ── Spot au sol (uplighting) ──────────────────────────────────────
            local floorSpotPart = mp("FloorSpot_" .. i .. sideLabel,
                Vector3.new(0.6, 0.3, 0.6),
                Vector3.new(baseX - side * 4, FLOOR_Y + 0.15, placeZ),
                Color3.fromRGB(30, 30, 30), Enum.Material.Metal)
            floorSpotPart.CanCollide = false

            local floorSpot = Instance.new("SpotLight")
            floorSpot.Face       = Enum.NormalId.Top
            floorSpot.Brightness = 1.5
            floorSpot.Range      = 8
            floorSpot.Angle      = 30
            floorSpot.Color      = Color3.fromRGB(255, 240, 200)
            floorSpot.Shadows    = true
            floorSpot.Parent     = floorSpotPart
        end
    end

    -- ── 5. ENSEIGNE "BASE DE [Joueur]" ────────────────────────────────────────
    local signPlaque = mp("GallerySignPlaque",
        Vector3.new(CORRIDOR_W - 4, 5, 3),
        Vector3.new(0, FLOOR_Y + WALL_H - 2, START_Z - 6),
        COL_PLAQUE, Enum.Material.SmoothPlastic)
    signPlaque.CanCollide = false

    local signRim = mp("GallerySignRim",
        Vector3.new(CORRIDOR_W - 2, 5.5, 0.4),
        Vector3.new(0, FLOOR_Y + WALL_H - 2, START_Z - 4.3),
        COL_GOLD, Enum.Material.Metal)
    signRim.CanCollide = false

    -- SurfaceGui : LightInfluence=0 → toujours visible même dans la galerie sombre
    local signSGui = Instance.new("SurfaceGui")
    signSGui.Name           = "GallerySignGui"
    signSGui.Face           = Enum.NormalId.Front  -- -Z = face vers le spawn
    signSGui.CanvasSize     = Vector2.new(520, 100)
    signSGui.SizingMode     = Enum.SurfaceGuiSizingMode.FixedSize
    signSGui.LightInfluence = 0
    signSGui.AlwaysOnTop    = false
    signSGui.ZOffset        = 1
    signSGui.Parent         = signPlaque

    local signLabel = Instance.new("TextLabel")
    signLabel.Name                   = "GallerySignLabel"
    signLabel.Size                   = UDim2.new(1, 0, 1, 0)
    signLabel.BackgroundColor3       = Color3.new(0, 0, 0)
    signLabel.BackgroundTransparency = 0.1
    signLabel.Text                   = "★  BASE DE " .. string.upper(playerName) .. "  ★"
    signLabel.TextColor3             = Color3.fromRGB(255, 230, 0)
    signLabel.Font                   = Enum.Font.GothamBlack
    signLabel.TextScaled             = true
    signLabel.TextStrokeTransparency = 0
    signLabel.TextStrokeColor3       = Color3.new(0, 0, 0)
    signLabel.Parent                 = signSGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent       = signLabel

    -- ── 6. LAMPADAIRES D'ENTRÉE ───────────────────────────────────────────────
    do
        local LAMP_POLE_COLOR = Color3.fromRGB(50, 50, 55)
        local LAMP_BULB_COLOR = Color3.fromRGB(255, 220, 120)
        local poleH = 16

        for _, side in ipairs({-1, 1}) do
            local sLbl = side == -1 and "L" or "R"
            local lx   = side * (CORRIDOR_W / 2 + 1)
            local lz   = START_Z - 4

            local pole = mp("EntryPole_" .. sLbl,
                Vector3.new(1, poleH, 1),
                Vector3.new(lx, FLOOR_Y + poleH / 2, lz),
                LAMP_POLE_COLOR, Enum.Material.Metal)
            pole.CanCollide = false

            local cap = mp("EntryLampCap_" .. sLbl,
                Vector3.new(2.8, 0.5, 2.8),
                Vector3.new(lx, FLOOR_Y + poleH + 0.25, lz),
                LAMP_POLE_COLOR, Enum.Material.Metal)
            cap.CanCollide = false

            local bulb = mp("EntryLampBulb_" .. sLbl,
                Vector3.new(2, 1.5, 2),
                Vector3.new(lx, FLOOR_Y + poleH - 0.5, lz),
                LAMP_BULB_COLOR, Enum.Material.SmoothPlastic)
            bulb.CanCollide = false

            local light = Instance.new("PointLight")
            light.Color      = LAMP_BULB_COLOR
            light.Brightness = 3
            light.Range      = 22
            light.Shadows    = true
            light.Parent     = bulb
        end
    end

    -- ── 7. LUMIÈRES DE PLAFOND ────────────────────────────────────────────────
    for j = 1, NUM_SIDES do
        local lightZ    = START_Z + j * PLACE_GAP
        local lightPart = mp("CeilingLight_" .. j,
            Vector3.new(1.5, 0.3, 1.5),
            Vector3.new(0, FLOOR_Y + WALL_H - 0.5, lightZ),
            Color3.fromRGB(255, 255, 240), Enum.Material.SmoothPlastic)
        lightPart.CanCollide = false

        local pt = Instance.new("PointLight")
        pt.Brightness = 1.2
        pt.Range      = 14
        pt.Color      = Color3.fromRGB(255, 240, 200)
        pt.Shadows    = false
        pt.Parent     = lightPart
    end

    -- ── 8. LUMIÈRES D'AMBIANCE (8 points) ────────────────────────────────────
    local edgeX  = CORRIDOR_W / 2 - WALL_T - 4
    local midY   = FLOOR_Y + WALL_H / 2
    local frontZ = START_Z + 2
    local backZ  = START_Z + GALLERY_LEN + 2

    local ambPositions = {
        Vector3.new(-edgeX, midY, frontZ),
        Vector3.new( edgeX, midY, frontZ),
        Vector3.new(-edgeX, midY, backZ),
        Vector3.new( edgeX, midY, backZ),
        Vector3.new(-edgeX, midY, START_Z + GALLERY_LEN * 0.33),
        Vector3.new( edgeX, midY, START_Z + GALLERY_LEN * 0.33),
        Vector3.new(-edgeX, midY, START_Z + GALLERY_LEN * 0.66),
        Vector3.new( edgeX, midY, START_Z + GALLERY_LEN * 0.66),
    }

    for k, pos in ipairs(ambPositions) do
        local amb = Instance.new("Part")
        amb.Name         = "AmbientLight_" .. k
        amb.Size         = Vector3.new(0.2, 0.2, 0.2)
        amb.Position     = Vector3.new(pos.X + offsetX, pos.Y, pos.Z)
        amb.Anchored     = true
        amb.CanCollide   = false
        amb.Transparency = 1
        amb.CastShadow   = false
        amb.Parent       = folder

        local pl = Instance.new("PointLight")
        pl.Color      = Color3.fromRGB(255, 255, 255)
        pl.Brightness = 3.5
        pl.Range      = 25
        pl.Shadows    = false
        pl.Parent     = amb
    end

    print(string.format("[BrainrotGallery] Galerie #%d creee pour %s (X=%d)", plotIndex, playerName, offsetX))

    return {
        folder       = folder,
        pedestalRefs = pedestalRefs,
        displayParts = {},
        signLabelRef = signLabel,
    }
end

-- ══════════════════════════════════════════════════════════════════════════════
-- FIGURINES (par état de parcelle)
-- ══════════════════════════════════════════════════════════════════════════════
local function createFigurine(state: PlotState, slotIndex: number, itemData: any)
    if state.displayParts[slotIndex] then
        (state.displayParts[slotIndex] :: Part):Destroy()
        state.displayParts[slotIndex] = nil
    end
    if not itemData then return end

    local refs = state.pedestalRefs[slotIndex]
    if not refs then return end

    local topPos       = refs.top.Position
    local rarityColor  = RARITY_COLOR[itemData.Rarity] or RARITY_COLOR.NORMAL
    local isHighRarity = itemData.Rarity == "ULTRA" or itemData.Rarity == "LEGENDARY"

    local fig = Instance.new("Part")
    fig.Name        = "Figurine_" .. slotIndex
    fig.Size        = Vector3.new(3, 4, 3)
    fig.Position    = topPos + Vector3.new(0, 2.25, 0)
    fig.Anchored    = true
    fig.CanCollide  = false
    fig.Color       = rarityColor
    fig.Material    = Enum.Material.SmoothPlastic
    fig.Reflectance = isHighRarity and 0.1 or 0
    fig.Parent      = state.folder

    if itemData.Rarity == "ULTRA" then
        local sparkles = Instance.new("Sparkles")
        sparkles.SparkleColor = rarityColor
        sparkles.Parent       = fig
    end

    if isHighRarity then
        local light = Instance.new("PointLight")
        light.Color      = rarityColor
        light.Brightness = 1.5
        light.Range      = 6
        light.Parent     = fig
    end

    local bb = Instance.new("BillboardGui")
    bb.Size        = UDim2.new(0, 160, 0, 36)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = false
    bb.MaxDistance = 40
    bb.Adornee     = fig
    bb.Parent      = fig

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = itemData.Name
    lbl.TextColor3             = rarityColor
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextScaled             = true
    lbl.TextStrokeTransparency = 0.3
    lbl.TextStrokeColor3       = Color3.new(0, 0, 0)
    lbl.Parent                 = bb

    state.displayParts[slotIndex] = fig
end

-- ══════════════════════════════════════════════════════════════════════════════
-- MISE À JOUR DE LA GALERIE (inventaire du joueur → socles)
-- ══════════════════════════════════════════════════════════════════════════════
local function refreshGallery(player: Player)
    local plotIndex = plotAssignments[player.UserId]
    if not plotIndex then return end
    local state = plotState[plotIndex]
    if not state then return end

    -- Polling : attend que DataManager ait chargé les données (max 10 sec)
    local data = nil
    for _ = 1, 20 do
        data = DataManager.GetData(player)
        if data then break end
        task.wait(0.5)
    end

    if not data then
        print("[BrainrotGallery] Aucune donnee pour " .. player.Name .. " — socles vides")
        return
    end

    -- Collecte des items possédés
    local ownedItems: {{Name: string, Rarity: string, Priority: number, Id: string}} = {}
    for itemId, invItem in pairs(data.Inventory) do
        local info = itemLookup[itemId]
        if info and invItem.Count > 0 then
            table.insert(ownedItems, {
                Id       = itemId,
                Name     = info.Name,
                Rarity   = info.Rarity,
                Priority = RARITY_PRIORITY[info.Rarity] or 0,
            })
        end
    end

    -- Tri par rareté décroissante, puis par nom
    table.sort(ownedItems, function(a, b)
        if a.Priority ~= b.Priority then return a.Priority > b.Priority end
        return a.Name < b.Name
    end)

    -- Mise à jour des 10 socles
    for slotIndex = 1, NUM_SIDES * 2 do
        local item = ownedItems[slotIndex]
        local refs = state.pedestalRefs[slotIndex]
        if refs then
            if item then
                refs.nameLabel.Text       = item.Name
                refs.nameLabel.TextColor3 = RARITY_COLOR[item.Rarity] or COL_GOLD
                createFigurine(state, slotIndex, item)
                local imgId = BRAINROT_DATA[item.Id or ""]
                if imgId and imgId ~= 0 then
                    refs.decal.Texture = "rbxassetid://" .. imgId
                else
                    refs.decal.Texture = ""
                end
            else
                refs.nameLabel.Text       = "???  Slot " .. slotIndex
                refs.nameLabel.TextColor3 = COL_GOLD
                createFigurine(state, slotIndex, nil)
                refs.decal.Texture = ""
            end
        end
    end

    print("[BrainrotGallery] Galerie #" .. plotIndex .. " maj pour " .. player.Name
        .. " (" .. #ownedItems .. " items)")
end

-- ══════════════════════════════════════════════════════════════════════════════
-- AVENUE CENTRALE (route le long de l'axe X, devant toutes les galeries)
-- ══════════════════════════════════════════════════════════════════════════════
do
    -- Largeur totale : couvre MAX_PLOTS/2 plots de chaque côté + marge
    local AVENUE_HALF_LEN = (MAX_PLOTS / 2 + 2) * PLOT_STEP + CORRIDOR_W / 2
    -- Profondeur : du spawn (Z≈76) jusqu'à l'entrée des galeries (Z=START_Z-2)
    local AVENUE_DEPTH = START_Z - 76
    local AVENUE_CZ    = 76 + AVENUE_DEPTH / 2

    -- Sol de la route (asphalte gris foncé)
    local roadPart = Instance.new("Part")
    roadPart.Name          = "CityAvenue"
    roadPart.Size          = Vector3.new(AVENUE_HALF_LEN * 2, 1, AVENUE_DEPTH)
    roadPart.Position      = Vector3.new(0, FLOOR_Y - 0.5, AVENUE_CZ)
    roadPart.Anchored      = true
    roadPart.CanCollide    = true
    roadPart.Color         = Color3.fromRGB(72, 72, 72)
    roadPart.Material      = Enum.Material.SmoothPlastic
    roadPart.Reflectance   = 0
    roadPart.TopSurface    = Enum.SurfaceType.Smooth
    roadPart.BottomSurface = Enum.SurfaceType.Smooth
    roadPart.Parent        = mapFolder

    -- Ligne centrale (marquage au sol jaune)
    local centerMark = Instance.new("Part")
    centerMark.Name          = "AvenueCenter"
    centerMark.Size          = Vector3.new(1, 0.1, AVENUE_DEPTH)
    centerMark.Position      = Vector3.new(0, FLOOR_Y + 0.05, AVENUE_CZ)
    centerMark.Anchored      = true
    centerMark.CanCollide    = false
    centerMark.Color         = Color3.fromRGB(255, 215, 0)
    centerMark.Material      = Enum.Material.SmoothPlastic
    centerMark.Reflectance   = 0
    centerMark.TopSurface    = Enum.SurfaceType.Smooth
    centerMark.BottomSurface = Enum.SurfaceType.Smooth
    centerMark.Parent        = mapFolder

    -- Bordures de trottoir (côté galeries)
    for _, side in ipairs({-1, 1}) do
        local curb = Instance.new("Part")
        curb.Name          = "AvenueCurb_" .. (side == -1 and "L" or "R")
        curb.Size          = Vector3.new(AVENUE_HALF_LEN * 2, 0.4, 1)
        curb.Position      = Vector3.new(0, FLOOR_Y + 0.2, AVENUE_CZ + side * (AVENUE_DEPTH / 2 - 0.5))
        curb.Anchored      = true
        curb.CanCollide    = true
        curb.Color         = Color3.fromRGB(180, 180, 180)
        curb.Material      = Enum.Material.SmoothPlastic
        curb.Reflectance   = 0
        curb.Parent        = mapFolder
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- STREAMING ENABLED (optimisation : charge uniquement les parties proches)
-- ══════════════════════════════════════════════════════════════════════════════
Workspace.StreamingEnabled = true
pcall(function()
    -- Ces propriétés sont configurables via Studio ou via script selon la version
    (Workspace :: any).StreamingMinDistance    = 64
    (Workspace :: any).StreamingTargetDistance = 512
end)
print("[BrainrotGallery] StreamingEnabled active (min=64, target=512)")

-- ══════════════════════════════════════════════════════════════════════════════
-- GESTION DES JOUEURS
-- ══════════════════════════════════════════════════════════════════════════════
local function onPlayerAdded(player: Player)
    if plotAssignments[player.UserId] then return end  -- Reconnexion : parcelle déjà assignée

    if nextPlotIndex > MAX_PLOTS then
        warn("[BrainrotGallery] Limite de " .. MAX_PLOTS .. " parcelles atteinte !")
        return
    end

    local plotIndex = nextPlotIndex
    nextPlotIndex  += 1
    plotAssignments[player.UserId] = plotIndex

    -- Construire la galerie pour ce joueur
    local state = buildGallery(player, plotIndex)
    plotState[plotIndex] = state

    -- Mettre les socles à jour selon l'inventaire
    task.spawn(refreshGallery, player)
end

Players.PlayerAdded:Connect(onPlayerAdded)

-- Joueurs déjà connectés au démarrage (mode Studio test)
for _, p in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, p)
end

print("[BrainrotGallery] Systeme multi-parcelles pret. Max " .. MAX_PLOTS .. " joueurs.")

-- BrainrotModelsSetup.server.lua
-- Fusionne TOUS les modèles brainrot trouvés dans ReplicatedStorage
-- dans un dossier unifié "BrainrotModels" pour WheelSystem et BrainrotGallery.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Créer ou récupérer le dossier unifié
local folder = ReplicatedStorage:FindFirstChild("BrainrotModels")
if not folder then
    folder        = Instance.new("Folder")
    folder.Name   = "BrainrotModels"
    folder.Parent = ReplicatedStorage
end

-- Noms de sources à chercher (au premier niveau ET en profondeur dans ReplicatedStorage)
local SOURCE_NAMES = {
    "Brainrots",        -- Brainrots.rbxm (peut être dans BrainrotModels/ ou à la racine)
    "BrainrotPack",     -- BrainrotPack.rbxm (déclaré explicitement dans project.json)
    "Brainrot pack1",   -- Ancien dossier Studio (préservé par $ignoreUnknownInstances)
}

local totalImported = 0

-- Fonction utilitaire : importer les enfants d'un conteneur dans le dossier unifié
local function importFrom(source: Instance)
    local count = 0
    for _, child in ipairs(source:GetChildren()) do
        if child:IsA("Model") or child:IsA("MeshPart") or child:IsA("BasePart") then
            if not folder:FindFirstChild(child.Name) then
                local cloned = child:Clone()
                cloned.Parent = folder
                totalImported += 1
                count += 1
            end
        elseif child:IsA("Folder") then
            -- Dossier imbriqué → descendre d'un niveau
            for _, subChild in ipairs(child:GetChildren()) do
                if (subChild:IsA("Model") or subChild:IsA("BasePart")) and not folder:FindFirstChild(subChild.Name) then
                    local cloned = subChild:Clone()
                    cloned.Parent = folder
                    totalImported += 1
                    count += 1
                end
            end
        end
    end
    return count
end

-- 1. Chercher les sources par nom (racine + récursif)
for _, sourceName in ipairs(SOURCE_NAMES) do
    -- Chercher au premier niveau de ReplicatedStorage
    local source = ReplicatedStorage:FindFirstChild(sourceName)
    -- Aussi chercher DANS BrainrotModels (Rojo y met les .rbxm du sous-dossier)
    if not source then
        source = folder:FindFirstChild(sourceName)
    end
    -- Recherche récursive en dernier recours
    if not source then
        source = ReplicatedStorage:FindFirstChild(sourceName, true)
    end

    if source then
        local count = importFrom(source)
        print(string.format("[BrainrotModels] Source '%s' trouvée → %d modèle(s) importé(s). (%s)",
            sourceName, count, source:GetFullName()))
    else
        warn(string.format("[BrainrotModels] Source '%s' introuvable.", sourceName))
    end
end

-- 2. Scan de sécurité : chercher TOUT ce qui ressemble à un conteneur de brainrots
--    (dossiers/modèles avec beaucoup d'enfants Model dans ReplicatedStorage)
for _, child in ipairs(ReplicatedStorage:GetChildren()) do
    if child ~= folder and (child:IsA("Folder") or child:IsA("Model")) then
        local modelCount = 0
        for _, sub in ipairs(child:GetChildren()) do
            if sub:IsA("Model") then modelCount += 1 end
        end
        -- Si un dossier contient 5+ modèles, c'est probablement un pack de brainrots
        if modelCount >= 5 then
            local count = importFrom(child)
            if count > 0 then
                print(string.format("[BrainrotModels] Pack détecté '%s' → %d modèle(s) importé(s).",
                    child.Name, count))
            end
        end
    end
end

-- 3. Déballer les conteneurs imbriqués dans BrainrotModels lui-même
--    (ex: "Brainrots" est un conteneur avec des modèles dedans)
for _, child in ipairs(folder:GetChildren()) do
    if (child:IsA("Folder") or child:IsA("Model")) and #child:GetChildren() > 0 then
        local hasModels = false
        for _, sub in ipairs(child:GetChildren()) do
            if sub:IsA("Model") then hasModels = true; break end
        end
        if hasModels then
            local count = 0
            for _, sub in ipairs(child:GetChildren()) do
                if sub:IsA("Model") and not folder:FindFirstChild(sub.Name) then
                    local cloned = sub:Clone()
                    cloned.Parent = folder
                    totalImported += 1
                    count += 1
                end
            end
            if count > 0 then
                print(string.format("[BrainrotModels] Conteneur '%s' déballé → %d modèle(s).", child.Name, count))
            end
        end
    end
end

print(string.format("[BrainrotModels] Dossier unifié prêt — %d modèle(s) total (%d importé(s)).",
    #folder:GetChildren(), totalImported))

-- Diagnostic : lister les 10 premiers
local children = folder:GetChildren()
for i = 1, math.min(10, #children) do
    print(string.format("  [%d] %s (%s)", i, children[i].Name, children[i].ClassName))
end
if #children > 10 then
    print(string.format("  ... et %d autres", #children - 10))
end

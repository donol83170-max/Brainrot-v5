# Guide d'Implémentation — Roblox Studio

> Conventions, bonnes pratiques et workflow de développement.

---

## Workflow de dev (story par story)

```
1. Ouvrir le plan de production → prendre la prochaine story TODO
2. Lire le PRD correspondant (rappel du contexte et des règles)
3. Relire l'architecture pour ce système
4. Coder dans Roblox Studio
5. Tester en Play Mode (solo + avec des joueurs si multi)
6. Si ça marche → marquer comme FAIT
7. Si un manque dans le design est découvert → STOP → compléter le PRD → reprendre
8. Story suivante
```

**Règle absolue :** NE JAMAIS improviser un design pendant le code.
Si quelque chose n'est pas dans les PRD, c'est soit un oubli (à corriger), soit pas nécessaire.

---

## Conventions de nommage

### Scripts

| Type | Convention | Exemple |
|------|-----------|---------|
| Server Script | `NomManager.server.lua` | `CombatManager.server.lua` |
| Client Script | `NomController.client.lua` | `InputController.client.lua` |
| Module Script | `NomModule.lua` | `DataModule.lua` |
| Config | `NomConfig.lua` | `GameConfig.lua` |

### Dossiers Roblox

| Dossier | Convention | Exemple |
|---------|-----------|---------|
| Zones (Workspace) | `Zone_NomZone` | `Zone_ForetEnchantee` |
| NPCs | `NPC_Nom` | `NPC_Forgeron` |
| Ennemis | `Enemy_Nom` | `Enemy_Gobelin` |
| Items (templates) | `Item_Nom` | `Item_EpeeEnFer` |
| UI | `UI_NomEcran` | `UI_Inventaire` |
| Effects | `FX_Nom` | `FX_LevelUp` |

### Variables Luau

```lua
-- Variables locales : camelCase
local playerData = {}
local maxHealth = 100

-- Constantes : UPPER_SNAKE_CASE
local MAX_INVENTORY_SLOTS = 20
local XP_PER_LEVEL_BASE = 100

-- Fonctions : camelCase (verbe + nom)
local function calculateDamage(attacker, target) end
local function savePlayerData(player) end

-- Services : PascalCase (standard Roblox)
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

-- RemoteEvents : PascalCase, verbe impératif
local RequestAttack = remoteEvents:FindFirstChild("RequestAttack")
local UpdateStats = remoteEvents:FindFirstChild("UpdateStats")
```

---

## Structure type d'un module

```lua
-- DataModule.lua
local DataModule = {}

-- Services
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

-- Constantes
local DATASTORE_NAME = "PlayerData_v1"
local AUTO_SAVE_INTERVAL = 300 -- 5 minutes

-- Variables privées
local playerDataCache = {}
local dataStore = DataStoreService:GetDataStore(DATASTORE_NAME)

-- Fonctions privées
local function getDefaultData()
    return {
        version = 1,
        level = 1,
        xp = 0,
        coins = 0,
    }
end

-- Fonctions publiques
function DataModule.loadData(player)
    -- [implémentation]
end

function DataModule.saveData(player)
    -- [implémentation]
end

function DataModule.getData(player)
    return playerDataCache[player.UserId]
end

return DataModule
```

---

## Patterns de sécurité

### Validation des RemoteEvents

```lua
-- MAUVAIS (ne JAMAIS faire ça)
attackEvent.OnServerEvent:Connect(function(player, targetId, damage)
    -- Le client envoie les dégâts → TRICHE FACILE
    target.Health -= damage
end)

-- BON
attackEvent.OnServerEvent:Connect(function(player, targetId)
    -- Le serveur calcule tout
    local target = findTarget(targetId)
    if not target then return end
    if not isInRange(player, target) then return end
    if isOnCooldown(player) then return end

    local damage = calculateDamage(player) -- calcul serveur
    applyDamage(target, damage)
end)
```

### Rate limiting

```lua
local lastAction = {}

local function rateLimitCheck(player, actionName, cooldown)
    local key = player.UserId .. "_" .. actionName
    local now = tick()
    if lastAction[key] and (now - lastAction[key]) < cooldown then
        return false -- trop rapide
    end
    lastAction[key] = now
    return true
end
```

---

## Gestion des erreurs DataStore

```lua
local function safeSave(player, data)
    local success, err
    for attempt = 1, 3 do
        success, err = pcall(function()
            dataStore:SetAsync("Player_" .. player.UserId, data)
        end)
        if success then break end
        warn("[DataStore] Tentative " .. attempt .. " échouée: " .. tostring(err))
        task.wait(2 ^ attempt) -- backoff exponentiel
    end
    if not success then
        warn("[DataStore] ÉCHEC SAUVEGARDE pour " .. player.Name)
    end
    return success
end
```

---

## Testing dans Roblox Studio

### Checklist de test par story

- [ ] **Fonctionnel** : La feature marche comme décrit dans le PRD
- [ ] **Edge cases** : Que se passe-t-il dans les cas limites ?
- [ ] **Multijoueur** : Tester en mode "Test > Start (2 players)"
- [ ] **Performance** : Vérifier le MicroProfiler (Ctrl+F6) pour les lags
- [ ] **Mobile** : Tester avec l'émulateur mobile de Studio
- [ ] **Sauvegarde** : Les données persistent après avoir quitté et rejoint

### Outils de debug Studio

| Outil | Raccourci | Usage |
|-------|-----------|-------|
| Output | View > Output | Voir les prints et erreurs |
| MicroProfiler | Ctrl+F6 | Analyser les performances frame par frame |
| Explorer | View > Explorer | Naviguer l'arborescence du jeu |
| Properties | View > Properties | Modifier les propriétés des objets |
| Script Analysis | View > Script Analysis | Trouver les erreurs de script |
| Test multi | Test > Start (X players) | Tester le multijoueur |
| Emulateur | Test > Device | Simuler mobile/tablette |

---

## Playtest avec des vrais joueurs

### Avant le playtest
1. Publier le jeu en mode **Privé**
2. Inviter les testeurs via Roblox (amis ou lien privé)
3. Préparer les questions à poser (voir plan de production)

### Pendant le playtest
- **Observer sans intervenir** (résister à l'envie d'aider)
- Noter les moments de confusion, frustration, plaisir
- Chronométrer la durée de session

### Après le playtest
- Recueillir le feedback (oral ou écrit)
- Identifier les 3 problèmes les plus critiques
- Créer des stories pour les corriger

---

## Publication

### Checklist pré-lancement

- [ ] Le jeu fonctionne sans crash pendant 30 minutes
- [ ] La sauvegarde/chargement marche parfaitement
- [ ] Le tutoriel guide correctement un nouveau joueur
- [ ] Les Game Passes fonctionnent (tester avec Robux de test)
- [ ] Pas de contenu inapproprié (vérifier les guidelines Roblox)
- [ ] Icône du jeu (512x512) et thumbnails (16:9) créés
- [ ] Description du jeu rédigée
- [ ] Genre correctement catégorisé
- [ ] Paramètres serveur configurés (max joueurs, streaming, etc.)

### Configuration Roblox

| Paramètre | Valeur recommandée |
|-----------|-------------------|
| Max Players | [20-50 selon le jeu] |
| Allow Copying | **Non** |
| StreamingEnabled | **Oui** (si grande map) |
| Genre | [Le genre qui correspond] |
| Devices | [PC + Mobile + Console] |
| Chat | [TextChatService activé] |

---

## Ressources utiles

| Ressource | URL | Usage |
|-----------|-----|-------|
| Roblox Creator Hub | create.roblox.com | Documentation officielle |
| DevForum | devforum.roblox.com | Communauté, tutos, aide |
| Toolbox | Dans Studio | Assets gratuits |
| Roblox API Reference | create.roblox.com/docs/reference | Référence API complète |

# Architecture Technique — [NOM DU JEU]

> Plan technique complet pour Roblox Studio. Chaque système, chaque service, chaque module.

---

## Vue d'ensemble

### Stack technique

| Composant | Technologie |
|-----------|------------|
| **Engine** | Roblox Studio |
| **Langage** | Luau (Roblox Lua) |
| **Persistence** | DataStoreService (+ OrderedDataStore pour classements) |
| **Communication** | RemoteEvents / RemoteFunctions |
| **UI** | Roblox GUI (ScreenGui, BillboardGui) |
| **Physique** | Roblox Physics Engine |
| **Audio** | SoundService |
| **Chat** | TextChatService |

### Architecture Client/Serveur

```
┌─────────────────────────────────────────────────────┐
│                    SERVEUR                           │
│  ServerScriptService/                               │
│  ├── GameManager.server.lua      (orchestration)    │
│  ├── DataManager.server.lua      (sauvegarde)       │
│  ├── CombatManager.server.lua    (dégâts, loot)     │
│  ├── EconomyManager.server.lua   (monnaie, shop)    │
│  └── [AutreManager].server.lua                      │
│                                                      │
│  ServerStorage/                                      │
│  ├── Modules/        (modules partagés serveur)      │
│  ├── Assets/         (modèles, items server-only)    │
│  └── Data/           (configs, tables de loot)       │
├──────────────────────┬──────────────────────────────┤
│   RemoteEvents /     │    RemoteFunctions            │
│   (fire-and-forget)  │    (request-response)         │
├──────────────────────┴──────────────────────────────┤
│                    CLIENT                            │
│  StarterPlayerScripts/                               │
│  ├── InputController.client.lua  (contrôles)         │
│  ├── UIController.client.lua     (interface)         │
│  ├── CameraController.client.lua (caméra)            │
│  └── EffectsController.client.lua (VFX, sons)        │
│                                                      │
│  ReplicatedStorage/                                  │
│  ├── Modules/        (modules partagés client+srv)   │
│  ├── Events/         (RemoteEvents)                  │
│  ├── Assets/         (modèles répliqués)             │
│  └── Config/         (constantes partagées)          │
└─────────────────────────────────────────────────────┘
```

### Règle d'or Client/Serveur

| Côté | Responsabilité | Exemples |
|------|---------------|----------|
| **Serveur** | Toute la LOGIQUE et les DONNÉES | Calcul de dégâts, sauvegarde, loot, économie, anti-triche |
| **Client** | Tout l'AFFICHAGE et les INPUTS | Rendu UI, animations, effets visuels, contrôles |
| **Partagé** | Constantes et types | Config, enums, types d'items |

> **Ne JAMAIS faire confiance au client.** Le serveur vérifie TOUT.

---

## Structure des dossiers Roblox

```
game/
├── Workspace/
│   ├── Map/
│   │   ├── Zone1_[Nom]/
│   │   ├── Zone2_[Nom]/
│   │   └── Zone3_[Nom]/
│   ├── NPCs/
│   ├── SpawnLocations/
│   └── Lighting/
│
├── ServerScriptService/
│   ├── [Chaque manager serveur]
│   └── Init.server.lua          (point d'entrée serveur)
│
├── ServerStorage/
│   ├── Modules/
│   │   ├── DataModule.lua
│   │   ├── CombatModule.lua
│   │   ├── LootModule.lua
│   │   └── [AutreModule].lua
│   ├── ItemTemplates/           (modèles d'items)
│   ├── EnemyTemplates/          (modèles d'ennemis)
│   └── Config/
│       ├── GameConfig.lua       (toutes les constantes)
│       ├── LootTables.lua       (tables de drop)
│       └── ShopPrices.lua       (prix boutique)
│
├── ReplicatedStorage/
│   ├── Modules/
│   │   ├── Types.lua            (types partagés)
│   │   ├── Utils.lua            (fonctions utilitaires)
│   │   └── Constants.lua        (constantes client+serveur)
│   ├── Events/
│   │   ├── CombatEvents/        (RemoteEvents combat)
│   │   ├── UIEvents/            (RemoteEvents UI)
│   │   └── SystemEvents/        (RemoteEvents système)
│   └── Assets/
│       ├── UI/                  (templates UI)
│       ├── Effects/             (particules, beams)
│       └── Sounds/              (sons)
│
├── StarterGui/
│   ├── HUD/                     (ScreenGui principal)
│   ├── Menus/                   (menus, popups)
│   └── Notifications/           (toasts, alerts)
│
├── StarterPlayerScripts/
│   ├── [Controllers client]
│   └── Init.client.lua          (point d'entrée client)
│
├── StarterCharacterScripts/
│   └── [Scripts liés au personnage]
│
├── Lighting/
│   └── [Configuration d'éclairage]
│
└── SoundService/
    └── [Musiques et sons ambiants]
```

---

## Schéma DataStore

> Comment les données du joueur sont sauvegardées

### Structure de sauvegarde par joueur

```lua
PlayerData = {
    -- Identité
    version = 1,                    -- version du schéma (migration)
    firstJoin = timestamp,
    lastJoin = timestamp,
    totalPlayTime = number,         -- en secondes

    -- Progression
    level = number,
    xp = number,
    -- [Autres stats de progression]

    -- Économie
    coins = number,
    gems = number,
    -- [Autres monnaies]

    -- Inventaire
    inventory = {
        [itemId] = {
            id = string,
            quantity = number,
            -- [Propriétés spécifiques]
        },
    },

    -- Équipement
    equipped = {
        weapon = itemId or nil,
        armor = itemId or nil,
        -- [Autres slots]
    },

    -- Quêtes
    quests = {
        active = { [questId] = { progress = number } },
        completed = { [questId] = true },
        daily = { lastReset = timestamp, completed = {} },
    },

    -- Social
    -- [Données sociales si nécessaire]

    -- Paramètres
    settings = {
        musicVolume = number,
        sfxVolume = number,
        -- [Autres paramètres]
    },

    -- Achats
    purchases = {
        gamePasses = { [passId] = true },
        -- [Historique Dev Products si nécessaire]
    },
}
```

### Stratégie de sauvegarde

| | Détail |
|---|--------|
| **Fréquence auto-save** | [Toutes les 5 minutes] |
| **Save on leave** | [Oui — BindToClose + PlayerRemoving] |
| **Retry en cas d'échec** | [3 tentatives avec backoff exponentiel] |
| **Version du schéma** | [Numéro de version pour migrations futures] |
| **Backup** | [Sauvegarder l'ancien data avant migration] |

### Limites DataStore à respecter

| Limite | Valeur |
|--------|--------|
| Taille max par clé | 4 MB |
| Requêtes/minute (GET) | 60 + 10 × joueurs |
| Requêtes/minute (SET) | 60 + 10 × joueurs |
| Throttle | Respecter les budgets de requêtes |

---

## Map des RemoteEvents

### Client → Serveur (le joueur fait quelque chose)

| Event | Payload | Validation serveur |
|-------|---------|-------------------|
| `RequestAttack` | `{ targetId }` | Vérifier distance, cooldown, cible valide |
| `RequestBuyItem` | `{ itemId, quantity }` | Vérifier fonds, stock, prix |
| `RequestEquip` | `{ itemId, slot }` | Vérifier possession, type correct |
| `RequestTrade` | `{ targetPlayerId, offer }` | Vérifier les deux joueurs, items valides |
| | | |

### Serveur → Client (le serveur informe le joueur)

| Event | Payload | Usage |
|-------|---------|-------|
| `UpdateStats` | `{ hp, xp, level, coins }` | Mise à jour HUD |
| `UpdateInventory` | `{ inventory }` | Sync inventaire |
| `ShowNotification` | `{ text, type, duration }` | Notifications UI |
| `PlayEffect` | `{ effectType, position }` | VFX |
| `EnemySpawned` | `{ enemyData, position }` | Spawn ennemi côté client |
| | | |

### RemoteFunctions (request → response)

| Function | Request | Response | Usage |
|----------|---------|----------|-------|
| `GetShopItems` | `{ shopId }` | `{ items[] }` | Charger la boutique |
| `GetLeaderboard` | `{ type }` | `{ entries[] }` | Afficher classement |
| | | | |

---

## Systèmes techniques

> Lister chaque système qui doit être codé

| # | Système | Complexité | Dépendances | PRD source |
|---|---------|-----------|-------------|------------|
| 1 | Sauvegarde/Chargement | Haute | DataStoreService | Tous |
| 2 | Combat | Haute | Raycasting, Animations | PRD 02, 09 |
| 3 | Inventaire | Moyenne | DataStore, UI | PRD 08 |
| 4 | Économie/Shop | Moyenne | DataStore, MarketplaceService | PRD 05, 12 |
| 5 | Progression/XP | Basse | DataStore | PRD 04 |
| 6 | Spawn ennemis | Moyenne | CollectionService | PRD 09 |
| 7 | IA ennemis | Haute | Pathfinding | PRD 09 |
| 8 | UI/HUD | Moyenne | GUI, Events | PRD 06 |
| 9 | Quêtes | Moyenne | DataStore | PRD 04 |
| 10 | [Autre] | | | |

---

## Sécurité & Anti-triche

| Menace | Protection |
|--------|-----------|
| Speed hack | Vérifier la position serveur-side, téléporter si incohérent |
| Damage hack | Calculer les dégâts côté serveur uniquement |
| Dupe items | Opérations atomiques sur DataStore, vérifier avant trade |
| Auto-farm | Détection de patterns, captcha périodique (optionnel) |
| Exploit RemoteEvents | Valider CHAQUE argument, rate limiting par joueur |

### Principes de sécurité

1. **Le client est un menteur.** Toujours valider côté serveur.
2. **Rate limit** les RemoteEvents (max X par seconde par joueur).
3. **Sanitize** tous les inputs (pas de strings infinies, pas de nombres NaN).
4. **Log** les actions suspectes pour investigation.

---

## Performance

### Budget performance

| Métrique | Objectif | Alerte |
|----------|---------|--------|
| FPS | > 30 FPS mobile, > 60 FPS PC | < 20 FPS |
| Ping | < 200ms | > 500ms |
| Memory serveur | < 500 MB | > 800 MB |
| Instances Workspace | < 50K | > 80K |
| Scripts actifs | < 100 | > 200 |

### Techniques d'optimisation

- **Streaming** : Activer StreamingEnabled pour les grandes maps
- **LOD** : Objets low-poly à distance
- **Culling** : Ne pas répliquer ce qui est loin du joueur
- **Pooling** : Réutiliser les objets (ennemis, projectiles) plutôt que créer/détruire
- **Debounce** : Limiter la fréquence des RemoteEvents
- **Batch updates** : Grouper les mises à jour UI (pas 60 updates/sec)

---

## Services Roblox utilisés

| Service | Usage dans notre jeu |
|---------|---------------------|
| DataStoreService | Sauvegarde données joueurs |
| MarketplaceService | Game Passes, Dev Products |
| Players | Gestion joueurs |
| RunService | Game loop, Heartbeat |
| CollectionService | Tags pour ennemis, items, zones |
| PathfindingService | IA ennemis |
| TweenService | Animations UI et objets |
| SoundService | Musique et SFX |
| TextChatService | Chat |
| BadgeService | Achievements |
| TeleportService | Si multi-places |
| HttpService | JSON encode/decode |

---

## Questions clés

- [ ] Chaque système des PRD est-il couvert dans l'architecture ?
- [ ] La séparation client/serveur est-elle claire pour chaque système ?
- [ ] Le schéma DataStore couvre-t-il toutes les données nécessaires ?
- [ ] Les RemoteEvents sont-ils sécurisés (validation serveur) ?
- [ ] Le budget performance est-il réaliste pour le scope du jeu ?

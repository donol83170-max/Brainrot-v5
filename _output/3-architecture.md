# Architecture Technique — Dodgeball Royale

> Date : 2026-02-22
> Statut : EN COURS

---

## Vue d'ensemble

### Stack technique

| Composant | Technologie |
|-----------|------------|
| **Engine** | Roblox Studio |
| **Langage** | Luau |
| **Persistance** | DataStoreService + OrderedDataStore (classements) |
| **Communication** | RemoteEvents / RemoteFunctions |
| **UI** | Roblox ScreenGui + BillboardGui |
| **Physique balle** | Roblox Physics Engine + validation serveur |
| **Audio** | SoundService |
| **Chat** | TextChatService |
| **Achats** | MarketplaceService |
| **Badges** | BadgeService |

---

## Architecture Client / Serveur

```
┌──────────────────────────────────────────────────────────────┐
│                         SERVEUR                              │
│  ServerScriptService/                                        │
│  ├── Init.server.lua            (point d'entrée serveur)     │
│  ├── PlayerDataManager.server   (DataStore, sauvegarde)      │
│  ├── GameStateManager.server    (lobby ↔ match state)        │
│  ├── MatchManager.server        (cycle de vie d'un match)    │
│  ├── BallSystem.server          (physique + validation tirs) │
│  ├── PrisonSystem.server        (éliminations + libérations) │
│  ├── ZoneSystem.server          (zone dynamique + marée)     │
│  ├── BotController.server       (IA des bots)                │
│  ├── ProgressionSystem.server   (XP, niveaux, missions)      │
│  ├── ShopSystem.server          (boutique, achats Or/Robux)  │
│  └── LeaderboardSystem.server   (classements)               │
│                                                              │
├────────────────────┬─────────────────────────────────────────┤
│  RemoteEvents      │  RemoteFunctions                        │
│  (fire-and-forget) │  (request → response)                   │
├────────────────────┴─────────────────────────────────────────┤
│                         CLIENT                               │
│  StarterPlayerScripts/                                       │
│  ├── Init.client.lua            (point d'entrée client)      │
│  ├── InputController.client     (WASD, clic, touche E)       │
│  ├── UIController.client        (HUD, menus, notifications)  │
│  ├── EffectsController.client   (VFX, SFX, musique)          │
│  └── LobbyController.client     (lobby, file d'attente)      │
└──────────────────────────────────────────────────────────────┘
```

### Règle absolue Client/Serveur

| Côté | Responsabilité |
|------|----------------|
| **Serveur** | Toute la logique : validation des tirs, éliminations, XP, économie, anti-triche |
| **Client** | Tout l'affichage : HUD, animations, effets visuels, sons, inputs |
| **Partagé** | Constantes, types, IDs d'items, config du jeu |

> **Le client est un menteur. Le serveur vérifie TOUT.**

---

## Structure des dossiers Roblox

```
game/
├── Workspace/
│   ├── Lobby/
│   │   ├── Boardwalk/          (terrain lobby)
│   │   ├── SpawnLobby          (spawn point lobby)
│   │   └── NPCs/               (Maître de Plage, Marchand)
│   ├── Arena/
│   │   ├── Terrain/            (sable, obstacles)
│   │   ├── Obstacles/
│   │   │   ├── CoolerA         (glacière équipe A)
│   │   │   ├── CoolerB         (glacière équipe B)
│   │   │   └── SandCastle      (château de sable central)
│   │   ├── PrisonZones/
│   │   │   ├── PrisonA         (zone prison équipe A)
│   │   │   └── PrisonB         (zone prison équipe B)
│   │   ├── ZoneBoundary        (mur invisible de zone)
│   │   └── WaterPlane          (plan d'eau pour la marée)
│   └── Lighting/
│
├── ServerScriptService/
│   ├── Init.server.lua
│   ├── PlayerDataManager.server.lua
│   ├── GameStateManager.server.lua
│   ├── MatchManager.server.lua
│   ├── BallSystem.server.lua
│   ├── PrisonSystem.server.lua
│   ├── ZoneSystem.server.lua
│   ├── BotController.server.lua
│   ├── ProgressionSystem.server.lua
│   ├── ShopSystem.server.lua
│   └── LeaderboardSystem.server.lua
│
├── ServerStorage/
│   ├── Modules/
│   │   ├── DataModule.lua      (opérations DataStore)
│   │   ├── MatchModule.lua     (logique match)
│   │   ├── BallModule.lua      (logique balle)
│   │   └── ValidationModule.lua (anti-triche)
│   ├── BallTemplates/          (modèles 3D des balles par skin)
│   ├── EffectTemplates/        (particules, beams)
│   └── Config/
│       ├── GameConfig.lua      (toutes les constantes du jeu)
│       ├── ItemsConfig.lua     (liste complète des cosmétiques)
│       ├── MissionsConfig.lua  (pool de missions quotidiennes)
│       └── ShopConfig.lua      (prix + rotation boutique)
│
├── ReplicatedStorage/
│   ├── Modules/
│   │   ├── Types.lua           (types partagés Luau)
│   │   ├── Utils.lua           (fonctions utilitaires)
│   │   └── Constants.lua       (constantes client + serveur)
│   ├── Events/
│   │   ├── MatchEvents/        (RemoteEvents match)
│   │   ├── PlayerEvents/       (RemoteEvents joueur)
│   │   ├── UIEvents/           (RemoteEvents UI)
│   │   └── ShopEvents/         (RemoteEvents boutique)
│   └── Assets/
│       ├── UI/                 (templates ScreenGui)
│       ├── Effects/            (particules répliquées)
│       └── Sounds/             (sons partagés)
│
├── StarterGui/
│   ├── HUD/                    (ScreenGui principal en jeu)
│   ├── LobbyUI/                (menus lobby)
│   ├── MatchEndUI/             (écran fin de match)
│   └── Notifications/          (toasts, alerts)
│
├── StarterPlayerScripts/
│   ├── Init.client.lua
│   ├── InputController.client.lua
│   ├── UIController.client.lua
│   ├── EffectsController.client.lua
│   └── LobbyController.client.lua
│
├── StarterCharacterScripts/
│   └── CharacterSetup.lua      (config personnage : hitbox, vitesse)
│
└── SoundService/
    ├── Music/                  (pistes musicales)
    └── SFX/                    (effets sonores)
```

---

## Schéma DataStore

### Structure de sauvegarde par joueur

```lua
PlayerData = {
    -- Méta
    version = 1,
    firstJoin = timestamp,
    lastJoin = timestamp,
    totalPlayTime = number,     -- secondes

    -- Progression
    level = 1,                  -- 1 à 100
    xp = 0,

    -- Économie
    gold = 0,                   -- Or in-game

    -- Stats (pour classements + profil)
    stats = {
        totalMatches = 0,
        totalWins = 0,
        totalKills = 0,
        totalLiberations = 0,
        totalCatches = 0,
        mvpCount = 0,
        seasonXP = 0,           -- reset chaque saison
        weeklyKills = 0,        -- reset chaque lundi
    },

    -- Cosmétiques possédés
    cosmetics = {
        balls    = { ["ball_default"] = true },
        trails   = {},
        auras    = {},
        titles   = { ["title_player"] = true },
        animations = { ["anim_default"] = true },
        emotes   = { ["emote_celebrate"] = true },
    },

    -- Cosmétiques équipés
    equipped = {
        ball      = "ball_default",
        trail     = nil,
        aura      = nil,
        title     = "title_player",
        animation = "anim_default",
        emote     = "emote_celebrate",
    },

    -- Missions quotidiennes
    missions = {
        lastReset = 0,          -- timestamp dernier reset
        daily = {
            -- [missionId] = { progress = n, completed = bool, claimed = bool }
        },
    },

    -- Login bonus
    loginBonus = {
        lastClaim = 0,          -- timestamp dernière connexion
        streak = 0,             -- jours consécutifs (1-7)
    },

    -- Achats
    purchases = {
        gamePasses = {
            starterPack = false,
            doubleGold  = false,
            vipPack     = false,
        },
    },

    -- Onboarding
    onboarding = {
        welcomePackClaimed = false,
        tooltipsSeen = {},
    },

    -- Paramètres
    settings = {
        musicVolume   = 0.5,
        sfxVolume     = 0.8,
        ambianceVolume = 0.3,
        tipsEnabled   = true,
    },
}
```

### Stratégie de sauvegarde

| | Détail |
|---|--------|
| **Auto-save** | Toutes les 5 minutes (RunService) |
| **Save on leave** | PlayerRemoving + BindToClose |
| **Retry** | 3 tentatives avec backoff exponentiel (1s, 2s, 4s) |
| **Version schéma** | `version = 1` — migration propre si structure change |
| **Classements** | OrderedDataStore séparé pour kills hebdo + XP saison |

---

## Map des RemoteEvents

### Client → Serveur

| Event | Payload | Validation serveur |
|-------|---------|-------------------|
| `RequestThrow` | `{ direction: Vector3 }` | Joueur a bien une balle, pas de cooldown, position cohérente |
| `RequestCatch` | `{}` | Balle bien en approche, fenêtre de 0,5s valide, pas déjà une balle en main |
| `RequestEquipCosmetic` | `{ category: string, itemId: string }` | Joueur possède l'item, catégorie valide |
| `RequestBuyItem` | `{ itemId: string, currency: string }` | Fonds suffisants, item disponible en boutique |
| `RequestClaimMission` | `{ missionId: string }` | Mission complète, pas déjà réclamée |
| `RequestEmote` | `{ emoteId: string }` | Joueur possède l'emote, en lobby ou fin de match |
| `RequestJoinQueue` | `{}` | Joueur en lobby, pas déjà en file |
| `RequestLeaveQueue` | `{}` | Joueur en file |

### Serveur → Client

| Event | Payload | Usage |
|-------|---------|-------|
| `UpdateHUD` | `{ teamA, teamB, timer, hasBall }` | Mise à jour HUD complet |
| `BallThrown` | `{ origin: Vector3, direction: Vector3, throwerId }` | Afficher trajectoire côté client |
| `BallCaught` | `{ catcherId, position }` | Effet catch + son |
| `PlayerEliminated` | `{ playerId, byPlayerId }` | Animation élimination + son |
| `PlayerLiberated` | `{ playerId }` | Animation libération + notification |
| `ZoneShrinkWarning` | `{ newRadius, delay }` | Alerte 5s avant rétrécissement |
| `ZoneShrink` | `{ newRadius }` | Déclencher animation marée |
| `BonusBallSpawned` | `{ position: Vector3, team }` | Afficher balle bonus |
| `MatchStart` | `{ teamA[], teamB[], mapName }` | Démarrer le match côté client |
| `MatchEnd` | `{ winner, stats[], xpGained, goldGained }` | Afficher écran résultats |
| `UpdateProgression` | `{ xp, level, leveledUp, newLevel }` | Mise à jour barre XP + animation level up |
| `UpdateGold` | `{ gold, delta }` | Mise à jour compteur Or |
| `ShowNotification` | `{ text, type, duration }` | Toast notification |
| `PlayEffect` | `{ effectId, position, color }` | VFX client |
| `PlaySound` | `{ soundId, position }` | SFX client |
| `QueueUpdate` | `{ playersFound, total }` | Mise à jour barre file d'attente |

### RemoteFunctions

| Function | Request | Response |
|----------|---------|----------|
| `GetShopItems` | `{ tab: "fixed" \| "weekly" \| "daily" }` | `{ items[] }` |
| `GetLeaderboard` | `{ type: string }` | `{ entries[] }` |
| `GetPlayerProfile` | `{ playerId }` | `{ level, title, equipped }` |

---

## Systèmes techniques

| # | Système | Complexité | Dépendances | PRD source |
|---|---------|-----------|-------------|------------|
| 1 | **PlayerDataManager** | Haute | DataStoreService | Tous |
| 2 | **GameStateManager** | Moyenne | Players | PRD 01, 07 |
| 3 | **MatchManager** | Haute | GameState, tous systèmes match | PRD 01, 02 |
| 4 | **BallSystem** | Haute | Physics, RemoteEvents, PrisonSystem | PRD 02 |
| 5 | **PrisonSystem** | Moyenne | MatchManager, BallSystem | PRD 02 |
| 6 | **ZoneSystem** | Moyenne | MatchManager, TweenService | PRD 02, 03 |
| 7 | **BotController** | Haute | MatchManager, BallSystem | PRD 09 |
| 8 | **ProgressionSystem** | Basse | PlayerDataManager | PRD 04 |
| 9 | **ShopSystem** | Moyenne | PlayerDataManager, MarketplaceService | PRD 05, 12 |
| 10 | **MissionSystem** | Moyenne | PlayerDataManager, ProgressionSystem | PRD 04 |
| 11 | **LeaderboardSystem** | Basse | OrderedDataStore | PRD 07 |
| 12 | **InputController** (C) | Moyenne | RemoteEvents | PRD 02, 06 |
| 13 | **UIController** (C) | Haute | GUI, RemoteEvents | PRD 06 |
| 14 | **EffectsController** (C) | Moyenne | SoundService, Particles | PRD 10 |
| 15 | **LobbyController** (C) | Basse | UIController | PRD 03, 07 |

---

## Logique Match — State Machine

```
LOBBY
  │
  │ (assez de joueurs / timeout → bots ajoutés)
  ▼
COUNTDOWN (5 secondes)
  │
  ▼
MATCH_PLAYING
  │   ┌──────────────────────────┐
  │   │ BallSystem actif         │
  │   │ PrisonSystem actif       │
  │   │ ZoneSystem actif (shrink │
  │   │   à chaque 2 élim.)      │
  │   │ BotController actif      │
  │   └──────────────────────────┘
  │
  │ (1 équipe avec tous les membres en prison → vérif last chance)
  ▼
MATCH_END (10 secondes d'affichage résultats)
  │
  ▼
LOBBY (joueurs retournent au lobby)
```

---

## Sécurité & Anti-triche

| Menace | Protection |
|--------|-----------|
| **Tir depuis position invalide** | Vérifier distance joueur/balle côté serveur avant de valider |
| **Catch hack** (toujours attraper) | Valider fenêtre de timing 0,5s côté serveur avec timestamp |
| **Speed hack** | Vérifier déplacement entre deux ticks — téléporter si incohérent |
| **RemoteEvent spam** | Rate limit : max 5 `RequestThrow` par seconde par joueur |
| **Gold/XP hack** | Toutes les modifications de gold/XP uniquement côté serveur |
| **Achat sans fonds** | Vérifier solde avant toute transaction, opération atomique |
| **Faux items équipés** | Vérifier possession dans PlayerData avant d'appliquer |

### Règles de validation systématiques

1. Vérifier que le joueur est dans le bon état (en jeu, en lobby, en prison)
2. Vérifier que l'action respecte les cooldowns
3. Vérifier que les arguments sont du bon type et dans les plages valides
4. Ne jamais faire confiance à une position ou valeur venant du client

---

## Performance

| Métrique | Objectif | Alerte |
|----------|---------|--------|
| FPS mobile | > 30 FPS | < 20 FPS |
| FPS PC | > 60 FPS | < 30 FPS |
| Ping | < 150ms | > 400ms |
| Instances Workspace | < 3 000 (arène simple) | > 6 000 |
| RemoteEvents/sec par joueur | < 10 | > 30 |
| ParticleEmitters actifs | < 20 | > 40 |

### Optimisations clés

- **Balle** : objet unique réutilisé par Tween (pas de Create/Destroy à chaque tir)
- **Zone** : Tween sur un seul plan d'eau, pas de destruction de terrain
- **Bots** : IA tick toutes les 0,5s, pas à chaque frame
- **UI** : Batch updates HUD — une seule mise à jour par seconde max (pas au tick)
- **Sons** : Pool de 8 sons simultanés max

---

## Services Roblox utilisés

| Service | Usage |
|---------|-------|
| **DataStoreService** | Sauvegarde PlayerData |
| **OrderedDataStore** | Classements hebdo kills + XP saison |
| **MarketplaceService** | Game Passes + Developer Products |
| **Players** | Gestion connexions/déconnexions |
| **RunService** | Heartbeat pour auto-save + timers match |
| **TweenService** | Zone rétrécit, animations UI, marée montante |
| **CollectionService** | Tags pour PrisonZone, BallSpawn, BotSpawn |
| **SoundService** | Musique + SFX |
| **TextChatService** | Chat filtré |
| **BadgeService** | 8 badges achievements |
| **HttpService** | JSON encode/decode pour DataStore complexe |

---

## Questions clés validées

- [x] Chaque système des PRD est couvert ? → Oui : 15 systèmes couvrant les 13 PRDs
- [x] Séparation client/serveur claire ? → Oui : logique serveur, affichage client
- [x] DataStore couvre toutes les données ? → Oui : progression, cosmétiques, missions, achats
- [x] RemoteEvents sécurisés ? → Oui : validation serveur systématique + rate limiting
- [x] Budget performance réaliste ? → Oui : mobile-first, optimisations clés documentées

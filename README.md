# Brainrot Gallery — Roblox Game

Jeu Roblox synchronisé avec **Rojo**. Les joueurs collectent des brainrots via une machine de spin et les exposent dans leur base.

## Architecture

```
src/
├── ReplicatedStorage/          -- Données partagées client/serveur
│   ├── BrainrotModels/         -- Dossier unifié des modèles 3D (Brainrots.rbxm)
│   ├── BrainrotPack.rbxm       -- Pack supplémentaire de modèles
│   ├── base.rbxm               -- Prefab base joueur (apparaît comme "Base1" in-game)
│   ├── Constants.lua           -- Constantes globales (GOLD=10000, TICKETS, XP...)
│   ├── LootTables.lua          -- Tables de loot (non utilisé actuellement)
│   ├── BrainrotData.lua        -- Métadonnées des brainrots
│   └── LegoRenderer.lua        -- Rendu sol LEGO
│
├── ServerScriptService/        -- Scripts serveur
│   ├── ServerMain.server.lua   -- Point d'entrée : WalkSpeed, PlayerAdded/Removing, SaveData
│   ├── BrainrotModelsSetup.server.lua -- Fusionne Brainrots + BrainrotPack + "Brainrot pack1" → BrainrotModels
│   ├── BrainrotGallery.server.lua     -- Galerie : clone Base1, scan socles, placement figurines, hooks _G
│   ├── WheelSystem.server.lua         -- Machine de spin : charge TOUS les brainrots, tirage, socles machine, E/F
│   ├── LevelGenerator.server.lua      -- Monde : montagnes, lampadaires, sol LEGO vert, éclairage
│   └── DataManager.lua                -- DataStore "Brainrot_v3" : Gold, XP, Tickets, TotalPower, Inventory
│
└── StarterPlayer/              -- Scripts client
    └── StarterPlayerScripts/
```

## Systemes cles

### Machine de Spin (WheelSystem)
- Charge **tous** les modeles brainrot dynamiquement (pas de limite, pas de rarete)
- Sources : `Brainrots`, `BrainrotPack`, `Brainrot pack1`, `BrainrotModels`
- Mini-clones affiches sur les socles de la machine (taille 9 studs max)
- Auto-redressement : detecte si le modele est couche et le remet debout
- Touche **E** : porter le brainrot jusqu'a la base
- Touche **F** : teleporter le brainrot sur un socle vide de la base + TP joueur

### Galerie / Base (BrainrotGallery)
- Clone le prefab **"Base1"** (base.rbxm) depuis ReplicatedStorage pour chaque joueur
- **ATTENTION** : le fichier s'appelle `base.rbxm` mais in-game le Model s'appelle `Base1` (capital B, suffixe 1)
- `FindFirstChild` est **case-sensitive** : chercher "base1" ne trouve PAS "Base1"
- Scan dynamique des socles : mots-cles (PedestalTop, Pedestal, Stand, Podium, Display, Socle, Plate) + fallback parts plates
- 10 socles dans la base, chaque brainrot gagne prend le premier socle vide
- Figurines redressees automatiquement (rotation corrective si couchees)
- Taille figurines : 12.5 studs max (TARGET_SIZE)
- Hooks exposes via `_G` pour communication WheelSystem → Gallery :
  - `_G.BrainrotGallery_GetEmptyPedestalTops(player)` → socles vides
  - `_G.BrainrotGallery_ForcePlace(player, slotIndex, item)` → placement direct
  - `_G.BrainrotGallery_TeleportToPlot(character, userId, slotIndex)` → TP joueur

### Donnees joueur (DataManager)
- DataStore : `"Brainrot_v3"` (bump de v2 pour reset avec 10 000 Gold de depart)
- Sauvegarde : Gold, XP, Level, Tickets, TotalPower, Inventory, Collection
- TotalPower est **cumulatif** et persiste entre sessions
- Sauvegarde auto sur PlayerRemoving + BindToClose

### Monde (LevelGenerator)
- Sol LEGO vert : grille 12x8 tuiles (50x50 studs), `CanCollide=true`, `Position Y=0.5`
- Montagnes decoratives en arriere-plan
- Lampadaires avec PointLight
- Eclairage : ClockTime=14, Bloom faible, Atmosphere

## Rojo / Sync

- `default.project.json` : configuration Rojo
- `$ignoreUnknownInstances: true` preserve les objets Studio non geres par Rojo
- Les `.rbxm` dans les dossiers `$path` sont synchronises automatiquement
- **base.rbxm** et **BrainrotPack.rbxm** : fichiers `.rbxm` dans ReplicatedStorage

## Pieges connus

| Piege | Detail |
|-------|--------|
| Case sensitivity | `FindFirstChild("base1")` ≠ `FindFirstChild("Base1")` — toujours verifier le nom exact in-game |
| Brainrots couches | Beaucoup de modeles ont leur axe principal sur X ou Z — le code auto-redresse |
| Sol vert traversable | Les tuiles doivent avoir `CanCollide=true` et `Position.Y=0.5` (top=1 stud) |
| Luau syntax | `(expr).field = val` cause "Ambiguous syntax" — utiliser une variable intermediaire |
| DataStore reset | Changer `DATASTORE_NAME` pour forcer un reset des donnees (ex: v2→v3) |
| 0 socles | Si le prefab base n'est pas trouve → fallback folder vide → 0 pedestals → brainrots perdus |

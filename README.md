# Brainrot V5 — Roblox Game

## BASE ET SPIN PARFAITES — Point de reprise stable

> **Ce commit est le point de reference.** Si un bug de base ou de spin apparait plus tard,
> revenir ici avec `git log` pour retrouver l'etat qui marchait.

---

## Ce qui fonctionne

### Machine de Spin (WheelSystem)
- Charge **tous** les modeles brainrot dynamiquement depuis BrainrotModels
- Scan recursif : conteneurs (5+ enfants) sont ouverts, les Models individuels sont des brainrots
- Mini-clones sur les socles de la machine (9 studs max, auto-redresses)
- **E** = porter le brainrot
- **F** = envoyer le brainrot dans la base (le joueur reste a la machine)
- Fallback : si aucun brainrot trouve dans les sources, scan tout ReplicatedStorage

### Base joueur (BrainrotGallery)
- **base.rbxm** = prefab de la base (10 socles)
- Au demarrage : le script cherche le prefab partout (ReplicatedStorage, Workspace, ServerStorage)
- Si trouve dans Workspace → le clone dans ReplicatedStorage, puis supprime l'original
- **1 base clonee par joueur**, placee le long de l'avenue :
  - Plots impairs → cote nord (Z=195)
  - Plots pairs → cote sud (Z=25)
  - Espacement X = 130 studs
- Scan des socles : mots-cles (PedestalTop, Pedestal, Stand, Podium, Display, Socle, Plate)
- Fallback : petites parts plates (hauteur <= 3, surface 2x2 a 12x12)
- Figurines : 12.5 studs max, auto-redressees (rotation corrective si couchees)
- Plaques de recolte **vertes** a cote de chaque socle → accumulent du power
- Spawn joueur **devant la machine a spin** (X=30, Z=0)

### Donnees joueur (DataManager)
- DataStore `"Brainrot_v3"` — 10 000 Gold de depart
- Sauvegarde : Gold, XP, Level, Tickets, TotalPower, Inventory, Collection
- **Autosave toutes les 60s** + PlayerRemoving + BindToClose
- TotalPower cumulatif entre sessions

### Communication entre systemes (hooks _G)
- `_G.BrainrotGallery_GetEmptyPedestalTops(player)` → socles vides
- `_G.BrainrotGallery_ForcePlace(player, slotIndex, item)` → place brainrot + active recolte
- `_G.BrainrotGallery_TeleportToPlot(character, userId, slotIndex)` → TP joueur au socle
- `_G.BrainrotGallery_Refresh` → refresh galerie depuis inventaire

### Monde (LevelGenerator)
- Sol LEGO vert : 12x8 tuiles, CanCollide=true, Y=0.5
- Montagnes, lampadaires, eclairage (ClockTime=14)

---

## Architecture

```
src/
├── ReplicatedStorage/
│   ├── BrainrotModels/         -- Dossier unifie (Brainrots.rbxm)
│   ├── BrainrotPack.rbxm       -- Pack supplementaire
│   ├── base.rbxm               -- PREFAB BASE JOUEUR (10 socles)
│   ├── Constants.lua           -- GOLD=10000, TICKETS, XP
│   ├── BrainrotData.lua        -- Metadonnees brainrots
│   └── LegoRenderer.lua        -- Rendu sol LEGO
│
├── ServerScriptService/
│   ├── ServerMain.server.lua           -- Entry point, WalkSpeed=32, autosave 60s
│   ├── BrainrotModelsSetup.server.lua  -- Fusionne tous les packs → BrainrotModels
│   ├── BrainrotGallery.server.lua      -- Clone base, socles, figurines, recolte, hooks
│   ├── WheelSystem.server.lua          -- Machine spin, tirage, E/F prompts
│   ├── LevelGenerator.server.lua       -- Montagnes, lampadaires, sol LEGO, eclairage
│   ├── EconomyManager.server.lua       -- Leaderstats, revenu passif
│   ├── DataManager.lua                 -- DataStore v3, CRUD inventaire/gold/power
│   └── Communication.server.lua        -- RemoteEvents vente, donnees client
│
└── StarterPlayer/StarterPlayerScripts/
```

## Rojo — Regles

1. **NE JAMAIS modifier les scripts dans Studio** — Rojo ecrase avec la version disque
2. **base.rbxm et BrainrotPack.rbxm** declares explicitement dans `default.project.json`
3. `$ignoreUnknownInstances: true` partout → objets Studio preserves
4. **Autosave 60s** protege contre les crash/deconnexions

## Pieges connus

| Piege | Solution |
|-------|----------|
| base.rbxm pas dans ReplicatedStorage | Le script cherche partout (Workspace, ServerStorage) et la recupere |
| FindFirstChild case-sensitive | "Base1" ≠ "base1" — le script essaie tous les noms |
| Brainrots couches | Auto-redressement par detection d'axe |
| 0 socles detectes | Fallback sur petites parts plates dans le prefab |
| Conteneur vs brainrot | Model avec 5+ enfants = conteneur, pas un brainrot |
| DataStore reset | Changer DATASTORE_NAME (ex: v3 → v4) |

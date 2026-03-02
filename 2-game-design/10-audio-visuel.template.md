# PRD 10 — Audio & Visuel

> Le style graphique, les sons, la musique, les effets visuels.

---

## Direction artistique

| | Choix |
|---|-------|
| **Style 3D** | [Low-poly / Réaliste / Cartoon / Anime / Roblox classique / Voxel] |
| **Palette de couleurs** | [Vives / Pastels / Sombres / Néon / Naturelles] |
| **Éclairage** | [Lumineux / Atmosphérique / Sombre / Dynamique] |
| **Inspiration visuelle** | [Jeux/films/animes de référence] |
| **Technologie Roblox** | [Future Lighting / ShadowMap / Voxel / Compatibility] |

### Mood board (références visuelles)

> Lister 3-5 images/jeux de référence pour l'ambiance visuelle

1. [Référence 1] — pour : [couleurs / architecture / ambiance]
2. [Référence 2] — pour : [style personnages / nature]
3. [Référence 3] — pour : [UI / effets]

---

## Effets visuels (VFX)

| Effet | Quand | Style | Implémentation |
|-------|-------|-------|----------------|
| Particules d'attaque | Chaque coup | [Étincelles, slash] | ParticleEmitter |
| Level up | Gain de niveau | [Colonne de lumière] | Beam + Particles |
| Obtention item rare | Drop rare | [Aura dorée] | Particles + Sound |
| Dégâts reçus | Joueur touché | [Flash rouge écran] | GUI overlay |
| Mort | HP = 0 | [Désintégration / fade] | Tween + Particles |
| Heal | Potion / Regen | [Particules vertes] | ParticleEmitter |
| | | | |

---

## Animations

| Animation | Sur quoi | Détail |
|-----------|----------|--------|
| Idle | Personnage | [Respire, regarde autour] |
| Marche | Personnage | [Standard / Style custom] |
| Course | Personnage | [Plus rapide, bras en arrière ?] |
| Attaque | Personnage | [Selon type d'arme] |
| Saut | Personnage | [Standard / Double jump ?] |
| Mort | Personnage | [Ragdoll / Animation fixe] |
| Emotes | Personnage | [Liste des emotes custom] |
| [Autre] | | |

**Source des animations :** [Roblox par défaut / Custom (Moon Animator) / Mixamo]

---

## Musique

### Pistes musicales

| Piste | Contexte | Ambiance | Durée | Loop ? |
|-------|----------|----------|-------|--------|
| Menu principal | Lobby/Menu | [Épique, calme, mystérieux] | [~2min] | Oui |
| Zone 1 | [Zone débutant] | [Aventureux, léger] | [~3min] | Oui |
| Zone boss | [Arène de boss] | [Intense, percussions] | [~2min] | Oui |
| Combat | [Pendant les combats] | [Rapide, tension] | [~2min] | Oui |
| Victoire | [Boss vaincu] | [Triomphant, bref] | [~15s] | Non |
| [Autre] | | | | |

**Source :** [Roblox library / Compositions originales / Licences Creative Commons]
**Transitions :** [Fondu enchaîné / Coupure / Crossfade de X secondes]

---

## Effets sonores (SFX)

| Son | Quand | Style |
|-----|-------|-------|
| Coup d'épée | Attaque mêlée | [Swoosh métallique] |
| Impact | Toucher un ennemi | [Thud / crunch selon rareté] |
| Ramassage item | Pick up | [Ding léger, plus fort si rare] |
| Ouverture menu | UI ouverte | [Click doux] |
| Level up | Gain de niveau | [Fanfare courte] |
| Mort joueur | HP = 0 | [Son grave, souffle] |
| Pas | Marche | [Selon surface : herbe, pierre, bois] |
| Ambiance | Fond sonore par zone | [Oiseaux, vent, lave...] |
| | | |

**Volume relatif :** SFX > Musique > Ambiance (réglable par le joueur)

---

## Éclairage

| Zone | Type d'éclairage | Couleur dominante | Atmosphère |
|------|-----------------|-------------------|------------|
| Lobby | Lumineux, chaud | Doré | Accueillant |
| Forêt | Filtré, vert | Vert/Doré | Naturel |
| Grotte | Sombre, ponctuel | Bleu/Violet | Mystérieux |
| Volcan | Chaud, rouge | Rouge/Orange | Dangereux |
| [Zone] | | | |

**Cycle jour/nuit :** [Durée — ex: 20 minutes. Impact sur éclairage ?]

---

## Skybox & Terrain

| | Détail |
|---|--------|
| **Skybox** | [Custom / Roblox default — style ?] |
| **Terrain** | [Smooth terrain / Parts / Mesh / Mixte] |
| **Eau** | [Terrain water / Custom — transparence, couleur] |
| **Brouillard** | [Distance, couleur, densité par zone] |

---

## Performance & Optimisation

| Contrainte | Limite recommandée |
|-----------|-------------------|
| Polycount par zone | [< 100K triangles visibles] |
| Nombre de Parts | [< 10K par zone chargée] |
| Textures | [256x256 ou 512x512 max] |
| Particules simultanées | [< 500 total] |
| Lumières dynamiques | [< 20 par zone] |
| Sons simultanés | [< 10] |

---

## Questions clés

- [ ] Le style visuel est-il cohérent dans TOUTES les zones ?
- [ ] La musique correspond-elle à l'ambiance de chaque zone ?
- [ ] Les effets sonores donnent-ils un feedback satisfaisant ?
- [ ] Le jeu tourne bien sur les machines/appareils bas de gamme ?
- [ ] Les VFX sont-ils lisibles (on comprend ce qui se passe) ?

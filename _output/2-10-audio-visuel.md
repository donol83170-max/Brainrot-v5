# PRD 10 — Audio & Visuel — Dodgeball Royale

> Date : 2026-02-22
> Statut : VALIDÉ ✅

---

## Direction artistique

| | Choix |
|---|-------|
| **Style 3D** | Cartoon coloré — Roblox enrichi (formes rondes, couleurs saturées) |
| **Palette de couleurs** | Vives et saturées — bleu ciel, sable doré, orange coral, rouge/bleu équipes |
| **Éclairage** | Lumineux, chaud — soleil de plage permanent, pas de cycle jour/nuit |
| **Inspiration visuelle** | Fall Guys (cartoon PvP coloré), Stumble Guys (ambiance festive), Roblox BedWars |
| **Technologie Roblox** | Future Lighting — meilleure qualité visuelle, ombres douces |

### Mood board (références visuelles)

1. **Fall Guys** — pour : les couleurs saturées, le style cartoon festif, les effets d'élimination comiques
2. **Roblox BedWars** — pour : la lisibilité du HUD, les couleurs d'équipes franches
3. **Beach Buggy Racing** — pour : l'ambiance tropicale cartoon, le ciel chaud
4. **Splatoon** — pour : les effets visuels d'impacts colorés et lisibles

---

## Effets visuels (VFX)

| Effet | Quand | Style | Implémentation Roblox |
|-------|-------|-------|-----------------------|
| **Impact balle** | Balle touche un joueur | Flash rouge vif + splash cartoon | GUI overlay + ParticleEmitter |
| **Élimination** | Joueur éliminé | Tourbillon cartoon + "POP!" + téléportation | Tween + Particles + BillboardGui |
| **Catch réussi** | Joueur attrape une balle | Flash vert + étoiles | ParticleEmitter + GUI |
| **Libération** | Retour de prison | Explosion de confettis aux couleurs de l'équipe + flash blanc | Beam + Particles |
| **Level up** | Montée de niveau | Colonne de lumière dorée + confettis | Beam + ParticleEmitter |
| **Zone rétrécit** | Alerte pré-rétrécissement | Bords de l'écran qui flashent bleu + vague visuelle | GUI overlay + Tween |
| **Marée montante** | Zone qui avance | Eau bleue cartoon qui avance progressivement | Tween sur le plan d'eau |
| **Balle bonus** | Apparition à 1 min | Balle qui tombe du ciel avec traînée lumineuse | Tween + ParticleEmitter |
| **Prompt ATTRAPE** | Balle en approche | Texte gros et gras qui pulse | BillboardGui animé |
| **Victoire** | Équipe gagnante | Feux d'artifice + texte "VICTOIRE !" animé | Particles + GUI |

---

## Animations

| Animation | Sur quoi | Style | Source |
|-----------|----------|-------|--------|
| **Idle** | Personnage | Légère respiration, regard qui bouge | Roblox default modifié |
| **Marche** | Personnage | Standard Roblox, légèrement cartoon | Roblox default |
| **Lancer** | Personnage | Bras qui balance, élan vers l'avant | Custom (Moon Animator) |
| **Catch** | Personnage | Deux mains qui saisissent devant soi | Custom (Moon Animator) |
| **Élimination** | Personnage | Saut comique + atterrissage en prison | Custom (Moon Animator) |
| **Libération** | Personnage | Saut victorieux au retour sur terrain | Custom (Moon Animator) |
| **Emotes** | Personnage | Célébration, danse, pose | Custom (Moon Animator) |
| **Marée montante** | Terrain | Plan d'eau qui avance en douceur | Tween Service |
| **Bots idle** | Bots | Légère oscillation pour paraître vivants | Roblox default |

---

## Musique

### Pistes musicales

| Piste | Contexte | Ambiance | BPM | Loop ? |
|-------|----------|----------|-----|--------|
| **🏖️ Lobby Theme** | Lobby commun | Pop tropicale chill — festive, détendue | 110-120 | Oui |
| **⚡ Match Theme** | En jeu (phases 1-2) | Electro-pop énergique — montée d'adrénaline | 140-150 | Oui |
| **🔥 Final Theme** | Dernière minute | Version accélérée du Match Theme — tension max | 160+ | Oui |
| **🏆 Victoire** | Écran victoire | Fanfare courte, triomphante, cartoon | — | Non |
| **😢 Défaite** | Écran défaite | Jingle court, taquin, pas frustrant | — | Non |
| **⏳ File d'attente** | Matchmaking | Version allégée du Lobby Theme | 110 | Oui |

**Source :** Roblox Audio Library (gratuit) — sélection de pistes libres de droits
**Transitions :** Crossfade de 2 secondes entre Lobby → Match, coupure nette pour Victoire/Défaite

---

## Effets Sonores (SFX)

| Son | Quand | Style recherché |
|-----|-------|----------------|
| **Lancer balle** | Joueur lance | Whoosh rapide et puissant |
| **Impact sur joueur** | Balle touche | Clap/slap cartoon satisfaisant — "SMACK !" |
| **Catch réussi** | Balle attrapée | Clap sonore net — "CLAP !" |
| **Balle au sol** | Balle tombe | Rebond élastique léger |
| **Élimination** | Joueur éliminé | Son cartoon comique — "POP !" ou "BOING !" |
| **Libération** | Retour de prison | Fanfare mini 1 seconde — joyeuse |
| **Zone alerte** | 5s avant rétrécissement | Son de vague + klaxon court |
| **Marée avance** | Zone rétrécit | Son de vague continue (3s) |
| **Level up** | Montée de niveau | Fanfare ascendante courte (1,5s) |
| **Balle bonus** | Apparition | Son distinctif "DING DING !" |
| **Boutons UI** | Clic menu | Click léger et doux |
| **Login bonus** | Connexion journalière | Pluie de pièces (tintement) |
| **Victoire** | Fin de match gagnée | Fanfare joyeuse (3s) |
| **Défaite** | Fin de match perdue | Jingle court taquin (2s) |
| **Ambiance lobby** | Fond lobby | Sons de plage — vagues douces, cris de mouettes |
| **Ambiance match** | Fond match | Foule légère en fond, sons d'ambiance sportive |

**Volume relatif :** SFX > Musique > Ambiance (tous réglables séparément dans les paramètres)

---

## Éclairage

| Zone | Type | Couleur dominante | Atmosphère |
|------|------|-------------------|------------|
| **Lobby (boardwalk)** | Chaud, direct | Doré/Orange | Coucher de soleil, accueillant |
| **Arène Sunset Beach** | Brillant, solaire | Jaune/Blanc | Plage en plein soleil |
| **Zone prison** | Légèrement teinté | Couleur de l'équipe adverse | Distinct du terrain principal |
| **Dernière minute** | Intensité augmentée | Plus vif, plus contrasté | Tension visuelle |

- **Pas de cycle jour/nuit** — l'arène est toujours en plein soleil (cohérence entre les matchs)
- **Future Lighting** activé pour ombres douces et reflets sur le sable

---

## Skybox & Terrain

| | Détail |
|---|--------|
| **Skybox** | Ciel bleu tropical avec quelques nuages cartoon — custom ou Roblox library |
| **Terrain arène** | Parts/Meshes — sol en sable, obstacles en solide coloré |
| **Eau (marée)** | Plan coloré bleu tropical qui avance via Tween — pas de Terrain Water (performance) |
| **Brouillard** | Aucun — visibilité maximale sur toute l'arène |

---

## Performance & Optimisation

| Contrainte | Limite cible |
|-----------|-------------|
| Parts visibles par arène | < 5 000 (arène simple) |
| Triangles visibles | < 50 000 (format mobile-first) |
| Textures | 256×256 max pour les éléments répétés |
| ParticleEmitters actifs simultanément | < 20 |
| Sons simultanés | < 8 |
| Lumières dynamiques | < 10 |

> **Mobile-first** : Roblox est joué à ~60% sur mobile — optimiser en priorité pour mobile, enrichir ensuite pour PC.

---

## Questions clés validées

- [x] Style visuel cohérent dans toutes les zones ? → Oui : même palette cartoon tropical partout
- [x] Musique adaptée à chaque moment ? → Oui : chill lobby, intense match, accéléré finale
- [x] SFX donnent un feedback satisfaisant ? → Oui : chaque action clé a son son distinctif
- [x] Le jeu tourne sur mobile bas de gamme ? → Oui : mobile-first, limites strictes de parts/particules
- [x] Les VFX sont-ils lisibles ? → Oui : chaque effet a une couleur et un style distinct

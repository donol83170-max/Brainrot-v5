# PRD 03 — Monde & Map — Dodgeball Royale

> Date : 2026-02-22
> Statut : VALIDÉ ✅

---

## Vue d'ensemble

| | Détail |
|---|--------|
| **Type de monde** | Lobby commun + Instances d'arène (une par match) |
| **Taille estimée** | Petite — arène de combat resserrée, lobby compact |
| **Nombre de zones** | 2 : Lobby + Arène (MVP — 1 map) |
| **Style général** | Plage tropicale cartoon — sable doré, couleurs vives, ambiance estivale festive |

---

## Structure du monde

```
┌─────────────────────────────────┐
│         LOBBY COMMUN            │  ← Tous les joueurs se retrouvent ici
│   (plage/boardwalk cartoon)     │
└────────────┬────────────────────┘
             │ Clic "Jouer" → file d'attente
             ▼
┌─────────────────────────────────┐
│     INSTANCE D'ARÈNE (match)    │  ← Une instance = un match = 3-5 min
│  [Prison B] [Terrain] [Prison A]│
└─────────────────────────────────┘
             │ Fin de match
             ▼
      Retour au Lobby
```

---

## Zone 1 : Lobby Commun

| | Détail |
|---|--------|
| **Thème** | Promenade de plage cartoon (boardwalk) |
| **Ambiance** | Lumineux, festif, coloré — les joueurs se baladent en attendant |
| **Taille** | Petite — suffisante pour voir et croiser les autres joueurs |
| **Accès** | Libre dès la connexion |
| **Fonction gameplay** | Vitrine des cosmétiques, accès au matchmaking, social |

**Contenu du lobby :**
- Planche de bois sur la plage (boardwalk) avec stands décoratifs
- Joueurs visibles avec leurs cosmétiques (skins de balle, effets personnage)
- Bouton / zone "JOUER" pour lancer la recherche de match
- Accès aux menus : boutique, inventaire, classement, stats
- Déco : palmiers, parasols, transats, stands de plage — tout cartoon

**Schéma du lobby :**
```
🌴  🌴  🌴  🌴  🌴  🌴  🌴  🌴  🌴  🌴
🏖️ ═══════════════════════════════════════ 🏖️
   [Stats]  [JOUER 🎯]  [Boutique]  [Classement]
   ↑                                    ↑
   Panneaux / PNJ décoratifs         Panneaux
🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
```

---

## Zone 2 : Arène — "Sunset Beach" (map MVP)

| | Détail |
|---|--------|
| **Thème** | Plage tropicale cartoon au coucher de soleil |
| **Ambiance** | Vive, compétitive, festive — terrain de sport sur sable |
| **Taille** | Moyenne — assez grand pour 4v4 au départ, se resserre avec la zone |
| **Accès** | Via matchmaking uniquement (pas d'accès direct) |
| **Fonction gameplay** | Toute l'action du match se déroule ici |

### Schéma de l'arène

```
☀️                                                    ☀️
🌴 🌴 🌴 🌴 🌴 🌴 🌴 🌴 🌴 🌴 🌴 🌴 🌴 🌴 🌴 🌴

  ╔══════════════════════════════════════════════════╗
  ║  🏖️ ZONE PRISON ÉQUIPE B 🏖️  (drapeaux bleus)   ║
  ╠══════════════════════════════════════════════════╣
  ║                                                  ║
  ║   [🧊 Glacière B]                               ║
  ║        (couverte bleue)      🏰                 ║
  ║                         Château de sable        ║
  ║                          (structure centrale)   ║
  ║                                  [🧊 Glacière A]║
  ║                                  (couverte rouge)║
  ║                                                  ║
  ╠══════════════════════════════════════════════════╣
  ║  🏖️ ZONE PRISON ÉQUIPE A 🏖️  (drapeaux rouges)  ║
  ╚══════════════════════════════════════════════════╝

🌴 🌴 🌴 🌴 🌴 🌴 🌴 🌴 🌴 🌴 🌴 🌴 🌴 🌴 🌴 🌴
🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊
```

### Éléments du terrain

| Élément | Description | Rôle gameplay |
|---------|-------------|---------------|
| **Sol** | Sable doré cartoon avec reflets | Purement visuel |
| **Glacière Équipe A** | Glacière rouge cartoon, hauteur ~mi-torse | Couverture côté A — abri au départ |
| **Glacière Équipe B** | Glacière bleue cartoon, même taille | Couverture côté B — abri au départ |
| **Château de sable** | Structure centrale à 2 niveaux bas, cartoon | Point stratégique central — les deux équipes se battent pour la position |
| **Palmiers** | Rangée de palmiers tout autour du terrain | Purement décoratif — hors terrain, pas d'interaction |
| **Parasols & transats** | Bordure extérieure | Purement décoratifs |
| **Drapeaux de plage** | Couleurs d'équipe plantés en zone prison | Identification visuelle des zones |

### Zone Prison

| | Détail |
|---|--------|
| **Position** | Derrière la ligne de fond de l'équipe adverse |
| **Taille** | Suffisante pour accueillir les 4 prisonniers max avec espace de mouvement |
| **Séparation visuelle** | Ligne de sable plus sombre + drapeaux de plage aux couleurs de l'équipe |
| **Affectée par la zone** | Non — la zone prison reste constante tout le match |
| **Accès** | Téléportation automatique à l'élimination uniquement |

### Zone Dynamique — La Marée qui Monte 🌊

| Palier | Éliminations | Taille terrain | Visuel |
|--------|-------------|----------------|--------|
| Début | 0 | 100% | Sable sec, bordure calme |
| Phase 2 | 2 élim. | 75% | Vague 1 avance — bande de sable mouillé |
| Phase 3 | 4 élim. | 50% | Vague 2 avance — les parasols sont dans l'eau |
| Finale | 6 élim. | 30% | Vague 3 — presque tout sous l'eau, île restante |
| Balle bonus | 1 min restante | — | Balles bonus apparaissent sur le sable sec restant |

- La marée monte visuellement depuis les 4 côtés vers le centre
- **Alerte 5 secondes avant** chaque vague : son de vague + flash bleu sur les bords
- Joueur pris par la vague : **3 secondes pour rentrer** sinon élimination automatique

---

## Spawn

| Situation | Spawn |
|-----------|-------|
| Début de match | Côté de son équipe (moitié de terrain), positions aléatoires dans la moitié |
| Après élimination | Zone prison de l'équipe adverse — position aléatoire dans la zone |
| Après libération | Milieu du terrain côté équipe — dans la zone active |
| Connexion | Lobby commun |

---

## Navigation

| Moyen | Disponible | Vitesse | Condition |
|-------|-----------|---------|-----------|
| Marche | Partout | Base | — |
| Saut | Partout | — | Passer par-dessus les obstacles bas |
| Téléportation prison | Automatique | Instant | Être éliminé |
| Téléportation libération | Automatique | Instant | Toucher un adversaire depuis la prison |
| Téléportation arène→lobby | Automatique | Instant | Fin de match |

---

## Maps post-MVP (Version Complète)

| Map | Thème | Twist gameplay |
|-----|-------|----------------|
| **Sunset Beach** *(MVP)* | Plage tropicale cartoon | Marée montante |
| **Snow Dome** | Igloo / blizzard cartoon | Glace au sol (glissement) |
| **Neon City** | Ville futuriste néon | Zone néon qui crépite |
| **Jungle Temple** | Temple antique cartoon | Lianes comme obstacles |

---

## Questions clés validées

- [x] Le joueur sait toujours où il est ? → Oui : couleurs d'équipe, drapeaux, HUD mini-map
- [x] Chaque zone a une raison d'exister ? → Lobby = social/cosmétiques, Arène = gameplay
- [x] La navigation est fluide ? → Oui : tout est automatique ou par bouton simple
- [x] La map est assez intéressante sans être complexe ? → Oui : 2 glacières + château de sable = simple et lisible
- [x] La zone dynamique est lisible ? → Oui : marée montante = visuel intuitif et cohérent avec le thème

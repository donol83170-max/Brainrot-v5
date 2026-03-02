# PRD 03 — Monde & Map

> Tout ce qui concerne l'espace de jeu : zones, navigation, environnement.

---

## Vue d'ensemble

**Type de monde :** [Ouvert / Semi-ouvert / Linéaire / Lobby+Instances / Arène]
**Taille estimée :** [Petite / Moyenne / Grande]
**Nombre de zones :** [X zones]
**Style général :** [Décris l'ambiance visuelle du monde]

---

## Carte des zones

> Dessine un schéma simple de comment les zones sont connectées

```
[Zone de départ / Lobby]
        │
   ┌────┼────┐
   ▼    ▼    ▼
[Zone A] [Zone B] [Zone C]
   │         │
   ▼         ▼
[Zone D]  [Zone E]
              │
              ▼
        [Zone Boss]
```

---

## Détail par zone

> Copier ce bloc pour CHAQUE zone

### Zone : [NOM]

| | Détail |
|---|--------|
| **Thème** | [Ex: Forêt enchantée, Ville abandonnée, Volcan] |
| **Ambiance** | [Lumineux/Sombre, Calme/Dangereux, Ouvert/Claustro] |
| **Taille** | [Petite / Moyenne / Grande] |
| **Accès** | [Libre / Niveau requis / Quête / Game Pass] |
| **Fonction gameplay** | [Pourquoi le joueur vient ici] |

**Contenu de la zone :**
- Ennemis/PNJ présents : [liste]
- Ressources disponibles : [liste]
- Points d'intérêt : [liste]
- Secrets/Easter eggs : [liste]

**Connexions :**
- Entrée depuis : [zone(s)]
- Sortie vers : [zone(s)]
- Téléportation depuis/vers : [oui/non, conditions]

---

## Navigation

| Moyen de transport | Disponible depuis | Vitesse | Condition |
|-------------------|-------------------|---------|-----------|
| Marche | Partout | Base | — |
| Sprint | Partout | x1.5 | [Stamina ?] |
| [Véhicule/Monture] | [Zone] | [Vitesse] | [Condition] |
| Téléportation | [Où] | Instant | [Condition] |

---

## Points d'intérêt (POI)

| POI | Zone | Type | Ce qu'on y trouve |
|-----|------|------|-------------------|
| [Nom] | [Zone] | [Shop / Quête / Boss / Craft / Social] | [Description] |
| | | | |

---

## Spawn & Respawn

- **Spawn initial :** [Où apparaît un nouveau joueur ?]
- **Respawn après mort :** [Où ? Pénalité ?]
- **Respawn ennemis :** [Timer ? Conditions ?]
- **Sauvegarde position :** [Oui/Non ? Checkpoints ?]

---

## Environnement dynamique

| Élément | Comportement | Impact gameplay |
|---------|-------------|-----------------|
| Cycle jour/nuit | [Durée, effet visuel] | [Ennemis plus forts la nuit ?] |
| Météo | [Types, fréquence] | [Effets sur le gameplay ?] |
| Événements monde | [Quoi, quand] | [Boss spawn, ressources rares ?] |
| Éléments destructibles | [Quoi] | [Ressources, passages secrets ?] |

---

## Questions clés

- [ ] Le joueur sait toujours où il est et où aller ?
- [ ] Chaque zone a une raison gameplay d'exister ?
- [ ] La navigation est fluide (pas de murs invisibles frustrants) ?
- [ ] Le monde est assez grand pour être intéressant mais pas trop pour être vide ?
- [ ] Les zones hautes level sont visibles mais clairement "pas encore pour toi" ?

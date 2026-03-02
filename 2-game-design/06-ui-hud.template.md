# PRD 06 — UI & HUD

> Chaque écran, chaque menu, chaque bouton du jeu.

---

## HUD principal (en jeu)

> Ce que le joueur voit en permanence pendant qu'il joue

```
┌──────────────────────────────────────────────────────┐
│ [Vie/HP]              [Nom du joueur]    [Monnaie] $ │
│ [Barre XP]                              [Gems]    ◆ │
│                                                      │
│                                                      │
│                  ZONE DE JEU                         │
│                                                      │
│                                                      │
│                                                      │
│ [Minimap?]                                           │
│                          [Boutons action]  [Inv] [⚙] │
└──────────────────────────────────────────────────────┘
```

### Éléments du HUD

| Élément | Position | Toujours visible ? | Info affichée |
|---------|----------|-------------------|---------------|
| Barre de vie | Haut-gauche | Oui | HP actuel / HP max |
| Barre XP | Sous la vie | Oui | XP actuel, % progression |
| Monnaie(s) | Haut-droite | Oui | Montant de chaque monnaie |
| Minimap | Bas-gauche | [Oui/Non/Toggle] | Position, POI proches |
| Boutons action | Bas-droite | Oui | Skills/Actions rapides |
| | | | |

---

## Écrans & Menus

> Lister TOUS les écrans du jeu

### Arborescence des menus

```
Écran titre / Lobby
├── Jouer
├── Inventaire
│   ├── Équipement
│   ├── Items
│   └── Cosmétiques
├── Boutique
│   ├── Items (Coins)
│   ├── Items (Gems)
│   └── Robux (Game Passes)
├── Quêtes
│   ├── Principales
│   ├── Secondaires
│   └── Quotidiennes
├── Classement
├── Paramètres
│   ├── Audio
│   ├── Graphiques
│   └── Contrôles
└── Social
    ├── Amis
    ├── Équipe
    └── Trade
```

---

## Détail par écran

> Copier ce bloc pour chaque écran important

### Écran : [NOM]

**Accès :** [Comment on y arrive — bouton, touche, PNJ]
**Fermeture :** [Bouton X, touche Échap, clic dehors]
**Le jeu est en pause ?** [Oui / Non (Roblox = généralement non)]

**Layout :**
```
┌─────────────────────────────┐
│ [Titre]              [X]    │
│─────────────────────────────│
│                             │
│  [Contenu principal]        │
│                             │
│─────────────────────────────│
│ [Bouton action]  [Bouton 2] │
└─────────────────────────────┘
```

**Éléments interactifs :**
| Élément | Type | Action au clic |
|---------|------|----------------|
| [Nom] | Bouton / Toggle / Slider / Liste | [Ce qui se passe] |

---

## Notifications & Popups

| Notification | Quand | Durée | Position | Style |
|-------------|-------|-------|----------|-------|
| Level up | Gain de niveau | 3s | Centre | Doré, animation |
| Nouvel item | Obtention d'item | 2s | Droite | Toast notification |
| Quête complétée | Fin de quête | 3s | Centre | Animation + son |
| Mort | HP = 0 | Jusqu'à respawn | Centre | Écran sombre |
| | | | | |

---

## Responsive (Mobile vs PC)

| Élément | PC | Mobile | Différence |
|---------|-----|--------|------------|
| HUD | [Layout PC] | [Layout mobile] | [Boutons plus gros ?] |
| Menus | [Largeur] | [Plein écran ?] | [Scroll vs pages ?] |
| Boutons | [Hover possible] | [Touch — pas de hover] | [Taille min 44px] |
| Chat | [Coin bas-gauche] | [Réduit / Toggle] | [Clavier virtuel] |

---

## Thème visuel UI

| Propriété | Choix |
|-----------|-------|
| Style | [Fantasy / Sci-fi / Cartoon / Minimaliste / Pixel] |
| Couleur primaire | [#hex ou description] |
| Couleur secondaire | [#hex ou description] |
| Couleur accent | [#hex ou description] |
| Typographie | [Roblox default / Custom font] |
| Coins des boutons | [Arrondis / Carrés / Très arrondis] |
| Animations | [Subtiles / Prononcées / Aucune] |

---

## Questions clés

- [ ] Le joueur peut-il trouver n'importe quelle info en 2 clics max ?
- [ ] Le HUD ne surcharge pas l'écran (surtout mobile) ?
- [ ] Les boutons sont assez gros pour le tactile ?
- [ ] Les notifications sont visibles mais pas intrusives ?
- [ ] Le style UI est cohérent avec l'ambiance du jeu ?

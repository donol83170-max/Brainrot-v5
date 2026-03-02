# PRD 06 — UI & HUD — Dodgeball Royale

> Date : 2026-02-22
> Statut : VALIDÉ ✅

---

## HUD principal (en jeu)

> Ce que le joueur voit pendant le match — épuré, lisible d'un coup d'œil

```
┌──────────────────────────────────────────────────────────────┐
│ [🔴 Équipe A : 3 actifs | 1 prison]  [⏱ 3:42]  [🔵 Équipe B : 2 actifs | 2 prison] │
│                                                              │
│                                                              │
│                    ZONE DE JEU                               │
│                                                              │
│                                                              │
│          🌊 Zone rétrécit dans : 00:08  ⚠️                   │
│                                                              │
│ [minimap]          [🎯 BALLE ✅]         [🪙 Or : 240]       │
│                    [  ATTRAPE ! ]                            │
└──────────────────────────────────────────────────────────────┘
```

### Éléments du HUD

| Élément | Position | Toujours visible ? | Info affichée |
|---------|----------|-------------------|---------------|
| **Scores équipes** | Haut — gauche et droite | Oui | Nb joueurs actifs + en prison par équipe |
| **Timer match** | Haut centre | Oui | Temps restant (MM:SS) |
| **Indicateur balle** | Bas centre | Oui | ✅ "BALLE" si en main / ❌ si vide |
| **Alerte zone** | Bas centre (au-dessus balle) | Seulement avant rétrécissement | Compte à rebours + flash |
| **Mini-map** | Bas gauche | Oui | Zone actuelle + limite de la vague |
| **Or** | Bas droite | Oui | Solde Or actuel |
| **Prompt ATTRAPE !** | Centre écran | Contextuel (0,5s) | Apparaît quand une balle vole vers le joueur |
| **Notif prison** | Haut centre (sous timer) | Contextuel | "Tu es en prison — lance pour revenir !" |
| **Balle bonus** | Centre écran | Quand disponible | "⚡ BALLE BONUS DISPONIBLE !" |

### HUD en mode Prison

Quand le joueur est en prison, le HUD change légèrement :
- Le fond de l'écran a une légère teinte colorée (couleur équipe adverse)
- Le prompt "Lance pour te libérer !" est affiché en bas
- Le reste du HUD reste identique

---

## Arborescence des menus

```
LOBBY (écran principal)
├── [JOUER] → File d'attente → Match
├── [MISSIONS] → Missions quotidiennes
├── [INVENTAIRE] → Cosmétiques équipés
│   ├── Balles
│   ├── Effets traînée
│   ├── Titres
│   └── Auras
├── [BOUTIQUE]
│   ├── Boutique fixe (Or)
│   ├── Rotation hebdomadaire
│   └── Items du jour
├── [CLASSEMENT] → Top joueurs / amis
├── [STATS] → Stats personnelles
└── [PARAMÈTRES]
    ├── Audio
    ├── Graphiques
    └── Contrôles
```

---

## Détail par écran

---

### Écran : Lobby

**Accès :** Automatique à la connexion
**Le jeu est en pause ?** Non

```
┌──────────────────────────────────────────────────┐
│  🌴 DODGEBALL ROYALE 🌴        [⚙] [👤 Profil]  │
│  ─────────────────────────────────────────────── │
│                                                  │
│         [Joueurs qui se baladent en 3D]          │
│              (cosmétiques visibles)              │
│                                                  │
│  ─────────────────────────────────────────────── │
│  🪙 240 Or    Niveau 7 ██████░░ 620/1232 XP      │
│  ─────────────────────────────────────────────── │
│  [JOUER 🎯]  [MISSIONS📋]  [BOUTIQUE🛍]  [+]    │
└──────────────────────────────────────────────────┘
```

| Élément | Action |
|---------|--------|
| Bouton JOUER | Lance la file d'attente |
| Bouton MISSIONS | Ouvre le panneau missions quotidiennes |
| Bouton BOUTIQUE | Ouvre la boutique |
| [+] | Accès inventaire, classement, stats, paramètres |
| Clic sur un joueur | Voir son profil / ses cosmétiques |

---

### Écran : File d'attente

**Accès :** Via bouton JOUER
**Fermeture :** Bouton Annuler

```
┌──────────────────────────────┐
│  🔍 Recherche d'un match...  │
│  ──────────────────────────  │
│       ⏳  00:12              │
│                              │
│  Joueurs trouvés : 5/8       │
│  [████████░░░░░░░] 5/8       │
│                              │
│       [Annuler]              │
└──────────────────────────────┘
```

- Bots ajoutés automatiquement si la file tarde > 30 secondes

---

### Écran : Fin de match

**Accès :** Automatique à la fin du match
**Durée :** 10 secondes avant retour lobby automatique (ou bouton)

```
┌──────────────────────────────────────────────────┐
│         🏆 VICTOIRE ! / ❌ ÉLIMINÉ               │
│  ──────────────────────────────────────────────  │
│  🥇 Équipe Rouge — Vainqueur                     │
│  🥈 Équipe Bleue — 2ème                          │
│  ──────────────────────────────────────────────  │
│  TES STATS                                       │
│  🎯 Kills : 3     🔓 Libérations : 2             │
│  🏆 Victoires : Oui    🎖️ MVP : ✅               │
│  ──────────────────────────────────────────────  │
│  +125 XP  [████████████░░] Niveau 7 → 8 ?       │
│  +95 🪙 Or                                       │
│  ──────────────────────────────────────────────  │
│  [REJOUER]              [RETOUR LOBBY]           │
└──────────────────────────────────────────────────┘
```

---

### Écran : Boutique

**Accès :** Bouton BOUTIQUE dans le lobby

```
┌──────────────────────────────────────────────────┐
│  🛍 BOUTIQUE              🪙 240 Or    [X]       │
│  [FIXE]  [SEMAINE ⏳5j]  [AUJOURD'HUI ⏳3h]     │
│  ──────────────────────────────────────────────  │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐   │
│  │  Item  │ │  Item  │ │  Item  │ │  Item  │   │
│  │  🔥    │ │  ⭐    │ │  💨    │ │  👑    │   │
│  │300 Or  │ │200 R$  │ │150 Or  │ │400 R$  │   │
│  └────────┘ └────────┘ └────────┘ └────────┘   │
│  ──────────────────────────────────────────────  │
│  ⭐ ITEM VEDETTE — Skin "Tempête" (encore 5j)   │
│                        [ACHETER — 250 R$]        │
└──────────────────────────────────────────────────┘
```

---

### Écran : Missions quotidiennes

**Accès :** Bouton MISSIONS dans le lobby

```
┌──────────────────────────────────────────────────┐
│  📋 MISSIONS DU JOUR          Reset dans 08:42   │
│  ──────────────────────────────────────────────  │
│  ✅ Joue 2 matchs              +30 Or  RÉCLAMÉ  │
│  🔲 Fais 3 kills (1/3)         +50 Or           │
│  🔲 Libère-toi 2 fois (0/2)    +75 Or           │
│  ──────────────────────────────────────────────  │
│  Complète les 3 → Bonus +100 Or                  │
│  ──────────────────────────────────────────────  │
│                  [FERMER]                        │
└──────────────────────────────────────────────────┘
```

---

## Notifications & Popups

| Notification | Quand | Durée | Position | Style |
|-------------|-------|-------|----------|-------|
| **Level up** | Gain de niveau | 3s | Centre haut | Doré, animation confettis |
| **Or gagné** | Fin de match | 2s | Bas droite | Toast doré |
| **Mission complétée** | Objectif atteint | 2s | Bas droite | Toast vert |
| **Zone rétrécit** | 5s avant chaque vague | 5s | Centre bas | Flash bleu + son |
| **Éliminé** | Touché par une balle | Jusqu'en prison | Centre | Flash rouge + message |
| **Libéré** | Retour du prison | 2s | Centre | Flash vert + animation |
| **Balle bonus** | 1 min restante | 3s | Centre | Flash jaune + son |
| **Prompt ATTRAPE** | Balle qui vole vers toi | 0,5s | Centre | Gros texte + flash |
| **Login bonus** | Connexion journalière | Popup | Centre | Animé, or qui tombe |

---

## Thème visuel UI

| Propriété | Choix |
|-----------|-------|
| **Style** | Cartoon coloré — cohérent avec le thème plage |
| **Couleur primaire** | Bleu ciel (`#4FC3F7`) |
| **Couleur secondaire** | Sable doré (`#FFD54F`) |
| **Couleur accent** | Orange coral (`#FF7043`) |
| **Couleur équipe A** | Rouge vif (`#EF5350`) |
| **Couleur équipe B** | Bleu vif (`#42A5F5`) |
| **Typographie** | Police arrondie et grasse — lisible en un clin d'œil |
| **Coins des boutons** | Très arrondis (pill shape) |
| **Animations** | Prononcées — bouncy, satisfaisantes, cartoon |
| **Icônes** | Emojis + icônes cartoon simples |

---

## Responsive (Mobile vs PC)

| Élément | PC | Mobile |
|---------|-----|--------|
| HUD | Compact, discret | Boutons plus gros, zones tactiles min 48px |
| Menus | Fenêtre flottante | Plein écran |
| Bouton ATTRAPE | Touche E visible | Gros bouton tactile centre-bas |
| Boutons lobby | Hover effect | Tap — pas de hover |
| Chat | Bas gauche | Réduit / toggle |

---

## Questions clés validées

- [x] Le joueur trouve n'importe quelle info en 2 clics max ? → Oui : lobby → tout accessible depuis les 4 boutons principaux
- [x] Le HUD ne surcharge pas l'écran ? → Oui : épuré, seulement l'essentiel visible en permanence
- [x] Boutons assez gros pour le tactile ? → Oui : min 48px, adaptés mobile
- [x] Notifications visibles mais pas intrusives ? → Oui : toasts + centre uniquement pour les moments clés
- [x] Style UI cohérent avec le jeu ? → Oui : cartoon coloré plage, même palette que le terrain

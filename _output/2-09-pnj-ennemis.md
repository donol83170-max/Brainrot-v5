# PRD 09 — PNJ & Ennemis — Dodgeball Royale

> Date : 2026-02-22
> Statut : VALIDÉ ✅

> Note : Dodgeball Royale est un PvP pur. Il n'y a ni ennemis PvE, ni boss, ni marchands PNJ.
> Ce PRD couvre uniquement les **bots** (joueurs IA) et les **PNJ décoratifs** du lobby.

---

## Bots (Joueurs IA)

**Rôle :** Compléter les équipes quand le matchmaking manque de joueurs humains.
**Apparence :** Identique à un joueur humain (skin de base Roblox) — indiscernables visuellement.
**Nommage :** Noms générés aléatoirement (style pseudo Roblox — ex: "CoolDodger42").

---

### Comportements des Bots

Les bots ont **3 niveaux de difficulté**, assignés automatiquement selon le contexte :

| Niveau | Quand utilisé | Précision tir | Réaction esquive | Prison |
|--------|--------------|---------------|-----------------|--------|
| **Facile** | Niveaux 1-5 / serveurs peu peuplés | 30% | Lente (0,8s) | Tire rarement (40%) |
| **Normal** | Niveaux 6-20 / matchs standard | 55% | Normale (0,5s) | Tire souvent (70%) |
| **Difficile** | Niveaux 20+ / serveurs vides | 75% | Rapide (0,3s) | Tire toujours (90%) |

---

### Comportement détaillé (Bot Normal)

#### En jeu actif (sur le terrain)

| Situation | Comportement |
|-----------|-------------|
| A une balle | Se déplace vers le joueur le plus proche + tire avec délai de 0,5s |
| N'a pas de balle | Se déplace vers la balle la plus proche sur le terrain |
| Balle en approche | Tente d'esquiver (déplacement latéral) — réussite selon niveau |
| Balle attrapable | Tente d'attraper si prompt actif — réussite 40% (Normal) |
| Zone qui rétrécit | Se déplace vers le centre automatiquement (délai 1s après alerte) |

#### En prison

| Situation | Comportement |
|-----------|-------------|
| Arrive en prison | Attend 1-2 secondes (simulation de réflexion) |
| A sa balle | Vise un joueur adverse actif + tire |
| Rate son tir | Attend le cooldown (3s) + recommence |
| Plusieurs prisonniers | Chaque bot agit indépendamment (pas de coordination entre bots) |

---

### Paramètres IA

| Paramètre | Valeur |
|-----------|--------|
| Distance de détection balle | 40 studs |
| Distance de détection joueur adverse | 60 studs |
| Vitesse de déplacement | Identique au joueur humain |
| Délai avant tir (Normal) | 0,4 - 0,7s (aléatoire dans la fourchette) |
| Délai réaction esquive (Normal) | 0,5s après détection balle |
| Cooldown après raté en prison | 3s (même que joueurs humains) |

---

### Règles anti-frustration

- Un bot ne peut pas **attraper 2 fois de suite** (laisse une chance au joueur)
- Les bots ne **spamment pas** la balle (délai minimum 1s entre actions)
- Un bot ne vise **jamais** un joueur déjà en prison (cible uniquement les joueurs actifs)
- En fin de match (dernière minute), les bots restants passent en difficulté **Facile** — pour que les humains aient plus de chances de gagner

---

### Scaling selon le serveur

| Situation | Niveau des bots |
|-----------|----------------|
| Serveur plein (8 humains) | Aucun bot |
| 1-2 joueurs manquants | Bots Normal |
| 3+ joueurs manquants | Mix Normal + Facile |
| Serveur presque vide (1-2 humains) | Bots Facile — pour ne pas frustrer |

---

## PNJ Décoratifs (Lobby)

Deux PNJ décoratifs dans le lobby — purement visuels, aucune interaction de gameplay.

### PNJ : Le Maître de Plage

| | Détail |
|---|--------|
| **Rôle** | Décoratif — donne l'ambiance du lobby |
| **Localisation** | Près du panneau "JOUER" dans le lobby |
| **Apparence** | Personnage Roblox avec chapeau de plage, sifflet, short coloré |
| **Interaction** | Clic → dialogue flavor text uniquement |

**Dialogues (aléatoires au clic) :**
- "Prêt à lancer ? La plage t'attend !"
- "Dernier à rester debout gagne. Simple, non ?"
- "Regarde bien la zone — la marée ne pardonne pas !"

---

### PNJ : Le Marchand de Glaces

| | Détail |
|---|--------|
| **Rôle** | Décoratif — accès rapide à la boutique |
| **Localisation** | Près de la zone boutique dans le lobby |
| **Apparence** | Personnage Roblox avec chariot à glaces coloré |
| **Interaction** | Clic → ouvre le menu Boutique (raccourci) |

**Dialogues (aléatoires au clic) :**
- "Nouveau look, nouveau champion !"
- "Les meilleures balles sont en stock cette semaine..."
- "Un beau skin, ça impressionne avant même de lancer !"

---

## Questions clés validées

- [x] Les bots sont-ils distincts et reconnaissables ? → Non nécessaire — ils imitent des humains
- [x] La difficulté suit-elle la courbe de progression ? → Oui : Facile pour débutants, Difficile pour vétérans
- [x] Les bots ne frustrent-ils pas les joueurs ? → Oui : règles anti-frustration + bots faciles en fin de match
- [x] Les PNJ sont-ils utiles ? → Oui : ambiance lobby + accès boutique rapide
- [x] Un serveur vide reste-t-il jouable ? → Oui : bots toujours disponibles pour compléter

# PRD 02 — Mécaniques de jeu — Dodgeball Royale

> Date : 2026-02-22
> Statut : VALIDÉ ✅

---

## Liste des mécaniques

| # | Mécanique | Catégorie | MVP |
|---|-----------|-----------|-----|
| 1 | Déplacement | Mouvement | Oui |
| 2 | Lancer | Combat | Oui |
| 3 | Attraper | Combat | Oui |
| 4 | Élimination | Combat | Oui |
| 5 | Système Prison | Prison | Oui |
| 6 | Libération | Prison | Oui |
| 7 | Zone Dynamique | Survie | Oui |
| 8 | Balle Bonus | Survie | Oui |
| 9 | Condition de Victoire | Règles | Oui |

---

## Détail par mécanique

---

### Mécanique 1 : Déplacement

**Résumé :** Le joueur se déplace librement sur le terrain pour esquiver, se positionner et atteindre la balle.

**Inputs joueur :**
| Input | Action | Plateforme |
|-------|--------|-----------|
| WASD / ZQSD | Déplacement | PC |
| Espace | Saut | PC |
| Joystick virtuel gauche | Déplacement | Mobile |
| Bouton saut | Saut | Mobile |
| Stick gauche | Déplacement | Manette |
| A / X | Saut | Manette |

**Règles :**
- Vitesse de déplacement fixe (pas de sprint) — tout le monde est égal en mobilité
- Le joueur peut sauter par-dessus les obstacles bas présents sur le terrain
- Pas de déplacement en dehors de la zone active (mur invisible ou zone éliminante)
- Les prisonniers se déplacent librement dans leur zone prison

---

### Mécanique 2 : Lancer

**Résumé :** Le joueur vise avec sa souris et lance la balle en direction du curseur d'un clic gauche.

**Inputs joueur :**
| Input | Action | Plateforme |
|-------|--------|-----------|
| Déplacement souris | Viser | PC |
| Clic gauche | Lancer | PC |
| Joystick virtuel droit | Viser | Mobile |
| Bouton Lancer | Lancer | Mobile |
| Stick droit | Viser | Manette |
| Gâchette droite (RT/R2) | Lancer | Manette |

**Comportement :**
1. Le joueur a une balle en main (indiqué visuellement)
2. Il vise avec le curseur / joystick droit
3. Il appuie sur Lancer
4. La balle part en trajectoire rectiligne dans la direction visée
5. Si la balle touche un adversaire → élimination (voir Mécanique 4)
6. Si la balle touche le sol ou un mur → rebondit une fois puis disparaît / devient ramassable

**Règles :**
- Vitesse de la balle : fixe (pas de charge)
- Un joueur ne peut porter qu'une seule balle à la fois
- Après le lancer, le joueur est sans balle — il doit en récupérer une au sol ou attendre
- La balle peut être attrapée par un adversaire (voir Mécanique 3)
- En prison : même fonctionnement, la balle est lancée vers le terrain principal

**Feedback :**
- Visuel : trajectoire visible de la balle, animation du bras qui lance
- Sonore : son de lancer distinctif
- UI : indicateur "BALLE" disparaît du HUD après le lancer

---

### Mécanique 3 : Attraper

**Résumé :** Quand une balle vole vers le joueur, il peut appuyer sur un bouton dans une courte fenêtre de timing pour l'attraper et éviter l'élimination.

**Inputs joueur :**
| Input | Action | Plateforme |
|-------|--------|-----------|
| E | Attraper | PC |
| Bouton Attraper (contextuel) | Attraper | Mobile |
| B / O | Attraper | Manette |

**Comportement :**
1. Une balle adverse vole en direction du joueur
2. Un prompt "ATTRAPE !" apparaît à l'écran (fenêtre de **0,5 seconde**)
3. **Si le joueur appuie dans la fenêtre :**
   - Il attrape la balle → pas éliminé
   - La balle est maintenant dans ses mains → peut la lancer
4. **Si le joueur ne réagit pas dans la fenêtre :**
   - La balle le touche → il est éliminé (voir Mécanique 4)

**Règles :**
- On ne peut attraper que si on n'a **pas déjà une balle en main** (si tu as une balle, esquive ou tu es éliminé)
- Le prompt n'apparaît que si la balle vole dans un rayon proche du joueur (pas de fausse alerte pour les balles lointaines)
- En prison : les prisonniers peuvent aussi attraper des balles qui entrent dans leur zone

**Feedback :**
- Visuel : flash vert sur le joueur + animation d'attrapage
- Sonore : son de catch satisfaisant (clap/impact sourd)
- UI : indicateur "BALLE" apparaît dans le HUD

**Interactions :**
- Attraper annule une élimination → lié à Mécanique 4
- La balle attrapée peut immédiatement être relancée → lié à Mécanique 2

---

### Mécanique 4 : Élimination

**Résumé :** Un joueur touché par une balle qu'il n'a pas attrapée est éliminé et envoyé en zone prison.

**Comportement :**
1. La balle touche le hitbox du joueur
2. Le serveur valide le touché (anti-triche côté serveur)
3. Animation d'élimination jouée
4. Le joueur est téléporté en **zone prison** de l'équipe adverse
5. Il spawn avec une balle immédiatement dans les mains

**Règles :**
- Le touché est validé côté **serveur** (pas côté client) pour éviter la triche
- Un joueur en prison est **intouchable** — les balles le traversent
- Une balle ne peut éliminer qu'**un seul joueur** par lancer (pas de chain)
- Les coéquipiers ne peuvent pas s'éliminer entre eux (friendly fire désactivé)

**Feedback :**
- Visuel : flash rouge sur le joueur touché + effet d'étourdissement 0,5s + fondu vers la prison
- Sonore : son d'impact fort + son de téléportation prison
- UI : message "Tu as été éliminé ! Lance depuis la prison pour revenir !"

---

### Mécanique 5 : Système Prison

**Résumé :** Les joueurs éliminés sont envoyés dans une zone derrière la ligne ennemie, où ils restent actifs avec une balle.

**Disposition :**
```
[ZONE PRISON Équipe B] | [======= TERRAIN =======] | [ZONE PRISON Équipe A]
```

**Règles :**
- La zone prison est **derrière la ligne de fond ennemie**, en dehors du terrain principal
- Les prisonniers peuvent **se déplacer librement** dans leur zone
- Les prisonniers sont **intouchables** — les balles ne les atteignent pas
- Chaque prisonnier a **sa propre balle** (pas de compétition entre prisonniers)
- La zone prison n'est **pas affectée** par le rétrécissement de la zone principale
- Plusieurs prisonniers d'une même équipe peuvent être en prison simultanément

**Feedback :**
- Visuel : zone prison distincte visuellement (couleur d'équipe + barrière visuelle)
- UI : compteur du nombre de prisonniers par équipe visible sur le HUD

---

### Mécanique 6 : Libération

**Résumé :** Un prisonnier peut se libérer en touchant un adversaire actif avec sa balle depuis la zone prison.

**Comportement :**
1. Le prisonnier vise un adversaire sur le terrain principal
2. Il lance sa balle (même contrôles que Mécanique 2)
3. **Si la balle touche un adversaire actif :**
   - L'adversaire est éliminé (envoyé en prison)
   - Le prisonnier est **libéré** → téléporté sur le terrain dans la zone encore active
4. **Si la balle rate (sol, mur, ou attrapée) :**
   - Cooldown de **3 secondes**
   - Nouvelle balle apparaît dans les mains du prisonnier

**Règles :**
- Un prisonnier ne peut libérer **qu'un seul coéquipier** par lancer (lui-même uniquement — pas de libération en chaîne)
- La balle lancée depuis la prison **peut être attrapée** par un adversaire actif (Mécanique 3)
- Après libération, le joueur respawn avec **une balle vide** (doit en récupérer une sur le terrain)

**Feedback :**
- Visuel : animation de libération spectaculaire (lumière, effet de particules) + message "[Nom] est de retour !"
- Sonore : son de libération distinct et satisfaisant
- UI : notification à toute l'équipe "Coéquipier libéré !"

---

### Mécanique 7 : Zone Dynamique

**Résumé :** La zone de jeu rétrécit progressivement au fil des éliminations, forçant les joueurs à se rapprocher.

**Comportement :**
1. Le match commence avec le terrain à sa taille maximale
2. À chaque **2 éliminations**, la zone rétrécit d'un palier
3. **5 secondes avant** le rétrécissement : alerte visuelle et sonore
4. Les joueurs hors de la nouvelle zone ont **3 secondes** pour rentrer
5. Passé ce délai : élimination automatique

**Paliers de rétrécissement (exemple pour 4v4 = 8 joueurs) :**
| Éliminations | Taille de la zone | Phase |
|---|---|---|
| 0 | 100% | Début |
| 2 | 75% | Phase 2 |
| 4 | 50% | Phase 3 |
| 6 | 30% | Phase finale |
| Balle bonus | — | Dernière minute |

**Règles :**
- La zone prison **ne rétrécit jamais** — les prisonniers gardent leur espace
- Le centre de la zone est **fixe** (centre du terrain)
- La zone est **circulaire** pour éviter les angles morts

**Feedback :**
- Visuel : ligne / mur lumineux indiquant la limite de zone + compte à rebours de rétrécissement
- Sonore : alarme distinctive avant chaque rétrécissement
- UI : mini-map avec la zone visible en permanence

---

### Mécanique 8 : Balle Bonus

**Résumé :** À la dernière minute du match, une balle bonus supplémentaire apparaît dans le camp de chaque équipe, accélérant la fin de partie.

**Comportement :**
1. Quand il reste **60 secondes** de match (ou quand il reste 2 équipes actives)
2. Une balle bonus apparaît dans la moitié du terrain de chaque équipe
3. N'importe quel joueur actif de l'équipe peut la ramasser
4. La balle bonus fonctionne exactement comme une balle normale

**Règles :**
- Maximum **une balle bonus par équipe**
- Si personne ne la ramasse, elle reste au sol jusqu'à la fin du match
- La balle bonus a un **visuel distinct** (effet lumineux, couleur différente) pour la repérer facilement

**Feedback :**
- Visuel : apparition animée de la balle avec effet lumineux + indicateur sur la mini-map
- Sonore : son d'apparition spécial "dernier round"
- UI : alerte "BALLE BONUS DISPONIBLE !" pour chaque équipe

---

### Mécanique 9 : Condition de Victoire

**Résumé :** Une équipe est éliminée quand tous ses membres sont en prison simultanément. La dernière équipe avec au moins un joueur libre remporte le match.

**Comportement :**
1. Tous les membres d'une équipe se retrouvent en prison en même temps
2. Chaque prisonnier a **une dernière tentative** de lancer pour se libérer
3. Si au moins un prisonnier touche un adversaire → l'équipe survit (le prisonnier est libéré)
4. Si tous les lancers ratent → l'équipe est **éliminée**
5. Le match continue jusqu'à ce qu'il ne reste **qu'une équipe**

**Fin de match :**
- Écran de résultats avec classement final, stats individuelles, XP gagné
- Animation de victoire pour l'équipe gagnante
- Retour au lobby après 10 secondes

---

## Contrôles complets

### PC

| Touche | Action |
|--------|--------|
| WASD / ZQSD | Déplacement |
| Espace | Saut |
| Souris | Viser |
| Clic gauche | Lancer |
| E | Attraper (contextuel) |
| Tab | Scores / HUD étendu |
| Échap | Menu pause |

### Mobile

| Geste / Bouton | Action |
|----------------|--------|
| Joystick virtuel gauche | Déplacement |
| Bouton saut | Saut |
| Joystick virtuel droit | Viser |
| Bouton Lancer | Lancer |
| Bouton Attraper (contextuel) | Attraper |

### Manette

| Bouton | Action |
|--------|--------|
| Stick gauche | Déplacement |
| Stick droit | Viser / Caméra |
| A / X | Saut |
| Gâchette droite (RT / R2) | Lancer |
| B / O | Attraper |
| Start | Menu pause |

---

## Formules de calcul

| Formule | Expression | Exemple |
|---------|-----------|---------|
| XP requis par niveau | `100 × niveau^1.4` | Niveau 5 → 690 XP, Niveau 10 → 2512 XP |
| XP moyen par match | `20 (participation) + kills×15 + libérations×10 + victoire×50` | 2 kills + 1 libé + victoire = 125 XP |
| Temps pour level 10 | ~20-30 matchs selon performance | Environ 2-4 heures de jeu |
| Cooldown balle prison | 3 secondes fixe | — |
| Fenêtre d'attrapage | 0,5 seconde | — |
| Délai hors zone | 3 secondes avant élimination | — |

---

## Interactions entre mécaniques

| | Déplacement | Lancer | Attraper | Élimination | Prison | Libération | Zone |
|---|---|---|---|---|---|---|---|
| **Déplacement** | — | Repositionnement avant tir | Esquive alternative | Fuir la zone | Libre en prison | Revenir dans la zone | S'adapter au rétrécissement |
| **Lancer** | — | — | Peut être contré | Cause l'élimination | Depuis la prison | Libère si touche | Depuis n'importe quelle position |
| **Attraper** | — | — | — | Annule l'élimination | Possible en prison | Contrecarre la libération | — |
| **Zone** | — | — | — | Hors zone = éliminé | Prison non affectée | Libéré dans zone active | — |

---

## Questions clés validées

- [x] Chaque mécanique est-elle intuitive sans tutoriel ? → Oui : lancer = clic, attraper = E au bon moment
- [x] Les contrôles sont-ils confortables sur toutes les plateformes ? → Oui : adaptés PC / Mobile / Manette
- [x] Les formules sont-elles équilibrées ? → À valider en test, mais les bases sont cohérentes
- [x] Chaque mécanique a-t-elle un feedback clair ? → Oui : visuel + sonore + UI pour chaque action

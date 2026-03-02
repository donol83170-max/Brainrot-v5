# PRD 11 — Onboarding & Tutoriel

> Les 5 premières minutes du joueur. C'est là que tout se joue.

---

## Principe fondamental

> **Si un joueur ne comprend pas ton jeu en 2 minutes, il quitte.**
> Sur Roblox, tu as ~30 secondes pour accrocher, ~2 minutes pour convaincre.

---

## FTUE (First Time User Experience)

### Seconde 0-10 : Première impression

| | Ce qui se passe |
|---|-----------------|
| **Écran de chargement** | [Texte / Image / Tips / Rien ?] |
| **Premier visuel** | [Que voit le joueur à l'arrivée ?] |
| **Premier son** | [Musique qui démarre ? Son ambiant ?] |
| **Première action possible** | [Que peut-il faire immédiatement ?] |

### Seconde 10-30 : Le hook

| | Ce qui se passe |
|---|-----------------|
| **Événement accrocheur** | [Explosion, PNJ qui parle, cutscene, action forcée ?] |
| **Première récompense** | [Item gratuit, XP, cosmétique de bienvenue ?] |
| **Le joueur comprend** | [Le but du jeu en une phrase — comment c'est communiqué ?] |

### Minutes 1-5 : Le tutoriel

| Étape | Ce qu'on apprend | Comment | Durée |
|-------|-----------------|---------|-------|
| 1 | Se déplacer | [Texte à l'écran / Tutoriel interactif / PNJ] | [30s] |
| 2 | [Action principale] | [Cible de pratique, ennemi facile] | [1min] |
| 3 | [Mécanisme secondaire] | [Mission guidée simple] | [1min] |
| 4 | [Première récompense] | [Coffre facile, level up] | [30s] |
| 5 | [Lâché dans le jeu] | [Objectif clair donné, liberté de jouer] | — |

### Style de tutoriel choisi

| Style | Description | Notre choix ? |
|-------|-------------|---------------|
| **Guidé par PNJ** | Un personnage guide le joueur pas à pas | [ ] |
| **Contextuel** | Tooltips qui apparaissent au bon moment | [ ] |
| **Par la pratique** | Zone de tutoriel fermée avec objectifs | [ ] |
| **Minimaliste** | Presque rien — le joueur découvre seul | [ ] |
| **Hybride** | Mix de plusieurs styles | [ ] |

---

## Objectifs visibles

> Le joueur doit TOUJOURS avoir un objectif clair

| Moment | Objectif affiché | Récompense promise |
|--------|-----------------|-------------------|
| Après le tuto | [Ex: "Tue 5 slimes"] | [50 coins] |
| Après objectif 1 | [Ex: "Trouve la forge"] | [Épée en fer] |
| Après objectif 2 | [Ex: "Atteins niveau 5"] | [Nouvelle zone débloquée] |
| Après objectif 3 | [Ex: "Bats le premier boss"] | [Item rare + titre] |

---

## Tooltips & Indices

| Tooltip | Condition d'affichage | Texte | Se cache après |
|---------|----------------------|-------|----------------|
| Mouvement | Premier spawn | "Utilise WASD pour te déplacer" | 10s ou mouvement |
| Combat | Premier ennemi proche | "Clique pour attaquer" | Premier coup |
| Inventaire | Premier item obtenu | "Appuie sur Tab pour l'inventaire" | Ouverture inventaire |
| [Autre] | | | |

**Fréquence :** [Un tooltip à la fois, pas de spam]
**Désactivable ?** [Oui — bouton "J'ai compris" ou option dans paramètres]

---

## Aides pour les joueurs perdus

| Situation | Détection | Solution |
|-----------|-----------|---------|
| Joueur immobile > 30s | Timer | [Tooltip d'aide / PNJ qui interpelle] |
| Joueur meurt 3x au même endroit | Compteur | [Conseil spécifique / Difficulté réduite temporaire ?] |
| Joueur n'a pas progressé depuis 5min | Timer quête | [Rappel objectif / Flèche directionnelle] |
| Joueur quitte et revient | Flag DB | [Résumé de ce qu'il faisait / Repositionnement] |

---

## Rétention premiers jours

| Jour | Objectif de rétention | Mécanisme |
|------|----------------------|-----------|
| Jour 1 | Finir le tutoriel + premier objectif | Récompense satisfaisante |
| Jour 2 | Revenir pour une raison | [Quête quotidienne / Récompense de login / "Continue demain"] |
| Jour 3 | S'investir dans la progression | [Premier choix significatif (classe, spé, base)] |
| Jour 7 | Faire partie de la communauté | [Guilde, amis, classement, trade] |

---

## Skippable ?

| | Détail |
|---|--------|
| **Le tuto est-il obligatoire ?** | [Oui (premier personnage) / Skippable (alt)] |
| **Skip total possible ?** | [Oui / Non — Pour les joueurs expérimentés ?] |
| **Re-jouer le tuto ?** | [Commande / PNJ / Impossible] |

---

## Questions clés

- [ ] Un joueur de 10 ans comprend-il le jeu en 2 minutes ?
- [ ] Le tutoriel est-il fun (pas une corvée) ?
- [ ] Le joueur a-t-il envie de continuer après les 5 premières minutes ?
- [ ] Les tooltips sont-ils utiles sans être envahissants ?
- [ ] Il y a un objectif clair à tout moment ?

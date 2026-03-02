# PRD 11 — Onboarding & Tutoriel — Dodgeball Royale

> Date : 2026-02-22
> Statut : VALIDÉ ✅

> Avantage clé : La balle au prisonnier est un jeu universel connu de tous les 7-16 ans.
> L'onboarding doit juste expliquer les **2 twists** : la prison active + la zone BR.

---

## Principe

> Sur Roblox, un joueur quitte s'il s'ennuie 30 secondes.
> Chez Dodgeball Royale : le joueur doit tenir une balle dans les mains **dans les 20 premières secondes**.

Pas de tutoriel séparé. L'apprentissage se fait **dans le premier match**, via des tooltips contextuels.

---

## Style de tutoriel choisi

| Style | Notre choix |
|-------|-------------|
| Guidé par PNJ | ❌ |
| Contextuel (tooltips au bon moment) | ✅ Principal |
| Par la pratique (dans le vrai match) | ✅ Complémentaire |
| Minimaliste (découverte libre) | ❌ |
| **Hybride contextuel + pratique** | ✅ **Choix final** |

---

## FTUE (First Time User Experience)

### Secondes 0-10 : Chargement

| | Ce qui se passe |
|---|-----------------|
| **Écran de chargement** | Logo Dodgeball Royale + tip rotatif toutes les 3s |
| **Tips de chargement** | "Lance la balle pour éliminer tes adversaires" / "En prison ? Lance depuis là-bas pour revenir !" / "La marée monte — reste dans la zone !" |
| **Premier son** | Musique lobby démarre en fondu |

---

### Secondes 10-30 : Arrivée dans le lobby (1ère connexion)

Popup de bienvenue automatique (skippable en 1 clic) :

```
┌────────────────────────────────────────┐
│  🏖️ BIENVENUE dans DODGEBALL ROYALE !  │
│  ──────────────────────────────────── │
│  🎯 Lance la balle → élimine           │
│  🔓 En prison ? Tire pour revenir      │
│  🌊 Reste dans la zone — la marée monte│
│  ──────────────────────────────────── │
│  [JOUER MON 1ER MATCH]   [Skip]        │
└────────────────────────────────────────┘
```

- **Récompense de bienvenue** affichée : "🎁 Pack de bienvenue t'attend après ton 1er match !"
- Le joueur voit les autres dans le lobby, voit leurs cosmétiques → envie de jouer

---

### Minutes 1-5 : Premier match avec tooltips contextuels

Les tooltips apparaissent **une seule fois**, au bon moment, et disparaissent automatiquement.

| Étape | Déclencheur | Tooltip affiché | Durée |
|-------|-------------|-----------------|-------|
| **1 — Déplacement** | 1ère seconde du match | "WASD / Joystick pour te déplacer" | 5s ou mouvement |
| **2 — Lancer** | Balle en main | "🖱️ Vise avec la souris — Clic pour lancer !" | 5s ou lancer |
| **3 — Attraper** | 1ère balle qui vole vers le joueur | "Appuie sur [E] quand tu vois ATTRAPE !" | Pendant le prompt |
| **4 — Prison** | Premier fois en prison | "Tu es en prison ! Lance ta balle sur un adversaire pour revenir !" | 6s ou lancer |
| **5 — Zone** | 1ère alerte de rétrécissement | "La marée monte ! Reste dans la zone !" | 5s |
| **6 — Balle bonus** | Apparition balle bonus | "⚡ Balle bonus ! Va la chercher !" | 3s |

**Règles des tooltips :**
- Un seul tooltip à la fois — jamais deux superposés
- Désactivables dans les paramètres après le 1er match
- Chaque tooltip n'apparaît qu'**une seule fois** dans la vie du compte

---

### Fin du 1er match : La récompense de bienvenue

Quelle que soit l'issue (victoire ou défaite) :

```
┌───────────────────────────────────────┐
│  🎁 PACK DE BIENVENUE                 │
│  ─────────────────────────────────── │
│  + 100 Or 🪙                          │
│  + Skin balle "Tropical" 🌺 (offert)  │
│  + Titre "Rookie" 🟩                  │
│  ─────────────────────────────────── │
│  Tu as gagné 45 XP — Niveau 1 → 2 !  │
│             [SUPER !]                 │
└───────────────────────────────────────┘
```

---

## Objectifs visibles (après le tuto)

| Moment | Objectif affiché | Récompense promise |
|--------|-----------------|-------------------|
| Après 1er match | "Joue 3 matchs au total" | +150 Or |
| Après 3 matchs | "Atteins le niveau 5" | Titre "Rookie" + animation libération |
| Après niveau 5 | "Complète ta 1ère mission quotidienne" | +100 Or bonus |
| Après 1ère mission | "Gagne un match !" | +50 XP bonus |

---

## Tooltips en jeu (récurrents)

| Tooltip | Condition | Texte | Se cache après |
|---------|-----------|-------|----------------|
| Rappel lancer | 5s en main sans lancer | "Lance !" + flèche | Lancer |
| Rappel prison | 4s en prison sans tirer | "Tire depuis ici pour revenir !" | Tir |
| Zone danger | Joueur à la limite | "⚠️ Rentre dans la zone !" (rouge) | Entrée zone |
| Balle au sol | 3s sans balle sur terrain | Flèche vers la balle la plus proche | Pick-up |

---

## Rétention premiers jours

| Jour | Objectif | Mécanisme |
|------|----------|-----------|
| **Jour 1** | Finir 3 matchs + obtenir pack bienvenue | Récompense immédiate + objectif guidé clair |
| **Jour 2** | Revenir pour les missions quotidiennes | Notification "Nouvelles missions disponibles !" + login bonus |
| **Jour 3** | Viser le niveau 5 (titre "Rookie") | Progression visible, prochain palier clair |
| **Jour 7** | Login bonus max (300 Or) + amis | Pic de récompense + incitation à inviter des amis |

---

## Skippable ?

| | Détail |
|---|--------|
| **Popup bienvenue** | Oui — bouton "Skip" visible |
| **Tooltips in-match** | Skippable individuellement (clic dessus) / tous désactivables en paramètres |
| **Pack de bienvenue** | Non — offert automatiquement à la fin du 1er match (pas de skip) |
| **Re-voir le tutoriel** | Options → "Réactiver les conseils" |

---

## Questions clés validées

- [x] Un joueur de 7 ans comprend-il le jeu en 2 minutes ? → Oui : balle au prisonnier universelle + 3 règles en popup
- [x] Le tutoriel est-il fun ? → Oui : pas de zone tuto séparée, apprentissage dans le vrai match
- [x] Le joueur a-t-il envie de continuer après 5 minutes ? → Oui : pack de bienvenue + objectif niveau 5 visible
- [x] Les tooltips sont-ils utiles sans envahir ? → Oui : 1 à la fois, 1 seule fois par compte, skippables
- [x] Un objectif est-il toujours visible ? → Oui : chaîne d'objectifs guidée jusqu'au niveau 5

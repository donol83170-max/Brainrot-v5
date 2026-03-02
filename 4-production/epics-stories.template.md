# Plan de Production — [NOM DU JEU]

> Découpage en Epics et Stories. Chaque story = une tâche codable en 1-4h.

---

## Epics (grands blocs de travail)

> Un Epic = un système complet du jeu. Dérivé directement des PRD et de l'Architecture.

| # | Epic | PRD source | Priorité | Statut |
|---|------|-----------|----------|--------|
| E1 | Infrastructure de base | Architecture | CRITIQUE | [ ] |
| E2 | Core Loop | PRD 01, 02 | CRITIQUE | [ ] |
| E3 | Monde & Map | PRD 03 | HAUTE | [ ] |
| E4 | Système de progression | PRD 04 | HAUTE | [ ] |
| E5 | Économie & Boutique | PRD 05, 12 | HAUTE | [ ] |
| E6 | UI & HUD | PRD 06 | HAUTE | [ ] |
| E7 | Social & Multi | PRD 07 | MOYENNE | [ ] |
| E8 | Items & Inventaire | PRD 08 | HAUTE | [ ] |
| E9 | PNJ & Ennemis | PRD 09 | HAUTE | [ ] |
| E10 | Audio & Visuel | PRD 10 | MOYENNE | [ ] |
| E11 | Onboarding & Tuto | PRD 11 | HAUTE | [ ] |
| E12 | Monétisation | PRD 12 | MOYENNE | [ ] |
| E13 | Polish & Launch | Tous | HAUTE | [ ] |

---

## Scope MVP

> Qu'est-ce qui DOIT être dans la première version jouable ?

### MVP = Epics critiques + hautes

| Epic | Dans le MVP ? | Version réduite ? |
|------|--------------|-------------------|
| E1 Infrastructure | OUI | Non (complet) |
| E2 Core Loop | OUI | Non (complet) |
| E3 Monde | OUI | [Réduit à X zones au lieu de Y] |
| E4 Progression | OUI | [Réduit à niveau max X au lieu de Y] |
| E5 Économie | OUI | [Version simplifiée — 1 monnaie] |
| E6 UI | OUI | [HUD basique, menus essentiels] |
| E7 Social | NON | [Post-MVP] |
| E8 Items | OUI | [Réduit à X items au lieu de Y] |
| E9 PNJ/Ennemis | OUI | [Réduit à X types au lieu de Y] |
| E10 Audio/Visuel | PARTIEL | [Sons basiques, pas de musique custom] |
| E11 Onboarding | OUI | [Tuto minimal] |
| E12 Monétisation | PARTIEL | [Game Passes basiques] |
| E13 Polish | OUI | [Bug fixes, performance] |

---

## Découpage en Stories

> Copier ce bloc pour chaque Epic et lister toutes les stories

### Epic E1 : Infrastructure de base

| # | Story | Critère de "fait" | Estimation | Dépendance |
|---|-------|-------------------|-----------|------------|
| E1-S1 | Créer la structure de dossiers Roblox | Tous les dossiers existent selon l'architecture | 30min | — |
| E1-S2 | Implémenter le système de sauvegarde/chargement | Les données persistent entre sessions | 2-3h | — |
| E1-S3 | Créer les RemoteEvents et les connecter | Events créés, listeners en place | 1-2h | E1-S1 |
| E1-S4 | Mettre en place le GameConfig | Toutes les constantes dans un module central | 1h | E1-S1 |
| E1-S5 | Système de logging/debug | Console structurée pour le dev | 30min | — |

### Epic E2 : Core Loop

| # | Story | Critère de "fait" | Estimation | Dépendance |
|---|-------|-------------------|-----------|------------|
| E2-S1 | [Mécanique principale 1] | [Critère] | [Xh] | E1-S3 |
| E2-S2 | [Mécanique principale 2] | [Critère] | [Xh] | E2-S1 |
| E2-S3 | [Feedback visuel/sonore du core loop] | [Critère] | [Xh] | E2-S1 |
| | | | | |

### Epic E3 : Monde & Map
| # | Story | Critère de "fait" | Estimation | Dépendance |
|---|-------|-------------------|-----------|------------|
| | | | | |

### Epic E4-E13 : [À détailler de la même manière]

---

## Ordre de développement

> Le chemin critique : dans quel ordre coder les stories ?

```
SEMAINE 1 : Infrastructure
E1-S1 → E1-S2 → E1-S3 → E1-S4

SEMAINE 2 : Core Loop
E2-S1 → E2-S2 → E2-S3

SEMAINE 3 : Monde + Ennemis basiques
E3-S1 (map basique) → E9-S1 (ennemi basique)

SEMAINE 4 : Progression + Items
E4-S1 (XP/Levels) → E8-S1 (inventaire basique)

SEMAINE 5 : Économie + UI
E5-S1 (monnaie) → E6-S1 (HUD) → E6-S2 (menus)

SEMAINE 6 : Onboarding + Polish
E11-S1 (tuto) → E13-S1 (bugs) → E13-S2 (perf)

POST-MVP : Social, Monétisation complète, Events
```

---

## Matrice de priorité

```
                    IMPACT ÉLEVÉ
                         │
         ┌───────────────┼───────────────┐
         │   QUICK WINS   │   BIG BETS    │
         │   Faire en     │   Planifier   │
EFFORT   │   premier      │   et exécuter │
FAIBLE ──┼───────────────┼───────────────┼── EFFORT ÉLEVÉ
         │   FILL-INS    │   MONEY PITS   │
         │   Quand on     │   Éviter ou   │
         │   a le temps   │   simplifier  │
         └───────────────┼───────────────┘
                         │
                    IMPACT FAIBLE
```

---

## Suivi de progression

### Sprint actuel : Sprint [X] — [dates]

| Story | Assigné à | Statut | Notes |
|-------|-----------|--------|-------|
| [E1-S1] | [Nom] | [TODO/En cours/Fait/Bloqué] | |
| [E1-S2] | [Nom] | | |
| | | | |

### Résumé global

| Epic | Stories total | Faites | En cours | TODO |
|------|-------------|--------|----------|------|
| E1 | | | | |
| E2 | | | | |
| ... | | | | |
| **TOTAL** | | | | |

---

## Playtesting

### Checklist avant chaque playtest

- [ ] Le jeu ne crash pas
- [ ] La sauvegarde fonctionne
- [ ] Les mécaniques principales marchent
- [ ] Le joueur peut comprendre quoi faire

### Feedback à collecter

| Question | Méthode |
|----------|---------|
| Le jeu est-il fun ? | Observation + question directe |
| Le joueur comprend-il le jeu ? | Observer sans aider |
| Où le joueur est-il bloqué/frustré ? | Observer les moments de confusion |
| Combien de temps joue-t-il avant d'arrêter ? | Timer |
| Reviendrait-il ? | Question directe |

---

## Questions clés

- [ ] Chaque PRD est-il couvert par au moins un Epic ?
- [ ] Chaque story est-elle assez petite (1-4h) ?
- [ ] Les dépendances sont-elles réalistes ?
- [ ] Le scope MVP est-il jouable et fun (pas juste "fonctionnel") ?
- [ ] Le planning est-il tenable pour l'équipe ?

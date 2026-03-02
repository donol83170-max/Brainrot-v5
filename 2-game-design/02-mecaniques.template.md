# PRD 02 — Mécaniques de jeu

> Chaque mécanique du jeu détaillée : comment ça marche exactement.

---

## Liste des mécaniques

> Lister TOUTES les mécaniques du jeu, même les plus simples

| # | Mécanique | Catégorie | Priorité MVP |
|---|-----------|-----------|-------------|
| 1 | [ex: Déplacement] | Mouvement | Oui |
| 2 | [ex: Combat] | Combat | Oui |
| 3 | | | |
| 4 | | | |

---

## Détail par mécanique

> Copier ce bloc pour CHAQUE mécanique listée ci-dessus

### Mécanique : [NOM]

**Résumé :** [En une phrase, ce que cette mécanique permet]

**Inputs joueur :**
| Input | Action | Plateforme |
|-------|--------|-----------|
| [Touche/Clic/Touch] | [Ce qui se passe] | PC / Mobile / Manette |

**Comportement :**
1. Quand le joueur fait [input] →
2. Le système vérifie [condition] →
3. Si OK → [résultat positif] →
4. Si KO → [résultat négatif / feedback]

**Règles :**
- [Règle 1 — ex: cooldown de 2 secondes entre chaque attaque]
- [Règle 2 — ex: les dégâts dépendent du niveau de l'arme]
- [Règle 3]

**Feedback :**
- Visuel : [animation, particules, changement d'état]
- Sonore : [son joué]
- UI : [texte affiché, barre qui bouge, nombre qui pop]

**Interactions avec d'autres mécaniques :**
- [Lien avec mécanique X — comment elles s'influencent]

**Évolution :**
- Niveau 1 : [version de base]
- Niveau 5 : [version améliorée]
- Niveau 10+ : [version avancée]

---

## Contrôles complets

### PC

| Touche | Action |
|--------|--------|
| WASD / ZQSD | Mouvement |
| Espace | Saut |
| Clic gauche | [Action principale] |
| Clic droit | [Action secondaire] |
| E | [Interaction] |
| Tab | [Inventaire / Menu] |
| [Autre] | |

### Mobile

| Geste | Action |
|-------|--------|
| Joystick virtuel | Mouvement |
| Bouton A | [Action] |
| Tap sur élément | [Interaction] |
| Swipe | [Action] |

### Manette

| Bouton | Action |
|--------|--------|
| Stick gauche | Mouvement |
| Stick droit | Caméra |
| A / X | [Action] |
| B / O | [Action] |
| Gâchettes | [Action] |

---

## Formules de calcul

> Toutes les formules mathématiques du jeu

| Formule | Expression | Exemple |
|---------|-----------|---------|
| Dégâts | [ex: base_dmg × weapon_mult × (1 + level×0.1)] | [Niveau 5, arme x2 = 15] |
| XP requis | [ex: 100 × level^1.5] | [Niveau 10 = 3162 XP] |
| | | |

---

## Interactions entre mécaniques (matrice)

| | Mouvement | Combat | Craft | Commerce |
|---|-----------|--------|-------|----------|
| **Mouvement** | — | | | |
| **Combat** | | — | | |
| **Craft** | | | — | |
| **Commerce** | | | | — |

---

## Questions clés

- [ ] Chaque mécanique est-elle intuitive sans tutoriel ?
- [ ] Les contrôles sont-ils confortables sur TOUTES les plateformes ?
- [ ] Les formules sont-elles équilibrées (pas de valeur cassée) ?
- [ ] Chaque mécanique a-t-elle un feedback clair ?

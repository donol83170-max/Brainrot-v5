# PRD 09 — PNJ & Ennemis

> Tous les personnages non-joueurs : alliés, marchands, ennemis, boss.

---

## PNJ alliés / neutres

> Copier ce bloc pour chaque PNJ

### PNJ : [NOM]

| | Détail |
|---|--------|
| **Rôle** | [Marchand / Guide / Donneur de quêtes / Décoration] |
| **Localisation** | [Zone — position précise] |
| **Apparence** | [Description rapide ou référence visuelle] |
| **Interaction** | [Clic → menu / dialogue / boutique] |

**Dialogues clés :**
- Première rencontre : "[texte]"
- Interaction standard : "[texte]"
- Après quête complétée : "[texte]"

**Quêtes données :**
| Quête | Objectif | Récompense |
|-------|----------|------------|
| [Nom] | [Tuer X, ramener Y] | [XP, coins, item] |

---

## Ennemis

### Tableau des ennemis

| Nom | Zone | HP | Dégâts | XP donné | Loot | Comportement |
|-----|------|----|--------|----------|------|-------------|
| [Slime] | Forêt | 50 | 5 | 10 | Coins (5) | Passif, attaque si touché |
| [Gobelin] | Forêt | 100 | 15 | 25 | Coins (10-20), Bois | Agressif, patrouille |
| [Dragon] | Volcan | 5000 | 100 | 500 | Loot table rare | Boss (voir détail) |
| | | | | | | |

### Types de comportement IA

| Comportement | Description | Utilisé par |
|-------------|-------------|-------------|
| **Passif** | N'attaque pas sauf si attaqué | [Slime, animaux] |
| **Patrouille** | Suit un chemin fixe, attaque si joueur proche | [Gardes, goblins] |
| **Agressif** | Poursuit le joueur dès qu'il le détecte | [Loups, monstres] |
| **Territorial** | Attaque si le joueur entre dans sa zone | [Boss, gardiens] |
| **Fuyant** | S'enfuit quand HP bas | [Créatures peureuses] |
| **Support** | Buff d'autres ennemis, heal | [Shamans, healers] |

### Détail IA ennemi

| Paramètre | Valeur type |
|-----------|-------------|
| Distance de détection | [Ex: 30 studs] |
| Distance d'abandon (leash) | [Ex: 100 studs — retour au spawn] |
| Vitesse de déplacement | [Ex: 16 (joueur = 16)] |
| Temps de respawn | [Ex: 30 secondes] |
| Spawn max dans une zone | [Ex: 10 ennemis simultanés] |

---

## Boss

> Copier ce bloc pour chaque boss

### Boss : [NOM]

| | Détail |
|---|--------|
| **Zone** | [Où le trouver] |
| **Condition d'accès** | [Niveau min, clé, quête préalable] |
| **Type** | [Solo / Groupe (combien ?)] |
| **HP** | [Quantité] |
| **Temps de respawn** | [Ex: 1h, quotidien, événement] |

**Phases de combat :**

| Phase | HP restant | Comportement | Attaques |
|-------|-----------|-------------|----------|
| Phase 1 | 100-70% | [Description] | [Attaque A, B] |
| Phase 2 | 70-30% | [Description — s'énerve ?] | [Attaque C + anciennes] |
| Phase 3 | 30-0% | [Description — mode rage ?] | [Attaque D ultime] |

**Attaques du boss :**

| Attaque | Dégâts | Portée | Indicateur visuel | Comment esquiver |
|---------|--------|--------|-------------------|-----------------|
| [Coup] | [50] | [Mêlée] | [Bras levé] | [Reculer] |
| [AOE] | [30] | [Zone 20 studs] | [Cercle rouge au sol] | [Sortir du cercle] |
| [Charge] | [80] | [Ligne droite] | [Flash rouge] | [Esquive latérale] |

**Table de loot boss :**

| Item | Drop rate | Garanti ? |
|------|-----------|-----------|
| [Coins x500] | 100% | Oui |
| [Arme rare du boss] | 5% | Non |
| [Cosmétique exclusif] | 1% | Non |

---

## Scaling des ennemis

| Niveau zone | HP ennemi | Dégâts | XP | Loot quality |
|-------------|----------|--------|-----|--------------|
| 1-10 | 50-200 | 5-20 | 10-50 | Commun |
| 10-25 | 200-1000 | 20-50 | 50-150 | Peu commun |
| 25-50 | 1000-5000 | 50-100 | 150-400 | Rare |
| 50+ | 5000+ | 100+ | 400+ | Épique+ |

---

## Spawn system

| | Détail |
|---|--------|
| **Type** | [Points fixes / Zones aléatoires / Vagues] |
| **Nombre max** | [Par zone, par serveur] |
| **Timer respawn** | [Fixe / Variable] |
| **Scaling avec joueurs** | [Plus de joueurs = plus d'ennemis ?] |

---

## Questions clés

- [ ] Chaque ennemi a-t-il un comportement distinct et reconnaissable ?
- [ ] Les boss ont-ils des attaques que le joueur peut apprendre à éviter ?
- [ ] La difficulté des ennemis suit-elle la courbe de progression ?
- [ ] Les PNJ sont-ils utiles et pas juste décoratifs ?
- [ ] Le respawn est-il assez rapide pour ne pas ennuyer mais pas spam ?

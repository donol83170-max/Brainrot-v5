# PRD 08 — Items & Inventaire

> Tous les objets du jeu : types, propriétés, raretés, obtention.

---

## Catégories d'items

| Catégorie | Exemples | Stackable ? | Tradable ? |
|-----------|----------|-------------|------------|
| Armes | [Épée, arc, bâton...] | Non | [Oui/Non] |
| Armures | [Casque, plastron, bottes...] | Non | [Oui/Non] |
| Consommables | [Potions, nourriture...] | Oui (x99) | [Oui/Non] |
| Matériaux | [Bois, fer, gemmes...] | Oui (x999) | [Oui/Non] |
| Outils | [Pioche, hache, canne...] | Non | [Oui/Non] |
| Cosmétiques | [Skins, trails, auras...] | Non | [Oui/Non] |
| Pets/Compagnons | [Créatures qui suivent] | Non | [Oui/Non] |
| Clés/Spéciaux | [Clés de coffre, tickets...] | Oui | Non |

---

## Système de rareté

| Rareté | Couleur | Drop rate | Puissance relative |
|--------|---------|-----------|---------------------|
| Commun | Blanc/Gris | 50-60% | x1 |
| Peu commun | Vert | 25-30% | x1.5 |
| Rare | Bleu | 10-15% | x2 |
| Épique | Violet | 3-5% | x3 |
| Légendaire | Doré/Orange | 0.5-1% | x5 |
| Mythique | Rouge/Rainbow | 0.01-0.1% | x10 |

---

## Liste des items (par catégorie)

> Copier et remplir pour chaque item du MVP

### Armes (exemple)

| Nom | Rareté | Dégâts | Vitesse | Effet spécial | Obtention |
|-----|--------|--------|---------|---------------|-----------|
| [Épée en bois] | Commun | 10 | Rapide | — | Shop (100 coins) |
| [Épée en fer] | Peu commun | 25 | Normal | — | Craft (5 fer) |
| [Lame de feu] | Rare | 50 | Normal | Brûlure 5 DPS | Boss Zone B |
| | | | | | |

---

## Inventaire

| | Détail |
|---|--------|
| **Nombre de slots** | [Ex: 20 de base, extensible à 50] |
| **Extension possible ?** | [Oui — Game Pass ou achat in-game] |
| **Tri** | [Par rareté / type / récent / nom] |
| **Recherche** | [Oui / Non] |
| **Inventaire plein ?** | [Que se passe-t-il ? Drop impossible ? Auto-suppression ?] |

---

## Équipement (si applicable)

### Slots d'équipement

```
        [Casque]
[Épaule G]  [Plastron]  [Épaule D]
       [Gants]
  [Arme]     [Bouclier]
       [Pantalon]
        [Bottes]
     [Accessoire 1]
     [Accessoire 2]
```

**Sets :** [Y a-t-il des bonus quand on porte un set complet ?]

---

## Crafting (si applicable)

| Item résultant | Ingrédients | Station de craft | Temps |
|----------------|-------------|-------------------|-------|
| [Épée en fer] | 5 fer + 2 bois | Forge | Instant |
| [Potion de soin] | 3 herbes + 1 fiole | Atelier | Instant |
| | | | |

**Échec de craft ?** [Oui/Non — Si oui, taux + conséquences]
**Recettes cachées ?** [Oui/Non — Comment les découvrir ?]

---

## Loot / Drops

### Table de loot (par source)

| Source | Items possibles | Taux | Condition |
|--------|----------------|------|-----------|
| [Ennemi basique] | Coins (5-10), Bois (1-2) | 100% / 30% | — |
| [Boss Zone A] | Épée rare, Armure rare | 5% / 3% | — |
| [Coffre commun] | Items communs/peu communs | Variable | Clé requise |
| [Coffre rare] | Items rares/épiques | Variable | Clé rare |

### Luck / Chance system (si applicable)

| | Détail |
|---|--------|
| **Stat de chance** | [Existe ? Comment l'augmenter ?] |
| **Pity system** | [Garantie d'un drop rare après X tentatives ?] |
| **Boost chance** | [Game Pass ? Potion ? Événement ?] |

---

## Pets / Compagnons (si applicable)

| Pet | Rareté | Effet | Obtention |
|-----|--------|-------|-----------|
| [Chat] | Commun | +5% coins | Quête tuto |
| [Dragon] | Légendaire | +50% dégâts | Œuf rare (0.5%) |

**Évolution ?** [Les pets évoluent-ils ?]
**Combien actifs ?** [Combien de pets équipés en même temps ?]

---

## Questions clés

- [ ] Chaque item a-t-il un usage clair et distinct ?
- [ ] La progression d'items est-elle satisfaisante (toujours un upgrade à viser) ?
- [ ] Le système de rareté crée-t-il de l'excitation sans être frustrant ?
- [ ] L'inventaire est-il facile à gérer ?
- [ ] Le loot est-il récompensant pour le temps investi ?

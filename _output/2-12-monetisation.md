# PRD 12 — Monétisation — Dodgeball Royale

> Date : 2026-02-22
> Statut : VALIDÉ ✅

---

## Philosophie de monétisation

| | Choix |
|---|-------|
| **Modèle** | Free-to-play + achats cosmétiques in-app |
| **Pay-to-win ?** | ❌ JAMAIS — tout avantage compétitif est interdit |
| **Cible de dépense par joueur payant** | 150-500 Robux au total |
| **% joueurs qui paient (estimé)** | 3-5% (typique Roblox) |

> **Règle absolue :** Un joueur F2P doit pouvoir gagner des matchs, monter de niveau, et s'amuser autant qu'un joueur payant. Les Robux achètent du style, jamais de la puissance.

---

## Game Passes (achats uniques permanents)

| Game Pass | Prix | Ce qu'il donne | Catégorie |
|-----------|------|----------------|-----------|
| **🎁 Starter Pack** | 99 R$ | 500 Or + Skin balle "Étoile" + Titre "Pro" — offre de lancement | Cosmétique + Or |
| **🪙 Double Or** | 149 R$ | x2 Or gagné à chaque match, permanent | Confort |
| **👑 Pack VIP** | 299 R$ | Badge VIP animé en lobby + Titre "VIP" + Skin balle "Diamant" exclusif + x1.25 XP | Cosmétique + Confort |
| **🏖️ VIP Server** | 50 R$/mois | Serveur privé pour jouer entre amis | Social (feature Roblox) |

### Détail des Game Passes

**Starter Pack (99 R$) :**
- Conçu pour les joueurs qui veulent démarrer avec de l'avance cosmétique
- Disponible uniquement les 30 premiers jours après le lancement (urgence)
- Meilleure valeur de tout le jeu → accélère la première adoption

**Double Or (149 R$) :**
- Ne donne aucun avantage en match — l'Or n'achète que des cosmétiques
- Réduit de moitié le temps pour débloquer les items boutique
- Idéal pour les joueurs qui veulent une collection complète plus vite

**Pack VIP (299 R$) :**
- Badge VIP visible dans le lobby = statut social visible
- x1.25 XP = progression légèrement plus rapide (pas de contenu bloqué, juste du confort)
- Le skin "Diamant" n'est disponible que via ce pass — exclusivité permanente

---

## Developer Products (achats répétables)

| Produit | Prix | Ce qu'il donne |
|---------|------|----------------|
| **💰 Sachet d'Or** | 25 R$ | +300 Or |
| **💰 Sac d'Or** | 75 R$ | +1 000 Or (+33% bonus) |
| **💰 Coffre d'Or** | 149 R$ | +2 500 Or (+66% bonus) |
| **🎰 Ticket Boutique** | 50 R$ | 1 item aléatoire parmi les items de la semaine (rare ou épique) |

### Note sur le Ticket Boutique
- L'item obtenu est **toujours au minimum Rare** (pas d'opacité — taux affiché)
- Pas de gacha pur : l'item peut être de la semaine en cours, aléatoire parmi les 5 slots
- Conforme aux règles Roblox sur les loot boxes

---

## Bonus Roblox Premium

Les joueurs avec un abonnement Roblox Premium reçoivent automatiquement :
- **+10% Or** par match (en plus du Double Or si actif)
- Badge "Premium" discret visible en lobby

> Ces bonus génèrent des revenus passifs via les Premium Payouts Roblox — plus le jeu est joué par des membres Premium, plus les revenus augmentent.

---

## Ce qui reste 100% gratuit

| Fonctionnalité | Gratuit ? |
|----------------|-----------|
| Tous les matchs (BR, Classique, Chaos) | ✅ Oui |
| Progression niveau 1-100 | ✅ Oui |
| Or gagné en jouant | ✅ Oui |
| Cosmétiques des niveaux | ✅ Oui |
| Missions quotidiennes | ✅ Oui |
| Classements | ✅ Oui |
| Chat + Social | ✅ Oui |
| Pack de bienvenue (1er match) | ✅ Oui |

---

## Projections de revenus

### Hypothèses

| Métrique | Conservateur | Optimiste |
|----------|-------------|-----------|
| DAU à 1 mois | 200 | 800 |
| % acheteurs Game Pass | 3% | 6% |
| Dépense moyenne GP | 200 R$ | 300 R$ |
| % acheteurs Dev Products | 2% | 4% |
| Dépense moyenne DP/mois | 75 R$ | 150 R$ |

### Projection mensuelle

```
─── Scénario conservateur (200 DAU) ───
Game Passes (nouveaux joueurs) : 200 × 3% × 200 R$ = 1 200 R$
Developer Products : 200 × 2% × 75 R$ = 300 R$
Premium Payouts (estimé) : ~200 R$
Total brut : ~1 700 R$
Après commission Roblox (30%) : ~1 190 R$ ≈ ~$4,2/mois

─── Scénario optimiste (800 DAU) ───
Game Passes : 800 × 6% × 300 R$ = 14 400 R$
Developer Products : 800 × 4% × 150 R$ = 4 800 R$
Premium Payouts : ~800 R$
Total brut : ~20 000 R$
Après commission Roblox (30%) : ~14 000 R$ ≈ ~$49/mois
```

> **Note :** Les revenus explosent avec la communauté. 1 000+ DAU réguliers = jeu viable.
> Taux de change DevEx : 100 000 Robux ≈ $350

---

## Boutique Robux (interface in-game)

| | Détail |
|---|--------|
| **Accès** | Bouton BOUTIQUE dans le lobby → onglet "Premium" |
| **Catégories** | Game Passes / Packs d'Or / Tickets boutique |
| **Offres limitées** | Oui — Starter Pack uniquement les 30 premiers jours |
| **Confirmation** | Popup Roblox standard (double confirmation automatique) |
| **Transparence** | Taux du Ticket Boutique affiché clairement |

---

## Éthique & Limites

### Ce qu'on NE FAIT PAS ❌

| Pratique interdite | Pourquoi |
|-------------------|---------|
| Stats de combat achetables | Pay-to-win = mort de la compétition |
| Loot boxes opaques | Taux masqués = malhonnêteté + risques légaux |
| Contenu de base verrouillé | Le jeu doit être complet en F2P |
| Countdown de pression abusifs | Public 7-16 ans — responsabilité forte |
| Achats obligatoires pour progresser | Progression 100% réalisable en F2P |

### Ce qu'on FAIT ✅

| Pratique éthique | Pourquoi |
|-----------------|---------|
| Cosmétiques purs | Revenus sans impact gameplay |
| Or gratuit en jouant | Les F2P peuvent acheter des cosmétiques |
| Taux transparents (Ticket Boutique) | Confiance des joueurs |
| Prix adaptés au public jeune | 25-299 R$ = accessible avec l'argent de poche |
| Aucune pression psychologique forcée | Boutique accessible, pas imposée |

---

## Questions clés validées

- [x] Un joueur F2P s'amuse-t-il autant ? → Oui : 100% du contenu accessible sans payer
- [x] Les Game Passes sont-ils tentants mais pas nécessaires ? → Oui : confort + cosmétique exclusif
- [x] Les prix sont-ils adaptés au public ? → Oui : 25-299 R$ = gamme accessible
- [x] La monétisation est-elle éthique ? → Oui : pas de P2W, taux transparents, pas de pression
- [x] Les projections sont-elles réalistes ? → Oui : scénario conservateur très atteignable

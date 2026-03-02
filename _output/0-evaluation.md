# Fiche d'évaluation — Dodgeball Royale

> Date : 2026-02-22
> Auteur(s) de l'idée : [Toi]

---

## Pitch (1-2 phrases)

Un battle royale en équipes basé sur la balle au prisonnier : lance, esquive, élimine. La zone se rétrécit à chaque vague d'éliminations — les derniers survivants remportent la partie.

## Genre & Références

- **Genre principal :** Combat / Battle Royale
- **Jeux de référence :** BedWars (Roblox), Island Royale (Roblox), Knockout Ball (concept physique)
- **Twist :** Pas d'arme, pas de build — juste une balle. Accessible, instantané, intense.

---

## Scoring

### FUN (/25)

| Critère | Score | Justification |
|---------|-------|---------------|
| Core loop addictif | 8/8 | Lancer/esquiver/libérer ses prisonniers = 3 objectifs simultanés, tension permanente |
| Rejouabilité | 5/6 | Chaque match différent selon équipes et zone. Manque de variété de cartes/modes pour l'instant |
| Originalité | 5/5 | Balle au prisonnier BR avec système prison = concept unique sur Roblox |
| Moment "wow" | 3/3 | Libérer un prisonnier au dernier moment = moment épique garanti |
| Flow/Rythme | 3/3 | Les prisonniers forcent l'attaque — anti-camping natif, rythme naturellement soutenu |
| **TOTAL FUN** | **24/25** | |

### MARCHÉ (/25)

| Critère | Score | Justification |
|---------|-------|---------------|
| Popularité du genre | 6/7 | Battle royale toujours fort sur Roblox (BedWars, The Survival Game) |
| Concurrence | 5/6 | Pas de concurrent direct sur ce concept exact |
| Recherche/Découverte | 3/5 | Tags "battle royale" + "dodgeball" = discoverability correcte mais niche |
| Public cible clair | 3/4 | Ados 10-16 ans qui connaissent la balle au prisonnier = cible naturelle |
| Timing | 2/3 | Bon timing — la mode "sport + BR" n'est pas encore saturée sur Roblox |
| **TOTAL MARCHÉ** | **19/25** | |

**Top concurrents :**

| Jeu | Genre proche | Force | Faiblesse |
|-----|-------------|-------|-----------|
| BedWars | BR équipes | Énorme base joueurs | Pas de mécanique balle |
| Island Royale | BR solo | BR classique | Pas original |
| Dodgeball! | Balle au prisonnier | Mécanique prouvée | Pas de BR, vieilli |

### FAISABILITÉ (/25)

| Critère | Score | Justification |
|---------|-------|---------------|
| Complexité technique | 5/8 | Physique du lancer (vélocité, hitbox), zone dynamique, système prison = modéré-complexe |
| Assets nécessaires | 5/6 | Peu d'assets : arène simple, balle(s), personnages Roblox de base |
| Taille équipe | 4/5 | Faisable en solo avec du temps |
| Compétences requises | 2/3 | Luau intermédiaire + Rojo (setup géré par Claude) |
| Temps au MVP | 2/3 | Rojo configuré dès le départ = workflow propre qui accélère la suite |
| **TOTAL FAISABILITÉ** | **18/25** | |

**Systèmes techniques identifiés :**
1. Système de lancer/attraper (physique balle, vélocité, détection touché)
2. Système d'équipes + matchmaking (min 2v2)
3. Zone dynamique (shrink déclenché par éliminations, pas par timer)
4. Gestion des éliminations (joueur touché = éliminé, pas de résurrection ?)
5. DataStore joueur (stats, victoires, K/D)
6. Workflow Rojo (structure fichiers, Wally pour packages)

### MONÉTISATION (/25)

| Critère | Score | Justification |
|---------|-------|---------------|
| Game Passes naturels | 6/8 | Skins de balle, effets de traînée, cosmétiques perso = naturels et non pay-to-win |
| Developer Products | 4/6 | XP boost, cosmétiques temporaires = possible mais moins évident |
| Retention → Monétisation | 3/5 | Nécessite une base solide de joueurs avant de bien monétiser |
| Prix acceptable | 2/3 | Cosmétiques à 100-400 Robux = prix standards acceptables |
| Éthique | 3/3 | 100% cosmétique = aucun avantage compétitif |
| **TOTAL MONÉTISATION** | **18/25** | |

**Idées de Game Passes :**
- [ ] Skin "Balle de feu" avec effet traînée — 150 Robux
- [ ] Pack cosmétique personnage (chapeau, aura) — 200 Robux
- [ ] Accès mode "Ranked" — 100 Robux

**Idées de Developer Products :**
- [ ] Boost XP x2 (1 heure) — 50 Robux
- [ ] Emote exclusive — 75 Robux

---

## SCORE TOTAL : 79/100

## Verdict : ✅ GO — on passe en Phase 1

### Points forts
- Concept unique sur Roblox : balle au prisonnier + BR + système de prison
- Anti-camping natif : les prisonniers forcent l'attaque permanente
- Mécanique universellement connue = prise en main en 10 secondes
- Bots pour combler les équipes = jouable dès le lancement
- Monétisation 100% éthique (cosmétiques only)
- Workflow Rojo = code propre et maintenable dès le départ

### Points faibles (à surveiller)
- Physique du lancer (hitbox, vélocité) = point technique critique à bien concevoir
- IA des bots à calibrer pour ne pas frustrer (ni trop forts, ni inutiles)

### Conditions pour passer en Phase 1
✅ Toutes les conditions sont remplies — GO !

---

## Notes libres

- Le concept "balle au prisonnier BR" est potentiellement viral — très tweetable/TikTokable
- Penser à une arène avec obstacles (caisses, murs bas) pour enrichir le gameplay d'esquive
- Les équipes pourraient avoir des rôles (lanceur, défenseur) pour plus de profondeur
- Score de 74 = à 1 point du GO direct — l'idée est solide, quelques précisions suffisent

# Vision du Jeu — Dodgeball Royale

> Date : 2026-02-22
> Statut : VALIDÉ ✅

---

## Elevator Pitch

> "C'est un jeu où tu lances, esquives et libères tes coéquipiers pour être la dernière équipe debout — sur un terrain qui rétrécit à chaque élimination."

---

## Core Loop (en une phrase)

> **Lancer** → **Éliminer ou être éliminé** → **Se battre depuis la prison** → **Se libérer** → recommencer

---

## Les 3 boucles de gameplay

### Boucle Micro (30 secondes - 2 minutes)
Se positionner sur le terrain → Lancer/attraper la balle → Toucher un adversaire ou être touché → Si prisonnier : spawner en zone prison avec une balle et tirer sur les adversaires depuis derrière → Toucher quelqu'un → Retourner sur le terrain

### Boucle Session (1 match = 3-5 minutes)
Rejoindre un match → Survivre le plus longtemps possible → La zone rétrécit au fil des éliminations → Gagner avec son équipe (ou se faire éliminer) → Voir ses stats (kills, libérations, précision) → Rejouer immédiatement

### Boucle Méta (jours - semaines)
Enchaîner les matchs → Gagner de l'XP → Monter en niveau → Débloquer des cosmétiques (balles, effets, skins) → Grimper dans le classement → Revenir pour les événements saisonniers

---

## Genre & Références

| | Détail |
|---|--------|
| **Genre principal** | Combat / Sport |
| **Sous-genre** | Battle Royale en équipes |
| **Référence 1** | BedWars — On prend : le format BR en équipes. On change : pas de construction ni d'armes, juste une balle |
| **Référence 2** | Dodgeball! (Roblox) — On prend : la mécanique de base balle au prisonnier. On change : zone dynamique, prison active, format BR |
| **Référence 3** | Island Royale — On prend : le rythme et la tension du BR. On change : pas d'armes, gameplay sport universel |

---

## Public cible

| | Détail |
|---|--------|
| **Tranche d'âge** | 7-16 ans |
| **Type de joueur** | Casual à Mid-core |
| **Profil** | Joueurs qui veulent du fun immédiat, des parties courtes et intenses, avec des potes ou en solo |
| **Temps de session visé** | 15-20 min (= 3-5 matchs de 3-5 min) |
| **Solo / Multi / Les deux** | Multi avant tout, bots pour compléter les équipes |

---

## USP — Unique Selling Point

> Pourquoi un joueur choisirait Dodgeball Royale plutôt qu'un autre BR ?

1. **Concept unique sur Roblox** — Balle au prisonnier + Battle Royale = personne ne l'a fait
2. **Zéro temps mort** — Même éliminé, tu joues encore depuis la prison avec ta balle
3. **Anti-camping natif** — La zone rétrécit, les prisonniers attaquent par derrière : impossible de se cacher

**Le hook en 30 secondes :** Tu te fais toucher, tu spawn en prison avec une balle dans les mains — tu peux encore retourner la situation. Aucun joueur n'est jamais spectateur.

---

## Les 3 Modes de jeu

| Mode | Description | Durée |
|------|-------------|-------|
| **Battle Royale** *(mode phare)* | Zone rétrécissante déclenchée par les éliminations, dernière équipe debout gagne | 4-5 min |
| **Classique** | 2 équipes face-à-face, éliminer tous les adversaires, terrain fixe | 3-4 min |
| **Chaos** | Free-for-all, chacun pour soi, le dernier survivant gagne | 2-3 min |

---

## Mécanique Prisonniers (résumé)

- Joueur touché → spawn en **zone prison** (derrière l'équipe adverse) avec une balle
- Peut tirer à tout moment depuis la prison
- Touche un adversaire actif → **libéré**, retour sur le terrain
- Rate → balle disponible à nouveau après un court cooldown
- Les prisonniers sont **intouchables** en zone prison
- La zone prison est positionnée **derrière la ligne ennemie** → pression double sur les adversaires

---

## Ambiance & Mood

| | Choix |
|---|-------|
| **Ton** | Fun, festif, compétitif mais accessible |
| **Palette couleurs** | Vive et saturée — couleurs d'équipes franches (rouge vs bleu, etc.) |
| **Style 3D** | Cartoon coloré, style Roblox classique enjolivé |
| **Musique** | Pop/chiptune énergique — upbeat, rythme rapide |
| **Ambiance générale** | Un gymnase coloré et festif qui se transforme en arène de survie. Accessible en 10 secondes, intense jusqu'à la dernière seconde. |

---

## Scope

### MVP (Version 1 — jouable au lancement)

- [x] 1 map unique (arène gymnase avec obstacles bas)
- [x] Mode Battle Royale uniquement
- [x] Format 4v4 (bots pour compléter les équipes)
- [x] Mécanique balle/prison complète et fonctionnelle
- [x] Zone rétrécissante déclenchée par les éliminations
- [x] Matchmaking basique
- [x] Écran de stats fin de partie (kills, libérations, précision)
- [x] 2-3 cosmétiques basiques (skins de balle) pour tester la monétisation

### Version Complète (post-MVP)

- [ ] Tout le MVP +
- [ ] Mode Classique
- [ ] Mode Chaos
- [ ] 3 maps supplémentaires
- [ ] Système de niveaux et XP complet
- [ ] Classement global (leaderboard)
- [ ] Cosmétiques complets (balles avec effets, skins personnage, traînées)
- [ ] Système d'événements saisonniers

### Post-Launch (idées futures)

- [ ] Mode Ranked avec système de divisions
- [ ] Tournois en jeu
- [ ] Modes limités (événements spéciaux — balle géante, gravité réduite...)
- [ ] Power-ups optionnels sur certains modes

---

## Risques identifiés

| Risque | Impact | Mitigation |
|--------|--------|------------|
| Physique du lancer (hitbox, vélocité, lag) | Haut | Validation serveur stricte, tests de latence dès le proto |
| IA des bots mal calibrée (trop forts ou inutiles) | Moyen | Bots progressifs selon le nombre de joueurs humains |
| Rétention D7 faible si contenu insuffisant | Moyen | MVP avec cosmétiques + événement de lancement prévu |
| Matchmaking vide au lancement | Moyen | Bots systématiques + serveurs régionaux dès le départ |

---

## Validation

- [x] Le pitch est clair et donne envie
- [x] Le core loop est identifié et semble fun
- [x] Le public cible est précis (7-16 ans, sessions 3-5 min)
- [x] L'USP est convaincant (unique sur Roblox)
- [x] Le scope MVP est réaliste
- [x] L'ambiance est cohérente avec le gameplay

**Validé — Date : 2026-02-22**

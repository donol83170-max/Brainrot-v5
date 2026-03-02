# PRD 01 — Core Loop — Dodgeball Royale

> Date : 2026-02-22
> Statut : VALIDÉ ✅

---

## La boucle principale

### En une phrase
> **Lancer** → **Éliminer ou être éliminé** → **Se battre depuis la prison** → **Se libérer** → **Gagner de l'XP** → **Débloquer des cosmétiques** → recommencer

### Détail minute par minute (match de 3-5 min)

| Temps | Ce que fait le joueur | Ce qu'il ressent |
|-------|----------------------|------------------|
| 0:00 - 0:20 | Spawn sur le terrain, se positionne, récupère une balle | Excitation, adrénaline du départ |
| 0:20 - 1:00 | Premiers échanges — lance, esquive, tente de toucher | Concentration, fun immédiat |
| 1:00 - 2:00 | Zone commence à rétrécir — les prisonniers tirent depuis derrière | Pression monte, décisions rapides |
| 2:00 - 3:30 | Zone très réduite — affrontements rapprochés, prisonniers ultra-actifs | Tension maximale, tout peut basculer |
| 3:30 - 5:00 | Derniers survivants — zone minimale, affrontement final | Adrénaline pure, sentiment épique |
| Fin de match | Écran de stats + XP gagné + animation de niveau si progression | Satisfaction ou envie de revanche |

### Boucle session (une session complète)

1. Le joueur se connecte → **arrive dans le lobby commun** (voit les autres joueurs et leurs cosmétiques)
2. Il clique "Jouer" → mis en file d'attente (bots si pas assez de joueurs)
3. Match de **3 à 5 minutes** — lance, esquive, libère, survit
4. Fin de match → **écran de stats** (kills, libérations, précision, position finale) + XP gagné
5. Si montée de niveau → **animation de déverrouillage cosmétique**
6. Retour au lobby → il rejoue immédiatement ("encore une !")
7. Il se déconnecte satisfait parce qu'**il a progressé** et que chaque match a été intense de la 1ère à la dernière seconde

### Boucle méta (progression long terme)

- **Jour 1 :** Première partie, découverte des mécaniques en 30 secondes, niveau 1→3, comprend l'intérêt de libérer ses coéquipiers
- **Jour 3 :** Maîtrise les angles de tir et la zone prison, niveau 6-10, a peut-être acheté son premier cosmétique en voyant ceux des autres dans le lobby
- **Semaine 1 :** Niveau 15-20, stratégie d'équipe consciente, visible dans le classement, connaît bien la map
- **Mois 1 :** Joueur régulier, niveau 30+, collection de cosmétiques débutée, joue les 3 modes, attend les events
- **Mois 3+ :** Classement compétitif, collection de cosmétiques avancée, joue pour les événements saisonniers et le mode Ranked

---

## Piliers de gameplay

> Les 4 verbes qui définissent Dodgeball Royale

| Pilier | Description | Importance |
|--------|-------------|------------|
| **Lancer** | Viser et envoyer la balle pour éliminer un adversaire — le geste central du jeu | Principal |
| **Esquiver** | Se déplacer pour éviter les balles — la survie dépend du mouvement | Principal |
| **Libérer** | Se battre depuis la prison pour revenir sur le terrain — zéro temps mort | Principal |
| **Survivre** | Gérer la zone, les positions, les priorités — la dimension stratégique | Secondaire |

---

## Rythme & Tension

### Courbe d'intensité d'une session typique

```
Intensité
  ▲
  │                              ╱╲
  │                         ╱╲ ╱  ╲
  │              ╱╲    ╱╲  ╱  ╳    ╲
  │         ╱╲  ╱  ╲  ╱  ╲╱         ╲
  │    ╱╲  ╱  ╲╱    ╲╱                ╲
  │───╱──╲╱                             ╲___
  └────────────────────────────────────────> Temps
     Spawn  Phase    Zone      Finale   Fin
           ouverte  rétrécit
```

- **Pics d'intensité :** Zone qui rétrécit → affrontements forcés / Libération d'un coéquipier au dernier moment / Dernier survivant face à face
- **Moments de calme :** Premières secondes du match (repositionnement) / Temps en prison avant de tirer
- **Climax de session :** L'affrontement final dans la zone minimale — tension maximale, tout le monde se voit

---

## Feedback loops (boucles de rétroaction)

### Feedback immédiat (chaque action)
- **Visuel :** Flash rouge sur l'adversaire touché, effet d'impact sur la balle, animation de prison (spawn prisonnier), animation de libération (retour sur le terrain)
- **Sonore :** Son d'impact satisfaisant quand la balle touche, son de libération distinct, son de zone qui rétrécit
- **Numérique :** +XP affiché à l'écran pour chaque kill (+15 XP) et chaque libération (+10 XP), compteur de kills en temps réel

### Feedback court terme (chaque objectif atteint)
- Notification "Prisonnier libéré !" avec nom du coéquipier
- Notification "Équipe éliminée !" quand une équipe est hors jeu
- Alerte visuelle quand la zone va rétrécir (5 secondes avant)
- Écran de stats complet en fin de match (kills, libérations, précision, temps survécu)

### Feedback long terme (progression globale)
- Barre d'XP et niveau visible dans le lobby et en fin de match
- Animation de montée de niveau avec cosmétique débloqué
- Classement global visible dans le lobby
- Historique des stats (victoires, K/D, meilleure série)

---

## Gains d'XP

| Action | XP gagné |
|--------|----------|
| Participation (match terminé) | +20 XP |
| Kill (adversaire touché et éliminé) | +15 XP |
| Libération (toucher un adversaire depuis la prison) | +10 XP |
| Victoire (équipe gagnante) | +50 XP |
| MVP du match (meilleur score individuel) | +25 XP bonus |

---

## Questions clés validées

- [x] Est-ce que la boucle est fun dès les 30 premières secondes ? → Oui : premier échange dans les 20 premières secondes
- [x] Est-ce que le joueur sait toujours quoi faire ensuite ? → Oui : balle en main = lance, pas de balle = esquive, prison = tire depuis derrière
- [x] Est-ce que la progression donne envie de continuer ? → Oui : XP à chaque action + cosmétiques visibles dans le lobby
- [x] Est-ce que le rythme alterne bien entre effort et récompense ? → Oui : tension progressive + stats satisfaisantes en fin de match
- [x] Est-ce que la session a une fin naturelle ? → Oui : 3-5 min max, fin de match claire, retour lobby immédiat

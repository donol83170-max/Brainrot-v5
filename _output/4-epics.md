# Plan de Production — Dodgeball Royale

> Date : 2026-02-22
> Statut : VALIDÉ ✅

---

## Epics (grands blocs de travail)

| # | Epic | PRD source | Priorité MVP | Statut |
|---|------|-----------|-------------|--------|
| E1 | Infrastructure de base | Architecture | 🔴 CRITIQUE | [ ] |
| E2 | Map & Arène | PRD 03 | 🔴 CRITIQUE | [ ] |
| E3 | Système de Match | PRD 01, 07 | 🔴 CRITIQUE | [ ] |
| E4 | Système Balle | PRD 02 | 🔴 CRITIQUE | [ ] |
| E5 | Système Prison | PRD 02 | 🔴 CRITIQUE | [ ] |
| E6 | Zone Dynamique | PRD 02, 03 | 🔴 CRITIQUE | [ ] |
| E7 | Bots IA | PRD 09 | 🟠 HAUTE | [ ] |
| E8 | Progression & Missions | PRD 04 | 🟠 HAUTE | [ ] |
| E9 | Cosmétiques & Inventaire | PRD 08 | 🟠 HAUTE | [ ] |
| E10 | Économie & Boutique | PRD 05, 12 | 🟠 HAUTE | [ ] |
| E11 | UI & HUD | PRD 06 | 🟠 HAUTE | [ ] |
| E12 | Audio & VFX | PRD 10 | 🟡 MOYENNE | [ ] |
| E13 | Onboarding | PRD 11 | 🟠 HAUTE | [ ] |
| E14 | Social & Classements | PRD 07 | 🟡 MOYENNE | [ ] |
| E15 | Polish & Lancement | Tous | 🟠 HAUTE | [ ] |

---

## Scope MVP

| Epic | Dans le MVP ? | Notes |
|------|--------------|-------|
| E1 Infrastructure | ✅ Oui (complet) | Base de tout |
| E2 Map | ✅ Oui (1 map) | Sunset Beach uniquement |
| E3 Match | ✅ Oui (mode BR uniquement) | Classique + Chaos post-MVP |
| E4 Balle | ✅ Oui (complet) | Mécanique centrale |
| E5 Prison | ✅ Oui (complet) | Mécanique centrale |
| E6 Zone | ✅ Oui (complet) | Mécanique centrale |
| E7 Bots | ✅ Oui (basique) | 3 niveaux de difficulté |
| E8 Progression | ✅ Oui (complet) | XP + missions quotidiennes |
| E9 Cosmétiques | ✅ Partiel (5-8 items) | Système complet, peu d'items |
| E10 Boutique | ✅ Partiel (boutique fixe) | Rotation hebdo post-MVP |
| E11 UI/HUD | ✅ Oui (essentiel) | Toutes les UI critiques |
| E12 Audio/VFX | ✅ Partiel (sons basiques) | Musique + SFX essentiels |
| E13 Onboarding | ✅ Oui (complet) | Critique pour la rétention |
| E14 Social | 🔶 Partiel (invitations amis) | Classements basiques |
| E15 Polish | ✅ Oui (performance + bugs) | Avant lancement |

---

## Découpage en Stories

---

### E1 — Infrastructure de base

| # | Story | Critère "c'est fait" | Estim. | Dépendance |
|---|-------|---------------------|--------|------------|
| E1-S1 | Créer la structure de dossiers dans Roblox Studio | Tous les dossiers de l'archi existent | 30 min | — |
| E1-S2 | Créer le module GameConfig | Toutes les constantes du jeu dans un seul fichier (vitesses, timers, XP, prix...) | 1h | E1-S1 |
| E1-S3 | Créer et organiser tous les RemoteEvents | 21 events créés dans ReplicatedStorage/Events | 1h | E1-S1 |
| E1-S4 | Implémenter PlayerDataManager — chargement | Les données d'un joueur se chargent à la connexion | 2h | E1-S1 |
| E1-S5 | Implémenter PlayerDataManager — sauvegarde | Données sauvegardées à la déconnexion + toutes les 5 min | 2h | E1-S4 |
| E1-S6 | Implémenter la migration de schéma | Si version du data < version actuelle, migration sans perte | 1h | E1-S5 |
| E1-S7 | Mettre en place le système de logging debug | Fonction Log() qui affiche fichier:ligne + niveau (INFO/WARN/ERROR) | 30 min | — |

**Total E1 : ~8h**

---

### E2 — Map & Arène

| # | Story | Critère "c'est fait" | Estim. | Dépendance |
|---|-------|---------------------|--------|------------|
| E2-S1 | Construire le lobby (boardwalk de base) | Zone de lobby jouable avec spawn, ambiance plage visible | 2h | — |
| E2-S2 | Construire l'arène Sunset Beach (terrain + sable) | Terrain sableux, dimensions correctes pour 4v4 | 2h | — |
| E2-S3 | Placer les obstacles (2 glacières + château de sable) | 3 obstacles positionnés, bonne taille pour se cacher | 1h | E2-S2 |
| E2-S4 | Créer les zones prison (A et B) | Deux zones distinctes visuellement avec drapeaux | 1h | E2-S2 |
| E2-S5 | Placer les spawn points (équipes + prison) | 4 spawns par équipe, 4 spawns par prison | 30 min | E2-S4 |
| E2-S6 | Ajouter la déco (palmiers, parasols hors terrain) | Ambiance tropicale visible sans impacter le gameplay | 1h | E2-S2 |
| E2-S7 | Configurer l'éclairage Future Lighting | Éclairage chaud, soleil de plage, ombres douces | 1h | E2-S2 |

**Total E2 : ~8,5h**

---

### E3 — Système de Match

| # | Story | Critère "c'est fait" | Estim. | Dépendance |
|---|-------|---------------------|--------|------------|
| E3-S1 | Implémenter GameStateManager (états lobby/match) | Le jeu peut passer de LOBBY → COUNTDOWN → MATCH → END → LOBBY | 2h | E1-S3 |
| E3-S2 | Implémenter la file d'attente | Les joueurs peuvent rejoindre/quitter la file, elle compte les joueurs | 1h | E3-S1 |
| E3-S3 | Implémenter l'assignation d'équipes | Les joueurs sont répartis en 2 équipes équilibrées à chaque match | 1h | E3-S2 |
| E3-S4 | Implémenter le countdown (5s) + téléportation | Les joueurs sont téléportés aux spawns après le countdown | 1h | E3-S3 |
| E3-S5 | Implémenter le timer de match | Timer de 5 min affiché, fin de match si timer = 0 | 1h | E3-S1 |
| E3-S6 | Implémenter la logique de victoire (condition de fin) | Match se termine quand toute une équipe est en prison sans possibilité | 2h | E3-S1, E5 |
| E3-S7 | Implémenter l'écran de fin de match + retour lobby | Stats calculées, joueurs renvoyés au lobby après 10s | 1h | E3-S6 |

**Total E3 : ~9h**

---

### E4 — Système Balle

| # | Story | Critère "c'est fait" | Estim. | Dépendance |
|---|-------|---------------------|--------|------------|
| E4-S1 | Créer la balle physique (objet Roblox) | Balle qui existe dans le workspace, bonne taille | 30 min | E2-S2 |
| E4-S2 | Implémenter le lancer (InputController + RemoteEvent) | Clic gauche → balle part dans la direction de la souris | 2h | E1-S3, E4-S1 |
| E4-S3 | Validation serveur du lancer | Serveur vérifie joueur = a une balle, position cohérente avant d'exécuter | 1h | E4-S2 |
| E4-S4 | Implémenter la détection de collision balle-joueur | Balle touche un joueur → événement déclenché | 2h | E4-S2 |
| E4-S5 | Implémenter le prompt ATTRAPE (client) | Prompt apparaît 0,5s quand balle en approche | 1h | E4-S4 |
| E4-S6 | Implémenter la validation du catch (serveur) | Serveur valide la fenêtre de timing, résultat cohérent | 2h | E4-S5 |
| E4-S7 | Implémenter la récupération de balle au sol | Balle non attrapée reste au sol X secondes puis réapparaît | 1h | E4-S2 |
| E4-S8 | Feedback visuel du lancer/catch/impact (client) | Sons + effets de base pour chaque action | 1h | E4-S2, E4-S6 |

**Total E4 : ~10,5h**

---

### E5 — Système Prison

| # | Story | Critère "c'est fait" | Estim. | Dépendance |
|---|-------|---------------------|--------|------------|
| E5-S1 | Implémenter l'élimination (joueur touché → prison) | Joueur touché est téléporté en zone prison adverse | 1h | E4-S4, E3-S4 |
| E5-S2 | Spawn balle en prison pour le prisonnier | Prisonnier reçoit automatiquement une balle à son arrivée en prison | 1h | E5-S1 |
| E5-S3 | Implémenter le tir depuis la prison | Prisonnier peut lancer sa balle vers le terrain principal | 1h | E5-S2, E4-S2 |
| E5-S4 | Implémenter la libération (tir touche adversaire actif) | Prisonnier libéré et téléporté sur le terrain si son tir touche | 2h | E5-S3 |
| E5-S5 | Cooldown balle en prison (3s après raté) | Après un raté, 3s avant qu'une nouvelle balle apparaisse | 30 min | E5-S3 |
| E5-S6 | Rendre les prisonniers intouchables | Les balles passent à travers les joueurs en prison | 1h | E5-S1 |
| E5-S7 | Feedback visuel prison (teinte d'écran + notifications) | Écran légèrement teinté en prison, message "Lance pour revenir !" | 1h | E5-S1 |

**Total E5 : ~7,5h**

---

### E6 — Zone Dynamique

| # | Story | Critère "c'est fait" | Estim. | Dépendance |
|---|-------|---------------------|--------|------------|
| E6-S1 | Créer le plan d'eau (marée) et la zone boundary | Plan d'eau invisible au départ, boundary visible | 1h | E2-S2 |
| E6-S2 | Implémenter le compteur d'éliminations | Chaque élimination incrémente un compteur, déclenche shrink tous les 2 | 1h | E5-S1 |
| E6-S3 | Implémenter l'alerte pré-rétrécissement (5s) | Son + flash bords d'écran 5s avant chaque vague | 1h | E6-S2 |
| E6-S4 | Implémenter l'animation marée montante (Tween) | Plan d'eau avance progressivement sur le sable en 3s | 1h | E6-S1 |
| E6-S5 | Implémenter la zone boundary (mur invisible mobile) | Joueurs ne peuvent pas aller au-delà de la zone active | 2h | E6-S4 |
| E6-S6 | Implémenter l'élimination hors zone (3s de grâce) | Joueur hors zone a 3s pour rentrer, sinon éliminé | 1h | E6-S5 |
| E6-S7 | Implémenter la balle bonus (1 min restante) | Balle bonus spawn dans chaque camp à 1 min du chrono | 1h | E3-S5, E4-S1 |

**Total E6 : ~8h**

---

### E7 — Bots IA

| # | Story | Critère "c'est fait" | Estim. | Dépendance |
|---|-------|---------------------|--------|------------|
| E7-S1 | Créer la structure d'un bot (personnage + data) | Bot spawn comme un joueur normal, a un nom aléatoire | 1h | E3-S3 |
| E7-S2 | IA mouvement basique (vers la balle) | Bot se déplace vers la balle la plus proche | 2h | E7-S1 |
| E7-S3 | IA tir (viser + lancer avec précision variable) | Bot tire sur le joueur le plus proche avec délai configurable | 2h | E7-S2 |
| E7-S4 | IA esquive (réaction aux balles entrantes) | Bot esquive les balles avec délai selon difficulté | 2h | E7-S3 |
| E7-S5 | IA prison (tir depuis la prison après délai) | Bot en prison attend 1-2s puis tire depuis la prison | 1h | E7-S3, E5-S3 |
| E7-S6 | Difficulté adaptative (3 niveaux) | Précision + délai varient selon le niveau de difficulté | 1h | E7-S3 |
| E7-S7 | Règles anti-frustration | Bots Facile en fin de match, pas 2 catches consécutifs | 1h | E7-S4 |
| E7-S8 | Remplissage automatique avec bots | Si file insuffisante après 30s, bots ajoutés pour compléter | 1h | E7-S1, E3-S2 |

**Total E7 : ~11h**

---

### E8 — Progression & Missions

| # | Story | Critère "c'est fait" | Estim. | Dépendance |
|---|-------|---------------------|--------|------------|
| E8-S1 | Implémenter le gain d'XP (toutes sources) | XP attribué pour kills (+15), libérations (+10), victoire (+50), participation (+20) | 1h | E1-S4, E3-S7 |
| E8-S2 | Implémenter le level up (formule + déverrouillage) | Joueur monte de niveau quand XP atteint le seuil, notification | 2h | E8-S1 |
| E8-S3 | Implémenter le gain d'Or | Or attribué selon les mêmes actions que l'XP | 1h | E1-S4 |
| E8-S4 | Implémenter les missions quotidiennes — structure | Pool de missions chargé depuis MissionsConfig, reset à minuit | 2h | E1-S4 |
| E8-S5 | Implémenter le suivi de progression des missions | Compteurs mis à jour en temps réel selon les actions en match | 1h | E8-S4, E8-S1 |
| E8-S6 | Implémenter la réclamation de missions (claim) | Joueur clique "Réclamer" → Or + XP crédités, mission marquée | 1h | E8-S5 |
| E8-S7 | Implémenter le login bonus (7 jours) | Bonus Or crédité à la connexion selon streak, reset si raté | 1h | E1-S4 |
| E8-S8 | Implémenter le bonus XP amis (+10%) | Si un ami dans l'équipe, XP × 1.1 pour les deux | 1h | E8-S1 |

**Total E8 : ~10h**

---

### E9 — Cosmétiques & Inventaire

| # | Story | Critère "c'est fait" | Estim. | Dépendance |
|---|-------|---------------------|--------|------------|
| E9-S1 | Créer ItemsConfig (liste complète des cosmétiques) | Tous les items documentés (id, nom, rareté, prix, source) | 1h | — |
| E9-S2 | Implémenter l'attribution de cosmétiques (par niveau) | Cosmétique ajouté à l'inventaire du joueur au bon niveau | 1h | E8-S2, E9-S1 |
| E9-S3 | Implémenter l'équipement d'un cosmétique | Joueur change son skin de balle → sauvegardé dans equipped | 1h | E1-S4, E9-S1 |
| E9-S4 | Appliquer le skin de balle en jeu | La balle affiche le skin équipé du joueur qui l'a lancée | 2h | E9-S3, E4-S2 |
| E9-S5 | Appliquer l'effet traînée en jeu | Traînée visible derrière la balle lors du vol | 1h | E9-S4 |
| E9-S6 | Afficher le titre sous le pseudo (lobby + match) | BillboardGui avec titre équipé visible de tous | 1h | E9-S3 |
| E9-S7 | UI Inventaire / Cosmetic Locker | Écran avec 6 slots équipables + aperçu des items possédés | 3h | E9-S3, E11 |

**Total E9 : ~10h**

---

### E10 — Économie & Boutique

| # | Story | Critère "c'est fait" | Estim. | Dépendance |
|---|-------|---------------------|--------|------------|
| E10-S1 | Implémenter l'achat avec Or (boutique fixe) | Joueur achète un item → Or débité, item ajouté à l'inventaire | 2h | E1-S4, E9-S1 |
| E10-S2 | Implémenter la boutique fixe UI | Écran boutique avec items permanents, prix, bouton acheter | 2h | E10-S1, E11 |
| E10-S3 | Implémenter les Game Passes (MarketplaceService) | Starter Pack, Double Or, VIP Pack détectés et crédités | 2h | E1-S4 |
| E10-S4 | Implémenter les Developer Products (packs d'Or) | Achat Robux → Or crédité au joueur | 1h | E10-S3 |
| E10-S5 | Implémenter le multiplicateur Double Or (Game Pass) | Si Game Pass actif, Or × 2 à chaque gain | 1h | E10-S3, E8-S3 |
| E10-S6 | Implémenter le bonus VIP Pack (× 1.25 XP) | Si Game Pass VIP actif, XP × 1.25 | 30 min | E10-S3, E8-S1 |

**Total E10 : ~8,5h**

---

### E11 — UI & HUD

| # | Story | Critère "c'est fait" | Estim. | Dépendance |
|---|-------|---------------------|--------|------------|
| E11-S1 | HUD en jeu — scores équipes + timer | Scores et timer visibles et mis à jour en temps réel | 2h | E3-S5 |
| E11-S2 | HUD en jeu — indicateur balle + alerte zone | "BALLE ✅/❌" + alerte zone visible | 1h | E4-S2, E6-S3 |
| E11-S3 | HUD en jeu — mini-map zone | Mini-map bas gauche avec la zone actuelle | 1h | E6-S4 |
| E11-S4 | Écran fin de match (stats + XP + Or) | Affichage kills, libérations, XP gagné, Or gagné | 2h | E3-S7, E8-S1 |
| E11-S5 | UI Lobby principal (boutons + profil + monnaie) | Lobby fonctionnel avec tous les boutons de navigation | 2h | E1-S3 |
| E11-S6 | UI File d'attente (joueurs trouvés + annuler) | Barre de progression + compteur joueurs trouvés | 1h | E3-S2 |
| E11-S7 | UI Missions quotidiennes | Liste des 3 missions + progression + bouton réclamer | 2h | E8-S5 |
| E11-S8 | Système de notifications (toasts) | Notifications toasts pour kills, libérations, missions, level up | 2h | E1-S3 |
| E11-S9 | Popup bienvenue + pack (1ère connexion) | Popup s'affiche 1 seule fois, bouton JOUER MON 1ER MATCH | 1h | E1-S4 |

**Total E11 : ~14h**

---

### E12 — Audio & VFX

| # | Story | Critère "c'est fait" | Estim. | Dépendance |
|---|-------|---------------------|--------|------------|
| E12-S1 | Intégrer les SFX essentiels (lancer, impact, catch, élim, libér.) | 5 sons essentiels jouent aux bons moments | 2h | E4, E5 |
| E12-S2 | Intégrer les SFX UI + zone + balle bonus | Sons alerte zone, balle bonus, boutons UI | 1h | E6, E11 |
| E12-S3 | Intégrer la musique (lobby + match + victoire/défaite) | 4 pistes musicales jouent dans les bons contextes | 2h | E3 |
| E12-S4 | VFX élimination (tourbillon cartoon + flash rouge) | Effet visible et lisible à l'élimination | 1h | E5-S1 |
| E12-S5 | VFX libération (confettis + flash vert) | Effet spectaculaire à la libération | 1h | E5-S4 |
| E12-S6 | VFX level up (colonne dorée + confettis) | Effet satisfaisant à la montée de niveau | 1h | E8-S2 |
| E12-S7 | Sons ambiance (plage lobby + foule match) | Ambiance sonore de fond pour lobby et match | 1h | E2 |

**Total E12 : ~9h**

---

### E13 — Onboarding

| # | Story | Critère "c'est fait" | Estim. | Dépendance |
|---|-------|---------------------|--------|------------|
| E13-S1 | Popup bienvenue (1ère connexion, 3 règles) | Popup s'affiche uniquement au 1er lancement | 1h | E1-S4, E11-S5 |
| E13-S2 | Tooltips contextuels in-match (6 tooltips) | Chaque tooltip s'affiche au bon moment, 1 seule fois | 2h | E4, E5, E6 |
| E13-S3 | Pack de bienvenue (fin du 1er match) | 100 Or + Skin Tropical + Titre Rookie crédités après le 1er match | 1h | E3-S7, E8-S3 |
| E13-S4 | Chaîne d'objectifs guidés (niveau 1-5) | Objectifs "Joue 3 matchs" → "Atteins niveau 5" → etc. visibles | 2h | E8-S2, E11-S5 |

**Total E13 : ~6h**

---

### E14 — Social & Classements

| # | Story | Critère "c'est fait" | Estim. | Dépendance |
|---|-------|---------------------|--------|------------|
| E14-S1 | Classement global victoires (OrderedDataStore) | Top joueurs visibles dans l'UI | 2h | E1-S4 |
| E14-S2 | Classement hebdo kills (reset chaque lundi) | Classement mis à jour en temps réel | 1h | E14-S1 |
| E14-S3 | Profil joueur public (niveau, titre, cosmétiques) | Clic sur un joueur → affiche son profil | 1h | E9-S3 |
| E14-S4 | Invitations amis + groupes de jeu | Bouton "Inviter" → notification envoyée → rejoindre même file | 3h | E3-S2 |
| E14-S5 | Bonus XP amis (+10% si ami dans l'équipe) | Détecte les amis Roblox dans l'équipe, applique le bonus | 1h | E8-S8 |

**Total E14 : ~8h**

---

### E15 — Polish & Lancement

| # | Story | Critère "c'est fait" | Estim. | Dépendance |
|---|-------|---------------------|--------|------------|
| E15-S1 | Tests de performance mobile | FPS > 30 sur mobile bas de gamme, optimisations si nécessaire | 2h | Tout |
| E15-S2 | Anti-triche — validation serveur systématique | Tous les RemoteEvents validés côté serveur, rate limiting en place | 2h | E4, E5 |
| E15-S3 | Fix bugs critiques (playtest interne) | Session de playtest complète, bugs bloquants corrigés | 4h | Tout |
| E15-S4 | Codes promotionnels de lancement | Système de codes fonctionnel, 3 codes préparés pour le J-Day | 1h | E8-S3 |
| E15-S5 | Rojo + GitHub workflow (si utilisé) | Code versionné, workflow de sync Studio ↔ fichiers établi | 1h | E1-S1 |
| E15-S6 | Playtest public (amis/famille) | 5+ personnes testent, feedback collecté et appliqué | — | Tout |

**Total E15 : ~10h**

---

## Ordre de développement (chemin critique)

```
SEMAINE 1 — Fondations (E1 + E2)
  E1-S1 → E1-S2 → E1-S3 → E1-S4 → E1-S5 → E1-S7
  E2-S1 → E2-S2 → E2-S3 → E2-S4 → E2-S5

SEMAINE 2 — Le match tourne (E3 + E4)
  E3-S1 → E3-S2 → E3-S3 → E3-S4 → E3-S5
  E4-S1 → E4-S2 → E4-S3 → E4-S4

SEMAINE 3 — Prison + Zone (E5 + E6)
  E5-S1 → E5-S2 → E5-S3 → E5-S4 → E5-S5 → E5-S6
  E6-S1 → E6-S2 → E6-S3 → E6-S4 → E6-S5 → E6-S6
  E3-S6 → E3-S7 (fin de match maintenant possible)

SEMAINE 4 — Catch + Bots (E4 suite + E7)
  E4-S5 → E4-S6 → E4-S7 → E4-S8
  E7-S1 → E7-S2 → E7-S3 → E7-S4 → E7-S5 → E7-S8

SEMAINE 5 — Progression + Économie (E8 + E10 partiel)
  E8-S1 → E8-S2 → E8-S3 → E8-S4 → E8-S5 → E8-S6 → E8-S7
  E10-S3 → E10-S4 → E10-S5 → E10-S6

SEMAINE 6 — UI + HUD (E11)
  E11-S1 → E11-S2 → E11-S3 → E11-S4 → E11-S5 → E11-S6 → E11-S7 → E11-S8

SEMAINE 7 — Cosmétiques + Boutique (E9 + E10)
  E9-S1 → E9-S2 → E9-S3 → E9-S4 → E9-S5 → E9-S6 → E9-S7
  E10-S1 → E10-S2
  E6-S7 (balle bonus)

SEMAINE 8 — Audio + VFX + Onboarding (E12 + E13)
  E12-S1 → E12-S2 → E12-S3 → E12-S4 → E12-S5 → E12-S6
  E13-S1 → E13-S2 → E13-S3 → E13-S4

SEMAINE 9 — Social + Polish (E14 + E15)
  E14-S1 → E14-S2 → E14-S3
  E15-S1 → E15-S2 → E15-S3 → E15-S4 → E15-S6

🚀 LANCEMENT
```

---

## Résumé global

| Epic | Stories | Estimation |
|------|---------|------------|
| E1 Infrastructure | 7 | ~8h |
| E2 Map & Arène | 7 | ~8,5h |
| E3 Système Match | 7 | ~9h |
| E4 Système Balle | 8 | ~10,5h |
| E5 Système Prison | 7 | ~7,5h |
| E6 Zone Dynamique | 7 | ~8h |
| E7 Bots IA | 8 | ~11h |
| E8 Progression | 8 | ~10h |
| E9 Cosmétiques | 7 | ~10h |
| E10 Économie | 6 | ~8,5h |
| E11 UI & HUD | 9 | ~14h |
| E12 Audio & VFX | 7 | ~9h |
| E13 Onboarding | 4 | ~6h |
| E14 Social | 5 | ~8h |
| E15 Polish | 6 | ~10h |
| **TOTAL** | **103 stories** | **~138h** |

> Soit environ **9 semaines à ~15h/semaine** de travail solo.

---

## Checklist avant lancement

- [ ] Match complet jouable de bout en bout (lobby → match → fin)
- [ ] Prison et libération fonctionnelles
- [ ] Zone dynamique opérationnelle
- [ ] Bots remplissent les équipes
- [ ] Sauvegarde/chargement des données fiable
- [ ] XP et Or gagnés et sauvegardés
- [ ] Au moins 5 cosmétiques disponibles
- [ ] Boutique fonctionnelle (Or)
- [ ] Game Passes activés (MarketplaceService)
- [ ] Onboarding complet (1ère connexion)
- [ ] FPS > 30 sur mobile
- [ ] Playtest avec 5+ personnes externes
- [ ] Codes promo de lancement prêts

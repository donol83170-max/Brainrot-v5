# PRD 07 — Social & Multijoueur — Dodgeball Royale

> Date : 2026-02-22
> Statut : VALIDÉ ✅

---

## Type de multijoueur

| | Choix |
|---|-------|
| **Mode** | PvP — équipes (4v4) |
| **Joueurs par serveur** | 16 max (lobby) — instances de 8 joueurs par match |
| **Serveurs privés** | Oui — VIP Servers Roblox (payant, prix standard Roblox) |
| **Cross-platform** | Oui — PC + Mobile + Tablette (pas de console sur Roblox) |

---

## Interactions entre joueurs

| Interaction | Disponible ? | Conditions | Détails |
|-------------|-------------|------------|---------|
| Chat texte | ✅ Oui | — | Roblox TextChatService — filtré automatiquement |
| Chat vocal | ✅ Optionnel | 13+ vérifié (Roblox) | Roblox Voice Chat — activable dans les paramètres |
| Emotes | ✅ Oui | — | Disponibles en fin de match et dans le lobby |
| Trade | ❌ Non | — | Pas de trading (voir PRD 05) |
| Inviter un ami | ✅ Oui | Ami Roblox | Invitation directe depuis le lobby |
| Rejoindre un ami | ✅ Oui | Ami Roblox | Bouton "Rejoindre" sur le profil ami |
| Gifting | ❌ Non (MVP) | — | Post-MVP possible |

---

## Système de parties avec amis

| | Détail |
|---|--------|
| **Jouer ensemble** | Créer un groupe depuis le lobby → rejoindre la même file → même équipe si possible |
| **Taille du groupe** | 1 à 4 joueurs (taille max d'une équipe) |
| **Création** | Bouton "Inviter un ami" dans le lobby → liste amis Roblox connectés |
| **Rejoindre** | Notification reçue → accepter → arrivée dans le lobby du groupe |
| **Bonus XP** | **+10% XP** pour chaque joueur du groupe (stackable — 4 amis = +10% pour tous) |
| **Même équipe** | Le système tente de placer le groupe ensemble — pas garanti si groupe incomplet |

---

## Système d'amis

| | Détail |
|---|--------|
| **Système utilisé** | Friend list Roblox native — pas de système custom |
| **Bonus d'amis** | +10% XP quand on joue dans la même équipe qu'un ami |
| **Rejoindre un ami** | Via le profil Roblox ou bouton dans le lobby |
| **Voir les amis connectés** | Panneau "Amis" dans le lobby — affiche qui est en ligne et dans quel mode |

---

## Classements (Leaderboards)

| Classement | Critère de tri | Reset | Récompenses |
|------------|---------------|-------|-------------|
| **Global — Victoires** | Total de victoires toutes saisons | Jamais | Titre affiché sur le profil |
| **Saison — XP** | XP gagné pendant la saison en cours | Chaque saison (4-6 semaines) | Cosmétiques exclusifs Top 100 |
| **Hebdomadaire — Kills** | Total kills de la semaine | Chaque lundi | +500 Or pour le Top 10 |
| **Amis** | XP gagné cette semaine — entre amis seulement | Chaque lundi | Social, pas de récompense |

---

## Emotes

Disponibles après une victoire, une libération, ou dans le lobby :

| Emote | Comment l'obtenir | Moment d'utilisation |
|-------|------------------|----------------------|
| 🙌 Célébration basique | Par défaut (tout le monde) | Victoire / Lobby |
| 🕺 Danse plage | Niveau 10 | Lobby |
| 🤙 "Trop fort !" | Boutique (Or) | Victoire / Libération |
| 🔥 Emote premium | Boutique (Robux) | Victoire / Lobby |

---

## PvP — Matchmaking

| | Détail |
|---|--------|
| **Type** | Matchmaking automatique — arène, équipes assignées |
| **Base du matchmaking** | Aléatoire au MVP — ELO / niveau post-MVP |
| **Protection nouveaux joueurs** | Niveaux 1-5 : mis ensemble de préférence (soft MMR) |
| **Pénalité mort** | Aucune — pas de perte d'items, d'Or ou d'XP à l'élimination |
| **Abandon de match** | Pas de pénalité au MVP — cooldown de 2 min post-MVP pour les abandons répétés |
| **Bots** | Ajoutés automatiquement si file vide — indiscernables visuellement |

---

## Serveurs Privés (VIP Servers)

| | Détail |
|---|--------|
| **Disponible ?** | Oui — feature standard Roblox |
| **Prix** | Fixé par le développeur (recommandé : 50-100 Robux/mois) |
| **Utilisation** | Jouer entre amis, tournois privés, entraînement |
| **Bots** | Disponibles pour compléter les équipes en serveur privé |
| **Modes disponibles** | Tous les modes débloqués (Classique, Battle Royale, Chaos) |

---

## Clans (Post-MVP)

Non implémenté au MVP. Prévu pour la Version Complète :
- Créer / rejoindre un clan (nom + tag 4 lettres)
- Classement de clans hebdomadaire
- Bonus XP clan (+5% supplémentaire si joueur du même clan dans l'équipe)
- Emblème de clan visible dans le lobby

---

## Modération & Sécurité

| Mesure | Implémentation |
|--------|---------------|
| **Chat filtré** | Roblox TextChatService — filtrage automatique, conforme COPPA |
| **Report joueur** | Bouton report natif Roblox + report custom in-game (comportement toxique) |
| **Anti-spam chat** | Cooldown 2s entre messages |
| **Anti-triche** | Validation serveur pour tous les touchers de balle (voir PRD 02) |
| **Protection mineurs** | Chat vocal désactivé par défaut pour les joueurs sans vérification d'âge |
| **Bannissement** | Via outils Roblox standard (temporaire / permanent) |

---

## Questions clés validées

- [x] Le jeu est-il meilleur à plusieurs ? → Oui : bonus XP amis + coordination équipe
- [x] Les joueurs ont-ils des raisons de coopérer ? → Oui : libérer ses coéquipiers = stratégie centrale
- [x] Le PvP est-il fair ? → Oui : soft MMR niveaux 1-5 + bots calibrés
- [x] Les interactions sont-elles sécurisées ? → Oui : filtrage Roblox + vocal désactivé par défaut
- [x] Un joueur solo peut-il s'amuser ? → Oui : matchmaking automatique + bots disponibles

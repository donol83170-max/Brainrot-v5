# Plan de Production — Brainrot Wheel Royale

> Découpage en Epics et Stories pour un développement structuré.

---

## Epics (Grands blocs)

| # | Epic | Priorité | Statut |
| :--- | :--- | :--- | :--- |
| **E1** | Infrastructure & Data | CRITIQUE | [ ] |
| **E2** | Système de Roues (Wheel System) | CRITIQUE | [ ] |
| **E3** | Économie & Vente (Gold/XP/Tickets) | HAUTE | [ ] |
| **E4** | Machine à Échange (Trade Machine) | HAUTE | [ ] |
| **E5** | Inventaire & UI | HAUTE | [ ] |
| **E6** | Contenu (Brainrots Memes) | MOYENNE | [ ] |

---

## Story Breakdown

### E1 : Infrastructure
*   **E1-S1** : Setup Rojo & structure de dossiers (Services, Controllers, Modules).
*   **E1-S2** : Implémentation du `DataManager` (DataStore v1 - Gold/XP/Inventory).
*   **E1-S3** : Création des RemoteEvents de base (`SpinRequest`, `UpdateData`).

### E2 : Système de Roues (Core Loop)
*   **E2-S1** : Logique serveur de calcul de rareté (60/20/10/8/2).
*   **E2-S2** : Module `LootTables` avec les premiers items (Sigma, Skibidi).
*   **E2-S3** : Contrôleur client pour l'animation de rotation de la roue UI.

### E3 : Économie & Vente
*   **E3-S1** : Système de vente d'items vs Or/XP.
*   **E3-S2** : Système de tickets (Condition d'accès aux roues).

### E4 : Machine à Échange
*   **E4-S1** : Interaction physique avec la machine (ProximityPrompt).
*   **E4-S2** : Interface d'échange multijoueur (Validation 2-step).
*   **E4-S3** : Logique serveur de transfert d'items sécurisé.

### E5 : Inventaire & UI
*   **E5-S1** : Grille d'inventaire montrant les Brainrots et leur rareté.
*   **E5-S2** : HUD principal (Barre d'Or, XP, Niveau).

---

## Ordre de Développement (Chemin Critique)
1.  **Infrastructure** (E1) -> Pour avoir une base stable.
2.  **Core Wheel Logic** (E2) -> Pour rendre le jeu "jouable" (le plaisir de spin).
3.  **Inventory & Sell** (E3 & E5) -> Pour donner une utilité aux objets gagnés.
4.  **Trade Machine** (E4) -> Pour l'aspect social/multi.

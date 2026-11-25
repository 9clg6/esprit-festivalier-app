# UX Design : Esprit Festivalier App

**Date :** 2026-11-25
**Designer :** clement
**Version :** 1.0

## Projet

- **Plateforme :** iPhone (iOS 17+), mode portrait. Android plus tard, avec les mêmes parcours.
- **Accessibilité :** WCAG 2.1 AA (NFR-006), VoiceOver, Dynamic Type.
- **Direction artistique :** celle du site (`docs/design/direction-artistique.md`). Esprit premium et sobre ; récompenses discrètes (animation du favori, badges), sans effet « enfant ».
- **Ton :** tutoiement, phrases courtes, vocabulaire de festivalier.

## Périmètre

- **Écrans MVP :** 15 (plus 4 états communs).
- **Parcours :** 6.
- **Composants :** 16.
- Écrans de phase 2 (premium, concours, fiche partenaire) esquissés à la fin.

---

## Principes

1. **Le jour J d'abord.** « Mes festivals » s'ouvre directement sur le prochain festival et sa timetable quand il a lieu dans moins de 48 h.
2. **Rien à demander au lancement.** Ni compte, ni position, ni notifications : chaque autorisation se demande au moment où elle sert, avec un écran qui explique pourquoi.
3. **Hors ligne visible.** Un bandeau discret dit quand l'app affiche des données en cache ; rien ne se bloque.
4. **Une action principale par écran.** Bouton plein (pilule `accent-fill`) pour l'action principale, bouton pilule clair pour le reste.
5. **Transparence.** « Partenaire », « Mis en avant » et « Sponsorisé » sont toujours affichés.

---

## Navigation

Barre d'onglets, 5 onglets :

| Onglet | Icône SF Symbols | Contenu |
|---|---|---|
| Accueil | `house` | À la une, programmations, festivals du week-end, articles |
| Festivals | `magnifyingglass` | Liste et carte, filtres, recherche |
| Mes festivals | `heart` | Favoris, prochain festival, ma timetable |
| Articles | `newspaper` | Rubriques du site |
| Profil | `person.crop.circle` | Compte, notifications, confidentialité, à propos |

Liens universels : `/festival/{slug}` → fiche ; `/article/{id}` → article. Une notification ouvre l'écran concerné, avec le bon onglet sélectionné.

---

## Parcours

### P1 : Choisir un festival

**Entrée :** onglet Festivals, ou « Ce week-end » sur l'Accueil.

1. Liste → touche « Filtres » → feuille Filtres (région ou « autour de moi », période, genres) → « Voir 23 festivals ».
2. Liste filtrée → bascule « Carte » → touche un point → aperçu → touche l'aperçu → Fiche.
3. Fiche → ♥ (favori) → animation et vibration légère.
4. Fiche → « Billets » → billetterie dans Safari (feuille intégrée).

**Décisions :**
- « Autour de moi » sans autorisation de position → écran d'explication → demande iOS. Refus → on propose de choisir une région.
- Premier favori sans notifications autorisées → feuille « Préviens-moi » (P5).

**Erreurs :**
- Aucun résultat → état vide : « Aucun festival avec ces filtres » + « Élargir à 100 km » / « Effacer les filtres ».
- Réseau coupé → liste du cache + bandeau hors ligne.

### P2 : Vivre le jour J

**Entrée :** notification J-1, ou onglet Mes festivals.

1. Mes festivals → carte « Demain : Festival X » → Fiche (disponible hors ligne).
2. Fiche → « Timetable » → coche 5 concerts (☆ devient ★).
3. Deux concerts se chevauchent → bandeau « 2 concerts en même temps » sur les deux lignes.
4. 15 min avant → notification locale « Artiste Y sur la scène Z dans 15 min ».

**Erreurs :** horaires modifiés par le festival → notification + ligne « Horaire modifié » surlignée en jaune `sun` dans la timetable.

### P3 : Suivre l'actualité

1. Notification « Nouvelle programmation : Festival X » → écran Programmation.
2. Touche un artiste → page Artiste → festivals à venir de l'artiste → ♥.

### P4 : Lire un article

1. Articles → rubrique « Live reports » → article.
2. En bas de l'article : festivals cités → Fiche. « Partager » → lien du site.

### P5 : Activer les notifications

**Entrée :** premier favori, ou Profil → Notifications.

1. Feuille « Ne rate rien » : 3 lignes d'exemple (programmation, J-1, rappels de concerts) → « Activer » → demande iOS.
2. Refus → la feuille ne revient pas d'elle-même ; Profil → Notifications montre « Désactivées dans Réglages » + bouton « Ouvrir Réglages ».

### P6 : Créer un compte

**Entrée :** Profil → « Se connecter », ou « Synchroniser mes favoris » (bandeau dans Mes festivals après 3 favoris).

1. Feuille Connexion → « Continuer avec Apple » → compte créé → favoris locaux envoyés.
2. Ou « Continuer avec un e-mail » → saisie → code à 6 chiffres → connecté.

**Erreurs :** code faux → « Code incorrect, vérifie le dernier e-mail reçu » + « Renvoyer le code » (actif après 30 s).

**Sortie :** retour à l'écran d'origine avec le message « Favoris synchronisés ».

---

## Écrans

Les maquettes sont dessinées pour un iPhone de 390 pt de large. Marges latérales de 16 pt.

### E1 : Accueil

```
┌───────────────────────────────┐
│ [logo Esprit Festivalier]  🔔 │  barre (logo à gauche)
├───────────────────────────────┤
│ ┌───────────────────────────┐ │
│ │      [grande photo]       │ │  À la une (article ou
│ │ LIVE REPORT               │ │  partenaire « Mis en avant »)
│ │ Titre sur 2 lignes        │ │  texte blanc sur dégradé night
│ └───────────────────────────┘ │
│ Programmations      Tout voir │
│ ┌──────┐ ┌──────┐ ┌──────┐    │  défilement horizontal
│ │visuel│ │visuel│ │visuel│    │
│ │Fest. │ │Fest. │ │Fest. │    │
│ │12 art│ │8 art.│ │20 art│    │
│ └──────┘ └──────┘ └──────┘    │
│ Ce week-end         Tout voir │
│ ┌───────────────────────────┐ │
│ │[img] Nom du festival    ♥ │ │  FestivalRow (3 max)
│ │      13-15 juin · Rennes  │ │
│ │      [Électro] [Rock]     │ │
│ └───────────────────────────┘ │
│ Derniers articles   Tout voir │
│ [ArticleCard] [ArticleCard]   │
├───────────────────────────────┤
│  🏠    🔍    ♥    📰    👤    │
└───────────────────────────────┘
```

- **But :** donner envie et montrer ce qui est nouveau.
- 🔔 ouvre l'historique des notifications (phase 2 ; masqué au MVP).
- Rafraîchir en tirant vers le bas.
- « Ce week-end » sans festival proche → remplacé par « Ce mois-ci ».

### E2 : Festivals (liste)

```
┌───────────────────────────────┐
│ Festivals                     │  grand titre (Chivo)
│ [🔍 Rechercher un festival  ] │
│ [Filtres · 2] [Ce week-end]   │  pastilles rapides
│ [Autour de moi] [Électro] …   │
│        [ Liste | Carte ]      │  sélecteur
├───────────────────────────────┤
│ JUIN 2027                     │  en-tête de mois (Raleway, majuscules)
│ ┌───────────────────────────┐ │
│ │[img] Nom du festival    ♥ │ │
│ │      13-15 juin · Rennes  │ │
│ │      [Électro]  PARTENAIRE│ │
│ └───────────────────────────┘ │
│ ┌───────────────────────────┐ │
│ │[img] Autre festival     ♡ │ │
│ │      20-22 juin · Lyon    │ │
│ └───────────────────────────┘ │
│ JUILLET 2027                  │
│ …                             │
└───────────────────────────────┘
```

- Groupé par mois, comme le site.
- Partenaire mis en avant : en tête de son mois, avec le badge « Mis en avant ».
- Glisser une ligne vers la gauche → favori (même effet que ♥).

### E3 : Filtres (feuille)

```
┌───────────────────────────────┐
│ Filtres            Effacer    │
│ OÙ                            │
│ (•) Autour de moi  [ 50 km ▾] │
│ ( ) Région         [Bretagne▾]│
│ QUAND                         │
│ [Ce week-end][Ce mois-ci]     │
│ [Choisir des dates]           │
│ GENRES                        │
│ [Rock][Électro][Rap][Pop]     │
│ [Jazz][Metal][Reggae][…]      │
│                               │
│ [   Voir 23 festivals     ]   │  bouton plein, compte en direct
└───────────────────────────────┘
```

- Feuille à deux hauteurs (moyenne et grande).
- Le compteur du bouton se met à jour à chaque choix.

### E4 : Festivals (carte)

```
┌───────────────────────────────┐
│ [🔍 …] [Filtres · 2]          │
│        [ Liste | Carte ]      │
│   ·  (12)       ·             │  points regroupés
│        ●   ·                  │
│   (5)        ●                │
│              [◎]              │  recentrer sur moi
│ ┌───────────────────────────┐ │
│ │[img] Nom du festival    ♥ │ │  aperçu (après un toucher)
│ │      13-15 juin · Rennes  │ │
│ └───────────────────────────┘ │
└───────────────────────────────┘
```

- Point : rond `accent-fill` ; point favori : cœur ; partenaire : contour `sun`.
- Toucher un groupe → zoom sur ce groupe.

### E5 : Fiche festival

```
┌───────────────────────────────┐
│ ‹                    ⤴    ♥   │  barre transparente sur la photo
│      [photo plein écran]      │
│ ÉLECTRO · PARTENAIRE          │
│ Nom du festival               │  titre Chivo
│ 13-15 juin 2027 · Rennes (35) │
├───────────────────────────────┤
│ [ Billets ↗ ]  [ Itinéraire ] │  plein + pilule claire
│ [Infos][Programmation][Timetable][Accès]  onglets ancrés
│ À PROPOS                      │
│ Texte court… Lire plus        │
│ PROGRAMMATION (24)  Tout voir │
│ (●)(●)(●)(●)(●) →             │  avatars d'artistes
│ INFOS PRATIQUES               │
│ 🚌 Navettes depuis la gare    │
│ 🚫 Objets interdits           │
│ ☁️ Météo (phase 2)             │
│ PLAN DU SITE                  │
│ [image du plan, zoomable]     │
│ ARTICLES                      │
│ [ArticleCard]                 │
│ Disponible hors ligne ✓       │  si favori
└───────────────────────────────┘
```

- Les sections sans données sont masquées.
- « Billets » ouvre la billetterie dans une feuille Safari ; libellé VoiceOver « Billets, site externe ».
- Favori : le cœur se remplit avec une petite animation de rebond (désactivée si « Réduire les animations ») et une vibration légère.

### E6 : Timetable

```
┌───────────────────────────────┐
│ ‹ Timetable            [Moi]  │  [Moi] = seulement mes concerts
│ [Ven 13][Sam 14][Dim 15]      │
│ GRANDE SCÈNE                  │
│ 19:00  Artiste A          ☆   │
│ 20:30  Artiste B          ★   │
│ ⚠ En même temps qu'Artiste D  │  conflit (ink sur fond sun)
│ CHAPITEAU                     │
│ 20:45  Artiste D          ★   │
│ ⚠ En même temps qu'Artiste B  │
│ 22:00  Artiste E          ☆   │
│        Horaire modifié        │  surligné sun
└───────────────────────────────┘
```

- Liste par scène plutôt qu'une grille : plus lisible en grand texte, avec VoiceOver et à une main.
- Le concert en cours porte la mention « Maintenant ».
- Toucher ★ ou ☆ coche ou décoche ; rappel 15 min avant (réglable dans Profil).

### E7 : Programmations

Liste de cartes : visuel du festival, nom, date d'annonce, 5 premiers artistes, « + 19 ». Toucher → écran Programmation du festival (liste d'artistes en grille de 2, avec photo et nom).

### E8 : Artiste

Photo, nom, genres, « Suivre » (phase 2), liste « En festival » (FestivalRow), lien vers Apple Music.

### E9 : Mes festivals

```
┌───────────────────────────────┐
│ Mes festivals                 │
│ ┌───────────────────────────┐ │
│ │ DEMAIN                    │ │  carte « Prochain » (fond deep,
│ │ Nom du festival           │ │  texte blanc)
│ │ 5 concerts dans ta timetable│
│ │ [ Ma timetable ]          │ │
│ └───────────────────────────┘ │
│ À VENIR                       │
│ [FestivalRow ♥] …             │
│ PASSÉS                        │
│ [FestivalRow grisé] …         │
│ ┌───────────────────────────┐ │
│ │ Synchronise tes favoris   │ │  après 3 favoris, sans compte
│ │ [ Se connecter ]       ✕  │ │
│ └───────────────────────────┘ │
└───────────────────────────────┘
```

**État vide :** illustration sobre (logo en contour) + « Ajoute des festivals en favori pour les retrouver ici, même sans réseau » + « Explorer les festivals ».

### E10 : Articles

Grand titre, pastilles des rubriques défilantes (Tout, Live reports, Programmations, Interviews, Actus, Guides, Décryptages, Chroniques). Liste d'ArticleCard : image 16:9, rubrique, titre, auteur et date, badge « Sponsorisé » si besoin.

### E11 : Article

Lecture : image, rubrique, titre (Chivo), auteur et date, texte en Open Sans 17 pt, interligne 1,5, largeur de lecture limitée. Crédit sous chaque photo. En bas : festivals cités, « Lire sur le site », « Partager ».

### E12 : Profil

Sections : compte (connexion ou e-mail, « Se déconnecter », « Supprimer mon compte »), notifications (par type, délai des rappels), confidentialité (position, mesure d'audience, « Exporter mes données »), à propos (le média, rejoindre la rédaction, contact, licence, version).

### E13 : Connexion (feuille)

Logo, « Garde tes festivals sur tous tes appareils », bouton « Continuer avec Apple » (style Apple officiel), « Continuer avec un e-mail », mention de la politique de confidentialité.

### E14 : Pré-autorisations (feuille, modèle commun)

Icône, titre (« Ne rate rien », « Festivals autour de toi »), 2 ou 3 lignes d'exemple, bouton plein « Activer », lien « Plus tard ». Utilisé pour les notifications et la position.

### E15 : Accueil de premier lancement

Un seul écran, pas de tunnel : logo, « Le média des festivals, par ceux qui les vivent », « Trouve ton prochain festival » (bouton plein) → onglet Festivals. Pas de demande d'autorisation ici.

### États communs

| État | Rendu |
|---|---|
| Chargement | Squelettes aux formes des cartes (fond `thumb`), animation de scintillement sauf si « Réduire les animations » |
| Hors ligne | Bandeau sous la barre : « Hors ligne · données du 12 juin à 18:04 » (fond `sky`, texte `ink2`) |
| Erreur | Message court + « Réessayer » ; jamais de code d'erreur technique |
| Vide | Phrase utile + une action |

### Phase 2 (esquisse)

- **Premium :** feuille d'offre avec 3 avantages, prix, « Essayer », « Restaurer mes achats », liens CGU et confidentialité. Badge « Premium » en jaune `sun`.
- **Concours :** visuel du lot, date de fin, règlement, « Participer » ; premium : « +2 entrées » affiché ; après participation : « Tu participes · résultat le 2 juin ».
- **Fiche partenaire :** même structure que E5, avec la couleur et la bannière du festival, des blocs en plus (vidéo, FAQ, sponsors) et la mention « Partenaire ».

---

## Accessibilité (WCAG 2.1 AA)

### Contrastes vérifiés

| Paire | Rapport | Usage autorisé |
|---|---|---|
| `ink` sur `card` (clair) | 17,6:1 | Texte |
| `muted` sur `card` (clair) | 5,1:1 | Texte secondaire |
| `muted` sur `bg` (clair) | 4,7:1 | Texte secondaire |
| `accent-dark` sur blanc | 5,5:1 | Liens, texte d'accent |
| Blanc sur `accent-fill` | 5,5:1 | Bouton plein |
| Blanc sur `deep` | 11,3:1 | Cartes sombres |
| `ink` sur `sun` | 12,2:1 | Badges, alertes de conflit |
| **`accent` sur blanc** | **3,1:1** | **Icônes, gros titres (≥ 24 pt) seulement ; jamais de texte courant** |
| Blanc sur `accent` | 3,1:1 | **Interdit** pour du texte ; utiliser `accent-fill` |
| `ink` sur `card` (sombre) | 15,2:1 | Texte |
| `muted` sur `card` (sombre) | 6,7:1 | Texte secondaire |
| `accent-dark` sur `card` (sombre) | 8,3:1 | Liens |
| `line` sur `card` (clair) | 1,3:1 | Séparateurs décoratifs seulement |

### Règles

- **VoiceOver :** chaque FestivalRow est lue comme un seul élément : « Nom du festival, 13 au 15 juin, Rennes, électro, partenaire, en favori ». ♥ est une action personnalisée (« Ajouter aux favoris »).
- **Dynamic Type :** toutes les polices passent par `Font.custom(_:size:relativeTo:)`. Aux tailles d'accessibilité, les lignes passent sur plusieurs lignes et les carrousels deviennent des listes verticales.
- **Cibles tactiles :** 44 × 44 pt minimum (♥, ☆, pastilles).
- **Couleur :** jamais seule. Conflit = icône ⚠ + texte ; favori = cœur plein + libellé.
- **Mouvement :** animations de rebond et de scintillement coupées si « Réduire les animations » est actif.
- **Images :** photos d'articles avec la légende du site comme description ; visuels décoratifs ignorés par VoiceOver.
- **Ordre de lecture :** titre → actions principales → contenu, sur chaque écran.
- **Audit :** `performAccessibilityAudit()` dans les tests d'interface des écrans E2, E5, E6, E9.

---

## Composants

| Composant | Contenu | États | Notes |
|---|---|---|---|
| `PrimaryButton` | Texte, icône facultative | normal, pressé (`accent-dark`), désactivé (50 %), chargement | Pilule, fond `accent-fill`, texte blanc, 50 pt de haut |
| `SecondaryButton` | Texte | normal, pressé, désactivé | Pilule, fond `sky`, texte `accent-dark` |
| `FavoriteButton` | Cœur | vide, plein, animation | Vibration légère ; action VoiceOver |
| `FestivalRow` | Vignette 64 pt, nom, dates, ville, genres, ♥ | normal, pressé (`hover`), passé (grisé) | Un seul élément VoiceOver |
| `FestivalCard` | Visuel 16:9, nom, dates, nombre d'artistes | normal, pressé | Carrousels de l'Accueil |
| `HeroCard` | Grande photo, rubrique, titre | normal, pressé | Dégradé `night` pour le contraste du texte |
| `ArticleCard` | Image 16:9, rubrique, titre, auteur, date | normal, sponsorisé | Rubrique en Raleway majuscules |
| `GenreChip` | Libellé | normal, sélectionné (`accent-fill` + blanc) | Pilule |
| `Badge` | Partenaire, Mis en avant, Sponsorisé, Premium | — | Fond `sun`, texte `ink`, Raleway 12 pt gras |
| `SectionHeader` | Titre, « Tout voir » | — | Titre Raleway majuscules, lien `accent-dark` |
| `PerformanceCell` | Heure, artiste, ☆/★, conflit, modifié, maintenant | coché, conflit, modifié, en cours | Liste par scène |
| `OfflineBanner` | Texte et date du cache | — | Fond `sky` |
| `EmptyState` | Illustration, texte, action | — | |
| `SkeletonBlock` | Forme | animé, figé | Fond `thumb` |
| `PermissionSheet` | Icône, titre, exemples, Activer, Plus tard | — | E14 |
| `FestivalMapPin` | Point, cœur, contour partenaire, groupe | normal, sélectionné | `MKAnnotationView` |

---

## Tokens

Couleurs : celles de `docs/design/direction-artistique.md`, dans un catalogue d'assets avec variantes claire et sombre. Règle d'usage ajoutée : **`accent` pour les icônes et grands titres seulement ; `accent-fill` pour les fonds de boutons ; `accent-dark` pour le texte d'accent.**

### Typographie (alignée sur Dynamic Type)

| Style | Police | Taille de base (pt) | Style iOS de référence |
|---|---|---|---|
| Grand titre | Chivo Black | 34 | `.largeTitle` |
| Titre 1 | Chivo Bold | 28 | `.title` |
| Titre 2 | Chivo Bold | 22 | `.title2` |
| Titre 3 | Chivo Bold | 20 | `.title3` |
| Libellé fort | Raleway Bold | 17 | `.headline` |
| Corps | Open Sans Regular | 17 | `.body` |
| Corps secondaire | Open Sans Regular | 15 | `.subheadline` |
| Rubrique, en-tête de section | Raleway Bold, majuscules, +0,06 em | 13 | `.footnote` |
| Légende | Open Sans Regular | 12 | `.caption` |

### Espacements

4, 8, 12, 16, 24, 32, 48 pt. Marges latérales 16 pt ; espace entre sections 32 pt ; padding des cartes 12 à 16 pt.

### Formes et ombres

- Rayon : cartes 16 pt, vignettes 12 pt, pastilles et boutons en pilule, avatars ronds. Arrondis continus (`.continuous`).
- Ombre des cartes (clair seulement) : `deep` à 6 %, rayon 2, puis `deep` à 25 %, rayon 15, décalage 10. En sombre : pas d'ombre, fond `card`.

### Mouvement

- Ressorts courts (`.snappy`) pour les changements d'état ; rebond du favori 0,3 s.
- Pas d'animation décorative en boucle, sauf les squelettes de chargement.

---

## Remise aux développeurs

### Ordre

1. `EFDesign` : couleurs, polices (Chivo, Raleway, Open Sans embarquées), espacements, composants de base, avec aperçus clair, sombre et grand texte.
2. E2 et E5 (liste et fiche) sur la source `mock`, puis E3 et E4.
3. E9 et E6 (Mes festivals, timetable), puis E14 et P5.
4. E1, E10, E11, E7, E8, puis E12, E13, E15.
5. États communs et finitions (animations, vibrations).

### Notes

- Chaque écran a un aperçu SwiftUI alimenté par la source `mock`, en clair et en sombre, et en taille de texte AX3.
- Carte : `MKMapView` dans un `UIViewRepresentable` pour le regroupement des points.
- Billetterie et liens externes : `SFSafariViewController`.
- Vibrations : `sensoryFeedback(.impact(weight: .light), trigger:)`.

### Ressources à fournir

- Logo en SVG (à demander au designer du site) ; d'ici là, le WebP du site.
- Icône d'app : dérivée de `/icons/icon-512.png`, à décliner en 1024 px.
- Polices : Chivo, Raleway, Open Sans (Google Fonts, SIL OFL).
- Icônes : SF Symbols.

---

## Validation

### Couverture des exigences

| Exigence | Écrans |
|---|---|
| FR-001 Liste | E2 |
| FR-002 Filtres | E2, E3 |
| FR-003 Carte | E4 |
| FR-004 Fiche | E5 |
| FR-005 Billetterie | E5 |
| FR-006 Programmations | E1, E7 |
| FR-007 Compte | E12, E13 |
| FR-008 Favoris | E2, E5, E9 |
| FR-009 Timetable | E6, E9 |
| FR-010 Notifications des favoris | E14, E12 |
| FR-011 Articles | E10, E11 |
| FR-012 Notifications d'articles | E12 |
| FR-013 Rédaction | E12 (à propos) |
| FR-014 à FR-022 | Esquisses de phase 2 |
| NFR-003 Hors ligne | E5 (« Disponible hors ligne »), bandeau hors ligne |
| NFR-006 Accessibilité | Section Accessibilité |
| NFR-007 DA | Section Tokens |

### À faire avant le développement

- [ ] Relecture par la rédaction (ton des textes)
- [ ] Logo SVG reçu
- [ ] Maquettes visuelles (facultatif : les aperçus SwiftUI pourront servir de maquettes)

---

*Créé avec la méthode BMAD v6 (UX Designer), 2026-11-25.*

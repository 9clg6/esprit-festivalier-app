# UX Design : Esprit Festivalier App

**Date :** 2026-11-25
**Designer :** clement
**Version :** 1.1 (application complète : E11 complet, E16, réactions ; 2026-11-25)

## Projet

- **Plateforme :** iPhone (iOS 17+), mode portrait. Android plus tard, avec les mêmes parcours.
- **Accessibilité :** WCAG 2.1 AA (NFR-006), VoiceOver, Dynamic Type.
- **Direction artistique :** celle du site (`docs/design/direction-artistique.md`). Esprit premium et sobre ; récompenses discrètes (animation du favori, badges), sans effet « enfant ».
- **Ton :** tutoiement, phrases courtes, vocabulaire de festivalier.

## Périmètre

- **Écrans MVP :** 16 (plus 4 états communs).
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

Adresses du site routées dans l'app : `/festival/<slug>/` → fiche ; `/<slug>-<numéro>/` → article ; `/author/<slug>/` → auteur. Liens universels : plus tard (FR-034). Une notification ouvre l'écran concerné, avec le bon onglet sélectionné.

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

1. Articles → rubrique « Live reports » → article, en entier dans l'app.
2. Un lien du texte (article, festival, auteur, artiste, rubrique) ouvre l'écran de l'app ; un lien vers un autre site ouvre une feuille Safari.
3. Fin de l'article → réaction → bloc auteur → page auteur (E16) → autre article.
4. Rubrique en tête d'article → festival cité → Fiche. « Partager » → lien du site.

**Erreurs :** lecture impossible ou hors ligne sans copie → extrait du flux + « Réessayer » ; jamais d'ouverture de Safari sans action de l'utilisateur.

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
- La section « Articles » liste les articles du festival (FR-032) ; plus de lien « Lire sur Esprit Festivalier ».
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
│ ⚠ En même temps qu'Artiste D  │  conflit (#0e1a26 sur fond sun)
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

Grand titre, pastilles des rubriques défilantes (Tout, Live reports, Programmations, Interviews, Actus, Guides, Décryptages, Chroniques). Liste d'ArticleCard : image 16:9, rubrique, titre, auteur et date, badge « Sponsorisé » si besoin. Au bout des articles du flux, la liste d'une rubrique continue avec les archives du site, chargées en bas de liste (FR-031). Les pages liste du site (festival, artiste, mot-clé) reprennent ce même écran (FR-032).

### E11 : Article (lecteur complet, v1.1)

Le texte complet est dans l'app (FR-027, ADR-007). Plus de « Lire sur le site ».

```
┌───────────────────────────────┐
│ ‹                          ⤴  │  barre : retour, partager
│ [photo de couverture,         │  pleine largeur, proportions
│  bord à bord]                 │  d'origine
│ Orelsan / Mano Le Bris        │  légende et crédit (Légende, muted)
│ LIVE REPORT · TERRES DU SON ↗︎ │  rubrique ; festival en lien → E5
│ [SPONSORISÉ]                  │  Badge, si sponsorisé
│ Titre de l'article            │  Titre 1 (Chivo Bold 28)
│ Chapô sur quelques lignes…    │  Corps, ink
│ (ML) Par Mano Le Bris         │  avatar 32 pt ; nom en lien → E16
│      25 nov. 2026 · 3 min     │  Corps secondaire, muted
├───────────────────────────────┤
│ Paragraphe, avec du gras, de  │  Corps (Open Sans 17), interligne 1,5
│ l'italique et un lien.        │  liens accent-dark soulignés
│ Intertitre                    │  Titre 3 (Chivo Bold 20)
│ [image bord à bord]           │
│ Vald @odieuxboby              │  légende
│ ┃ « Citation »                │  barre accent 3 pt, Corps italique
│ ┌ LIRE AUSSI ───────────────┐ │  carte fond sky
│ │ Superbus : deux heures… › │ │
│ └───────────────────────────┘ │
│ ┌ ▶ VIDÉO YOUTUBE ──────────┐ │  contenu tiers : rien ne charge
│ │ Mentir au psy  youtube ↗  │ │  avant le toucher
│ └───────────────────────────┘ │
│ TA RÉACTION                   │  en-tête de section
│ (❤️ J'adore 12)(🔥 Ça chauffe 3)│  ReactionBar, pilules sur
│ (👏 Bravo)(🤩 Waouh)(💡 Instructif)│  plusieurs lignes
│ [Concert] [Orelsan] [Zénith]  │  mots-clés et artistes → écrans de l'app
│ ┌───────────────────────────┐ │  AuthorBlock (carte)
│ │ (ML) Mano Le Bris         │ │
│ │ Reporter bénévole …       │ │
│ │ [ Voir ses articles ]     │ │  SecondaryButton → E16
│ └───────────────────────────┘ │
│ ARTICLES CONNEXES             │
│ [ArticleCard] ×3              │
└───────────────────────────────┘
```

Réactions en emoji (décision du 2026-11-25) : ❤️ J'adore, 🔥 Ça chauffe, 👏 Bravo, 🤩 Waouh, 💡 Instructif. L'emoji suit Dynamic Type (taille du Corps) ; VoiceOver lit le libellé, jamais le nom de l'emoji. Les photos des photographes de l'association paraissent avec leur crédit.

**Blocs et typographie (tokens existants, pas de nouveau style) :**

| Bloc | Rendu |
|---|---|
| Rubrique, festival | Rubrique, en-tête de section (Raleway Bold 13, majuscules), `accent-dark` ; festival en lien |
| Titre | Titre 1, `ink`, trait d'en-tête VoiceOver |
| Chapô | Corps, `ink` (le texte courant est aussi en `ink`, la signature en dessous fait la séparation) |
| Signature | Avatar 32 pt (photo ou initiales sur `sky`), « Par » + nom en lien `accent-dark`, date et durée de lecture en Corps secondaire `muted` |
| Paragraphe | Corps 17 pt, interligne 1,5, 16 pt entre paragraphes ; gras et italique ; liens `accent-dark` soulignés (la couleur n'est jamais le seul signe) |
| Intertitre | Niveau 2 : Titre 2 ; niveaux 3 et 4 : Titre 3 ; 32 pt au-dessus, 8 pt en dessous |
| Image | Bord à bord sur iPhone (sans les marges de 16 pt, sans arrondi) ; largeur de lecture et arrondi de 12 pt au-delà de 680 pt ; place réservée avec les proportions d'origine ; fond `thumb` pendant le chargement |
| Légende et crédit | Légende (Open Sans 12), `muted`, 8 pt sous l'image, dans les marges ; un auteur reconnu dans le crédit devient un lien `accent-dark` → E16 |
| Citation | Corps italique, barre verticale `accent` de 3 pt (décorative), source en Légende |
| Liste | Puces ou numéros, retrait de 16 pt, 8 pt entre éléments |
| Lire aussi | Carte fond `sky`, « LIRE AUSSI » en en-tête de section, titre en Libellé fort, chevron |
| Contenu tiers | Carte fond `card` avec contour `line`, icône du type (vidéo, son, publication), titre, fournisseur, ↗ ; toucher ouvre l'app ou une feuille Safari |
| Séparateur | Filet `line` de 1 pt, 40 % de la largeur, centré |

- Largeur de lecture limitée à 680 pt (iPad, paysage), comme aujourd'hui.
- Toucher une image : plein écran sur fond `night`, zoom au pincement, légende en bas, glisser vers le bas pour fermer (fondu si « Réduire les animations »).
- Sélection du texte possible dans un paragraphe.

**États :**

| État | Rendu |
|---|---|
| Chargement | Couverture, titre et extrait du flux tout de suite ; squelettes pour le texte |
| Copie hors ligne | Article de la copie + bandeau hors ligne |
| Hors ligne sans copie | Extrait du flux, « Article complet indisponible hors ligne », « Réessayer » |
| Lecture impossible | Extrait, « Impossible d'afficher cet article dans l'app », « Réessayer », lien secondaire « Ouvrir sur le site ↗ » |

### E16 : Auteur

E15 existe déjà (premier lancement) : la page auteur prend le numéro E16.

```
┌───────────────────────────────┐
│ ‹ Auteur                   ⤴  │  partager : lien de la page sur le site
│             (ML)              │  avatar 80 pt (photo ou initiales)
│         Mano Le Bris          │  Titre 1
│ Reporter bénévole pour        │  Corps, ink2 (si connue)
│ Esprit Festivalier            │
│ 12 articles                   │  Corps secondaire, muted
│ [Instagram ↗]                 │  liens, s'il y en a un jour
├───────────────────────────────┤
│ [ArticleCard]                 │
│ [ArticleCard]                 │
│ [SkeletonBlock]               │  page suivante en bas de liste
└───────────────────────────────┘
```

- **Entrées :** signature, bloc auteur, crédit photo reconnu, lien `/author/…` dans un texte.
- L'en-tête (nom, avatar, présentation) vient de l'article d'où l'on vient : il s'affiche sans attendre ; seule la liste charge.
- **États :** liste en squelettes ; erreur → en-tête gardé + « Réessayer » ; aucun article → « Pas encore d'article » ; hors ligne → copie + bandeau.
- « Suivre » (si la proposition est acceptée) : bouton pilule sous le nom, plus tard.

### Réactions : états

| État | Rendu |
|---|---|
| Neutre | Pilule fond `sky`, emoji, libellé `ink2` |
| Active | Fond `accent-fill`, libellé `onFill` ; vibration légère ; rebond de l'emoji de 0,3 s (coupé si « Réduire les animations ») |
| Sans compteurs (bêta, avant le serveur) | Libellé seul ; jamais de « 0 » |
| Démo (source `mock`) | Compteurs + `DemoCaption` « Données de démonstration » sous la barre |
| Avec compteurs | Nombre après le libellé ; 0 masqué ; « 1,2 k » au-delà de 999 ; apparition en fondu, sans décaler les pilules |
| Hors ligne, erreur serveur | Aucun message : l'état reste sur l'appareil et part à la synchronisation suivante |

Placement : à la fin du texte, avant les mots-clés et le bloc auteur ; on réagit après avoir lu. Pas de barre flottante.

### Accessibilité du lecteur et des réactions

- **Ordre de lecture :** rubrique, titre, signature, chapô, texte, réactions, mots-clés, auteur, articles connexes.
- **Intertitres :** trait d'en-tête, pour naviguer au rotor « En-têtes ».
- **Liens :** dans le `Text`, accessibles au rotor « Liens » ; lien tiers annoncé « site externe ».
- **Images :** description = texte alternatif, sinon légende ; le crédit est lu après ; image sans l'un ni l'autre ignorée.
- **Contenu tiers :** « Vidéo YouTube, Mentir au psy, ouvre une app externe ».
- **Réactions :** chaque pilule est un bouton ; l'emoji est masqué pour VoiceOver ; libellé « J'adore », valeur « 12 réactions », trait « Sélectionné » si active ; groupe « Réactions » ; cibles de 44 × 44 pt.
- **Dynamic Type :** texte et légendes suivent la taille ; images toujours en pleine largeur ; aux tailles d'accessibilité, les réactions passent en liste verticale.
- **Contraste :** réaction active, blanc sur `accent-fill` 5,5:1 ; neutre, `ink2` sur `sky` 9,9:1 (clair) et 10,3:1 (sombre).

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
| `#0e1a26` sur `sun` (clair et sombre) | 12,2:1 | Badges, alertes de conflit (texte fixe `onSun` : jamais `ink`, qui tombe à 1,3:1 en sombre) |
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
| `Badge` | Partenaire, Mis en avant, Sponsorisé, Premium | — | Fond `sun`, texte `#0e1a26` fixe en clair et en sombre (`onSun`), Raleway 12 pt gras |
| `SectionHeader` | Titre, « Tout voir » | — | Titre Raleway majuscules, lien `accent-dark` |
| `PerformanceCell` | Heure, artiste, ☆/★, conflit, modifié, maintenant | coché, conflit, modifié, en cours | Liste par scène |
| `OfflineBanner` | Texte et date du cache | — | Fond `sky` |
| `EmptyState` | Illustration, texte, action | — | |
| `SkeletonBlock` | Forme | animé, figé | Fond `thumb` |
| `PermissionSheet` | Icône, titre, exemples, Activer, Plus tard | — | E14 |
| `FestivalMapPin` | Point, cœur, contour partenaire, groupe | normal, sélectionné | `MKAnnotationView` |
| `ArticleBlockView` | Un bloc d'article (voir E11) | selon le bloc | Paragraphe = un seul `Text` avec `AttributedString` |
| `ArticleImageView` | Image, légende, crédit | chargement, chargée, échec (fond `thumb`) | Bord à bord ; plein écran au toucher |
| `EmbedCard` | Type, titre, fournisseur, ↗ | normal, pressé | Rien de tiers ne charge avant le toucher |
| `ReactionBar` | 5 pilules de réaction (emoji + libellé) | voir « Réactions : états » | Retour à la ligne (`FlowLayout`) ; liste aux tailles d'accessibilité |
| `AuthorBlock` | Avatar, nom, présentation, « Voir ses articles » | normal, pressé | Carte ; ouvre E16 |

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
4. E1, E10, E11, E7, E8, puis E12, E13, E15 ; E11 complet, E16 et `ReactionBar` (STORY-055 à 058).
5. États communs et finitions (animations, vibrations).

### Notes

- Chaque écran a un aperçu SwiftUI alimenté par la source `mock`, en clair et en sombre, et en taille de texte AX3.
- Carte : `MKMapView` dans un `UIViewRepresentable` pour le regroupement des points.
- Billetterie et liens vers d'autres sites : `SFSafariViewController`. Liens du site : routés dans l'app (`OpenURLAction`).
- Vibrations : `sensoryFeedback(.impact(weight: .light), trigger:)`.

### Ressources à fournir

- Logo en SVG : `assets/brand/esprit-festivalier-logo.svg` (vectorisé).
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
| FR-027 Article complet | E11 |
| FR-028 Liens internes | E11, P4 |
| FR-029 Auteurs | E11 (signature, bloc auteur, crédits), E16 |
| FR-030 Réactions | E11 (`ReactionBar`) |
| FR-031 Archives | E10 (bas de liste) |
| FR-032 Pages liste | E5 (section Articles), E10 |
| FR-036 Lectures comptées | E11 (rien de visible ; choix dans E12, confidentialité) |
| FR-014 à FR-022 | Esquisses de phase 2 |
| NFR-003 Hors ligne | E5 (« Disponible hors ligne »), bandeau hors ligne |
| NFR-006 Accessibilité | Section Accessibilité |
| NFR-007 DA | Section Tokens |

### À faire avant le développement

- [ ] Relecture par la rédaction (ton des textes)
- [x] Logo SVG (vectorisé, `assets/brand/`)
- [ ] Maquettes visuelles (facultatif : les aperçus SwiftUI pourront servir de maquettes)

---

*Créé avec la méthode BMAD v6 (UX Designer), 2026-11-25.*

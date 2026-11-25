# Sprint Plan : Esprit Festivalier App

**Date :** 2026-11-25
**Scrum master :** clement
**Niveau de projet :** 3
**Stories MVP :** 34 (143 points) · **Phase 2 et 3 :** 18 stories (91 points), non planifiées
**Sprints planifiés :** 9 (du 2026-11-30 au 2027-04-04)

---

## Résumé

Le MVP (epics 1 à 4) se construit en 8 sprints de deux semaines. La bêta TestFlight pour les membres s'ouvre le 22 mars 2027 ; la soumission App Store se fait au sprint 9, avant le 1er mai. TestFlight est branché dès le sprint 2 : chaque sprint envoie une version testable.

**Chiffres clés :**
- Capacité : **24 points par sprint** (hypothèse : 1 développeur bénévole aidé par des agents ; 1 point ≈ 1 à 2 h). On vise environ 20 points, et 14 pendant les fêtes.
- MVP : 143 points.
- Fin prévue : bêta le 22 mars 2027, App Store début avril 2027.
- La capacité sera recalée après le sprint 1 avec la vitesse réelle.

---

## Stories du MVP

### EPIC-001 : socle et sources de données

#### STORY-001 : Monorepo, projet Xcode et CI

**Epic :** EPIC-001 · **Priorité :** Must · **Points :** 5

**En tant que** développeur, **je veux** un projet qui se construit et se teste automatiquement, **afin de** livrer sans casser.

**Critères :**
- [ ] Arborescence `ios/`, `api/`, `data/`, `contracts/` conforme à l'architecture.
- [ ] Projet `EspritFestivalier` (iOS 17, Swift 6) et package local `EFKit` avec les cibles `EFDomain`, `EFData`, `EFDesign`.
- [ ] GitHub Actions : build et tests sur chaque PR ; SwiftLint ; recherche de secrets (gitleaks).

**Notes :** bundle ID proposé `fr.espritfestivalier.app`, sur le compte Apple personnel.

#### STORY-002 : Design system `EFDesign`

**Epic :** EPIC-001 · **Priorité :** Must · **Points :** 5

**En tant que** festivalier, **je veux** retrouver l'univers du site dans l'app.

**Critères :**
- [ ] Couleurs de la DA dans un catalogue d'assets, en clair et en sombre ; règle d'usage de `accent` respectée.
- [ ] Chivo, Raleway, Open Sans embarquées et liées à Dynamic Type.
- [ ] `PrimaryButton`, `SecondaryButton`, `GenreChip`, `Badge`, `SectionHeader` avec aperçus en clair, en sombre et en taille AX3.

**Dépendances :** STORY-001

#### STORY-003 : Domaine, interfaces des sources et mocks

**Epic :** EPIC-001 · **Priorité :** Must · **Points :** 5

**En tant que** développeur, **je veux** des écrans branchés sur des interfaces, **afin de** changer de source sans les toucher.

**Critères :**
- [ ] Modèles `Festival`, `FestivalDetail`, `Stage`, `Performance`, `Lineup`, `Artist`, `Article`.
- [ ] Interfaces `FestivalSource`, `LineupSource`, `ArticleSource`, `ArtistSource`.
- [ ] Sources `Mock…` sur JSON embarqué : 5 festivals de démo complets (dates, programmation, timetable).
- [ ] `AppEnvironment` choisit la source selon `EF_DATA_SOURCE` (configuration de build, argument de lancement).

**Dépendances :** STORY-001

#### STORY-004 : Contrats de l'instantané

**Epic :** EPIC-001 · **Priorité :** Must · **Points :** 3

**Critères :**
- [ ] JSON Schema pour `manifest`, `festivals` (index), `festivals/{id}` (détail), `lineups`, `artists`.
- [ ] Les mocks de STORY-003 sont valides contre ces schémas (test en CI).

**Dépendances :** STORY-003

#### STORY-005 : Pipeline de l'instantané (données ouvertes + mocks)

**Epic :** EPIC-001 · **Priorité :** Must · **Points :** 5

**Critères :**
- [ ] `data/build_snapshot.py` télécharge la liste des festivals en France (data.gouv.fr) et garde les festivals de musique.
- [ ] Fusion avec `data/mocks/` par identifiant stable ; validation contre les schémas.
- [ ] Tests pytest sur la fusion et la validation.

**Dépendances :** STORY-004

#### STORY-006 : Artistes MusicBrainz et publication nocturne

**Epic :** EPIC-001 · **Priorité :** Must · **Points :** 5

**Critères :**
- [ ] Résolution des artistes sur MusicBrainz, 1 requête par seconde au plus, User-Agent générique du projet, cache.
- [ ] GitHub Actions publie chaque nuit sur R2 (`staging`) ; e-mail d'alerte en cas d'échec.
- [ ] `manifest.json` liste les fichiers et leurs versions.

**Dépendances :** STORY-005

#### STORY-007 : Sources « instantané » et cache dans l'app

**Epic :** EPIC-001 · **Priorité :** Must · **Points :** 5

**Critères :**
- [ ] `Snapshot…Source` lit R2 ; `CachedFestivalSource` affiche le cache puis met à jour.
- [ ] Seuls les fichiers changés dans le manifeste sont téléchargés.
- [ ] Le même jeu de tests passe sur la source mock et la source instantané (NFR-008).

**Dépendances :** STORY-003, STORY-006

#### STORY-008 : Fiches favorites hors ligne

**Epic :** EPIC-001 · **Priorité :** Must · **Points :** 3

**Critères :**
- [ ] Un favori copie sa fiche, son plan et ses images dans Application Support.
- [ ] En mode avion, la fiche s'affiche en entier avec la mention « Disponible hors ligne ».

**Dépendances :** STORY-015, STORY-018

#### STORY-009 : Worker de base et essai APNs

**Epic :** EPIC-001 · **Priorité :** Must · **Points :** 5

**Critères :**
- [ ] Worker Hono avec D1, migrations, Vitest, déploiement `staging` depuis la CI.
- [ ] Essai : une notification envoyée à un iPhone depuis le Worker (HTTP/2, jeton ES256).
- [ ] Décision notée dans l'architecture : APNs direct ou repli FCM.

**Dépendances :** STORY-001

#### STORY-010 : Navigation, premier lancement et états communs

**Epic :** EPIC-001 · **Priorité :** Must · **Points :** 3

**Critères :**
- [ ] Barre à 5 onglets ; liens universels `/festival/{slug}` et `/article/{id}`.
- [ ] Écran de premier lancement (E15), sans demande d'autorisation.
- [ ] `OfflineBanner`, `EmptyState`, `SkeletonBlock` disponibles.

**Dépendances :** STORY-002

### EPIC-002 : découverte des festivals

#### STORY-011 : Liste des festivals

**Epic :** EPIC-002 · **Priorité :** Must · **Points :** 5

**En tant que** festivalier, **je veux** voir les festivals à venir mois par mois.

**Critères :**
- [ ] Liste groupée par mois (E2), `FestivalRow`, festivals passés masqués.
- [ ] Rafraîchir en tirant ; défilement fluide avec 500 festivals.
- [ ] Partenaire mis en avant en tête de son mois, avec badge (si présent dans les données).

**Dépendances :** STORY-003, STORY-010

#### STORY-012 : Recherche et filtres

**Epic :** EPIC-002 · **Priorité :** Must · **Points :** 5

**Critères :**
- [ ] Filtres région, période (week-end, mois, dates), genres ; combinables ; compteur dans le bouton (E3).
- [ ] Recherche par nom.
- [ ] Logique de filtre dans `EFDomain`, testée unitairement.
- [ ] Aucun résultat : « Élargir » et « Effacer les filtres ».

**Dépendances :** STORY-011

#### STORY-013 : Autour de moi

**Epic :** EPIC-002 · **Priorité :** Must · **Points :** 3

**Critères :**
- [ ] Feuille d'explication (E14) puis demande iOS, seulement quand on active le filtre.
- [ ] Rayon 25, 50 ou 100 km ; calcul de distance testé.
- [ ] Refus : proposition de choisir une région.

**Dépendances :** STORY-012

#### STORY-014 : Carte des festivals

**Epic :** EPIC-002 · **Priorité :** Must · **Points :** 5

**Critères :**
- [ ] `MKMapView` avec regroupement ; points favori et partenaire distincts (E4).
- [ ] Mêmes filtres que la liste ; aperçu au toucher, puis fiche.

**Dépendances :** STORY-012

#### STORY-015 : Fiche festival

**Epic :** EPIC-002 · **Priorité :** Must · **Points :** 5

**Critères :**
- [ ] Sections de E5 ; sections vides masquées.
- [ ] « Itinéraire » ouvre Plans ; plan du site zoomable.
- [ ] Lecture VoiceOver dans l'ordre titre, actions, contenu.

**Dépendances :** STORY-011

#### STORY-016 : Lien billetterie suivi

**Epic :** EPIC-002 · **Priorité :** Must · **Points :** 2

**Critères :**
- [ ] Bouton « Billets » : `SFSafariViewController`, paramètres `utm_source=esprit-festivalier-app`.
- [ ] Clic enregistré dans la file d'événements anonymes (envoyée par STORY-030).
- [ ] Sans lien connu, pas de bouton.

**Dépendances :** STORY-015

#### STORY-017 : Programmations et page artiste

**Epic :** EPIC-002 · **Priorité :** Must · **Points :** 5

**Critères :**
- [ ] Liste des programmations, la plus récente en premier (E7) ; écran par festival avec la grille d'artistes.
- [ ] Page artiste (E8) : festivals à venir, lien Apple Music.

**Dépendances :** STORY-007

### EPIC-003 : compte, favoris et jour J

#### STORY-018 : Favoris et Mes festivals

**Epic :** EPIC-003 · **Priorité :** Must · **Points :** 5

**Critères :**
- [ ] `FavoriteButton` (animation, vibration légère, action VoiceOver) ; glisser pour ajouter depuis la liste.
- [ ] Favoris stockés sur l'appareil, sans compte.
- [ ] Mes festivals (E9) : carte « Prochain », à venir, passés, état vide.

**Dépendances :** STORY-015

#### STORY-019 : Timetable et conflits

**Epic :** EPIC-003 · **Priorité :** Must · **Points :** 5

**Critères :**
- [ ] Liste par jour et par scène (E6) ; cocher ☆/★ ; filtre « Moi » ; mention « Maintenant ».
- [ ] Conflits détectés dans `EFDomain`, testés (chevauchements, minuit passé).
- [ ] « Horaire modifié » affiché quand la donnée change.

**Dépendances :** STORY-015

#### STORY-020 : Rappels de concerts

**Epic :** EPIC-003 · **Priorité :** Must · **Points :** 3

**Critères :**
- [ ] Notification locale 15 min avant (délai réglable).
- [ ] Les 64 rappels les plus proches sont programmés ; reprogrammation à chaque ouverture (test unitaire du choix).
- [ ] Marche sans réseau.

**Dépendances :** STORY-019

#### STORY-021 : Authentification dans le Worker

**Epic :** EPIC-003 · **Priorité :** Must · **Points :** 8

**Critères :**
- [ ] Better Auth sur D1 : Sign in with Apple (jeton natif) et code par e-mail (Resend).
- [ ] Suppression du compte et de ses données ; sessions de 30 jours.
- [ ] Limitation de débit sur l'envoi de codes ; tests Vitest.

**Dépendances :** STORY-009

#### STORY-022 : Connexion et Profil dans l'app

**Epic :** EPIC-003 · **Priorité :** Must · **Points :** 5

**Critères :**
- [ ] Feuille de connexion (E13) : Apple et e-mail avec code ; erreurs de P6.
- [ ] Jeton dans le trousseau.
- [ ] Profil (E12) : compte, déconnexion, suppression du compte.

**Dépendances :** STORY-021

#### STORY-023 : Synchronisation

**Epic :** EPIC-003 · **Priorité :** Must · **Points :** 8

**Critères :**
- [ ] `GET/PUT /v1/me/sync` : favoris, concerts cochés, préférences ; le plus récent gagne.
- [ ] À la première connexion, les favoris locaux sont envoyés.
- [ ] Les changements hors ligne partent au retour du réseau ; tests des conflits.

**Dépendances :** STORY-018, STORY-019, STORY-022

#### STORY-024 : Appareils et préférences de notification

**Epic :** EPIC-003 · **Priorité :** Must · **Points :** 3

**Critères :**
- [ ] Feuille « Ne rate rien » au premier favori (P5), puis demande iOS.
- [ ] `PUT /v1/devices/{token}` avec rubriques et festivals suivis, sans compte obligatoire.
- [ ] Réglages par type de notification ; « Ouvrir Réglages » si refusé.

**Dépendances :** STORY-009, STORY-018

#### STORY-025 : Notifications des favoris

**Epic :** EPIC-003 · **Priorité :** Must · **Points :** 5

**Critères :**
- [ ] Tâche planifiée toutes les 15 min : compare le manifeste avec l'état précédent.
- [ ] Notifie : programmation publiée, horaires modifiés, J-7, J-1 ; seulement les appareils qui suivent ce festival.
- [ ] Toucher la notification ouvre le bon écran.

**Dépendances :** STORY-024, STORY-006

### EPIC-004 : contenus éditoriaux

#### STORY-026 : Articles

**Epic :** EPIC-004 · **Priorité :** Must · **Points :** 5

**Critères :**
- [ ] `RSSArticleSource` lit `/feed/` ; rubriques du site.
- [ ] Liste (E10) avec badge « Sponsorisé » ; lecture (E11) avec crédits photo, partage, « Lire sur le site ».

**Dépendances :** STORY-003

#### STORY-027 : Notifications d'articles

**Epic :** EPIC-004 · **Priorité :** Must · **Points :** 3

**Critères :**
- [ ] La tâche planifiée détecte les nouveaux articles du flux RSS.
- [ ] Notification par rubrique choisie ; « Programmations » activée par défaut, rien d'autre.

**Dépendances :** STORY-024, STORY-026

#### STORY-028 : Accueil

**Epic :** EPIC-004 · **Priorité :** Must · **Points :** 3

**Critères :**
- [ ] E1 : à la une, programmations, ce week-end (ou ce mois-ci), derniers articles.
- [ ] Carrousels transformés en listes aux tailles de texte d'accessibilité.

**Dépendances :** STORY-011, STORY-017, STORY-026

#### STORY-029 : Encart rédaction et « À propos »

**Epic :** EPIC-004 · **Priorité :** Could · **Points :** 1

**Critères :**
- [ ] Encart « Tu vis les festivals de l'intérieur ? » vers la page Recrutements ; section « À propos » du Profil.

**Dépendances :** STORY-022

### Transverse

#### STORY-030 : Mesure d'audience anonyme

**Priorité :** Should (FR-026) · **Points :** 3

**Critères :**
- [ ] `POST /v1/events` vers Analytics Engine ; aucun identifiant d'utilisateur ni d'appareil.
- [ ] Envoi par lots depuis l'app ; respect du consentement.

**Dépendances :** STORY-009, STORY-016

#### STORY-031 : Accessibilité et finitions

**Priorité :** Must · **Points :** 3

**Critères :**
- [ ] `performAccessibilityAudit()` sans erreur sur E2, E5, E6, E9.
- [ ] Taille AX3 sans texte coupé ; « Réduire les animations » respecté.

#### STORY-032 : Confidentialité

**Priorité :** Must · **Points :** 3

**Critères :**
- [ ] `PrivacyInfo.xcprivacy`, politique de confidentialité publiée, étiquettes App Store préparées.
- [ ] `GET /v1/me/export` (export RGPD) accessible depuis le Profil.

**Dépendances :** STORY-022

#### STORY-033 : Chaîne TestFlight

**Priorité :** Must · **Points :** 3

**Critères :**
- [ ] Signature avec le compte Apple personnel ; app créée dans App Store Connect.
- [ ] Envoi TestFlight déclenché à la main depuis la CI (ou en local avec `asc`).
- [ ] Groupe de testeurs internes créé.

**Dépendances :** STORY-001

#### STORY-034 : Soumission App Store

**Priorité :** Must · **Points :** 3

**Critères :**
- [ ] Fiche App Store (texte, captures, mots-clés), classification, confidentialité.
- [ ] Version soumise ; retours de la bêta corrigés.

**Dépendances :** toutes les stories du MVP

---

## Répartition par sprint

### Sprint 1 (30 nov. → 13 déc. 2026) : 20 / 24 points

**Objectif :** l'app démarre aux couleurs du site, sur données de démo, avec une CI verte ; on sait si les notifications Apple partent depuis un Worker.

- STORY-001 Monorepo, Xcode, CI (5)
- STORY-002 Design system (5)
- STORY-003 Domaine, interfaces, mocks (5)
- STORY-009 Worker de base et essai APNs (5)

**Risque :** essai APNs négatif → prévoir le repli FCM dans le sprint 2.

### Sprint 2 (14 → 27 déc.) : 14 / 16 points (fêtes)

**Objectif :** une première version TestFlight montre la liste des festivals de démo.

- STORY-010 Navigation et états communs (3)
- STORY-011 Liste des festivals (5)
- STORY-004 Contrats de l'instantané (3)
- STORY-033 Chaîne TestFlight (3)

### Sprint 3 (28 déc. → 10 janv. 2027) : 20 / 24 points

**Objectif :** trouver un festival : filtres, autour de moi, carte, fiche, billetterie.

- STORY-012 Recherche et filtres (5)
- STORY-013 Autour de moi (3)
- STORY-014 Carte (5)
- STORY-015 Fiche festival (5)
- STORY-016 Lien billetterie (2)

### Sprint 4 (11 → 24 janv.) : 20 / 24 points

**Objectif :** l'app lit les vraies données ouvertes, mises à jour chaque nuit, et garde des favoris.

- STORY-005 Pipeline de l'instantané (5)
- STORY-006 MusicBrainz et publication nocturne (5)
- STORY-007 Sources instantané et cache (5)
- STORY-018 Favoris et Mes festivals (5)

### Sprint 5 (25 janv. → 7 févr.) : 21 / 24 points

**Objectif :** le jour J et la lecture : timetable, rappels, hors ligne, programmations, articles.

- STORY-019 Timetable et conflits (5)
- STORY-020 Rappels de concerts (3)
- STORY-008 Fiches favorites hors ligne (3)
- STORY-017 Programmations et artiste (5)
- STORY-026 Articles (5)

### Sprint 6 (8 → 21 févr.) : 21 / 24 points

**Objectif :** compte et synchronisation sur plusieurs appareils.

- STORY-021 Authentification Worker (8)
- STORY-022 Connexion et Profil (5)
- STORY-023 Synchronisation (8)

**Risque :** deux stories à 8 points ; si l'une glisse, STORY-023 passe au sprint 7.

### Sprint 7 (22 févr. → 7 mars) : 18 / 24 points

**Objectif :** notifications utiles, accueil complet, mesure d'audience.

- STORY-024 Appareils et préférences (3)
- STORY-025 Notifications des favoris (5)
- STORY-027 Notifications d'articles (3)
- STORY-028 Accueil (3)
- STORY-029 Encart rédaction (1)
- STORY-030 Mesure d'audience (3)

### Sprint 8 (8 → 21 mars) : 6 / 24 points + marge

**Objectif :** bêta prête pour les membres : accessibilité, confidentialité, corrections.

- STORY-031 Accessibilité (3)
- STORY-032 Confidentialité (3)
- Marge : reprise des stories glissées et corrections.

**Jalon :** bêta TestFlight ouverte aux membres le 22 mars 2027.

### Sprint 9 (22 mars → 4 avril) : 3 points + retours de bêta

**Objectif :** soumettre à l'App Store avant la saison.

- STORY-034 Soumission App Store (3)

---

## Phase 2 et 3 (après la sortie, non planifiées)

| Story | Epic | Points | FR |
|---|---|---|---|
| STORY-035 Abonnement StoreKit 2 et écran d'offre | EPIC-005 | 8 | FR-014 |
| STORY-036 Vérification serveur des achats et notifications Apple | EPIC-005 | 8 | FR-014 |
| STORY-037 Programmations en avance (API premium) | EPIC-005 | 5 | FR-015 |
| STORY-038 Suivre des artistes à la main | EPIC-005 | 3 | FR-016 |
| STORY-039 Import Apple Music | EPIC-005 | 5 | FR-016 |
| STORY-040 Notification « artiste annoncé » | EPIC-005 | 3 | FR-016 |
| STORY-041 Festival autour de moi (sur l'appareil) | EPIC-005 | 5 | FR-017 |
| STORY-042 Réductions premium | EPIC-005 | 3 | FR-018 |
| STORY-043 Fiche partenaire (blocs, thème, contraste) | EPIC-006 | 8 | FR-019 |
| STORY-044 Mises en avant datées | EPIC-006 | 3 | FR-020 |
| STORY-045 Messages jour J (admin) | EPIC-006 | 5 | FR-021 |
| STORY-046 Concours : liste, règlement, participation, entrées en plus | EPIC-006 | 5 | FR-022 |
| STORY-047 Tirage serveur et résultat | EPIC-006 | 3 | FR-022 |
| STORY-048 Export des statistiques partenaires | EPIC-006 | 3 | FR-026 |
| STORY-049 Météo (WeatherKit) | EPIC-002 | 3 | FR-004 |
| STORY-050 Comptes photographes et galeries | EPIC-007 | 8 | FR-023 |
| STORY-051 Photos par QR code | EPIC-007 | 8 | FR-024 |
| STORY-052 Passeport et badges | EPIC-007 | 5 | FR-025 |

**Prérequis de la phase 2 :** avis juridique sur les concours, prix du premium.

---

## Traçabilité

### Epics

| Epic | Stories | Points | Sprints |
|---|---|---|---|
| EPIC-001 Socle et sources | 001-010 | 44 | 1-5 |
| EPIC-002 Découverte | 011-017 | 30 | 2-5 |
| EPIC-003 Compte et jour J | 018-025 | 42 | 4-7 |
| EPIC-004 Articles | 026-029 | 12 | 5-7 |
| Transverse | 030-034 | 15 | 2, 7-9 |
| EPIC-005 Premium et artistes | 035-042 | 40 | Phase 2 |
| EPIC-006 Partenaires | 043-048 | 27 | Phase 2 |
| EPIC-007 Photos et passeport | 050-052 | 21 | Phase 3 |

### Exigences

| FR | Stories | Sprint |
|---|---|---|
| FR-001 Liste | 011 | 2 |
| FR-002 Filtres | 012, 013 | 3 |
| FR-003 Carte | 014 | 3 |
| FR-004 Fiche | 015, 008 | 3, 5 |
| FR-005 Billetterie | 016 | 3 |
| FR-006 Programmations | 017 | 5 |
| FR-007 Compte | 021, 022 | 6 |
| FR-008 Favoris | 018, 023 | 4, 6 |
| FR-009 Timetable | 019, 020 | 5 |
| FR-010 Notifs favoris | 024, 025 | 7 |
| FR-011 Articles | 026 | 5 |
| FR-012 Notifs articles | 027 | 7 |
| FR-013 Rédaction | 029 | 7 |
| FR-014 à FR-025 | 035-052 | Phases 2-3 |
| FR-026 Mesure | 030, 048 | 7, phase 2 |

Toutes les NFR « Must » sont couvertes par EPIC-001, STORY-031 et STORY-032.

---

## Risques

**Élevés**
- Notifications APNs depuis un Worker → essai au sprint 1, repli FCM.
- Temps bénévole variable → capacité recalée après chaque sprint ; les stories « Could » sautent en premier.

**Moyens**
- Données ouvertes incomplètes (pas de dates ni de programmations) → 5 festivals de démo écrits à la main.
- Deux stories à 8 points au sprint 6 → STORY-023 peut glisser au sprint 7.
- Validation Apple (connexion, suppression du compte, confidentialité) → STORY-032 et STORY-034 suivent les règles d'Apple.

**Faibles**
- Limites de MusicBrainz → appels dans le pipeline seulement.

## Dépendances externes

- Compte Apple Developer personnel (actif).
- Compte Cloudflare (Workers, D1, R2), clé APNs (.p8), compte Resend.
- Contenus des 5 festivals de démo (à choisir).

---

## Définition de « terminé »

- [ ] Tests unitaires écrits avant le code pour la logique (`EFDomain`, `EFData`, API, pipeline), et verts.
- [ ] CI verte (build, tests, SwiftLint, recherche de secrets).
- [ ] PR relue puis fusionnée ; pas de push direct sur `main`.
- [ ] Aperçus SwiftUI en clair, en sombre et en AX3 pour chaque écran touché.
- [ ] Critères d'acceptation vérifiés dans le simulateur ou sur appareil.
- [ ] Documentation à jour si le comportement ou l'architecture change.

---

## Prochaines étapes

- Lancer le sprint 1 avec STORY-001 (`/dev-story STORY-001`).
- Rituels légers : bilan de sprint le dimanche de fin de sprint (démo TestFlight, vitesse réelle, ajustement de la capacité).

---

*Créé avec la méthode BMAD v6, phase 4 (planification de l'implémentation).*

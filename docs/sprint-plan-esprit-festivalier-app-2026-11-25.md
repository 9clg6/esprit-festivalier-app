# Sprint Plan : Esprit Festivalier App

**Date :** 2026-11-25
**Scrum master :** clement
**Niveau de projet :** 3
**Stories MVP :** 44 (179 points) · **Phase 2 et 3 :** 19 stories (96 points), non planifiées · **Plus tard :** 3 stories (6 points)
**Sprints planifiés :** 10 (du 2026-11-30 au 2027-04-18)
**Mise à jour :** 2026-11-25, application complète (STORY-053 à STORY-066, ADR-007, décisions de Clément du même jour)

---

## Résumé

Le MVP (epics 1 à 4) se construit en 9 sprints de deux semaines. La bêta TestFlight pour les membres s'ouvre le 22 mars 2027 ; la soumission App Store se fait au sprint 10, avant le 1er mai. TestFlight est branché dès le sprint 2 : chaque sprint envoie une version testable.

**Chiffres clés :**
- Capacité : **24 points par sprint** (hypothèse : 1 développeur bénévole aidé par des agents ; 1 point ≈ 1 à 2 h). On vise environ 20 points, et 14 pendant les fêtes.
- MVP : 179 points (143 + 36 pour l'application complète).
- Fin prévue : bêta le 22 mars 2027, App Store mi-avril 2027.
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
- [ ] Barre à 5 onglets ; routes pour les adresses du site `/festival/<slug>/` et `/<slug>-<numéro>/` (article). Liens universels : plus tard (FR-034).
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
- [ ] Liste (E10) avec badge « Sponsorisé » ; lecture (E11) de l'extrait du flux, avec partage. Le texte complet arrive avec STORY-055 : plus de « Lire sur le site ».

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

### EPIC-004 (suite) : application complète (ADR-007)

« Mock first » : chaque source a sa version `mock` dès la première story ; seules STORY-054, 057, 059 et 062 lisent le vrai site, et les réactions restent sur l'appareil jusqu'au serveur (STORY-061).

#### STORY-053 : Lecteur HTML tolérant et modèle en blocs

**Epic :** EPIC-004 · **Priorité :** Must (FR-027) · **Points :** 5

**En tant que** développeur, **je veux** transformer le HTML d'un article en blocs typés, **afin de** l'afficher en natif.

**Critères :**
- [ ] `ArticleContent`, `ArticleBlock`, `InlineRun` dans `EFDomain` ; `ArticleContentSource` et `MockArticleContentSource`.
- [ ] `HTMLReader` dans `EFData` : balises, texte, entités (décodeur commun avec `RSSArticleSource`), éléments vides, fermetures implicites, `script`/`style`/`svg` sautés.
- [ ] Tests sur des cas limites (balise non fermée, entité inconnue, fermeture orpheline) ; aucun plantage sur un HTML tronqué.

**Dépendances :** STORY-026

#### STORY-054 : Source « page du site » et cache

**Epic :** EPIC-004 · **Priorité :** Must (FR-027, FR-011) · **Points :** 5

**Critères :**
- [ ] `SiteTemplate.v1` : tous les repères en un seul endroit, avec `parserVersion`.
- [ ] Métadonnées depuis le JSON-LD ; corps de `div.article-body` à `div.read-end` ; légendes, festival, bloc auteur, connexes, sponsorisé.
- [ ] Fixtures dorées : 5 extraits réels, comparés à un JSON attendu.
- [ ] `CachedArticleContentSource` : copie disque d'abord, rechargement après 1 h, 100 articles au plus.
- [ ] Seules les adresses `https://esprit-festivalier.fr/` sont téléchargées.

**Dépendances :** STORY-053

#### STORY-055 : Lecteur natif (E11)

**Epic :** EPIC-004 · **Priorité :** Must (FR-027) · **Points :** 5

**Critères :**
- [ ] Rendu de chaque bloc selon l'UX (E11) ; images pleine largeur avec crédit ; plein écran zoomable au toucher.
- [ ] Contenus tiers en carte, chargés seulement au toucher.
- [ ] Échec : extrait, message, « Réessayer » ; « Ouvrir sur le site ↗ » seulement après un échec de lecture.
- [ ] Plus de « Lire l'article complet » ; aperçus clair, sombre et AX3 sur la source `mock`.

**Dépendances :** STORY-054

#### STORY-056 : Liens internes

**Epic :** EPIC-004 · **Priorité :** Must (FR-028) · **Points :** 3

**Critères :**
- [ ] `SiteLink` classe les adresses du site ; tests sur toutes les adresses des fixtures.
- [ ] `OpenURLAction` du lecteur : article, festival connu, auteur, artiste connu, rubrique → écran de l'app ; lien tiers → feuille Safari.
- [ ] Nouvelle route par adresse d'article (liens internes, plus tard notifications et liens universels).

**Dépendances :** STORY-055

#### STORY-057 : Auteurs (E16)

**Epic :** EPIC-004 · **Priorité :** Must (FR-029) · **Points :** 5

**Critères :**
- [ ] `AuthorSource`, `SitePageAuthorSource` (lecteur de cartes partagé), `MockAuthorSource`.
- [ ] E16 : avatar ou initiales, nom, présentation venue de l'article, nombre d'articles, liste paginée.
- [ ] Liens depuis la signature, le bloc auteur et les crédits photo qui nomment un auteur connu (`KnownAuthors`, tests sur les légendes réelles).
- [ ] Vérifier la pagination sur un auteur qui a plusieurs pages d'articles.

**Dépendances :** STORY-056

#### STORY-058 : Réactions sur l'appareil (mock first)

**Epic :** EPIC-004 · **Priorité :** Must (FR-030) · **Points :** 3

**Critères :**
- [ ] `ReactionService` et `LocalReactionService` (Application Support).
- [ ] `ReactionBar` en fin d'article : 5 réactions, états de l'UX, sans compte.
- [ ] Pas de compteur en bêta ; compteurs de démo et `DemoCaption` avec la source `mock`.
- [ ] Réactions comprises dans l'export local des données.

**Dépendances :** STORY-055

#### STORY-059 : Pages liste et articles d'un festival

**Epic :** EPIC-004 · **Priorité :** Must (FR-032) · **Points :** 3

**Critères :**
- [ ] D'abord : vérifier la structure des pages `/festival/<slug>/`, `/artiste/<slug>/`, `/tag/<slug>/` et `/category/<slug>/`.
- [ ] Lecteur de cartes réutilisé ; un écran « liste d'articles » générique.
- [ ] Section « Articles » sur la fiche festival ; « Lire sur Esprit Festivalier ↗ » supprimé.

**Dépendances :** STORY-057

#### STORY-060 : Garde-fou du gabarit

**Epic :** EPIC-004 · **Priorité :** Must · **Points :** 2

**Critères :**
- [ ] Job GitHub Actions chaque nuit : lit les 3 derniers articles du flux avec le lecteur (`swift test` sur une cible dédiée, sans simulateur).
- [ ] E-mail d'alerte si le titre, le corps ou l'auteur manque.

**Dépendances :** STORY-054

#### STORY-062 : Archives par rubrique

**Epic :** EPIC-004 · **Priorité :** Must (FR-031) · **Points :** 3

**Critères :**
- [ ] D'abord : vérifier la pagination des pages `/category/<slug>/`.
- [ ] Au bout des articles du flux, la liste d'une rubrique charge les pages suivantes (lecteur de cartes) ; aucun doublon (clé d'article).
- [ ] Source `mock` paginée pour les tests et les aperçus.

**Dépendances :** STORY-059

#### STORY-066 : Lectures d'articles comptées (mock first)

**Epic :** EPIC-004 · **Priorité :** Must (FR-036) · **Points :** 2

**Critères :**
- [ ] Événement `article_view` (clé de l'article, jour) au premier affichage du texte complet ; au plus un par article et par jour sur l'appareil (test unitaire).
- [ ] Aucun identifiant d'utilisateur ni d'appareil ; respect du choix de mesure d'audience.
- [ ] Rangé dans la file d'événements locale ; envoyé plus tard par STORY-030 vers Analytics Engine.

**Dépendances :** STORY-055

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

### Sprint 7 (22 févr. → 7 mars) : 23 / 24 points

**Objectif :** notifications utiles, accueil complet, mesure d'audience.

- STORY-024 Appareils et préférences (3)
- STORY-025 Notifications des favoris (5)
- STORY-027 Notifications d'articles (3)
- STORY-028 Accueil (3)
- STORY-029 Encart rédaction (1)
- STORY-030 Mesure d'audience (3)
- STORY-053 Lecteur HTML et modèle en blocs (5) — ajout v1.1, le sprint passe à 23 / 24 points

### Sprint 8 (8 → 21 mars) : 19 / 24 points

**Objectif :** bêta prête pour les membres, avec les articles complets dans l'app.

- STORY-031 Accessibilité (3)
- STORY-032 Confidentialité (3)
- STORY-054 Source « page du site » et cache (5)
- STORY-055 Lecteur natif E11 (5)
- STORY-056 Liens internes (3)

**Jalon :** bêta TestFlight ouverte aux membres le 22 mars 2027.

**Risque :** la marge de reprise passe de 18 à 5 points.

### Sprint 9 (22 mars → 4 avril) : 18 / 24 points + retours de bêta

**Objectif :** auteurs, réactions, pages liste et archives, lectures comptées ; le gabarit du site est surveillé.

- STORY-057 Auteurs (5)
- STORY-058 Réactions sur l'appareil (3)
- STORY-059 Pages liste et articles d'un festival (3)
- STORY-060 Garde-fou du gabarit (2)
- STORY-062 Archives par rubrique (3)
- STORY-066 Lectures d'articles comptées (2)

### Sprint 10 (5 → 18 avril) : 3 points + retours de bêta

**Objectif :** soumettre à l'App Store avant la saison.

- STORY-034 Soumission App Store (3)

**Risque :** la soumission recule de deux semaines ; il reste moins de deux semaines avant le 1er mai (O2). Le code est déjà en avance sur ce plan (timetable, rappels, favoris hors ligne et compte de démo livrés) : le recalage après le sprint 1 peut rendre ces deux semaines.

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
| STORY-061 Réactions sur le serveur : routes du Worker, table D1, limitation de débit, synchronisation | EPIC-004 | 5 | FR-030 |

**Après le serveur :** STORY-061 suppose STORY-021 et STORY-023 en vrai (aujourd'hui, compte et synchronisation sont des mocks).

### Plus tard (décision du 2026-11-25, non planifiées)

| Story | Points | FR |
|---|---|---|
| STORY-063 À lire plus tard, hors ligne | 3 | FR-033 |
| STORY-064 Liens universels (`/<slug>-<numéro>/`, `/festival/<slug>/`, `/author/<slug>/` ; demande le fichier `apple-app-site-association` sur le site) | 2 | FR-034 |
| STORY-065 À propos natif | 1 | FR-035 |

**Prérequis de la phase 2 :** avis juridique sur les concours, prix du premium.

---

## Traçabilité

### Epics

| Epic | Stories | Points | Sprints |
|---|---|---|---|
| EPIC-001 Socle et sources | 001-010 | 44 | 1-5 |
| EPIC-002 Découverte | 011-017 | 30 | 2-5 |
| EPIC-003 Compte et jour J | 018-025 | 42 | 4-7 |
| EPIC-004 Articles | 026-029, 053-060, 062, 066 | 48 | 5-9 |
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
| FR-027 Article complet | 053, 054, 055 | 7, 8 |
| FR-028 Liens internes | 056 | 8 |
| FR-029 Auteurs | 057 | 9 |
| FR-030 Réactions | 058, 061 | 9, après le serveur |
| FR-031 Archives | 062 | 9 |
| FR-032 Pages liste | 059 | 9 |
| FR-033 à FR-035 (plus tard) | 063-065 | Non planifiées |
| FR-036 Lectures comptées | 066, 030 | 9, 7 |
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
- Gabarit du site modifié sans prévenir → repères dans `SiteTemplate`, garde-fou nocturne (STORY-060), repli sur l'extrait.

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

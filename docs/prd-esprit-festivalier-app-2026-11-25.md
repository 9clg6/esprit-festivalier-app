# PRD : Esprit Festivalier App

**Date :** 2026-11-25
**Auteur :** clement
**Version :** 1.1 (application complète, 2026-11-25)
**Type de projet :** mobile-app (iOS Swift d'abord, Android Kotlin ensuite)
**Niveau de projet :** 3
**Statut :** Brouillon

---

## Présentation

Ce document fixe les exigences fonctionnelles et non fonctionnelles de l'app et les regroupe en epics. Il sert de référence pour l'architecture et le découpage en stories.

**Documents liés :**
- Product brief (validé) : `docs/product-brief-esprit-festivalier-app-2026-11-25.md`
- Brainstorm : `docs/brainstorm-esprit-festivalier-app-2026-11-25.md`
- Direction artistique : `docs/design/direction-artistique.md`

**Décisions prises depuis le brief (2026-11-25) :**
- **Données :** pas d'API du back-office pour l'instant. L'app tourne sur des **données de démonstration** (mocks) et des **API ouvertes**. L'architecture doit permettre de changer de source sans toucher aux écrans (NFR-008).
- **Diffusion :** TestFlight sur le compte Apple Developer personnel de Clément Guyon, pas sur un compte de l'association.
- **Jeux concours :** gratuits pour tous, entrées en plus pour les premium. À confirmer par un juriste, plus tard.
- **Application complète (Clément, 2026-11-25) :** l'app n'est pas un prolongement du site. Articles lus en entier, réactions, pages des auteurs ; aucune fonction ne renvoie simplement vers esprit-festivalier.fr. Restent à l'extérieur : billetterie, itinéraire, partage, réglages, contenus tiers. Voir FR-027 à FR-035 et l'ADR-007 de l'architecture.

---

## Résumé

App compagnon gratuite des festivaliers, faite par le média associatif Esprit Festivalier : trouver un festival, suivre programmations et artistes, préparer et vivre le jour J, lire les articles. Un premium et des offres pour les festivals la financent. Pas de vente de billets.

---

## Objectifs

### Objectifs

- **O1 :** une bêta TestFlight utilisable pendant un festival (découverte, fiches, favoris, timetable, articles) d'ici fin mars 2027.
- **O2 :** une sortie sur l'App Store avant le 1er mai 2027.
- **O3 :** des arguments chiffrés pour vendre les offres partenaires (favoris, vues, clics billetterie).
- **O4 :** un revenu récurrent (premium, partenaires) dès la saison 2027.

### Indicateurs

- Comptes créés, utilisateurs actifs par mois, part avec notifications activées.
- Favoris par utilisateur ; clics vers les billetteries par festival.
- Taux de passage au premium ; nombre de festivals partenaires.
- Taux d'ouverture des notifications d'articles.

---

## Exigences fonctionnelles

Priorités (MoSCoW) : **Must** = MVP (phase 1), **Should** = phase 2, **Could** = phase 3.

---

### Découverte des festivals

### FR-001 : Liste des festivals

**Priorité :** Must

**Description :** l'utilisateur voit la liste des festivals à venir, triée par date de début, avec nom, dates, ville, genre et visuel.

**Critères d'acceptation :**
- [ ] Les festivals passés n'apparaissent pas par défaut.
- [ ] Chaque ligne affiche nom, dates, ville, genre et visuel (ou un visuel par défaut).
- [ ] La liste charge par pages, sans blocage au défilement.

### FR-002 : Filtres et recherche

**Priorité :** Must

**Description :** l'utilisateur filtre par région ou distance, par période (ce week-end, ce mois-ci, dates précises) et par genre, et cherche par nom.

**Critères d'acceptation :**
- [ ] Les filtres se combinent ; leur nombre actif est affiché.
- [ ] Le filtre « autour de moi » ne demande la position qu'au moment où on l'active.
- [ ] Un résultat vide propose d'élargir les filtres.

**Dépendances :** FR-001

### FR-003 : Carte des festivals

**Priorité :** Must

**Description :** les festivals filtrés apparaissent sur une carte ; un point ouvre un aperçu, puis la fiche.

**Critères d'acceptation :**
- [ ] La carte respecte les filtres de FR-002.
- [ ] Les points proches se regroupent quand on dézoome.
- [ ] Toucher un aperçu ouvre la fiche (FR-004).

**Dépendances :** FR-002

### FR-004 : Fiche festival

**Priorité :** Must

**Description :** la fiche montre dates, lieu (carte et itinéraire), description, programmation, timetable si connue, infos pratiques (accès, navettes, objets interdits) et liens externes (site, réseaux).

**Critères d'acceptation :**
- [ ] Une section vide est masquée, jamais affichée vide.
- [ ] « Itinéraire » ouvre Plans avec l'adresse du festival.
- [ ] Les articles du site liés au festival apparaissent en bas de fiche (FR-011).

**Dépendances :** FR-001

### FR-005 : Lien billetterie suivi

**Priorité :** Must

**Description :** un bouton « Billets » ouvre la billetterie officielle à l'extérieur de l'app, avec des paramètres de suivi. L'app ne vend jamais de billets.

**Critères d'acceptation :**
- [ ] Le lien s'ouvre dans le navigateur, avec des paramètres UTM `utm_source=esprit-festivalier-app`.
- [ ] Chaque clic est compté par festival (FR-026).
- [ ] Sans lien connu, le bouton n'apparaît pas.

**Dépendances :** FR-004

### FR-006 : Programmations

**Priorité :** Must

**Description :** une rubrique liste les programmations annoncées (festival, date d'annonce, artistes), de la plus récente à la plus ancienne.

**Critères d'acceptation :**
- [ ] Chaque programmation renvoie à la fiche du festival.
- [ ] Un artiste de la programmation ouvre sa page (FR-016).

---

### Compte et personnalisation

### FR-007 : Compte gratuit

**Priorité :** Must

**Description :** l'utilisateur crée un compte avec « Se connecter avec Apple » ou un e-mail. La découverte reste accessible sans compte.

**Critères d'acceptation :**
- [ ] Sans compte : liste, carte, fiches et articles accessibles.
- [ ] La connexion est demandée seulement pour une action qui l'exige (favori, concours, synchronisation).
- [ ] L'utilisateur peut supprimer son compte depuis l'app (exigence Apple).

### FR-008 : Festivals favoris

**Priorité :** Must

**Description :** l'utilisateur ajoute ou retire un festival de ses favoris ; il les retrouve dans un onglet dédié.

**Critères d'acceptation :**
- [ ] Le favori marche sans compte (stocké sur l'appareil) ; il est synchronisé une fois connecté.
- [ ] Un favori est disponible hors ligne (NFR-003).

**Dépendances :** FR-004

### FR-009 : Ma timetable

**Priorité :** Must

**Description :** sur la timetable d'un festival, l'utilisateur coche des concerts ; l'app montre les conflits entre scènes et envoie un rappel avant chaque concert coché.

**Critères d'acceptation :**
- [ ] Deux concerts qui se chevauchent sont signalés.
- [ ] Le rappel part 15 min avant (délai réglable), même hors ligne (notification locale).
- [ ] Un changement d'horaire publié met la timetable à jour et prévient l'utilisateur.

**Dépendances :** FR-004, FR-008

### FR-010 : Notifications des favoris

**Priorité :** Must

**Description :** l'utilisateur est prévenu quand un festival favori publie sa programmation, change ses horaires ou approche (J-7, J-1).

**Critères d'acceptation :**
- [ ] L'autorisation de notifier est demandée après le premier favori, pas au lancement.
- [ ] Chaque type de notification se coupe dans les réglages.

**Dépendances :** FR-008

---

### Contenus éditoriaux

### FR-011 : Articles du site

**Priorité :** Must

**Description :** l'app liste les articles du site par rubrique (live reports, interviews, actus, guides, décryptages, chroniques) et les affiche **en entier, dans l'app** (FR-027).

**Critères d'acceptation :**
- [ ] Les rubriques correspondent à celles du site.
- [ ] Un article garde son crédit photo et son auteur.
- [ ] Un contenu sponsorisé est marqué comme tel.
- [ ] « Partager » donne le lien de l'article sur le site.
- [ ] Aucun bouton « Lire sur le site » ni « Lire l'article complet » : le texte complet est dans l'app.

**Changement (v1.1) :** la lecture se faisait sur l'extrait du flux, puis dans Safari. Elle passe dans l'app (FR-027) ; le crédit photo et la marque « sponsorisé », absents du flux, viennent de la page de l'article.

### FR-012 : Notifications d'articles

**Priorité :** Must

**Description :** l'utilisateur choisit les rubriques dont il veut être prévenu à chaque nouvel article.

**Critères d'acceptation :**
- [ ] Aucune rubrique activée par défaut, sauf « Programmations ».
- [ ] Toucher la notification ouvre l'article.

**Dépendances :** FR-011

### FR-013 : Rejoindre la rédaction

**Priorité :** Could

**Description :** un encart « Tu vis les festivals de l'intérieur ? » renvoie à la page Recrutements du site.

**Critères d'acceptation :**
- [ ] L'encart s'ouvre dans le navigateur.

---

### Premium

### FR-014 : Abonnement premium

**Priorité :** Should

**Description :** l'utilisateur souscrit au premium par achat intégré Apple, le gère et le résilie depuis les réglages d'Apple.

**Critères d'acceptation :**
- [ ] L'écran d'offre liste les avantages et le prix localisé.
- [ ] « Restaurer les achats » fonctionne.
- [ ] Le statut premium est vérifié côté serveur avant de débloquer un avantage.

**Dépendances :** FR-007

### FR-015 : Programmations en avance

**Priorité :** Should

**Description :** un premium voit une programmation avant sa publication générale, pendant une durée fixée avec le festival.

**Critères d'acceptation :**
- [ ] Un non-premium voit « Bientôt » et l'offre premium.
- [ ] À la date de publication générale, la programmation devient visible pour tous.

**Dépendances :** FR-006, FR-014

### FR-016 : Artistes suivis

**Priorité :** Should

**Description :** l'utilisateur suit des artistes, à la main ou en important ses artistes Apple Music ; il est prévenu quand un artiste suivi est annoncé dans un festival.

**Critères d'acceptation :**
- [ ] L'import Apple Music demande l'autorisation et marche sans abonnement Apple Music si l'API le permet ; sinon le choix manuel reste possible.
- [ ] La page artiste liste ses festivals à venir.
- [ ] Une annonce produit une seule notification par artiste et par festival.
- [ ] Spotify n'est pas requis en phase 2.

**Dépendances :** FR-006

### FR-017 : Festival autour de moi

**Priorité :** Should

**Description :** l'utilisateur qui l'accepte est prévenu quand un festival de ses genres préférés a lieu dans un rayon choisi.

**Critères d'acceptation :**
- [ ] Opt-in explicite, rayon réglable (25, 50, 100 km).
- [ ] La position est approximative et ne quitte pas l'appareil sans consentement (NFR-005).
- [ ] Au plus une notification de ce type par semaine.

**Dépendances :** FR-002

### FR-018 : Réductions premium

**Priorité :** Could

**Description :** un premium voit sur la fiche les réductions négociées et un code ou un lien pour en profiter sur la billetterie externe.

**Critères d'acceptation :**
- [ ] Le code n'est visible que pour un premium.
- [ ] L'usage est compté par festival (FR-026).

**Dépendances :** FR-005, FR-014

---

### Festivals partenaires

### FR-019 : Fiche partenaire enrichie

**Priorité :** Should

**Description :** un festival partenaire a une fiche à ses couleurs, composée de blocs configurables (bannière, vidéo, plan, FAQ, sponsors), sans code spécifique par festival.

**Critères d'acceptation :**
- [ ] Les couleurs et blocs viennent des données, pas du code.
- [ ] Le contraste reste lisible (NFR-006) même avec les couleurs du festival.
- [ ] La mention « Partenaire » est visible.

**Dépendances :** FR-004

### FR-020 : Mises en avant

**Priorité :** Should

**Description :** un partenaire peut avoir un encart sur l'accueil et une place mise en avant dans la liste, signalée comme telle.

**Critères d'acceptation :**
- [ ] L'encart et la mise en avant ont une date de début et de fin.
- [ ] Une mise en avant porte la mention « Mis en avant ».

**Dépendances :** FR-001, FR-019

### FR-021 : Messages jour J

**Priorité :** Should

**Description :** un partenaire envoie des messages aux utilisateurs qui l'ont en favori (changement d'horaire, météo, dernière navette).

**Critères d'acceptation :**
- [ ] Le message n'atteint que les utilisateurs qui ont ce festival en favori et les notifications activées.
- [ ] Un plafond de messages par jour évite le spam (valeur à fixer).
- [ ] En phase 2, l'équipe Esprit Festivalier envoie les messages pour le festival ; une interface pour les festivals viendra plus tard.

**Dépendances :** FR-010

---

### Jeux concours

### FR-022 : Participer à un concours

**Priorité :** Should

**Description :** l'utilisateur connecté participe gratuitement à un concours depuis sa page (lot, règlement, date de fin). Un premium a des entrées en plus. Le tirage se fait côté serveur.

**Critères d'acceptation :**
- [ ] Le règlement est accessible avant de participer.
- [ ] Une seule participation gratuite par compte ; le nombre d'entrées en plus des premium est fixé par concours.
- [ ] Aucune participation payante à l'unité (voir le brief, risque juridique).
- [ ] Le gagnant est prévenu dans l'app ; les autres voient le résultat.
- [ ] L'opt-in aux communications du festival est séparé et non coché.

**Dépendances :** FR-007, FR-014

---

### Photos et vidéos

### FR-023 : Galeries des photographes

**Priorité :** Could

**Description :** un photographe accrédité publie une galerie par festival, scène et jour ; chaque photo garde son crédit.

**Critères d'acceptation :**
- [ ] Seul un compte photographe validé peut publier.
- [ ] Une personne peut demander le retrait d'une photo ; la demande est traitée sous 72 h.

### FR-024 : Retrouver ses photos

**Priorité :** Could

**Description :** le festivalier montre un QR code personnel ; le photographe le scanne après la photo ; la photo arrive dans l'app du festivalier. Pas de reconnaissance faciale.

**Critères d'acceptation :**
- [ ] Le QR code se renouvelle et ne contient aucune donnée personnelle lisible.
- [ ] Le festivalier peut refuser ou supprimer une photo reçue.

**Dépendances :** FR-007, FR-023

---

### Engagement

### FR-025 : Passeport festivalier

**Priorité :** Could

**Description :** l'utilisateur valide sa présence à un festival (position sur le site ou QR sur place) et gagne des badges (festivals faits, saison, genres).

**Critères d'acceptation :**
- [ ] Une présence ne se valide que pendant les dates du festival.
- [ ] Les badges suivent la DA (sobres, pas d'effet « enfant »).

**Dépendances :** FR-007

---

### Statistiques

### FR-026 : Mesure d'audience par festival

**Priorité :** Should

**Description :** l'app mesure, par festival, les vues de fiche, les favoris, les clics billetterie et l'usage des réductions, de façon agrégée et anonyme, pour les bilans partenaires.

**Critères d'acceptation :**
- [ ] Aucun identifiant personnel dans les événements mesurés.
- [ ] Un export par festival et par période est possible.
- [ ] La mesure respecte le choix de l'utilisateur (NFR-005).

---

### Application complète (v1.1)

**Statut :** FR-027 à FR-030 découlent de la direction du 2026-11-25 ; FR-031 à FR-035 sont **proposées**, à valider par Clément.

### FR-027 : Article complet dans l'app

**Priorité :** Must

**Description :** l'article s'affiche en entier dans l'app, en natif : chapô, intertitres, paragraphes avec gras, italique et liens, images avec légende et crédit, citations, listes, « Lire aussi », contenus tiers en carte.

**Critères d'acceptation :**
- [ ] Le texte, les images et les légendes sont ceux de la page du site.
- [ ] Les images occupent toute la largeur ; le crédit est sous chaque photo.
- [ ] Un article déjà ouvert se relit hors ligne (images comprises tant que le cache les garde).
- [ ] Une vidéo ou un contenu tiers ne se charge qu'au toucher (NFR-005).
- [ ] Échec : l'extrait du flux, un message clair et « Réessayer » ; l'app n'ouvre jamais Safari d'elle-même.
- [ ] Source interchangeable (NFR-008) : page du site aujourd'hui, flux du site plus tard.

**Dépendances :** FR-011

### FR-028 : Liens internes dans l'app

**Priorité :** Must

**Description :** un lien vers le site dans un article (article, festival, auteur, artiste, rubrique, mot-clé) ouvre l'écran de l'app correspondant.

**Critères d'acceptation :**
- [ ] Article → lecture (FR-027) ; festival connu → fiche ; auteur → page auteur (FR-029) ; artiste connu → page artiste ; rubrique → Articles filtrés.
- [ ] Festival ou artiste hors catalogue, mot-clé → liste des articles de cette page (FR-032).
- [ ] Un lien vers un autre site s'ouvre dans une feuille Safari, signalé « site externe » pour VoiceOver.

**Dépendances :** FR-027

### FR-029 : Pages des auteurs

**Priorité :** Must

**Description :** la page d'un auteur montre son nom, son avatar (photo ou initiales), sa présentation si elle existe, ses liens s'il en a, le nombre d'articles et la liste de ses articles.

**Critères d'acceptation :**
- [ ] On l'ouvre depuis la signature, le bloc auteur en fin d'article et les cartes d'articles.
- [ ] Un crédit photo qui nomme un auteur connu ouvre sa page ; sinon il reste du texte.
- [ ] La liste charge la suite en bas de page.
- [ ] « Partager » donne le lien de la page auteur sur le site.

**Dépendances :** FR-027

### FR-030 : Réactions aux articles

**Priorité :** Must (sur l'appareil) ; compteurs partagés quand le serveur existe

**Description :** sous l'article, 5 réactions fixes (J'adore, Ça chauffe, Bravo, Waouh, Instructif). Une réaction active par utilisateur et par type ; toucher à nouveau la retire.

**Critères d'acceptation :**
- [ ] Réagir marche sans compte ; l'état est gardé sur l'appareil.
- [ ] Avant le serveur : pas de compteur en bêta ; compteurs de démo signalés « Données de démonstration » avec la source `mock`.
- [ ] Avec le serveur : compteurs partagés, un vote par votant, limitation de débit.
- [ ] Les réactions d'un compte sont comprises dans l'export et la suppression (NFR-005).
- [ ] Chaque réaction est un bouton VoiceOver avec son état (« J'adore, sélectionné, 12 »).

**Dépendances :** FR-027 ; FR-007 pour la synchronisation

### FR-031 : Archives par rubrique (proposée)

**Priorité :** Should

**Description :** au bout des articles du flux, la liste d'une rubrique continue avec les articles plus anciens du site.

**Critères d'acceptation :**
- [ ] « Charger plus » ou chargement en bas de liste, page par page.
- [ ] Aucun doublon avec les articles du flux.

**Dépendances :** FR-011, FR-032

### FR-032 : Pages liste du site dans l'app (proposée)

**Priorité :** Must

**Description :** les pages liste du site (festival, artiste, mot-clé, rubrique) s'affichent dans l'app comme listes d'articles. La fiche festival montre ses articles.

**Critères d'acceptation :**
- [ ] La fiche d'un festival montre ses derniers articles (critère de FR-004) et remplace « Lire sur Esprit Festivalier ».
- [ ] Même lecteur de cartes que les pages auteurs.

**Dépendances :** FR-027

### FR-033 : À lire plus tard (proposée)

**Priorité :** Should

**Description :** l'utilisateur garde un article pour plus tard ; il le relit hors ligne, images comprises.

**Critères d'acceptation :**
- [ ] Sans compte, sur l'appareil ; synchronisé une fois connecté.
- [ ] En mode avion, un article gardé s'affiche en entier.

**Dépendances :** FR-027

### FR-034 : Liens universels du site (proposée)

**Priorité :** Should

**Description :** un lien esprit-festivalier.fr (article, festival, auteur) ouvre l'app si elle est installée.

**Critères d'acceptation :**
- [ ] Le site publie `apple-app-site-association` (demande à l'équipe du site).
- [ ] Les pages sans écran dans l'app restent sur le site.

**Dépendances :** FR-028

### FR-035 : À propos natif (proposée)

**Priorité :** Could

**Description :** la page « À propos » est un écran de l'app, avec un texte relu par la rédaction.

**Critères d'acceptation :**
- [ ] Plus de feuille Safari pour « À propos ».

---

## Exigences non fonctionnelles

### NFR-001 : Performance — démarrage et navigation

**Priorité :** Must

**Description :** l'app est rapide sur un iPhone de 4 ans.

**Critères d'acceptation :**
- [ ] Premier écran affiché en moins de 2 s au démarrage à froid sur iPhone 12.
- [ ] Liste et carte défilent à 60 images par seconde avec 500 festivals.

**Justification :** l'app sert dans la file d'entrée, avec peu de patience et peu de réseau.

### NFR-002 : Performance — réseau faible

**Priorité :** Must

**Description :** l'app reste utilisable avec un réseau lent ou coupé.

**Critères d'acceptation :**
- [ ] Les données en cache s'affichent tout de suite, puis se mettent à jour en arrière-plan.
- [ ] Aucune requête ne bloque l'écran plus de 10 s ; une erreur propose de réessayer.

**Justification :** le réseau sature sur tous les festivals.

### NFR-003 : Fiabilité — hors ligne

**Priorité :** Must

**Description :** fiches des favoris, timetable personnelle, plan et rappels marchent sans réseau.

**Critères d'acceptation :**
- [ ] En mode avion, un favori ouvert au moins une fois s'affiche en entier, images comprises.
- [ ] Les rappels de la timetable partent sans réseau.

**Justification :** c'est le moment où l'app compte le plus.

### NFR-004 : Sécurité — comptes et paiements

**Priorité :** Must

**Description :** authentification standard, secrets hors du code, droits premium vérifiés côté serveur.

**Critères d'acceptation :**
- [ ] Aucun secret ni clé d'API dans le dépôt (le dépôt est public).
- [ ] Jetons stockés dans le trousseau iOS.
- [ ] Les reçus d'achat sont vérifiés côté serveur (App Store Server API).

**Justification :** dépôt public, paiements réels.

### NFR-005 : Vie privée — RGPD

**Priorité :** Must

**Description :** minimisation des données, consentements séparés, droits RGPD dans l'app.

**Critères d'acceptation :**
- [ ] Position, notifications, import musical et mesure d'audience ont chacun leur consentement.
- [ ] Export et suppression du compte depuis l'app.
- [ ] Étiquettes de confidentialité App Store et politique de confidentialité à jour.
- [ ] Pas de traceur publicitaire tiers.

**Justification :** goûts musicaux et position sont des données sensibles pour les utilisateurs.

### NFR-006 : Accessibilité

**Priorité :** Must

**Description :** l'app suit les règles d'accessibilité iOS.

**Critères d'acceptation :**
- [ ] VoiceOver lit chaque écran du MVP dans le bon ordre.
- [ ] Dynamic Type jusqu'à la taille maximale d'accessibilité sans texte coupé.
- [ ] Contraste au moins 4,5:1 (WCAG AA) en mode clair et sombre.

**Justification :** public large, usage en plein soleil ou de nuit.

### NFR-007 : Design — direction artistique

**Priorité :** Must

**Description :** l'app suit la DA du site : couleurs, polices, formes, ton, modes clair et sombre.

**Critères d'acceptation :**
- [ ] Les couleurs et polices viennent de tokens uniques, alignés sur `docs/design/direction-artistique.md`.
- [ ] L'app suit le mode clair ou sombre du système.
- [ ] Le ton des textes suit le site (tutoiement dans les appels à l'action).

**Justification :** l'app prolonge le média.

### NFR-008 : Maintenabilité — sources de données interchangeables

**Priorité :** Must

**Description :** chaque type de donnée (festivals, programmations, timetables, artistes, articles) passe par une interface ; changer de source (mocks, API ouvertes, futur back-office) ne touche ni les écrans ni la logique.

**Critères d'acceptation :**
- [ ] Une source se choisit par configuration, sans modifier les écrans.
- [ ] Une source de démonstration (mocks) existe pour chaque type de donnée et sert aux tests et aux aperçus SwiftUI.
- [ ] Les données de chaque source sont converties vers un même modèle interne.
- [ ] Remplacer la source des festivals est démontré par un test.

**Justification :** le back-office n'a pas encore d'API ; on commence avec des mocks et des données ouvertes.

### NFR-009 : Maintenabilité — qualité du code

**Priorité :** Must

**Description :** code testé, revu, construit automatiquement.

**Critères d'acceptation :**
- [ ] Tests unitaires sur la logique (filtres, conflits de timetable, conversion des sources).
- [ ] Chaque changement passe par une PR ; la CI construit l'app et lance les tests.

**Justification :** projet bénévole : le code doit rester lisible pour de nouveaux contributeurs.

### NFR-010 : Compatibilité — plateformes

**Priorité :** Must

**Description :** iPhone sous iOS 17 ou plus récent en phase 1 (à confirmer à l'architecture) ; Android en phase 3 avec le même modèle de données.

**Critères d'acceptation :**
- [ ] L'app tourne sur la plus petite et la plus grande taille d'iPhone supportées.
- [ ] Le modèle de données et les contrats d'API sont décrits indépendamment de Swift.

**Justification :** l'app Kotlin réutilisera les mêmes sources.

### NFR-011 : Localisation

**Priorité :** Should

**Description :** app en français, textes prêts à traduire.

**Critères d'acceptation :**
- [ ] Aucun texte affiché codé en dur hors des catalogues de chaînes.
- [ ] Dates et distances au format français.

**Justification :** public français d'abord ; festivaliers étrangers plus tard.

### NFR-012 : Coût d'exploitation

**Priorité :** Should

**Description :** l'infrastructure tient dans les offres gratuites ou très bon marché tant que l'app compte moins de 10 000 utilisateurs actifs par mois.

**Critères d'acceptation :**
- [ ] Coût mensuel estimé à l'architecture, inférieur à 20 € à 10 000 utilisateurs actifs par mois (hypothèse).

**Justification :** budget associatif.

---

## Epics

### EPIC-001 : Socle de l'app et sources de données

**Description :** projet Xcode, design system (tokens de la DA), navigation, couche d'accès aux données interchangeable, sources de démonstration et ouvertes, cache hors ligne, CI.

**Exigences :** NFR-001, NFR-002, NFR-003, NFR-006, NFR-007, NFR-008, NFR-009, NFR-010, NFR-011

**Estimation :** 6-8 stories

**Priorité :** Must

**Valeur :** tout le reste repose dessus ; permet de changer de source plus tard sans réécrire l'app.

### EPIC-002 : Découverte des festivals

**Description :** liste, filtres, recherche, carte, fiche, lien billetterie, programmations.

**Exigences :** FR-001, FR-002, FR-003, FR-004, FR-005, FR-006

**Estimation :** 7-9 stories

**Priorité :** Must

**Valeur :** cœur de l'app : répondre à « quel festival, où, quand, avec qui ».

### EPIC-003 : Compte, favoris et jour J

**Description :** compte gratuit, favoris, timetable personnelle, notifications des favoris.

**Exigences :** FR-007, FR-008, FR-009, FR-010

**Estimation :** 6-8 stories

**Priorité :** Must

**Valeur :** fidélise et rend l'app utile pendant le festival.

### EPIC-004 : Contenus éditoriaux

**Description :** articles par rubrique lus en entier dans l'app, liens internes, auteurs, réactions, notifications d'articles, encart recrutement ; propositions de la v1.1.

**Exigences :** FR-011, FR-012, FR-013, FR-027 à FR-030 ; proposées : FR-031 à FR-035

**Estimation :** 15-17 stories (dont 5 proposées)

**Priorité :** Must

**Valeur :** renvoie l'audience vers la rédaction.

### EPIC-005 : Premium et artistes

**Description :** abonnement, programmations en avance, artistes suivis, festival autour de moi, réductions.

**Exigences :** FR-014, FR-015, FR-016, FR-017, FR-018

**Estimation :** 7-9 stories

**Priorité :** Should

**Valeur :** revenu récurrent et personnalisation.

### EPIC-006 : Offre festivals partenaires

**Description :** fiche enrichie, mises en avant, messages jour J, mesure d'audience, jeux concours.

**Exigences :** FR-019, FR-020, FR-021, FR-022, FR-026

**Estimation :** 7-9 stories

**Priorité :** Should

**Valeur :** ce que les festivals paient.

### EPIC-007 : Photos et passeport

**Description :** galeries des photographes, photos par QR code, passeport festivalier.

**Exigences :** FR-023, FR-024, FR-025

**Estimation :** 5-7 stories

**Priorité :** Could

**Valeur :** différenciation forte, lien avec les photographes accrédités.

---

## User stories (premier jet)

Les stories détaillées viendront au sprint planning. Exemples par epic :

- **EPIC-001 :** En tant que développeur, je veux passer de la source de démonstration à une API sans toucher aux écrans, afin de brancher le back-office plus tard.
- **EPIC-002 :** En tant que festivalier, je veux voir les festivals rock de ce week-end à moins de 100 km, afin de choisir où aller.
- **EPIC-002 :** En tant que festivalier, je veux ouvrir la billetterie officielle depuis la fiche, afin d'acheter mon billet là où le festival le vend.
- **EPIC-003 :** En tant que festivalier sur place, je veux voir ma timetable et recevoir un rappel 15 min avant chaque concert, même sans réseau.
- **EPIC-004 :** En tant que lecteur, je veux être prévenu des nouveaux live reports, afin de lire le récit des festivals que j'ai ratés.
- **EPIC-005 :** En tant que premium, je veux découvrir une programmation avant tout le monde.
- **EPIC-005 :** En tant que fan, je veux être prévenu quand un artiste que j'écoute est annoncé dans un festival.
- **EPIC-006 :** En tant que festival partenaire, je veux prévenir mes festivaliers d'un changement d'horaire, afin d'éviter la confusion sur place.
- **EPIC-007 :** En tant que festivalier, je veux récupérer la photo que le photographe vient de prendre de moi.

---

## Personas

- **Léa, 24 ans, festivalière régulière :** 4 à 6 festivals par an, suit les annonces de programmation sur Instagram, compare les prix, part avec des amis. Veut ne rien rater et s'organiser le jour J.
- **Karim, 31 ans, occasionnel :** cherche « un truc sympa ce week-end pas loin ». Veut une carte et des filtres simples.
- **Organisatrice d'un festival de 5 000 personnes :** pas d'app, peu de budget com. Veut de la visibilité, un canal direct le jour J et des chiffres.
- **Photographe accrédité :** couvre 10 festivals par an pour l'association. Veut de la visibilité et, si possible, vendre ses photos.

---

## Parcours clés

1. **Choisir un festival :** Accueil → Festivals (filtre « ce week-end », « 100 km », « électro ») → Carte → Fiche → Favori → Billets (billetterie externe).
2. **Vivre le jour J :** Notification J-1 → Fiche favorite (hors ligne) → Timetable → cocher 5 concerts → conflit signalé → rappel 15 min avant chaque concert.
3. **Suivre l'actu :** Notification « Nouvelle programmation » → Programmation → Artiste → Festivals de l'artiste → Favori.

---

## Dépendances

### Internes

- Site esprit-festivalier.fr : flux RSS des articles (`/feed/`, disponible).
- Back-office du site : pas d'API pour l'instant ; remplacé par mocks et données ouvertes (NFR-008).
- Compte Apple Developer personnel de Clément Guyon pour TestFlight.

### Externes

- **Liste des festivals en France**, Ministère de la Culture, Licence Ouverte 2.0 (data.gouv.fr) : nom, lieu, coordonnées, genre, période. Pas de dates exactes ni de programmation : complétées par des mocks.
- **MusicBrainz** (API ouverte) : identifiants et données des artistes.
- **Apple MusicKit** : import des artistes (phase 2).
- **Apple MapKit** : carte et itinéraire.
- **Open-Meteo** ou **WeatherKit** : météo des festivals (à choisir à l'architecture).
- **App Store / StoreKit 2** : abonnement premium.
- **APNs** : notifications.
- Programmations et timetables : **mocks** écrits à la main pour quelques festivals de démonstration.

---

## Hypothèses

- Les données ouvertes suffisent pour une démonstration crédible ; le back-office fournira plus tard dates exactes, programmations et timetables.
- Le compte personnel suffit pour TestFlight ; la publication App Store finale pourra se faire sous un autre compte (transfert d'app possible).
- Les festivaliers acceptent les notifications si elles sont utiles et peu nombreuses.

---

## Hors périmètre

- Vente de billets et paiement cashless.
- Participation payante à l'unité aux jeux concours.
- Reconnaissance faciale.
- Messagerie et fil social.
- Spotify en phase 2.
- Commentaires sous les articles (modération trop lourde pour l'association ; à confirmer).
- Interface web pour que les festivals gèrent eux-mêmes leur fiche (plus tard).

---

## Questions ouvertes

1. Prix du premium et durée (mois, an, saison) ?
2. Nombre d'entrées en plus pour un premium dans les concours ? (avis juridique en attente)
3. Plafond de messages jour J par festival ?
4. Version minimale d'iOS : 17 ou 18 ?
5. Quels 3 à 5 festivals servent de démonstration dans les mocks ?
6. Compte de publication App Store final : personnel ou association ?
7. Les photographes acceptent-ils que leurs photos, déjà publiées sur le site, apparaissent dans l'app (même éditeur, autre support) ?
8. La rédaction compte-t-elle les lectures du site (contrats de contenus sponsorisés) ? Si oui, compter les lectures dans l'app de façon anonyme (`article_view`, FR-026).
9. Réactions : SF Symbols sobres (proposé) ou emojis ? Liste des 5 réactions à valider.
10. Propositions FR-031 à FR-035 : lesquelles entrent dans le MVP ?
11. Équipe du site : peut-elle ajouter `content:encoded` au flux, un flux JSON, une classe stable « sponsorisé » et le fichier `apple-app-site-association` ?

---

## Validation

### Parties prenantes

- **Clément (développeur, membre)** : influence forte.
- **Bureau de l'association** : influence forte ; a validé le brief.
- **Rédaction** : influence moyenne.
- **Équipe du site** : influence forte (future source des données).
- **Festivals partenaires, photographes** : influence moyenne à faible.

### Statut

- [ ] Product owner (bureau)
- [ ] Développement (Clément)
- [ ] Design
- [ ] Tests

---

## Historique

| Version | Date | Auteur | Changements |
|---|---|---|---|
| 1.0 | 2026-11-25 | clement | Première version |
| 1.1 | 2026-11-25 | clement | Application complète : FR-027 à FR-030, propositions FR-031 à FR-035, FR-011 modifiée |

---

## Prochaines étapes

1. **Architecture** (`/architecture`) : couche de données interchangeable, choix de l'API (FastAPI / Better Auth / Cloudflare), cache hors ligne, notifications.
2. **UX** (`/create-ux-design`) : écrans du MVP dans la DA.
3. **Sprint planning** (`/sprint-planning`) : stories des epics 1 à 4.

---

*Créé avec la méthode BMAD v6, phase 2 (Planification).*

---

## Annexe A : traçabilité

| Epic | Nom | Exigences fonctionnelles | Stories (est.) |
|---|---|---|---|
| EPIC-001 | Socle et sources de données | (NFR-001 à NFR-011) | 6-8 |
| EPIC-002 | Découverte des festivals | FR-001 à FR-006 | 7-9 |
| EPIC-003 | Compte, favoris et jour J | FR-007 à FR-010 | 6-8 |
| EPIC-004 | Contenus éditoriaux | FR-011 à FR-013, FR-027 à FR-035 | 15-17 |
| EPIC-005 | Premium et artistes | FR-014 à FR-018 | 7-9 |
| EPIC-006 | Offre festivals partenaires | FR-019 à FR-022, FR-026 | 7-9 |
| EPIC-007 | Photos et passeport | FR-023 à FR-025 | 5-7 |

**Total estimé :** 54 à 67 stories, dont 30 à 37 pour le MVP (epics 1 à 4).

---

## Annexe B : priorités

| | Must | Should | Could | Total |
|---|---|---|---|---|
| Exigences fonctionnelles | 17 | 12 | 6 | 35 |
| Exigences non fonctionnelles | 10 | 2 | 0 | 12 |

- **Must (MVP) :** FR-001 à FR-012, FR-027 à FR-030, FR-032 (proposée).
- **Should :** FR-014 à FR-017, FR-019 à FR-022, FR-026 (phase 2) ; FR-031, FR-033, FR-034 (proposées).
- **Could (phase 3) :** FR-013, FR-018, FR-023, FR-024, FR-025 ; FR-035 (proposée).
- Les comptes incluent les propositions FR-031 à FR-035.

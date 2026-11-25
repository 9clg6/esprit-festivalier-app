# Product Brief : Esprit Festivalier App

**Date :** 2026-11-25
**Auteur :** clement
**Version :** 1.0 (brouillon à valider par l'association)
**Type de projet :** mobile-app (iOS d'abord en Swift, Android en Kotlin ensuite)
**Niveau de projet :** 3 (12 à 40 stories)

> Les points marqués **(hypothèse)** viennent du cadrage et doivent être confirmés par l'association. Les questions ouvertes sont regroupées à la fin.

---

## Résumé

Esprit Festivalier, média associatif des festivals (« par ceux qui les vivent »), lance une app compagnon gratuite pour les festivaliers : trouver les festivals, suivre leurs programmations, préparer et vivre le jour J, retrouver articles et photos. L'app sert aussi de support aux festivals, qui paient pour être mis en avant et pour toucher leur public directement. Elle ne vend pas de billets, ce qui la distingue de DICE ou Ticketmaster : elle est du côté du festivalier et neutre vis-à-vis des billetteries.

---

## Problème

### Le problème

- **Festivaliers :** l'information est éparpillée (site de chaque festival, Instagram, app propre à chaque gros festival, billetteries). Rien ne suit « mes festivals » et « mes artistes » sur toute la saison. Le jour J, le réseau sature et les infos pratiques (horaires, plan, navettes) sont dures à trouver.
- **Petits et moyens festivals :** une app dédiée coûte trop cher (développement, maintenance, stores) pour quelques jours par an. Ils n'ont pas de canal direct vers leur public le jour J, ni de moyen simple de mesurer leur audience hors billetterie.
- **Esprit Festivalier :** le site a déjà l'annuaire, les programmations et les articles, mais pas de lien direct (notifications) avec ses lecteurs, ni de revenu récurrent hors contenus sponsorisés.

### Pourquoi maintenant ?

- Le contenu existe déjà : annuaire des festivals (par mois, région, genre, carte, « ce week-end »), programmations, artistes, plus de 10 000 articles. L'app réutilise cette base au lieu de partir de zéro.
- Pour être utile, l'app doit sortir avant la saison 2027 (mai-septembre) **(hypothèse)**.

### Si on ne fait rien

- Le public reste dépendant des réseaux sociaux (algorithmes, portée qui baisse).
- L'association reste sans revenu récurrent ni offre concrète à proposer aux festivals.

---

## Public cible

### Utilisateurs principaux

- **Festivaliers réguliers**, 18-35 ans, en France, qui font plusieurs festivals par an. À l'aise avec le mobile, ils suivent les annonces de programmation et hésitent entre plusieurs festivals.
- **Festivaliers occasionnels** qui cherchent « quoi faire ce week-end près de chez moi ».

### Utilisateurs secondaires

- **Festivals** (organisateurs, équipes com) : clients payants des mises en avant et des outils jour J.
- **Photographes et vidéastes** accrédités : publient leurs photos, gagnent en visibilité, vendent peut-être leurs photos.
- **Bénévoles de la rédaction** : publient articles et programmations (depuis le back-office existant).

### Besoins principaux

1. Savoir **quel festival** voir (où, quand, avec quels artistes) sans fouiller dix sites.
2. **Ne rien rater** : annonces de programmation, artistes favoris, festival près de chez soi.
3. **Vivre le jour J** sans galère : timetable personnelle, plan, infos pratiques, même hors réseau.

---

## Solution

### Solution proposée

Une app native (iOS d'abord), gratuite, à l'image du site (voir `docs/design/direction-artistique.md`), avec un compte gratuit et un compte premium. Les festivals partenaires paient pour une page enrichie, une mise en avant et un canal de communication avec leur public.

### Fonctionnalités clés

**Découverte**
- Liste des festivals avec filtres (lieu, date, genre) et **carte**.
- Fiche festival : lieu, dates, plan, timetable, infos pratiques, lien vers la billetterie (externe).
- Programmations (line-ups) et articles du site, avec notifications.

**Personnalisation**
- Favoris (festivals), artistes suivis (import Spotify ou Apple Music, ou choix manuel), alerte quand un artiste suivi joue dans un festival.
- Alerte quand un festival a lieu près de soi.

**Comptes**
- Gratuit : tout le contenu public, favoris, notifications.
- Premium : programmations en avance, jeux concours réservés (avec accès +1), réductions sur les billets négociées avec les festivals.

**Festivals partenaires**
- Page de détail personnalisée (design propre), encart sur l'accueil, mise en avant dans les listes.
- Jeux concours (gratuits, ou payants si c'est légal : voir les risques).

**Photos et vidéos**
- Les photographes et vidéastes publient leurs galeries par festival.
- Les festivaliers retrouvent les photos où ils apparaissent (par scène et créneau, ou par QR code : voir le brainstorm).

### Proposition de valeur

- **Festivalier :** un seul compagnon pour toute la saison, neutre, sans vente de billets, fait par des passionnés.
- **Festival :** une « mini-app » sans coût de développement, un canal direct le jour J et des statistiques d'audience.
- **Association :** revenus récurrents (premium, partenariats), audience qu'elle maîtrise (notifications), visibilité de la rédaction.

---

## Objectifs

### Objectifs (chiffres à valider)

- Publier une version TestFlight (bêta fermée) avec découverte, fiches, favoris et articles avant fin mars 2027 **(hypothèse)**.
- Sortir sur l'App Store avant le 1er mai 2027 (début de saison) **(hypothèse)**.
- Signer 3 festivals partenaires payants pour la saison 2027 **(hypothèse)**.
- Atteindre 5 000 comptes créés à fin septembre 2027 **(hypothèse)**.

### Indicateurs

- Comptes créés, utilisateurs actifs par mois (MAU), part avec notifications activées.
- Favoris par utilisateur ; clics vers les billetteries (suivi UTM) par festival.
- Taux de passage au premium ; nombre de festivals partenaires et revenu par festival.
- Ouvertures des notifications d'articles (trafic renvoyé vers la rédaction).

### Valeur

Revenu récurrent pour l'association (abonnements, partenariats), et un argument chiffré (audience, clics billetterie) pour vendre les partenariats et les accréditations.

---

## Périmètre

### Dans le périmètre (MVP, phase 1)

- Liste des festivals, filtres lieu et date, carte.
- Fiche festival (infos, dates, lieu, timetable, lien billetterie externe).
- Programmations et articles du site, notification des nouveaux articles.
- Compte gratuit, favoris, notifications liées aux favoris.
- Lecture hors ligne des fiches favorites et de la timetable.
- DA du site, mode clair et sombre.

### Phase 2

- Compte premium (achat intégré Apple), programmations en avance.
- Pages partenaires personnalisées, encart d'accueil, mise en avant dans les listes.
- Jeux concours gratuits (avec +1 pour les premium).
- Artistes suivis (Apple Music, choix manuel ; Spotify si l'accès est obtenu).
- Alertes « festival près de toi ».

### Phase 3

- Photos et vidéos des photographes, retrouver ses photos.
- Jeux concours payants (seulement si validés juridiquement et par Apple).
- App Android (Kotlin).

### Hors périmètre

- **Vente de billets** (choix de positionnement).
- Paiement cashless sur site.
- Réseau social complet (messagerie, fil public) : seulement si un vrai besoin apparaît.

### Pistes futures

Voir `docs/brainstorm-esprit-festivalier-app-2026-11-25.md` : planning perso avec conflits, « crew » entre amis, passeport festivalier et badges, outils jour J pour les festivals, statistiques partenaires.

---

## Parties prenantes

- **Clément (membre, développeur)** : influence forte. Construit l'app et l'API.
- **Bureau de l'association** : influence forte. Valide le modèle économique, les prix, les partenariats, l'aspect juridique.
- **Rédaction et bénévoles** : influence moyenne. Produisent le contenu ; veulent du trafic et des notifications.
- **Équipe ou prestataire du site et du back-office** : influence forte. Source des données (festivals, articles, artistes) ; API à ouvrir.
- **Festivals partenaires** : influence moyenne. Clients ; veulent visibilité, ventes de billets et données.
- **Photographes et vidéastes** : influence faible à moyenne. Fournissent les photos ; veulent visibilité ou revenu.

---

## Contraintes et hypothèses

### Contraintes

- Association bénévole : peu de temps de développement, budget serré.
- iOS d'abord en Swift, diffusion TestFlight ; Kotlin plus tard.
- Back-end prévu : FastAPI, Better Auth, Cloudflare. **Attention :** Better Auth est une bibliothèque TypeScript, elle ne tourne pas dans FastAPI (Python). Il faut choisir à l'étape architecture : soit l'auth Better Auth dans un Worker TypeScript à côté d'une API FastAPI, soit une API entièrement TypeScript (Workers + D1/R2), soit une autre solution d'auth en Python.
- Achats numériques dans l'app (premium) : achat intégré Apple obligatoire, commission de 15 % (Small Business Program) à 30 %.
- RGPD : géolocalisation, données de goûts musicaux, photos de personnes (droit à l'image).
- Code public mais non libre (voir `LICENSE`).

### Hypothèses

- Le back-office du site peut exposer les données (festivals, programmations, artistes, articles) par une API ou un flux ; aucune double saisie.
- Les festivaliers ont un smartphone récent ; l'app vise une version d'iOS récente (à fixer à l'architecture).
- Des festivals sont prêts à payer une mise en avant et à offrir des réductions aux premium.
- Les photographes accrédités par l'association acceptent de publier dans l'app.

---

## Critères de succès

- Les bêta-testeurs (membres et proches) utilisent l'app pendant au moins un festival et la recommandent.
- La rédaction voit du trafic venir des notifications.
- Au moins un festival partenaire renouvelle après la saison 2027.
- Note App Store ≥ 4,5.
- Aucun incident RGPD ni refus d'Apple bloquant.

---

## Calendrier

### Cible

App Store avant mai 2027 pour la saison des festivals **(hypothèse)**.

### Étapes

- Décembre 2026 : PRD, UX, architecture, accès aux données du back-office.
- Janvier-février 2027 : MVP iOS (découverte, fiches, favoris, articles).
- Mars 2027 : bêta TestFlight avec les membres.
- Avril 2027 : soumission App Store, premiers festivals partenaires (pages perso).
- Mai-septembre 2027 : saison ; phase 2 (premium, concours, artistes suivis).
- Automne 2027 : bilan, phase 3 (photos, Android).

---

## Risques

- **Risque :** jeu concours payant (1 € pour tenter de gagner un pass) = loterie interdite en France (Code de la sécurité intérieure, art. L322-1 et suivants : offre au public, espoir de gain, hasard, mise d'argent).
  - **Probabilité :** forte.
  - **Atténuation :** concours gratuits ; ou vrai concours d'adresse ou de connaissances sans hasard ; ou exception des loteries d'associations (autorisation préalable). À faire valider par un juriste avant tout développement. Apple encadre aussi strictement les concours et jeux d'argent (règle 5.3 de l'App Store).
- **Risque :** l'API Spotify n'accorde plus l'accès étendu qu'aux grosses organisations ; en mode développement, seuls quelques dizaines de comptes peuvent se connecter.
  - **Probabilité :** forte.
  - **Atténuation :** commencer par Apple Music (MusicKit) et le choix manuel des artistes ; demander l'accès Spotify plus tard.
- **Risque :** pas d'API sur le back-office du site → double saisie.
  - **Probabilité :** moyenne.
  - **Atténuation :** en parler tôt avec l'équipe du site ; en dernier recours, lire le flux RSS et les pages publiques.
- **Risque :** les festivals ne paient pas.
  - **Probabilité :** moyenne.
  - **Atténuation :** offrir la saison 2027 à 2-3 festivals pilotes contre des statistiques et un témoignage ; vendre ensuite avec les chiffres.
- **Risque :** photos de festivaliers publiées sans consentement (droit à l'image, RGPD) ; reconnaissance faciale = donnée biométrique.
  - **Probabilité :** moyenne.
  - **Atténuation :** pas de reconnaissance faciale ; lien par QR code ou créneau, avec opt-in ; retrait sur demande.
- **Risque :** réseau saturé sur les festivals.
  - **Probabilité :** forte.
  - **Atténuation :** cache hors ligne des fiches favorites, de la timetable et du plan.
- **Risque :** projet bénévole qui s'essouffle.
  - **Probabilité :** moyenne.
  - **Atténuation :** MVP petit, sortie avant la saison, phases courtes.

---

## Questions ouvertes pour l'association

1. Qui gère le site et le back-office, et peut-on y ajouter une API ?
2. Prix visé du premium (mensuel, annuel, à la saison) ?
3. Quels festivals pilotes contacter en premier ?
4. Qui porte le droit d'auteur du code : l'association (contributions cédées) ou les développeurs ?
5. Date cible réelle de sortie ?
6. Modèle photo : les photographes paient pour publier, les festivaliers paient pour télécharger, ou c'est gratuit ?

---

## Prochaines étapes

1. Valider ce brief et le brainstorm avec le bureau.
2. Créer le PRD : `/prd`.
3. Design UX dans la DA du site : `/create-ux-design`.
4. Architecture (dont le choix FastAPI / Better Auth) : `/architecture`.

---

*Créé avec la méthode BMAD v6, phase 1 (Analyse).*

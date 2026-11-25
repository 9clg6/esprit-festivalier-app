# Brainstorm : Esprit Festivalier App

**Date :** 2026-11-25
**Méthode :** BMAD, phase 1. Fonctionnalités demandées passées au crible (valeur, coût, risque), puis idées nouvelles.

Légende : **MVP** = phase 1 · **P2** / **P3** = phases suivantes · **Non** = écarté ou à revoir.

---

## 1. Fonctionnalités demandées : verdict

| Fonctionnalité | Verdict | Remarque |
|---|---|---|
| Compte gratuit | MVP | Connexion Apple obligatoire si d'autres connexions tierces sont proposées (règle Apple 4.8). |
| Compte premium | P2 | Achat intégré Apple obligatoire. Les réductions sur billets dépendent d'accords avec chaque festival. |
| Liste des programmations | MVP | Déjà sur le site (rubrique Programmations). |
| Liste des festivals + filtres lieu, date | MVP | Déjà sur le site (par mois, région, genre, « ce week-end »). |
| Carte des festivals | MVP | MapKit, sans coût. |
| Fiche festival (plan, lieu, dates, timetable, infos, billets) | MVP | Billets = lien externe suivi (UTM), jamais de vente. |
| Page partenaire personnalisée + mise en avant | P2 | Garder une base commune (thème, blocs) plutôt qu'un design libre par festival : sinon chaque partenaire devient un projet. |
| Page de participation au jeu concours | P2 | Concours gratuits d'abord. |
| Jeu concours payant (1 € pour gagner un pass) | Non en l'état | Payer pour un tirage = jeu de hasard interdit (CSI L320-1). Voies légales : concours gratuit + entrées bonus premium, concours d'adresse sans tirage, ou tombola autorisée par le maire (L322-3). À valider par un juriste. Apple très strict (règle 5.3). |
| Lier Spotify, alerte artistes favoris | P2 | Accès Spotify très restreint depuis 2025. Commencer par Apple Music (MusicKit) et le choix manuel. |
| Notification festival près de soi | P2 | Position approximative, opt-in explicite. |
| Festival en favori | MVP | Cœur de la personnalisation. |
| Photos et vidéos des photographes (payant ou non) | P3 | Voir l'idée « retrouve tes photos » plus bas. |
| Articles publiés + notification | MVP | Flux du site ; choix des rubriques suivies. |
| Valeur ajoutée pour les festivals | — | Voir la section 3. |
| Pas de vente de billets | Retenu | Positionnement : neutre, côté festivalier. |
| Photographes qui envoient ou taguent les photos aux festivaliers | P3 | Voir « retrouve tes photos ». |

---

## 2. Idées nouvelles pour les festivaliers

1. **Ma timetable** (MVP ou P2) : cocher les concerts, voir les conflits entre scènes, rappel 15 min avant. C'est la fonction qu'on ouvre le plus le jour J.
2. **Mode hors ligne** (MVP) : fiche, plan et timetable des favoris en cache. Le réseau sature toujours en festival.
3. **Retrouve tes photos** (P3), sans reconnaissance faciale :
   - le festivalier montre un **QR code** dans l'app ; le photographe le scanne juste après la photo ; la photo arrive dans l'app du festivalier ;
   - ou le festivalier indique « j'étais devant la scène X à 22 h » et voit les photos de ce créneau.
   Consentement clair, retrait sur demande. Le photographe choisit gratuit ou payant (téléchargement HD).
4. **Crew** (P3) : partager ses favoris et sa timetable avec ses amis, voir qui va où.
5. **Passeport festivalier** (P2) : badges et récompenses par festival fait (validé par position ou QR sur place), saison, genres. Récompense sans effet « enfant ». Donne aussi aux festivals une preuve de fréquentation.
6. **Infos pratiques** (MVP dans la fiche) : accès, navettes, covoiturage (lien externe), météo, objets interdits, liste « que mettre dans mon sac ».
7. **Après le festival** (P2) : live report de la rédaction, photos, note du festival → contenu pour le site.
8. **Rejoins la rédaction** (MVP, simple lien) : l'appel « Tu vis les festivals de l'intérieur ? » vers la page Recrutements.
9. **Widget et Live Activity iOS** (P2) : prochain concert de ma timetable sur l'écran verrouillé.

---

## 3. Pourquoi un festival aurait ENVIE de nous payer

Le point fort : **une app pour leur public sans payer le développement d'une app**. Les petits et moyens festivals n'en ont pas.

| Offre | Ce que le festival y gagne |
|---|---|
| **Page enrichie = mini-app** | Timetable, plan, infos pratiques, FAQ, hors ligne, aux couleurs du festival. Pas d'app à créer ni à maintenir. |
| **Notifications jour J** | Changement d'horaire, alerte météo, dernière navette, objets trouvés, envoyés aux festivaliers qui l'ont en favori. Canal direct, sans algorithme. |
| **Annonces de programmation** | Notification à tous ceux qui suivent le festival ou un artiste annoncé. Les premium la reçoivent en avance : plus de buzz. |
| **Statistiques** | Favoris, vues, clics billetterie, origine géographique (agrégée, anonyme). Bilan de fin de saison. |
| **Aide à la programmation** | « 1 200 utilisateurs dans un rayon de 100 km suivent l'artiste X » (agrégé, anonyme, avec consentement). Donnée rare pour un petit festival. |
| **Couverture éditoriale** | Live report, interviews, photos des photographes accrédités, réutilisables sur leurs réseaux (droits à négocier). Contenu sponsorisé toujours signalé, comme sur le site. |
| **Jeux concours** | Visibilité et recrutement de public ; les participants peuvent choisir de recevoir la newsletter du festival (opt-in RGPD). |
| **Réductions premium** | Le festival offre -X % aux premium : il remplit ses dates creuses ou ses catégories qui se vendent mal. |

**Formules à tester (hypothèse) :**
- **Gratuit** : fiche de base (déjà dans l'annuaire du site).
- **Partenaire** : page enrichie, notifications jour J, statistiques.
- **Partenaire+** : en plus, encart accueil, mise en avant dans les listes, jeu concours, couverture éditoriale.

Pour démarrer : 2 ou 3 festivals pilotes gratuits en 2027, contre un témoignage et le droit d'utiliser leurs chiffres.

---

## 4. Revenus possibles

1. Abonnement premium (achat intégré Apple, 15 % de commission si l'association est dans le Small Business Program).
2. Formules partenaires pour les festivals (facturées hors app, donc pas de commission Apple).
3. Photos : commission sur les ventes HD des photographes (P3).
4. Concours payants : seulement après validation juridique.

---

## 5. Écartés ou mis de côté

- Vente de billets : contraire au positionnement.
- Reconnaissance faciale pour les photos : donnée biométrique (RGPD art. 9), trop risqué.
- Messagerie ou fil social complet : coûteux à modérer, pas le cœur.
- Design entièrement libre pour chaque partenaire : maintenance impossible pour des bénévoles ; on fait un thème et des blocs configurables.

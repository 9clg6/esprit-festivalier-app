# Direction artistique — Esprit Festivalier

Source : CSS inline de https://esprit-festivalier.fr/ (relevé le 2026-11-25). Le site a un mode clair et un mode sombre (`prefers-color-scheme`) : l'app suit le réglage du système.

## Couleurs

| Token | Clair | Sombre | Usage sur le site |
|---|---|---|---|
| `accent` | `#1d9fc9` | `#1d9fc9` | Bleu principal, liens, boutons |
| `accent-dark` | `#14728f` | `#5cc3e4` | Accent sur fond clair / texte d'accent |
| `accent-fill` | `#14728f` | `#14728f` | Fond des boutons pleins |
| `deep` | `#0b3d63` | — | Bleu profond (en-têtes, blocs) |
| `night` | `#071e33` | — | Bleu nuit |
| `sun` | `#ffd23f` | — | Jaune soleil (mise en avant, badges) |
| `sky` | `#e6f4fa` | `#12283a` | Fond doux |
| `sky2` | `#d2ebf5` | `#173548` | Fond doux 2 |
| `ink` | `#0e1a26` | `#eef4f8` | Texte principal |
| `ink2` | `#2f3d4a` | `#cbd7e1` | Texte secondaire |
| `muted` | `#5f7180` | `#93a6b6` | Texte discret |
| `line` | `#dbe6ee` | `#22313f` | Séparateurs |
| `bg` | `#f3f8fb` | `#0b131b` | Fond de page |
| `card` | `#ffffff` | `#131e29` | Cartes |
| `hover` | `#e9f2f8` | `#1a2836` | Survol / état pressé |
| `thumb` | `#d9e8f0` | `#1c2a38` | Fond de vignette en chargement |

## Typographie

| Rôle | Police | Repli |
|---|---|---|
| Titres | **Chivo** (graisse forte) | Arial Black, Impact |
| Libellés, catégories | **Raleway** | Segoe UI, Helvetica |
| Texte courant | **Open Sans** | Segoe UI, Roboto |

Les trois polices sont libres (SIL Open Font License) : on peut les embarquer dans l'app.

## Formes

- Rayon des cartes : **16 px** ; petits éléments 12–14 px ; pastilles et boutons : **999 px** (pilule) ; avatars ronds.
- Ombre des cartes (clair) : `0 1px 2px rgba(11,61,99,.06), 0 10px 30px -14px rgba(11,61,99,.25)`.
- Mise en page : bloc « À la une » + grilles de cartes (vignette, catégorie, titre, auteur, date) avec « Tout voir ».

## Logo et ton

- Logo : « Esprit Festivalier » en lettres blanches épaisses, style pixel/bloc, contour noir (`/icons/logo-260.webp`, icône `/icons/icon-512.png`).
- Accroche : « Le média des festivals, par ceux qui les vivent ».
- Ton : sincère, indépendant, tutoiement dans les appels à l'action (« Tu vis les festivals de l'intérieur ? »).
- Photos : éditoriales, concerts et festivals, toujours créditées (« Photo : … »).

## À confirmer avec le designer du site

- Fichiers sources du logo (SVG) et règles d'usage.
- Usage exact de `sun` (jaune) : réservé aux badges premium ? Proposition : oui, il marque tout ce qui est premium ou mis en avant.

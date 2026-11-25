# Esprit Festivalier — App

App compagnon des festivaliers, par [Esprit Festivalier](https://esprit-festivalier.fr/), le média des festivals, par ceux qui les vivent.

## Code public, mais pas libre

Ce code est publié **pour la transparence**. Il n'est **pas open source** : toute utilisation, copie, modification ou redistribution est interdite sans accord écrit de l'association. Voir [`LICENSE`](LICENSE).

## État

Cadrage (méthode BMAD, phase 1) :

- [Product brief](docs/product-brief-esprit-festivalier-app-2026-11-25.md)
- [Brainstorm des fonctionnalités](docs/brainstorm-esprit-festivalier-app-2026-11-25.md)
- [Direction artistique](docs/design/direction-artistique.md)
- [PRD](docs/prd-esprit-festivalier-app-2026-11-25.md)
- [Architecture](docs/architecture-esprit-festivalier-app-2026-11-25.md)
- [UX](docs/ux-design-esprit-festivalier-app-2026-11-25.md)
- [Plan de sprints](docs/sprint-plan-esprit-festivalier-app-2026-11-25.md)
- [Suivi BMAD](docs/bmm-workflow-status.yaml)

## Stack

- iOS : SwiftUI (iOS 17+), package `EFKit` (`ios/EFKit`). Android en Kotlin plus tard.
- API : Cloudflare Workers en TypeScript (Hono, Better Auth, D1).
- Données publiques : instantané JSON sur R2, construit chaque nuit depuis les données ouvertes.

## Développement

Prérequis : Xcode et `brew install xcodegen swiftlint`.

```
cd ios && xcodegen generate && open EspritFestivalier.xcodeproj
```

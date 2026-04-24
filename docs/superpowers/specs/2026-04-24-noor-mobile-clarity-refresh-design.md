# Noor Mobile Clarity Refresh Design

**Date:** 2026-04-24

## Goal

Make Noor Express feel immediately clear, human, and premium on mobile without changing the validated business flows.

The product should feel like it speaks to a friend, not to a developer:

- short, warm, reassuring French
- almost no technical or internal wording on screen
- cleaner hierarchy on every critical page
- more elegant mobile buttons, cards, menus, and feedback states
- no large refactor and no backend changes for this phase

## Product Direction

### Editorial Direction

The app should use simple and reassuring French:

- one idea per sentence
- clear action verbs
- no technical wording unless unavoidable
- no backend, session, status, refresh, negotiation, or mode jargon exposed to the user when plain French can replace it

Examples:

- `Tracking` -> `trajet en direct` or removed entirely
- `GPS indisponible` -> `Votre position est difficile a retrouver pour le moment`
- `Reconnexion en cours` -> `La connexion revient...`
- `Offre` -> `proposition`
- `Negociation` -> `prix propose`

### Visual Direction

Keep the existing Noor identity, but make it more premium and polished:

- cleaner spacing
- stronger hierarchy
- more elegant cards
- clearer and prettier buttons
- calmer status feedback
- better mobile ergonomics

The work should reorganize the current pages without rewriting the whole structure.

## Scope

### Priority Order

1. client home
2. driver home
3. client tracking and driver tracking
4. client negotiation and driver offer
5. side menu and history
6. login, onboarding, and settings

### In Scope

- shared editorial cleanup for critical mobile flows
- shared premium button and feedback polish
- cleaner menu labels and grouping
- clearer empty, waiting, loading, and error states
- more human titles, subtitles, banners, and CTA labels
- targeted visual cleanup of the priority screens

### Out of Scope

- backend changes
- route structure changes
- new business flows
- large state-management refactors
- full design-system rewrite
- decorative animations without UX value

## Shared UX Rules

### Copy Rules

- use short French sentences
- remove developer or system language
- prefer clarity over feature naming
- every message should reassure, guide, or confirm
- avoid blaming the user

### Layout Rules

- one primary action per screen
- one main message at a time
- better separation between primary and secondary actions
- more breathing room inside cards and sheets
- cleaner visual grouping in menus and settings

### Component Rules

Strengthen the shared layer instead of styling pages ad hoc:

- `AppButton`
- `NotificationCard`
- `StatusBadge`
- `AppInlineFeedback`
- shared copy helpers

## Screen Family Design

### Client Home

The client should understand immediately:

- where to tap
- what the next action is
- whether a ride is already in progress

Keep the current structure, but make the bottom action sheet the clear heart of the page:

- `Depart`
- `Arrivee`
- `Votre prix` or `Budget propose`
- primary CTA such as `Chercher un chauffeur`

When a ride already exists, the page should switch visually from form mode to active-ride mode with one clear summary and one clear CTA.

### Driver Home

The driver should understand immediately:

- whether they are receiving rides
- whether a ride is active
- what they should do next

Replace technical labels with direct language:

- `Disponible`
- `En pause`
- `En course`

The bottom sheet becomes the main action surface for availability, active ride summary, and the next useful CTA.

### Tracking Screens

Client and driver tracking should feel like one coherent family:

- same visual rhythm
- same banner logic
- same style of calm progress feedback

Client copy should reassure:

- `Votre chauffeur arrive`
- `Votre chauffeur est sur place`
- `Le trajet a commence`

Driver copy should guide:

- `Allez vers le client`
- `Vous etes arrive`
- `Vous pouvez demarrer le trajet`

### Negotiation And Driver Offer

These pages should stop feeling technical or transactional.

Client side:

- `Un chauffeur vous a repondu`
- `Voici son prix`
- `Accepter`
- `Proposer un autre prix`

Driver side:

- `Cette course vous interesse ?`
- `Choisissez votre prix`
- `Envoyer ma proposition`

### Menu And History

The side menu should feel like a personal navigation space, not a module list.

Human groupings:

- `Accueil`
- `Mes trajets`
- `Notifications`
- `Mon profil`
- `Mon vehicule`
- `Mon activite`
- `Aide`
- `Reglages`
- `Se deconnecter`

History screens should show only the essentials clearly:

- departure
- arrival
- date
- price
- simple ride outcome

### Login, Onboarding, And Settings

Login should feel welcoming and frictionless:

- `Bienvenue`
- `Entrez votre numero pour continuer`

Driver onboarding should feel step-by-step and reassuring:

- `Parlez-nous de vous`
- `Ajoutez votre piece d identite`
- `Ajoutez votre photo`

Settings must remove developer language and stay honest:

- no `Dev:` text
- simple preference labels
- clean confirmation dialogs

## Constraints

- no backend-first flow changes
- no duplicated copy logic across pages
- prefer improving shared widgets over page-local styling
- preserve existing navigation and controller behavior where possible
- mobile-first spacing and tap comfort must improve

## Verification

The implementation should be considered successful when:

- the main client and driver screens read naturally in simple French
- the app no longer feels technical on critical pages
- buttons, banners, cards, and menus feel more premium and more coherent
- the same shared UI rules are reused across the touched screens
- `flutter analyze` remains clean

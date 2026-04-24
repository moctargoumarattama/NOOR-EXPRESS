# Noor Express Mobile UX Polish Design

**Date:** 2026-04-24

## Goal

Improve the mobile UX/UI of Noor Express without changing business behavior, without refactoring the whole app, and without scattering UI logic across the codebase.

The work must:

- make buttons more consistent and professional
- improve loading and reconnect states
- make critical messages clearer
- clean the most important pages only
- keep transitions simple and useful
- stay centralized and maintainable

## Scope

### In Scope

- shared button system improvements
- shared loading and status feedback improvements
- clearer user-facing copy for critical ride states
- targeted cleanup of these screens:
  - `home client`
  - `home chauffeur`
  - `negociation client`
  - `offre chauffeur`
  - `tracking client`
  - `tracking chauffeur`
- manual resync UI only for:
  - client negotiation
  - driver offer
  - client tracking
  - driver tracking

### Out of Scope

- backend or domain-flow changes
- route structure changes
- large architecture refactors
- full design-system rollout
- decorative animations without UX value
- manual resync UI on both home screens

## Product Constraints

- no change to validated business flow
- backend remains the source of truth
- the lifecycle recovery work already implemented stays authoritative
- UI changes should reuse shared components whenever possible
- `flutter analyze` must stay clean

## Current Problems

- button styles are only partially centralized and do not cover all important states
- loading behavior is inconsistent across critical flows
- reconnecting, waiting, and failure states are not always explicit enough
- some critical pages feel visually uneven in spacing, CTA emphasis, and status clarity
- manual recovery exists in logic but is not always visible enough to reassure users in extreme stuck states

## Approved Approach

Use a centralized, lightweight UX polish layer instead of page-by-page ad hoc edits.

Core idea:

- strengthen shared UI primitives first
- reuse them across the critical screens
- keep manual resync visible only where users are most likely to feel blocked

This avoids duplicated styling, limits UI drift, and keeps the change set small enough to remain safe.

## Shared UI Changes

### `AppButton`

Upgrade the shared button component so it becomes the default action primitive for critical flows.

Required variants:

- primary
- secondary
- danger
- loading
- disabled

Required behaviors:

- integrated loading state without duplicating spinner logic in screens
- clean disabled visuals with readable contrast
- consistent height, spacing, radius, and label weight
- optional icon support only if already useful in touched screens

Non-goals:

- no giant token system
- no per-screen button variants

### Shared Status / Loading Helpers

Add one or two minimal shared helpers, only if they reduce repetition immediately.

Recommended helpers:

- a compact inline loading widget for offers, ride creation, tracking refresh, and reconnect states
- a compact status banner/card pattern for warning, error, success, and reconnecting states

Rules:

- helpers must be generic enough to reuse on at least two critical screens
- do not create a helper if one existing widget can be improved instead

## Loading Design

### Priority Flows

Improve visible feedback for:

- ride creation
- offer loading
- offer acceptance
- tracking snapshot refresh
- reconnecting / websocket recovery

### UX Rules

- no silent blocked state
- users should always understand whether the app is:
  - waiting
  - retrying
  - reconnecting
  - blocked by a recoverable issue
- avoid full-screen spinners unless the page has no meaningful content to show yet
- prefer inline or section-level feedback when content can remain visible

## Messaging Strategy

Critical user-facing messages should be rewritten to be:

- short
- human
- actionable
- non-technical

Priority cases:

- network error
- no driver available
- offer expired
- ride cancelled
- driver unavailable
- reconnecting
- GPS unavailable

Copy principles:

- explain the situation plainly
- tell the user what the app is doing when applicable
- avoid backend jargon
- avoid blameful wording

## Manual Resync UX

### Approved Placement

Manual resync is intentionally limited to the screens where users are most likely to feel stuck:

- client negotiation
- driver offer
- client tracking
- driver tracking

### Approved Interaction Model

#### Negotiation

- keep `pull-to-refresh` on client negotiation
- make the refresh feel more intentional through clearer status text and loading feedback
- add a discreet refresh action on driver offer only if needed for parity or for non-scroll states

#### Tracking

- add a small secondary or ghost-style action such as `Rafraichir l etat`
- show it only when useful:
  - reconnecting
  - network error
  - state mismatch suspicion
- do not keep a permanent loud resync button on a healthy tracking screen

### Behavioral Rules

- manual resync always triggers the already approved backend-first recovery path
- local state must not be trusted over backend state
- the action must remain silent and fast when recovery succeeds
- no new business logic branch is introduced for manual resync

## Page-Level Cleanup

### Home Client

Improve:

- CTA hierarchy around ride creation
- loading clarity for estimate and create actions
- clearer empty / unavailable states
- more disciplined spacing and feedback placement

Do not:

- redesign the overall flow
- move major navigation entry points

### Home Chauffeur

Improve:

- online / offline / busy readability
- pending ride popup CTA clarity
- better feedback around live updates and availability changes
- more professional spacing and emphasis

Do not:

- change onboarding or driver workflow structure

### Client Negotiation

Improve:

- loading clarity while waiting for offers
- clearer offer list state
- clearer expired / closed / reconnecting feedback
- pull-to-refresh reassurance

### Driver Offer

Improve:

- hierarchy between ride info, proposed price, and primary CTA
- submission loading clarity
- clearer stale / unavailable state handling

### Client and Driver Tracking

Improve:

- connection-state readability
- status clarity for accepted / arrived / started / completed
- better placement of key actions
- visible but restrained reconnect / refresh affordance

## Transition Design

Only add simple transitions that clarify product state.

Allowed:

- smoother transition to tracking after accepted offer
- smoother exit to home after cancellation or completion
- animated state swap for reconnecting / offline banners or inline feedback

Forbidden:

- heavy page choreography
- motion added only for polish without information value

## Implementation Boundaries

- prefer editing existing shared widgets over creating many new ones
- prefer improving existing screen composition over extracting large UI frameworks
- keep touched files focused on replacing hardcoded UI behavior with shared primitives
- if a screen still needs local custom presentation, keep the logic local but the visual primitive shared

## Testing and Verification

### Verification Requirements

- run `flutter analyze`
- run targeted widget/unit tests for any new shared UI logic where practical
- verify the critical flows manually through state transitions:
  - create ride
  - wait for offers
  - accept or submit offer
  - enter tracking
  - reconnecting / degraded state
  - manual resync on tracking / negotiation

### Regression Priority

Pay extra attention to:

- disabled buttons still blocking duplicate submissions
- loading buttons preserving layout stability
- reconnecting state not causing noisy visual flashes
- manual resync not bypassing backend truth

## Final Report Requirements

The implementation closeout should explicitly report:

1. shared UI components created or improved
2. pages touched
3. UX bugs corrected
4. what was deliberately avoided
5. `flutter analyze` verification result

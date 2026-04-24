# Noor Express Ride V1 Architecture Design

**Date:** 2026-04-23

## Goal

Stabilize Noor Express around a single backend-driven ride lifecycle for an inDrive-style local transport flow:

- one active ride per client
- one active ride per driver
- one winning offer per ride
- locked agreed price after client acceptance
- verified drivers only
- strict lifecycle transitions
- backend as the only source of truth

## Current Problems

- ride status transitions are split between `ride_request_service.py` and `ride_offer_service.py`
- the system still exposes two contradictory assignment models:
  - direct driver acceptance of a ride
  - negotiation through offers
- a driver can currently change the ride price at completion time
- driver verification exists in admin workflows but is not enforced strongly by backend ride flows
- frontend and WebSocket state carry too much implicit meaning compared with the persisted backend state

## Final Domain Rules

### Active Ride Definition

A ride is active when its status is one of:

- `pending`
- `offered`
- `accepted`
- `arrived`
- `started`

Rides in `completed`, `cancelled`, or `expired` are not active.

### Ride Status Flow

Official lifecycle:

`pending -> offered -> accepted -> arrived -> started -> completed`

Authorized exceptions:

- `pending -> expired`
- `offered -> expired`
- `pending -> cancelled`
- `offered -> cancelled`
- `accepted -> cancelled`
- `accepted -> pending` after driver cancellation
- `arrived -> pending` after driver cancellation

Forbidden transitions:

- any status jump that skips a required step
- any backward transition other than the explicit driver cancellation reset above
- any normal business modification after `completed`, `cancelled`, or `expired`

### Offer Statuses

- `pending`
- `accepted`
- `rejected`
- `invalidated`
- `expired`

Meanings:

- `rejected`: explicitly refused by the client
- `invalidated`: no longer valid because ride state changed or another offer won
- `expired`: timed out without a valid resolution

### Pricing

- `estimated_price`: system-generated estimate before agreement
- `agreed_price`: official locked price after offer acceptance
- `final_price`: deprecated compatibility field; no free-form completion input in the normal flow

### Driver Verification

A non-verified driver must not be able to:

- go online
- view available rides
- create an offer
- accept a ride through any ride-assignment flow

## Architecture

### `ride_lifecycle_service`

The only service allowed to change ride status.

Responsibilities:

- create rides
- move a ride to `offered`
- accept the winning offer
- mark arrival
- start ride
- complete ride
- cancel by client
- cancel by driver
- expire ride
- invalidate or reconcile related offers after a lifecycle transition

### `ride_offer_service`

Offer management only.

Responsibilities:

- create offer
- list pending offers visible to the ride owner
- reject offer by client
- invalidate offers
- expire pending offers
- count pending offers
- request ride lifecycle resynchronization when needed

Non-responsibilities:

- no direct ride status ownership
- no direct driver assignment ownership
- no direct winning-offer lifecycle ownership

### `ride_policy`

Central backend rule helpers:

- active ride checks
- allowed status checks
- verified driver enforcement
- mutation guards
- reusable invariants for lifecycle and offer services

### API Errors

All relevant ride and offer flows should return a structured payload:

```json
{
  "code": "driver_not_verified",
  "message": "Driver must be verified before going online."
}
```

Error categories:

- access errors: `not_found`, `unauthorized`, `forbidden`
- validation / domain errors: ride already active, transition forbidden, offer expired, ride already assigned, driver not verified

## API Design

### Ride Endpoints

- `POST /ride-requests`
- `GET /ride-requests/active`
- `POST /ride-requests/{id}/cancel`
- `POST /ride-requests/{id}/arrive`
- `POST /ride-requests/{id}/start`
- `POST /ride-requests/{id}/complete`

### Offer Endpoints

- `POST /ride-offers`
- `GET /ride-offers/{ride_id}`
- `POST /ride-offers/{offer_id}/accept`
- `POST /ride-offers/{offer_id}/reject`

### Disabled Path

`POST /ride-requests/{id}/accept` remains explicitly disabled with a clear error message because direct ride acceptance is no longer an official flow.

## Resynchronization

`GET /ride-requests/active` becomes the official recovery endpoint after:

- application restart
- network loss
- WebSocket drop
- stale local state

WebSocket is notification only. It never becomes the source of truth for a critical transition.

## Backend Persistence Rules

- notifications are sent only after the backend confirms the change in persistence
- active ride checks must be enforced on the backend, not inferred from UI
- accepted offers invalidate all competing offers immediately
- old offers are never silently reactivated after driver cancellation

## Driver Cancellation Rule

If the assigned driver cancels while ride is `accepted` or `arrived`:

- ride returns to `pending`
- current driver is detached
- accepted offer is invalidated
- other previously resolved offers stay resolved
- no automatic reactivation of past offers

Driver cancellation is forbidden after `started` except for future explicit admin-only tooling.

## Testing Strategy

Add backend tests centered on invariants:

- client cannot create a second active ride
- driver cannot hold a second active ride
- non-verified driver cannot go online or offer
- offer creation allowed only in `pending` or `offered`
- first valid offer moves ride to `offered`
- only one accepted offer can win
- concurrency protection around offer acceptance
- `accepted -> started` is forbidden
- `accepted -> arrived -> started` works
- driver cancellation in `accepted` and `arrived` resets ride to `pending`
- driver cancellation in `started` is forbidden
- agreed price is locked after acceptance and cannot be changed at completion
- expired rides and offers close cleanly

## Files Expected To Change

Backend:

- `backend/app/core/*` for structured errors
- `backend/app/models/ride_request.py`
- `backend/app/models/ride_offer.py`
- `backend/app/schemas/ride_request.py`
- `backend/app/schemas/ride_offer.py`
- `backend/app/services/ride_policy.py`
- `backend/app/services/ride_lifecycle_service.py`
- `backend/app/services/ride_offer_service.py`
- `backend/app/services/ride_request_service.py`
- `backend/app/services/user_service.py`
- `backend/app/api/ride_request.py`
- `backend/app/api/ride_offer.py`
- `backend/app/api/driver.py`
- `backend/app/main.py`
- `backend/sql/*.sql`

Frontend:

- mobile network error parsing helpers
- ride models that read price and status fields
- driver flows to remove direct ride acceptance as an official path

## Scope Boundaries

This design intentionally avoids:

- admin-only advanced intervention flows beyond the current scope
- payment system redesign
- background job infrastructure redesign
- large UI redesign

The goal is a clean V1 backend-centered business flow, not a platform rewrite.

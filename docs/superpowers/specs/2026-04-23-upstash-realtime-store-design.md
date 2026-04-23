# Noor Express Upstash Realtime Store Design

**Date:** 2026-04-23

## Goal

Prepare Noor Express for a Redis-backed realtime layer without changing current behavior:

- keep `memory` as the default backend
- add an Upstash-ready implementation behind a feature flag
- keep MySQL as the source of truth
- limit Redis usage to driver presence, live positions, and nearby-driver lookup
- avoid any direct business dependency on Redis

## Scope

This design only prepares the realtime persistence layer. It does not:

- activate Upstash by default
- move ride lifecycle state into Redis
- add integration tests against a live Redis instance
- introduce background jobs or cleanup workers

## Current Constraints

- FastAPI backend with existing WebSocket flows
- SQLAlchemy + MySQL already persist business data
- the current realtime implementation uses `InMemoryRealtimeStore`
- application code already depends on the abstraction in `backend/app/realtime/store.py`
- Redis quota is currently blocked, so the Redis path must be present but inactive

## Activation Model

### Feature Flag

Add a backend switch:

- `REALTIME_STORE_BACKEND=memory` by default

Supported values:

- `memory`
- `redis`

Behavior:

- `memory`: current behavior stays unchanged
- `redis`: application tries to use the Upstash-backed implementation
- if `redis` is selected but the client cannot be initialized, the realtime layer fails open with safe neutral values and no business interruption

### Environment Variables

Add support for:

- `UPSTASH_REDIS_REST_URL`
- `UPSTASH_REDIS_REST_TOKEN`

These credentials are loaded from environment through the existing settings layer. They are never embedded in tests or committed into code.

## Architecture

### `backend/app/services/redis_client.py`

Responsibility:

- create and expose a single lazy async Upstash client
- use `upstash_redis.asyncio.Redis`
- return `None` when:
  - the Redis backend is not selected
  - required credentials are missing

Design rules:

- one initialization point only
- no business logic
- no retries or recovery loops in V1 beyond SDK defaults

### `backend/app/services/realtime_store.py`

Responsibility:

- provide the minimal Redis runtime helpers used by the Redis-backed store adapter

Public functions in this module:

- `set_driver_position(driver_id, lat, lng)`
- `get_driver_position(driver_id)`
- `is_driver_online(driver_id)`
- `find_nearby_drivers(lat, lng, radius_km)`

This module is Redis-specific. No business service should import it directly.

### `backend/app/realtime/store.py`

Responsibility:

- remain the single application-facing abstraction
- keep the current in-memory implementation
- add a Redis-backed implementation selected by config

Important boundary:

- business code continues to talk only to `RealtimeStore`
- Redis-specific details stay behind this adapter layer

This lets the existing connection manager and ride services keep their current dependency shape with minimal refactor.

## Redis Data Model

### Position Key

Key:

- `driver:{id}:pos`

Value:

```json
{
  "driver_id": 12,
  "lat": 34.0485,
  "lng": -6.8147,
  "ts": "2026-04-23T14:32:10Z"
}
```

Rules:

- structured JSON only
- TTL: `30s`
- used as the authoritative Redis-side signal that a driver position is still fresh

### Presence Key

Key:

- `driver:{id}:online`

Value:

- simple truthy marker such as `"1"`

Rules:

- TTL: `60s`
- indicates short-lived online presence

### GEO Key

Key:

- `drivers:geo`

Rules:

- updated on each position write
- contains `driver_id` as the GEO member
- used to query nearby drivers
- no cleanup worker in V1

## Write Flow

### `set_driver_position`

Required write order:

1. `SET driver:{id}:pos ... EX 30`
2. `SET driver:{id}:online "1" EX 60`
3. `GEOADD drivers:geo lng lat driver_id`

This order is intentional:

- the fresh position must exist before GEO membership is refreshed
- the online marker must be refreshed before the GEO index is updated
- if the final GEO write fails, the system still keeps a recent direct position and online signal

Errors:

- all Redis errors are swallowed inside the Redis-backed implementation
- the method becomes a no-op on failure

## Read Flow

### `get_driver_position`

- read `driver:{id}:pos`
- decode JSON
- return a normalized driver position object
- return `None` if the key is absent, invalid, or Redis is unavailable

### `is_driver_online`

- read `driver:{id}:online`
- return `True` only if the key exists
- return `False` for missing key, disabled Redis backend, or runtime error

### `find_nearby_drivers`

- query `drivers:geo` with `GEOSEARCH`
- for each returned `driver_id`, read `driver:{id}:pos`
- keep only drivers with a still-existing fresh position key
- build the nearby-driver response from the fresh position payload

This filtering step replaces explicit cleanup:

- `drivers:geo` may still contain stale members
- stale GEO members are ignored if `driver:{id}:pos` has expired
- no manual cleanup path is required in V1

If the Python SDK does not expose the exact GEO helper needed, the implementation may use the client `execute([...])` escape hatch for the Redis command while preserving the same adapter boundary.

## Compatibility Strategy

The current application still expects the richer `RealtimeStore` abstraction. To avoid a heavy refactor now:

- the in-memory implementation stays as-is
- the Redis-backed adapter implements the existing interface shape needed by current callers
- methods that exist for compatibility but are not part of the minimal Redis service can be implemented in the adapter using the minimal Redis primitives and safe neutral behavior

Compatibility behavior for the Redis-backed adapter:

- `list_driver_positions()` reads driver ids from the GEO structure, then loads `driver:{id}:pos` for each id and filters out expired positions
- `remove_driver()` deletes:
  - `driver:{id}:pos`
  - `driver:{id}:online`
  - the member from `drivers:geo`
- `cleanup_expired_drivers()` becomes a harmless no-op in V1
- `set_driver_status()` / `get_driver_status()` stay adapter-local compatibility methods only if current callers still require them; they must not introduce a new Redis key in V1

The important rule is that no caller outside `backend/app/realtime/store.py` learns anything about Redis.

## Failure Handling

The Redis path must never block the core ride flow.

Rules:

- no Redis exception should bubble into API or business logic
- write failures become silent no-ops
- read failures return safe neutral values:
  - `None`
  - `False`
  - `[]`
- MySQL remains the only source of truth for ride state, users, offers, and history

Optional startup behavior:

- log a single warning when `REALTIME_STORE_BACKEND=redis` is requested but the client cannot be created
- avoid per-request warning spam

## Testing Strategy

Tests stay unit-only for V1.

Rules:

- no network access
- no Upstash integration tests
- no real credentials in tests
- Redis is used only at backend runtime, never in automated tests

Test coverage:

- config-based backend selection defaults to `memory`
- Redis client factory returns `None` safely when Redis is disabled or credentials are missing
- `set_driver_position` writes structured JSON and respects the required order:
  - `SET pos`
  - `SET online`
  - `GEOADD`
- `get_driver_position` returns decoded structured payload
- `is_driver_online` reflects key existence
- `find_nearby_drivers` filters out stale GEO entries by checking the position key
- Redis runtime failures degrade to safe neutral values without raising

Implementation approach:

- use fake async Redis clients / mocks
- assert command calls and return values
- keep tests fast and deterministic

## Out of Scope for V1

- Redis pub/sub for cross-instance WebSocket fanout
- Redis Streams for durable notifications
- cleanup workers for stale GEO members
- driver status values beyond simple online presence
- ride state caching
- integration tests against a live Upstash database

## Expected Outcome

After this design is implemented:

- Noor Express still behaves exactly as it does today by default
- the codebase is structurally ready for controlled Upstash activation when quota allows
- enabling Redis will be a controlled configuration change, not a refactor
- realtime persistence remains simple, isolated, and reversible

# Ride V1 Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor Noor Express to use one backend-owned ride lifecycle with strict offer negotiation, locked pricing, verified drivers, and structured domain errors.

**Architecture:** Introduce a central `ride_lifecycle_service` plus shared ride policy rules, simplify `ride_offer_service`, and keep API routes as thin façades. Preserve mobile compatibility where possible while removing the direct-accept ride flow from official behavior.

**Tech Stack:** FastAPI, SQLAlchemy async, Pydantic, Flutter, Dio, Python `unittest`

---

### Task 1: Document The Design In Repo

**Files:**
- Create: `docs/superpowers/specs/2026-04-23-ride-v1-architecture-design.md`
- Create: `docs/superpowers/plans/2026-04-23-ride-v1-architecture.md`

- [ ] Save the approved design and implementation plan in the repo.

### Task 2: Add Backend Test Scaffolding

**Files:**
- Create: `backend/tests/__init__.py`
- Create: `backend/tests/test_ride_lifecycle_rules.py`
- Create: `backend/tests/test_api_error_payloads.py`

- [ ] Write failing tests for lifecycle invariants and structured errors.
- [ ] Run `& .\\venv\\Scripts\\python.exe -m unittest discover backend/tests -v` and confirm failures.

### Task 3: Add Shared API Error Infrastructure

**Files:**
- Create: `backend/app/core/api_errors.py`
- Modify: `backend/app/main.py`
- Modify: `backend/app/core/security.py`

- [ ] Add structured `{code, message}` API error responses.
- [ ] Register exception handlers in FastAPI.
- [ ] Keep legacy `HTTPException` paths compatible through global normalization.

### Task 4: Add Ride Policy And Lifecycle Services

**Files:**
- Create: `backend/app/services/ride_policy.py`
- Create: `backend/app/services/ride_lifecycle_service.py`
- Modify: `backend/app/models/ride_request.py`
- Modify: `backend/app/models/ride_offer.py`
- Modify: `backend/app/schemas/ride_request.py`
- Modify: `backend/app/schemas/ride_offer.py`
- Modify: `backend/app/services/user_service.py`

- [ ] Add new statuses and shared policy checks.
- [ ] Add strict lifecycle methods for create, offer acceptance, arrival, start, complete, cancel, and expire.
- [ ] Enforce verified-driver and single-active-ride rules in backend services.

### Task 5: Simplify Offer Service

**Files:**
- Modify: `backend/app/services/ride_offer_service.py`

- [ ] Reduce offer service to offer-only responsibilities.
- [ ] Delegate winning-offer acceptance and ride status changes to `ride_lifecycle_service`.
- [ ] Keep pending-offer counting and resynchronization hooks explicit.

### Task 6: Thin API Routes

**Files:**
- Modify: `backend/app/api/ride_request.py`
- Modify: `backend/app/api/ride_offer.py`
- Modify: `backend/app/api/driver.py`

- [ ] Remove route-level transition logic.
- [ ] Disable `POST /ride-requests/{id}/accept` with a clear domain error.
- [ ] Make `GET /ride-requests/active` the official resync path.

### Task 7: Database And Compatibility Updates

**Files:**
- Create: `backend/sql/2026_04_23_ride_v1_architecture.sql`
- Modify: `backend/app/services/admin_service.py`
- Modify: `backend/app/services/ride_request_service.py`

- [ ] Add persistence support for `offered`, `agreed_price`, and expanded offer statuses.
- [ ] Update stats and admin serialization to use the locked agreed price consistently.

### Task 8: Mobile Compatibility Pass

**Files:**
- Create: `mobile/lib/core/network/api_error.dart`
- Modify: `mobile/lib/features/home/client/data/client_rides_repository.dart`
- Modify: `mobile/lib/features/home/driver/data/driver_rides_repository.dart`
- Modify: `mobile/lib/features/home/driver/data/driver_repository.dart`
- Modify: `mobile/lib/features/negotiation/data/datasources/negotiation_datasource.dart`
- Modify: `mobile/lib/features/ride_tracking/data/datasources/tracking_remote_datasource.dart`
- Modify: `mobile/lib/features/profile/data/datasources/profile_datasource.dart`
- Modify: `mobile/lib/features/map/data/map_repository.dart`
- Modify: `mobile/lib/features/address_search/data/datasources/address_datasource.dart`
- Modify: `mobile/lib/features/driver_onboarding/data/datasources/driver_profile_datasource.dart`
- Modify: `mobile/lib/features/home/client/data/models/client_ride.dart`
- Modify: `mobile/lib/features/home/driver/data/models/driver_ride.dart`
- Modify: `mobile/lib/features/ride_tracking/data/models/ride_tracking_model.dart`
- Modify: `mobile/lib/features/profile/data/models/client_profile_model.dart`
- Modify: `mobile/lib/shared/widgets/status_badge.dart`
- Modify: `mobile/lib/features/home/driver/presentation/controllers/ride_driver_controller.dart`
- Modify: `mobile/lib/features/home/driver/data/driver_rides_repository.dart`

- [ ] Parse structured API errors cleanly.
- [ ] Read `agreed_price` and `offered` without breaking the existing UI.
- [ ] Remove direct ride-accept flow from mobile repositories/controllers.

### Task 9: Verification

**Files:**
- Test: `backend/tests/test_ride_lifecycle_rules.py`
- Test: `backend/tests/test_api_error_payloads.py`

- [ ] Run backend tests.
- [ ] Run any safe static verification available for the touched mobile/backend files.
- [ ] Summarize final file changes and remaining compatibility risks.

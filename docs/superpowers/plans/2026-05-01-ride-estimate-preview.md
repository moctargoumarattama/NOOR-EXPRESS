# Ride Estimate Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a cached pre-ride estimate endpoint and surface its enriched data in the existing Flutter booking confirmation flow.

**Architecture:** Reuse the existing routing, pricing, realtime-driver, and booking-preview layers. The backend will expose one shared estimate payload for both `/rides/estimate` and `/pricing/estimate`, and Flutter will enrich the existing `PriceEstimate` and `RouteSummaryCard` instead of creating parallel models or widgets.

**Tech Stack:** FastAPI, SQLAlchemy async session, existing in-memory cache pattern, Flutter, Riverpod, existing widget tests.

---

### Task 1: Backend estimate contract

**Files:**
- Modify: `backend/tests/test_routing_service.py`
- Modify: `backend/tests/test_ride_history_wallet.py`

- [ ] Add failing backend tests for enriched estimate payload, pricing compatibility, and zero-driver availability.
- [ ] Run targeted pytest commands and confirm the new tests fail for the expected missing fields or endpoint behavior.

### Task 2: Backend estimate implementation

**Files:**
- Modify: `backend/app/services/routing_service.py`
- Modify: `backend/app/services/pricing_service.py`
- Modify: `backend/app/services/ride_lifecycle_service.py`
- Modify: `backend/app/schemas/pricing.py`
- Modify: `backend/app/api/pricing.py`
- Modify: `backend/app/api/ride_request.py`
- Modify: `backend/app/main.py`

- [ ] Add a shared ride-estimate service flow that combines route metrics, pricing, availability count, and 60-second caching.
- [ ] Keep `/pricing/estimate` working by returning the enriched shared payload.
- [ ] Add `/rides/estimate` without moving business logic into the route layer.
- [ ] Re-run the targeted backend tests until green.

### Task 3: Flutter estimate model and UI

**Files:**
- Modify: `mobile/test/features/home/client/client_home_controller_test.dart`
- Modify: `mobile/test/features/home/client/search_bottom_sheet_route_preview_test.dart`
- Modify: `mobile/test/features/home/client/ride_booking_components_test.dart`
- Modify: `mobile/lib/features/home/client/data/models/client_ride.dart`
- Modify: `mobile/lib/features/home/client/data/client_rides_repository.dart`
- Modify: `mobile/lib/features/home/client/presentation/widgets/route_summary_card.dart`
- Modify: `mobile/lib/features/home/client/presentation/widgets/search_bottom_sheet_sections.dart`

- [ ] Add failing Flutter tests for enriched `PriceEstimate` parsing and availability messaging in the route preview.
- [ ] Point the client booking flow to `/rides/estimate` while leaving existing compatibility endpoints untouched elsewhere.
- [ ] Extend the existing summary card to show the price range and the availability message rules:
  - count only when `>= 1`
  - red discrete empty-state when `0`
- [ ] Re-run widget and controller tests until green.

### Task 4: Verification

**Files:**
- Modify: `docs/superpowers/plans/2026-05-01-ride-estimate-preview.md`

- [ ] Run targeted `pytest` for backend estimate coverage.
- [ ] Run targeted `flutter test` for booking preview coverage.
- [ ] Run `flutter analyze`.
- [ ] Update this plan if execution deviates from the original path.

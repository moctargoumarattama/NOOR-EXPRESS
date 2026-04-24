# Noor Express Android Background Tracking Design

**Date:** 2026-04-24

## Goal

Guarantee the following Android product promise for driver rides:

> Tant que l'application n'est pas fermee manuellement, le tracking chauffeur continue de fonctionner en arriere-plan, meme ecran eteint.

The implementation must make tracking credible in real conditions, stay aligned with the existing backend-owned ride lifecycle, and avoid a large refactor.

## Product Promise

### In Scope

- Android only
- Driver tracking during an active ride
- App in background
- Screen turned off
- Realtime position updates continue to reach the backend and the client
- Persistent Android notification while tracking is active during a ride

### Out of Scope

- iOS implementation
- Tracking after manual swipe kill
- Tracking after phone reboot
- Auto-restart on boot
- Full rewrite of the existing realtime stack
- Background tracking while the driver is merely online without an active ride

## User-Facing Behavior

### Driver

During an active ride, Android shows a persistent tracking notification.

Approved copy:

`Pendant une course active, une notification de tracking apparait. C'est normal et necessaire pour que votre position soit transmise au client, meme ecran eteint.`

The notification appears only while the ride status is one of:

- `accepted`
- `arrived`
- `started`

The notification disappears as soon as the active ride ends or is no longer valid.

### Client

The client should continue seeing driver movement even if the driver's screen is off or the driver app is backgrounded, as long as the app has not been manually closed.

## Current Problem

The current mobile implementation ties GPS production to Flutter UI controllers and activity-bound lifecycle:

- driver tracking currently starts from the tracking controller and screen lifecycle
- Android manifest currently lacks background-location-specific permissions required for a strong background promise
- there is no dedicated Android foreground service that owns tracking while the app is backgrounded
- when the app is backgrounded long enough, Android may pause or kill the activity, causing the GPS stream to stop and the client to see a frozen position

This makes the current implementation unsuitable for a product promise about real background continuity.

## Architecture Decision

Use an Android foreground service with a dedicated background execution path for driver tracking during active rides.

The system will be intentionally asymmetric:

- the backend remains the source of truth for ride state
- the Android background service becomes the source of GPS emission during active rides
- Flutter tracking screens become state observers and command surfaces, not the long-lived owner of GPS emission

## High-Level Design

### Shared Coordinator

Add a single app-facing coordinator responsible for background tracking orchestration:

- `RideTrackingBackgroundCoordinator`

Responsibilities:

- start background tracking when a driver has an active ride
- stop background tracking when the ride is no longer active
- synchronize the background service with backend truth
- expose lightweight status to the Flutter UI

Everything outside the platform bridge talks to this coordinator rather than directly to the background plugin.

### Android Bridge

Add an Android-specific background tracking bridge:

- `AndroidRideTrackingBackgroundBridge`

Responsibilities:

- configure and start the Android foreground service
- maintain the service notification
- run the background isolate entrypoint
- receive commands from Flutter UI
- report service state back to Flutter

### Background Runtime

Add a background runtime owned by the service:

- `DriverTrackingBackgroundRuntime`

Responsibilities:

- restore required session and ride context
- validate that the ride is still active
- start location streaming with Android-specific settings
- maintain the websocket connection
- send throttled location updates
- reconnect when websocket drops
- stop itself when the backend or local state indicates tracking is no longer valid

### Existing Tracking UI

Existing driver tracking screens and controllers stay in place, but their responsibility changes:

- they no longer own the only GPS loop
- they request start/stop through the coordinator
- they continue to render ride state, status banners, and actions
- they resync with backend truth on foreground return

## Android Platform Design

### Plugin Strategy

Use `flutter_background_service` for Android foreground service execution.

Reason:

- supports a dedicated background service model suitable for Android
- keeps implementation mostly in Dart for faster iteration
- avoids an immediate large native Android buildout
- is sufficient for the validated Android-only scope

### Required Android Permissions And Declarations

Update Android configuration to support a location foreground service:

- `android.permission.ACCESS_FINE_LOCATION`
- `android.permission.ACCESS_COARSE_LOCATION`
- `android.permission.ACCESS_BACKGROUND_LOCATION`
- `android.permission.FOREGROUND_SERVICE`
- `android.permission.FOREGROUND_SERVICE_LOCATION`
- `android.permission.POST_NOTIFICATIONS`

Also declare the service with foreground service type `location`.

The notification icon and channel must be configured explicitly for the service.

### Notification Rules

The foreground notification:

- appears only when ride status is `accepted`, `arrived`, or `started`
- is ongoing and not dismissible while tracking is active
- clearly tells the driver why it is visible
- disappears immediately when the ride leaves active tracking states

### Location Settings

Use Android-specific location settings for active ride tracking:

- `LocationAccuracy.high`
- small but not noisy `distanceFilter`
- explicit `intervalDuration`
- no arbitrary stream timeout for the tracking loop

The final send policy should remain conservative:

- throttle outbound updates to avoid battery and websocket noise
- keep updates frequent enough to look live on the client

The tracking service should prefer one throttling policy owned in one place, not duplicated between UI and background runtime.

## Ride Lifecycle Integration

### Start Conditions

Background tracking starts only when all of the following are true:

- current user is a driver
- there is an active ride
- ride status is one of `accepted`, `arrived`, `started`
- the driver has a valid authenticated session
- required location permission has been granted

### Stop Conditions

Background tracking stops when any of the following occurs:

- ride becomes `completed`
- ride becomes `cancelled`
- ride becomes `expired`
- backend reports no active ride
- user logs out
- app explicitly commands stop because ride ownership no longer matches the driver

### Backend Truth Check

On service start and on important reconnect/resume events, the service must verify backend truth through the existing active ride path before continuing to emit GPS.

This prevents stale local tracking after ride termination.

## Realtime Contract

### Websocket

Reuse the existing authenticated driver websocket route if possible:

- same backend websocket endpoint
- same auth token model
- same location payload shape

This avoids unnecessary backend protocol changes.

### Single Producer Rule

There must never be two competing producers sending driver GPS for the same ride.

During an active tracked ride on Android:

- the foreground service is the GPS producer
- the Flutter tracking screen must not continue its own parallel send loop

The tracking screen can still:

- render map state
- refresh backend snapshot
- show connection and recovery UI

But it must not duplicate the background service's location publishing path.

## App Lifecycle Rules

### Foreground To Background

When the app moves to background during an active ride:

- tracking continues in the Android foreground service
- websocket and GPS remain owned by the background runtime
- no UI lifecycle callback should stop tracking

### Background To Foreground

When the app returns to foreground:

- the UI refreshes ride state from backend truth
- it queries current service state
- it does not create a second GPS publishing loop if the service is already active

### Manual App Close

If the user manually closes the app:

- no continuity guarantee is provided
- the service may stop
- this is explicitly outside the product promise

## Error Handling

### Permission Problems

If background-capable location permission is missing:

- background tracking must not start silently
- driver sees a clear action-oriented explanation
- app can deep-link to app settings

### Service Failure

If the foreground service fails to start:

- log the failure
- show a visible warning to the driver
- avoid pretending tracking is still live

### Websocket Failure

If websocket fails:

- retry with bounded reconnect logic
- keep service alive while retries continue
- stop only if backend truth invalidates the active ride or the session becomes unusable

### GPS Failure

If GPS becomes temporarily unavailable:

- keep the service alive
- surface degraded-state status to the UI when visible
- resume sending as soon as location updates recover

## Files Expected To Change

### Mobile Shared / Core

- `mobile/lib/main.dart`
- `mobile/lib/core/location/location_service.dart`
- `mobile/lib/core/state/session_controller.dart`
- `mobile/pubspec.yaml`
- `mobile/pubspec.lock`

### New Mobile Background Tracking Layer

- `mobile/lib/core/tracking_background/ride_tracking_background_coordinator.dart`
- `mobile/lib/core/tracking_background/android_ride_tracking_background_bridge.dart`
- `mobile/lib/core/tracking_background/driver_tracking_background_runtime.dart`
- `mobile/lib/core/tracking_background/tracking_background_contract.dart`

### Existing Ride Tracking Layer

- `mobile/lib/features/ride_tracking/presentation/controllers/tracking_controller.dart`
- `mobile/lib/features/ride_tracking/presentation/controllers/tracking_controller_realtime.dart`
- `mobile/lib/features/ride_tracking/data/datasources/tracking_websocket_datasource.dart`
- `mobile/lib/features/ride_tracking/presentation/screens/driver_tracking_screen.dart`

### Android Platform Files

- `mobile/android/app/src/main/AndroidManifest.xml`
- Android service declaration and plugin-specific configuration files as required by the chosen package
- notification icon assets if required

### Tests

- new unit tests for coordinator start/stop rules
- new tests for service command contract
- updated tracking tests to ensure UI no longer acts as duplicate GPS producer

## Validation Strategy

### Automated

- Flutter unit tests for coordinator logic
- tests covering start/stop decisions based on ride status
- tests covering service-state reconciliation when returning to foreground
- static verification with `flutter analyze`

### Real Android Device Validation

Required manual product validation on real phones:

1. driver app foreground -> client sees movement
2. driver app background -> client still sees movement
3. driver app background + screen off for several minutes -> client still sees movement
4. reopen driver app -> state remains correct, no duplicated loops
5. ride completed -> notification disappears, tracking stops
6. ride cancelled -> tracking stops
7. temporary network loss -> service reconnects or degrades clearly

### Explicit Non-Validation Claims

Do not claim support for:

- swipe kill continuity
- reboot continuity
- iOS continuity

## Risks

### Android OEM Power Policies

Some manufacturers may still aggressively restrict background behavior. The foreground service significantly improves reliability, but device-specific battery policies can still interfere. This must be documented as an operational risk, not hidden.

### Duplicate Tracking Loops

If UI and service both emit GPS, the system will become noisy and harder to debug. The implementation must enforce one producer.

### Permission Friction

Background location permission on Android is sensitive. The app must request it only in the active-ride context where the value is obvious.

## Non-Goals

- no iOS implementation in this phase
- no new backend ride-state model
- no migration to a new transport protocol
- no tracking while merely online without an active ride
- no boot restart logic
- no recovery after manual app close

## Success Criteria

This design is successful when:

- the driver can lock the screen during an active ride and continue sending location on Android
- the client sees credible movement instead of a frozen marker
- tracking stops promptly when the ride is no longer active
- the implementation remains maintainable and backend-first
- the product promise is true without over-promising unsupported cases

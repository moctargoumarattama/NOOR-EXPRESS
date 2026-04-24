# Noor Android Background Tracking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the approved Android-only product promise for driver rides: while an active ride is in progress and the app has not been manually closed, driver tracking keeps running in the background, including with the screen off, and the client continues seeing credible movement.

**Architecture:** Keep the backend as the source of truth for ride state and reuse the existing `/ride-requests/active` snapshot plus the current driver websocket contract. Add a thin Android background-tracking layer around the current Flutter stack so the foreground service becomes the single GPS producer during active driver rides, while `TrackingController` remains an observer and action surface for the UI.

**Tech Stack:** Flutter, Riverpod, Android foreground service, `flutter_background_service`, `geolocator`, `permission_handler`, `web_socket_channel`, `flutter_test`

---

## Guardrails

- Android only in this phase. Do not add iOS work to this implementation.
- Keep the backend untouched unless device validation proves the existing active-ride or websocket contract is insufficient.
- Do not promise continuity after manual swipe kill or phone reboot.
- Enforce one GPS producer at a time:
  - background service owns GPS emission when active
  - driver UI may only fall back to local GPS emission if the background service is not running
- Screen dispose must not stop an active ride tracking service.

## Planned File Map

- Modify: `mobile/pubspec.yaml` - add the Android background service dependency and keep existing location/notification packages.
- Modify: `mobile/pubspec.lock`
- Modify: `mobile/lib/main.dart` - bootstrap the background service before `runApp()`.
- Modify: `mobile/lib/core/location/location_service.dart` - add Android-specific active-ride location settings plus background-permission helpers.
- Modify: `mobile/lib/core/state/session_controller.dart` - stop the background service on logout and force logout.
- Create: `mobile/lib/core/tracking_background/tracking_background_contract.dart` - shared command names, service states, ride-status helpers, and serializable payload keys.
- Create: `mobile/lib/core/tracking_background/android_ride_tracking_background_bridge.dart` - `flutter_background_service` wrapper for start, stop, sync, and state events.
- Create: `mobile/lib/core/tracking_background/ride_tracking_background_coordinator.dart` - app-facing orchestration layer and provider.
- Create: `mobile/lib/core/tracking_background/driver_tracking_background_runtime.dart` - background isolate entrypoint, GPS loop, websocket loop, and backend-truth checks.
- Modify: `mobile/lib/features/ride_tracking/presentation/controllers/tracking_controller.dart`
- Modify: `mobile/lib/features/ride_tracking/presentation/controllers/tracking_controller_realtime.dart`
- Modify: `mobile/lib/features/ride_tracking/presentation/controllers/tracking_controller_snapshot.dart` - resync coordinator when ride truth changes.
- Modify: `mobile/lib/features/ride_tracking/presentation/screens/driver_tracking_screen.dart` - surface permission/service degradation clearly without fake success states.
- Modify: `mobile/lib/shared/copy/ride_ui_copy.dart` - add approved background-tracking notification and permission guidance copy.
- Modify: `mobile/android/app/src/main/AndroidManifest.xml` - add Android background tracking permissions and service declaration.
- Create: `mobile/android/app/src/main/res/drawable/ic_tracking_notification.xml` - small monochrome notification icon for the foreground service.
- Create: `mobile/test/core/tracking_background/ride_tracking_background_coordinator_test.dart`
- Create: `mobile/test/core/tracking_background/android_ride_tracking_background_bridge_test.dart`
- Create: `mobile/test/core/tracking_background/driver_tracking_background_runtime_test.dart`
- Create: `mobile/test/features/ride_tracking/tracking_controller_background_handoff_test.dart`

### Task 1: Add The Background Tracking Contract And Test Scaffolding

**Files:**
- Modify: `mobile/pubspec.yaml`
- Modify: `mobile/pubspec.lock`
- Create: `mobile/lib/core/tracking_background/tracking_background_contract.dart`
- Create: `mobile/test/core/tracking_background/ride_tracking_background_coordinator_test.dart`
- Create: `mobile/test/features/ride_tracking/tracking_controller_background_handoff_test.dart`

- [ ] **Step 1: Add the Android background service package**

Add `flutter_background_service` to `pubspec.yaml` and keep the dependency set minimal. Do not add battery-optimization or boot-restart packages in this phase.

Run: `Set-Location mobile; & "C:\Users\hp\Desktop\flutter_windows_3.41.7-stable\flutter\bin\flutter.bat" pub get`

Expected: PASS and `pubspec.lock` updates only for the new background-service dependency tree.

- [ ] **Step 2: Write the failing contract/coordinator tests first**

Create tests that lock the product rules before implementation:

- `isTrackedRideStatus(...)` is `true` only for `accepted`, `arrived`, and `started`
- coordinator refuses to start when the user is not a driver, there is no ride, or permissions are blocked
- controller handoff test proves driver UI does not start its local GPS stream when the background producer is already running
- controller handoff test proves driver UI can still use its local GPS stream only as a foreground fallback when the service is unavailable

Use a small fake bridge API instead of the real plugin in these tests.

- [ ] **Step 3: Run the new tests and confirm they fail for the right reason**

Run: `Set-Location mobile; & "C:\Users\hp\Desktop\flutter_windows_3.41.7-stable\flutter\bin\flutter.bat" test test\core\tracking_background\ride_tracking_background_coordinator_test.dart test\features\ride_tracking\tracking_controller_background_handoff_test.dart`

Expected: FAIL because the tracking background contract and coordinator do not exist yet.

- [ ] **Step 4: Add the serializable contract layer**

Define one small shared contract file that both the UI isolate and the background isolate can use without Riverpod:

```dart
enum TrackingBackgroundServiceState {
  stopped,
  starting,
  running,
  permissionBlocked,
  rideInactive,
  degraded,
}

bool isTrackedRideStatus(RideTrackingStatus status) =>
    status == RideTrackingStatus.accepted ||
    status == RideTrackingStatus.arrived ||
    status == RideTrackingStatus.started;
```

Include:

- command names such as `startTracking`, `stopTracking`, `syncRide`, `queryState`
- payload keys for `ride_id`, `driver_id`, `ride_status`, `reason`, and `last_error`
- one lightweight immutable snapshot model for service state reporting

- [ ] **Step 5: Re-run the new tests**

Run: `Set-Location mobile; & "C:\Users\hp\Desktop\flutter_windows_3.41.7-stable\flutter\bin\flutter.bat" test test\core\tracking_background\ride_tracking_background_coordinator_test.dart test\features\ride_tracking\tracking_controller_background_handoff_test.dart`

Expected: still FAIL, but now only on missing coordinator/bridge behavior rather than missing shared types.

### Task 2: Implement The Coordinator And Android Bridge

**Files:**
- Create: `mobile/lib/core/tracking_background/android_ride_tracking_background_bridge.dart`
- Create: `mobile/lib/core/tracking_background/ride_tracking_background_coordinator.dart`
- Create: `mobile/test/core/tracking_background/android_ride_tracking_background_bridge_test.dart`
- Modify: `mobile/test/core/tracking_background/ride_tracking_background_coordinator_test.dart`

- [ ] **Step 1: Write the failing bridge tests**

Cover the plugin wrapper behavior, not Android itself:

- `startService` sends one start payload with the ride and driver identifiers
- `stopService` does not throw when already stopped
- `queryState` returns the last known snapshot
- state events are normalized into one stream the coordinator can consume

- [ ] **Step 2: Implement the Android bridge as a thin wrapper**

Wrap `flutter_background_service` behind a small interface so the rest of the app does not know plugin details:

```dart
abstract class RideTrackingBackgroundBridge {
  Stream<TrackingBackgroundSnapshot> get states;
  Future<void> initialize();
  Future<void> startTracking(TrackingBackgroundStartRequest request);
  Future<void> syncRide(TrackingBackgroundStartRequest request);
  Future<void> stopTracking({String? reason});
  Future<TrackingBackgroundSnapshot> queryState();
}
```

Rules:

- keep all plugin event names inside this file
- normalize plugin maps into typed snapshots
- treat duplicate `startTracking` calls as idempotent

- [ ] **Step 3: Implement the coordinator around business rules**

The coordinator should be the only app-facing API used by tracking screens/controllers. It should:

- decide whether a ride status requires background tracking
- request permission checks through `LocationService`
- start or sync the service when a driver ride becomes active
- stop the service when the ride becomes `completed`, `cancelled`, `expired`, or missing
- expose one Riverpod-friendly state stream/value for the UI
- never stop the service just because a screen is disposed

- [ ] **Step 4: Re-run the background contract tests**

Run: `Set-Location mobile; & "C:\Users\hp\Desktop\flutter_windows_3.41.7-stable\flutter\bin\flutter.bat" test test\core\tracking_background`

Expected: PASS

### Task 3: Configure Android Platform And App Bootstrap

**Files:**
- Modify: `mobile/lib/main.dart`
- Modify: `mobile/android/app/src/main/AndroidManifest.xml`
- Create: `mobile/android/app/src/main/res/drawable/ic_tracking_notification.xml`
- Modify: `mobile/lib/shared/copy/ride_ui_copy.dart`

- [ ] **Step 1: Initialize the bridge/service at app startup**

Update `main.dart` so the background service infrastructure is configured before `runApp()`, just like Firebase messaging setup is done today. Keep startup order simple:

1. `WidgetsFlutterBinding.ensureInitialized()`
2. tile cache init
3. Firebase/notifications init
4. background tracking bridge init
5. `runApp(...)`

Add a top-level service entrypoint registration in the background runtime file and make sure it is reachable from startup.

- [ ] **Step 2: Add the Android permissions and service declaration**

Update `AndroidManifest.xml` to include:

- `android.permission.ACCESS_BACKGROUND_LOCATION`
- `android.permission.FOREGROUND_SERVICE_LOCATION`

Keep the existing `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `FOREGROUND_SERVICE`, and `POST_NOTIFICATIONS` permissions.

Also declare the foreground service with type `location` as required by the chosen plugin version.

- [ ] **Step 3: Add the persistent notification assets and copy**

Create a clean small notification icon and centralize the approved copy in `RideUiCopy`:

`Pendant une course active, une notification de tracking apparait. C'est normal et necessaire pour que votre position soit transmise au client, meme ecran eteint.`

Also add one short permission-blocked message and one degraded-service message for the driver UI.

- [ ] **Step 4: Run static verification after the platform/bootstrap changes**

Run: `Set-Location mobile; & "C:\Users\hp\Desktop\flutter_windows_3.41.7-stable\flutter\bin\flutter.bat" analyze`

Expected: PASS

### Task 4: Implement The Driver Background Runtime

**Files:**
- Create: `mobile/lib/core/tracking_background/driver_tracking_background_runtime.dart`
- Modify: `mobile/lib/core/location/location_service.dart`
- Create: `mobile/test/core/tracking_background/driver_tracking_background_runtime_test.dart`

- [ ] **Step 1: Write the failing runtime tests**

Cover the long-lived tracking rules:

- runtime refuses to run if backend truth reports no active ride
- runtime refuses to run if the ride status is outside `accepted`, `arrived`, `started`
- runtime keeps its GPS stream alive without the old arbitrary timeout
- runtime throttles outbound websocket location sends in one place
- runtime attempts bounded reconnect on websocket failure
- runtime transitions to `degraded` on temporary GPS failure instead of pretending everything is healthy

- [ ] **Step 2: Add Android-specific location helpers**

Extend `LocationService` so the background runtime can request one explicit active-ride Android profile, for example:

- `LocationAccuracy.high`
- `distanceFilter` around the current `8m` default unless tests or field trials prove otherwise
- explicit Android interval configuration
- no stream timeout
- background-permission helpers separate from foreground-only permission checks

Do not spread location-policy constants across UI and runtime files.

- [ ] **Step 3: Implement the background isolate runtime**

Create a top-level entrypoint similar to:

```dart
@pragma('vm:entry-point')
Future<void> driverTrackingBackgroundEntrypoint(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  await DriverTrackingBackgroundRuntime(service: service).run();
}
```

Inside the runtime:

- rebuild only the minimal dependencies needed outside Riverpod:
  - `SecureStorageService`
  - `ApiClient`
  - `TrackingRemoteDatasource`
  - `TrackingWebSocketDatasource`
  - `LocationService`
- re-read backend truth from `/ride-requests/active` before starting GPS emission
- connect to the existing driver websocket route
- publish throttled location updates through the current payload shape
- keep the foreground notification alive while the ride remains active
- stop itself immediately when the ride becomes invalid or the session disappears

- [ ] **Step 4: Re-run the runtime tests**

Run: `Set-Location mobile; & "C:\Users\hp\Desktop\flutter_windows_3.41.7-stable\flutter\bin\flutter.bat" test test\core\tracking_background\driver_tracking_background_runtime_test.dart`

Expected: PASS

### Task 5: Hand Off GPS Ownership From The Driver UI To The Service

**Files:**
- Modify: `mobile/lib/features/ride_tracking/presentation/controllers/tracking_controller.dart`
- Modify: `mobile/lib/features/ride_tracking/presentation/controllers/tracking_controller_realtime.dart`
- Modify: `mobile/lib/features/ride_tracking/presentation/controllers/tracking_controller_snapshot.dart`
- Modify: `mobile/lib/features/ride_tracking/presentation/screens/driver_tracking_screen.dart`
- Modify: `mobile/lib/core/state/session_controller.dart`
- Modify: `mobile/test/features/ride_tracking/tracking_controller_background_handoff_test.dart`

- [ ] **Step 1: Update the failing handoff test to capture the final rule**

Lock these exact behaviors:

- when the driver has an active tracked ride and the service reports `running`, `TrackingController` does not call `LocationService.streamPosition()`
- when the service is unavailable or permission-blocked, the driver UI may fall back to local GPS only while the screen is alive
- client tracking behavior stays unchanged
- `TrackingController.stop()` disconnects UI subscriptions but does not stop a valid background tracking service

- [ ] **Step 2: Route driver tracking through the coordinator**

Update controller flow so:

- `start()` still refreshes snapshot and binds realtime
- driver mode also calls `RideTrackingBackgroundCoordinator.syncWithRide(...)`
- local driver GPS streaming is skipped when the coordinator says the service is the active producer
- `_refreshSnapshot(...)` re-syncs the coordinator whenever ride truth changes
- ride actions like complete/cancel lead to a coordinator stop when the backend state leaves tracked statuses

- [ ] **Step 3: Stop the service only from lifecycle boundaries that really end tracking**

Integrate the coordinator into `SessionController`:

- `logout()` and `forceLogout()` stop the background service before clearing session state
- screen disposal does not stop the service
- returning to foreground refreshes UI state and service state, but does not create a second producer

- [ ] **Step 4: Surface honest driver-facing recovery states**

Update `DriverTrackingScreen` so the driver sees:

- a clear warning when background permission is missing
- a degraded warning when the service failed or GPS/websocket is unstable
- no fake "tracking live" UI if the service failed to start

Reuse the existing recovery/banner patterns instead of adding a new heavy UI subsystem.

- [ ] **Step 5: Re-run the driver handoff tests**

Run: `Set-Location mobile; & "C:\Users\hp\Desktop\flutter_windows_3.41.7-stable\flutter\bin\flutter.bat" test test\features\ride_tracking\tracking_controller_background_handoff_test.dart`

Expected: PASS

### Task 6: Full Verification And Real Device Validation

**Files:**
- Test: `mobile/test/core/tracking_background/ride_tracking_background_coordinator_test.dart`
- Test: `mobile/test/core/tracking_background/android_ride_tracking_background_bridge_test.dart`
- Test: `mobile/test/core/tracking_background/driver_tracking_background_runtime_test.dart`
- Test: `mobile/test/features/ride_tracking/tracking_controller_background_handoff_test.dart`
- Test: existing tracking and notification tests already in the repo

- [ ] **Step 1: Run the targeted Flutter tests**

Run: `Set-Location mobile; & "C:\Users\hp\Desktop\flutter_windows_3.41.7-stable\flutter\bin\flutter.bat" test test\core\tracking_background test\features\ride_tracking`

Expected: PASS

- [ ] **Step 2: Run static verification**

Run: `Set-Location mobile; & "C:\Users\hp\Desktop\flutter_windows_3.41.7-stable\flutter\bin\flutter.bat" analyze`

Expected: PASS

- [ ] **Step 3: Validate the product promise on real Android phones**

Run this on at least one driver phone and one client phone:

1. driver app foreground, ride accepted: client sees movement
2. driver app backgrounded: client still sees movement
3. driver app backgrounded plus screen off for several minutes: client still sees movement
4. reopen driver app: UI state is correct and there is still only one producer
5. complete the ride: notification disappears and tracking stops
6. cancel the ride: tracking stops
7. temporary network loss: service reconnects or degrades clearly

For each check, record:

- result: `OK`, `PARTIEL`, or `KO`
- phone model and Android version
- visible driver behavior
- visible client behavior
- whether the persistent notification stayed present

- [ ] **Step 4: Stop if the device validation reveals a contract gap**

If `/ride-requests/active` or the current websocket route is not sufficient in the background runtime, do not patch around it ad hoc. Write a short follow-up design note before changing backend contracts.

- [ ] **Step 5: Commit the Android background tracking work**

```bash
git add mobile/pubspec.yaml mobile/pubspec.lock mobile/lib/main.dart mobile/lib/core/location/location_service.dart mobile/lib/core/state/session_controller.dart mobile/lib/core/tracking_background mobile/lib/features/ride_tracking/presentation/controllers/tracking_controller.dart mobile/lib/features/ride_tracking/presentation/controllers/tracking_controller_realtime.dart mobile/lib/features/ride_tracking/presentation/controllers/tracking_controller_snapshot.dart mobile/lib/features/ride_tracking/presentation/screens/driver_tracking_screen.dart mobile/lib/shared/copy/ride_ui_copy.dart mobile/android/app/src/main/AndroidManifest.xml mobile/android/app/src/main/res/drawable/ic_tracking_notification.xml mobile/test/core/tracking_background mobile/test/features/ride_tracking/tracking_controller_background_handoff_test.dart
git commit -m "feat: add android background ride tracking"
```

## Expected Outcome

This plan is complete when:

- an active driver ride keeps sending GPS in Android background with the screen off
- the client keeps seeing credible movement instead of a frozen marker
- driver UI does not own the only long-lived GPS loop anymore
- screen disposal no longer kills active ride tracking
- the implementation stays backend-first and does not introduce a parallel ride-state system

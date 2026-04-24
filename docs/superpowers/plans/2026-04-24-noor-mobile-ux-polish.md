# Noor Mobile UX Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Polish the critical Noor Express mobile flows with shared buttons, clearer loading and status feedback, better copy, and discreet manual resync on negotiation and tracking without changing business behavior.

**Architecture:** Keep the existing lifecycle recovery and controller flows authoritative, then add a thin shared UX layer on top of them. Centralize the visual rules in `AppButton`, `RideUiCopy`, and one compact inline feedback widget, then reuse those primitives across the critical home, negotiation, offer, and tracking screens instead of adding page-specific styling.

**Tech Stack:** Flutter, Riverpod, GoRouter, Material 3, flutter_test

---

## Planned File Map

- Create: `mobile/lib/shared/copy/ride_ui_copy.dart` - shared short copy for network, offer, cancellation, GPS, and recovery states.
- Modify: `mobile/lib/shared/widgets/app_button.dart` - add primary, secondary, danger, loading, and clean disabled states with one API.
- Modify: `mobile/lib/core/theme/app_theme.dart` - keep button typography and colors aligned with the shared button API.
- Create: `mobile/lib/shared/widgets/app_inline_feedback.dart` - compact inline loading, reconnecting, and recoverable-error surface with optional action.
- Modify: `mobile/lib/shared/widgets/notification_card.dart` - optional compact/trailing action support for top overlays.
- Modify: `mobile/lib/shared/widgets/status_badge.dart` - clearer labels and palettes for ride states used on critical surfaces.
- Modify: `mobile/lib/features/home/client/presentation/screens/client_home_screen.dart` - cleaner top feedback and ride creation status placement.
- Modify: `mobile/lib/features/home/client/presentation/screens/client_home_screen_helpers.dart` - human, short, reusable snackbar copy.
- Modify: `mobile/lib/features/home/client/presentation/widgets/search_bottom_sheet.dart`
- Modify: `mobile/lib/features/home/client/presentation/widgets/search_bottom_sheet_sections.dart` - replace local button/loading code with shared primitives.
- Modify: `mobile/lib/features/home/driver/presentation/screens/driver_home_screen.dart` - clearer live update, GPS, and status feedback.
- Modify: `mobile/lib/features/home/driver/presentation/widgets/driver_status_bar.dart`
- Modify: `mobile/lib/features/home/driver/presentation/widgets/driver_bottom_sheet.dart`
- Modify: `mobile/lib/features/home/driver/presentation/widgets/ride_request_popup.dart` - replace popup-local buttons/spinners with shared components.
- Modify: `mobile/lib/features/negotiation/presentation/screens/client_negotiation_screen.dart` - stronger waiting/error/recovery states while keeping pull-to-refresh.
- Modify: `mobile/lib/features/negotiation/presentation/screens/driver_offer_screen.dart` - clearer hierarchy, submit loading, and discreet resync.
- Modify: `mobile/lib/features/negotiation/presentation/widgets/offer_card.dart` - shared CTA handling and clearer busy state.
- Modify: `mobile/lib/features/ride_tracking/presentation/screens/client_tracking_screen.dart`
- Modify: `mobile/lib/features/ride_tracking/presentation/screens/driver_tracking_screen.dart`
- Modify: `mobile/lib/features/ride_tracking/presentation/widgets/tracking_shell_widgets.dart` - add a small degraded-state recovery banner used by both tracking screens.
- Modify: `mobile/lib/features/ride_tracking/presentation/widgets/ride_status_banner.dart` - smoother status swaps and clearer reconnecting presentation.
- Modify: `mobile/lib/features/ride_tracking/presentation/tracking_status_presenter.dart` - tighten copy for accepted, arrived, started, completed, expired, and cancelled.
- Create: `mobile/test/shared/widgets/app_button_test.dart`
- Create: `mobile/test/shared/widgets/app_inline_feedback_test.dart`
- Create: `mobile/test/features/home/client/search_bottom_sheet_test.dart`
- Create: `mobile/test/features/home/driver/ride_request_popup_test.dart`
- Create: `mobile/test/features/negotiation/offer_card_test.dart`
- Create: `mobile/test/features/ride_tracking/tracking_shell_widgets_test.dart`
- Modify: `mobile/test/features/ride_tracking/tracking_status_presenter_test.dart`

### Task 1: Harden Shared Action Buttons

**Files:**
- Modify: `mobile/lib/shared/widgets/app_button.dart`
- Modify: `mobile/lib/core/theme/app_theme.dart`
- Test: `mobile/test/shared/widgets/app_button_test.dart`

- [ ] **Step 1: Write the failing button tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/core/theme/app_theme.dart';
import 'package:noor_express_mobile/shared/widgets/app_button.dart';

void main() {
  testWidgets('AppButton blocks taps and keeps spinner inside the button while loading', (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: AppButton(
            label: 'Chercher un chauffeur',
            isLoading: true,
            onPressed: () => taps++,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(AppButton));
    expect(taps, 0);
  });

  testWidgets('AppButton.danger renders without using per-screen styling', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: AppButton.danger(
            label: 'Annuler la course',
            onPressed: null,
          ),
        ),
      ),
    );

    expect(find.text('Annuler la course'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the button test to confirm the API does not exist yet**

Run: `Set-Location mobile; & "C:\Users\hp\Desktop\flutter_windows_3.41.7-stable\flutter\bin\flutter.bat" test test\shared\widgets\app_button_test.dart`

Expected: FAIL because `AppButton` does not yet expose `isLoading` or `danger`.

- [ ] **Step 3: Implement the shared button API**

```dart
enum AppButtonVariant { primary, secondary, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
  });

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  }) : variant = AppButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
}
```

Add one internal builder that:
- keeps the button height at `56`
- treats `isLoading` as disabled
- uses a small in-button spinner instead of screen-local spinner code
- keeps label alignment stable whether the spinner or icon is shown
- routes primary, secondary, and danger colors through one palette instead of ad hoc `ElevatedButton` styling

Update `AppTheme.lightTheme` only enough to keep typography, radius, and disabled contrast consistent with the shared button widget.

- [ ] **Step 4: Re-run the button test and confirm the new API is stable**

Run: `Set-Location mobile; & "C:\Users\hp\Desktop\flutter_windows_3.41.7-stable\flutter\bin\flutter.bat" test test\shared\widgets\app_button_test.dart`

Expected: PASS

- [ ] **Step 5: Commit only the shared button changes**

```bash
git add mobile/lib/shared/widgets/app_button.dart mobile/lib/core/theme/app_theme.dart mobile/test/shared/widgets/app_button_test.dart
git commit -m "feat: centralize shared mobile buttons"
```

### Task 2: Add Shared Copy And Inline Feedback

**Files:**
- Create: `mobile/lib/shared/copy/ride_ui_copy.dart`
- Create: `mobile/lib/shared/widgets/app_inline_feedback.dart`
- Modify: `mobile/lib/shared/widgets/notification_card.dart`
- Modify: `mobile/lib/shared/widgets/status_badge.dart`
- Test: `mobile/test/shared/widgets/app_inline_feedback_test.dart`

- [ ] **Step 1: Write the failing inline feedback test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/shared/widgets/app_inline_feedback.dart';

void main() {
  testWidgets('AppInlineFeedback shows a recovery action for degraded states', (tester) async {
    var refreshes = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppInlineFeedback(
            message: 'Reconnexion en cours...',
            tone: AppInlineFeedbackTone.warning,
            isLoading: true,
            actionLabel: 'Rafraichir l etat',
            onAction: () => refreshes++,
          ),
        ),
      ),
    );

    expect(find.text('Reconnexion en cours...'), findsOneWidget);
    expect(find.text('Rafraichir l etat'), findsOneWidget);
    await tester.tap(find.text('Rafraichir l etat'));
    expect(refreshes, 1);
  });
}
```

- [ ] **Step 2: Run the inline feedback test to confirm the helper is missing**

Run: `Set-Location mobile; & "C:\Users\hp\Desktop\flutter_windows_3.41.7-stable\flutter\bin\flutter.bat" test test\shared\widgets\app_inline_feedback_test.dart`

Expected: FAIL because `AppInlineFeedback` does not exist yet.

- [ ] **Step 3: Add the shared copy and feedback layer**

```dart
abstract final class RideUiCopy {
  static const reconnecting = 'Reconnexion en cours...';
  static const refreshing = 'Mise a jour en cours...';
  static const noDriverAvailable = 'Aucun chauffeur disponible pour le moment.';
  static const offerExpired = 'Cette offre n est plus disponible.';
  static const rideCancelled = 'La course a ete annulee.';
  static const driverUnavailable = 'Ce chauffeur n est plus disponible.';
  static const gpsUnavailable = 'Position GPS indisponible. Reessayez dans un endroit mieux couvert.';
}

enum AppInlineFeedbackTone { info, success, warning, error }

class AppInlineFeedback extends StatelessWidget {
  const AppInlineFeedback({
    super.key,
    required this.message,
    this.tone = AppInlineFeedbackTone.info,
    this.isLoading = false,
    this.actionLabel,
    this.onAction,
  });
}
```

Use this task to:
- keep critical copy out of individual widgets when the same phrase appears on multiple screens
- give `NotificationCard` an optional compact layout and optional trailing action so top overlays can reuse the same styling
- tighten `StatusBadge` labels so `pending`, `offered`, `accepted`, `arrived`, `started`, `completed`, `cancelled`, and `expired` read consistently across screens

- [ ] **Step 4: Re-run the shared feedback test**

Run: `Set-Location mobile; & "C:\Users\hp\Desktop\flutter_windows_3.41.7-stable\flutter\bin\flutter.bat" test test\shared\widgets\app_inline_feedback_test.dart`

Expected: PASS

- [ ] **Step 5: Commit the shared feedback layer**

```bash
git add mobile/lib/shared/copy/ride_ui_copy.dart mobile/lib/shared/widgets/app_inline_feedback.dart mobile/lib/shared/widgets/notification_card.dart mobile/lib/shared/widgets/status_badge.dart mobile/test/shared/widgets/app_inline_feedback_test.dart
git commit -m "feat: add shared mobile feedback surfaces"
```

### Task 3: Clean Up Client Home Ride Creation And Search States

**Files:**
- Modify: `mobile/lib/features/home/client/presentation/screens/client_home_screen.dart`
- Modify: `mobile/lib/features/home/client/presentation/screens/client_home_screen_helpers.dart`
- Modify: `mobile/lib/features/home/client/presentation/widgets/search_bottom_sheet.dart`
- Modify: `mobile/lib/features/home/client/presentation/widgets/search_bottom_sheet_sections.dart`
- Test: `mobile/test/features/home/client/search_bottom_sheet_test.dart`

- [ ] **Step 1: Write the failing `SearchBottomSheet` widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/features/address_search/domain/entities/address_result.dart';
import 'package:noor_express_mobile/features/home/client/presentation/widgets/search_bottom_sheet.dart';
import 'package:noor_express_mobile/shared/widgets/app_button.dart';
import 'package:noor_express_mobile/shared/widgets/app_inline_feedback.dart';

void main() {
  testWidgets('SearchBottomSheet shows shared loading feedback while creating a ride', (tester) async {
    final controller = TextEditingController(text: '2500');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchBottomSheet(
            pickup: const AddressResult(
              name: 'Grand Marche',
              displayName: 'Grand Marche',
              latitude: 13.5,
              longitude: 2.1,
              type: 'zone',
            ),
            dropoff: const AddressResult(
              name: 'Aeroport',
              displayName: 'Aeroport',
              latitude: 13.48,
              longitude: 2.17,
              type: 'zone',
            ),
            priceController: controller,
            isCreating: true,
            isEstimatingPrice: true,
            activeRide: null,
            onPickupTap: _noop,
            onDropoffTap: _noop,
            onClearPickup: _noop,
            onClearDropoff: _noop,
            onSubmit: _noop,
            onOpenActiveRide: _noop,
          ),
        ),
      ),
    );

    expect(find.byType(AppInlineFeedback), findsOneWidget);
    expect(find.byType(AppButton), findsOneWidget);
  });
}

void _noop() {}
```

- [ ] **Step 2: Run the widget test and confirm the screen still uses ad hoc loading surfaces**

Run: `Set-Location mobile; & "C:\Users\hp\Desktop\flutter_windows_3.41.7-stable\flutter\bin\flutter.bat" test test\features\home\client\search_bottom_sheet_test.dart`

Expected: FAIL or assert against the old local button/loading behavior.

- [ ] **Step 3: Replace the client home ad hoc CTA and status code with shared primitives**

```dart
AppInlineFeedback(
  message: isEstimatingPrice
      ? RideUiCopy.refreshing
      : estimateError ?? 'Prix suggere disponible des que le trajet est pret.',
  tone: estimateError == null
      ? AppInlineFeedbackTone.info
      : AppInlineFeedbackTone.error,
  isLoading: isEstimatingPrice,
)

AppButton(
  label: 'Chercher un chauffeur',
  isLoading: isCreating,
  icon: Icons.local_taxi_rounded,
  onPressed: canSubmit ? onSubmit : null,
)
```

Use this task to:
- delete `_PrimaryButton`
- replace silent text-only estimate/loading states with `AppInlineFeedback`
- keep the existing `SearchBottomSheet` layout and `AnimatedSwitcher`, but make waiting states more explicit
- rewrite client home snackbar copy in `client_home_screen_helpers.dart` so creation, network, GPS, and validation messages are short and human
- keep the flow unchanged: create ride, show success, then push negotiation

- [ ] **Step 4: Re-run the bottom sheet test and do a quick manual pass**

Run: `Set-Location mobile; & "C:\Users\hp\Desktop\flutter_windows_3.41.7-stable\flutter\bin\flutter.bat" test test\features\home\client\search_bottom_sheet_test.dart`

Expected: PASS

Manual check:
- choose pickup and dropoff
- wait for estimate loading
- create a ride
- confirm there is no silent blocked state and no layout jump

- [ ] **Step 5: Commit the client home polish**

```bash
git add mobile/lib/features/home/client/presentation/screens/client_home_screen.dart mobile/lib/features/home/client/presentation/screens/client_home_screen_helpers.dart mobile/lib/features/home/client/presentation/widgets/search_bottom_sheet.dart mobile/lib/features/home/client/presentation/widgets/search_bottom_sheet_sections.dart mobile/test/features/home/client/search_bottom_sheet_test.dart
git commit -m "feat: polish client home ride creation ux"
```

### Task 4: Clean Up Driver Home Availability And Incoming Offer UI

**Files:**
- Modify: `mobile/lib/features/home/driver/presentation/screens/driver_home_screen.dart`
- Modify: `mobile/lib/features/home/driver/presentation/widgets/driver_status_bar.dart`
- Modify: `mobile/lib/features/home/driver/presentation/widgets/driver_bottom_sheet.dart`
- Modify: `mobile/lib/features/home/driver/presentation/widgets/ride_request_popup.dart`
- Test: `mobile/test/features/home/driver/ride_request_popup_test.dart`

- [ ] **Step 1: Write the failing popup widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/features/home/driver/data/models/driver_ride.dart';
import 'package:noor_express_mobile/features/home/driver/presentation/widgets/ride_request_popup.dart';
import 'package:noor_express_mobile/shared/widgets/app_button.dart';

void main() {
  testWidgets('RideRequestPopup keeps the send CTA disabled while submitting', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            RideRequestPopup(
              ride: DriverRide(
                id: 1,
                pickupLocation: 'Grand Marche',
                dropoffLocation: 'Aeroport',
                status: 'pending',
                estimatedPrice: 3000,
                createdAt: DateTime(2026, 4, 24),
              ),
              isSubmitting: true,
              onSend: (_) {},
              onSkip: () {},
            ),
          ],
        ),
      ),
    );

    expect(find.byType(AppButton), findsNWidgets(2));
    expect(find.text('Passer'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the popup test**

Run: `Set-Location mobile; & "C:\Users\hp\Desktop\flutter_windows_3.41.7-stable\flutter\bin\flutter.bat" test test\features\home\driver\ride_request_popup_test.dart`

Expected: FAIL or assert against popup-local loading/button code.

- [ ] **Step 3: Apply the shared button and feedback layer to the driver home surfaces**

```dart
AppButton(
  label: 'Envoyer mon offre',
  isLoading: widget.isSubmitting,
  onPressed: widget.isSubmitting ? null : _submitCurrentPrice,
)

AppButton.secondary(
  label: 'Passer',
  onPressed: widget.isSubmitting ? null : widget.onSkip,
)
```

Use this task to:
- delete `_PopupButton` and `_BigButton`
- make online, offline, and busy states read more clearly in `DriverStatusBar` and `DriverBottomSheet`
- replace `Skip` with French copy that matches the rest of the app
- show cleaner notification/GPS feedback in `driver_home_screen.dart` with the shared copy and compact notification styling
- keep the driver workflow and realtime logic unchanged

- [ ] **Step 4: Re-run the driver widget test and manually verify the availability flow**

Run: `Set-Location mobile; & "C:\Users\hp\Desktop\flutter_windows_3.41.7-stable\flutter\bin\flutter.bat" test test\features\home\driver\ride_request_popup_test.dart`

Expected: PASS

Manual check:
- go online
- receive a pending ride popup
- submit an offer
- ignore a ride
- confirm CTA positions stay stable and copy stays clear

- [ ] **Step 5: Commit the driver home polish**

```bash
git add mobile/lib/features/home/driver/presentation/screens/driver_home_screen.dart mobile/lib/features/home/driver/presentation/widgets/driver_status_bar.dart mobile/lib/features/home/driver/presentation/widgets/driver_bottom_sheet.dart mobile/lib/features/home/driver/presentation/widgets/ride_request_popup.dart mobile/test/features/home/driver/ride_request_popup_test.dart
git commit -m "feat: polish driver home action surfaces"
```

### Task 5: Polish Client Negotiation And Driver Offer Screens

**Files:**
- Modify: `mobile/lib/features/negotiation/presentation/screens/client_negotiation_screen.dart`
- Modify: `mobile/lib/features/negotiation/presentation/screens/driver_offer_screen.dart`
- Modify: `mobile/lib/features/negotiation/presentation/widgets/offer_card.dart`
- Test: `mobile/test/features/negotiation/offer_card_test.dart`

- [ ] **Step 1: Write the failing offer-card test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/features/negotiation/data/models/ride_offer_model.dart';
import 'package:noor_express_mobile/features/negotiation/presentation/widgets/offer_card.dart';

void main() {
  testWidgets('OfferCard disables duplicate actions while busy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfferCard(
            offer: const RideOfferModel(
              offerId: 5,
              driverId: 9,
              driverName: 'Amadou',
              driverRating: 4.8,
              proposedPrice: 2800,
              status: 'pending',
            ),
            isBusy: true,
            onSelect: _noop,
            onReject: _noop,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}

void _noop() {}
```

- [ ] **Step 2: Run the negotiation widget test**

Run: `Set-Location mobile; & "C:\Users\hp\Desktop\flutter_windows_3.41.7-stable\flutter\bin\flutter.bat" test test\features\negotiation\offer_card_test.dart`

Expected: FAIL until the card uses the shared loading-capable button.

- [ ] **Step 3: Apply the shared negotiation polish without changing flow logic**

```dart
AppInlineFeedback(
  message: state.errorMessage ?? RideUiCopy.refreshing,
  tone: state.errorMessage == null
      ? AppInlineFeedbackTone.info
      : AppInlineFeedbackTone.error,
  isLoading: state.isLoading && state.offers.isEmpty,
)

AppButton.secondary(
  label: 'Rafraichir l etat',
  onPressed: state.isSubmitting
      ? null
      : () => ref.read(negotiationControllerProvider(_scope).notifier).refresh(),
)
```

Use this task to:
- keep `RefreshIndicator` on client negotiation
- add one short helper text that tells the user pull-to-refresh resynchronizes with the backend if offers feel stuck
- replace raw error text blocks with `AppInlineFeedback` or compact `NotificationCard`
- use `AppButton` loading states inside `OfferCard` and on the driver submit CTA
- show a discreet manual resync action on the driver offer screen only when the offer is stale, loading too long, or showing a recoverable error
- wrap waiting vs offers vs submitted state swaps in `AnimatedSwitcher` so the screen changes feel smoother without route-level animation work

- [ ] **Step 4: Re-run the negotiation test and manually verify the resync path**

Run: `Set-Location mobile; & "C:\Users\hp\Desktop\flutter_windows_3.41.7-stable\flutter\bin\flutter.bat" test test\features\negotiation\offer_card_test.dart`

Expected: PASS

Manual check:
- wait for offers on client negotiation
- pull to refresh
- submit an offer on driver offer
- trigger the discreet refresh action after a recoverable error
- confirm the controller still uses the existing `refresh()` / `resumeFromLifecycle()` path

- [ ] **Step 5: Commit the negotiation polish**

```bash
git add mobile/lib/features/negotiation/presentation/screens/client_negotiation_screen.dart mobile/lib/features/negotiation/presentation/screens/driver_offer_screen.dart mobile/lib/features/negotiation/presentation/widgets/offer_card.dart mobile/test/features/negotiation/offer_card_test.dart
git commit -m "feat: polish negotiation loading and recovery states"
```

### Task 6: Polish Tracking Screens And Add Degraded-State Manual Resync

**Files:**
- Modify: `mobile/lib/features/ride_tracking/presentation/screens/client_tracking_screen.dart`
- Modify: `mobile/lib/features/ride_tracking/presentation/screens/driver_tracking_screen.dart`
- Modify: `mobile/lib/features/ride_tracking/presentation/widgets/tracking_shell_widgets.dart`
- Modify: `mobile/lib/features/ride_tracking/presentation/widgets/ride_status_banner.dart`
- Modify: `mobile/lib/features/ride_tracking/presentation/tracking_status_presenter.dart`
- Test: `mobile/test/features/ride_tracking/tracking_shell_widgets_test.dart`
- Test: `mobile/test/features/ride_tracking/tracking_status_presenter_test.dart`

- [ ] **Step 1: Write the failing tracking recovery widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_express_mobile/features/ride_tracking/domain/entities/tracking_state.dart';
import 'package:noor_express_mobile/features/ride_tracking/presentation/widgets/tracking_shell_widgets.dart';

void main() {
  testWidgets('TrackingRecoveryBanner shows manual refresh only in degraded states', (tester) async {
    var refreshes = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackingRecoveryBanner(
            connectionState: TrackingConnectionState.reconnecting,
            message: 'Reconnexion en cours...',
            onRefresh: () => refreshes++,
          ),
        ),
      ),
    );

    expect(find.text('Rafraichir l etat'), findsOneWidget);
    await tester.tap(find.text('Rafraichir l etat'));
    expect(refreshes, 1);
  });
}
```

- [ ] **Step 2: Run the tracking widget and presenter tests**

Run: `Set-Location mobile; & "C:\Users\hp\Desktop\flutter_windows_3.41.7-stable\flutter\bin\flutter.bat" test test\features\ride_tracking\tracking_shell_widgets_test.dart test\features\ride_tracking\tracking_status_presenter_test.dart`

Expected: FAIL because `TrackingRecoveryBanner` and the updated copy do not exist yet.

- [ ] **Step 3: Implement the tracking recovery surface and clearer status copy**

```dart
class TrackingRecoveryBanner extends StatelessWidget {
  const TrackingRecoveryBanner({
    super.key,
    required this.connectionState,
    required this.message,
    required this.onRefresh,
  });

  final TrackingConnectionState connectionState;
  final String message;
  final VoidCallback onRefresh;
}
```

Use this task to:
- add `TrackingRecoveryBanner` inside `tracking_shell_widgets.dart` and reuse it in both client and driver tracking screens
- show the banner only when `connectionState != TrackingConnectionState.connected` or when `state.errorMessage` is present
- wire the refresh action to `trackingControllerProvider(_scope).notifier.refresh()`
- keep manual resync silent and backend-first by reusing the existing tracking controller refresh path
- update `RideStatusBanner` and the tracking screen stacks with `AnimatedSwitcher` so reconnecting/error/success swaps do not flash harshly
- tighten `tracking_status_presenter.dart` copy so accepted, arrived, started, completed, cancelled, and expired read plainly and professionally

- [ ] **Step 4: Re-run the tracking tests and manually verify degraded-state behavior**

Run: `Set-Location mobile; & "C:\Users\hp\Desktop\flutter_windows_3.41.7-stable\flutter\bin\flutter.bat" test test\features\ride_tracking\tracking_shell_widgets_test.dart test\features\ride_tracking\tracking_status_presenter_test.dart`

Expected: PASS

Manual check:
- enter tracking after offer acceptance
- simulate reconnecting or a backend refresh
- confirm `Rafraichir l etat` appears only when useful
- complete or cancel a ride and verify the return to home stays smooth without extra route work

- [ ] **Step 5: Commit the tracking polish**

```bash
git add mobile/lib/features/ride_tracking/presentation/screens/client_tracking_screen.dart mobile/lib/features/ride_tracking/presentation/screens/driver_tracking_screen.dart mobile/lib/features/ride_tracking/presentation/widgets/tracking_shell_widgets.dart mobile/lib/features/ride_tracking/presentation/widgets/ride_status_banner.dart mobile/lib/features/ride_tracking/presentation/tracking_status_presenter.dart mobile/test/features/ride_tracking/tracking_shell_widgets_test.dart mobile/test/features/ride_tracking/tracking_status_presenter_test.dart
git commit -m "feat: polish tracking recovery and status feedback"
```

### Task 7: Verify, Analyze, And Prepare The Closeout Report

**Files:**
- Test: `mobile/test/shared/widgets/app_button_test.dart`
- Test: `mobile/test/shared/widgets/app_inline_feedback_test.dart`
- Test: `mobile/test/features/home/client/search_bottom_sheet_test.dart`
- Test: `mobile/test/features/home/driver/ride_request_popup_test.dart`
- Test: `mobile/test/features/negotiation/offer_card_test.dart`
- Test: `mobile/test/features/ride_tracking/tracking_shell_widgets_test.dart`
- Test: `mobile/test/features/ride_tracking/tracking_status_presenter_test.dart`

- [ ] **Step 1: Run the targeted widget and unit tests**

Run: `Set-Location mobile; & "C:\Users\hp\Desktop\flutter_windows_3.41.7-stable\flutter\bin\flutter.bat" test test\shared\widgets\app_button_test.dart test\shared\widgets\app_inline_feedback_test.dart test\features\home\client\search_bottom_sheet_test.dart test\features\home\driver\ride_request_popup_test.dart test\features\negotiation\offer_card_test.dart test\features\ride_tracking\tracking_shell_widgets_test.dart test\features\ride_tracking\tracking_status_presenter_test.dart`

Expected: PASS

- [ ] **Step 2: Run static verification**

Run: `Set-Location mobile; & "C:\Users\hp\Desktop\flutter_windows_3.41.7-stable\flutter\bin\flutter.bat" analyze`

Expected: PASS with no new issues.

- [ ] **Step 3: Run the manual regression walkthrough**

Check these flows in order:
- client create ride
- wait for offers
- accept an offer and enter tracking
- driver submit an offer
- reconnecting / offline feedback on tracking
- pull-to-refresh on client negotiation
- discreet manual refresh on driver offer
- discreet manual refresh on degraded tracking
- return home after cancellation or completion

- [ ] **Step 4: Prepare the implementation closeout**

The final report must explicitly include:
- shared UI components created or improved
- pages touched
- UX bugs corrected
- what was deliberately avoided
- the `flutter analyze` result

- [ ] **Step 5: Commit the verification-safe final pass**

```bash
git add mobile/lib/shared/copy/ride_ui_copy.dart mobile/lib/shared/widgets/app_button.dart mobile/lib/shared/widgets/app_inline_feedback.dart mobile/lib/shared/widgets/notification_card.dart mobile/lib/shared/widgets/status_badge.dart mobile/lib/core/theme/app_theme.dart mobile/lib/features/home/client/presentation/screens/client_home_screen.dart mobile/lib/features/home/client/presentation/screens/client_home_screen_helpers.dart mobile/lib/features/home/client/presentation/widgets/search_bottom_sheet.dart mobile/lib/features/home/client/presentation/widgets/search_bottom_sheet_sections.dart mobile/lib/features/home/driver/presentation/screens/driver_home_screen.dart mobile/lib/features/home/driver/presentation/widgets/driver_status_bar.dart mobile/lib/features/home/driver/presentation/widgets/driver_bottom_sheet.dart mobile/lib/features/home/driver/presentation/widgets/ride_request_popup.dart mobile/lib/features/negotiation/presentation/screens/client_negotiation_screen.dart mobile/lib/features/negotiation/presentation/screens/driver_offer_screen.dart mobile/lib/features/negotiation/presentation/widgets/offer_card.dart mobile/lib/features/ride_tracking/presentation/screens/client_tracking_screen.dart mobile/lib/features/ride_tracking/presentation/screens/driver_tracking_screen.dart mobile/lib/features/ride_tracking/presentation/widgets/tracking_shell_widgets.dart mobile/lib/features/ride_tracking/presentation/widgets/ride_status_banner.dart mobile/lib/features/ride_tracking/presentation/tracking_status_presenter.dart mobile/test/shared/widgets/app_button_test.dart mobile/test/shared/widgets/app_inline_feedback_test.dart mobile/test/features/home/client/search_bottom_sheet_test.dart mobile/test/features/home/driver/ride_request_popup_test.dart mobile/test/features/negotiation/offer_card_test.dart mobile/test/features/ride_tracking/tracking_shell_widgets_test.dart mobile/test/features/ride_tracking/tracking_status_presenter_test.dart
git commit -m "feat: ship mobile ux polish pass"
```

## Self-Review

- Spec coverage: shared buttons, loading states, clearer copy, critical page cleanup, negotiation/tracking manual resync, and lightweight transitions are each mapped to at least one task above.
- Placeholder scan: no `TODO`, `TBD`, or "implement later" markers remain.
- Type consistency: shared primitives use consistent names across tasks: `AppButton`, `RideUiCopy`, `AppInlineFeedback`, and `TrackingRecoveryBanner`.

# Noor Mobile Clarity Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refresh the Noor Express mobile experience so the most important pages feel clearer, more human, and more premium without changing the validated product flow.

**Architecture:** Strengthen the shared UX layer first, then apply it screen family by screen family in the approved order. Reuse shared copy, buttons, cards, banners, and menu structure instead of styling pages ad hoc, while keeping existing controllers and routes authoritative.

**Tech Stack:** Flutter, Riverpod, GoRouter, Material 3, flutter_test

---

## Planned File Map

- Modify: `mobile/lib/core/theme/app_theme.dart`
- Modify: `mobile/lib/shared/copy/ride_ui_copy.dart`
- Modify: `mobile/lib/shared/widgets/app_button.dart`
- Modify: `mobile/lib/shared/widgets/app_inline_feedback.dart`
- Modify: `mobile/lib/shared/widgets/notification_card.dart`
- Modify: `mobile/lib/shared/widgets/status_badge.dart`
- Modify: `mobile/lib/features/home/client/presentation/screens/client_home_screen.dart`
- Modify: `mobile/lib/features/home/client/presentation/screens/client_home_screen_helpers.dart`
- Modify: `mobile/lib/features/home/client/presentation/widgets/search_bottom_sheet.dart`
- Modify: `mobile/lib/features/home/client/presentation/widgets/search_bottom_sheet_sections.dart`
- Modify: `mobile/lib/features/home/client/presentation/widgets/hamburger_menu.dart`
- Modify: `mobile/lib/features/home/driver/presentation/screens/driver_home_screen.dart`
- Modify: `mobile/lib/features/home/driver/presentation/widgets/driver_status_bar.dart`
- Modify: `mobile/lib/features/home/driver/presentation/widgets/driver_bottom_sheet.dart`
- Modify: `mobile/lib/features/home/driver/presentation/widgets/ride_request_popup.dart`
- Modify: `mobile/lib/features/home/driver/presentation/widgets/driver_hamburger_menu.dart`
- Modify: `mobile/lib/features/ride_tracking/presentation/screens/client_tracking_screen.dart`
- Modify: `mobile/lib/features/ride_tracking/presentation/screens/driver_tracking_screen.dart`
- Modify: `mobile/lib/features/ride_tracking/presentation/widgets/tracking_shell_widgets.dart`
- Modify: `mobile/lib/features/ride_tracking/presentation/widgets/ride_status_banner.dart`
- Modify: `mobile/lib/features/ride_tracking/presentation/tracking_status_presenter.dart`
- Modify: `mobile/lib/features/negotiation/presentation/screens/client_negotiation_screen.dart`
- Modify: `mobile/lib/features/negotiation/presentation/screens/driver_offer_screen.dart`
- Modify: `mobile/lib/features/negotiation/presentation/widgets/offer_card.dart`
- Modify: `mobile/lib/features/history/screens/ride_detail_screen.dart`
- Modify: `mobile/lib/features/home/client/presentation/screens/client_history_screen.dart`
- Modify: `mobile/lib/features/home/driver/presentation/screens/driver_history_screen.dart`
- Modify: `mobile/lib/features/auth/presentation/screens/login_screen.dart`
- Modify: `mobile/lib/features/driver_onboarding/presentation/screens/*.dart`
- Modify: `mobile/lib/shared/screens/settings_screen.dart`

## Task Order

### Task 1: Build The Shared Editorial And Visual Layer

- [ ] Expand shared copy helpers with simple and reassuring French.
- [ ] Improve `AppButton`, `NotificationCard`, `StatusBadge`, and `AppInlineFeedback` so premium styling and clearer states can be reused everywhere.
- [ ] Tune `AppTheme` so buttons, cards, sheets, and headings feel more elegant on mobile.
- [ ] Run targeted shared-widget tests and `flutter analyze`.

### Task 2: Refresh Client Home

- [ ] Clean the main bottom sheet hierarchy.
- [ ] Rewrite ride creation copy in simple French.
- [ ] Make active-ride states feel like an active journey instead of a form.
- [ ] Clean the client side menu labels and grouping.

### Task 3: Refresh Driver Home

- [ ] Replace technical status language with `Disponible`, `En pause`, and `En course`.
- [ ] Improve the driver bottom sheet and live-request popup hierarchy.
- [ ] Make the driver menu clearer and more premium.
- [ ] Keep the current availability and active-ride flow unchanged.

### Task 4: Refresh Tracking Screens

- [ ] Align client and driver tracking with one calmer visual family.
- [ ] Rewrite banners, recovery states, and next-step language.
- [ ] Keep the current tracking logic intact while making the UI more understandable.

### Task 5: Refresh Negotiation And Offer Screens

- [ ] Replace negotiation jargon with simpler price language.
- [ ] Improve the decision hierarchy around `Accepter` and `Proposer un autre prix`.
- [ ] Make the driver offer screen feel more guided and less form-heavy.

### Task 6: Refresh Menus, History, Login, Onboarding, And Settings

- [ ] Clean side-menu grouping and labels.
- [ ] Rewrite history and ride-detail copy.
- [ ] Simplify login wording and hierarchy.
- [ ] Make onboarding steps shorter and more reassuring.
- [ ] Remove developer wording from settings.

### Task 7: Verification

- [ ] Run targeted Flutter tests for shared widgets and touched screen helpers.
- [ ] Run `flutter analyze`.
- [ ] Review the touched screens for obvious wording regressions and duplicated technical language.

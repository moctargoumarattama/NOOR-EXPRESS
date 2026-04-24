# Noor Logo Light Branding Design

**Date:** 2026-04-24

## Goal

Integrate the official Noor Express logo into the mobile app in a way that strengthens brand recognition without making the product feel overloaded.

The intended product effect is:

- strong and memorable brand presence at the beginning
- lighter and more discreet brand presence during actual use
- no visual clutter on action-heavy screens
- no large refactor

The official source asset for this phase is:

- `logo.jpeg`

## Product Direction

The brand should be felt clearly at the start of the app journey, then become lighter once the user is actively using the product.

This means:

- the logo is fully visible on entry points
- the logo becomes compact on recurring navigation surfaces
- the logo is not repeated inside every card, button, or state block

The visual intent is:

- elegant
- premium
- calm
- recognizable
- never excessive

## Recommended Approach

Use the full logo only where brand introduction matters, then use a lighter brand signature in the app shell.

This is preferred over either:

- using the logo almost nowhere, which weakens recognition
- using it everywhere, which makes the app feel noisy and less premium

## Placement Rules

### Full Logo

Use the full `logo.jpeg` in these places:

- `SplashScreen`
- `LoginScreen`
- menu headers

Purpose:

- establish brand recognition at app opening
- make the login flow feel official and polished
- make the menus feel like part of one branded experience

### Light Brand Signature

Use a lighter brand presence on the two home screens:

- client home
- driver home

This signature should be small and calm, for example:

- a compact `Noor Express` wordmark treatment
- or a small logo mark paired with subtle text

It should not compete with the main action panel.

### Where Not To Add Branding

Do not add the logo heavily to:

- tracking screens
- negotiation screens
- history cards
- settings rows
- notifications
- inline feedback
- buttons

Those screens should stay focused on user action and clarity.

## Screen-Level Design

### Splash Screen

The splash screen should become the strongest brand moment in the app.

Design rules:

- show the full logo centered
- keep the current calm loading feel
- reduce reliance on the generic taxi icon
- keep the loading state minimal and elegant

The screen should feel like a polished opening card for the brand, not a utility loading page.

### Login Screen

The login screen should use the full logo above the content card.

Design rules:

- logo visible before the title and form
- smaller than on splash
- enough spacing to feel premium
- no extra decorative branding elsewhere on the page

The brand should reassure without pushing the form too low on mobile.

### Client Home

The client home should get a light signature only.

Design rules:

- no large full-width logo block
- no brand wallpaper effect
- small, elegant signature near the top section or main panel
- the booking flow remains visually dominant

The user should feel the brand, but the main task should still be ordering a ride.

### Driver Home

The driver home should follow the same rule as client home.

Design rules:

- same visual family as client home
- light signature only
- availability state and active ride remain visually dominant

### Menus

Both side menus should include a compact but clear logo presence in the header.

Design rules:

- full logo or compact horizontal logo treatment
- placed above or near the profile summary
- cleaner header hierarchy
- no oversized banner feel

The menu should feel branded, personal, and polished.

## Asset Handling

For this phase:

- keep the provided logo as a static asset
- add it to Flutter assets in `pubspec.yaml`
- wrap access through one small shared branding widget instead of hardcoding `Image.asset(...)` everywhere

Recommended shared widgets:

- `NoorLogo`
- optional size variants such as `hero`, `header`, and `compact`

This keeps placement maintainable and consistent.

## Visual Restraint Rules

To keep the branding from feeling heavy:

- never place the full logo more than once on a screen
- never combine the full logo with extra decorative brand badges on the same screen
- do not place the logo inside buttons
- do not repeat the logo in every card section
- keep logo sizing proportional to the task importance of the screen

## Expected Files

- `mobile/pubspec.yaml`
- `mobile/lib/features/auth/presentation/screens/splash_screen.dart`
- `mobile/lib/features/auth/presentation/screens/login_screen.dart`
- `mobile/lib/features/home/client/presentation/screens/client_home_screen.dart`
- `mobile/lib/features/home/driver/presentation/screens/driver_home_screen.dart`
- `mobile/lib/features/home/client/presentation/widgets/floating_top_bar.dart`
- `mobile/lib/features/home/client/presentation/widgets/hamburger_menu.dart`
- `mobile/lib/features/home/driver/presentation/widgets/driver_hamburger_menu.dart`
- `mobile/lib/features/home/driver/presentation/widgets/driver_menu_header.dart`
- new shared branding widget file under `mobile/lib/shared/widgets/`

## Verification

### Functional

- the asset loads correctly in Flutter
- splash and login display the logo without layout breakage
- home screens show a lighter brand signature
- menus show a branded header

### UX

- the logo is clearly visible at app opening
- branding feels lighter once the user is navigating
- no critical screen feels cluttered
- the booking and ride actions remain more visually important than the brand

### Technical

- `flutter test` for touched widget areas when applicable
- `flutter analyze`

## Non-Goals

- no animated brand intro
- no full visual redesign
- no icon launcher change in this phase unless requested separately
- no aggressive branding across all screens

## Success Criteria

This design is successful when:

- Noor Express feels clearly branded from the first second
- the app still feels clean and usable during active flows
- the logo improves perceived quality instead of adding noise
- the implementation stays simple and easy to maintain

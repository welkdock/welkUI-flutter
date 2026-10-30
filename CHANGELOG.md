## 0.2.1
* Fixed Dependency Issue

## 0.2.0
§
* Add `WelkAppBar` with ComicStrip, Sticker, Bubble, and Split layouts,
  floating card appearance, string/custom titles, logo positioning, up to three
  actions, and theme-aware styling.
* Add `WelkSliverAppBar` for pinned or scroll-away behavior and an interactive
  app bar example with a launchable scrolling demo.

## 0.1.9

* Add `WelkBottomNavBar` and `WelkBottomNavScaffold` with five comic layouts
  (PopCircle, BlockCenter, PopBlock, ComicDock, BubbleRail), default and
  floating modes, per-destination stateful pages with nested navigators, and
  sticky, hide-on-scroll-down, always-visible, and hide-on-subpages behaviors.
* Add `WelkBottomNavStyle` for colors, typography, sizing, borders, shadows,
  elevation, and animations, with light and dark theme support.
* Add a bottom navigation preview and launchable demo app to the example.

## 0.1.8

* Include bundled avatar icons in the published package, fixing missing-asset
  warnings and ensuring default avatars load in light and dark modes.

## 0.1.7
* Add a global `WelkThemeData.textScaleFactor` preference and customizable text
  scaling across all widgets, with `overRideTextScaleFactor` local overrides.

## 0.1.6

* Select dedicated black and white avatar assets for light and dark modes
  without filtering custom icons or profile images.

* Add a global `WelkThemeData.darkMode` preference and customizable dark palette
  tokens across all widgets, with `overRideDarkMode` local overrides.
* Carry local dark-mode overrides through nested widgets, popups, and overlays.
* Add a floating `WelkIconButton` global theme toggle to example app screens.
* Use black-tinted semantic fills, black borders, whitish-gray hard shadows,
  and contrasting text and icons in dark mode, with customizable
  `darkButtonTint`, `darkShadow`, and `darkMuted` tokens.

## 0.1.5

* Use a compact 36px calendar container inside the date input field while
  preserving its 48px touch target and spacing from the field outline.

## 0.1.4

* Fit complete Monday-to-Sunday months into date picker and date input calendars
  without horizontal scrolling, including narrow screens and RTL layouts.
* Adapt day-cell widths to available space, retain tall touch targets, and align
  keyboard Home/End navigation with Monday-first weeks.

## 0.1.3

* Use white backgrounds throughout the example app and web preview shell,
  including app bars, while preserving the widgets' original design colors.

## 0.1.2

* Allow measured CI text-edge rasterization noise in example catalog goldens
  without changing widget visuals or golden baselines.
* Preserve stricter package golden defaults, exact dimensions and alpha, and
  bounded RGB differences; add regression coverage for catalog tolerance limits.

## 0.1.1

* Simplify snackbar placement to centered `top` and `bottom` positions.
* Update the snackbar example to show only these two positions.

## 0.1.0

* Complete the 30-component catalog from the React library with mobile form
  controls, date/time pickers, content widgets, navigation, overlays, and feedback.
* Add locally encoded QR codes with standard and card treatments, square or
  rounded modules, validation, and a four-module quiet zone.
* Add a dedicated mobile and embeddable example route for every widget, backed
  by a shared catalog and narrow-screen regression coverage.
* Use the pure-Dart `qr` package for standards-compliant QR encoding.
* Bundle the reference avatar portraits and transparent sticker artwork.

## 0.0.10

* Add `WelkImage.network` and `WelkImage.asset` with asymmetric outlines and hard shadows.
* Bundle five mobile-compatible comic fallback images; select once per failed
  network source, or use a custom fallback asset.
* Add the `/image` example and documentation preview route.

## 0.0.9

* Make narrow example screens more compact with small button showcases,
  tighter spacing, smaller section headings, and concise card copy.
* Preserve size demonstrations, long-content examples, touch targets, and text scaling.

## 0.0.8
* Update the README banner to a new image with the WelkUI Flutter logo and a mobile device mockup.


## 0.0.7

* Refresh the README with a single banner, package quick start, widget names,
  and links to full documentation and live previews.
* Add contribution guidelines covering setup, design conventions, tests, and releases.
* Clarify package and bundled-font licensing.

## 0.0.6

* Bound text-edge rast§erization noise in the widget gallery golden comparison
  across macOS versions; preserve strict dimensions, alpha, and failure artifacts.
* Add regression coverage for golden comparison limits; leave menu comparisons exact.

## 0.0.5

* Align CI golden comparisons with the macOS baseline environment and pinned Flutter SDK.
* Upload golden comparison images when CI fails.
* Run checks and preview builds on pull requests; restrict Pages deployment to main.

## 0.0.4
* Add an embeddable web build of the example app for live documentation previews.


## 0.0.3

* Document installing from pub.dev.
* Add an embeddable web build of the example app for live documentation previews.

## 0.0.2

* Package metadata and documentation updates.

## 0.0.1

* Add the first mobile widgets: `WelkButton`, `WelkSwitch`, and `WelkCard`.
* Bundle Short Stack typography and shared WelkUI design tokens.
* Add `WelkMenu` with nested navigation, collapsible menus, and active routes.
* Give each widget a dedicated example route, reached from the initial menu.

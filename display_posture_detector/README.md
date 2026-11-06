# display_posture_detector

[![Publisher: kauscoder.com](https://img.shields.io/badge/Publisher-kauscoder.com-indigo.svg)](https://kauscoder.com)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-blue.svg)](https://pub.dev/packages/display_posture_detector)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

A Flutter plugin for real-time detection of display postures, hardware hinge bounds, side panel cutouts, device orientation, device classification, and dual-display regions on foldable, dual-screen, and tablet devices—now with **built-in adaptive window size breakpoints** for seamless responsive design.

> **Active Testing & Device Expansion**  
> This package is actively tested across a wide range of devices—including dual-screen devices (e.g. iPhone Duo simulator), foldables (Samsung Galaxy Z Fold/Flip, Google Pixel Fold), tablets (iPads, Android tablets), floating windows (Samsung Pop-up view, Android freeform), and desktop window resizing (macOS, Windows).  
> If you test this on additional hardware or encounter edge cases, please feel free to [open an issue or contribute](https://github.com/KaustavCodes/Flutter-Display-Posture-Detector-Plugin/issues)!

---

## Features

- **Fold State Detection**: Accurately tracks `FoldState.flat` (unfolded flat continuous), `FoldState.halfOpened` (dual-screen book / laptop tabletop posture), and `FoldState.normal` (standard flat screen).
- **Tabletop, Book & Flat Posture Getters**: High-level semantic properties on `PostureEvent` (`isTableTop`, `isBookPosture`, `isFlat`) to build posture-specific layouts instantly.
- **Adaptive Breakpoints & Window Size Classes**: Classify window widths into `WindowSizeClass.compact`, `medium`, and `expanded` with zero layout delay.
- **Android Floating & Multi-Window Ready**: Works out of the box with Samsung Pop-up view, Android freeform/multi-window, and iPad Split View via performant `MediaQuery.sizeOf(context)` aspect queries.
- **Configurable Breakpoints (`PostureBreakpoints`)**: Configure global thresholds in `main()` with `DisplayPostureDetector.initialize()` using `standard` (768/1024), `material` (600/840), or custom values.
- **`AdaptivePostureBuilder` Widget**: An out-of-the-box adaptive widget that tracks both real-time physical fold posture and window size classes in a single unified callback.
- **Hardware Hinge & Crease Bounds (`hingeBounds`)**: Emits exact bounding rectangles (`PostureRect`) in logical dp representing the physical hinge or division crease.
- **Isolated Display Regions (`displayAreas`)**: Provides exact hardware coordinates for individual usable screen panels (Pane 1 and Pane 2) taking into account physical hinges and edge panels.
- **Side Panel Inset Tracking (`sidePanel`)**: Detects status/dock panels (such as the iPhone Duo right-side clock/status panel or system bar insets) so dual-pane layouts remain pixel-aligned with physical hardware hinges.
- **Combined Wide Canvas (`combinedArea` / `wideArea`)**: Provides the continuous usable canvas across all panels, excluding the side panel, allowing apps to span wide panoramic content.
- **Tablet Landscape (50% / 50%) Multi-Panel**: Returns dual 50%/50% split viewports when running in landscape on tablets or iPads.
- **Hardware & Platform Classification (`DeviceType`)**: Classifies devices into `iphone`, `ipad`, `androidPhone`, `androidTablet`, `mac`, `windows`, `linux`, and `other`, with `isTablet`, `isMobile`, and `isDesktop` helpers.
- **Interactive Simulation**: Built-in posture simulation toggles for rapid testing on standard non-foldable phones, iPads, and simulators.

---

## Platform Support

| Feature | Android | iOS |
|---|---|---|
| **Fold State Tracking** | Supported (`androidx.window`) | Supported (Division regions / Simulation) |
| **Hinge Bounds & Crease** | Supported (Hardware bounds) | Supported (Division bounds / Simulation) |
| **Display Areas (Dual-Pane)** | Supported | Supported |
| **Side Panel Detection** | Supported | Supported |
| **Combined Wide Canvas** | Supported | Supported |
| **Tablet Landscape (50% / 50%)** | Supported | Supported |
| **Adaptive Breakpoints** | Supported (Floating windows & full-screen) | Supported (iPad Split View & full-screen) |
| **Device Classification (`deviceType`)** | Supported (`androidPhone`, `androidTablet`) | Supported (`iphone`, `ipad`, `mac`) |
| **Screen Metrics & Orientation** | Supported | Supported |

---

## Getting Started

### 1. Installation

Add `display_posture_detector` to your `pubspec.yaml`:

```yaml
dependencies:
  display_posture_detector: ^0.0.3
```

### 2. Optional Startup Initialization (Custom Breakpoints)

Initialize global breakpoints once in `main()` before launching `runApp()`:

```dart
import 'package:flutter/material.dart';
import 'package:display_posture_detector/display_posture_detector.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure custom responsive breakpoints (defaults to 768 / 1024)
  DisplayPostureDetector.initialize(
    breakpoints: const PostureBreakpoints(
      compact: 768.0,  // Anything under 768 is compact / mobile / floating window
      medium: 1024.0,  // 768 to 1023 is tablet / medium
    ),
  );

  runApp(const MyApp());
}
```

---

## Quick Usage

### 1. Fast Responsive Checks ($O(1)$)
Query current window width and floating window classification directly from any widget:

```dart
// Context-based aspect checks (reacts only when window bounds change)
if (DisplayPostureDetector.isCompact(context)) {
  return const MobileLayout();
} else if (DisplayPostureDetector.isDesktop(context)) {
  return const DesktopSidebarLayout();
}

// Or check with explicit constraints (e.g. inside a LayoutBuilder)
if (DisplayPostureDetector.isDesktopWidth(constraints.maxWidth)) {
  return const DesktopSidebarLayout();
}
```

### 2. All-in-One `AdaptivePostureBuilder`
React to both physical folding posture and responsive window sizing seamlessly:

```dart
AdaptivePostureBuilder(
  builder: (context, posture, sizeClass) {
    // 1. Check physical posture first (propped on table / half-opened)
    if (posture.isTableTop) {
      return const TableTopClamshellLayout(); // Top display, bottom controls
    } else if (posture.isBookPosture) {
      return const BookDualPaneLayout(); // Left / right reading panes
    }

    // 2. Fall back to responsive window size class (floating window, phone, or desktop)
    if (sizeClass == WindowSizeClass.expanded) {
      return const DesktopSidebarLayout();
    }
    return const MobileSinglePaneLayout();
  },
)
```

### 3. Listening to Raw Hardware Posture Stream

```dart
final detector = DisplayPostureDetector();

detector.onPostureChanged.listen((event) {
  print('Fold State: ${event.foldState}');
  print('Is TableTop: ${event.isTableTop}');
  print('Is Book Posture: ${event.isBookPosture}');
  print('Is Separating: ${event.isSeparating}');

  if (event.hasHinge) {
    final hinge = event.hingeBounds!;
    print('Hinge: ${hinge.width}x${hinge.height} dp at (L: ${hinge.left}, T: ${hinge.top})');
  }

  for (int i = 0; i < event.displayAreas.length; i++) {
    final area = event.displayAreas[i];
    print('Panel ${i + 1}: ${area.width}x${area.height} dp');
  }
});
```

---

## Dual-Pane vs. Combined Wide Layouts

Physical hinge coordinates (`event.hingeBounds`) are relative to the hardware screen.
- **Pane 1**: Sized to match `event.displayAreas[0].width` (anchored to the physical hinge left edge).
- **Hinge**: Renders with `event.hingeBounds.width` at the exact physical fold location.
- **Pane 2**: Uses `Expanded`, allowing it to **take up all remaining space on the right side** up to the bezel.
- **Combined Wide**: Uses `event.wideArea` to span wide panoramic content across both screens, excluding edge side panels.

```dart
Widget build(BuildContext context) {
  return Scaffold(
    body: LayoutBuilder(
      builder: (context, constraints) {
        if (event.isSplit) {
          if (viewMode == DisplayViewMode.combinedWide) {
            return Container(
              width: event.wideArea.width,
              height: event.wideArea.height,
              child: const WideDashboardCanvas(),
            );
          }

          final isVertical = event.isVerticalHinge;
          final pane1Size = isVertical 
              ? (event.primaryPanel?.width ?? constraints.maxWidth / 2)
              : (event.primaryPanel?.height ?? constraints.maxHeight / 2);
          final hingeThickness = isVertical
              ? (event.hingeBounds?.width ?? 24.0)
              : (event.hingeBounds?.height ?? 24.0);

          return isVertical
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: pane1Size, child: const PrimaryPane()),
                    HingeIndicator(thickness: hingeThickness),
                    const Expanded(child: SecondaryPane()), // Fills entire right side
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: pane1Size, child: const PrimaryPane()),
                    HingeIndicator(thickness: hingeThickness),
                    const Expanded(child: SecondaryPane()), // Fills entire bottom side
                  ],
                );
        }

        return const SinglePaneView();
      },
    ),
  );
}
```

---

## API Reference

### `PostureEvent`
Emitted by `DisplayPostureDetector.onPostureChanged`:

| Field / Getter | Type | Description |
|---|---|---|
| `foldState` | `FoldState` | `flat`, `halfOpened`, or `normal`. |
| `isTableTop` | `bool` | `true` when propped open horizontally (clamshell tabletop). |
| `isBookPosture` | `bool` | `true` when half-opened vertically (book left/right panes). |
| `isFlat` | `bool` | `true` when flat continuous or normal single screen. |
| `isSeparating` | `bool` | Whether the hinge physically occludes or separates content. |
| `orientation` | `PostureOrientation` | `portrait` or `landscape`. |
| `deviceType` | `DeviceType` | Classified hardware/platform form factor. |
| `hingeBounds` | `PostureRect?` | Bounding box of the physical or simulated hinge in logical dp. |
| `displayAreas` | `List<PostureRect>` | Usable panels (Pane 1, Pane 2) around the fold. |
| `sidePanel` | `PostureRect?` | Bounding box of detected side dock/status panel if present. |
| `combinedArea` | `PostureRect?` | Combined usable canvas across panels excluding side panels. |
| `wideArea` | `PostureRect` | Non-null fallback to `combinedArea` or full display. |
| `primaryPanel` | `PostureRect?` | First usable panel (`displayAreas[0]`). |
| `secondaryPanel` | `PostureRect?` | Second usable panel (`displayAreas[1]`). |
| `isSplit` | `bool` | `true` if half-opened, separating, or tablet landscape. |
| `hasHinge` | `bool` | `true` if `hingeBounds` exists with positive dimensions. |
| `isVerticalHinge` | `bool` | `true` for book fold (left/right split). |
| `isHorizontalHinge` | `bool` | `true` for tabletop clamshell fold (top/bottom split). |

### `WindowSizeClass` & `PostureBreakpoints`
- **`WindowSizeClass.compact`**: Phone screens, Android pop-up floating windows, 1/3 split screen (< compact breakpoint).
- **`WindowSizeClass.medium`**: Foldables unfolded, small tablets, 1/2 split screen windows.
- **`WindowSizeClass.expanded`**: Large tablets, laptops, full-screen desktop windows.

---

## Publishing & Support

- **Publisher**: [kauscoder.com](https://kauscoder.com)
- **Author**: Kaustav Halder
- **Repository**: [GitHub](https://github.com/KaustavCodes/Flutter-Display-Posture-Detector-Plugin)
- **Issues & Contributions**: [Issue Tracker](https://github.com/KaustavCodes/Flutter-Display-Posture-Detector-Plugin/issues)
- **License**: [MIT](LICENSE)

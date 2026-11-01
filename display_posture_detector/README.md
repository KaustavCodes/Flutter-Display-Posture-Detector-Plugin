# display_posture_detector

[![Publisher: kauscoder.com](https://img.shields.io/badge/Publisher-kauscoder.com-indigo.svg)](https://kauscoder.com)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-blue.svg)](https://pub.dev/packages/display_posture_detector)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

A Flutter plugin for real-time detection of display postures, hardware hinge bounds, side panel cutouts, device orientation, device classification, and dual-display regions on foldable, dual-screen, and tablet devices.

> **Work in Progress (Active Testing & Device Expansion)**  
> This package is actively under development and continuously tested across a wide range of devices—including dual-screen devices (e.g. iPhone Duo simulator, Microsoft Surface Duo), foldables (Samsung Galaxy Z Fold/Flip, Google Pixel Fold), tablets (iPads, Android tablets), and standard mobile phones.  
> Our primary goal is to make it effortless for Flutter developers to accurately judge **device orientation**, **available spacing**, **window size**, and **physical hinge creases** to create responsive multi-screen layouts.  
> If you test this on additional hardware or encounter edge cases, please feel free to [open an issue or contribute](https://github.com/KaustavCodes/Flutter-Display-Posture-Detector-Plugin/issues)!

---

## Features

- **Fold State Detection**: Accurately tracks `FoldState.flat` (unfolded flat continuous), `FoldState.halfOpened` (dual-screen book / laptop tabletop posture), and `FoldState.normal` (standard flat screen).
- **Hardware Hinge & Crease Bounds (`hingeBounds`)**: Emits exact bounding rectangles (`PostureRect`) in logical dp representing the physical hinge or division crease.
- **Isolated Display Regions (`displayAreas`)**: Provides exact hardware coordinates for individual usable screen panels (Pane 1 and Pane 2) taking into account physical hinges and edge panels.
- **Side Panel Inset Tracking (`sidePanel`)**: Detects status/dock panels (such as the iPhone Duo right-side clock/status panel or system bar insets) so dual-pane layouts remain pixel-aligned with physical hardware hinges.
- **Full-Bleed Pane Sizing**: Pane 1 anchors to the physical hinge width, while Pane 2 expands to take up all remaining space on the right or bottom of the device.
- **Combined Wide Canvas (`combinedArea` / `wideArea`)**: Provides the continuous usable canvas across all panels, excluding the side panel, allowing apps to span wide widescreen content.
- **Tablet Landscape (50% / 50%) Multi-Panel**: Returns dual 50%/50% split viewports when running in landscape on tablets or iPads.
- **Hardware & Platform Classification (`DeviceType`)**: Classifies devices into `iphone`, `ipad`, `androidPhone`, `androidTablet`, `mac`, `windows`, `linux`, and `other`, with `isTablet`, `isMobile`, and `isDesktop` helpers.
- **Physical & Logical Screen Telemetry**: Hardware pixel resolution (`widthPx`, `heightPx`), screen density scale factor (`density`), and orientation (`portrait`, `landscape`).
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
| **Device Classification (`deviceType`)** | Supported (`androidPhone`, `androidTablet`) | Supported (`iphone`, `ipad`, `mac`) |
| **Screen Metrics & Orientation** | Supported | Supported |

### Android & Dual-Screen Devices (Surface Duo, Galaxy Z Fold/Flip, Pixel Fold)
On Android, the plugin leverages Google's official Jetpack WindowManager (`androidx.window:window` / `WindowInfoTracker`) API.
- **Microsoft Surface Duo / Duo 2**: Reports two distinct physical screens separated by an 84px physical hinge mask (`isSeparating: true`).
- **Galaxy Z Fold / Pixel Fold**: Reports single flexible display unfolding flat or half-opened in book posture.
- **Galaxy Z Flip**: Reports clamshell tabletop/laptop posture with horizontal hinge separation.

### iOS Support (iPhone Duo, iPad, & Simulators)
- Supports division regions and division lines on dual-screen setups (e.g. iPhone Duo simulator with iOS 27.1).
- Detects the side panel (status/dock area) so that Pane 1 and Pane 2 maintain their true physical proportions without shifting the hinge off-center.
- Provides automatic 50%/50% panel splits on iPad/tablet landscape orientations.

---

## Getting Started

### 1. Installation

Add `display_posture_detector` to your `pubspec.yaml`:

```yaml
dependencies:
  display_posture_detector: ^0.0.1
```

### 2. Basic Usage

```dart
import 'package:flutter/material.dart';
import 'package:display_posture_detector/display_posture_detector.dart';

final _plugin = DisplayPostureDetector();

// 1. Fetch physical display metrics snapshot
final metrics = await _plugin.getMetrics();
print('Device Type: ${metrics.deviceType.displayName}');
print('Physical: ${metrics.widthPx}x${metrics.heightPx} px @ ${metrics.density}x');
print('Logical Viewport: ${metrics.logicalWidth}x${metrics.logicalHeight} dp');
print('Orientation: ${metrics.orientation}');

// 2. Listen to real-time posture and hinge changes
_plugin.onPostureChanged.listen((event) {
  print('Device Type: ${event.deviceType.displayName}');
  print('Fold State: ${event.foldState}');
  print('Is Separating: ${event.isSeparating}');
  print('Orientation: ${event.orientation}');

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

## Responsive Layouts: Dual-Pane vs. Combined Wide

### Hardware-Accurate Positioning & Full Bleed
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
            // Spanned wide content across both panels, excluding the side panel
            return Container(
              width: event.wideArea.width,
              height: event.wideArea.height,
              child: WideDashboardCanvas(),
            );
          }

          // Split panels: Pane 1 anchors to hinge, Pane 2 fills the rest of the right side
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
                    SizedBox(width: pane1Size, child: PrimaryPane()),
                    HingeIndicator(thickness: hingeThickness),
                    Expanded(child: SecondaryPane()), // Fills entire right side
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: pane1Size, child: PrimaryPane()),
                    HingeIndicator(thickness: hingeThickness),
                    Expanded(child: SecondaryPane()), // Fills entire bottom side
                  ],
                );
        }

        // Standard single-screen continuous layout
        return SinglePaneView();
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

### `DeviceType`
Classified device hardware form factors:
- `DeviceType.iphone`: Apple iPhone (including iPhone Duo).
- `DeviceType.ipad`: Apple iPad.
- `DeviceType.androidPhone`: Android smartphone.
- `DeviceType.androidTablet`: Android tablet.
- `DeviceType.mac`: macOS / Mac Catalyst.
- `DeviceType.windows`: Windows PC.
- `DeviceType.linux`: Linux desktop.
- `DeviceType.other`: Unidentified / generic device.

Helper getters on `DeviceType`:
- `isTablet`: `true` for `ipad` or `androidTablet`.
- `isMobile`: `true` for `iphone` or `androidPhone`.
- `isDesktop`: `true` for `mac`, `windows`, or `linux`.
- `displayName`: Formatted readable label (e.g. `'iPhone'`, `'Android Tablet'`).

### `PostureRect`
A 2D bounding rectangle in logical pixels (dp/points):
- `left`, `top`, `width`, `height`, `right`, `bottom`.
- `isVertical`: `height >= width`.
- `isHorizontal`: `width > height`.
- `toRect()`: Converts to `dart:ui` `Rect` for seamless painting and positioning.

---

## Publishing & Support

- **Publisher**: [kauscoder.com](https://kauscoder.com)
- **Author**: Kaustav Halder
- **Repository**: [GitHub](https://github.com/KaustavCodes/Flutter-Display-Posture-Detector-Plugin)
- **Issues & Contributions**: [Issue Tracker](https://github.com/KaustavCodes/Flutter-Display-Posture-Detector-Plugin/issues)
- **License**: [MIT](LICENSE)

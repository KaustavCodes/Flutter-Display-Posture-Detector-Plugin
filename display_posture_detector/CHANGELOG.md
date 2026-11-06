## 0.0.3

* **iOS Hinge Interaction Integration**: Connected native `UIHingeInteraction` and `UIHinge.Status` on iOS to accurately detect semi-folded / half-opened postures in vertical Book mode in addition to Tabletop mode.
* **Adaptive & Responsive System**: Added `WindowSizeClass` (`compact`, `medium`, `expanded`) and configurable `PostureBreakpoints` (with `standard` 768/1024 and `material` 600/840 presets).
* **Startup Initialization**: Added `DisplayPostureDetector.initialize(...)` and `configure(...)` for one-time global breakpoint configuration in `main()`.
* **Zero-Overhead Responsive Queries**: Added $O(1)$ size queries (`sizeClass(context)`, `isCompact(context)`, `isMedium(context)`, `isExpanded(context)`, `isDesktop(context)`, `isMobile(context)`, and constraint-based width helpers).
* **Android Floating & Multi-Window Ready**: Native support for Samsung Pop-up view, Android multi-window split, iPad Split View, and desktop window resizing via performant `MediaQuery.sizeOf(context)` aspect queries.
* **Convenience Posture Getters**: Added `isTableTop`, `isBookPosture`, and `isFlat` properties to `PostureEvent`.
* **`AdaptivePostureBuilder` Widget**: Added an out-of-the-box adaptive widget that tracks both real-time physical posture and window size classes.
* **Example & Docs**: Updated example application and documentation to demonstrate responsive breakpoint customization, fixed pane header wrapping, and posture-aware layouts.

## 0.0.2

* **Performance Optimization**: Implemented native event deduplication on iOS (`PostureState`) and Android (`lastEmittedPayload`) to eliminate redundant PlatformChannel serialization and bridge traffic during rapid layout transitions.
* **Main Thread Coalescing**: Added frame-aligned scheduling (`scheduleEmit()`) for iOS layout events to prevent UI jank during 120Hz ProMotion animations.
* **Direct Root View Resolution**: Optimized view hierarchy lookups to bypass redundant window scene traversals.
* **Dart Equality Support**: Implemented `operator ==` and `hashCode` on `PostureEvent` and `DisplayMetrics` for seamless integration with reactive state management and `.distinct()` stream filtering.
* **Stage Manager & Split View Refinement**: Added width threshold safeguards for tablet landscape multi-panel splitting.

## 0.0.1

* Initial release of `display_posture_detector`.
* Real-time posture tracking (`FLAT`, `HALF_OPENED`, `NORMAL`).
* Physical hinge and crease bounds detection (`hingeBounds`).
* Usable display regions (`displayAreas`) and side dock/status panel detection (`sidePanel`).
* Full-bleed multi-pane layout support and combined wide canvas (`combinedArea`).
* Tablet landscape 50% / 50% multi-panel detection for iPads and Android tablets.
* Form factor and platform hardware classification (`DeviceType`).
* Hardware display metrics (`widthPx`, `heightPx`, `density`, `orientation`).
* Interactive posture simulation for testing on standard non-foldable devices and simulators.

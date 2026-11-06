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

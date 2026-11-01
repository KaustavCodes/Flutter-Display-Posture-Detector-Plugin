# display_posture_detector_example

An interactive example app demonstrating the capabilities of the `display_posture_detector` plugin on dual-screen devices, foldables, tablets, and phones.

---

## Features Demonstrated

1. **Dual-Pane Split Layout**:
   - Anchors Pane 1 to the hardware fold crease.
   - Accurately renders the hardware hinge at its exact physical position (`hingeBounds`).
   - Expands Pane 2 to fill all remaining space on the right or bottom of the display.
2. **Combined Wide Canvas ("Show a Wide Thing")**:
   - Toggle between **Split Panels** and **Combined Wide Canvas**.
   - Spans wide content across both panels while accounting for and excluding edge side panels.
3. **In-Content Telemetry**:
   - Moves display dimensions, orientation, density, and fold status inside the content panels to prevent layout displacement.
4. **Device Classification**:
   - Detects and displays device form factors (`iPhone`, `iPad`, `Android Phone`, `Android Tablet`, etc.).
5. **Interactive Simulation**:
   - **Simulate Hinge Fold**: Test dual-screen behavior on standard non-foldable devices.
   - **Simulation Axis**: Switch between Vertical (Book) and Horizontal (Laptop) fold axes.
   - **Simulate Tablet (50% / 50%)**: Test tablet landscape multi-column viewports.

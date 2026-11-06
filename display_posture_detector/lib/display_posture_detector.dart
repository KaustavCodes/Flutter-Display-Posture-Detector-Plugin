import 'package:flutter/widgets.dart';

import 'display_posture_detector_platform_interface.dart';
import 'src/adaptive_models.dart';
import 'src/posture_models.dart';

export 'src/adaptive_models.dart';
export 'src/adaptive_posture_builder.dart';
export 'src/posture_models.dart';

class DisplayPostureDetector {
  static PostureBreakpoints _breakpoints = PostureBreakpoints.standard;

  /// Returns the currently active global breakpoints.
  static PostureBreakpoints get breakpoints => _breakpoints;

  /// Initializes or configures global responsive breakpoints and settings.
  /// Call this once in `main()` or at app startup if you wish to override the defaults.
  ///
  /// ```dart
  /// void main() {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   DisplayPostureDetector.initialize(
  ///     breakpoints: const PostureBreakpoints(compact: 768, medium: 1024),
  ///   );
  ///   runApp(const MyApp());
  /// }
  /// ```
  static void initialize({
    PostureBreakpoints breakpoints = PostureBreakpoints.standard,
  }) {
    _breakpoints = breakpoints;
  }

  /// Configures the active global breakpoints.
  static void configure({required PostureBreakpoints breakpoints}) {
    _breakpoints = breakpoints;
  }

  /// Classifies the current window size using [MediaQuery.sizeOf].
  /// This is an O(1) aspect query that only triggers rebuilds when window dimensions change.
  static WindowSizeClass sizeClass(
    BuildContext context, {
    PostureBreakpoints? customBreakpoints,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    return (customBreakpoints ?? _breakpoints).classify(width);
  }

  /// Returns `true` if current window width is within the compact size class (< compact threshold).
  /// Handles standard phones, Android floating pop-up windows, and narrow split screens.
  static bool isCompact(
    BuildContext context, {
    PostureBreakpoints? customBreakpoints,
  }) =>
      sizeClass(context, customBreakpoints: customBreakpoints) ==
      WindowSizeClass.compact;

  /// Returns `true` if current window width is within the medium size class.
  /// Covers unfolded foldables, tablets, and 1/2 split windows.
  static bool isMedium(
    BuildContext context, {
    PostureBreakpoints? customBreakpoints,
  }) =>
      sizeClass(context, customBreakpoints: customBreakpoints) ==
      WindowSizeClass.medium;

  /// Returns `true` if current window width is within the expanded / desktop size class.
  static bool isExpanded(
    BuildContext context, {
    PostureBreakpoints? customBreakpoints,
  }) =>
      sizeClass(context, customBreakpoints: customBreakpoints) ==
      WindowSizeClass.expanded;

  /// Helper alias for mobile checks (compact window size).
  static bool isMobile(
    BuildContext context, {
    PostureBreakpoints? customBreakpoints,
  }) => isCompact(context, customBreakpoints: customBreakpoints);

  /// Helper alias for tablet checks (medium window size).
  static bool isTablet(
    BuildContext context, {
    PostureBreakpoints? customBreakpoints,
  }) => isMedium(context, customBreakpoints: customBreakpoints);

  /// Helper alias for desktop checks (expanded window size).
  static bool isDesktop(
    BuildContext context, {
    PostureBreakpoints? customBreakpoints,
  }) => isExpanded(context, customBreakpoints: customBreakpoints);

  /// Classifies an explicit width or [BoxConstraints.maxWidth].
  static WindowSizeClass classifyWidth(
    double width, {
    PostureBreakpoints? customBreakpoints,
  }) => (customBreakpoints ?? _breakpoints).classify(width);

  /// Checks if an explicit width is compact.
  static bool isCompactWidth(
    double width, {
    PostureBreakpoints? customBreakpoints,
  }) =>
      classifyWidth(width, customBreakpoints: customBreakpoints) ==
      WindowSizeClass.compact;

  /// Checks if an explicit width is medium.
  static bool isMediumWidth(
    double width, {
    PostureBreakpoints? customBreakpoints,
  }) =>
      classifyWidth(width, customBreakpoints: customBreakpoints) ==
      WindowSizeClass.medium;

  /// Checks if an explicit width is expanded / desktop.
  static bool isDesktopWidth(
    double width, {
    PostureBreakpoints? customBreakpoints,
  }) =>
      classifyWidth(width, customBreakpoints: customBreakpoints) ==
      WindowSizeClass.expanded;

  /// Fetches a snapshot of physical screen dimensions, density, and orientation.
  Future<DisplayMetrics> getMetrics() {
    return DisplayPostureDetectorPlatform.instance.getMetrics();
  }

  /// Emits real-time updates whenever hinge fold posture or orientation changes.
  Stream<PostureEvent> get onPostureChanged {
    return DisplayPostureDetectorPlatform.instance.onPostureChanged;
  }
}

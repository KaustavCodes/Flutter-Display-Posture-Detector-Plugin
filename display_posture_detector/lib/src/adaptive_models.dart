/// Represents the window size categorization based on available width.
/// Follows modern adaptive window size classifications:
/// - [compact]: Typical phones, portrait orientation, or floating/split windows (< compact breakpoint).
/// - [medium]: Foldables unfolded, small tablets, landscape phones, or 1/2 split screen windows.
/// - [expanded]: Large tablets, desktops, full-screen laptops (>= medium breakpoint).
enum WindowSizeClass {
  compact,
  medium,
  expanded;

  bool get isCompact => this == WindowSizeClass.compact;
  bool get isMedium => this == WindowSizeClass.medium;
  bool get isExpanded => this == WindowSizeClass.expanded;
}

/// Configurable breakpoint thresholds (in logical pixels) for categorizing window width.
class PostureBreakpoints {
  /// Upper bound for [WindowSizeClass.compact] (exclusive).
  /// Any width strictly less than this threshold is classified as compact.
  final double compact;

  /// Upper bound for [WindowSizeClass.medium] (exclusive).
  /// Any width greater than or equal to [compact] and strictly less than [medium] is medium.
  /// Any width greater than or equal to [medium] is classified as [WindowSizeClass.expanded].
  final double medium;

  const PostureBreakpoints({this.compact = 768.0, this.medium = 1024.0});

  /// Standard iOS/macOS/desktop thresholds (768 / 1024 pt).
  static const PostureBreakpoints standard = PostureBreakpoints(
    compact: 768.0,
    medium: 1024.0,
  );

  /// Material 3 adaptive window class breakpoints (600 / 840 dp).
  static const PostureBreakpoints material = PostureBreakpoints(
    compact: 600.0,
    medium: 840.0,
  );

  /// Classifies a given logical width into a [WindowSizeClass].
  WindowSizeClass classify(double width) {
    if (width < compact) return WindowSizeClass.compact;
    if (width < medium) return WindowSizeClass.medium;
    return WindowSizeClass.expanded;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostureBreakpoints &&
          runtimeType == other.runtimeType &&
          compact == other.compact &&
          medium == other.medium;

  @override
  int get hashCode => Object.hash(compact, medium);

  @override
  String toString() => 'PostureBreakpoints(compact: $compact, medium: $medium)';
}

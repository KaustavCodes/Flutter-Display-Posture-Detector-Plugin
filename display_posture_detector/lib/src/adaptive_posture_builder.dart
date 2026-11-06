import 'dart:async';

import 'package:flutter/material.dart';

import '../display_posture_detector.dart';

/// Signature for a builder function that receives physical posture and window size classification.
typedef AdaptivePostureWidgetBuilder = Widget Function(
  BuildContext context,
  PostureEvent posture,
  WindowSizeClass sizeClass,
);

/// An adaptive Flutter widget that continuously tracks both hardware folding posture
/// (flat, tabletop, book, hinge dimensions) and responsive window size class
/// (compact, medium, expanded).
///
/// Automatically responds to:
/// - Real-time physical folding/unfolding events on dual-screen and foldable devices.
/// - Window resizing, Android floating pop-up windows, and split-screen mode.
class AdaptivePostureBuilder extends StatefulWidget {
  /// The builder called whenever window size or device posture changes.
  final AdaptivePostureWidgetBuilder builder;

  /// Optional local breakpoint overrides for this specific widget subtree.
  /// If null, defaults to [DisplayPostureDetector.breakpoints].
  final PostureBreakpoints? breakpoints;

  /// Optional initial posture snapshot while the native stream initializes.
  final PostureEvent? initialPosture;

  const AdaptivePostureBuilder({
    super.key,
    required this.builder,
    this.breakpoints,
    this.initialPosture,
  });

  @override
  State<AdaptivePostureBuilder> createState() => _AdaptivePostureBuilderState();
}

class _AdaptivePostureBuilderState extends State<AdaptivePostureBuilder> {
  final _plugin = DisplayPostureDetector();
  StreamSubscription<PostureEvent>? _subscription;
  late PostureEvent _currentPosture;

  @override
  void initState() {
    super.initState();
    _currentPosture =
        widget.initialPosture ??
        const PostureEvent(
          foldState: FoldState.normal,
          isSeparating: false,
          orientation: PostureOrientation.portrait,
        );

    _subscription = _plugin.onPostureChanged.listen(
      (event) {
        if (!mounted) return;
        if (event != _currentPosture) {
          setState(() => _currentPosture = event);
        }
      },
      onError: (_) {
        // Fall back gracefully to existing posture if native stream has an issue
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final activeBreakpoints =
        widget.breakpoints ?? DisplayPostureDetector.breakpoints;
    final sizeClass = activeBreakpoints.classify(width);

    return widget.builder(context, _currentPosture, sizeClass);
  }
}

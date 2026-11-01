import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:display_posture_detector/display_posture_detector.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('getMetrics returns valid native screen dimensions', (
    WidgetTester tester,
  ) async {
    final DisplayPostureDetector plugin = DisplayPostureDetector();
    final DisplayMetrics metrics = await plugin.getMetrics();

    // Verify native side returned real screen pixel measurements
    expect(metrics.widthPx, greaterThan(0));
    expect(metrics.heightPx, greaterThan(0));
    expect(metrics.density, greaterThan(0.0));
    expect(
      metrics.orientation,
      isIn([PostureOrientation.portrait, PostureOrientation.landscape]),
    );
  });

  testWidgets('onPostureChanged stream emits initial posture event', (
    WidgetTester tester,
  ) async {
    final DisplayPostureDetector plugin = DisplayPostureDetector();

    // Grab the first event emitted when the EventChannel listener attaches
    final PostureEvent firstEvent = await plugin.onPostureChanged.first.timeout(
      const Duration(seconds: 5),
    );

    expect(
      firstEvent.foldState,
      isIn([FoldState.normal, FoldState.flat, FoldState.halfOpened]),
    );
    expect(
      firstEvent.orientation,
      isIn([PostureOrientation.portrait, PostureOrientation.landscape]),
    );
  });
}

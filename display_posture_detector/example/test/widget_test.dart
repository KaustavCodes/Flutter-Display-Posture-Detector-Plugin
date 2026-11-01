import 'package:flutter_test/flutter_test.dart';
import 'package:display_posture_detector_example/main.dart';

void main() {
  testWidgets('Verify PostureDashboard renders title and simulation toggle',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Display Posture'), findsOneWidget);
    expect(find.text('Simulate Hinge Fold'), findsOneWidget);
  });
}

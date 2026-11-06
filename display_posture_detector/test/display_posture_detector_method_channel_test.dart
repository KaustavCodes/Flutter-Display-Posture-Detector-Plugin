import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:display_posture_detector/display_posture_detector_method_channel.dart';
import 'package:display_posture_detector/src/posture_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelDisplayPostureDetector();
  const methodChannel = MethodChannel('com.kauscoder.display_posture/methods');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (MethodCall methodCall) async {
          if (methodCall.method == 'getMetrics') {
            return <String, dynamic>{
              'widthPx': 1800,
              'heightPx': 2700,
              'density': 2.5,
              'orientation': 'PORTRAIT',
              'deviceType': 'IPHONE',
            };
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  test('getMetrics parses native method channel payload correctly', () async {
    final metrics = await platform.getMetrics();
    expect(metrics.widthPx, 1800);
    expect(metrics.heightPx, 2700);
    expect(metrics.density, 2.5);
    expect(metrics.orientation, PostureOrientation.portrait);
    expect(metrics.deviceType, DeviceType.iphone);
    expect(metrics.logicalWidth, 720.0);
    expect(metrics.logicalHeight, 1080.0);
  });

  test('PostureEvent.fromMap parses hingeBounds, displayAreas, and sidePanel correctly', () {
    final map = <String, dynamic>{
      'foldState': 'HALF_OPENED',
      'isSeparating': true,
      'orientation': 'LANDSCAPE',
      'hingeBounds': <String, dynamic>{
        'left': 456.0,
        'top': 0.0,
        'width': 40.0,
        'height': 669.0,
      },
      'displayAreas': <dynamic>[
        <String, dynamic>{
          'left': 0.0,
          'top': 0.0,
          'width': 456.0,
          'height': 669.0,
        },
        <String, dynamic>{
          'left': 496.0,
          'top': 0.0,
          'width': 455.0,
          'height': 669.0,
        },
      ],
      'sidePanel': <String, dynamic>{
        'left': 871.0,
        'top': 0.0,
        'width': 80.0,
        'height': 669.0,
      },
      'combinedArea': <String, dynamic>{
        'left': 0.0,
        'top': 0.0,
        'width': 871.0,
        'height': 669.0,
      },
      'isTablet': false,
    };

    final event = PostureEvent.fromMap(map);
    expect(event.foldState, FoldState.halfOpened);
    expect(event.isSeparating, isTrue);
    expect(event.orientation, PostureOrientation.landscape);
    expect(event.hasHinge, isTrue);
    expect(event.isVerticalHinge, isTrue);
    expect(event.hingeBounds?.left, 456.0);
    expect(event.hingeBounds?.width, 40.0);
    expect(event.displayAreas.length, 2);
    expect(event.displayAreas[0].width, 456.0);
    expect(event.displayAreas[1].left, 496.0);
    expect(event.displayAreas[1].width, 455.0);
    expect(event.sidePanel?.width, 80.0);
    expect(event.wideArea.width, 871.0);
  });
}

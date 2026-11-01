import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:display_posture_detector/display_posture_detector.dart';
import 'package:display_posture_detector/display_posture_detector_platform_interface.dart';
import 'package:display_posture_detector/display_posture_detector_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDisplayPostureDetectorPlatform
    with MockPlatformInterfaceMixin
    implements DisplayPostureDetectorPlatform {
  @override
  Future<DisplayMetrics> getMetrics() {
    return Future.value(
      const DisplayMetrics(
        widthPx: 1080,
        heightPx: 2400,
        density: 2.625,
        orientation: PostureOrientation.portrait,
        deviceType: DeviceType.androidPhone,
      ),
    );
  }

  @override
  Stream<PostureEvent> get onPostureChanged {
    return Stream.value(
      const PostureEvent(
        foldState: FoldState.halfOpened,
        isSeparating: true,
        orientation: PostureOrientation.portrait,
        deviceType: DeviceType.androidPhone,
        hingeBounds: PostureRect(left: 0, top: 440, width: 412, height: 24),
        displayAreas: [
          PostureRect(left: 0, top: 0, width: 412, height: 440),
          PostureRect(left: 0, top: 464, width: 412, height: 440),
        ],
      ),
    );
  }
}

void main() {
  final DisplayPostureDetectorPlatform initialPlatform =
      DisplayPostureDetectorPlatform.instance;

  test('$MethodChannelDisplayPostureDetector is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelDisplayPostureDetector>());
  });

  test('getMetrics returns DisplayMetrics from mock platform', () async {
    final detector = DisplayPostureDetector();
    final fakePlatform = MockDisplayPostureDetectorPlatform();
    DisplayPostureDetectorPlatform.instance = fakePlatform;

    final metrics = await detector.getMetrics();
    expect(metrics.widthPx, 1080);
    expect(metrics.heightPx, 2400);
    expect(metrics.density, 2.625);
    expect(metrics.orientation, PostureOrientation.portrait);
    expect(metrics.deviceType, DeviceType.androidPhone);
    expect(metrics.logicalWidth, closeTo(411.4, 0.1));
  });

  test('onPostureChanged emits PostureEvent with hinge and display areas', () async {
    final detector = DisplayPostureDetector();
    final fakePlatform = MockDisplayPostureDetectorPlatform();
    DisplayPostureDetectorPlatform.instance = fakePlatform;

    final event = await detector.onPostureChanged.first;
    expect(event.foldState, FoldState.halfOpened);
    expect(event.isSeparating, isTrue);
    expect(event.hasHinge, isTrue);
    expect(event.hingeBounds?.height, 24);
    expect(event.displayAreas.length, 2);
  });
}

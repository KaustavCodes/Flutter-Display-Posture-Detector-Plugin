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
    expect(
      initialPlatform,
      isInstanceOf<MethodChannelDisplayPostureDetector>(),
    );
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

  test(
    'onPostureChanged emits PostureEvent with hinge and display areas',
    () async {
      final detector = DisplayPostureDetector();
      final fakePlatform = MockDisplayPostureDetectorPlatform();
      DisplayPostureDetectorPlatform.instance = fakePlatform;

      final event = await detector.onPostureChanged.first;
      expect(event.foldState, FoldState.halfOpened);
      expect(event.isSeparating, isTrue);
      expect(event.hasHinge, isTrue);
      expect(event.hingeBounds?.height, 24);
      expect(event.displayAreas.length, 2);
    },
  );

  test('PostureEvent and DisplayMetrics value equality and hashCode work correctly', () {
    const event1 = PostureEvent(
      foldState: FoldState.halfOpened,
      isSeparating: true,
      orientation: PostureOrientation.portrait,
      displayAreas: [PostureRect(left: 0, top: 0, width: 100, height: 100)],
    );
    const event2 = PostureEvent(
      foldState: FoldState.halfOpened,
      isSeparating: true,
      orientation: PostureOrientation.portrait,
      displayAreas: [PostureRect(left: 0, top: 0, width: 100, height: 100)],
    );
    const event3 = PostureEvent(
      foldState: FoldState.flat,
      isSeparating: false,
      orientation: PostureOrientation.portrait,
    );

    expect(event1, equals(event2));
    expect(event1.hashCode, equals(event2.hashCode));
    expect(event1 == event3, isFalse);

    const metrics1 = DisplayMetrics(
      widthPx: 1080,
      heightPx: 1920,
      density: 2.0,
      orientation: PostureOrientation.portrait,
    );
    const metrics2 = DisplayMetrics(
      widthPx: 1080,
      heightPx: 1920,
      density: 2.0,
      orientation: PostureOrientation.portrait,
    );

    expect(metrics1, equals(metrics2));
    expect(metrics1.hashCode, equals(metrics2.hashCode));
  });

  test('PostureBreakpoints and DisplayPostureDetector initialize & responsive checks work', () {
    DisplayPostureDetector.initialize(
      breakpoints: const PostureBreakpoints(compact: 768.0, medium: 1024.0),
    );

    expect(DisplayPostureDetector.breakpoints.compact, 768.0);
    expect(DisplayPostureDetector.breakpoints.medium, 1024.0);

    // Compact (< 768)
    expect(DisplayPostureDetector.classifyWidth(390), WindowSizeClass.compact);
    expect(DisplayPostureDetector.isCompactWidth(390), isTrue);
    expect(DisplayPostureDetector.isDesktopWidth(390), isFalse);

    // Medium (768 to 1023)
    expect(DisplayPostureDetector.classifyWidth(800), WindowSizeClass.medium);
    expect(DisplayPostureDetector.isMediumWidth(800), isTrue);

    // Desktop / Expanded (>= 1024)
    expect(
      DisplayPostureDetector.classifyWidth(1280),
      WindowSizeClass.expanded,
    );
    expect(DisplayPostureDetector.isDesktopWidth(1280), isTrue);
  });

  test('PostureEvent posture convenience getters identify tabletop, book, and flat postures', () {
    const tabletop = PostureEvent(
      foldState: FoldState.halfOpened,
      isSeparating: true,
      orientation: PostureOrientation.portrait,
      hingeBounds: PostureRect(
        left: 0,
        top: 400,
        width: 400,
        height: 20,
      ), // horizontal hinge
    );
    expect(tabletop.isTableTop, isTrue);
    expect(tabletop.isBookPosture, isFalse);

    const book = PostureEvent(
      foldState: FoldState.halfOpened,
      isSeparating: true,
      orientation: PostureOrientation.landscape,
      hingeBounds: PostureRect(
        left: 400,
        top: 0,
        width: 20,
        height: 400,
      ), // vertical hinge
    );
    expect(book.isBookPosture, isTrue);
    expect(book.isTableTop, isFalse);

    const flat = PostureEvent(
      foldState: FoldState.flat,
      isSeparating: false,
      orientation: PostureOrientation.portrait,
    );
    expect(flat.isFlat, isTrue);
  });

  test('PostureEvent equality includes occlusionAreas and Portrait top clearance works', () {
    const baseSidePanel = PostureRect(left: 346, top: 0, width: 84, height: 932);
    const portraitWithOcclusion = PostureEvent(
      foldState: FoldState.normal,
      isSeparating: false,
      orientation: PostureOrientation.portrait,
      sidePanel: baseSidePanel,
      occlusionAreas: [
        PostureRect(left: 366, top: 18, width: 44, height: 112),
      ],
    );
    const portraitWithoutOcclusion = PostureEvent(
      foldState: FoldState.normal,
      isSeparating: false,
      orientation: PostureOrientation.portrait,
      sidePanel: baseSidePanel,
    );

    expect(portraitWithOcclusion == portraitWithoutOcclusion, isFalse);
    final pad = portraitWithOcclusion.sidePanelSafePadding(extraMargin: 8.0);
    expect(pad.top, 138.0);
    expect(pad.bottom, 0.0);
  });
}

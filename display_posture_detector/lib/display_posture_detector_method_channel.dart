import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'display_posture_detector_platform_interface.dart';
import 'src/posture_models.dart';

class MethodChannelDisplayPostureDetector
    extends DisplayPostureDetectorPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('com.kauscoder.display_posture/methods');

  @visibleForTesting
  final eventChannel = const EventChannel('com.kauscoder.display_posture/events');

  Stream<PostureEvent>? _postureStream;

  @override
  Future<DisplayMetrics> getMetrics() async {
    final result = await methodChannel.invokeMapMethod<String, dynamic>('getMetrics');
    if (result == null) {
      throw PlatformException(
        code: 'NULL_RESULT',
        message: 'Native platform returned null for getMetrics.',
      );
    }
    return DisplayMetrics.fromMap(result);
  }

  @override
  Stream<PostureEvent> get onPostureChanged {
    _postureStream ??= eventChannel
        .receiveBroadcastStream()
        .map((dynamic event) => PostureEvent.fromMap(event as Map));
    return _postureStream!;
  }
}

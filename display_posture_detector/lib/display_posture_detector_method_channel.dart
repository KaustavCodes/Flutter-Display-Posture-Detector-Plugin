import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'display_posture_detector_platform_interface.dart';
import 'src/posture_models.dart';

class MethodChannelDisplayPostureDetector
    extends DisplayPostureDetectorPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel(
    'com.kauscoder.display_posture/methods',
  );

  @visibleForTesting
  final eventChannel = const EventChannel(
    'com.kauscoder.display_posture/events',
  );

  final Set<MultiStreamController<PostureEvent>> _controllers =
      <MultiStreamController<PostureEvent>>{};
  StreamSubscription<dynamic>? _nativeSubscription;
  PostureEvent? _latestPosture;
  Stream<PostureEvent>? _postureStream;

  /// Latest [PostureEvent] received from the native platform while active listeners exist.
  PostureEvent? get latestPosture => _latestPosture;

  @override
  Future<DisplayMetrics> getMetrics() async {
    final result = await methodChannel.invokeMapMethod<String, dynamic>(
      'getMetrics',
    );
    if (result == null) {
      throw PlatformException(
        code: 'NULL_RESULT',
        message: 'Native platform returned null for getMetrics.',
      );
    }
    return DisplayMetrics.fromMap(result);
  }

  void _ensureNativeSubscription() {
    if (_nativeSubscription != null) return;
    _nativeSubscription = eventChannel.receiveBroadcastStream().listen(
      (dynamic rawEvent) {
        final event = PostureEvent.fromMap(rawEvent as Map);
        _latestPosture = event;
        for (final controller in List<MultiStreamController<PostureEvent>>.of(
          _controllers,
        )) {
          if (!controller.isClosed) {
            controller.add(event);
          }
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        for (final controller in List<MultiStreamController<PostureEvent>>.of(
          _controllers,
        )) {
          if (!controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        }
      },
    );
  }

  @override
  Stream<PostureEvent> get onPostureChanged {
    _postureStream ??= Stream<PostureEvent>.multi((
      MultiStreamController<PostureEvent> controller,
    ) {
      _controllers.add(controller);
      final cached = _latestPosture;
      if (cached != null) {
        scheduleMicrotask(() {
          if (!controller.isClosed && _latestPosture != null) {
            controller.add(cached);
          }
        });
      }
      _ensureNativeSubscription();
      controller.onCancel = () {
        _controllers.remove(controller);
        if (_controllers.isEmpty) {
          _nativeSubscription?.cancel();
          _nativeSubscription = null;
          _latestPosture = null;
        }
      };
    });
    return _postureStream!;
  }
}

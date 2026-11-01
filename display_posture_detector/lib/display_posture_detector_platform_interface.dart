import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'display_posture_detector_method_channel.dart';
import 'src/posture_models.dart';

abstract class DisplayPostureDetectorPlatform extends PlatformInterface {
  DisplayPostureDetectorPlatform() : super(token: _token);

  static final Object _token = Object();

  static DisplayPostureDetectorPlatform _instance =
      MethodChannelDisplayPostureDetector();

  static DisplayPostureDetectorPlatform get instance => _instance;

  static set instance(DisplayPostureDetectorPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<DisplayMetrics> getMetrics() {
    throw UnimplementedError('getMetrics() has not been implemented.');
  }

  Stream<PostureEvent> get onPostureChanged {
    throw UnimplementedError('onPostureChanged has not been implemented.');
  }
}

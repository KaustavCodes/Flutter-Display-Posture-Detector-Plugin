import 'display_posture_detector_platform_interface.dart';
import 'src/posture_models.dart';

export 'src/posture_models.dart';

class DisplayPostureDetector {
  /// Fetches a snapshot of physical screen dimensions, density, and orientation.
  Future<DisplayMetrics> getMetrics() {
    return DisplayPostureDetectorPlatform.instance.getMetrics();
  }

  /// Emits real-time updates whenever hinge fold posture or orientation changes.
  Stream<PostureEvent> get onPostureChanged {
    return DisplayPostureDetectorPlatform.instance.onPostureChanged;
  }
}

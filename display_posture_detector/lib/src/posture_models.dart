import 'dart:ui' show Rect, Size;

/// Represents the folding state of a foldable or dual-screen device.
enum FoldState {
  flat,
  halfOpened,
  normal;

  static FoldState fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'FLAT':
        return FoldState.flat;
      case 'HALF_OPENED':
        return FoldState.halfOpened;
      default:
        return FoldState.normal;
    }
  }
}

/// Represents the physical display orientation.
enum PostureOrientation {
  portrait,
  landscape;

  static PostureOrientation fromString(String? value) {
    return value?.toUpperCase() == 'LANDSCAPE'
        ? PostureOrientation.landscape
        : PostureOrientation.portrait;
  }
}

/// Represents the classified hardware or OS device type.
enum DeviceType {
  iphone,
  ipad,
  androidPhone,
  androidTablet,
  mac,
  windows,
  linux,
  other;

  static DeviceType fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'IPHONE':
        return DeviceType.iphone;
      case 'IPAD':
        return DeviceType.ipad;
      case 'ANDROID_PHONE':
      case 'ANDROID':
        return DeviceType.androidPhone;
      case 'ANDROID_TABLET':
        return DeviceType.androidTablet;
      case 'MAC':
      case 'MACOS':
        return DeviceType.mac;
      case 'WINDOWS':
        return DeviceType.windows;
      case 'LINUX':
        return DeviceType.linux;
      default:
        return DeviceType.other;
    }
  }

  String get displayName => switch (this) {
    DeviceType.iphone => 'iPhone',
    DeviceType.ipad => 'iPad',
    DeviceType.androidPhone => 'Android Phone',
    DeviceType.androidTablet => 'Android Tablet',
    DeviceType.mac => 'Mac',
    DeviceType.windows => 'Windows',
    DeviceType.linux => 'Linux',
    DeviceType.other => 'Unidentified Device',
  };

  bool get isTablet => this == DeviceType.ipad || this == DeviceType.androidTablet;
  bool get isMobile => this == DeviceType.iphone || this == DeviceType.androidPhone;
  bool get isDesktop => this == DeviceType.mac || this == DeviceType.windows || this == DeviceType.linux;
}

/// Represents a 2D bounding rectangle in logical pixels (dp/points).
class PostureRect {
  final double left;
  final double top;
  final double width;
  final double height;

  const PostureRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  double get right => left + width;
  double get bottom => top + height;
  bool get isVertical => height >= width;
  bool get isHorizontal => width > height;

  factory PostureRect.fromMap(Map<dynamic, dynamic> map) {
    return PostureRect(
      left: (map['left'] as num?)?.toDouble() ?? 0.0,
      top: (map['top'] as num?)?.toDouble() ?? 0.0,
      width: (map['width'] as num?)?.toDouble() ?? 0.0,
      height: (map['height'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Rect toRect() => Rect.fromLTWH(left, top, width, height);

  Map<String, dynamic> toMap() => {
    'left': left,
    'top': top,
    'width': width,
    'height': height,
  };

  @override
  String toString() =>
      'PostureRect(left: ${left.toStringAsFixed(1)}, top: ${top.toStringAsFixed(1)}, width: ${width.toStringAsFixed(1)}, height: ${height.toStringAsFixed(1)})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostureRect &&
          runtimeType == other.runtimeType &&
          left == other.left &&
          top == other.top &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => Object.hash(left, top, width, height);
}

/// Physical display dimensions, density, orientation, and device type.
class DisplayMetrics {
  final int widthPx;
  final int heightPx;
  final double density;
  final PostureOrientation orientation;
  final DeviceType deviceType;

  const DisplayMetrics({
    required this.widthPx,
    required this.heightPx,
    required this.density,
    required this.orientation,
    this.deviceType = DeviceType.other,
  });

  /// Logical width in dp/points.
  double get logicalWidth => density > 0 ? widthPx / density : widthPx.toDouble();

  /// Logical height in dp/points.
  double get logicalHeight => density > 0 ? heightPx / density : heightPx.toDouble();

  /// Physical resolution [Size].
  Size get physicalSize => Size(widthPx.toDouble(), heightPx.toDouble());

  /// Logical resolution [Size].
  Size get logicalSize => Size(logicalWidth, logicalHeight);

  factory DisplayMetrics.fromMap(Map<dynamic, dynamic> map) {
    return DisplayMetrics(
      widthPx: (map['widthPx'] as num?)?.toInt() ?? 0,
      heightPx: (map['heightPx'] as num?)?.toInt() ?? 0,
      density: (map['density'] as num?)?.toDouble() ?? 1.0,
      orientation: PostureOrientation.fromString(map['orientation'] as String?),
      deviceType: DeviceType.fromString(map['deviceType'] as String?),
    );
  }

  Map<String, dynamic> toMap() => {
    'widthPx': widthPx,
    'heightPx': heightPx,
    'density': density,
    'orientation': orientation.name.toUpperCase(),
    'deviceType': deviceType.name.toUpperCase(),
  };

  @override
  String toString() =>
      'DisplayMetrics(${widthPx}x$heightPx px, density: ${density}x, orientation: ${orientation.name}, deviceType: ${deviceType.displayName})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DisplayMetrics &&
          runtimeType == other.runtimeType &&
          widthPx == other.widthPx &&
          heightPx == other.heightPx &&
          density == other.density &&
          orientation == other.orientation &&
          deviceType == other.deviceType;

  @override
  int get hashCode =>
      Object.hash(widthPx, heightPx, density, orientation, deviceType);
}

/// Event emitted when posture, hinge crease, display regions, or device orientation changes.
class PostureEvent {
  final FoldState foldState;
  final bool isSeparating;
  final PostureOrientation orientation;
  final DeviceType deviceType;
  final PostureRect? hingeBounds;
  final List<PostureRect> displayAreas;
  final PostureRect? sidePanel;
  final PostureRect? combinedArea;
  final bool isTablet;

  const PostureEvent({
    required this.foldState,
    required this.isSeparating,
    required this.orientation,
    this.deviceType = DeviceType.other,
    this.hingeBounds,
    this.displayAreas = const [],
    this.sidePanel,
    this.combinedArea,
    this.isTablet = false,
  });

  /// Primary display panel (e.g. Left screen in vertical fold, Top screen in horizontal fold).
  PostureRect? get primaryPanel => displayAreas.isNotEmpty ? displayAreas.first : null;

  /// Secondary display panel (e.g. Right screen in vertical fold, Bottom screen in horizontal fold).
  PostureRect? get secondaryPanel => displayAreas.length > 1 ? displayAreas[1] : null;

  /// Combined / Wide canvas area spanning across panels, excluding side panels.
  PostureRect get wideArea =>
      combinedArea ??
      (displayAreas.isNotEmpty
          ? displayAreas.first
          : const PostureRect(left: 0, top: 0, width: 0, height: 0));

  /// Whether a physical or simulated hinge is present with positive dimensions.
  bool get hasHinge =>
      hingeBounds != null && (hingeBounds!.width > 0 || hingeBounds!.height > 0);

  /// Whether the display is split into multiple panels (half-opened, separating, or tablet multi-panel).
  bool get isSplit =>
      foldState == FoldState.halfOpened ||
      isSeparating ||
      displayAreas.length >= 2 ||
      (isTablet && orientation == PostureOrientation.landscape);

  /// Whether the hinge is vertically oriented (book posture: left/right panes).
  bool get isVerticalHinge =>
      hingeBounds != null ? hingeBounds!.isVertical : (orientation == PostureOrientation.landscape);

  /// Whether the hinge is horizontally oriented (laptop/tabletop posture: top/bottom panes).
  bool get isHorizontalHinge => !isVerticalHinge;

  factory PostureEvent.fromMap(Map<dynamic, dynamic> map) {
    PostureRect? hinge;
    if (map['hingeBounds'] is Map) {
      hinge = PostureRect.fromMap(map['hingeBounds'] as Map);
    }

    final displayAreas = <PostureRect>[];
    if (map['displayAreas'] is List) {
      for (final item in (map['displayAreas'] as List)) {
        if (item is Map) {
          displayAreas.add(PostureRect.fromMap(item));
        }
      }
    }

    PostureRect? sidePanel;
    if (map['sidePanel'] is Map) {
      sidePanel = PostureRect.fromMap(map['sidePanel'] as Map);
    }

    PostureRect? combinedArea;
    if (map['combinedArea'] is Map) {
      combinedArea = PostureRect.fromMap(map['combinedArea'] as Map);
    }

    return PostureEvent(
      foldState: FoldState.fromString(map['foldState'] as String?),
      isSeparating: map['isSeparating'] as bool? ?? false,
      orientation: PostureOrientation.fromString(map['orientation'] as String?),
      deviceType: DeviceType.fromString(map['deviceType'] as String?),
      hingeBounds: hinge,
      displayAreas: displayAreas,
      sidePanel: sidePanel,
      combinedArea: combinedArea,
      isTablet: map['isTablet'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'foldState': foldState.name.toUpperCase(),
    'isSeparating': isSeparating,
    'orientation': orientation.name.toUpperCase(),
    'deviceType': deviceType.name.toUpperCase(),
    if (hingeBounds != null) 'hingeBounds': hingeBounds!.toMap(),
    'displayAreas': displayAreas.map((a) => a.toMap()).toList(),
    if (sidePanel != null) 'sidePanel': sidePanel!.toMap(),
    if (combinedArea != null) 'combinedArea': combinedArea!.toMap(),
    'isTablet': isTablet,
  };

  @override
  String toString() =>
      'PostureEvent(deviceType: ${deviceType.displayName}, foldState: $foldState, isSeparating: $isSeparating, orientation: $orientation, hingeBounds: $hingeBounds, displayAreas: ${displayAreas.length}, sidePanel: $sidePanel, combinedArea: $combinedArea)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostureEvent &&
          runtimeType == other.runtimeType &&
          foldState == other.foldState &&
          isSeparating == other.isSeparating &&
          orientation == other.orientation &&
          deviceType == other.deviceType &&
          hingeBounds == other.hingeBounds &&
          sidePanel == other.sidePanel &&
          combinedArea == other.combinedArea &&
          isTablet == other.isTablet &&
          _listEquals(displayAreas, other.displayAreas);

  @override
  int get hashCode => Object.hash(
        foldState,
        isSeparating,
        orientation,
        deviceType,
        hingeBounds,
        sidePanel,
        combinedArea,
        isTablet,
        Object.hashAll(displayAreas),
      );

  static bool _listEquals<E>(List<E> a, List<E> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

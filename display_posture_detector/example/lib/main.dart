import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:display_posture_detector/display_posture_detector.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  DisplayPostureDetector.initialize(
    breakpoints: const PostureBreakpoints(compact: 768.0, medium: 1024.0),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Display Posture Inspector',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F1117),
      ),
      home: const PostureDashboard(),
    );
  }
}

class PostureDashboard extends StatefulWidget {
  const PostureDashboard({super.key});

  @override
  State<PostureDashboard> createState() => _PostureDashboardState();
}

enum DisplayViewMode {
  splitPanels, // Independent split panels around the hinge
  combinedWide, // Continuous wide canvas spanning across screens (excluding side panel)
}

class _PostureDashboardState extends State<PostureDashboard> {
  final _plugin = DisplayPostureDetector();
  StreamSubscription<PostureEvent>? _postureSubscription;

  DisplayMetrics? _metrics;
  PostureEvent _currentPosture = const PostureEvent(
    foldState: FoldState.normal,
    isSeparating: false,
    orientation: PostureOrientation.portrait,
  );

  DisplayViewMode _viewMode = DisplayViewMode.splitPanels;
  bool _simulateHingeFold = false;
  bool? _overrideSimulatedVertical;
  bool _simulateTabletLandscape = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchMetrics();
    _listenToPostureStream();
  }

  Future<void> _fetchMetrics() async {
    try {
      final metrics = await _plugin.getMetrics();
      if (!mounted) return;
      setState(() {
        _metrics = metrics;
        _error = null;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  void _listenToPostureStream() {
    _postureSubscription = _plugin.onPostureChanged.listen(
      (event) {
        if (!mounted) return;
        final orientationChanged =
            event.orientation != _currentPosture.orientation;
        setState(() {
          _currentPosture = event;
          if (event.foldState != FoldState.normal) {
            _simulateHingeFold = false;
          }
        });
        if (orientationChanged) {
          _fetchMetrics();
        }
      },
      onError: (Object err) {
        if (!mounted) return;
        setState(() => _error = err.toString());
      },
    );
  }

  @override
  void dispose() {
    _postureSubscription?.cancel();
    super.dispose();
  }

  FoldState get _effectiveFoldState =>
      _simulateHingeFold ? FoldState.halfOpened : _currentPosture.foldState;

  bool get _effectiveSeparating =>
      _simulateHingeFold ? true : _currentPosture.isSeparating;

  bool get _isSplitMode {
    if (_simulateTabletLandscape) return true;
    return _effectiveFoldState == FoldState.halfOpened ||
        _effectiveSeparating ||
        _currentPosture.displayAreas.length >= 2;
  }

  bool get _isVerticalHinge {
    if (_simulateTabletLandscape) return true;
    if (_simulateHingeFold && _overrideSimulatedVertical != null) {
      return _overrideSimulatedVertical!;
    }
    if (_currentPosture.hasHinge) {
      return _currentPosture.isVerticalHinge;
    }
    return _currentPosture.orientation == PostureOrientation.landscape;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Spans edge-to-edge so hinge alignment is pixel-perfect with physical hardware
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (_isSplitMode) {
            if (_viewMode == DisplayViewMode.combinedWide) {
              return _buildCombinedWideLayout(constraints);
            }
            return _buildDualPaneLayout(constraints);
          }
          return _buildSinglePaneLayout(constraints);
        },
      ),
    );
  }

  // ===========================================================================
  // 1. Dual-Pane Split Layout (Accurately positioned using native display regions)
  // ===========================================================================
  Widget _buildDualPaneLayout(BoxConstraints constraints) {
    final isVertical = _isVerticalHinge;
    final hasNativeRegions = _currentPosture.displayAreas.length >= 2;

    // Use native hinge dimensions if available, otherwise 24dp for simulation
    final double hingeThickness = _currentPosture.hasHinge
        ? (isVertical
              ? (_currentPosture.hingeBounds?.width ?? 24.0)
              : (_currentPosture.hingeBounds?.height ?? 24.0))
        : 24.0;

    // Calculate exact pane sizes taking into account side panels & hinge
    double pane1Size;

    if (hasNativeRegions && !_simulateHingeFold && !_simulateTabletLandscape) {
      // Use exact hardware-measured region sizes from native platform!
      if (isVertical) {
        pane1Size = _currentPosture.displayAreas[0].width;
      } else {
        pane1Size = _currentPosture.displayAreas[0].height;
      }
    } else {
      // Fallback or simulated calculation (takes into account side panel if detected)
      final sidePanelSize = isVertical
          ? (_currentPosture.sidePanel?.width ?? 0.0)
          : (_currentPosture.sidePanel?.height ?? 0.0);
      final totalAvailable =
          (isVertical ? constraints.maxWidth : constraints.maxHeight) -
          sidePanelSize -
          hingeThickness;
      pane1Size = (totalAvailable / 2.0).clamp(0.0, double.infinity);
    }

    final paneA = _PaneContainer(
      title: 'PANE 1 • PRIMARY VIEWPORT',
      color: Colors.indigo,
      child: _buildPaneAContent(isVertical),
    );

    final hinge = _HingeIndicator(
      isVertical: isVertical,
      thickness: hingeThickness,
      hingeBounds: _currentPosture.hingeBounds,
      isSimulated: _simulateHingeFold || _simulateTabletLandscape,
    );

    final paneB = _PaneContainer(
      title: isVertical
          ? 'PANE 2 • SECONDARY DISPLAY'
          : 'PANE 2 • TABLETOP CONTROLS',
      color: Colors.teal,
      child: _buildPaneBContent(isVertical),
    );

    if (isVertical) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left pane takes exact width up to hinge
          SizedBox(width: pane1Size, child: paneA),
          // Hinge rendered at its exact hardware location
          hinge,
          // Right pane fills ALL remaining space on the right side
          Expanded(child: paneB),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top pane takes exact height up to hinge
          SizedBox(height: pane1Size, child: paneA),
          // Hinge rendered at its exact hardware location
          hinge,
          // Bottom pane fills ALL remaining space at the bottom
          Expanded(child: paneB),
        ],
      );
    }
  }

  // ===========================================================================
  // 2. Combined / Wide Canvas Layout ("show a wide thing" spanning both screens)
  // ===========================================================================
  Widget _buildCombinedWideLayout(BoxConstraints constraints) {
    final isVertical = _isVerticalHinge;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.indigo.shade900.withValues(alpha: 0.35),
            Colors.teal.shade900.withValues(alpha: 0.35),
          ],
        ),
        border: Border.all(color: Colors.indigoAccent.withValues(alpha: 0.3)),
      ),
      child: Stack(
        children: [
          // If a physical hinge is present, show a subtle crease guide overlay
          if (_currentPosture.hasHinge)
            Positioned(
              left: isVertical ? _currentPosture.hingeBounds!.left : 0,
              top: isVertical ? 0 : _currentPosture.hingeBounds!.top,
              width: isVertical ? _currentPosture.hingeBounds!.width : null,
              right: isVertical ? null : 0,
              height: isVertical ? null : _currentPosture.hingeBounds!.height,
              bottom: isVertical ? 0 : null,
              child: Container(
                color: Colors.amber.withValues(alpha: 0.08),
                child: Center(
                  child: RotatedBox(
                    quarterTurns: isVertical ? 3 : 0,
                    child: const Text(
                      'HINGE CREASE (COMBINED CANVAS)',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.amberAccent,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Spanned Wide Content filling the entire combined display
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildAppHeader(compact: false),
                  const SizedBox(height: 16),
                  _buildViewModeSelector(),
                  const SizedBox(height: 16),
                  _buildWideCanvasBanner(),
                  const SizedBox(height: 16),
                  _buildTelemetryCards(compact: false),
                  const SizedBox(height: 16),
                  _buildRegionsListCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. Single-Pane Layout (Flat / Standard continuous screen)
  // ===========================================================================
  Widget _buildSinglePaneLayout(BoxConstraints constraints) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAppHeader(),
            const SizedBox(height: 16),
            if (_error != null) _buildErrorCard(),
            _buildPostureStatusBanner(isSplit: false),
            const SizedBox(height: 16),
            _buildTelemetryCards(),
            const SizedBox(height: 16),
            _buildSimulationCard(isSplit: false),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Content inside Pane 1
  // ===========================================================================
  Widget _buildPaneAContent(bool isVertical) {
    return SafeArea(
      right: !isVertical,
      bottom: isVertical,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAppHeader(compact: true),
            const SizedBox(height: 10),
            _buildViewModeSelector(),
            const SizedBox(height: 10),
            if (_error != null) _buildErrorCard(),
            _buildPostureStatusBanner(isSplit: true),
            const SizedBox(height: 12),
            _buildTelemetryCards(compact: true),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Content inside Pane 2
  // ===========================================================================
  Widget _buildPaneBContent(bool isVerticalHinge) {
    return SafeArea(
      left: !isVerticalHinge,
      top: isVerticalHinge,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHingeDetailsCard(isVerticalHinge),
            const SizedBox(height: 12),
            _buildRegionsListCard(),
            const SizedBox(height: 12),
            _buildSimulationCard(isSplit: true),
            const SizedBox(height: 12),
            _buildQuickActions(),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Widgets: Header, View Mode Switcher, Telemetry, and Regions
  // ===========================================================================

  Widget _buildViewModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () =>
                  setState(() => _viewMode = DisplayViewMode.splitPanels),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _viewMode == DisplayViewMode.splitPanels
                      ? Colors.indigo.withValues(alpha: 0.5)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.splitscreen,
                      size: 15,
                      color: _viewMode == DisplayViewMode.splitPanels
                          ? Colors.white
                          : Colors.white54,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Split Panels',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _viewMode == DisplayViewMode.splitPanels
                            ? Colors.white
                            : Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () =>
                  setState(() => _viewMode = DisplayViewMode.combinedWide),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _viewMode == DisplayViewMode.combinedWide
                      ? Colors.teal.withValues(alpha: 0.5)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.panorama_horizontal,
                      size: 15,
                      color: _viewMode == DisplayViewMode.combinedWide
                          ? Colors.white
                          : Colors.white54,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Combined Wide',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _viewMode == DisplayViewMode.combinedWide
                            ? Colors.white
                            : Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideCanvasBanner() {
    final wide = _currentPosture.wideArea;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.aspect_ratio,
                color: Colors.tealAccent,
                size: 22,
              ),
              const SizedBox(width: 10),
              const Text(
                'COMBINED WIDE DISPLAY CANVAS',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.tealAccent,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${wide.width.toStringAsFixed(0)} × ${wide.height.toStringAsFixed(0)} dp',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: Colors.tealAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'This wide layout spans across all physical display panels while excluding and respecting the side panel. Ideal for maps, panoramic media, and wide multi-column dashboards.',
            style: TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionsListCard() {
    final areas = _currentPosture.displayAreas;
    final side = _currentPosture.sidePanel;
    final wide = _currentPosture.wideArea;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.view_quilt, size: 16, color: Colors.lightBlueAccent),
              SizedBox(width: 8),
              Text(
                'DETECTED DISPLAY REGIONS & SIZES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Colors.lightBlueAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (areas.isEmpty)
            const Text(
              'No isolated regions reported.',
              style: TextStyle(fontSize: 11, color: Colors.white54),
            )
          else
            ...areas.asMap().entries.map((entry) {
              final idx = entry.key;
              final rect = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: idx == 0
                            ? Colors.indigoAccent
                            : Colors.tealAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Panel ${idx + 1}:',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${rect.width.toStringAsFixed(1)} × ${rect.height.toStringAsFixed(1)} dp  (L: ${rect.left.toStringAsFixed(0)}, T: ${rect.top.toStringAsFixed(0)})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          if (side != null) ...[
            const Divider(height: 12, color: Colors.white10),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.amberAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Side Panel:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.amberAccent,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${side.width.toStringAsFixed(1)} × ${side.height.toStringAsFixed(1)} dp  (L: ${side.left.toStringAsFixed(0)})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 12, color: Colors.white10),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.greenAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Combined Wide:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.greenAccent,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${wide.width.toStringAsFixed(1)} × ${wide.height.toStringAsFixed(1)} dp',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppHeader({bool compact = false}) {
    return Row(
      children: [
        Icon(
          Icons.devices_fold,
          color: Colors.indigoAccent.shade100,
          size: compact ? 20 : 26,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              Text(
                'Display Posture',
                style: TextStyle(
                  fontSize: compact ? 15 : 19,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.indigoAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getDeviceIcon(_currentPosture.deviceType),
                      size: 11,
                      color: Colors.indigoAccent.shade100,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _currentPosture.deviceType.displayName,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.indigoAccent.shade100,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.tealAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${MediaQuery.sizeOf(context).width.toInt()}dp • ${DisplayPostureDetector.sizeClass(context).name.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.tealAccent.shade100,
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh Native Metrics',
          icon: Icon(Icons.refresh, size: compact ? 18 : 22),
          onPressed: _fetchMetrics,
        ),
      ],
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error ?? '',
              style: const TextStyle(fontSize: 11, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostureStatusBanner({required bool isSplit}) {
    final fold = _effectiveFoldState;
    final (IconData icon, String label, Color color) = switch (fold) {
      FoldState.halfOpened => (
        Icons.laptop_chromebook,
        'HALF-OPENED (DUAL-SCREEN POSTURE)',
        Colors.amber,
      ),
      FoldState.flat => (
        Icons.tablet_android,
        'UNFOLDED FLAT CONTINUOUS',
        Colors.greenAccent,
      ),
      FoldState.normal => (
        _currentPosture.orientation == PostureOrientation.landscape
            ? Icons.stay_current_landscape
            : Icons.stay_current_portrait,
        'STANDARD DISPLAY (${_currentPosture.orientation.name.toUpperCase()})',
        Colors.lightBlueAccent,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isSplit
                      ? 'Screen divided into isolated regions around the physical hinge.'
                      : 'Single continuous display active.',
                  style: const TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getDeviceIcon(DeviceType type) {
    return switch (type) {
      DeviceType.iphone => Icons.phone_iphone,
      DeviceType.ipad => Icons.tablet_mac,
      DeviceType.androidPhone => Icons.phone_android,
      DeviceType.androidTablet => Icons.tablet_android,
      DeviceType.mac => Icons.laptop_mac,
      DeviceType.windows => Icons.laptop_windows,
      DeviceType.linux => Icons.terminal,
      DeviceType.other => Icons.devices_other,
    };
  }

  Widget _buildTelemetryCards({bool compact = false}) {
    final m = _metrics;
    final logicalWidth = m != null
        ? (m.widthPx / m.density).toStringAsFixed(0)
        : '--';
    final logicalHeight = m != null
        ? (m.heightPx / m.density).toStringAsFixed(0)
        : '--';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                title: 'DEVICE TYPE',
                value: _currentPosture.deviceType.displayName,
                subtitle: _currentPosture.deviceType.isTablet
                    ? 'Tablet form factor'
                    : (_currentPosture.deviceType.isDesktop
                          ? 'Desktop OS'
                          : 'Mobile form factor'),
                accentColor: Colors.deepPurpleAccent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricTile(
                title: 'ORIENTATION',
                value: _currentPosture.orientation.name.toUpperCase(),
                subtitle:
                    _currentPosture.orientation == PostureOrientation.landscape
                    ? 'Landscape mode'
                    : 'Portrait mode',
                accentColor: Colors.blueAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                title: 'PHYSICAL RESOLUTION',
                value: m != null
                    ? '${m.widthPx} × ${m.heightPx}'
                    : 'Loading...',
                subtitle: 'Hardware pixels',
                accentColor: Colors.tealAccent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricTile(
                title: 'LOGICAL VIEWPORT',
                value: '$logicalWidth × $logicalHeight dp',
                subtitle: m != null
                    ? 'Scale: ${m.density.toStringAsFixed(2)}x'
                    : 'dp points',
                accentColor: Colors.amberAccent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHingeDetailsCard(bool isVerticalHinge) {
    final hinge = _currentPosture.hingeBounds;
    final hingeDesc = hinge != null
        ? '${hinge.width.toStringAsFixed(1)} × ${hinge.height.toStringAsFixed(1)} dp\n(L: ${hinge.left.toStringAsFixed(0)}, T: ${hinge.top.toStringAsFixed(0)})'
        : (_simulateHingeFold ? 'Simulated 24.0 dp' : 'None detected');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.line_weight,
                size: 16,
                color: Colors.amberAccent,
              ),
              const SizedBox(width: 8),
              const Text(
                'HINGE METRICS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Colors.amberAccent,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isVerticalHinge ? 'VERTICAL (BOOK)' : 'HORIZONTAL (LAPTOP)',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.amberAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hingeDesc,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _effectiveSeparating
                ? 'Hinge physically divides screen into separate viewports.'
                : 'Display area is continuous.',
            style: const TextStyle(fontSize: 10, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationCard({required bool isSplit}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.indigo.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigoAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Simulate Hinge Fold',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Test dual-pane behavior on standard phones',
                      style: TextStyle(fontSize: 10, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _simulateHingeFold,
                onChanged: (val) {
                  setState(() {
                    _simulateHingeFold = val;
                  });
                },
              ),
            ],
          ),
          if (_simulateHingeFold) ...[
            const Divider(height: 16, color: Colors.white12),
            Row(
              children: [
                const Text(
                  'Axis:',
                  style: TextStyle(fontSize: 10, color: Colors.white70),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text(
                    'Vertical (Book)',
                    style: TextStyle(fontSize: 10),
                  ),
                  selected: _isVerticalHinge,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _overrideSimulatedVertical = true);
                    }
                  },
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text(
                    'Horizontal (Laptop)',
                    style: TextStyle(fontSize: 10),
                  ),
                  selected: !_isVerticalHinge,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _overrideSimulatedVertical = false);
                    }
                  },
                ),
              ],
            ),
          ],
          const Divider(height: 16, color: Colors.white12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Simulate Tablet (50% / 50%)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Test tablet dual-column layout',
                      style: TextStyle(fontSize: 10, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _simulateTabletLandscape,
                onChanged: (val) =>
                    setState(() => _simulateTabletLandscape = val),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CONTROLS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.sync, size: 14),
                  label: const Text(
                    'Refetch Native Metrics',
                    style: TextStyle(fontSize: 11),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.withValues(alpha: 0.3),
                    foregroundColor: Colors.indigoAccent.shade100,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: _fetchMetrics,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Helper Widgets
// =============================================================================

class _PaneContainer extends StatelessWidget {
  final String title;
  final MaterialColor color;
  final Widget child;

  const _PaneContainer({
    required this.title,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: color.withValues(alpha: 0.2),
            child: Row(
              children: [
                Icon(Icons.dashboard_outlined, size: 13, color: color.shade100),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: color.shade100,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _HingeIndicator extends StatelessWidget {
  final bool isVertical;
  final double thickness;
  final PostureRect? hingeBounds;
  final bool isSimulated;

  const _HingeIndicator({
    required this.isVertical,
    required this.thickness,
    required this.hingeBounds,
    required this.isSimulated,
  });

  @override
  Widget build(BuildContext context) {
    final label = isSimulated
        ? 'SIMULATED HINGE • ${thickness.toStringAsFixed(0)}dp'
        : 'HARDWARE HINGE • ${thickness.toStringAsFixed(0)}dp';

    return Container(
      width: isVertical ? thickness : double.infinity,
      height: isVertical ? double.infinity : thickness,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: isVertical ? Alignment.centerLeft : Alignment.topCenter,
          end: isVertical ? Alignment.centerRight : Alignment.bottomCenter,
          colors: [
            Colors.amber.withValues(alpha: 0.1),
            Colors.amber.withValues(alpha: 0.35),
            Colors.amber.withValues(alpha: 0.1),
          ],
        ),
        border: Border(
          left: isVertical
              ? BorderSide(color: Colors.amber.withValues(alpha: 0.5), width: 1)
              : BorderSide.none,
          right: isVertical
              ? BorderSide(color: Colors.amber.withValues(alpha: 0.5), width: 1)
              : BorderSide.none,
          top: !isVertical
              ? BorderSide(color: Colors.amber.withValues(alpha: 0.5), width: 1)
              : BorderSide.none,
          bottom: !isVertical
              ? BorderSide(color: Colors.amber.withValues(alpha: 0.5), width: 1)
              : BorderSide.none,
        ),
      ),
      alignment: Alignment.center,
      child: RotatedBox(
        quarterTurns: isVertical ? 3 : 0,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.unfold_less,
              size: 11,
              color: Colors.amberAccent.shade100,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: Colors.amberAccent.shade100,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color accentColor;

  const _MetricTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white54,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 9.5, color: Colors.white38),
          ),
        ],
      ),
    );
  }
}

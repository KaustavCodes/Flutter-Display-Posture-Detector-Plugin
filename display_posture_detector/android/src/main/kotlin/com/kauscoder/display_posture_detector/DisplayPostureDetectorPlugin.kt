package com.kauscoder.display_posture_detector

import android.app.Activity
import android.content.ComponentCallbacks
import android.content.res.Configuration
import android.graphics.Rect
import android.os.Build
import android.view.WindowInsets
import androidx.window.layout.FoldingFeature
import androidx.window.layout.WindowInfoTracker
import androidx.window.layout.WindowMetricsCalculator
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

class DisplayPostureDetectorPlugin : FlutterPlugin, MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler, ActivityAware {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var activity: Activity? = null
    private var eventSink: EventChannel.EventSink? = null
    private var windowScope: CoroutineScope? = null

    private var lastFoldState: String = "NORMAL"
    private var lastIsSeparating: Boolean = false
    private var lastHingeBoundsPx: Rect? = null

    private val configCallback = object : ComponentCallbacks {
        override fun onConfigurationChanged(newConfig: Configuration) {
            emitCurrentPosture()
        }
        override fun onLowMemory() {}
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, "com.kauscoder.display_posture/methods")
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, "com.kauscoder.display_posture/events")
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "getMetrics") {
            val currentActivity = activity
            if (currentActivity == null) {
                result.error("NO_ACTIVITY", "Activity is not attached", null)
                return
            }

            val windowMetrics = WindowMetricsCalculator.getOrCreate()
                .computeCurrentWindowMetrics(currentActivity)
            val bounds = windowMetrics.bounds
            val density = currentActivity.resources.displayMetrics.density
            val orientation = getOrientationString(currentActivity, bounds.width(), bounds.height())
            val isTablet = (currentActivity.resources.configuration.screenLayout and Configuration.SCREENLAYOUT_SIZE_MASK) >= Configuration.SCREENLAYOUT_SIZE_LARGE
            val deviceType = if (isTablet) "ANDROID_TABLET" else "ANDROID_PHONE"

            result.success(
                mapOf(
                    "widthPx" to bounds.width(),
                    "heightPx" to bounds.height(),
                    "density" to density.toDouble(),
                    "orientation" to orientation,
                    "deviceType" to deviceType
                )
            )
        } else {
            result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        startTracking()
    }

    override fun onCancel(arguments: Any?) {
        stopTracking()
        eventSink = null
    }

    private fun startTracking() {
        val currentActivity = activity ?: return
        stopTracking()

        currentActivity.registerComponentCallbacks(configCallback)
        windowScope = CoroutineScope(Dispatchers.Main + SupervisorJob())

        emitCurrentPosture()

        windowScope?.launch {
            WindowInfoTracker.getOrCreate(currentActivity)
                .windowLayoutInfo(currentActivity)
                .collect { layoutInfo ->
                    val foldingFeature = layoutInfo.displayFeatures
                        .filterIsInstance<FoldingFeature>()
                        .firstOrNull()

                    lastFoldState = when (foldingFeature?.state) {
                        FoldingFeature.State.FLAT -> "FLAT"
                        FoldingFeature.State.HALF_OPENED -> "HALF_OPENED"
                        else -> "NORMAL"
                    }
                    lastIsSeparating = foldingFeature?.isSeparating ?: false
                    lastHingeBoundsPx = foldingFeature?.bounds

                    emitCurrentPosture()
                }
        }
    }

    private fun stopTracking() {
        windowScope?.cancel()
        windowScope = null
        try {
            activity?.unregisterComponentCallbacks(configCallback)
        } catch (_: Exception) {}
    }

    private fun emitCurrentPosture() {
        val currentActivity = activity ?: return
        val sink = eventSink ?: return

        val windowMetrics = WindowMetricsCalculator.getOrCreate()
            .computeCurrentWindowMetrics(currentActivity)
        val bounds = windowMetrics.bounds
        val density = currentActivity.resources.displayMetrics.density.toDouble()

        // Subtract Android system status/navigation bars & display cutouts to get true usable safe area
        var insetLeftPx = 0
        var insetTopPx = 0
        var insetRightPx = 0
        var insetBottomPx = 0

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val windowInsets = currentActivity.window?.decorView?.rootWindowInsets
            if (windowInsets != null) {
                val bars = windowInsets.getInsets(
                    WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout()
                )
                insetLeftPx = bars.left
                insetTopPx = bars.top
                insetRightPx = bars.right
                insetBottomPx = bars.bottom
            }
        }

        val safeLeftDp = insetLeftPx / density
        val safeTopDp = insetTopPx / density
        val safeRightDp = (bounds.width() - insetRightPx) / density
        val safeBottomDp = (bounds.height() - insetBottomPx) / density
        val safeWidthDp = (safeRightDp - safeLeftDp).coerceAtLeast(0.0)
        val safeHeightDp = (safeBottomDp - safeTopDp).coerceAtLeast(0.0)

        val hingePx = lastHingeBoundsPx
        var hingeMap: Map<String, Double>? = null
        val displayAreas = mutableListOf<Map<String, Double>>()
        val orientation = getOrientationString(currentActivity, bounds.width(), bounds.height())
        val isTablet = (currentActivity.resources.configuration.screenLayout and Configuration.SCREENLAYOUT_SIZE_MASK) >= Configuration.SCREENLAYOUT_SIZE_LARGE

        if (hingePx != null && (lastIsSeparating || lastFoldState != "NORMAL")) {
            val hLeft = hingePx.left / density
            val hTop = hingePx.top / density
            val hRight = hingePx.right / density
            val hBottom = hingePx.bottom / density
            val hWidth = hRight - hLeft
            val hHeight = hBottom - hTop

            hingeMap = mapOf(
                "left" to hLeft,
                "top" to hTop,
                "width" to hWidth,
                "height" to hHeight
            )

            val totalWidthDp = bounds.width() / density
            val totalHeightDp = bounds.height() / density

            if (hHeight >= hWidth) {
                // Vertical hinge (Left & Right panes)
                val leftPaneWidth = hLeft.coerceAtLeast(0.0)
                val rightPaneWidth = (totalWidthDp - hRight).coerceAtLeast(0.0)

                displayAreas.add(
                    mapOf("left" to 0.0, "top" to 0.0, "width" to leftPaneWidth, "height" to totalHeightDp)
                )
                displayAreas.add(
                    mapOf("left" to hRight, "top" to 0.0, "width" to rightPaneWidth, "height" to totalHeightDp)
                )
            } else {
                // Horizontal hinge (Top & Bottom panes)
                val topPaneHeight = hTop.coerceAtLeast(0.0)
                val bottomPaneHeight = (totalHeightDp - hBottom).coerceAtLeast(0.0)

                displayAreas.add(
                    mapOf("left" to 0.0, "top" to 0.0, "width" to totalWidthDp, "height" to topPaneHeight)
                )
                displayAreas.add(
                    mapOf("left" to 0.0, "top" to hBottom, "width" to totalWidthDp, "height" to bottomPaneHeight)
                )
            }
        } else if (isTablet && orientation == "LANDSCAPE") {
            // Tablet landscape mode: 2 panels (50% / 50%)
            val halfWidth = safeWidthDp / 2.0
            displayAreas.add(
                mapOf("left" to safeLeftDp, "top" to safeTopDp, "width" to halfWidth, "height" to safeHeightDp)
            )
            displayAreas.add(
                mapOf("left" to safeLeftDp + halfWidth, "top" to safeTopDp, "width" to halfWidth, "height" to safeHeightDp)
            )
        } else {
            // Single display area
            displayAreas.add(
                mapOf("left" to safeLeftDp, "top" to safeTopDp, "width" to safeWidthDp, "height" to safeHeightDp)
            )
        }

        // Side panel detection (system edge insets, notification/side dock panel)
        var sidePanel: Map<String, Double>? = null
        val rightInsetDp = insetRightPx / density
        val leftInsetDp = insetLeftPx / density
        if (rightInsetDp > 20.0) {
            sidePanel = mapOf(
                "left" to safeRightDp,
                "top" to 0.0,
                "width" to rightInsetDp,
                "height" to (bounds.height() / density)
            )
        } else if (leftInsetDp > 20.0) {
            sidePanel = mapOf(
                "left" to 0.0,
                "top" to 0.0,
                "width" to leftInsetDp,
                "height" to (bounds.height() / density)
            )
        }

        val deviceType = if (isTablet) "ANDROID_TABLET" else "ANDROID_PHONE"

        val payload = mutableMapOf<String, Any>(
            "foldState" to lastFoldState,
            "isSeparating" to lastIsSeparating,
            "orientation" to orientation,
            "displayAreas" to displayAreas,
            "combinedArea" to mapOf(
                "left" to safeLeftDp,
                "top" to safeTopDp,
                "width" to safeWidthDp,
                "height" to safeHeightDp
            ),
            "isTablet" to isTablet,
            "deviceType" to deviceType
        )
        if (hingeMap != null) {
            payload["hingeBounds"] = hingeMap
        }
        if (sidePanel != null) {
            payload["sidePanel"] = sidePanel
        }

        sink.success(payload)
    }

    private fun getOrientationString(act: Activity, width: Int, height: Int): String {
        return if (width > height || act.resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE) {
            "LANDSCAPE"
        } else {
            "PORTRAIT"
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        if (eventSink != null) startTracking()
    }

    override fun onDetachedFromActivityForConfigChanges() {
        stopTracking()
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        if (eventSink != null) startTracking()
    }

    override fun onDetachedFromActivity() {
        stopTracking()
        activity = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopTracking()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }
}

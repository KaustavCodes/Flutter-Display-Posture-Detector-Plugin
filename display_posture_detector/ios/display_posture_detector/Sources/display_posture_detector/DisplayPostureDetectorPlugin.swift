import Flutter
import UIKit

private class PostureObserverView: UIView {
    var onLayoutOrFoldChanged: (() -> Void)?
    private var verticalBarTraitRegistration: Any?

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if superview != nil {
            #if compiler(>=6.0)
            if #available(iOS 27.1, *), verticalBarTraitRegistration == nil {
                verticalBarTraitRegistration = registerForTraitChanges(
                    UITraitCollection.systemTraitsAffectingVerticalBarEdge
                ) { [weak self] (_: PostureObserverView, _: UITraitCollection) in
                    self?.onLayoutOrFoldChanged?()
                }
            }
            #endif
        } else {
            #if compiler(>=6.0)
            if #available(iOS 17.0, *),
               let registration = verticalBarTraitRegistration as? UITraitChangeRegistration {
                unregisterForTraitChanges(registration)
            }
            #endif
            verticalBarTraitRegistration = nil
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            onLayoutOrFoldChanged?()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayoutOrFoldChanged?()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        onLayoutOrFoldChanged?()
    }
}

private struct PostureState: Equatable {
    let foldState: String
    let isSeparating: Bool
    let orientation: String
    let deviceType: String
    let isTablet: Bool
    let bounds: CGRect
    let safeFrame: CGRect
    let hingeRect: CGRect?
    let sidePanel: [String: Double]?
    let displayAreas: [[String: Double]]
    let occlusionAreas: [[String: Double]]
}

public class DisplayPostureDetectorPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private weak var observerView: PostureObserverView?
    private var lastEmittedState: PostureState?
    private var emitScheduled = false
    private var isObservingLifecycle = false
    private var hingeInteraction: Any?
    private var latestHingeStatusRaw: Int?

    deinit {
        stopObservingLifecycleNotifications()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(
            name: "com.kauscoder.display_posture/methods",
            binaryMessenger: registrar.messenger()
        )
        let eventChannel = FlutterEventChannel(
            name: "com.kauscoder.display_posture/events",
            binaryMessenger: registrar.messenger()
        )

        let instance = DisplayPostureDetectorPlugin()
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getMetrics":
            guard let rootView = getActiveRootView() else {
                result(FlutterError(code: "NO_VIEW", message: "Active root UIView not found", details: nil))
                return
            }

            let bounds = rootView.bounds
            let scale = rootView.traitCollection.displayScale > 0 ? rootView.traitCollection.displayScale : 3.0
            let orientation = bounds.width > bounds.height ? "LANDSCAPE" : "PORTRAIT"
            let deviceType = getDeviceType(for: rootView)

            result([
                "widthPx": Int(bounds.width * scale),
                "heightPx": Int(bounds.height * scale),
                "density": Double(scale),
                "orientation": orientation,
                "deviceType": deviceType
            ])
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        self.lastEmittedState = nil
        startObservingLifecycleNotifications()
        attachObserverViewIfNeeded()
        emitCurrentPosture()
        if observerView?.window == nil {
            scheduleEmit()
        }
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        stopObservingLifecycleNotifications()
        #if compiler(>=6.0)
        if #available(iOS 27.1, *), let interaction = hingeInteraction as? UIInteraction {
            getTargetView()?.removeInteraction(interaction)
        }
        #endif
        latestHingeStatusRaw = nil
        hingeInteraction = nil
        observerView?.removeFromSuperview()
        observerView = nil
        eventSink = nil
        lastEmittedState = nil
        emitScheduled = false
        return nil
    }

    private func startObservingLifecycleNotifications() {
        guard !isObservingLifecycle else { return }
        isObservingLifecycle = true
        let nc = NotificationCenter.default
        nc.addObserver(
            self,
            selector: #selector(handleLifecycleNotification(_:)),
            name: UIWindow.didBecomeKeyNotification,
            object: nil
        )
        nc.addObserver(
            self,
            selector: #selector(handleLifecycleNotification(_:)),
            name: UIWindow.didBecomeVisibleNotification,
            object: nil
        )
        nc.addObserver(
            self,
            selector: #selector(handleLifecycleNotification(_:)),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        if #available(iOS 13.0, *) {
            nc.addObserver(
                self,
                selector: #selector(handleLifecycleNotification(_:)),
                name: UIScene.didActivateNotification,
                object: nil
            )
            nc.addObserver(
                self,
                selector: #selector(handleLifecycleNotification(_:)),
                name: UIScene.willEnterForegroundNotification,
                object: nil
            )
        }
    }

    private func stopObservingLifecycleNotifications() {
        guard isObservingLifecycle else { return }
        isObservingLifecycle = false
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleLifecycleNotification(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.eventSink != nil else { return }
            self.attachObserverViewIfNeeded()
            self.scheduleEmit()
        }
    }

    private func attachObserverViewIfNeeded() {
        guard let rootView = getActiveRootView() else { return }

        if let existing = observerView {
            if existing.superview === rootView {
                return
            }
            #if compiler(>=6.0)
            if #available(iOS 27.1, *), let interaction = hingeInteraction as? UIInteraction {
                existing.superview?.removeInteraction(interaction)
                self.hingeInteraction = nil
            }
            #endif
            existing.removeFromSuperview()
            self.observerView = nil
        }

        let obs = PostureObserverView(frame: rootView.bounds)
        obs.isUserInteractionEnabled = false
        obs.backgroundColor = .clear
        obs.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        obs.onLayoutOrFoldChanged = { [weak self] in
            self?.scheduleEmit()
        }

        rootView.addSubview(obs)
        self.observerView = obs

        #if compiler(>=6.0)
        if #available(iOS 27.1, *) {
            if hingeInteraction == nil {
                let interaction = UIHingeInteraction { [weak self] _, update in
                    guard let self = self else { return }
                    self.latestHingeStatusRaw = update.hinge?.status.rawValue
                    self.scheduleEmit()
                }
                rootView.addInteraction(interaction)
                self.hingeInteraction = interaction
            }
        }
        #endif
    }

    private func scheduleEmit() {
        guard !emitScheduled else { return }
        emitScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.emitScheduled = false
            self.emitCurrentPosture()
        }
    }

    private func getTargetView() -> UIView? {
        if let parent = observerView?.superview {
            return parent
        }
        return getActiveRootView()
    }

    private func emitCurrentPosture() {
        guard let sink = eventSink else { return }
        attachObserverViewIfNeeded()
        guard let targetView = getTargetView() else { return }

        let bounds = targetView.bounds
        guard bounds.width > 0 && bounds.height > 0 else {
            scheduleEmit()
            return
        }
        let safeFrame = targetView.safeAreaLayoutGuide.layoutFrame
        let orientation = bounds.width > bounds.height ? "LANDSCAPE" : "PORTRAIT"

        var foldState = "NORMAL"
        var isSeparating = false
        var hingeRect: CGRect? = nil

        #if compiler(>=6.0)
        if #available(iOS 27.1, *) {
            if let raw = latestHingeStatusRaw, let status = UIHinge.Status(rawValue: raw) {
                switch status {
                case .partiallyOpen:
                    foldState = "HALF_OPENED"
                    isSeparating = true
                case .fullyOpen:
                    foldState = "FLAT"
                    isSeparating = false
                case .closed:
                    foldState = "NORMAL"
                    isSeparating = false
                default:
                    break
                }
            }

            let activeDivisions = targetView.reservedRegions(kind: .division)
            let allDivisions = targetView.reservedRegions(kind: .division, options: [.includeInactive])
            if let fold = activeDivisions.first ?? allDivisions.first {
                hingeRect = fold.frame
                if foldState == "NORMAL" {
                    foldState = fold.isActive ? "HALF_OPENED" : "FLAT"
                    isSeparating = fold.isActive
                }
            } else if targetView.traitCollection.horizontalSizeClass == .regular && foldState == "NORMAL" {
                foldState = "FLAT"
            }
        }
        #endif

        // Fallback if simulator reports a zero-width frame for the division line:
        // The physical hinge is always centered in the full hardware view.bounds (NOT safeFrame)
        if isSeparating && (hingeRect == nil || hingeRect!.isEmpty) {
            if bounds.width > bounds.height {
                hingeRect = CGRect(x: bounds.midX - 10, y: 0, width: 20, height: bounds.height)
            } else {
                hingeRect = CGRect(x: 0, y: bounds.midY - 10, width: bounds.width, height: 20)
            }
        }

        // Compute usable safe render areas on each side of the physical hinge
        var displayAreas: [[String: Double]] = []
        let isTablet = targetView.traitCollection.userInterfaceIdiom == .pad || (orientation == "LANDSCAPE" && bounds.width >= 800)

        if let hRect = hingeRect, (isSeparating || foldState != "NORMAL") {
            let isVerticalHinge = hRect.height >= hRect.width
            if isVerticalHinge {
                // Left Pane: from screen left edge to hinge left edge
                let leftWidth = max(0, hRect.minX - bounds.minX)
                // Right Pane: from hinge right edge all the way to screen right edge (fills entire right screen!)
                let rightWidth = max(0, bounds.maxX - hRect.maxX)

                displayAreas = [
                    rectToMap(CGRect(x: bounds.minX, y: bounds.minY, width: leftWidth, height: bounds.height)),
                    rectToMap(CGRect(x: hRect.maxX, y: bounds.minY, width: rightWidth, height: bounds.height))
                ]
            } else {
                // Top Pane & Bottom Pane (Clamshell / Laptop orientation)
                let topHeight = max(0, hRect.minY - bounds.minY)
                let bottomHeight = max(0, bounds.maxY - hRect.maxY)

                displayAreas = [
                    rectToMap(CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: topHeight)),
                    rectToMap(CGRect(x: bounds.minX, y: hRect.maxY, width: bounds.width, height: bottomHeight))
                ]
            }
        } else if isTablet && orientation == "LANDSCAPE" && bounds.width >= 700 {
            // Tablet landscape mode: 2 panels (50% / 50%) for wide displays
            let halfWidth = bounds.width / 2.0
            displayAreas = [
                rectToMap(CGRect(x: bounds.minX, y: bounds.minY, width: halfWidth, height: bounds.height)),
                rectToMap(CGRect(x: bounds.minX + halfWidth, y: bounds.minY, width: halfWidth, height: bounds.height))
            ]
        } else {
            // Single display area
            displayAreas = [rectToMap(bounds)]
        }

        // Side panel detection using UIKit verticalBarEdge (iOS 27.1+) with strict asymmetric fallback
        // so symmetric notched/Dynamic Island regular iPhone landscape insets do not trigger a false sidePanel.
        var sidePanel: [String: Double]? = nil
        let rightInset = bounds.maxX - safeFrame.maxX
        let leftInset = safeFrame.minX - bounds.minX
        let isRTL = targetView.effectiveUserInterfaceLayoutDirection == .rightToLeft

        var resolvedBarEdge: UIRectEdge? = nil
        #if compiler(>=6.0)
        if #available(iOS 27.1, *) {
            switch targetView.traitCollection.verticalBarEdge {
            case .trailing:
                resolvedBarEdge = isRTL ? .left : .right
            case .leading:
                resolvedBarEdge = isRTL ? .right : .left
            case .unspecified:
                resolvedBarEdge = nil
            @unknown default:
                resolvedBarEdge = nil
            }
        }
        #endif

        if let barEdge = resolvedBarEdge {
            if barEdge == .right && rightInset > 20 {
                sidePanel = [
                    "left": Double(safeFrame.maxX),
                    "top": 0.0,
                    "width": Double(rightInset),
                    "height": Double(bounds.height)
                ]
            } else if barEdge == .left && leftInset > 20 {
                sidePanel = [
                    "left": 0.0,
                    "top": 0.0,
                    "width": Double(leftInset),
                    "height": Double(bounds.height)
                ]
            }
        } else if rightInset > 20 && leftInset <= 20 {
            sidePanel = [
                "left": Double(safeFrame.maxX),
                "top": 0.0,
                "width": Double(rightInset),
                "height": Double(bounds.height)
            ]
        } else if leftInset > 20 && rightInset <= 20 {
            sidePanel = [
                "left": 0.0,
                "top": 0.0,
                "width": Double(leftInset),
                "height": Double(bounds.height)
            ]
        }

        // Occlusion reserved regions (camera cutouts, status clusters, etc.) on iOS 27.1+
        var rawOcclusionRects: [CGRect] = []
        #if compiler(>=6.0)
        if #available(iOS 27.1, *) {
            let activeOcclusions = targetView.reservedRegions(kind: .occlusion)
            for region in activeOcclusions {
                let frame = region.frame.intersection(bounds)
                if !frame.isNull && !frame.isEmpty && frame.width > 0.5 && frame.height > 0.5 {
                    rawOcclusionRects.append(frame)
                }
            }
        }
        #endif
        let occlusionAreas = rawOcclusionRects.sorted { a, b in
            if abs(a.origin.y - b.origin.y) > 0.5 { return a.origin.y < b.origin.y }
            if abs(a.origin.x - b.origin.x) > 0.5 { return a.origin.x < b.origin.x }
            if abs(a.size.width - b.size.width) > 0.5 { return a.size.width < b.size.width }
            return a.size.height < b.size.height
        }.map { rectToMap($0) }

        let deviceType = getDeviceType(for: targetView)

        let currentState = PostureState(
            foldState: foldState,
            isSeparating: isSeparating,
            orientation: orientation,
            deviceType: deviceType,
            isTablet: isTablet,
            bounds: bounds,
            safeFrame: safeFrame,
            hingeRect: hingeRect,
            sidePanel: sidePanel,
            displayAreas: displayAreas,
            occlusionAreas: occlusionAreas
        )

        // Deduplication: Avoid redundant serialization and bridge traffic if state is unchanged
        if currentState == lastEmittedState {
            return
        }
        lastEmittedState = currentState

        var payload: [String: Any] = [
            "foldState": foldState,
            "isSeparating": isSeparating,
            "orientation": orientation,
            "displayAreas": displayAreas,
            "occlusionAreas": occlusionAreas,
            "combinedArea": rectToMap(safeFrame),
            "isTablet": isTablet,
            "deviceType": deviceType
        ]
        if let hRect = hingeRect {
            payload["hingeBounds"] = rectToMap(hRect)
        }
        if let sPanel = sidePanel {
            payload["sidePanel"] = sPanel
        }

        sink(payload)
    }

    private func rectToMap(_ rect: CGRect) -> [String: Double] {
        return [
            "left": Double(rect.origin.x),
            "top": Double(rect.origin.y),
            "width": Double(rect.size.width),
            "height": Double(rect.size.height)
        ]
    }

    private func getActiveRootView() -> UIView? {
        if #available(iOS 13.0, *) {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            for scene in scenes where scene.activationState == .foregroundActive || scene.activationState == .foregroundInactive {
                if let keyWindow = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
                    return keyWindow.rootViewController?.view ?? keyWindow
                }
            }
            for scene in scenes {
                if let keyWindow = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
                    return keyWindow.rootViewController?.view ?? keyWindow
                }
            }
        }
        return UIApplication.shared.delegate?.window??.rootViewController?.view ?? UIApplication.shared.delegate?.window ?? nil
    }

    private func getDeviceType(for view: UIView) -> String {
        #if targetEnvironment(macCatalyst)
        return "MAC"
        #else
        switch view.traitCollection.userInterfaceIdiom {
        case .pad:
            return "IPAD"
        case .phone:
            return "IPHONE"
        case .mac:
            return "MAC"
        default:
            return "OTHER"
        }
        #endif
    }
}

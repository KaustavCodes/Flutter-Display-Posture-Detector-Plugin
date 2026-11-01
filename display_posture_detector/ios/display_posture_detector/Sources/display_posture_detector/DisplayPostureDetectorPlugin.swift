import Flutter
import UIKit

private class PostureObserverView: UIView {
    var onLayoutOrFoldChanged: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayoutOrFoldChanged?()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        onLayoutOrFoldChanged?()
    }
}

public class DisplayPostureDetectorPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private weak var observerView: PostureObserverView?

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
        attachObserverViewIfNeeded()
        emitCurrentPosture()
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        observerView?.removeFromSuperview()
        observerView = nil
        eventSink = nil
        return nil
    }

    private func attachObserverViewIfNeeded() {
        guard observerView == nil, let rootView = getActiveRootView() else { return }

        let obs = PostureObserverView(frame: rootView.bounds)
        obs.isUserInteractionEnabled = false
        obs.backgroundColor = .clear
        obs.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        obs.onLayoutOrFoldChanged = { [weak self] in
            self?.emitCurrentPosture()
        }

        rootView.addSubview(obs)
        self.observerView = obs
    }

    private func emitCurrentPosture() {
        guard let sink = eventSink else { return }
        guard let targetView = observerView ?? getActiveRootView() else { return }

        let bounds = targetView.bounds
        let safeFrame = targetView.safeAreaLayoutGuide.layoutFrame
        let orientation = bounds.width > bounds.height ? "LANDSCAPE" : "PORTRAIT"

        var foldState = "NORMAL"
        var isSeparating = false
        var hingeRect: CGRect? = nil

        #if compiler(>=6.0)
        if #available(iOS 27.1, *) {
            let activeDivisions = targetView.reservedRegions(kind: .division)
            if let activeFold = activeDivisions.first, activeFold.isActive {
                foldState = "HALF_OPENED"
                isSeparating = true
                hingeRect = activeFold.frame
            } else {
                let allDivisions = targetView.reservedRegions(kind: .division, options: [.includeInactive])
                if let inactiveFold = allDivisions.first {
                    foldState = "FLAT"
                    isSeparating = false
                    hingeRect = inactiveFold.frame
                } else if targetView.traitCollection.horizontalSizeClass == .regular {
                    foldState = "FLAT"
                }
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
        } else if isTablet && orientation == "LANDSCAPE" {
            // Tablet landscape mode: 2 panels (50% / 50%)
            let halfWidth = bounds.width / 2.0
            displayAreas = [
                rectToMap(CGRect(x: bounds.minX, y: bounds.minY, width: halfWidth, height: bounds.height)),
                rectToMap(CGRect(x: bounds.minX + halfWidth, y: bounds.minY, width: halfWidth, height: bounds.height))
            ]
        } else {
            // Single display area
            displayAreas = [rectToMap(bounds)]
        }

        // Side panel detection (e.g. right-side status/dock panel on iPhone Duo or notch inset)
        var sidePanel: [String: Double]? = nil
        let rightInset = bounds.maxX - safeFrame.maxX
        let leftInset = safeFrame.minX - bounds.minX
        if rightInset > 20 {
            sidePanel = [
                "left": Double(safeFrame.maxX),
                "top": 0.0,
                "width": Double(rightInset),
                "height": Double(bounds.height)
            ]
        } else if leftInset > 20 {
            sidePanel = [
                "left": 0.0,
                "top": 0.0,
                "width": Double(leftInset),
                "height": Double(bounds.height)
            ]
        }

        let deviceType = getDeviceType(for: targetView)

        var payload: [String: Any] = [
            "foldState": foldState,
            "isSeparating": isSeparating,
            "orientation": orientation,
            "displayAreas": displayAreas,
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
        }
        return UIApplication.shared.delegate?.window??.rootViewController?.view
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

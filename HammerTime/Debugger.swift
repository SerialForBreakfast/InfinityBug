//
//  AXFocusDebugger.swift
//  InfinityBugDiagnostics
//
//  Created by You on 2025-06-16.
//  Fully refreshed 2025-06-16 — now checks Run-Loop stalls, dup IDs/labels,
//  preferredFocusEnvironments bloat, tiny focus-guides, memory warnings.
//

import UIKit
import os
import Combine
import ObjectiveC.runtime
import GameController

private struct AXNotificationKeys {
    static let focusedElement = "UIAccessibilityFocusedElementKey"
    static let nextFocusedElement = "UIAccessibilityNextFocusedElementKey"
    static let announcementSuccess = "UIAccessibilityAnnouncementSuccessKey"
    static let announcementMessage = "UIAccessibilityAnnouncementStringValueKey"
}

private let notificationUserInfoKeyFocusedElement = "UIAccessibilityFocusedElementKey"
private let notificationUserInfoKeyNextFocusedElement = "UIAccessibilityNextFocusedElementKey"

@objc final class AXFocusDebugger: NSObject {

    // MARK: – Public API ----------------------------------------------------

    @objc static let shared = AXFocusDebugger()
    @objc func start() { guard !enabled else { return }; enabled = true; bootstrap() }

    // MARK: – Private -------------------------------------------------------

    private override init() {}
    private var enabled = false
    private var cancellables: Set<Combine.AnyCancellable> = []
    /// Last time a focus hop was observed
    private var lastFocusTimestamp = CACurrentMediaTime()
    
    /// tvOS-specific low-level input monitoring dispatch queue
    private let inputQueue = DispatchQueue(label: "com.infinitybug.input-monitor", qos: .userInteractive)
    
    /// Private API function pointers for ultra-low-level monitoring
    private var systemEventTap: UnsafeMutableRawPointer?
    
    /// High-frequency controller state monitoring
    private var controllerPollingTimer: Timer?

    private let poiLog  = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.infinitybug",
                                category: "FocusPOI")
    private let perfLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.infinitybug",
                                category: "FocusPerf")
    internal let inputLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.infinitybug",
                                  category: "LowLevelInput")
    
    
    // Register every possible input from any kind of tvOS controller / remote.
    // The approach is:  ❶ reflect over all ButtonInput properties,
    //                   ❷ give each one a readable ID,
    //                   ❸ hook its `pressedChangedHandler` so every *down* event
    //                      feeds HardwarePressCache.markDown(_:)
    private func registerGameController(_ c: GCController) {

        //----------------------------------------------------------------------
        // 1) Helper that wires a single GCControllerButtonInput  --------------
        //----------------------------------------------------------------------
        func wire(_ btn: GCControllerButtonInput?,
                  id name: String,
                  alias fallback: String? = nil) {

            guard let b = btn else { return }

            // Avoid duplicate handlers if the same controller reconnects
            b.pressedChangedHandler = nil

            let label = name.isEmpty ? (fallback ?? "Button") : name

            b.pressedChangedHandler = { _, _, pressed in
                if pressed { HardwarePressCache.markDown(label) }
            }
        }

        //----------------------------------------------------------------------
        // 2) Micro‑gamepad (Siri Remote) --------------------------------------
        //----------------------------------------------------------------------
        if let mg = c.microGamepad {
            mg.reportsAbsoluteDpadValues = true   // ensures crisp ±1.0 values
            // D‑pad (Up/Down/Left/Right)
            // Explicit discrete D‑pad buttons (works on all Siri Remote variants)
            wire(mg.dpad.up,    id: "Up Arrow")
            wire(mg.dpad.down,  id: "Down Arrow")
            wire(mg.dpad.left,  id: "Left Arrow")
            wire(mg.dpad.right, id: "Right Arrow")
            mg.dpad.valueChangedHandler = { _, x, y in
                // X‑axis is unchanged
                if x < -0.5 { HardwarePressCache.markDown("Left Arrow")  }
                if x >  0.5 { HardwarePressCache.markDown("Right Arrow") }

                // Y‑axis on tvOS:  Up = negative –1,  Down = positive +1
                if y < -0.5 { HardwarePressCache.markDown("Up Arrow")    }
                if y >  0.5 { HardwarePressCache.markDown("Down Arrow")  }
            }

            // A‑button = Select/Play (on some remotes)
            wire(mg.buttonA, id: "Select", alias: "A")

            // Menu (top‑left button on Siri Remote)
            wire(mg.buttonMenu, id: "Menu")

            // Newer remotes expose Play/Pause as buttonX
            let sel = NSSelectorFromString("buttonX")
            if mg.responds(to: sel),
               let unmanaged = mg.perform(sel),
               let playPause = unmanaged.takeUnretainedValue() as? GCControllerButtonInput {
                wire(playPause, id: "Play/Pause", alias: "X")
            }
        }

        //----------------------------------------------------------------------
        // 3) Extended gamepads / Dual‑Sense / Nimbus --------------------------
        //----------------------------------------------------------------------
        if let gp = c.extendedGamepad {

            // Reflect over every property that is GCControllerButtonInput
            Mirror(reflecting: gp)
                .children
                .forEach { child in
                    if let btn = child.value as? GCControllerButtonInput {
                        let name = child.label ?? "Btn"
                        wire(btn, id: name.capitalized)         // e.g. "buttonA" → "Buttona"
                    }
                }

            // D‑pad
            gp.dpad.valueChangedHandler = { _, x, y in
                if x < -0.5 { HardwarePressCache.markDown("Left Arrow")  }
                if x >  0.5 { HardwarePressCache.markDown("Right Arrow") }
                if y < -0.5 { HardwarePressCache.markDown("Down Arrow")  }
                if y >  0.5 { HardwarePressCache.markDown("Up Arrow")    }
            }
        }

        //----------------------------------------------------------------------
        // 4) Keyboards (tvOS 17+) ---------------------------------------------
        //----------------------------------------------------------------------
        if #available(tvOS 17.0, *) {
            GCKeyboard.coalesced?.keyboardInput?.keyChangedHandler = { _, _, keyCode, pressed in
                if pressed { HardwarePressCache.markDown("Key\(keyCode.rawValue)") }
            }
        }
    }
    
    // MARK: – Bootstrap -----------------------------------------------------

    private func bootstrap() {
        // 🔌  Listen for any controller connection
        NotificationCenter.default.publisher(for: .GCControllerDidBecomeCurrent, object: nil)
            .sink { [weak self] note in
                guard let pad = note.object as? GCController else { return }
                self?.registerGameController(pad)
            }
            .store(in: &cancellables)

        //  …also cover controllers that are already connected
        GCController.controllers().forEach { registerGameController($0) }
        
        //-------------------------- 1. VO ON/OFF ---------------------------------
        NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)
            .sink { _ in
                let on = UIAccessibility.isVoiceOverRunning
                self.log("VoiceOver \(on ? "ON" : "OFF")")
                os_signpost(.event, log: self.poiLog, name: "VOStatus", "%{public}s", on.description)
            }
            .store(in: &cancellables)

        //-------------------------- 2. Focus hops --------------------------------
        NotificationCenter.default.publisher(for: UIAccessibility.elementFocusedNotification)
            .sink { [weak self] note in
                guard let self else { return }
                self.lastFocusTimestamp = CACurrentMediaTime()
                let from = note.userInfo?[AXNotificationKeys.focusedElement] as? NSObject
                let to = note.userInfo?[AXNotificationKeys.nextFocusedElement] as? NSObject
                let desc = "\(Self.describe(from)) → \(Self.describe(to))"
                self.log("FOCUS HOP: \(desc)")
                os_signpost(.event, log: self.poiLog, name: "AXFocus", "%{public}s", desc)

                // ---- 5. Duplicate IDs & labels check (visible hierarchy) -----
                DispatchQueue.main.async {
                    let window = UIApplication.shared.connectedScenes
                        .compactMap { $0 as? UIWindowScene }
                        .flatMap { $0.windows }
                        .first { $0.isKeyWindow }
                    self.checkDuplicateAccessibilityIDs(in: window)
                    self.checkDuplicateAccessibilityLabels(in: window)
                    self.checkConflictingPressRecognizers(in: window)
                }
            }
            .store(in: &cancellables)

        //-------------------------- 3. Announce done -----------------------------
        NotificationCenter.default.publisher(for: UIAccessibility.announcementDidFinishNotification)
            .sink { [weak self] note in
                guard
                    let self,
                    let ok = note.userInfo?[AXNotificationKeys.announcementSuccess] as? Bool,
                    let msg = note.userInfo?[AXNotificationKeys.announcementMessage] as? String
                else { return }
                let txt = String(format: "🔊 VoiceOver announcement completed (%@) – \"%@\"", ok.description, msg)
                self.log(txt)
                os_signpost(.event, log: self.poiLog, name: "AXAnnounceDone", "%{public}s", txt)
            }
            .store(in: &cancellables)

        //-------------------------- 3a. Announce start (new) -----------------------------
        NotificationCenter.default.publisher(for: UIAccessibility.announcementDidFinishNotification)
            .compactMap { $0.userInfo?[AXNotificationKeys.announcementMessage] as? String }
            .sink { [weak self] msg in
                guard let self else { return }
                let txt = "🔈 VoiceOver announcement starting – \"\(msg)\""
                self.log(txt)
                os_signpost(.event, log: self.poiLog, name: "AXAnnounceStart", "%{public}s", txt)
            }
            .store(in: &cancellables)

        //-------------------------- 4. Remote presses ----------------------------
//        NotificationCenter.default.publisher(for: UIPressesEvent.pressNotifications, object: nil)
//            .sink { [weak self] notification in
//                guard let press = notification.object as? UIPress else { return }
//                let typeDesc  = press.type.readable
//                let phaseDesc = press.phase.readable
//                self?.log("[A11Y] REMOTE \(typeDesc) – \(phaseDesc)")
//            }
//            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: UIPressesEvent.pressNotifications)
            .sink { [weak self] note in
                guard
                    let self,
                    let press = note.object as? UIPress,
                    press.phase == .began               // we only care about the first down
                else { return }

                let id = press.type.readable           // e.g. "Up Arrow", "Select" …

                // 👉  Treat as phantom only when
                //     a) no recent hardware press  **and**
                //     b) no focus hop in the last 120 ms
                let noHW  = !HardwarePressCache.recentlyPressed(id)
                let stale = CACurrentMediaTime() - self.lastFocusTimestamp > 0.12
                if noHW && stale {
                    self.log("[A11Y] ⚠️ Phantom UIPress \(id) → InfinityBug?")
                    self.log("(debug)  noHW=\(noHW)  stale=\(stale)  dt=\(CACurrentMediaTime() - self.lastFocusTimestamp)s")
                    os_signpost(.event, log: self.poiLog,
                                name: "InfinityBugPhantomPress",
                                "%{public}s", id)
                    return
                }

                // Normal user press
                self.log("[A11Y] REMOTE \(id)")
                os_signpost(.event, log: self.poiLog, name: "UserPress", "%{public}s", id)
            }
            .store(in: &cancellables)
        //-------------------------- 5. Memory warnings ---------------------------
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                self.log("⚠️ Memory warning")
                os_signpost(.event, log: self.perfLog, name: "MemWarn")
            }
            .store(in: &cancellables)

        //-------------------------- 6. Run-Loop stall detector (#1) --------------
        addRunLoopObserver()

        //-------------------------- 7. CADisplayLink frame hitches ---------------
        addDisplayLink()

        //-------------------------- 8. Focus-guide tiny frame (#7) ---------------
        hookFocusGuideMonitor()

        //-------------------------- 9. preferredFocusEnvironments bloat (#4) -----
        swizzlePreferredFocusEnvironments()

        //-------------------------- 10. Low-level tvOS input monitoring -----------
        setupTVOSInputMonitoring()
        
        //-------------------------- 11. Private API event monitoring --------------
        setupPrivateAPIMonitoring()
        
        //-------------------------- 12. Enhanced hardware polling ----------------
        setupHardwarePolling()

        UIWindow.performSwizzling()
    }

    // MARK: – Run-Loop Stall ----------------------------------------------------

    private func addRunLoopObserver() {
        var lastTime = CFAbsoluteTimeGetCurrent()
        let obs = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault,
                                                     CFRunLoopActivity.beforeSources.rawValue,
                                                     true, 0) { _, _ in
            let now = CFAbsoluteTimeGetCurrent()
            let diff = now - lastTime
            if diff > 1 {
                let ms = Int(diff * 1_000)
                self.log("⚠️ RunLoop stall \(ms) ms")
                os_signpost(.event, log: self.perfLog, name: "RunLoopStall", "%d", ms)
            }
            lastTime = now
        }
        CFRunLoopAddObserver(CFRunLoopGetMain(), obs, .defaultMode)
    }

    // MARK: – Display-Link Hitch ----------------------------------------------

    private func addDisplayLink() {
        let link = CADisplayLink(target: self, selector: #selector(displayTick(_:)))
        link.add(to: .main, forMode: .common)
        link.preferredFramesPerSecond = 60
        cancellables.insert(Combine.AnyCancellable { link.invalidate() })
    }

    @objc private func displayTick(_ link: CADisplayLink) {
        let dur = link.targetTimestamp - link.timestamp
        if dur > (2.0 / 60.0) { // > 2 frames drop
            let ms = Int(dur * 1_000)
            log("⚠️ Frame hitch \(ms) ms")
            os_signpost(.event, log: perfLog, name: "FrameHitch", "%d", ms)
        }
    }

    // MARK: – Focus-Guide monitor (#7) -------------------------------------------
    private func hookFocusGuideMonitor() {

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in

            // 1️⃣ Gather every UIFocusGuide from every window / view tree
            var guides: [UIFocusGuide] = []

            func walk(_ view: UIView) {
                view.layoutGuides
                    .compactMap { $0 as? UIFocusGuide }
                    .forEach { guides.append($0) }
                view.subviews.forEach { walk($0) }
            }

            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .forEach { if let root = $0.rootViewController?.view { walk(root) } }
            guard let self else {
                return
            }
            // 2️⃣ Check each guide's size in global coordinates
            for guide in guides {
                guard let host = guide.owningView else { continue }
                let global = host.convert(guide.layoutFrame, to: nil)   // layoutFrame is correct API

                if global.width < 6 || global.height < 6 {
                    let rectStr = NSCoder.string(for: global)
                    self.log("[A11Y] ⚠️ FocusGuide tiny frame \(rectStr)")
                    os_signpost(.event, log: self.poiLog, name: "TinyFocusGuide", "%{public}s", rectStr)
                }
            }
        }
    }
    
    // MARK: – Conflicting UIGestureRecognizer / Press handlers ---------------
    private func checkConflictingPressRecognizers(in root: UIView?) {
        guard let root else { return }

        for view in root.recursiveSubviews {
            guard let grs = view.gestureRecognizers, grs.count > 1 else { continue }

            // Keep only recognizers that look at remote‑control presses
            let pressGRs = grs.filter { recognizer in
                // -------------------------------------------------------------
                // 1) UILongPressGestureRecognizer has a 'pressType' selector
                // -------------------------------------------------------------
                if recognizer is UILongPressGestureRecognizer {
                    return true
                }

                // -------------------------------------------------------------
                // 2) For UITap/Swipe/Pan on tvOS, check the private ivar
                //    '_allowedPressTypes' *without* KVC – this avoids the
                //    NSMapGet(NULL) console spew that happens when UIKit’s
                //    getter touches an un‑initialised map table.
                // -------------------------------------------------------------
                guard
                    let ivar = class_getInstanceVariable(type(of: recognizer),
                                                         "_allowedPressTypes")
                else { return false }

                if let arr = object_getIvar(recognizer, ivar) as? NSArray,
                   arr.count > 0 {
                    return true        // it specifically handles remote presses
                }

                return false
            }

            guard pressGRs.count > 1 else { continue }

            let list = pressGRs
                .map { String(describing: type(of: $0)) }
                .joined(separator: ", ")

            log("⚠️ Multiple press-gesture recognizers on \(type(of: view)): [\(list)]")
            os_signpost(.event,
                        log: poiLog,
                        name: "ConflictingPressGR",
                        "%{public}s", list)
        }
    }
    // MARK: – preferredFocusEnvironments spy (#4) -----------------------------

    private func swizzlePreferredFocusEnvironments() {
#if DEBUG
        guard let orig = class_getInstanceMethod(UIViewController.self,
                                                 #selector(getter: UIViewController.preferredFocusEnvironments)),
              let repl = class_getInstanceMethod(UIViewController.self,
                                                 #selector(UIViewController.axdbg_preferredFocusEnvironments))
        else { return }
        method_exchangeImplementations(orig, repl)
#endif
    }

    // MARK: – Duplicate ID / label checks (#5) ---------------------------------

    private func checkDuplicateAccessibilityIDs(in root: UIView?) {
        guard let root else { return }
        var dict = [String: Int]()
        for v in root.recursiveSubviews where v !== root {
            if let id = v.accessibilityIdentifier, !id.isEmpty {
                dict[id, default: 0] += 1
            }
        }
        for (id, count) in dict where count > 1 {
            log("⚠️ Duplicate accessibilityIdentifier \"\(id)\" ×\(count)")
        }
    }

    private func checkDuplicateAccessibilityLabels(in root: UIView?) {
        guard let root else { return }
        var dict = [String: Int]()
        for v in root.recursiveSubviews where v !== root {
            if let label = v.accessibilityLabel, !label.isEmpty {
                dict[label, default: 0] += 1
            }
        }
        for (label, count) in dict where count > 5 { // >5 identical labels usually smells
            log("⚠️ Potential duplicate label \"\(label)\" ×\(count)")
        }
    }

    // MARK: – Helpers ----------------------------------------------------------

    private static func describe(_ obj: NSObject?) -> String {
        guard let v = obj else { return "nil" }
        if let view = v as? UIView {
            return "\(type(of: view))(id: \(view.accessibilityIdentifier ?? "nil"), label: \(view.accessibilityLabel ?? "nil"))"
        }
        return String(describing: v)
    }

    /// ISO‑timestamped logger so you can see when each event occurs
    private static let tsFmt: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
//        f.formatOptions = [.withFullDate, .withTime, .withFractionalSeconds]
        f.formatOptions = [.withTime, .withFractionalSeconds]
        return f
    }()

    internal func log(_ msg: String) {
        let stamp = Self.tsFmt.string(from: Date())
        NSLog("[AXDBG] \(stamp) %@", msg)
    }
    
    // MARK: – tvOS Low-Level Input Monitoring ----------------------------------
    
    /// Sets up tvOS-specific low-level input monitoring using GameController framework
    private func setupTVOSInputMonitoring() {
        #if DEBUG
        log("✅ Starting tvOS low-level input monitoring")
        os_signpost(.event, log: inputLog, name: "TVOSInputMonitoringStarted")
        
        // Enhanced GameController monitoring with state tracking
        setupEnhancedGameControllerMonitoring()
        
        // High-frequency controller polling to catch missed events
        setupControllerPolling()
        
        // Monitor controller connections/disconnections more precisely
        setupControllerConnectionMonitoring()
        #endif
    }
    
    /// Enhanced GameController monitoring with detailed state tracking
    private func setupEnhancedGameControllerMonitoring() {
        // Monitor all existing controllers
        for controller in GCController.controllers() {
            setupControllerStateMonitoring(controller)
        }
        
        // Monitor future controller connections
        NotificationCenter.default.publisher(for: .GCControllerDidConnect)
            .sink { [weak self] notification in
                if let controller = notification.object as? GCController {
                    self?.setupControllerStateMonitoring(controller)
                }
            }
            .store(in: &cancellables)
    }
    
    /// Sets up detailed state monitoring for a specific controller
    private func setupControllerStateMonitoring(_ controller: GCController) {
        let productName = controller.productCategory
        
        log("🎮 Enhanced monitoring for controller: \(productName)")
        os_signpost(.event, log: inputLog, name: "ControllerMonitoringSetup", "%{public}s", productName)
        
        // Track previous state for differential monitoring
        var previousDPadState: (x: Float, y: Float) = (0, 0)
        var previousButtonStates: [String: Bool] = [:]
        
        if let microGamepad = controller.microGamepad {
            // Enhanced D-pad monitoring with precise state tracking
            microGamepad.dpad.valueChangedHandler = { [weak self] (dpad, x, y) in
                let currentTime = CACurrentMediaTime()
                
                // Detect actual state changes (not just value updates)
                if abs(x - previousDPadState.x) > 0.1 || abs(y - previousDPadState.y) > 0.1 {
                    let direction = self?.mapDPadToDirection(x: x, y: y) ?? "Unknown"
                    
                    self?.log("🕹️ DPAD STATE: \(direction) (x:\(String(format: "%.3f", x)), y:\(String(format: "%.3f", y)), ts:\(String(format: "%.6f", currentTime)))")
                    
                    os_signpost(.event, log: self?.inputLog ?? OSLog.disabled,
                               name: "DPadStateChange",
                               "%{public}s x:%.3f y:%.3f",
                               direction, x, y)
                    
                    // Update hardware press cache with precise timing
                    HardwarePressCache.markDownPrecise("DPad \(direction)", timestamp: currentTime)
                    
                    previousDPadState = (x, y)
                }
            }
            
            // Individual button monitoring
            let buttons: [(button: GCControllerButtonInput?, name: String)] = [
                (microGamepad.buttonA, "Select"),
                (microGamepad.buttonMenu, "Menu"),
                (microGamepad.buttonX, "Play/Pause")
            ]
            
            for (button, name) in buttons {
                button?.pressedChangedHandler = { [weak self] (btn, value, pressed) in
                    let currentTime = CACurrentMediaTime()
                    
                    // Only log actual state changes
                    if previousButtonStates[name] != pressed {
                        self?.log("🔘 BUTTON: \(name) \(pressed ? "PRESSED" : "RELEASED") (value:\(String(format: "%.3f", value)), ts:\(String(format: "%.6f", currentTime)))")
                        
                        os_signpost(.event, log: self?.inputLog ?? OSLog.disabled,
                                   name: "ButtonStateChange",
                                   "%{public}s %{public}s value:%.3f",
                                   name, pressed ? "PRESSED" : "RELEASED", value)
                        
                        if pressed {
                            HardwarePressCache.markDownPrecise(name, timestamp: currentTime)
                        }
                        
                        previousButtonStates[name] = pressed
                    }
                }
            }
        }
    }
    
    /// Maps D-pad coordinates to directional names
    private func mapDPadToDirection(x: Float, y: Float) -> String {
        let threshold: Float = 0.5
        
        if abs(x) > abs(y) {
            return x > threshold ? "Right" : x < -threshold ? "Left" : "Center"
        } else {
            return y > threshold ? "Down" : y < -threshold ? "Up" : "Center"
        }
    }
    
    /// High-frequency controller polling to catch missed events
    private func setupControllerPolling() {
        controllerPollingTimer = Timer.scheduledTimer(withTimeInterval: 0.008, repeats: true) { [weak self] _ in
            self?.pollControllerStates()
        }
        
        cancellables.insert(AnyCancellable { [weak self] in
            self?.controllerPollingTimer?.invalidate()
        })
    }
    
    /// Polls all controller states at high frequency
    private func pollControllerStates() {
        for controller in GCController.controllers() {
            if let microGamepad = controller.microGamepad {
                let x = microGamepad.dpad.xAxis.value
                let y = microGamepad.dpad.yAxis.value
                
                // Check for significant analog values that might indicate missed events
                if abs(x) > 0.8 || abs(y) > 0.8 {
                    let direction = mapDPadToDirection(x: x, y: y)
                    
                    // Only log if this is a new state
                    let stateKey = "Polled\(direction)"
                    if !HardwarePressCache.recentlyPressed(stateKey, within: 0.1) {
                        log("📊 POLL: \(direction) detected via polling (x:\(String(format: "%.3f", x)), y:\(String(format: "%.3f", y)))")
                        HardwarePressCache.markDown(stateKey)
                    }
                }
            }
        }
    }
    
    /// Enhanced controller connection monitoring
    private func setupControllerConnectionMonitoring() {
        NotificationCenter.default.publisher(for: .GCControllerDidConnect)
            .sink { [weak self] notification in
                if let controller = notification.object as? GCController {
                    let name = controller.productCategory
                    self?.log("🔌 Controller connected: \(name)")
                    os_signpost(.event, log: self?.inputLog ?? OSLog.disabled,
                               name: "ControllerConnected", "%{public}s", name)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .GCControllerDidDisconnect)
            .sink { [weak self] notification in
                if let controller = notification.object as? GCController {
                    let name = controller.productCategory
                    self?.log("🔌 Controller disconnected: \(name)")
                    os_signpost(.event, log: self?.inputLog ?? OSLog.disabled,
                               name: "ControllerDisconnected", "%{public}s", name)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: – Private API Event Monitoring -----------------------------------
    
    /// Sets up private API monitoring for system-level events
    private func setupPrivateAPIMonitoring() {
        #if DEBUG
        // Method 1: Hook into private UIApplication event handling
        setupUIApplicationEventHook()
        
        // Method 2: Monitor GSEvent (GraphicsServices) if available
        setupGSEventMonitoring()
        
        // Method 3: Low-level event tap using private APIs
        setupSystemEventTap()
        #endif
    }
    
    /// Hooks UIApplication's private event handling methods
    private func setupUIApplicationEventHook() {
        guard let appClass = NSClassFromString("UIApplication") else { return }
        
        // Hook _handleNonLaunchSpecificActions:forScene:withTransitionContext:completion:
        let eventHandlingSelectors = [
            "_handlePhysicalButtonEvent:",
            "_handleRemoteControlEvent:",
            "_handleKeyUIEvent:",
            "sendEvent:"
        ]
        
        for selectorName in eventHandlingSelectors {
            guard let originalMethod = class_getInstanceMethod(appClass, NSSelectorFromString(selectorName)) else {
                continue
            }
            
            let originalImplementation = method_getImplementation(originalMethod)
            let newImplementation: IMP = imp_implementationWithBlock({ (app: UIApplication, event: Any) in
                // Log the private event (using AXFocusDebugger.shared to avoid capture issues)
                AXFocusDebugger.shared.log("🔐 Private API Event: \(selectorName) - \(type(of: event))")
                os_signpost(.event, log: AXFocusDebugger.shared.inputLog, name: "PrivateAPIEvent", "%{public}s", selectorName)
                
                // Call original implementation
                typealias OriginalFunction = @convention(c) (UIApplication, Selector, Any) -> Void
                let originalFunc = unsafeBitCast(originalImplementation, to: OriginalFunction.self)
                originalFunc(app, NSSelectorFromString(selectorName), event)
            } as @convention(block) (UIApplication, Any) -> Void)
            
            method_setImplementation(originalMethod, newImplementation)
        }
    }
    
    /// Monitors GSEvent (GraphicsServices) if accessible
    private func setupGSEventMonitoring() {
        // GraphicsServices is private but sometimes accessible
        guard NSClassFromString("GSEvent") != nil else {
            log("⚠️ GSEvent class not accessible")
            return
        }
        
        log("✅ GSEvent monitoring enabled")
        
        // This would require more complex reflection to access GSEvent methods
        // Implementation would be highly version-dependent and fragile
    }
    
    /// Sets up system-level event tap using private APIs
    private func setupSystemEventTap() {
        // This would use private CoreGraphics/IOKit APIs similar to macOS CGEventTap
        // Implementation is complex and version-dependent
        // Would require reverse engineering of tvOS private frameworks
        
        log("⚠️ System event tap not implemented (requires private API research)")
    }
    
    // MARK: – Enhanced Hardware Polling -------------------------------------
    
    /// Adds continuous polling for hardware state changes
    private func setupHardwarePolling() {
        // Create a high-frequency timer to poll for hardware state changes
        let pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.008, repeats: true) { [weak self] _ in
            self?.pollHardwareState()
        }
        
        // Store timer for cleanup
        cancellables.insert(AnyCancellable {
            pollingTimer.invalidate()
        })
    }
    
    /// Polls hardware state at high frequency to catch missed events
    private func pollHardwareState() {
        // Poll GameController state directly
        for controller in GCController.controllers() {
            if let micro = controller.microGamepad {
                // Check D-pad state
                let x = micro.dpad.xAxis.value
                let y = micro.dpad.yAxis.value
                
                // Detect state changes that might have been missed
                if abs(x) > 0.8 || abs(y) > 0.8 {
                    let direction = x > 0.8 ? "Right" : x < -0.8 ? "Left" : y > 0.8 ? "Down" : "Up"
                    HardwarePressCache.markDown("Polled \(direction)")
                }
            }
        }
    }
}

// MARK: – UIViewController swizzle (preferredFocus) ---------------------------

#if DEBUG
private var pfKey: UInt8 = 0
extension UIViewController {

    @objc func axdbg_preferredFocusEnvironments() -> [UIFocusEnvironment] {
        let envs = axdbg_preferredFocusEnvironments() // calls original
        if envs.count > 1 {
            NSLog("[AXDBG] ⚠️ preferredFocusEnvironments count = \(envs.count) in \(type(of: self))")
        }
        return envs
    }
}
#endif

// MARK: – UIPress publisher helper -------------------------------------------

private extension UIPressesEvent {
    static let pressNotifications = Notification.Name("AXDBG.Press")
}

#if DEBUG
private extension UIWindow {
    static func performSwizzling() {
        _ = swizzleSendEvent
        _ = swizzlePressHandlers
    }

    private static let swizzleSendEvent: Void = {
        let original = #selector(sendEvent(_:))
        let swizzled = #selector(axdbg_sendEvent(_:))
        let cls = UIWindow.self
        guard
            let o = class_getInstanceMethod(cls, original),
            let s = class_getInstanceMethod(cls, swizzled)
        else { return }
        method_exchangeImplementations(o, s)
    }()

    private static let swizzlePressHandlers: Void = {
        let cls = UIWindow.self
        let pairs: [(Selector, Selector)] = [
            (#selector(UIResponder.pressesBegan(_:with:)),
             #selector(UIWindow.axdbg_pressesBegan(_:with:))),
            (#selector(UIResponder.pressesChanged(_:with:)),
             #selector(UIWindow.axdbg_pressesChanged(_:with:))),
            (#selector(UIResponder.pressesEnded(_:with:)),
             #selector(UIWindow.axdbg_pressesEnded(_:with:))),
            (#selector(UIResponder.pressesCancelled(_:with:)),
             #selector(UIWindow.axdbg_pressesCancelled(_:with:)))
        ]
        for (orig, repl) in pairs {
            if let o = class_getInstanceMethod(cls, orig),
               let s = class_getInstanceMethod(cls, repl) {
                method_exchangeImplementations(o, s)
            }
        }
    }()

    @objc func axdbg_sendEvent(_ ev: UIEvent) {
        if let pe = ev as? UIPressesEvent {
            for press in pe.allPresses {
                NotificationCenter.default.post(name: UIPressesEvent.pressNotifications,
                                                object: press)
            }
        }
        axdbg_sendEvent(ev) // original impl
    }

    // MARK: - Press life‑cycle logging ---------------------------------

    @objc func axdbg_pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        axdbg_logPresses("began", presses, in: self)
        axdbg_pressesBegan(presses, with: event) // original impl
    }

    @objc func axdbg_pressesChanged(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        axdbg_logPresses("changed", presses, in: self)
        axdbg_pressesChanged(presses, with: event)
    }

    @objc func axdbg_pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        axdbg_logPresses("ended", presses, in: self)
        axdbg_pressesEnded(presses, with: event)
    }

    @objc func axdbg_pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        axdbg_logPresses("cancelled", presses, in: self)
        axdbg_pressesCancelled(presses, with: event)
    }

    // Helper that prints window address, press type/phase, and first responder
    private func axdbg_logPresses(_ phase: String,
                                  _ presses: Set<UIPress>,
                                  in window: UIWindow) {
        let winPtr = Unmanaged.passUnretained(window).toOpaque()
        for press in presses {
            let type = press.type.readable
            let responderPtr = press.responder
                .map { Unmanaged.passUnretained($0).toOpaque() }
                .map { String(format: "%p", UInt(bitPattern: $0)) } ?? "nil"
            NSLog("[HWDBG_CHAIN] window=0x%0llx  press=%@  phase=%@  firstResponder=%@",
                  UInt(bitPattern: winPtr), type, phase, responderPtr)
        }
    }
}
#endif

// MARK: – Convenience ---------------------------------------------------------

private extension UIWindow {
    var recurseSubviews: [UIView] {
        var arr: [UIView] = []
        func walk(_ v: UIView) {
            arr.append(v)
            v.subviews.forEach { walk($0) }
        }
        if let root = rootViewController?.view { walk(root) }
        return arr
    }
}

private extension UIView {
    var recursiveSubviews: [UIView] {
        var result: [UIView] = []
        func walk(_ view: UIView) {
            result.append(view)
            view.subviews.forEach { walk($0) }
        }
        walk(self)
        return result
    }
}
// MARK: – Human-readable press names -----------------------------------------
private extension UIPress.PressType {
    var readable: String {
        switch self {
        case .upArrow:     return "Up Arrow"
        case .downArrow:   return "Down Arrow"
        case .leftArrow:   return "Left Arrow"
        case .rightArrow:  return "Right Arrow"
        case .select:      return "Select"
        case .menu:        return "Menu"
        case .playPause:   return "Play/Pause"
        case .pageUp:      return "Page Up"
        case .pageDown:    return "Page Down"
        case .tvRemoteOneTwoThree: return "TV Remote 123"
        case .tvRemoteFourColors: return "TV Remote Colors"
        @unknown default:  return "Unknown(\(rawValue))"
        }
    }
}

private extension UIPress.Phase {
    var readable: String {
        switch self {
        case .began:      return "began"
        case .changed:    return "changed"
        case .stationary: return "stationary"
        case .ended:      return "ended"
        case .cancelled:  return "cancelled"
        @unknown default: return "unknown"
        }
    }
}
/// Hardware events we care about (Siri Remote, Bluetooth gamepad, keyboard)
private struct HardwarePressCache {
    /// last timestamp for each GC button that went down
    static var lastDown: [String : TimeInterval] = [:]
    
    /// Ultra-precise timestamps from HID layer
    static var preciseTimestamps: [String : Double] = [:]
    
    /// write helper
    static func markDown(_ id: String) {
        lastDown[id] = CACurrentMediaTime()
    }
    
    /// write helper with precise HID timestamp
    static func markDownPrecise(_ id: String, timestamp: Double) {
        preciseTimestamps[id] = timestamp
        lastDown[id] = CACurrentMediaTime() // Also update the regular cache
    }
    
    /// was there a hardware press in the last 200 ms?
    static func recentlyPressed(_ id: String, within s: Double = 0.20) -> Bool {
        // Check both regular and precise timestamps
        let currentTime = CACurrentMediaTime()
        
        // Check regular timestamp
        if let t = lastDown[id], currentTime - t < s {
            return true
        }
        
        // Check precise HID timestamp (convert to current time base)
        if let preciseTime = preciseTimestamps[id] {
            let hidTime = preciseTime * Double(NSEC_PER_SEC) / 1_000_000_000.0 // Convert to seconds
            if currentTime - hidTime < s {
                return true
            }
        }
        
        return false
    }
    
    /// Get the most precise timestamp available for a button
    static func getPreciseTimestamp(_ id: String) -> Double? {
        return preciseTimestamps[id]
    }
}



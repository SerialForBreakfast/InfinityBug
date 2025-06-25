//
//  AXFocusDebugger.swift
//  InfinityBugDiagnostics
//
//  Created by You on 2025-06-16.
//  Enhanced 2025-01-22 for InfinityBug investigation:
//  - Event Queue Depth Estimation (hardware vs UIKit event tracking)
//  - VoiceOver Processing Time Measurement (accessibility operation timing)
//  - Memory Pressure Correlation Analysis (memory usage during RunLoop stalls)
//  - Queue Persistence Mystery Investigation (event processing across app states)
//

import UIKit
import os
import Combine
import ObjectiveC.runtime
import GameController
import Darwin.Mach

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
    
    /// Comprehensive analysis report for InfinityBug investigation
    @objc func logInfinityBugAnalysis() {
        log("🔍 ====== InfinityBug Analysis Report ======")
        logQueueDepthAnalysis()
        logVoiceOverPerformanceSummary()
        logMemoryCorrelationAnalysis()
        log("🔍 ======================================")
    }
    
    /// Quick summary of current swipe vs press status for manual testing
    @objc func logSwipeVsPressStatus() {
        let totalQueue = hardwareEventCount - uikitEventCount
        log("📊 SWIPE vs PRESS Status:")
        log("   🏃‍♂️ SWIPES: Hardware=\(hardwareSwipeCount), UIKit=\(uikitSwipeCount), Queue=\(swipeQueueDepth)")
        log("   👆 PRESSES: Hardware=\(hardwarePressCount), UIKit=\(uikitPressCount), Queue=\(pressQueueDepth)")
        log("   📈 TOTAL: Queue depth=\(totalQueue), Max observed=\(maxObservedQueueDepth)")
        
        // Current latency status
        if !swipeLatencies.isEmpty {
            let currentSwipeLatency = swipeLatencies.last! * 1000
            log("   ⏱️ Current SWIPE latency: \(String(format: "%.0f", currentSwipeLatency))ms")
        }
        if !pressLatencies.isEmpty {
            let currentPressLatency = pressLatencies.last! * 1000
            log("   ⏱️ Current PRESS latency: \(String(format: "%.0f", currentPressLatency))ms")
        }
        
        // Status assessment
        if swipeQueueDepth > pressQueueDepth * 2 {
            log("   🚨 Swipe queue dominates - InfinityBug pattern detected!")
        } else if swipeQueueDepth > 10 {
            log("   ⚠️ Significant swipe backlog - monitor for InfinityBug")
        } else if !swipeLatencies.isEmpty && swipeLatencies.last! > 0.1 {
            log("   ⚠️ High swipe latency - performance degradation detected")
        } else {
            log("   ✅ Queue depths and latencies appear normal")
        }
    }

    // MARK: – Private -------------------------------------------------------

    private override init() {}
    private var enabled = false
    private var cancellables: Set<Combine.AnyCancellable> = []
    /// Last time a focus hop was observed
    private var lastFocusTimestamp = CACurrentMediaTime()
    
    /// Count recent presses by type for phantom detection
    private var recentPressByType: [String: Int] = [:]
    private var lastPressReset = CACurrentMediaTime()
    
    /// tvOS-specific low-level input monitoring dispatch queue
    private let inputQueue = DispatchQueue(label: "com.infinitybug.input-monitor", qos: .userInteractive)
    
    /// Private API function pointers for ultra-low-level monitoring
    private var systemEventTap: UnsafeMutableRawPointer?
    
    /// High-frequency controller state monitoring
    private var controllerPollingTimer: Timer?
    
    // MARK: – Enhanced InfinityBug Investigation Properties -----------------
    
    /// Event Queue Depth Estimation
    private var hardwareEventCount: Int = 0
    private var uikitEventCount: Int = 0
    private var queueDepthHistory: [TimeInterval: Int] = [:]
    private var maxObservedQueueDepth: Int = 0
    
    /// Input Type Differentiation
    private var hardwareSwipeCount: Int = 0
    private var hardwarePressCount: Int = 0
    private var uikitSwipeCount: Int = 0
    private var uikitPressCount: Int = 0
    private var swipeQueueDepth: Int = 0
    private var pressQueueDepth: Int = 0
    
    /// Input to Focus Change Latency Tracking
    private var hardwareInputTimestamps: [TimeInterval] = []  // FIFO queue of hardware input times
    private var uikitInputTimestamps: [(TimeInterval, String)] = []  // FIFO queue of (time, inputType)
    private var swipeLatencies: [TimeInterval] = []  // Recent swipe latencies
    private var pressLatencies: [TimeInterval] = []  // Recent press latencies
    private var maxSwipeLatency: TimeInterval = 0
    private var maxPressLatency: TimeInterval = 0
    
    /// VoiceOver Processing Time Measurement
    private var accessibilityOperationStartTime: TimeInterval = 0
    private var voiceOverProcessingTimes: [TimeInterval] = []
    private var focusChangeStartTime: TimeInterval = 0
    private var announcementStartTimes: [String: TimeInterval] = [:]
    
    /// Memory Pressure Correlation Analysis
    private var memoryUsageHistory: [TimeInterval: Int] = [:]  // timestamp: bytes
    private var runLoopStallHistory: [TimeInterval: TimeInterval] = [:]  // timestamp: stall_duration
    private var lastMemoryCheck: TimeInterval = 0
    private let memoryCheckInterval: TimeInterval = 0.5  // Check every 500ms
    
    /// Queue Persistence Mystery Investigation
    private var appStateTransitions: [TimeInterval: String] = [:]
    private var backgroundEventCount: Int = 0
    private var foregroundEventCount: Int = 0
    private var persistentEventTimer: Timer?

    // MARK: – Optimized Logging Properties ---------------------------------
    
    /// Polling rate limiting
    private var lastPollingLogTimes: [String: TimeInterval] = [:]
    private var hardwarePollingCounter: Int = 0
    
    /// Queue status reporting optimization
    private var lastReportedQueueDepth: Int = 0
    private var lastQueueReportTime: TimeInterval = 0
    
    /// Hardware event burst detection
    private var lastHardwareEventTime: TimeInterval = 0
    private var hardwareEventBurstCount: Int = 0

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

            b.pressedChangedHandler = { [weak self] _, _, pressed in
                if pressed { 
                    HardwarePressCache.markDown(label)
                    self?.trackHardwarePress()
                }
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
            mg.dpad.valueChangedHandler = { [weak self] _, x, y in
                // X‑axis is unchanged
                if x < -0.5 { 
                    HardwarePressCache.markDown("Left Arrow")
                    self?.trackHardwareSwipe()
                }
                if x >  0.5 { 
                    HardwarePressCache.markDown("Right Arrow")
                    self?.trackHardwareSwipe()
                }

                // Y‑axis on tvOS:  Up = negative –1,  Down = positive +1
                if y < -0.5 { 
                    HardwarePressCache.markDown("Up Arrow")
                    self?.trackHardwareSwipe()
                }
                if y >  0.5 { 
                    HardwarePressCache.markDown("Down Arrow")
                    self?.trackHardwareSwipe()
                }
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
                let currentTime = CACurrentMediaTime()
                
                // Measure VoiceOver processing time if we had a previous accessibility operation
                if self.accessibilityOperationStartTime > 0 {
                    let processingTime = currentTime - self.accessibilityOperationStartTime
                    self.voiceOverProcessingTimes.append(processingTime)
                    self.log("📊 VoiceOver processing time: \(String(format: "%.2f", processingTime * 1000))ms")
                    
                    // Keep only last 100 measurements
                    if self.voiceOverProcessingTimes.count > 100 {
                        self.voiceOverProcessingTimes.removeFirst()
                    }
                }
                
                self.lastFocusTimestamp = currentTime
                self.focusChangeStartTime = currentTime
                let from = note.userInfo?[AXNotificationKeys.focusedElement] as? NSObject
                let to = note.userInfo?[AXNotificationKeys.nextFocusedElement] as? NSObject
                let desc = "\(Self.describe(from)) → \(Self.describe(to))"
                self.log("FOCUS HOP: \(desc)")
                os_signpost(.event, log: self.poiLog, name: "AXFocus", "%{public}s", desc)
                
                // Track UIKit event processing
                self.trackUIKitEvent()
                
                // Calculate and log input-to-focus latencies
                self.calculateInputLatencies(currentTime)
                
                // Track memory usage during focus changes
                self.checkMemoryUsage()

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
                let currentTime = CACurrentMediaTime()
                self.announcementStartTimes[msg] = currentTime
                self.accessibilityOperationStartTime = currentTime  // Track for processing time measurement
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

                // 👉  Treat as phantom only when:
                //     a) no recent hardware press **and**
                //     b) no focus hop in the last 120ms **and** 
                //     c) rapid repetition of same press type **and**
                //     d) not in UI test environment
                let noHW  = !HardwarePressCache.recentlyPressed(id)
                let stale = CACurrentMediaTime() - self.lastFocusTimestamp > 0.12
                let isUITest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
                
                // Reset counter every 2 seconds
                if CACurrentMediaTime() - self.lastPressReset > 2.0 {
                    self.recentPressByType.removeAll()
                    self.lastPressReset = CACurrentMediaTime()
                }
                
                self.recentPressByType[id, default: 0] += 1
                let rapidRepetition = self.recentPressByType[id, default: 0] > 5 // >5 of same press in 2s
                
                if noHW && stale && rapidRepetition && !isUITest {
                    let isSwipe = ["UpArrow", "DownArrow", "LeftArrow", "RightArrow"].contains(id)
                    let eventType = isSwipe ? "SWIPE" : "PRESS"
                    
                    self.log("[A11Y] WARNING: Phantom UI\(eventType) \(id) → InfinityBug?")
                    let dt = CACurrentMediaTime() - self.lastFocusTimestamp
                    self.log("(debug)  noHW=\(noHW)  stale=\(stale)  rapid=\(rapidRepetition)  dt=\(String(format: "%.1f", dt))s")
                    
                    // Log current queue depth for phantom events
                    let currentQueueDepth = self.hardwareEventCount - self.uikitEventCount
                    let swipeDepth = self.swipeQueueDepth
                    let pressDepth = self.pressQueueDepth
                    
                    if isSwipe {
                        self.log("📊 SWIPE queue depth during phantom: \(swipeDepth) | Total: \(currentQueueDepth)")
                        self.trackUIKitSwipe()
                    } else {
                        self.log("📊 PRESS queue depth during phantom: \(pressDepth) | Total: \(currentQueueDepth)")
                        self.trackUIKitPress()
                    }
                    
                    if isSwipe {
                        os_signpost(.event, log: self.poiLog,
                                    name: "InfinityBugPhantomSwipe",
                                    "%{public}s queueDepth:%d", id, currentQueueDepth)
                    } else {
                        os_signpost(.event, log: self.poiLog,
                                    name: "InfinityBugPhantomPress",
                                    "%{public}s queueDepth:%d", id, currentQueueDepth)
                    }
                    return
                }

                // Normal user input - differentiate swipes vs presses
                let isSwipe = ["UpArrow", "DownArrow", "LeftArrow", "RightArrow"].contains(id)
                let eventType = isSwipe ? "SWIPE" : "PRESS"
                
                self.log("[A11Y] REMOTE \(eventType): \(id)")
                
                if isSwipe {
                    self.trackUIKitSwipe()
                } else {
                    self.trackUIKitPress()
                }
                
                if isSwipe {
                    os_signpost(.event, log: self.poiLog, name: "UserSwipe", "%{public}s", id)
                } else {
                    os_signpost(.event, log: self.poiLog, name: "UserPress", "%{public}s", id)
                }
            }
            .store(in: &cancellables)
        //-------------------------- 5. Memory warnings ---------------------------
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                self.log("WARNING: Memory warning")
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
        
        //-------------------------- 13. Queue persistence mystery investigation ---
        setupQueuePersistenceMonitoring()

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
                
                // Store stall in history for correlation analysis
                self.runLoopStallHistory[now] = diff
                
                // Check memory usage during stalls
                let memoryMB = self.getCurrentMemoryUsage()
                let queueDepth = self.hardwareEventCount - self.uikitEventCount
                let swipeDepth = self.swipeQueueDepth
                let pressDepth = self.pressQueueDepth
                
                self.log("⚠️ RunLoop stall \(ms)ms | Memory: \(memoryMB)MB | Total queue: \(queueDepth) | Swipes: \(swipeDepth) | Presses: \(pressDepth)")
                
                // Update max observed queue depth
                if queueDepth > self.maxObservedQueueDepth {
                    self.maxObservedQueueDepth = queueDepth
                    self.log("📊 New max queue depth: \(queueDepth) events (swipes: \(swipeDepth), presses: \(pressDepth))")
                }
                
                // Use optimized reporting for InfinityBug correlation
                if swipeDepth >= 50 {
                    self.log("🚨 CRITICAL SWIPE BACKLOG during stall: \(swipeDepth) swipes - InfinityBug correlation!")
                } else if swipeDepth > 20 {
                    self.log("🚨 HIGH SWIPE BACKLOG during stall: \(swipeDepth) swipes - InfinityBug correlation!")
                }
                
                os_signpost(.event, log: self.perfLog, name: "RunLoopStall", 
                           "%d ms, %d MB, total:%d, swipes:%d, presses:%d", ms, memoryMB, queueDepth, swipeDepth, pressDepth)
                
                // Clean up old history (keep last 5 minutes)
                let cutoff = now - 300
                self.runLoopStallHistory = self.runLoopStallHistory.filter { $0.key > cutoff }
                self.memoryUsageHistory = self.memoryUsageHistory.filter { $0.key > cutoff }
                self.queueDepthHistory = self.queueDepthHistory.filter { $0.key > cutoff }
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
            log("WARNING: Frame hitch \(ms) ms")
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
                    self.log("[A11Y] WARNING: FocusGuide tiny frame \(rectStr)")
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
                //    NSMapGet(NULL) console spew that happens when UIKit's
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

            log("WARNING: Multiple press-gesture recognizers on \(type(of: view)): [\(list)]")
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
            log("WARNING: Duplicate accessibilityIdentifier \"\(id)\" ×\(count)")
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
            log("WARNING: Potential duplicate label \"\(label)\" ×\(count)")
        }
    }

    // MARK: – Enhanced InfinityBug Investigation Methods --------------------
    
    /// Tracks hardware events for queue depth estimation
    private func trackHardwareEvent() {
        hardwareEventCount += 1
        let currentTime = CACurrentMediaTime()
        let queueDepth = hardwareEventCount - uikitEventCount
        queueDepthHistory[currentTime] = queueDepth
        
        if queueDepth > maxObservedQueueDepth {
            maxObservedQueueDepth = queueDepth
        }
        
        // Log significant queue buildups
        if queueDepth > 0 && queueDepth % 10 == 0 {
            log("📊 Event queue building: \(queueDepth) events behind")
        }
    }
    
    /// Tracks hardware swipe events specifically
    private func trackHardwareSwipe() {
        hardwareEventCount += 1
        let currentTime = CACurrentMediaTime()
        
        // Burst detection for hardware events
        if currentTime - lastHardwareEventTime < 0.1 {
            hardwareEventBurstCount += 1
        } else {
            hardwareEventBurstCount = 1
        }
        lastHardwareEventTime = currentTime
        
        // Only log hardware detection for bursts or significant events
        if hardwareEventBurstCount == 1 || hardwareEventBurstCount % 10 == 0 {
            let direction = getLastDetectedDirection()
            log("🕹️ HW_SWIPE: \(direction) [burst: \(hardwareEventBurstCount)]")
        }
        
        // Check queue status with context
        reportQueueStatus(context: "HW_SWIPE")
    }
    
    /// Tracks hardware press events specifically  
    private func trackHardwarePress() {
        hardwareEventCount += 1
        let currentTime = CACurrentMediaTime()
        
        // Press events are less frequent, log each one
        log("🕹️ HW_PRESS detected")
        
        reportQueueStatus(context: "HW_PRESS")
    }
    
    /// Tracks UIKit events for queue depth estimation
    private func trackUIKitEvent() {
        uikitEventCount += 1
        let currentTime = CACurrentMediaTime()
        let queueDepth = hardwareEventCount - uikitEventCount
        queueDepthHistory[currentTime] = queueDepth
        
        // Log when queue catches up
        if queueDepth <= 0 && maxObservedQueueDepth > 5 {
            log("📊 Event queue caught up! Max depth was: \(maxObservedQueueDepth)")
        }
    }
    
    /// Tracks UIKit swipe events specifically
    private func trackUIKitSwipe() {
        let currentTime = CACurrentMediaTime()
        uikitSwipeCount += 1
        swipeQueueDepth = hardwareSwipeCount - uikitSwipeCount
        trackUIKitEvent()  // Also update general count
        
        // Record UIKit event timestamp with type for latency calculation
        uikitInputTimestamps.append((currentTime, "swipe"))
        
        // Keep only last 50 timestamps
        if uikitInputTimestamps.count > 50 {
            uikitInputTimestamps.removeFirst()
        }
        
        if swipeQueueDepth <= 0 && hardwareSwipeCount > 5 {
            log("📊 SWIPE queue caught up! Processed \(uikitSwipeCount) swipes")
        }
    }
    
    /// Tracks UIKit press events specifically
    private func trackUIKitPress() {
        let currentTime = CACurrentMediaTime()
        uikitPressCount += 1
        pressQueueDepth = hardwarePressCount - uikitPressCount
        trackUIKitEvent()  // Also update general count
        
        // Record UIKit event timestamp with type for latency calculation
        uikitInputTimestamps.append((currentTime, "press"))
        
        // Keep only last 50 timestamps
        if uikitInputTimestamps.count > 50 {
            uikitInputTimestamps.removeFirst()
        }
        
        if pressQueueDepth <= 0 && hardwarePressCount > 5 {
            log("📊 PRESS queue caught up! Processed \(uikitPressCount) presses")
        }
    }
    
    /// Checks current memory usage for correlation analysis
    private func checkMemoryUsage() {
        let currentTime = CACurrentMediaTime()
        
        // Only check memory periodically to avoid performance impact
        if currentTime - lastMemoryCheck < memoryCheckInterval {
            return
        }
        lastMemoryCheck = currentTime
        
        let memoryMB = getCurrentMemoryUsage()
        memoryUsageHistory[currentTime] = memoryMB
        
        // Log memory spikes during navigation
        if let previousMemory = memoryUsageHistory.values.suffix(2).first,
           memoryMB > previousMemory + 50 {  // 50MB spike
            log("🧠 Memory spike: +\(memoryMB - previousMemory)MB during navigation")
        }
    }
    
    /// Gets current memory usage in MB
    private func getCurrentMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int(info.resident_size) / (1024 * 1024)  // Convert to MB
        }
        return 0
    }
    
    /// Calculates latencies from hardware input to focus change completion
    private func calculateInputLatencies(_ focusChangeTime: TimeInterval) {
        // Calculate hardware-to-focus latency (oldest hardware input)
        if let oldestHardwareTime = hardwareInputTimestamps.first {
            let hardwareLatency = focusChangeTime - oldestHardwareTime
            log("⏱️ HARDWARE→FOCUS latency: \(String(format: "%.0f", hardwareLatency * 1000))ms")
            
            // Remove the consumed hardware timestamp
            hardwareInputTimestamps.removeFirst()
        }
        
        // Calculate UIKit-to-focus latency (oldest UIKit input of each type)
        if let oldestUIKitEntry = uikitInputTimestamps.first {
            let (uikitTime, inputType) = oldestUIKitEntry
            let uikitLatency = focusChangeTime - uikitTime
            let latencyMs = uikitLatency * 1000
            
            if inputType == "swipe" {
                log("⏱️ SWIPE→FOCUS latency: \(String(format: "%.0f", latencyMs))ms")
                swipeLatencies.append(uikitLatency)
                if uikitLatency > maxSwipeLatency {
                    maxSwipeLatency = uikitLatency
                    log("📊 New max SWIPE latency: \(String(format: "%.0f", latencyMs))ms")
                }
                
                // Alert on concerning swipe latencies
                if latencyMs > 100 {  // 100ms threshold
                    log("⚠️ HIGH SWIPE LATENCY: \(String(format: "%.0f", latencyMs))ms - InfinityBug warning!")
                }
                
            } else {  // press
                log("⏱️ PRESS→FOCUS latency: \(String(format: "%.0f", latencyMs))ms")
                pressLatencies.append(uikitLatency)
                if uikitLatency > maxPressLatency {
                    maxPressLatency = uikitLatency
                    log("📊 New max PRESS latency: \(String(format: "%.0f", latencyMs))ms")
                }
                
                // Alert on concerning press latencies
                if latencyMs > 200 {  // 200ms threshold (presses should be less frequent)
                    log("⚠️ HIGH PRESS LATENCY: \(String(format: "%.0f", latencyMs))ms")
                }
            }
            
            // Remove the consumed UIKit timestamp
            uikitInputTimestamps.removeFirst()
            
            // Keep only last 100 latency measurements
            if swipeLatencies.count > 100 {
                swipeLatencies.removeFirst()
            }
            if pressLatencies.count > 100 {
                pressLatencies.removeFirst()
            }
        }
    }
    
    /// Sets up monitoring for queue persistence across app state changes
    private func setupQueuePersistenceMonitoring() {
        // Monitor app state transitions
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                let currentTime = CACurrentMediaTime()
                self.appStateTransitions[currentTime] = "willResignActive"
                self.backgroundEventCount = self.uikitEventCount
                self.log("🔄 App going to background | Events processed: \(self.uikitEventCount)")
                
                // Start monitoring events while backgrounded
                self.startPersistentEventMonitoring()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                let currentTime = CACurrentMediaTime()
                self.appStateTransitions[currentTime] = "didBecomeActive"
                self.foregroundEventCount = self.uikitEventCount
                
                let backgroundEvents = self.foregroundEventCount - self.backgroundEventCount
                if backgroundEvents > 0 {
                    self.log("🔄 App returned to foreground | Background events: \(backgroundEvents)")
                    self.log("🚨 QUEUE PERSISTENCE: Events continued processing while backgrounded!")
                }
                
                self.stopPersistentEventMonitoring()
            }
            .store(in: &cancellables)
        
        // Monitor for system-level events that might indicate queue persistence
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                let queueDepth = self.hardwareEventCount - self.uikitEventCount
                self.log("🧠 Memory warning with queue depth: \(queueDepth)")
                
                // Check if memory pressure correlates with queue depth
                if queueDepth > 20 {
                    self.log("🚨 High queue depth during memory warning - potential correlation!")
                }
            }
            .store(in: &cancellables)
    }
    
    /// Starts monitoring for persistent events during background state
    private func startPersistentEventMonitoring() {
        persistentEventTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let currentEventCount = self.uikitEventCount
            if currentEventCount > self.backgroundEventCount {
                let backgroundEvents = currentEventCount - self.backgroundEventCount
                self.log("🔍 Background event processing detected: +\(backgroundEvents) events")
            }
        }
    }
    
    /// Stops monitoring for persistent events
    private func stopPersistentEventMonitoring() {
        persistentEventTimer?.invalidate()
        persistentEventTimer = nil
    }
    
    // MARK: – Analysis and Reporting Methods --------------------------------
    
    /// Provides summary of VoiceOver processing performance
    @objc func logVoiceOverPerformanceSummary() {
        guard !voiceOverProcessingTimes.isEmpty else {
            log("📊 No VoiceOver processing time data available")
            return
        }
        
        let avgTime = voiceOverProcessingTimes.reduce(0, +) / Double(voiceOverProcessingTimes.count)
        let maxTime = voiceOverProcessingTimes.max() ?? 0
        let minTime = voiceOverProcessingTimes.min() ?? 0
        
        log("📊 VoiceOver Performance Summary:")
        log("   Average processing time: \(String(format: "%.2f", avgTime * 1000))ms")
        log("   Max processing time: \(String(format: "%.2f", maxTime * 1000))ms")
        log("   Min processing time: \(String(format: "%.2f", minTime * 1000))ms")
        log("   Total measurements: \(voiceOverProcessingTimes.count)")
        
        // Flag concerning performance
        if avgTime > 0.05 {  // 50ms average
            log("⚠️ Average VoiceOver processing time exceeds 50ms!")
        }
        if maxTime > 0.1 {   // 100ms max
            log("⚠️ Peak VoiceOver processing time exceeds 100ms!")
        }
    }
    
    /// Provides summary of queue depth analysis
    @objc func logQueueDepthAnalysis() {
        let currentQueueDepth = hardwareEventCount - uikitEventCount
        let currentSwipeDepth = swipeQueueDepth
        let currentPressDepth = pressQueueDepth
        
        log("📊 Event Queue Analysis:")
        log("   === TOTAL EVENTS ===")
        log("   Hardware events: \(hardwareEventCount)")
        log("   UIKit events processed: \(uikitEventCount)")
        log("   Current queue depth: \(currentQueueDepth)")
        log("   Max observed queue depth: \(maxObservedQueueDepth)")
        log("")
        log("   === SWIPES ===")
        log("   Hardware swipes: \(hardwareSwipeCount)")
        log("   UIKit swipes processed: \(uikitSwipeCount)")
        log("   Current swipe queue depth: \(currentSwipeDepth)")
        log("")
        log("   === PRESSES ===")
        log("   Hardware presses: \(hardwarePressCount)")
        log("   UIKit presses processed: \(uikitPressCount)")
        log("   Current press queue depth: \(currentPressDepth)")
        
        // Analysis and warnings
        if maxObservedQueueDepth > 50 {
            log("🚨 Significant event queue backlog detected!")
        }
        
        if currentSwipeDepth > 10 {
            log("⚠️ SWIPE backlog: \(currentSwipeDepth) swipes behind - InfinityBug risk!")
        }
        
        if currentPressDepth > 5 {
            log("⚠️ PRESS backlog: \(currentPressDepth) presses behind")
        }
        
        // InfinityBug correlation analysis
        if currentSwipeDepth > currentPressDepth * 2 {
            log("🚨 PATTERN: Swipe queue significantly larger than press queue - classic InfinityBug pattern!")
        }
        
        // Latency analysis
        log("")
        log("   === LATENCY ANALYSIS ===")
        if !swipeLatencies.isEmpty {
            let avgSwipeLatency = swipeLatencies.reduce(0, +) / Double(swipeLatencies.count)
            log("   Average SWIPE latency: \(String(format: "%.0f", avgSwipeLatency * 1000))ms")
            log("   Max SWIPE latency: \(String(format: "%.0f", maxSwipeLatency * 1000))ms")
            
            if avgSwipeLatency > 0.1 {  // 100ms average
                log("   ⚠️ SWIPE latency degraded - InfinityBug risk!")
            }
        } else {
            log("   No SWIPE latency data available")
        }
        
        if !pressLatencies.isEmpty {
            let avgPressLatency = pressLatencies.reduce(0, +) / Double(pressLatencies.count)
            log("   Average PRESS latency: \(String(format: "%.0f", avgPressLatency * 1000))ms")
            log("   Max PRESS latency: \(String(format: "%.0f", maxPressLatency * 1000))ms")
        } else {
            log("   No PRESS latency data available")
        }
    }
    
    /// Provides correlation analysis between memory usage and performance
    @objc func logMemoryCorrelationAnalysis() {
        guard !memoryUsageHistory.isEmpty && !runLoopStallHistory.isEmpty else {
            log("📊 Insufficient data for memory correlation analysis")
            return
        }
        
        // Find memory usage during stalls
        var correlatedStalls: [(TimeInterval, Int, TimeInterval)] = []  // (time, memory, stall_duration)
        
        for (stallTime, stallDuration) in runLoopStallHistory {
            // Find closest memory measurement
            let closestMemory = memoryUsageHistory
                .min(by: { abs($0.key - stallTime) < abs($1.key - stallTime) })
            
            if let memory = closestMemory, abs(memory.key - stallTime) < 2.0 {  // Within 2 seconds
                correlatedStalls.append((stallTime, memory.value, stallDuration))
            }
        }
        
        if !correlatedStalls.isEmpty {
            let avgMemoryDuringStalls = correlatedStalls.map { $0.1 }.reduce(0, +) / correlatedStalls.count
            let avgStallDuration = correlatedStalls.map { $0.2 }.reduce(0, +) / Double(correlatedStalls.count)
            
            log("📊 Memory-Performance Correlation:")
            log("   Average memory during stalls: \(avgMemoryDuringStalls)MB")
            log("   Average stall duration: \(String(format: "%.0f", avgStallDuration * 1000))ms")
            log("   Correlated samples: \(correlatedStalls.count)")
            
            if avgMemoryDuringStalls > 200 {  // 200MB
                log("🧠 High memory usage correlated with performance issues!")
            }
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
        log("SUCCESS: Starting tvOS low-level input monitoring")
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
        
                    log("CONTROLLER: Enhanced monitoring for controller: \(productName)")
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
                        log("POLL: \(direction) detected via polling (x:\(String(format: "%.3f", x)), y:\(String(format: "%.3f", y)))")
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
    /// WARNING: These methods may not work reliably and are for research only
    private func setupPrivateAPIMonitoring() {
        #if DEBUG
                  log("WARNING: Private API monitoring is experimental and may not work")
        
        // Method 1: Hook into UIApplication event handling (may not work)
        setupUIApplicationEventHook()
        
        // Note: GSEvent and system event tap monitoring removed as they don't work on tvOS
        #endif
    }
    
    /// Hooks UIApplication's event handling methods (experimental)
    /// WARNING: These private methods may not exist or work as expected
    private func setupUIApplicationEventHook() {
        guard let appClass = NSClassFromString("UIApplication") else { return }
        
        // These selectors may not exist or may not work as expected
        let experimentalSelectors = [
            "sendEvent:"  // This is the only one that might actually exist
        ]
        
        for selectorName in experimentalSelectors {
            guard let originalMethod = class_getInstanceMethod(appClass, NSSelectorFromString(selectorName)) else {
                                  log("WARNING: Selector \(selectorName) not found - skipping")
                continue
            }
            
            let originalImplementation = method_getImplementation(originalMethod)
            let newImplementation: IMP = imp_implementationWithBlock({ (app: UIApplication, event: Any) in
                // Log the event (using AXFocusDebugger.shared to avoid capture issues)
                AXFocusDebugger.shared.log("APP_EVENT: UIApplication Event: \(selectorName) - \(type(of: event))")
                os_signpost(.event, log: AXFocusDebugger.shared.inputLog, name: "UIApplicationEvent", "%{public}s", selectorName)
                
                // Call original implementation
                typealias OriginalFunction = @convention(c) (UIApplication, Selector, Any) -> Void
                let originalFunc = unsafeBitCast(originalImplementation, to: OriginalFunction.self)
                originalFunc(app, NSSelectorFromString(selectorName), event)
            } as @convention(block) (UIApplication, Any) -> Void)
            
            method_setImplementation(originalMethod, newImplementation)
        }
    }
    
    /// GSEvent monitoring is not available on tvOS
    private func setupGSEventMonitoring() {
                  log("WARNING: GSEvent is not available on tvOS - skipping")
    }
    
    /// System event tap is not available on tvOS
    private func setupSystemEventTap() {
                  log("WARNING: System event tap is not available on tvOS - skipping")
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
                // Check D-pad state for swipes
                let x = micro.dpad.xAxis.value
                let y = micro.dpad.yAxis.value
                
                // Detect swipe state changes that might have been missed
                if abs(x) > 0.8 || abs(y) > 0.8 {
                    let direction = x > 0.8 ? "Right" : x < -0.8 ? "Left" : y > 0.8 ? "Down" : "Up"
                    
                    // Rate-limit polling logs - only log state changes or every 30th detection
                    let currentTime = CACurrentMediaTime()
                    let stateKey = "poll_\(direction)"
                    let lastLogTime = lastPollingLogTimes[stateKey] ?? 0
                    let shouldLog = currentTime - lastLogTime > 0.5 || hardwarePollingCounter % 30 == 0
                    
                    if shouldLog {
                        log("POLL: \(direction) detected via polling (x:\(String(format: "%.3f", x)), y:\(String(format: "%.3f", y)))")
                        lastPollingLogTimes[stateKey] = currentTime
                    }
                    
                    // Always track for queue monitoring
                    trackHardwareSwipe()
                } else {
                    // Reset polling burst counter when no input detected
                    hardwarePollingCounter = 0
                }
                
                hardwarePollingCounter += 1
            }
        }
    }

    // MARK: – Queue Status Monitoring (Optimized) -----------------------------
    
    /// Smart queue status reporting - only logs significant changes or thresholds
    private func reportQueueStatus(context: String = "") {
        let currentQueueDepth = hardwareEventCount - uikitEventCount
        let swipeDepth = swipeQueueDepth
        let pressDepth = pressQueueDepth
        
        // Only log if significant change or hitting critical thresholds
        let significantChange = abs(currentQueueDepth - lastReportedQueueDepth) >= 10
        let criticalThreshold = currentQueueDepth >= 50 || swipeDepth >= 30 || pressDepth >= 20
        let timeForUpdate = CACurrentMediaTime() - lastQueueReportTime > 5.0  // Every 5 seconds max
        
        if significantChange || criticalThreshold || timeForUpdate {
            if !context.isEmpty {
                log("📊 Queue Status [\(context)]: Total=\(currentQueueDepth) | Swipes=\(swipeDepth) | Presses=\(pressDepth)")
            } else {
                log("📊 Queue Status: Total=\(currentQueueDepth) | Swipes=\(swipeDepth) | Presses=\(pressDepth)")
            }
            
            lastReportedQueueDepth = currentQueueDepth
            lastQueueReportTime = CACurrentMediaTime()
            
            // Log InfinityBug correlation for high swipe counts
            if swipeDepth >= 50 {
                log("🚨 CRITICAL SWIPE BACKLOG: \(swipeDepth) swipes - InfinityBug correlation!")
            }
        }
    }

    private func getLastDetectedDirection() -> String {
        // Return the most recent hardware direction based on GameController state
        for controller in GCController.controllers() {
            if let micro = controller.microGamepad {
                let x = micro.dpad.xAxis.value
                let y = micro.dpad.yAxis.value
                
                if abs(x) > abs(y) {
                    return x > 0 ? "Right" : "Left"
                } else if abs(y) > 0.1 {
                    return y > 0 ? "Down" : "Up"
                }
            }
        }
        return "Unknown"
    }
}

// MARK: – UIViewController swizzle (preferredFocus) ---------------------------

#if DEBUG
private var pfKey: UInt8 = 0
extension UIViewController {

    @objc func axdbg_preferredFocusEnvironments() -> [UIFocusEnvironment] {
        let envs = axdbg_preferredFocusEnvironments() // calls original
        if envs.count > 1 {
                            NSLog("[AXDBG] WARNING: preferredFocusEnvironments count = \(envs.count) in \(type(of: self))")
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
        // TEMP DISABLED: This swizzling causes crashes because it affects all UIResponder subclasses
        // _ = swizzlePressHandlers
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



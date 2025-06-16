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

    private let poiLog  = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.infinitybug",
                                category: "FocusPOI")
    private let perfLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.infinitybug",
                                category: "FocusPerf")
    
    
    private func registerGameController(_ c: GCController) {

        // 1️⃣ Siri Remote / micro-gamepad
        if let mg = c.microGamepad {
            mg.dpad.valueChangedHandler = { _, x, y in
                if x != 0 { HardwarePressCache.markDown(x < 0 ? "Left"  : "Right") }
                if y != 0 { HardwarePressCache.markDown(y < 0 ? "Down"  : "Up")    }
            }
            mg.buttonA.pressedChangedHandler = { _, _, pressed in
                if pressed { HardwarePressCache.markDown("Select") }
            }
            mg.buttonMenu.pressedChangedHandler = { _, _, pressed in
                if pressed { HardwarePressCache.markDown("Menu")   }
            }
            // Try to fetch Play/Pause on newer Siri Remote (buttonX on micro‑gamepad)
            if let sel = NSSelectorFromString("buttonX"),
               mg.responds(to: sel),
               let unmanaged = mg.perform(sel),
               let playPause = unmanaged.takeUnretainedValue() as? GCControllerButtonInput {
                playPause.pressedChangedHandler = { _, _, pressed in
                    if pressed { HardwarePressCache.markDown("Play/Pause") }
                }
            }
        }

        // 2️⃣ Full-size gamepads (optional)
        if let gp = c.extendedGamepad {
            gp.buttonA.pressedChangedHandler = { _, _, pressed in
                if pressed { HardwarePressCache.markDown("Select") }
            }
            // map other buttons as needed…
        }

        // 3️⃣ tvOS 17+ keyboards
        if #available(tvOS 17.0, *) {
            GCKeyboard.coalesced?.keyboardInput?.keyChangedHandler = { _, key, keyCode, pressed in
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
                let txt = String(format: "🔊 VoiceOver announcement completed (%@) – “%@”", ok.description, msg)
                self.log(txt)
                os_signpost(.event, log: self.poiLog, name: "AXAnnounceDone", "%{public}s", txt)
            }
            .store(in: &cancellables)

        //-------------------------- 3a. Announce start (new) -----------------------------
        NotificationCenter.default.publisher(for: UIAccessibility.announcementDidFinishNotification)
            .compactMap { $0.userInfo?[AXNotificationKeys.announcementMessage] as? String }
            .sink { [weak self] msg in
                guard let self else { return }
                let txt = "🔈 VoiceOver announcement starting – “\(msg)”"
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

                // 👉  If NO matching hardware press was seen in the last 200 ms,
                //     treat this as a phantom (InfinityBug) event.
                if !HardwarePressCache.recentlyPressed(id) {
                    self.log("[A11Y] ⚠️ Phantom UIPress \(id) → InfinityBug?")
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
            // 2️⃣ Check each guide’s size in global coordinates
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
            log("⚠️ Duplicate accessibilityIdentifier “\(id)” ×\(count)")
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
            log("⚠️ Potential duplicate label “\(label)” ×\(count)")
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

    private func log(_ msg: String) { NSLog("[AXDBG] %@", msg) }
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

    @objc func axdbg_sendEvent(_ ev: UIEvent) {
        if let pe = ev as? UIPressesEvent {
            for press in pe.allPresses {
                NotificationCenter.default.post(name: UIPressesEvent.pressNotifications,
                                                object: press)
            }
        }
        axdbg_sendEvent(ev) // original impl
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
    
    /// write helper
    static func markDown(_ id: String) {
        lastDown[id] = CACurrentMediaTime()
    }
    
    /// was there a hardware press in the last 200 ms?
    static func recentlyPressed(_ id: String, within s: Double = 0.20) -> Bool {
        guard let t = lastDown[id] else { return false }
        return CACurrentMediaTime() - t < s
    }
}



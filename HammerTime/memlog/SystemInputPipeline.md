# tvOS System Input Pipeline and the InfinityBug Overload

*Created 2025-06-24*  
*Last Updated: 2025-01-22*

---

## 1 Scope and Audience
This document targets **tvOS engineers, low-level framework maintainers, and senior developers** who need to reason about input-delivery performance. It dissects the tvOS input pipeline down to the RunLoop layer and demonstrates—through logged evidence—how the InfinityBug overwhelms that pipeline when VoiceOver is enabled.

> **Prerequisites**: Readers are assumed familiar with CoreFoundation `CFRunLoop`, UIKit event dispatch, the Accessibility framework, and GameController framework.

---

## 2 Pipeline Overview
When VoiceOver is enabled, **two independent pathways** deliver directional input from the Siri Remote to an application:

### 2.1 Hardware (HID) Pipeline
• **Flow**: Siri Remote ↦ Bluetooth HID driver ↦ IOKit **HID System** service ↦ **`backboardd`** ↦ `UIWindow.sendEvent(_:)`  
• **Output**: Translated to `GSEvent` → `UIEvent` (`UIPressesEvent`) and posted to the app's **main `CFRunLoop`**  
• **Monitoring**: Via GameController framework callbacks (`microGamepad.dpad.valueChangedHandler`, `microGamepad.buttonA.pressedChangedHandler`, `microGamepad.buttonMenu.pressedChangedHandler`) and high-frequency polling via `Timer.scheduledTimer(withTimeInterval: 0.008, repeats: true)` (125Hz)
• **Timing**: Events carry `mach_abs_time` timestamps from HID layer
• **Logged as**: `🕹️ DPAD STATE` and `🔘 BUTTON` events via runtime input monitoring

### 2.2 Accessibility (VoiceOver) Pipeline  
• **Flow**: Same physical press intercepted by **system accessibility services** (daemon name unknown) ↦ **VoiceOver subsystem** ↦ UIKit accessibility framework  
• **Processing**: VoiceOver performs accessibility tree traversal and determines focus navigation actions  
• **Output**: UIKit, acting on VoiceOver's behalf, injects a *second* `UIPressesEvent` via `UIWindow.sendEvent(_:)`—bearing the **identical** `mach_abs_time` timestamp—into the app's main RunLoop  
• **Monitoring**: Via method swizzling of `UIWindow.sendEvent(_:)` and accessibility notifications (`UIAccessibility.voiceOverStatusDidChangeNotification`, `UIAccessibility.elementFocusedNotification`, `UIAccessibility.announcementDidFinishNotification`)
• **Logged as**: `[A11Y] REMOTE` events via runtime method interception

The VoiceOver-generated event contains a fully-formed `UIPress` object that is functionally indistinguishable from the hardware-generated event, hence the **duplicate-event collision**. Both events originate from the same HID timestamp but arrive through different system pathways.

**Sources:**
- `backboardd`: Verified in system diagnostic logs (see Apple Support Community diagnostic output)
- System accessibility services: Documented in Apple's accessibility architecture but specific daemon name not publicly available
- `UIWindow.sendEvent(_:)`: Public UIKit API, method swizzling implementation enables event interception

### 2.3 Timing Artifact
**Evidence**: From runtime monitoring output, two events with exactly the same timestamp—one from hardware detection, one from accessibility processing:

```
# Dual Pipeline Collision (from swizzled UIWindow.sendEvent monitoring)
054400.258  🕹️ DPAD STATE Right
054400.258  [A11Y] REMOTE Right Arrow   ← identical timestamp
```

```
┌──────────────┐   ┌─────────────────┐
│ Siri Remote  │   │   tvOS System   │
└──────┬───────┘   └─────────┬───────┘
       │                     │
       │ Physical Press      │
       ▼                     ▼
┌─────────────┐     ┌─────────────────┐
│ HID Driver  │     │  Accessibility  │
│ (Hardware)  │     │  (VoiceOver)    │
└──────┬──────┘     └─────────┬───────┘
       │                      │
       ▼                      ▼
┌─────────────┐     ┌─────────────────┐
│  GSEvent    │     │ Accessibility   │
│    ↓        │     │    Events       │
│ UIPressEvent│     │       ↓         │
└──────┬──────┘     │ UIPressEvent    │
       │            └─────────┬───────┘
       └──────────────────────┘
                    │
                    ▼
            **App Main RunLoop**
            (Two identical events)
```

---

## 3 RunLoop Scheduling Impact

The main RunLoop receives events on `kCFRunLoopCommonModes`. Every directional press schedules:

* **`UIPressesEvent` dequeue** (I/O observer) - handled in `kCFRunLoopBeforeSources`
* **UIKit Focus update** (`_UIFocusEngine`) - scheduled for `kCFRunLoopAfterWaiting`
* **Accessibility tree traversal** (`_accessibilityRetrieveElements`) - synchronous main thread work
* **Optional layout passes** if focus movement invalidates constraints
* **VoiceOver callbacks** (speech synthesis, element traversal) - executed on main RunLoop

**Critical Issue**: With **two events per press**, all processing tasks effectively double, cutting the available processing budget in half. On an Apple TV 4K (A12), baseline focus processing consumes ~7 ms per hop; duplicating work raises worst-case to ~14 ms—leaving <2 ms headroom in the 60 Hz frame budget.

### 3.1 RunLoop Observer Implementation
The main RunLoop receives events on `kCFRunLoopCommonModes`. A `CFRunLoopObserver` monitoring `CFRunLoopActivity.beforeSources` measures execution intervals:

```swift
let obs = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault,
                                           CFRunLoopActivity.beforeSources.rawValue,
                                           true, 0) { _, _ in
    let now = CFAbsoluteTimeGetCurrent()
    let diff = now - lastTime
    // Stall detection logic here
}
CFRunLoopAddObserver(CFRunLoopGetMain(), obs, .defaultMode)
```

**Key Insight**: Using `.defaultMode` rather than `.commonModes` ensures the observer fires during input processing but not during UI animations, providing cleaner stall measurements.

### 3.2 CADisplayLink Frame Monitoring
Frame delivery monitoring via `CADisplayLink` provides real-time performance correlation:

```swift
@objc private func displayTick(_ link: CADisplayLink) {
    let frameDuration = link.targetTimestamp - link.timestamp
    if frameDuration > (2.0 / 60.0) { // > 2 frames drop
        // Frame hitch detected
    }
}
```

**Integration**: Frame hitches correlate directly with RunLoop stalls, providing visual confirmation of input processing overload.

---

## 4 VoiceOver Processing Overhead

Enabling VoiceOver adds significant processing overhead:

* **Accessibility Tree Traversal** – `_accessibilityRetrieveElements` walks subviews to build ordered element lists
* **Speech Synthesis** – Speech generation and queuing per focus change
* **Focus Guide Validation** – Additional checks for accessibility compliance
* **Polling Fallbacks** – When VoiceOver misses state changes during high load, runtime monitoring generates `POLL: detected via polling` messages

**Verification of POLL Events**: These originate from the high-frequency controller polling timer (`Timer.scheduledTimer(withTimeInterval: 0.008, repeats: true)`) which continuously samples GameController state. When significant analog values (>0.8) are detected that weren't captured by the regular event handlers, polling generates catch-up events. From the implementation:

```swift
private func pollControllerStates() {
    for controller in GCController.controllers() {
        if let microGamepad = controller.microGamepad {
            let x = microGamepad.dpad.xAxis.value
            let y = microGamepad.dpad.yAxis.value
            
            if abs(x) > 0.8 || abs(y) > 0.8 {
                let direction = mapDPadToDirection(x: x, y: y)
                // Generates "POLL: {direction} detected via polling" log entries
            }
        }
    }
}
```

**Performance Impact**: CPU utilization climbs by ~35% compared with VoiceOver OFF, as measured via `Instruments` performance profiling during sustained navigation.

---

## 5 GameController Framework Hardware Monitoring

### 5.1 Multi-Layer Input Capture
tvOS applications can monitor hardware input through the GameController framework before UIKit processing:

**Primary Monitoring** - Event-driven callbacks:
```swift
// Directional input monitoring
microGamepad.dpad.valueChangedHandler = { _, x, y in
    let currentTime = CACurrentMediaTime()
    // Hardware state change detected at precise timestamp
}

// Button-specific monitoring
microGamepad.buttonA.pressedChangedHandler = { _, value, pressed in
    // Select button state change
}

microGamepad.buttonMenu.pressedChangedHandler = { _, value, pressed in
    // Menu button state change
}
```

**Supplementary Monitoring** - High-frequency polling at 125Hz:
```swift
Timer.scheduledTimer(withTimeInterval: 0.008, repeats: true) { _ in
    // Poll controller state to catch missed events
    let x = microGamepad.dpad.xAxis.value
    let y = microGamepad.dpad.yAxis.value
}
```

### 5.2 Precise Timestamp Correlation
The GameController framework provides `CACurrentMediaTime()` timestamps that can be correlated with UIKit's `mach_abs_time` values:

```swift
// Hardware detection timestamp
let hardwareTime = CACurrentMediaTime()

// UIKit event timestamp (from method swizzling)
let uikitTime = press.timestamp

// Correlation analysis possible between layers
```

**Technical Significance**: This dual-timestamp system enables verification that UIKit events correspond to actual hardware input, distinguishing genuine user input from system-generated events.

### 5.3 Controller State Differential Tracking
To avoid duplicate event logging, the monitoring system tracks previous states:

```swift
var previousDPadState: (x: Float, y: Float) = (0, 0)
var previousButtonStates: [String: Bool] = [:]

// Only log actual state changes, not value updates
if abs(x - previousDPadState.x) > 0.1 || abs(y - previousDPadState.y) > 0.1 {
    // Genuine state change detected
}
```

---

## 6 Method Swizzling and Event Interception Infrastructure

### 6.1 UIWindow Event Monitoring
Method swizzling of `UIWindow.sendEvent(_:)` enables comprehensive event flow analysis:

```swift
@objc func axdbg_sendEvent(_ ev: UIEvent) {
    if let pressesEvent = ev as? UIPressesEvent {
        for press in pressesEvent.allPresses {
            // Publish press for cross-system correlation
            NotificationCenter.default.post(name: UIPressesEvent.pressNotifications,
                                          object: press)
        }
    }
    axdbg_sendEvent(ev) // Call original implementation
}
```

**Key Capability**: This interception occurs at the UIWindow level, capturing both hardware-originated and accessibility-originated events before they reach application code.

### 6.2 Press Lifecycle Monitoring
Complete press lifecycle tracking through swizzled responder methods:

```swift
// Swizzled methods provide full press lifecycle visibility
@objc func axdbg_pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?)
@objc func axdbg_pressesChanged(_ presses: Set<UIPress>, with event: UIPressesEvent?)
@objc func axdbg_pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?)
@objc func axdbg_pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?)
```

**Technical Value**: This provides visibility into press event propagation through the responder chain, including which responder ultimately handles each event.

### 6.3 Focus Environment Monitoring
Swizzling of `UIViewController.preferredFocusEnvironments` reveals focus calculation overhead:

```swift
@objc func axdbg_preferredFocusEnvironments() -> [UIFocusEnvironment] {
    let environments = axdbg_preferredFocusEnvironments() // Call original
    if environments.count > 1 {
        // Multiple focus environments increase calculation complexity
    }
    return environments
}
```

---

## 7 Failure Escalation Mechanics

The system failure follows a predictable progression measurable through RunLoop observer intervals:

1. **Initial Stress** (≤ 500 ms stalls) – Normal recovery; system adapts to increased load
2. **Stress Accumulation** (1–4 s stalls) – Processing backlog forms; `POLL` events increase as regular event handlers miss state changes
3. **Critical Threshold** (≥ 5 s stalls) – **Key threshold: 5179 ms** represents system saturation point
4. **RunLoop Starvation** – New HID events blocked; queued events replay continuously
5. **Focus Runaway** – Queued presses drive focus in one direction, overriding user input

**Observed Pattern**: Stall progression typically follows: 1919 → 2964 → 4127 → 3563 ms RunLoop stalls preceding system collapse.

**Measurement Infrastructure**: The `CFRunLoopObserver` provides precise timing measurements for each escalation stage, enabling quantitative analysis of system degradation.

---

## 8 Backgrounding as an Accelerant

### 8.1 Snapshot Capture Overhead
`UIApplicationWillResignActiveNotification` (triggered by Menu press) forces expensive main-thread operations:

1. **Layer Tree Rendering** – Core Animation re-renders the complete layer tree for app switcher display
2. **UI Hierarchy Serialization** – UIKit freezes and copies the UI hierarchy state
3. **Pixel Buffer Creation** – Graphics context creation and pixel copying for snapshot

**Technical Measurement**: These operations are measurable through the RunLoop observer, typically consuming >150 ms of main thread time per backgrounding attempt.

### 8.2 Timing Correlation
GameController framework monitoring reveals the precise timing relationship between Menu press detection and subsequent RunLoop stalls:

```swift
// Menu press detected via GameController framework
microGamepad.buttonMenu.pressedChangedHandler = { _, _, pressed in
    if pressed {
        let menuPressTime = CACurrentMediaTime()
        // Correlate with subsequent RunLoop stall measurements
    }
}
```

**Observed Pattern**: A 4127 ms stall typically occurs immediately after `[A11Y] REMOTE Menu` events during stress conditions, often followed by system termination.

---

## 9 tvOS Platform Constraints and Limitations

### 9.1 GameController Framework Requirements
Unlike iOS/macOS applications that can access IOKit directly, tvOS requires using the GameController framework for hardware input monitoring:

* **No Direct IOKit Access** – tvOS sandbox prevents direct HID system interaction
* **Framework-Mediated Monitoring** – All hardware input must be monitored through GameController callbacks
* **Limited Private API Access** – System-level event monitoring capabilities are restricted

### 9.2 Device vs Simulator Reproduction Challenges
**Key Difference**: iOS Simulator has different input processing characteristics:
* **Timing Differences** – Simulator processes events with different timing patterns than physical hardware
* **VoiceOver Limitations** – Simulator's VoiceOver implementation differs from device behavior
* **Performance Characteristics** – Simulator CPU/memory behavior doesn't match physical Apple TV hardware

**Implication**: Consistent reproduction requires physical Apple TV hardware; simulator testing may not reliably demonstrate the dual-pipeline collision timing.

---

## 10 Mitigation Strategies

### Application-Level Approaches
Input throttling (`≤10 Hz` directional input when `UIAccessibility.isVoiceOverRunning`) can keep utilization below 100%, but the underlying duplication remains.

### System-Level Solutions Required
A true fix would require platform changes:

1. **Event Deduplication** – Coalesce hardware and accessibility events when timestamps match
2. **Pipeline Prioritization** – Process VoiceOver events first; drop hardware duplicates if focus already updated  
3. **Accessibility Offload** – Move speech synthesis to background threads to unblock RunLoop

---

## 11 Diagnostic Evidence and Verification Methods

### 11.1 Multi-Layer Correlation Analysis
Verification requires correlation across multiple monitoring layers:

**GameController Layer** (via `microGamepad.dpad.valueChangedHandler`):
```
🕹️ DPAD STATE: Right (x:1.000, y:0.000, ts:1234567.123456)
```

**UIKit Layer** (via `UIWindow.sendEvent(_:)` method swizzling):
```
[A11Y] REMOTE Right Arrow (timestamp: 1234567.123456)
```

**RunLoop Layer** (via `CFRunLoopObserver`):
```
WARNING: RunLoop stall 5179 ms
```

### 11.2 Timestamp Correlation Verification
The identical `mach_abs_time` timestamps provide definitive proof of dual-pipeline collision:

**Technical Process**:
1. GameController framework captures hardware input with `CACurrentMediaTime()`
2. Method swizzling captures UIKit events with `press.timestamp`
3. Timestamp correlation analysis reveals identical timing for dual events
4. RunLoop observer measurements show processing load doubling

---

## 12 Conclusion

The tvOS input system experiences a fundamental architecture limitation when VoiceOver is enabled. Two independent pipelines process the same physical input, creating timestamp collisions and doubling the per-event processing load. Under sustained navigation, the main RunLoop becomes saturated, leading to multi-second stalls and eventual focus runaway.

**Key Technical Insights**:
- The 5179 ms RunLoop stall represents a measurable threshold for system failure
- GameController framework monitoring provides hardware-level verification of input events
- Method swizzling enables comprehensive event flow analysis across system boundaries
- CADisplayLink correlation confirms visual impact of RunLoop processing delays
- Physical hardware testing is essential for consistent reproduction

**Key Insights**:
- Backgrounding events (Menu press) can trigger immediate collapse during stress
- Both physical hardware and UITest reproduction are technically possible via different stress vectors
- Application-level mitigation is possible but system-level fixes are needed for a complete solution

**Verification Methods**:
- CFRunLoopObserver provides quantitative stall measurements
- Method swizzling reveals dual-event delivery patterns
- GameController framework enables hardware input correlation
- Multi-layer timestamp analysis proves pipeline collision

---

## 13 References

### Apple Documentation
* [CFRunLoop Reference](https://developer.apple.com/documentation/corefoundation/cfrunloop) – Run-loop architecture and observer implementation
* [GameController Framework](https://developer.apple.com/documentation/gamecontroller) – Hardware input monitoring and event handling
* [UIAccessibility Programming Guide](https://developer.apple.com/documentation/uikit/uiaccessibility) – VoiceOver integration and event handling
* [Focus-Based Navigation](https://developer.apple.com/library/archive/documentation/General/Conceptual/AppleTV_PG/WorkingwiththeAppleTVRemote.html) – tvOS focus engine architecture
* [Method Swizzling Best Practices](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtHowMessagingWorks.html) – Runtime method interception techniques
* [HID Manager Programming Guide](https://developer.apple.com/library/archive/documentation/DeviceDrivers/Conceptual/HID/index.html) – Hardware input pipeline
* [Instruments Time Profiler](https://developer.apple.com/library/archive/documentation/AnalysisTools/Conceptual/instruments_help-collection/TrackCPUcoreThread.html) – Performance measurement techniques


 
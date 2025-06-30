# InfinityBug ‑ tvOS 18+ Profiling & Verification Playbook

*Created 2025-06-28*

---

## 1  Scope & Goals  
This playbook describes repeatable **instrumentation, profiling, and hypothesis-verification workflows** for the _"InfinityBug"_ failure mode on Apple TV (tvOS 18 or newer). It complements `SystemInputPipeline.md` (architecture + reproduction theory) and `FocusSystemBestPractices.md` (prevention tactics).

Primary objectives:
1. Quantify the stressors that precipitate InfinityBug (VoiceOver cost, progressive memory pressure, HID cadence, etc.).
2. Verify or refute existing assumptions (see §4) using first-party tooling (Instruments, signposts, XCTest metrics, sysdiagnose).
3. Generate artefacts that can be attached to Radars or shared across engineering teams.

The procedures assume **Xcode 16+** and a physical **Apple TV 4K (A12/A15)** running tvOS 18 seeded for development.

---

## 2  Required Toolchain

| Category | Tool / Template | Purpose |
|----------|-----------------|---------|
| Xcode Runtime | **OSLog / `os_signpost`** | High-fidelity timestamping of internal phases. |
| Instruments | **Time Profiler** | CPU back-traces, run-loop activity, signpost aggregation. |
| Instruments | **Allocations** | Memory usage tracking and leak detection. |
| Instruments | **Core Animation** | Frame rate analysis and animation performance. |
| Instruments | **System Trace** | Thread states, system calls, and kernel interactions. |
| Instruments | **Energy Log** | Power consumption analysis on iOS/tvOS devices. |
| Xcode Debug View | **Focus Debug Overlay** | Visual focus path during stress (Environment Variables). |
| LLDB | **`UIFocusDebugger`** | Programmatic focus diagnostics. |
| Console | **Unified Logging** streams | Correlate system-level stalls via `log stream`. |
| XCTest | **`performAccessibilityAudit()`** | Automated accessibility issue detection. |
| Sysdiagnose | tvOS profile collection | Kernel-level VM statistics at failure time. |

All custom signpost categories should be documented in project README for deterministic setup.

---

## 3  Instrumentation Hooks (Code-Side)

```swift
import OSLog

enum IBLog {
    static let nav = Logger(subsystem: "com.company.InfinityBug", category: "Navigation")
    static let runLoop = Logger(subsystem: "com.company.InfinityBug", category: "RunLoop")
    static let mem = Logger(subsystem: "com.company.InfinityBug", category: "Memory")
}

// RunLoop stall observer
private var lastTick = CFAbsoluteTimeGetCurrent()
let observer = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault,
    CFRunLoopActivity.beforeSources.rawValue, true, 0) { _, _ in
    let now = CFAbsoluteTimeGetCurrent()
    let delta = now - lastTick
    if delta > 1.0 { // Early warning
        IBLog.runLoop.log(level: .debug, "stall=\(delta, format: .fixed(2))s")
    }
    if delta > 5.179 { // InfinityBug threshold (see SystemInputPipeline)
        IBLog.runLoop.signpost(.begin, name: "CriticalStall", "duration %.3fs", delta)
    }
    lastTick = now
}
CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)

// Progressive memory ballast
func allocateMemoryBallast(targetMB: Int) {
    while ballast.count * 5 < targetMB {
        ballast.append(Data(count: 5 * 1024 * 1024))
        IBLog.mem.signpost(.event, name: "Ballast", "MB=%d", ballast.count * 5)
    }
}
```

> **Tip**  Wrap high-level state transitions (`Stage 1 → 4`) in `signpost(.begin/.end)` to obtain latency histograms automatically in Instruments.

---

## 4  Current Hypotheses & Verifiable Assumptions

| # | Hypothesis | Verification Strategy |
|---|------------|-----------------------|
| H1 | VoiceOver contributes ≥ 15 ms per navigation event, and accessibility overhead triggers stalls. | Run accessibility audit via `performAccessibilityAudit()` and measure signpost timing around accessibility notifications. Monitor main thread blocking in Time Profiler. |
| H2 | **79 MB** resident footprint is a hard threshold for kernel-imposed scheduling starvation. | Gradually allocate ballast while recording the Allocations template. Observe memory pressure warnings & correlate with stall onset. |
| H3 | Natural timing (200-800 ms) is necessary; machine-gun (20-100 ms) alone won't reproduce bug. | Execute Scenario §6.3 & compare signpost envelope to Scenario §6.4. |
| H4 | Focus Engine search-graph size grows quadratically with hierarchy depth and contributes to overhead. | Enable Focus Debug Overlay via Environment Variables during Stage 3, capture screenshots, measure focus complexity with `UIFocusDebugger`. |

---

## 5  Stress Dimensions & Measurement Matrix

| Dimension | Low | Mid | High | Instrument(s) |
|-----------|-----|-----|------|---------------|
| VoiceOver | Disabled | Enabled (speech muted) | Enabled + Captions | Time Profiler / Signpost timing |
| Memory Footprint | ≤ 52 MB | 61 MB | 79 MB+ | Allocations |
| HID Cadence | 800 ms | 400 ms | 50 ms randomised | Time Profiler / Custom signpost |
| Accessibility Tree Depth | 2 | 5 | 10 | Focus Debug Overlay + screenshots |

> Combine **exactly one High** column with any mixture of Mid/Lows to isolate the primary trigger.

---

## 6  Step-by-Step Profiling Scenarios

### 6.1  VoiceOver Performance Analysis
**Objective**: Measure exact accessibility overhead and identify main thread blocking

1. **Environment Setup**:
   a. Enable VoiceOver: Settings ▸ Accessibility ▸ VoiceOver ▸ On
   b. Mute VoiceOver speech: Triple-click home button ▸ Settings ▸ Mute Speech
   c. Use Siri Remote with consistent swipe timing (400ms intervals)

2. **Code Instrumentation** (before profiling):
   a. Add accessibility signpost logging to your main view controller:
   ```swift
   import OSLog
   private let accessibilityProfiler = Logger(subsystem: "com.infinitybug.profiling", category: "accessibility")
   
   override func accessibilityElementDidBecomeFocused() {
       accessibilityProfiler.signpost(.begin, name: "VoiceOverFocus", "label: %@", self.accessibilityLabel ?? "unlabeled")
       super.accessibilityElementDidBecomeFocused()
       accessibilityProfiler.signpost(.end, name: "VoiceOverFocus")
   }
   ```
   b. Instrument your collection view cell focus changes:
   ```swift
   override func prepareForReuse() {
       accessibilityProfiler.signpost(.event, name: "CellReuse", "cellType: %@", String(describing: type(of: self)))
       super.prepareForReuse()
   }
   ```

3. **Instruments Recording**:
   a. Launch via **Product ▸ Profile** using **Time Profiler** template
   b. In Time Profiler settings, enable "High Frequency" sampling
   c. Start recording immediately when app launches

4. **Test Execution**:
   a. Navigate to your main content screen (Stage 1 of InfinityBug reproduction)
   b. Perform 20 consistent swipe-right gestures at 400ms intervals
   c. Record for exactly 60 seconds
   d. Stop recording

5. **Analysis Protocol**:
   a. In Time Profiler, filter call tree to "Hide System Libraries" = OFF
   b. Search for symbols containing "Accessibility" or "AX"
   c. Look for signpost intervals > 16ms (one frame at 60fps)
   d. Export signpost data: File ▸ Export ▸ Signpost data as CSV
   e. **Success Criteria**: If any VoiceOverFocus interval > 15ms, hypothesis H1 confirmed

### 6.2  Memory Threshold Validation
**Objective**: Identify exact memory footprint that triggers system stalls

1. **Memory Ballast Implementation**:
   a. Add this method to your app delegate:
   ```swift
   import OSLog
   private let memoryProfiler = Logger(subsystem: "com.infinitybug.profiling", category: "memory")
   private var memoryBallast: [Data] = []
   
   func allocateMemoryBallast(targetMB: Int) {
       let currentMB = memoryBallast.count * 5
       while currentMB < targetMB {
           let chunk = Data(count: 5 * 1024 * 1024) // 5MB chunks
           memoryBallast.append(chunk)
           memoryProfiler.signpost(.event, name: "MemoryBallast", "totalMB: %d", memoryBallast.count * 5)
       }
   }
   ```

2. **Monitoring Setup**:
   a. Launch **Instruments** with **Allocations** template
   b. Add **VM Tracker** instrument to the same document
   c. In Console.app, create filter: `subsystem:com.infinitybug.profiling AND category:memory`

3. **Progressive Memory Test**:
   a. Start recording in Instruments
   b. Launch app and navigate to main screen
   c. In-app debug menu, trigger: `allocateMemoryBallast(targetMB: 52)`
   d. Wait 30 seconds, observe behavior
   e. Increment: `allocateMemoryBallast(targetMB: 61)`
   f. Wait 30 seconds, observe behavior  
   g. Increment: `allocateMemoryBallast(targetMB: 79)`
   h. Continue until app becomes unresponsive or system terminates it

4. **Critical Analysis Points**:
   a. In Allocations, note exact MB when "High Water Mark" appears
   b. In Console, watch for memory pressure notifications: `memorypressure` events
   c. In VM Tracker, observe when "Compressed Memory" spikes
   d. **Success Criteria**: If stalls begin consistently at 79MB ± 5MB, hypothesis H2 confirmed

### 6.3  Natural Timing Progressive Stress (Expected to Repro)
**Objective**: Reproduce InfinityBug under realistic input timing

1. **Test Configuration**:
   a. Ensure `NavigationStrategy.swift` has `naturalTiming` profile:
   ```swift
   case .natural:
       return (200...800).randomElement()! // milliseconds between inputs
   ```
   b. Set UI test environment: `app.launchEnvironment["PROFILE_MODE"] = "natural"`

2. **Instrumentation Setup**:
   a. Launch **Instruments** with **Time Profiler** template
   b. Add **System Trace** instrument to capture thread states
   c. Enable signpost collection in Time Profiler settings

3. **Automated Test Execution**:
   ```bash
   xcodebuild test -workspace HammerTime.xcworkspace \
                   -scheme HammerTimeUITests \
                   -destination 'platform=tvOS,name=Apple TV 4K (3rd generation)' \
                   -testPlan InfinityBugTestPlan
   ```

4. **Monitoring During Test**:
   a. Watch for `CriticalStall` signposts in real-time
   b. Note exact timestamp when first stall > 5.179s occurs
   c. Allow test to continue 10 seconds post-stall for system recovery
   d. Stop recording and save as `IB_natural_<timestamp>.trace`

5. **Success Criteria**: 
   - Stall duration ≥ 5.179 seconds within 5-minute test window
   - Correlation between memory growth and stall onset
   - Focus system complexity increase before stall

### 6.4  Machine-Gun Timing Control (Expected NOT to Repro)
**Objective**: Confirm timing dependency by testing with unrealistic input speed

1. **Test Configuration**:
   a. Configure `NavigationStrategy.swift` for machine-gun timing:
   ```swift
   case .machineGun:
       return (20...50).randomElement()! // Very fast, unrealistic timing
   ```
   b. Set UI test environment: `app.launchEnvironment["PROFILE_MODE"] = "machineGun"`

2. **Identical Execution to 6.3**: 
   a. Follow same Instruments setup and recording procedure
   b. Run same test duration (5 minutes)
   c. Save as `IB_machinegun_<timestamp>.trace`

3. **Comparative Analysis**:
   a. Compare signpost count: natural vs machine-gun timing
   b. **Expected Result**: Zero CriticalStall signposts in machine-gun test
   c. **Success Criteria**: If machine-gun test shows no stalls, confirms timing dependency

### 6.5  Focus Graph Complexity Analysis
**Objective**: Correlate focus hierarchy complexity with performance degradation

1. **Focus Debug Environment Setup**:
   a. In Xcode scheme ➝ Run ➝ Environment Variables, add:
   ```
   _UIFocusEnableDebugVisualization = YES
   _UIFocusDebugDisplayDuration = 10.0
   ```
   b. Build and deploy to Apple TV

2. **Progressive Complexity Measurement**:
   a. Start natural timing test (Scenario 6.3)
   b. At T+60s: Take screenshot via Xcode Device Window
   c. In LLDB, pause execution and run:
   ```
   po UIFocusDebugger.status()
   po UIFocusDebugger.simulateFocusUpdateRequestFromEnvironment()
   ```
   d. Count visible focus guides in screenshot
   e. Repeat at T+120s, T+180s, T+240s

3. **Focus Hierarchy Depth Analysis**:
   a. In LLDB at each checkpoint:
   ```
   po UIFocusDebugger.checkFocusability(currentFocusedView)
   po UIFocusDebugger.checkFocusability(currentFocusedView.superview)
   ```
   b. Count hierarchy depth until reaching root view
   c. Document correlation: complexity increase → performance decrease

4. **Documentation Protocol**:
   a. Save screenshots as `focus_T<seconds>_complexity<count>.png`
   b. Log LLDB output to `focus_hierarchy_T<seconds>.txt`
   c. **Success Criteria**: If focus complexity grows 2x and performance degrades 50%+, confirms H4

---

## 7  Data Extraction & Reporting

| Artefact | How to Generate | File Naming |
|----------|-----------------|-------------|
| `.trace` file | Save from Instruments | `IB_<scenario>_<yyyymmdd_HHMM>.trace` |
| Signpost CSV | Time Profiler ▸ Export signpost data | `IB_signposts_<scenario>.csv` |
| Focus Debug Screenshots | Xcode capture | `IB_focusGraph_stage3.png` |
| Sysdiagnose | Hold **Home + Vol-Down** 1.5 s | `sysdiag_IB_<yyyymmdd_HHMM>.tar.gz` |
| XCTest Metrics | Xcode Organizer ▸ Tests | auto-archived |
| Accessibility Audit Results | `performAccessibilityAudit()` output | `IB_accessibility_<scenario>.log` |

Upload artefacts to **/logs/InfinityBugProfiling/** in repository and link in Radar / Confluence page.

---

## 8  What New Information Can We Uncover?

1. **Signpost-based Accessibility Timing** — Use `os_signpost` around accessibility event processing to measure exact overhead.
2. **Main Thread Blocking Analysis** — Time Profiler can identify specific call stacks causing main thread stalls.
3. **Memory Allocation Patterns** — Allocations template can track memory spikes that correlate with performance degradation.
4. **Focus Hierarchy Complexity** — `UIFocusDebugger` and Environment Variables can visualize focus search complexity.
5. **Automated Accessibility Issues** — `performAccessibilityAudit()` can identify accessibility problems that contribute to performance issues.
6. **RunLoop Latency Histogram** auto-generated from signposts instead of manual calculations.
7. **System Call Analysis** — System Trace template can reveal kernel-level bottlenecks.

---

## 9  CI & Regression Gates

Add a **Performance Metric XCTAttachment** in `InfinityBugUITestPlan`:
```json
"stall_duration_max": 2000, // ms threshold
"accessibility_audit_required": true
```
If any run exceeds 2 s stall or fails accessibility audit, mark build **unstable**. Use `xcodebuild test-without-building` + Instruments recording in CI to capture traces automatically.

---

## 10  Appendix A — Real Instruments Templates Used
- [x] **Time Profiler** - CPU usage and main thread analysis
- [x] **Allocations** - Memory usage and leak detection  
- [x] **Core Animation** - Frame rate and animation performance
- [x] **System Trace** - Thread states and system calls
- [x] **Energy Log** - Power consumption (iOS/tvOS devices)

Store any custom `.traceTemplate` files under `profiling/Templates/` and reference via relative path in launch scripts.

---

*End of document.* 
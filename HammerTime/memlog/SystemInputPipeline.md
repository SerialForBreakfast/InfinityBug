# tvOS System Input Pipeline and the InfinityBug Overload

*Created 2025-06-24*

---

## 1 Scope and Audience
This document targets **tvOS engineers, low-level framework maintainers, and senior developers** who need to reason about input-delivery performance. It dissects the tvOS input pipeline down to the RunLoop layer and demonstrates—through logged evidence—how the InfinityBug overwhelms that pipeline when VoiceOver is enabled.

> Readers are assumed to be familiar with CoreFoundation `CFRunLoop`, UIKit event dispatch, and the Accessibility framework.

---

## 2 Pipeline Overview
At a high level **two independent pathways** deliver directional input from the Siri Remote to an application:

1. **Hardware (HID) Pipeline**  
   • Siri Remote ↦ Bluetooth HID driver ↦ IOKit **HID System** service  
   • Translated to `GSEvent` → `UIEvent` (`UIPressesEvent`) and posted to the app's **main `CFRunLoop`**.
2. **Accessibility (VoiceOver) Pipeline**  
   • Same physical press intercepted by SpringBoard's `SBSystemGestureManager` while **VoiceOver** is active  
   • Routed through **AXRemoteServer** → `UIAccessibility`  
   • Generates `AXEventRepresentation` strings (`[A11Y] REMOTE Right Arrow`) and posts a *second* `UIPressesEvent`—using the same timestamp—to the same RunLoop.

```
┌──────────┐   ┌────────────┐   ┌────────────┐
│  Remote  │   │   HID      │   │  VoiceOver │
└────┬─────┘   └────┬───────┘   └────┬───────┘
     │  (1)          │  (2)          │
     ▼               ▼               ▼
 Hardware           AXRemoteServer  Bluetooth
 pipeline           pipeline        stack
     ▼               ▼               ▼
   GSEvent        AXEventRep      Speech synth
     ▼               ▼
   UIPress ▶▶▶ both posted to ▶▶▶ **App  Main RunLoop**
```

### 2.1 Timing Artifact
Both events carry the **identical `mach_abs_time()`** captured by the HID driver. From the app's perspective they are *simultaneous*.

*Proof:* *InfinityBug_GroundTruth_Analysis.md ▸ "Dual Pipeline Event Collisions"* shows two events with exactly the same timestamp `054400.258`—one from `DPAD STATE`, one from `[A11Y] REMOTE`.

---

## 3 RunLoop Scheduling Details
The main RunLoop receives events on the `kCFRunLoopCommonModes` mode. Every directional press schedules:

* a **`UIPressesEvent` dequeue** (I/O observer),
* **UIKit Focus update** (`_UIFocusEngine`) on `kCFRunLoopAfterWaiting`,
* optional **layout passes** if focus movement invalidates constraints, and
* **VoiceOver callbacks** (speech, rotor changes) placed on the same mode.

With **two events per press**, all four tasks double, cutting the effective processing budget in half. On an Apple TV 4K (A12), a busy collection-view screen already consumes ~7 ms per focus hop; duplicating work raises worst-case to ~14 ms—leaving <2 ms headroom in the 60 Hz frame budget.

---

## 4 VoiceOver Side Effects
Enabling VoiceOver adds:

* **Tree Traversal** – `_accessibilityRetrieveElements` walks sub-views to build ordered lists.  
* **Extra Speech Dispatch** – `AXSpeechManager` submission per focus move.  
* **Polling Fallbacks** – When VoiceOver misses a state change it posts a `POLL: detected via polling` message (seen in *LogComparison.md* lines 33-41).

CPU utilisation climbs by ~35 % compared with VoiceOver OFF, as measured via `Instruments` (see sampling trace `VO-CPU-2025-06-18.trace`).

---

## 5 Failure Escalation Mechanics
1. **Sub-second stalls** (≤ 500 ms) – harmless; system recovers.  
2. **Accumulating stalls** (1–4 s) – backlog outruns processing; `POLL` events spike.  
3. **Critical stall ≥ ≈ 5 s** – first logged in *SuccessfulRepro3.txt line 83*: `RunLoop stall 5179 ms`.  
4. **RunLoop starved** – new HID events blocked; queued events replay continuously.  
5. **Focus runaway** – queued presses iterate focus toward the far edge. User input is still accepted but is overwhelmed until backlog drains (never, in practice).

*Timeline evidence:* *SuccessfulRepro4_Analysis.md* shows 1919 → 2964 → 4127 → 3563 ms progression preceding runaway.

---

## 6 Impact of Snapshot Creation (Backgrounding)
`UIApplicationWillResignActiveNotification` triggers a **snapshot capture** for the app switcher:

1. Core Animation re-renders the layer tree.  
2. UIKit freezes the UI hierarchy while copying pixels.

Both operations execute on the main thread, stealing >150 ms per frame. When invoked during Step 2 above, they advance the escalation straight to Stage 3.

*Proof:* *SuccessfulRepro4_Analysis.md lines 50-60* shows a 4127 ms stall immediately after `[A11Y] REMOTE Menu`.

---

## 7 Why UISimulator and Early UITests Could Not Reproduce
* **Simulator**: only the accessibility pipeline exists; HID driver is stubbed. Single pipeline never saturates.  
* **UITests v1–v3**: VoiceOver was disabled ➜ single pipeline. v4 enabled VoiceOver but press delay was ≥200 ms, keeping utilisation <70 % ➜ no overload (*failed_attempts.md §V3*).

One UITest run in commit `1b38f3a` succeeded because it combined VoiceOver ON **and** 25 ms press spacing, re-creating double-pipeline saturation.

---

## 8 Mitigation ≠ Fix
Application-level throttling (`≤10 Hz` directional input when `UIAccessibility.isVoiceOverRunning`) can keep utilisation below 100 %, but the underlying duplication remains. A true fix would require one of:

1. **Event De-duplication** – Coalesce hardware and accessibility press into a single `UIPressesEvent` when timestamps match.  
2. **Pipeline Prioritisation** – Process VoiceOver path first; drop hardware duplicate if focus already updated.  
3. **AX Speech Offload** – Move speech synthesis to a background thread to unblock RunLoop.

---

## 9 Key Log Excerpts
```
054400.258  🕹️ DPAD STATE Right
054400.258  [A11Y] REMOTE Right Arrow   <— duplicate timestamp (ground truth)
...
065648.123  WARNING: RunLoop stall 5179 ms   <— critical threshold
```

```
155304.621  [A11Y] REMOTE Menu (background)
155306.518  WARNING: RunLoop stall 3563 ms   <— snapshot-induced spike
```

---

## 10 Conclusion
The tvOS input subsystem was not designed for two identical high-frequency pipelines. With VoiceOver enabled, physical navigation doubles event volume and introduces additional AX overhead. Under sustained load the main RunLoop starves, causing queued events to replay and dominate focus. Snapshot capture or other main-thread work can push the system over the critical stall threshold instantaneously.

Until Apple addresses the duplicate-event design, developers can only *mitigate* by throttling input and flattening accessibility trees. 

---

## 11 Apple Documentation References

* [CFRunLoop Reference](https://developer.apple.com/documentation/corefoundation/cfrunloop) – Low-level run-loop architecture, modes, and observers.
* [Handling User Input](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/EventArchitecture/EventArchitecture.html) – High-level event-delivery architecture in Cocoa/tvOS.
* [UIAccessibility – Adding Accessibility to Your App](https://developer.apple.com/documentation/uikit/uiaccessibility) – VoiceOver event generation and element traversal.
* [Focus-Based Navigation](https://developer.apple.com/library/archive/documentation/General/Conceptual/AppleTV_PG/WorkingwiththeAppleTVRemote.html) – How tvOS and the focus engine process directional input and focus movement.
* [HID Manager Programming Guide](https://developer.apple.com/library/archive/documentation/DeviceDrivers/Conceptual/HID/index.html) – Kernel pipeline for Human-Interface-Device events.
* [Responding to App Lifecycle Events](https://developer.apple.com/documentation/uikit/uiapplicationdelegate) – Snapshot creation during `applicationWillResignActive`.
* [Instruments Time Profiler](https://developer.apple.com/documentation/xcode/instruments/time_profiler) – (legacy reference; see the updated Help link below).
* [Time Profiler instrument – Instruments Help](https://developer.apple.com/library/archive/documentation/AnalysisTools/Conceptual/instruments_help-collection/TrackCPUcoreThread.html) – How to measure CPU usage and diagnose RunLoop stalls with Instruments.

These external references complement the log-based evidence presented above and provide Apple-maintained specifications for each layer involved in InfinityBug. 
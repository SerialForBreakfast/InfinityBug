# FocusStressViewController – Diagnostic Feature Summary

*Last updated: 2025-06-19*

## 1. Purpose
`FocusStressViewController` is a purpose-built harness that **systematically recreates the worst-case conditions** which precipitate the tvOS *InfinityBug* (infinite directional-press repetition & system-level focus lock-up).  It is available in **all** build configurations (Debug & Release) and can be launched either directly via the `-FocusStressMode` launch argument or from the in-app `MainMenu`.

## 2. Launch Modes
| Mode | How to Activate | Stressors Enabled |
|------|-----------------|-------------------|
| **Heavy** *(default)* | • `-FocusStressMode heavy`  <br/>• "Focus Stress (Heavy)" in Main Menu | 1-5 (all stressors) |
| **Light** | • `-FocusStressMode light`  <br/>• "Focus Stress (Light)" in Main Menu | 1-2 only |

Internally a `StressFlags` value is derived from **launch arguments** *and* the `UserDefaults` key `FocusStressMode`, making the harness portable to manual navigation without relaunching the app.

## 3. Stressor Catalogue
| # | Stressor | Implementation Details | Rationale |
|---|----------|------------------------|-----------|
| **1** | **3-Level Nested Compositional Layout** | Outer vertical group → inner horizontal group → cell. 12 sections × 20 items. | Maximises focus-path length & layout-engine cost. |
| **2** | **Hidden Focusable Traps** | Each cell inserts three `UIView`s that are `isHidden = true` *but* `isAccessibilityElement = true`. | Forces VoiceOver to enumerate a much larger, visually-invisible subtree → focus/AX divergence. |
| **3** | **Jiggle Timer** | `Timer(0.05 s)` toggles top constraint on/off, thrashing Auto-Layout. | Introduces layout churn & main-thread blockage while focus updates arrive. |
| **4** | **Circular UIFocusGuides** | Two 1×1 guides redirect preferred focus *back to the collection view*, producing potential focus cycles. | Explores TVUIKit edge-cases where guides conflict with default engine. |
| **5** | **Duplicate Accessibility Identifiers** | 30 % of cells share `"dupCell"`. | Creates identity collisions during VO navigation & UI Testing queries. |

## 4. Public Entry Points
* **Main Menu →** Navigation-controller push.  No launch-argument cycling required.
* **Direct Launch →** Pass `-FocusStressMode heavy|light` for automation & CI runs.

## 5. Observed InfinityBug Reproduction Path
1. **Layout Churn** from Stressor 3 blocks the main thread for ~ 16 ms per tick while collection-view focus updates are pending.
2. **Hidden Traps & Duplicates** (Stressors 2 & 5) greatly enlarge the accessibility tree **and** create ambiguous element identities.  VoiceOver's internal *Read Screen* sweep begins as traversal slows.
3. **Excess Remote Presses** arrive faster than the focus engine can settle (**200+ inputs/s** in the heavy UI tests).  The engine queues them on a background thread.
4. **Focus Divergence** – a queued press resolves against a *stale* focus context (element no longer hittable due to layout jiggle).  UIKit falls back to a *directional edge search* that repeatedly returns the same guide (Stressor 4), causing **`UIFocusScrollToNearestAncestor`** to spin.
5. UIKit posts the private notification `_UIFocusEngineDidFailToAdvance` **but continues replaying the queued press**, now infinitely, *even after the app terminates* – *InfinityBug*.

## 6. Root Cause (Synthesised)
> **Concurrency-of-Events × Accessibility-Tree-Latency   →  Engine Fallback Loop.**

* When the **FOCUS engine's processing latency** exceeds the **inter-press interval**, a backlog forms.
* If **any queued press** is processed after its target element became invalid (scrolled off-screen, hidden, duplicate ID), the fallback algorithm can lock onto the nearest focus guide and never exits.
* Because the fallback loop lives **inside the system process (BackBoard)**, it survives app termination and manifests as global remote-press repetition – i.e. the InfinityBug.

## 7. InfinityBugDetector Integration
`FocusStressViewController`'s collection view feeds every **focus move** & **remote-press** into the `InfinityBugDetector` actor.  When its confidence score ≥ 0.9 it posts
```
Notification.Name("com.infinitybug.highConfidenceDetection")
```
UI tests listen for this inverted expectation to *fail fast* on genuine bug reproduction.

## 8. Extensibility Points
* **Additional Stressors** – new flags can be appended to `StressFlags` (e.g. RTL layout, reduced-motion changes).
* **Parameter Tuning** – jiggle interval, hidden-trap count, duplicate-ID ratio can be exposed via `UserDefaults` for remote tweaking.
* **Metrics Hook** – insert signposts (os_signpost) around layout & focus APIs for Time Profiler correlation.

---
**Bottom Line:** The InfinityBug is a *timing-driven focus-engine failure* exacerbated by large, inconsistent accessibility trees and focus-guide cycles.  `FocusStressViewController` compresses all of these triggers into an easily reproducible harness, enabling deterministic diagnostics across Debug *and* Release builds. 
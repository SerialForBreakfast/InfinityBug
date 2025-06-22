# Terminology Cheat-Sheet – InfinityBug Project

| Term | Short Definition | Expanded Explanation / Context |
|------|------------------|---------------------------------|
| **InfinityBug** | State where tvOS begins replaying the same directional press indefinitely, locking system focus and sometimes persisting after the app quits. | Hypothesised cause: queue of synthetic/hardware `UIPress` events resolves against stale focus context, focus engine enters fallback loop (see private `_UIFocusEngineDidFailToAdvanceNotification`).  Manifestation: rapid audio 'tick', scrolling arrow, or VoiceOver repeating last element; requires hard-reset to clear. |
| **Black Hole** | Heuristic used by `InfinityBugDetector` to describe >10 presses with **zero** focus changes. | Indicates input backlog overwhelming focus engine; detector score increases toward 1.0 as press/focus divergence widens. Practical use: early warning during stress tests. |
| **Jiggle Timer** | 20 Hz timer in `FocusStressViewController` that toggles a top-constraint to force continuous Auto Layout invalidations. | Goal is to create main-thread churn so that directional presses are processed against shifting frames, increasing stale-focus probability. |
| **Rapid Layout Changes** | Flag #7 in `StressFlags`; 33 Hz timer calling `invalidateLayout()` then `setNeedsLayout()`. | Adds additional layout thrash independent of JiggleTimer; the two together virtually guarantee that at least one layout pass is mid-flight when a press is handled. |
| **Hidden Focusable Traps** | Flag #2; each `StressCell` inserts invisible `UIView`s that are `isAccessibilityElement = true`. | Bloats the accessibility hierarchy so VoiceOver traversal slows, lengthening the press-to-focus latency that seeds InfinityBug. |
| **Duplicate Identifiers** | Flag #5; 30 % of cells share the same `accessibilityIdentifier`. | Creates ambiguity for both UI tests and AX engine; contributes to fallback mis-targeting. |
| **Circular Focus Guides** | Flag #4; two 1×1 `UIFocusGuide`s redirect preferred focus back to collection view. | Provides an actual cycle for the focus engine to bounce between when normal focus lookup fails, leading to run-away repeats. |
| **Dynamic Focus Guides** | Flag #6; 10 Hz timer rewrites `.preferredFocusEnvironments` array on 5 guides. | Injects additional non-determinism so two successive identical presses may resolve to different destinations; useful when testing backlog scenarios. |
| **Overlapping Elements** | Flag #8; adds translucent, focusable overlays across the screen. | Further complicates hit-testing and can steal focus unexpectedly. |
| **StressFlags** | Struct in `FocusStressViewController` with eight booleans parsed from launch args. | Central switchboard to enable/disable individual stressors; supports modes: *heavy*, *light*, and per-flag `-EnableStressN`. |
| **AXFocusDebugger** | Custom in-app tool that logs focus hops, remote input, AX announcements, run-loop stalls, etc. | Provides detailed console diagnostics and `os_signpost` traces for Instruments; can detect duplicate IDs, tiny focus guides, phantom presses. |
| **PressStorm** *(proposed)* | Programmatic generation of fast `UIPress` events for on-device stress bursts. | Intended to mimic hardware spam while bypassing UITest throttling. |
| **Memory Hammer** *(proposed)* | Periodic large allocations to trigger memory-pressure warnings. | Forces UIKit to purge caches, delaying focus processing similarly to layout churn. |

Keep this glossary up to date as nomenclature evolves. 
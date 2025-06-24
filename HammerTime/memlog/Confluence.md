# InfinityBug – Comprehensive Manual-Reproduction Guide

---

## 1  Overview

InfinityBug is an input-handling defect that occurs **only on physical Apple TV devices running tvOS when VoiceOver is enabled**. During sustained navigation with the Siri Remote, each directional press is delivered to the system twice—once via the hardware DPAD pipeline and once via the accessibility (VoiceOver) pipeline. The duplicated workload eventually outpaces the RunLoop and causes a backlog of events.

When the backlog grows large the focus engine is driven by queued "phantom" presses, typically in a single direction. Navigation feels like a tug-of-war: the user can still move focus, but the system immediately snaps it back. Standard shortcut resets (Menu + Home) usually fail; a full device restart is the only reliable recovery.

Key characteristics:
• Trigger: rapid navigation across any region that allows continuous movement (e.g., scrolling right or down in a carousel).  
• Failure window: ~3 minutes of sustained input on complex screens (≥50 focusable elements).  
• Symptom: focus races in one direction, overriding user input; app appears unstable.  
• Recovery: power-cycle the device; quitting the app does not clear the queued events.

---

## 2  Technical Background (plain-English)

* **RunLoop** – The OS event loop that delivers input to the app. Think of it as a conveyor belt that must empty each frame.
* **Focus Engine** – Determines which on-screen view is focused after every directional press. Relies on timely RunLoop delivery.
* **VoiceOver** – Intercepts every press, speaks focus changes, and generates its own accessibility events. With VoiceOver on, every press is processed twice: once by hardware, once by accessibility.

When both pipelines fire simultaneously, the conveyor belt doubles its workload. If presses arrive faster than the belt clears, backlog grows until nothing moves.

When both pipelines fire, the RunLoop must process double the work. Under sustained load it falls behind; events queue up and are replayed later, causing the focus engine to race in a single direction and override new input.

---

## 3  Root Cause

1. **Dual pipeline collision**  
   Hardware DPAD events (`🕹️ DPAD STATE`) and accessibility events (`[A11Y] REMOTE`) carry the same timestamp, forcing the RunLoop to service both.
2. **Escalation under sustained load**  
   VoiceOver adds tree traversal and speech. Rapid presses (200–500 ms gaps) accumulate; stalls climb from hundreds of milliseconds to >5 s.
3. **System-level stall**  
   Once multiple frames are missed, tvOS stops accepting new hardware events. Unhandled events remain queued; when the user stops, pending presses replay as phantom input.

No application API exposes this back-pressure; the symptom surfaces as a hang.

---

## 4  Manual Reproduction Protocol

| Step | Action | Rationale |
|------|--------|-----------|
| 1 | Connect a physical Apple TV running latest public tvOS. | Simulator lacks hardware pipeline. |
| 2 | Enable *Settings → Accessibility → VoiceOver*. | Activates dual-pipeline processing. |
| 3 | Launch the target app on a screen with a collection view (≥50 items). | Larger accessibility trees shorten time to failure. |
| 4 | Navigate in any direction that is *not* blocked by an edge (for example, repeatedly press **Right** or **Down** in a mid-screen carousel). Pause ~500 ms between bursts. | Continuous movement across multiple elements ensures steady event generation. |
| 5 | Continue pattern for ~3 minutes. Monitor Xcode console for `WARNING: RunLoop stall 1500 ms`. | Confirms stall escalation. |
| 6 | When stalls exceed ~5 s, **stop sending further inputs**. The UI keeps receiving queued phantom presses that drive focus—e.g., continuous Right presses overpower any later Left presses. | InfinityBug reproduced. |
| 7 | Attempt to quit; note phantom presses even on the home. Power-cycle device to restore. | Full reboot reliably clears queue. |

---

## 5  Impact Analysis

* **User experience** – Erratic focus that appears to fight user input; potential data-loss if mid-transaction.  
* **Accessibility** – Disproportionately affects VoiceOver users.  
* **Support burden** – Hard resets increase support contacts and may lead to device returns.  
* **Engineering cost** – Misleading symptoms suggest UI bugs; root cause is deeper in OS.

---

## 6  Mitigation Ideas (application-side)

1. **Input rate limiting** – Discard presses arriving <100 ms after last accepted press when `UIAccessibility.isVoiceOverRunning == true`.
2. **Lightweight stall monitoring** – Add RunLoop observer; if a frame exceeds 1 s, temporarily throttle input.
3. **Reduce accessibility tree depth** – Avoid unnecessary nested focus guides and massive collection views.
4. **Guard background transitions** – Avoid Menu presses during stall; snapshot creation accelerates failure.

These are work-arounds; root issue is within the system input pipeline.

When you press Menu, tvOS tries to capture a screenshot of the app for the system switcher before suspending it. That extra work (rendering the snapshot and freezing the UI hierarchy) lands on the same overloaded RunLoop, so the backlog jumps sharply and the bug triggers sooner.

---

## 7  Conclusion

InfinityBug is a system-level defect triggered by the interaction of VoiceOver with sustained physical navigation. Redundant hardware and accessibility events overwhelm the RunLoop, causing multi-second stalls. The app still receives input, but queued phantom presses repeatedly override user commands, giving the impression of a "tug-of-war" for focus. Any tvOS app can trigger the defect; complex focus hierarchies and rapid input merely hasten its arrival.

**Recommended actions**  
• Throttle input and simplify accessibility where feasible.  
• Reproduce on physical hardware during QA.  
• File detailed bug reports and logs with Apple; advocate for a platform fix.

---

## 8  References

* *RootCauseAnalysis.md* – detailed technical timeline  
* *InfinityBug_GroundTruth_Analysis.md* – log excerpts proving dual-pipeline collisions  
* *SuccessfulRepro4_Analysis.md* – backgrounding-trigger escalation  
* *LogComparison.md* – quantitative stall progression

## TL;DR

InfinityBug occurs when VoiceOver is on and rapid navigation floods the RunLoop with duplicate hardware and accessibility events. After ~3 minutes of continuous movement, queued phantom presses take over, forcing focus in a single direction and overriding user input until the device is restarted. 
# InfinityBug – Updated Root Cause Analysis (Revision 2025-06-24)

> This revision reconciles all available evidence across the *memlog* corpus and removes or updates earlier statements that were not demonstrably true.  Inline citations use the filename (and, when helpful, a section header) so future readers can quickly locate the primary source material.

## 1  Executive Summary

`InfinityBug` is a **system-level RunLoop overload on tvOS** that manifests as phantom or stuck Siri Remote button repeats requiring a device restart.  The immediate cause is **input load that exceeds RunLoop processing capacity while VoiceOver is enabled**.  Two distinct stress vectors have been confirmed:

1. **Dual-pipeline collision on physical hardware** – the same button press is processed by the hardware DPAD path *and* the VoiceOver accessibility path, doubling work and increasing timestamp collisions.  
2. **Synthetic high-frequency input during UITests** – with VoiceOver pre-enabled the accessibility workload is already elevated; rapid synthetic `UIPressesEvent`s alone can push the RunLoop past its limit.

Both vectors converge on the *same* failure mode: progressive RunLoop stalls grow past ~5 s, input back-pressure builds, and the system enters an unrecoverable state that survives app termination (phantom presses).

## 2  Technical Root Cause

### 2.1 Dual Input Pipelines (Physical Device)
* tvOS delivers Siri Remote input through:
  * `🕹️ DPAD STATE` – direct HID hardware events, and
  * `[A11Y] REMOTE` – VoiceOver-generated accessibility events.
* When VoiceOver is active both pipelines fire for every press, causing timestamp collisions and doubling per-event workload.  
* Evidence: identical timestamps for DPAD and A11Y events (`InfinityBug_GroundTruth_Analysis.md ▸ "Dual Pipeline Event Collisions"`).

### 2.2 Synthetic Stress (UITest Path)
* Commit history ([`1b38f3a`](#) & [`80811bb`](#); see *InfinityBug_GroundTruth_Analysis.md ▸ "MAJOR REVISION – UITest Success*") demonstrates that UITests **can** reproduce InfinityBug when:
  1. VoiceOver is enabled before the test starts, *and*
  2. The test issues high-frequency directional presses (≈25 ms on / 30-50 ms off) for several minutes.
* No hardware pipeline is involved, but the sheer volume of synthetic events saturates the RunLoop once the accessibility workload is present.

### 2.3 RunLoop Stall Escalation
1. **Normal operation** – stall <1 s; system recovers.
2. **Stress accumulation** – stalls 1-4 s; polling fall-backs appear (`POLL detected via polling`).
3. **Critical threshold** – first stall ≥≈5 s (e.g. 5 179 ms [^crit5179]); backlog begins to grow faster than it can drain.
4. **Collapse** – subsequent stalls often exceed 9 s (`InfinityBug_GroundTruth_Analysis.md ▸ "RunLoop Stall Progression"`).

[^crit5179]: 5 179 ms stall observed in multiple successful reproductions (*LogComparison.md*, lines 20-65).

## 3  Observed Symptoms

* **Stalls logged**: `WARNING: RunLoop stall XXXX ms` progressively increasing.  
* **POLL events**: frequent "detected via polling" messages indicate fallback input handling.  
* **Snapshot failures** when backgrounding: `response-not-possible` (see *InfinityBug_SuccessfulRepro4_Analysis.md*).
* **Phantom presses** continue after the user stops input; restarting the device clears the state.

## 4  Environmental & Procedural Requirements

| Requirement | Physical Repro | UITest Repro |
|-------------|---------------|--------------|
| VoiceOver enabled | ✅ | ✅ (pre-test)
| Hardware Siri Remote | ✅ | ⛔️  |
| High-frequency input | Optional | **Required**  |
| Duration | 2-3 min (navigation) | ≥4 min (navigation) |
| Backgrounding trigger | Accelerates failure | Optional |

Sources: *SuccessfulRepro4_Analysis.md* (backgrounding) and *DevTicket_CreateInfinityBugUITest.md* (UITest parameters).

## 5  Why Automation *Initially* Failed

Early UITest attempts injected directional presses at human-speed without VoiceOver.  Without the accessibility workload the single pipeline never saturated the RunLoop (see *failed_attempts.md* §V2 & V3).  Re-enabling VoiceOver and increasing press frequency resolved that gap.

## 6  Mitigation Strategies

1. **Input Rate Limiting** – throttle directional presses to ≤10 Hz when `UIAccessibility.isVoiceOverRunning == true`.
2. **RunLoop Stall Monitoring** – abort or defer non-critical work when stalls >1 s are detected.
3. **Accessibility Tree Optimisation** – minimise nested focus guides and large collection-view layouts.
4. **Backgrounding Guard** – delay `applicationWillResignActive` tasks if a stall >1 s was observed in the last 2 s.

These strategies map to the stress vectors and are informed by *InfinityBug_Mitigation_Strategy.md*.

## 7  Open Questions / Future Work

* Can the accessibility and hardware pipelines be prioritised or coalesced at the system level?  
* What is the minimum reproducible stall threshold across devices / OS versions?  
* Would reducing accessibility verbosity (e.g. `UIAccessibility.post` rate) raise the threshold?

---

### Appendix A  Selected Log Evidence

```
065648.123  WARNING: RunLoop stall 5179 ms  ← first critical stall
065650.441  🕹️ DPAD STATE: Right (0.534, 0.000)
065650.441  [A11Y] REMOTE Right Arrow      ← same timestamp
```
*Source: logs/manualExecutionLogs/SuccessfulRepro3.txt lines 80-84*

```
155304.621  [A11Y] REMOTE Menu             ← backgrounding under stress
155306.518  WARNING: RunLoop stall 3563 ms ← immediate post-menu collapse
Snapshot request… error: "response-not-possible"
```
*Source: logs/manualExecutionLogs/SuccessfulRepro4.txt lines 2600-2609*

---
**Document history**: Original draft (2025-01-23) asserted UITest reproduction was impossible and set a hard 5 179 ms threshold.  This revision incorporates later findings (2025-01-24 → 2025-06-24) showing UITest viability and a more nuanced threshold (≥≈5 s). 
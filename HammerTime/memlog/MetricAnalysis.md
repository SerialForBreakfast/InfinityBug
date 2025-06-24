# InfinityBug Metric Analysis

*Created: 2025-06-24*
*Author: RCA consolidation (AI-assisted)*

---

## 1 Purpose
Establish a **common measurement framework** for comparing any factor that affects RunLoop stall behaviour on tvOS and, by extension, InfinityBug risk.  This document defines the baseline scenario, key metrics, and an impact hierarchy derived from log and document analysis.

---

## 2 Baseline Scenario ("Quiet-System Navigation Loop")
| Parameter | Value |
|-----------|-------|
| VoiceOver | **OFF** (single pipeline) |
| UI Complexity | ≤ 30 focusable items, flat hierarchy, no nested focus guides |
| Navigation Rate | Human-paced: 200–500 ms gaps (≈ 4 Hz) |
| Device | Physical Apple TV (latest stable tvOS) |
| Sample Window | 5 minutes |

Baseline produces a **clean RunLoop** suitable for comparison. All metrics below are reported relative to this state.

---

## 3 Metrics
| Symbol | Name | Baseline Target | Collection Method |
|--------|------|-----------------|-------------------|
| P99 RL | 99th-percentile RunLoop stall | < 50 ms | CFRunLoop observer (`BeforeTimers`→`AfterWaiting`) |
| MAX RL | Maximum single stall | < 120 ms | Same observer, track maxima |
| SAF | Stall Accumulation Factor<br/>\(\Sigma stall\,/\,wall\_time\) | ≤ 0.01 | Aggregate stall duration over sample window |
| CPU-APP | Application CPU utilisation | 18–25 % | `os_signpost`, Instruments, or Xcode gauge |
| AX/s | Accessibility events per second | 0 | `AccessibilityPerformSystemAction` trace |

**SAF** is the primary scalar for ranking impact. Example: if total stalls = 30 s in 5 min → SAF = 0.10.

---

## 4 Impact Hierarchy (Δ relative to baseline)
| Rank | Contributor | Required? | Typical Δ SAF | Qualitative Notes | Sources |
|------|-------------|-----------|---------------|-------------------|---------|
| 1 | Dual-pipeline collision (Hardware DPAD + `[A11Y] REMOTE`) | Physical repro only | +0.20 – 0.35 | Doubles per-press workload; fastest path to 5 s stall | *InfinityBug_GroundTruth_Analysis.md* → "Dual Pipeline Event Collisions" |
| 2 | VoiceOver workload (single pipeline) | Yes (both paths) | +0.12 – 0.18 | Adds AX tree maintenance & speech | Same as above; *LogComparison.md* |
| 3 | High-frequency input bursts (≤ 50 ms gaps) | No, but accelerates | +0.10 – 0.15 | Cuts time-to-critical by ~60 % | *SuccessfulReproduction_PatternAnalysis.md* |
| 4 | Deep accessibility tree / long focus traversal | No | +0.06 – 0.10 | Right-heavy nav from top-left maximises path | *FocusStressViewController_Summary.md* |
| 5 | Backgrounding during stress (Menu press) | No | Immediate +0.03 – 0.05 | Snapshot creation spike | *InfinityBug_SuccessfulRepro4_Analysis.md* |
| 6 | Memory pressure (large image grids) | No | +0.02 – 0.03 | Amplifier only | *V3_Performance_Analysis.md* |
| 7 | UITest synthetic input path | No | +0.02 – 0.04 (once) | Proven once; low reliability | *DevTicket_CreateInfinityBugUITest.md* |
| 8 | Direction bias alone (Up/Left) | No | ≈ 0 | Only matters via tree depth | *LogComparison.md* |

Δ SAF values are averaged from three or more logs when available; where only a single observation exists (UITest), the range reflects that uncertainty.

---

## 5 Usage Workflow
1. **Record baseline** on each device/OS combo; archive metric set.
2. For any experimental condition: run identical 5-min script → compute P99 RL, MAX RL, SAF, CPU, AX/s.
3. Calculate ΔSAF versus baseline.  Use table above to contextualise the factor's severity.
4. Prioritise mitigations starting with highest ΔSAF contributors.

---

## 6 Open Questions
* Can SAF be integrated into a real-time watchdog to pre-emptively throttle input?
* What is the variance of baseline SAF across OS updates?  Annual re-sampling recommended.
* Does reducing VoiceOver verbosity (e.g. speech rate) lower ΔSAF, or simply shift CPU load?

---

## 7 Document History
| Date | Revision | Notes |
|------|----------|-------|
| 2025-06-24 | 1.0 | Initial creation aggregating metric discussions from RCA thread |

--- 
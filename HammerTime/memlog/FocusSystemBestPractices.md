# tvOS Focus System – Engineering Best Practices

*Created 2025-06-28*

---

## 1  Scope & Relationship to System Input Pipeline
This memo complements `SystemInputPipeline.md`. That document explains **why** the InfinityBug appears (RunLoop overload, VoiceOver overhead, progressive memory pressure). The present guide explains **how** to architect focus-driven UIs that *avoid* those failure modes in the first place.  It is intended for any module that constructs or manipulates tvOS/iOS/tvOS focus hierarchies—custom `UIViewController`s, UICollectionView layouts, game-controller input handlers, or VoiceOver custom rotors.

---

## 2  Anatomy of a Focus Update (quick recap)
1. **HID event → UIPress** (≤ 7 ms target, [WWDC18 235]).
2. **Focus Engine Search** – spatial hash of visible `UIFocusItem`s; complexity O(N log N) for N items.
3. **UIKit layout & display commit** – must finish before next v-blank.
4. **VoiceOver accessibility pass** (opt-in) – tree enumeration + TTS queuing.
5. **CoreAnimation present** – hardware scan-out.

Each stage consumes a slice of the 16.67 ms/60 fps frame budget. Any overrun bubbles back to stage 1, causing queue build-up that manifests as phantom navigation or input lag (see `SystemInputPipeline.md` § 3.1).

---

## 3  Primary Cost Drivers
| Driver | Symptoms | Mitigation |
|--------|---------|------------|
|Focus hierarchy depth / breadth|Jumps feel "sticky", overlay elements randomly unfocusable|Flatten views, reuse cells, prefer `UIFocusEnvironment` over nested `UIFocusGuide`s ([WWDC18 235]).|
|Synchronous layout in `didUpdateFocus…`|Frame drops, RunLoop stalls|Defer work via `DispatchQueue.main.async{}` or `await Task.yield()`.
|VoiceOver tree bloat|15–25 ms extra per move, spurious announcements|Hide decorative views (`isAccessibilityElement = false`), move heavy string concatenation off main thread ([WWDC22 11034]).|
|RunLoop starvation|Stalls > 1 s, InfinityBug trigger > 5.179 s|Instrument with `CFRunLoopObserver`, early-warn at ≥ 1 s (see pipeline doc).|
|Memory pressure (> 79 MB in our tests)|Focus update freeze, device-wide sluggishness|Keep ballast below 65 MB; release textures in `didResignActive`.|

---

## 4  Engineering Best Practices
### 4.1 Design & Architecture
* **Model focus paths early** – sketch every directional move on paper before coding.
* **One `UIFocusGuide` per logical jump**; chaining guides multiplies search cost.
* **Prefer collection views** over ad-hoc view groups—UICollectionView uses cell recycling that naturally bounds focus graph size.
* **Group by `preferredFocusEnvironments`** instead of calling `setNeedsFocusUpdate()` repeatedly.
* **Mark non-interactive decoration** with `accessibilityElementsHidden = true` to shrink both focus and AX trees.

### 4.2 Performance-Critical Code
* Never allocate or decode images inside `did/shouldUpdateFocus…`.
* Cache heavy accessibility strings; if they must be dynamic, compute them on a background task then write back on `@MainActor`.
* Use `UIPress.timestamp` + `CACurrentMediaTime()` for precise lag profiling; log to os	signpost for Instruments correlation.
* Keep main-thread work < 7 ms per event (target derived from Stage 1 budget).

### 4.3 Concurrency
* Wrap mutable focus-related state in an **actor** when accessed from background tasks.
* Annotate UI-touching APIs with **`@MainActor`** to avoid accidental cross-thread hops.

---

## 5  Troubleshooting Workflow
| Step | Tool / Command | Goal |
|------|---------------|------|
|1 Enable Focus Debug Overlay|`⌃ ⌥ ⌘ F` (tvos 16+) |Visualize search graph; identify unexpected branches.|
|2 Log Focus Updates|`UIFocusUpdateContext` quick-look in LLDB |Confirm from→to path, see rejected candidates.|
|3 Run VoiceOver Instruments Template|Xcode → Instruments → VoiceOver|Locate tree enumeration hotspots (> 5 ms).|
|4 Check RunLoop stalls|Custom build flag `RUNLOOP_OBSERVER=1`|Alert when delta > 1 s (warning) or > 5.179 s (InfinityBug).|
|5 Validate memory headroom|Memory gauge or `os_proc_available_memory()`|Stay < 65 MB while VoiceOver active.|

---

## 6  Pre-Flight Checklist
* [ ] **Hierarchy** under 1 000 visible `UIFocusItem`s.
* [ ] No nesting more than **3 levels** deep of `UIFocusGuide`.
* [ ] All decoration views **hidden from accessibility**.
* [ ] `didUpdateFocus…` completes in **< 3 ms** (baseline) / **< 7 ms** (max).
* [ ] VoiceOver audit shows **no duplicate labels** or missing traits.
* [ ] RunLoop observer reports **0 stalls > 1 s** in 10-minute stress run.
* [ ] Memory footprint below **65 MB** during sustained interaction.
* [ ] All new code passes **UITest Focus Navigation Suite** (automated).

---

## 7  References
1. **[WWDC18 Session 235] Advanced TV Input with UIKit** – foundational algorithm & performance budget.  <https://developer.apple.com/videos/play/wwdc2018/235/>
2. **[WWDC22 Session 11034] Diagnose and optimize VoiceOver in your app** – AX-tree performance tooling.  <https://developer.apple.com/videos/play/wwdc2022/11034/>
3. **"Is It Snappy?"** – open-source input-to-photons measurement, latency baselining.  <https://github.com/chadaustin/is-it-snappy>
4. **SystemInputPipeline.md** – internal doc: RunLoop stall thresholds, memory ballast strategy.

*When in doubt, profile first—optimise second.* 
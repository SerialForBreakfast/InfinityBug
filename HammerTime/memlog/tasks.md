#### 🚨 TASK 6: TortureRack View & Debug Menu
**Prompt (DEV‑only code):**  
* Create `TortureRackViewController` guarded by `#if DEBUG`.  
* Hard‑enable these stressors:  
  1. 3‑level nested compositional `UICollectionView`s.  
  2. ≥ 50 hidden but `isAccessibilityElement == true` traps.  
  3. Timer (`0.05 s`) toggling a top constraint constant (jiggle).  
  4. Two circular `UIFocusGuide`s linking to each other.  
  5. Duplicate `accessibilityIdentifier` on 30 % of cells.  
* Provide `struct StressFlags` with Bool toggles + launch arg `-TortureMode heavy|light` (`heavy` = all on, `light` = 1 & 2 only).  
* Add `DebugMenuViewController` (also `#if DEBUG`) shown when app starts with `-ShowDebugMenu YES`. Menu rows: “Default App Flow” and “Torture Rack (heavy|light)”.  

**Acceptance Criteria:**  
* `-TortureMode heavy` launches TortureRack with every stressor live; `light` enables only flags 1 & 2.  
* `-ShowDebugMenu YES` shows the menu; selecting a row navigates correctly via remote & VoiceOver.  
* No DEBUG code included in RELEASE build.  
* All new types/functions have QuickHelp comments.

#### 🚨 TASK 7: TortureRack UITest Suite
**Prompt:**  
* New test class `TortureRackUITests`.  
* Launch app with `-TortureMode heavy`.  
* Perform 200 alternating `.right` / `.left` presses (scaled by `STRESS_FACTOR`).  
* Use `isValidFocus` helper; fail if the same valid focus ID repeats > 8 times consecutively.  
* Add helper to rerun test with each individual stressor by passing `-EnableStress<n> YES`.  

**Acceptance Criteria:**  
* Suite passes on healthy build, fails when any stressor triggers infinite repeat (manual validation).  
* Each test finishes ≤ 90 s with `STRESS_FACTOR=1`.  
* No false positives when focus ID == `"NONE"`.

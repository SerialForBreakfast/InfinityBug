# UI Testing Facts and Limitations

*Created: 2025-01-22*

## Key Findings from InfinityBug Testing

### 1. Focus Detection Issues
- **`hasFocus` predicate limitations**: Only works reliably when VoiceOver is enabled
- **Focus state queries are expensive**: Should not be called at high frequency
- **Focus changes lag behind input**: There's a timing mismatch between sending input and detecting focus changes
- **Collection view focus queries are unreliable**: Cells don't consistently report focus state

### 2. UI Test Environment Limitations
- **Simulators don't accurately represent physical device execution**
- **Real device accessibility must be configured before test execution**
- **UI tests can't change accessibility options during execution**
- **Rotors don't work in UI testing environment**

### 3. Launch Argument Processing Issues
- **Individual stressor launch arguments (`-EnableStress1`) may not be processed correctly**
- **App launch state may not match expected configuration**
- **Collection view may not exist when expected stressor is enabled**

### 4. Timing and Performance Issues
- **High-frequency input (8-50ms intervals) may be too fast for UI test framework**
- **Input debouncing affects test reliability**
- **Layout invalidation timers may interfere with focus detection**

### 5. Test Execution Findings
From failed tests:
- Only 2 unique focus states detected instead of expected 3+
- 200 input presses resulted in only 5 focus changes (2.5% effectiveness)
- Performance tests taking 262ms instead of expected <30ms
- Collection view not found when individual stressors enabled

## Implications for InfinityBug Testing

### Current Test Approach Issues
1. **Over-reliance on focus detection**: Tests assume focus changes can be reliably detected
2. **Too aggressive input timing**: May be overwhelming the UI test framework
3. **Incorrect launch configuration**: Individual stressor tests not launching properly
4. **Simulator vs. real device**: Tests may behave differently on actual Apple TV

### Recommendations
1. **Reduce focus detection frequency**: Only check focus state occasionally, not after every input
2. **Increase input timing**: Use longer intervals (100-200ms) to ensure processing
3. **Fix launch argument processing**: Ensure individual stressor tests launch correctly
4. **Add UI state validation**: Verify collection view and cells exist before testing
5. **Manual testing priority**: Focus on creating conditions for manual observation rather than automated detection

## Test Strategy Revisions Needed
- Simplify automated detection logic
- Focus on creating obvious visual symptoms
- Reduce reliance on precise timing
- Improve test environment validation
- Separate simulator testing from real device testing 

## 2025-06-22 Additional Confirmed Limitations

### 6. Synthetic Input vs. Hardware Remote
- **XCUIRemote events bypass the HID layer** – HardwarePressCache remains empty during UITests, so phantom-vs-real divergence cannot be analysed.
- **Event delivery is throttled to ~15 Hz** by XCTest; micro-timing (3-8 ms) is coalesced before reaching the device.

### 7. VoiceOver Precondition
- VoiceOver state cannot be toggled from UITests. It **must be enabled in Settings before the run**; otherwise focus queue backlog never forms.

### 8. Stressor Overlap
- UITest press loops and the main-thread layout timers often do **not overlap** because both use the main run-loop; this reduces stale-context likelihood.

These findings explain why automated UITest reproduction continues to fail and motivate hardware-only, manual-observation strategies. 
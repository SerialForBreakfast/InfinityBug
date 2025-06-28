# Apple Feedback Assistant Bug Report

## Title
tvOS Focus Engine Infinite Loop with VoiceOver Navigation Causes System Unresponsiveness

## Technology/Framework
- **Technology**: UIKit Focus Engine / Accessibility
- **Platform**: tvOS
- **Version**: tvOS 18+ (reproduced across multiple versions)

## Classification
- **Area**: Developer Technologies & SDKs → UIKit → tvOS
- **Type**: Bug/Incorrect Behavior

## Description

### Summary
The tvOS focus engine enters an infinite loop when VoiceOver navigates rapidly through collection views with complex layouts. The bug causes phantom button repeats that continue after app termination, requiring device restart to restore normal operation.

### Steps to Reproduce
1. Enable VoiceOver on Apple TV device
2. Launch app with UICollectionView using compositional layout
3. Navigate rapidly using a combination of swipes and directional buttons (avoid sticking at the edges and navigate for the most changes in focus)
4. Continue rapid navigation for 2-3 minutes until system becomes unresponsive
5. Press Home button to exit app

### Actual Results
- Focus becomes stuck in infinite navigation loop
- Remote inputs repeat continuously without user interaction
- System-wide focus navigation fails across all apps
- Console shows RunLoop stall warnings >5000ms
- Device requires hard restart to restore functionality

### Expected Results
- Focus navigation should stop when user stops pressing buttons
- Exiting app should terminate all navigation behavior
- System focus should remain responsive across all apps
- No phantom button repeats should occur

### Additional Information

**Environment**: 
- Physical Apple TV device (not Simulator)
- VoiceOver accessibility feature enabled
- Complex UICollectionView with nested groups and accessibility elements

**Console Output Pattern**:
```
[AXDBG] WARNING: RunLoop stall 5179 ms
[AXDBG] WARNING: RunLoop stall 8234 ms
```

**Triggering Conditions**:
- Rapid directional navigation (intervals <100ms)
- Right/Down movement combinations most susceptible
- Collection views with 50+ focusable elements
- Nested accessibility hierarchy with overlapping elements

**System Impact**:
- Affects focus navigation system-wide
- Persists across app launches until restart
- Cannot be resolved by disabling VoiceOver
- Requires physical device restart

### Reproducibility
Consistently reproducible on physical Apple TV devices when VoiceOver is enabled and rapid navigation patterns are executed through complex collection view layouts.

---

**Attachments to Include**:
- Sample project demonstrating issue
- sysdiagnose from device during bug occurrence
- Console logs showing RunLoop stall warnings
- Screen recording of phantom navigation behavior

**Workaround**: 
None identified. Device restart required to restore normal operation. 
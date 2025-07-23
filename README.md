# HammerTime: tvOS InfinityBug Research Project

A tvOS research application for reproducing and analyzing the InfinityBug - a system issue where VoiceOver focus gets stuck in infinite navigation loops requiring device restart.

## The Problem

The InfinityBug occurs when VoiceOver is enabled and sustained navigation overwhelms the focus system. The device continues navigating autonomously after user input stops. Only a full restart recovers the system.

## Video
https://github.com/user-attachments/assets/ba3b7fe2-01a4-4b76-a36a-cd2da2573961


### What is the InfinityBug?
The InfinityBug is a system-level tvOS issue that occurs when:
- **VoiceOver accessibility is enabled**
- **Sustained directional navigation** occurs in complex focus hierarchies
- **System resources become overwhelmed** by accessibility processing
- **Focus navigation continues autonomously** after user input stops
- **Standard recovery methods fail** - only device restart works

### Why This Matters
- **Affects VoiceOver users** who depend on accessibility for tvOS navigation
- **No software recovery** - requires full device power cycle
- **Persists across app launches** - system-level corruption
- **Difficult to reproduce** - requires specific stress conditions
- **No official Apple documentation** on this issue

## 📊 Project Achievements

HammerTime/
- ViewController.swift - Root container with stress elements  
- FocusStressViewController.swift - Configurable stress testing
- InfinityBugDetector.swift - Bug detection and monitoring
- TestRunLogger.swift - Execution logging
- FocusStressConfiguration.swift - Test presets
- AXFocusDebugger.swift - Ultra-low-level accessibility and input monitoring


HammerTimeUITests/
- FocusStressUITests.swift - Automated reproduction tests
- FocusStressUITests+Extensions.swift - Test utilities

memlog/
- Research documentation and analysis
- Test execution logs
- Technical findings

FocusStressViewController Features
1. **Nested Layout Structures** - Complex compositional hierarchies (up to triple-nested)
2. **Hidden/Visible Focusable Traps** - 15 conflicting accessibility elements per cell
3. **Jiggle Timer** - Continuous layout recalculation (0.015s intervals)
4. **Circular Focus Guides** - Competing focus guidance systems
5. **Duplicate Identifiers** - Accessibility tree inconsistencies
6. **Dynamic Focus Guides** - Runtime-modified focus behavior
7. **Rapid Layout Changes** - Constraint animation conflicts
8. **Overlapping Elements** - Focus calculation ambiguity
9. **VoiceOver Announcements** - Speech synthesis system stress

### Requirements
- Physical Apple TV (simulator cannot reproduce the bug)
- VoiceOver enabled in Settings > General > Accessibility
- Xcode with tvOS deployment

### Quick Start

Build and run on Apple TV:
```bash
git clone [repository]
cd HammerTime
open HammerTime.xcodeproj
```

Run reproduction test:
```bash
xcodebuild test -scheme HammerTime -destination 'platform=tvOS,name=Apple TV' \
  -testArgs "-FocusStressPreset heavyReproduction"
```

### Test Presets

- lightExploration: Basic testing (10-15MB)
- mediumStress: Development testing (25-35MB) 
- heavyReproduction: Research reproduction (50-65MB)
- maxStress: Maximum stress testing (150MB+)

## Research Findings

Successful reproduction requires:
- Memory escalation from 52MB to 79MB
- RunLoop stalls exceeding 5,000ms
- Event queue saturation (200+ events)
- Complex accessibility hierarchies with competing focus guides

Manual reproduction is more reliable than automated testing. UI tests have approximately 5% success rate while manual testing achieves consistent reproduction with proper conditions.

## Important Notes

- Device restart required if bug is triggered
- Test on physical device only
- Enable VoiceOver before testing
- One configuration per test session

This research aims to document the issue and develop mitigation strategies for production applications. 

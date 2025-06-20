# HammerTime Directory Structure

## Project Root Structure
```
HammerTime/
├── memlog/                               # Project state tracking (NEW)
│   ├── changelog.md                      # Change history and project status
│   ├── directory_tree.md                 # This file - project structure
│   └── tasks.md                          # Task management and progress
├── HammerTime/                           # Main app target
│   ├── AppDelegate.swift                 # App lifecycle management
│   ├── ViewController.swift              # Root container with InfinityBug stress
│   ├── ContainerFactory.swift           # Complex accessibility hierarchy creator
│   ├── Assets.xcassets/                  # App icons and images
│   └── Base.lproj/                       # Storyboards and localization
├── HammerTimeTests/                      # Unit tests
│   └── HammerTimeTests.swift             # Basic unit test structure
├── HammerTimeUITests/                    # UI Tests for InfinityBug detection
│   ├── HammerTimeUITests.swift           # Comprehensive InfinityBug test suite
│   └── HammerTimeUITestsLaunchTests.swift # Launch behavior tests
├── HammerTime.xcodeproj/                 # Xcode project configuration
├── Debugger.swift                        # Low-level input/accessibility monitoring
├── README_HID_DEBUGGING.md              # HID debugging documentation
└── Test Plans (*.xctestplan)             # Test execution configurations
```

## Key Components by Purpose

### InfinityBug Detection Infrastructure
- `Debugger.swift` - Ultra low-level input monitoring, accessibility tree analysis
- `HammerTimeUITests.swift` - 20+ test methods for InfinityBug reproduction
- `ViewController.swift` - Performance stress elements, accessibility conflicts

### Accessibility Conflict Generation
- `ContainerFactory.swift` - Creates Plant->Animal->SampleVC hierarchy conflicts
- Complex view layering with competing accessibility properties
- Focus guide conflicts and circular reference creation

### Core App Structure
- `AppDelegate.swift` - Basic tvOS app lifecycle with debugger integration
- `ViewController.swift` - Main container orchestrating all conflict elements
- Asset and storyboard resources for tvOS deployment

## File Purposes

| File | Primary Purpose | Lines | Key Features |
|------|----------------|-------|--------------|
| `Debugger.swift` | Input monitoring & accessibility analysis | 956 | GameController integration, focus tracking |
| `HammerTimeUITests.swift` | InfinityBug detection test suite | 1373 | 20+ test methods, rapid input simulation |
| `ViewController.swift` | Main app container with stress elements | 971 | Accessibility conflicts, performance stress |
| `ContainerFactory.swift` | Complex hierarchy generation | 227 | Plant/Animal themed accessibility conflicts |

## Testing Strategy Structure
```
UI Tests (HammerTimeUITests.swift):
├── Basic Navigation Tests
│   ├── testAppLaunchesAndUIIsAccessible()
│   ├── testBasicNavigation()
│   └── testAccessibilityIdentifiersExist()
├── InfinityBug Detection Tests  
│   ├── testRandomHammerScroll()
│   ├── testInfinityBugReplication()
│   ├── testInfinityBugReplicationBrute()
│   └── testInfinityBugDirectionalSwitchAfterHang()
├── Focus Behavior Tests
│   ├── testRapidDirectionalFocusChanges()
│   ├── testFocusDuringInterruptions()
│   └── testFocusRecoveryAfterStress()
└── Container Conflict Tests
    ├── testContainerFactoryAccessibilityConflicts()
    ├── testContainerAccessibilityPropertyConflicts()
    └── testVoiceOverNestedContainerBehavior()
```

## File-by-File Breakdown

| Path                                        | LoC | Purpose                                                      |
| ------------------------------------------- | --- | ------------------------------------------------------------ |
| **App Logic & UI**                          |     |                                                              |
| `HammerTime/AppDelegate.swift`              | 80  | App entry point, lifecycle management, test harness routing.   |
| `HammerTime/ViewController.swift`           | 971 | Root view controller for the main application.                 |
| `HammerTime/ContainerFactory.swift`         | 108 | Creates complex, nested view controller hierarchies for stress.|
| `HammerTime/FocusStressViewController.swift`| 212 | **NEW**: `DEBUG`-only view controller with multiple focus stressors.|
| **Debugging & Diagnostics**                 |     |                                                              |
| `Debugger.swift`                            | 956 | Low-level event monitoring and logging framework.            |
| `HammerTime/InfinityBugDetector.swift`      | 202 | **NEW**: Actor-based system for high-confidence bug detection.|
| **UI Testing**                              |     |                                                              |
| `HammerTimeUITests/HammerTimeUITests.swift` | 1373| Original UI test suite for the main `ViewController`.          |
| `HammerTimeUITests/FocusStressUITests.swift`| 335 | **NEW**: UI tests for the `FocusStressViewController`.         |
| **Project & Memlog**                        |     |                                                              |
| `memlog/changelog.md`                       | 66  | Project history and status.                                  |
| `memlog/tasks.md`                           | 128 | Task management and progress tracking.                       |
| `memlog/directory_tree.md`                  | 76  | This file.                                                   |

---
*This directory structure supports the InfinityBug detection strategy through systematic accessibility conflict generation and comprehensive testing.* 
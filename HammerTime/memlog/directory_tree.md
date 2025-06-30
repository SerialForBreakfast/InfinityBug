# HammerTime Directory Structure

## Project Root Structure
```
HammerTime/
├── memlog/                               # Project state tracking and analysis
│   ├── changelog.md                      # Change history and project status
│   ├── directory_tree.md                 # This file - project structure
│   ├── tasks.md                          # Task management and progress
│   ├── Confluence2.md                    # Professional InfinityBug technical analysis
│   ├── DualPipelineCollision.md          # Analysis of false technical claims (learning record)
│   ├── SystemInputPipeline.md            # Corrected tvOS input architecture analysis
│   ├── failed_attempts.md               # Historical record of failed approaches
│   ├── UnreliableTests.md               # Test reliability and performance analysis
│   ├── AutomatedTest_FailureAnalysis.md  # Why automation fails analysis
│   ├── DevTicket_CreateInfinityBugUITest.md # Project management
│   ├── EvolutionaryTestImprovementPlan.md # High-level strategy
│   ├── FocusStressViewController_Summary.md # Component analysis
│   ├── RadarSubmission.md                # Bug report template
│   ├── SearchResults.md                  # Reference material
│   ├── SimulatorVSManualTestingLimitations.md # Platform differences
│   ├── Terminology.md                    # Definitions
│   ├── Test_Documentation_Summary.md     # Documentation overview
│   ├── UITestingFacts.md                 # Testing platform limitations
│   ├── V3_Performance_Analysis.md        # Performance measurements
│   ├── InfinityBug_Test_Analysis.md      # Test analysis
│   ├── InfinityBug_Mitigation_Strategy.md # Mitigation approaches
│   ├── LogComparison.md                  # Log analysis
│   ├── InfinityBug_LogAnalysis_Summary.md # Log analysis summary
│   ├── InfinityBug_SuccessfulRepro4_Analysis.md # Reproduction analysis
│   └── SuccessfulReproduction_PatternAnalysis.md # Pattern analysis
├── HammerTime/                           # Main app target
│   ├── AppDelegate.swift                 # App lifecycle management
│   ├── ViewController.swift              # Root container with InfinityBug stress
│   ├── ContainerFactory.swift           # Complex accessibility hierarchy creator
│   ├── FocusStressViewController.swift   # Enhanced stress testing controller
│   ├── InfinityBugDetector.swift         # Bug detection system
│   ├── MainMenuViewController.swift      # Navigation controller
│   ├── TestRunLogger.swift              # Test execution logging
│   ├── FocusStressConfiguration.swift   # Configuration management
│   ├── Assets.xcassets/                  # App icons and images
│   └── Base.lproj/                       # Storyboards and localization
├── HammerTimeTests/                      # Unit tests
│   └── HammerTimeTests.swift             # Basic unit test structure
├── HammerTimeUITests/                    # UI Tests for InfinityBug detection
│   ├── FocusStressUITests.swift          # Comprehensive stress test suite
│   ├── FocusStressUITests+Extensions.swift # Test utilities and extensions
│   └── NavigationStrategy.swift         # Navigation strategy implementation
├── logs/                                 # Test execution logs and analysis
│   ├── manualExecutionLogs/              # Manual reproduction evidence
│   └── UITestRunLogs-OnDevice/           # Device test execution logs
├── HammerTime.xcodeproj/                 # Xcode project configuration
├── Debugger.swift                        # Low-level input/accessibility monitoring
├── README_HID_DEBUGGING.md              # HID debugging documentation
└── Test Plans (*.xctestplan)             # Test execution configurations
```

## Key Components by Purpose

### InfinityBug Analysis Infrastructure
- `Debugger.swift` - Ultra low-level input monitoring, accessibility tree analysis
- `FocusStressUITests.swift` - Comprehensive test methods for InfinityBug reproduction
- `SystemInputPipeline.md` - Technical analysis of tvOS input architecture
- `Confluence2.md` - Professional technical documentation

### Evidence-Based Documentation
- `DualPipelineCollision.md` - Documents analytical failures (learning record)
- `failed_attempts.md` - Historical record of what didn't work and why
- `SimulatorVSManualTestingLimitations.md` - Platform-specific constraints
- `UITestingFacts.md` - Testing environment limitations

### Core App Structure
- `AppDelegate.swift` - Basic tvOS app lifecycle with debugger integration
- `FocusStressViewController.swift` - Enhanced stress testing with configurable parameters
- `InfinityBugDetector.swift` - Actor-based detection system
- `ContainerFactory.swift` - Complex accessibility hierarchy generation

## Documentation Cleanup Summary

### Files Removed (False Technical Claims)
The following files contained false "dual pipeline collision" claims and have been removed:
- ~~`InfinityBug_GroundTruth_Analysis.md`~~ - False claims about dual pipeline collisions
- ~~`RootCauseAnalysis.md`~~ - Built on false technical premises
- ~~`Confluence.md`~~ - Superseded by corrected `Confluence2.md`
- ~~`MetricAnalysis.md`~~ - Performance metrics based on false assumptions
- ~~`V7_Evolution_Summary.md`~~ - Evolution plan based on impossible simulation
- ~~`InfinityBug_7Step_Analysis.md`~~ - Implementation plan using invalid methods
- ~~`InfinityBug_Immediate_Fixes.md`~~ - Fixes based on incorrect root cause

### Files Corrected
- `SystemInputPipeline.md` - Rewritten with evidence-based technical analysis
- `failed_attempts.md` - Dual pipeline references removed, failure analysis preserved
- `UnreliableTests.md` - Verified clean of false claims

### Current Valid Documentation
- `Confluence2.md` - Professional technical analysis using only Apple's public APIs
- `DualPipelineCollision.md` - Analysis of analytical failures | ✅ Learning Record | Documents errors to prevent repetition

## File Purposes

| File | Primary Purpose | Status | Key Features |
|------|----------------|--------|--------------|
| `Debugger.swift` | Input monitoring & accessibility analysis | ✅ Valid | GameController integration, focus tracking |
| `FocusStressUITests.swift` | InfinityBug detection test suite | ✅ Valid | Comprehensive test methods, rapid input simulation |
| `Confluence2.md` | Professional technical documentation | ✅ Valid | Evidence-based analysis, Apple API references |
| `SystemInputPipeline.md` | tvOS input architecture analysis | ✅ Corrected | Accurate technical description, no false claims |
| `DualPipelineCollision.md` | Analysis of analytical failures | ✅ Learning Record | Documents errors to prevent repetition |

## Testing Strategy Structure
```
UI Tests (FocusStressUITests.swift):
├── Basic Functionality Tests
│   ├── testAppLaunchesWithoutCrashing()
│   ├── testBasicNavigationWorks()
│   └── testAccessibilityTreeIsValid()
├── InfinityBug Investigation Tests  
│   ├── testExtendedNavigationStress()
│   ├── testMemoryPressureDuringNavigation()
│   ├── testFocusConflictGeneration()
│   └── testVoiceOverStressConditions()
├── Performance Monitoring Tests
│   ├── testRunLoopPerformanceTracking()
│   ├── testHardwareInputCorrelation()
│   └── testAccessibilityProcessingOverhead()
└── Platform Limitation Tests
    ├── testUITestEnvironmentLimitations()
    ├── testSimulatorVsDeviceDifferences()
    └── testVoiceOverIntegrationConstraints()
```

---
*This directory structure supports evidence-based InfinityBug analysis through systematic accessibility testing and accurate technical documentation. All false technical claims have been removed and replaced with verified, evidence-based analysis.* 
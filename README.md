# HammerTime: tvOS InfinityBug Research Project

![tvOS](https://img.shields.io/badge/Platform-tvOS-blue.svg)
![Swift](https://img.shields.io/badge/Language-Swift-orange.svg)
![Accessibility](https://img.shields.io/badge/Focus-VoiceOver%20Accessibility-green.svg)
![Research](https://img.shields.io/badge/Type-Research%20Project-red.svg)

**HammerTime** is a specialized tvOS research application designed to systematically reproduce and analyze the **InfinityBug** - a critical accessibility issue where VoiceOver focus gets permanently stuck in infinite navigation loops, requiring device restart for recovery.

## 🚨 The InfinityBug Problem

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

### ✅ Validated Reproduction Methods
- **UITest Automation**: Fast reproduction in <130 seconds (40,124ms peak stalls)
- **Manual Progressive Stress**: Comprehensive analysis in ~190 seconds (4,387ms critical stalls)
- **System Performance Monitoring**: Real-time RunLoop stall detection and memory tracking
- **Hardware Input Correlation**: GameController integration for low-level input monitoring

### ✅ Technical Evidence Collection
- **625+ test execution logs** with detailed performance metrics
- **Professional technical analysis** documenting root cause mechanisms
- **Memory escalation patterns** (52MB→79MB progression validation)
- **Event queue saturation detection** (205 events maximum, overflow indicators)

## 🏗️ Project Architecture

### Core Components

#### 📱 **Main Application** (`HammerTime/`)
```
HammerTime/
├── ViewController.swift              # Root container with InfinityBug stress elements
├── FocusStressViewController.swift   # Enhanced stress testing with 9 configurable patterns
├── InfinityBugDetector.swift         # Actor-based detection system with stall monitoring
├── ContainerFactory.swift           # Complex accessibility hierarchy generator
├── AXFocusDebugger.swift            # Ultra-low-level accessibility and input monitoring
├── TestRunLogger.swift              # Comprehensive execution logging and metrics
└── FocusStressConfiguration.swift   # Preset management and stress pattern configuration
```

#### 🧪 **UI Test Suite** (`HammerTimeUITests/`)
```
HammerTimeUITests/
├── FocusStressUITests.swift          # Comprehensive InfinityBug reproduction tests
├── FocusStressUITests+Extensions.swift # Test utilities and device management
└── NavigationStrategy.swift         # Advanced navigation pattern implementation
```

#### 📚 **Research Documentation** (`memlog/`)
```
memlog/
├── Confluence2.md                    # Professional technical analysis
├── SystemInputPipeline.md            # tvOS input architecture analysis  
├── SuccessfulReproduction_PatternAnalysis.md # Evidence-based pattern analysis
├── UITestingFacts.md                 # Platform limitation documentation
├── failed_attempts.md               # Historical record of unsuccessful approaches
└── [20+ analysis documents]         # Comprehensive research documentation
```

### 🎯 Enhanced Stress Patterns

The project implements **9 stress patterns** that recreate InfinityBug conditions:

1. **Nested Layout Structures** - Complex compositional hierarchies (up to triple-nested)
2. **Hidden/Visible Focusable Traps** - 15 conflicting accessibility elements per cell
3. **Jiggle Timer** - Continuous layout recalculation (0.015s intervals)
4. **Circular Focus Guides** - Competing focus guidance systems
5. **Duplicate Identifiers** - Accessibility tree inconsistencies
6. **Dynamic Focus Guides** - Runtime-modified focus behavior
7. **Rapid Layout Changes** - Constraint animation conflicts
8. **Overlapping Elements** - Focus calculation ambiguity
9. **VoiceOver Announcements** - Speech synthesis system stress

## 🚀 Quick Start

### Prerequisites
- **Physical Apple TV device** (Simulator cannot reproduce the bug)
- **tvOS with VoiceOver enabled** in Settings → General → Accessibility
- **Xcode with tvOS deployment target**

### Installation
```bash
git clone https://github.com/yourusername/InfinityBug.git
cd InfinityBug/HammerTime
open HammerTime.xcodeproj
```

### Basic Usage

#### 1. Manual Testing
```bash
# Launch with guaranteed reproduction preset
xcodebuild test -scheme HammerTime -destination 'platform=tvOS,name=Apple TV' \
  -testPlan HammerTime.xctestplan \
  -testArgs "-FocusStressPreset guaranteedInfinityBug"
```

#### 2. Custom Configuration
```swift
// Example: Create custom stress configuration
let config = FocusStressConfiguration(
    preset: .custom(
        layout: LayoutConfiguration(
            numberOfSections: 100,
            itemsPerSection: 100,
            nestingLevel: .tripleNested
        ),
        stressors: [.hiddenFocusableTraps, .jiggleTimer, .circularFocusGuides],
        timing: TimingConfiguration(jiggleInterval: 0.02)
    )
)
```

#### 3. Automated Reproduction
```bash
# Run the validated reproduction test
xcodebuild test -scheme HammerTime -destination 'platform=tvOS,name=Apple TV' \
  -only-testing:HammerTimeUITests/FocusStressUITests/testEvolvedInfinityBugReproduction
```

## 📈 Configuration Presets

| Preset | Purpose | Memory Impact | Reproduction Rate |
|--------|---------|---------------|-------------------|
| `lightExploration` | Basic testing | 10-15MB | Diagnostic only |
| `mediumStress` | Development | 25-35MB | Low |
| `heavyReproduction` | Research | 50-65MB | Moderate |
| `edgeTesting` | Edge cases | 20-30MB | Specific scenarios |
| `performanceBaseline` | Benchmarking | 100MB+ | Performance testing |
| `guaranteedInfinityBug` | Maximum stress | 150MB+ | **High (validated)** |

## 🔬 Research Methodology

### Evidence-Based Analysis
- **No speculation** - all claims backed by measurement data
- **Systematic reproduction** - validated across multiple test runs  
- **Performance correlation** - memory usage tied to bug manifestation
- **Hardware validation** - real device testing required

### Selection Pressure Evolution
Tests undergo **evolutionary pressure** - only successful reproduction methods are retained:

```
✅ RETAINED: testEvolvedInfinityBugReproduction (confirmed reproduction)
❌ DISABLED: testDevTicket_AggressiveRunLoopStallMonitoring (resource drain, no reproduction)
❌ DISABLED: testDevTicket_EdgeAvoidanceNavigationPattern (zero stalls, no contribution)
❌ DISABLED: testEvolvedBackgroundingTriggeredInfinityBug (zero success rate)
```

### Key Metrics
- **Critical Stall Threshold**: >5,000ms RunLoop stalls
- **Memory Escalation**: 52MB baseline → 79MB critical failure
- **Event Queue Saturation**: 205 events maximum before overflow
- **Reproduction Timeline**: UITest <130s, Manual ~190s

## 📋 Current Project Status

### ✅ Completed
- [x] **InfinityBug Reproduction**: Validated automated and manual methods
- [x] **Performance Monitoring**: Real-time stall detection and memory tracking
- [x] **Professional Documentation**: Technical analysis suitable for bug reports
- [x] **Test Suite Evolution**: Selection pressure applied to maintain only effective tests
- [x] **Enhanced Stress Patterns**: 9 configurable stress mechanisms
- [x] **Research Infrastructure**: Comprehensive logging and analysis capabilities

### 🔄 In Progress
- [ ] **Rule Compliance**: Standardizing access levels and concurrency documentation
- [ ] **Mitigation Research**: Developing protection strategies for production apps
- [ ] **Apple Bug Report**: Preparing formal submission with evidence package

### 🎯 Goals
- [ ] **100% Reproduction Rate**: Achieve deterministic InfinityBug triggering
- [ ] **Mitigation Strategies**: Develop protection mechanisms for production apps
- [ ] **Apple Recognition**: Official acknowledgment and fix for this accessibility issue

## 🛠️ Development Guidelines

### Code Standards
- **No emojis in codebase** (professional requirement)
- **Comprehensive documentation** with Xcode QuickHelp formatting
- **Explicit access levels** and concurrency requirements
- **Evidence-based analysis** - no speculation or unverified claims
- **Test evolution** - unsuccessful methods are removed via selection pressure

### Research Approach
- **Manual validation required** - UITest automation supplements but cannot replace human verification
- **Physical device testing** - Simulator cannot reproduce system-level accessibility issues
- **Performance correlation** - all bug claims must correlate with measurable system stress
- **Historical tracking** - failed approaches documented to prevent repetition

## 📖 Documentation

### Essential Reading
- **[UsageGuide.txt](HammerTime/UsageGuide.txt)** - Comprehensive stress pattern usage
- **[Confluence2.md](HammerTime/memlog/Confluence2.md)** - Professional technical analysis
- **[SystemInputPipeline.md](HammerTime/memlog/SystemInputPipeline.md)** - tvOS input architecture
- **[UITestingFacts.md](HammerTime/memlog/UITestingFacts.md)** - Platform limitations
- **[SuccessfulReproduction_PatternAnalysis.md](HammerTime/memlog/SuccessfulReproduction_PatternAnalysis.md)** - Evidence analysis

### Research History
- **[changelog.md](HammerTime/memlog/changelog.md)** - Complete project evolution
- **[failed_attempts.md](HammerTime/memlog/failed_attempts.md)** - Unsuccessful approaches
- **[tasks.md](HammerTime/memlog/tasks.md)** - Current development priorities

## ⚠️ Important Notes

### Safety Warnings
- **Device restart required** if InfinityBug is triggered
- **VoiceOver must be enabled** before testing (cannot be enabled via UITest)
- **Physical device only** - Simulator testing is ineffective
- **Test one configuration at a time** - multiple tests fragment system stress

### Legal Disclaimer
This project is for **research and accessibility improvement purposes only**. The InfinityBug is a genuine accessibility issue affecting VoiceOver users. This research aims to:
- **Document the issue** with technical evidence
- **Develop mitigation strategies** for production applications  
- **Provide Apple with reproduction steps** for official resolution

## 🤝 Contributing

### Current Focus
- **Reproduction reliability** - achieving 100% deterministic triggering
- **Mitigation development** - protection strategies for production apps
- **Documentation quality** - professional technical analysis improvement

### How to Help
1. **Test on different Apple TV models** - validate reproduction across hardware
2. **Analyze performance data** - contribute to pattern analysis
3. **Develop mitigation strategies** - research protection mechanisms
4. **Documentation improvement** - enhance technical accuracy

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**HammerTime** - *Systematic tvOS accessibility research for the InfinityBug*

*"When VoiceOver focus gets stuck, it's time to hammer down the root cause."* 
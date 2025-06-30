# UITest Console Log Capture Guide

This guide explains how to capture comprehensive console logs during UITest execution, including both XCUITest framework logs and application console output.

## Overview

The HammerTime project now includes enhanced console log capture that combines:

1. **XCUITest Framework Logs** - Standard test execution output
2. **Application Console Output** - TestRunLogger, AXFocusDebugger, and app-specific logs
3. **Unified Logging** - Structured logs filterable by subsystem and category
4. **Device Console Access** - Real-time streaming and log collection

## Quick Start

### Method 1: Automated Script (Recommended)

```bash
# Start log capture
./capture_uitest_logs.sh ComprehensiveConsoleCapture

# In another terminal, run your test
xcodebuild test -project HammerTime.xcodeproj \
  -scheme HammerTime \
  -destination 'platform=tvOS,name=Apple TV' \
  -only-testing:HammerTimeUITests/FocusStressUITests/testComprehensiveConsoleCapture

# Stop capture with Ctrl+C when test completes
```

### Method 2: Manual Setup

1. **Enable UITest Console Capture in Code:**
   ```swift
   func testMyTest() throws {
       setupComprehensiveConsoleCapture(testName: "MyTest")
       startConsoleMonitoring(testName: "MyTest")
       
       // Your test code here
       
       stopConsoleMonitoring(testName: "MyTest", success: true)
   }
   ```

2. **Launch App with Enhanced Logging:**
   The setup automatically configures these launch arguments:
   - `--enable-console-logging`
   - `--verbose-accessibility-logging`
   - `--capture-uitest-logs`

## Features Added

### 1. Enhanced TestRunLogger

**New unified logging support:**
```swift
// Standard logging (file + console + unified)
TestRunLogger.shared.log("Test message")

// UITest-specific logging
TestRunLogger.shared.logUITest("UITest-specific message")

// Accessibility debugging
TestRunLogger.shared.logAXDebug("AX debugging message")
```

**Automatic UITest detection:**
- Detects `UITEST_EXECUTION=TRUE` environment variable
- Auto-starts TestRunLogger with test name from `UITEST_NAME`
- Enables verbose console output automatically

### 2. Enhanced AXFocusDebugger

**Added unified logging:**
- All `[AXDBG]` messages now also go to unified logging
- Filterable by category: `com.showblender.HammerTime.AXFocusDebugger`
- Maintains original NSLog output for compatibility

### 3. UITest Extensions

**New methods in `FocusStressUITests+Extensions.swift`:**
- `setupComprehensiveConsoleCapture(testName:)` - One-call setup
- `startConsoleMonitoring(testName:)` - Begin monitoring
- `logUITestMessage(_:)` - Test-specific logging
- `printConsoleAccessInstructions(testName:)` - Help text

### 4. AppDelegate Integration

**Automatic UITest detection:**
- Detects launch from UITest environment
- Configures enhanced logging automatically
- Auto-starts TestRunLogger and AXFocusDebugger
- Optimizes console output for UITest capture

## Accessing Captured Logs

### Real-time Console Access

#### Option 1: Xcode Console
1. Xcode → Window → Devices and Simulators
2. Select your Apple TV device
3. Click "Open Console"
4. Filter by subsystem: `com.showblender.HammerTime`

#### Option 2: Console.app (macOS)
1. Open Console.app
2. Select your Apple TV in sidebar
3. Search for `com.showblender.HammerTime` or `TestRunLogger`

#### Option 3: Terminal Streaming
```bash
# Live streaming
xcrun devicectl log stream --device [DEVICE-ID] \
  --predicate 'subsystem == "com.showblender.HammerTime"'

# Collect time-based logs
xcrun devicectl log collect --device [DEVICE-ID] \
  --start "2025-06-25 10:00:00" \
  --output uitest-logs.logarchive
```

### Log File Access

#### Option 1: App Container (Recommended)
1. Xcode → Window → Devices and Simulators
2. Select device → Installed Apps → HammerTime
3. Download Container
4. Navigate to `Documents/HammerTimeLogs/`

#### Option 2: Automated Script Output
When using `capture_uitest_logs.sh`:
- Raw logs: `logs/UITestConsoleCapture/[timestamp]-[testname]-raw.log`
- Filtered: `logs/UITestConsoleCapture/[timestamp]-[testname]-filtered.log`
- Summary: `logs/UITestConsoleCapture/[timestamp]-[testname]-summary.txt`

## Log Filtering and Categories

### Unified Logging Categories

| Category | Purpose | Example Filter |
|----------|---------|----------------|
| `TestRunLogger` | Test execution logs | `category == "TestRunLogger"` |
| `AXFocusDebugger` | Accessibility debugging | `category == "AXFocusDebugger"` |
| `UITestExecution` | UITest framework logs | `category == "UITestExecution"` |
| `UITestSetup` | Test setup and configuration | `category == "UITestSetup"` |
| `UITestMonitoring` | Test monitoring and status | `category == "UITestMonitoring"` |

### Console.app Filters

```
# All HammerTime logs
subsystem:com.showblender.HammerTime

# TestRunLogger only
subsystem:com.showblender.HammerTime AND category:TestRunLogger

# AXFocusDebugger only
subsystem:com.showblender.HammerTime AND category:AXFocusDebugger

# UITest execution logs
subsystem:com.showblender.HammerTime AND category:UITestExecution
```

## Example Test with Full Console Capture

```swift
func testInfinityBugWithFullLogging() throws {
    // Set up comprehensive console capture
    setupComprehensiveConsoleCapture(testName: "InfinityBugDetection")
    startConsoleMonitoring(testName: "InfinityBugDetection")
    
    // Print access instructions
    printConsoleAccessInstructions(testName: "InfinityBugDetection")
    
    // Your test logic here
    logUITestMessage("Starting InfinityBug reproduction sequence")
    
    // ... test steps ...
    
    logUITestMessage("InfinityBug reproduction completed")
    
    // Stop monitoring
    stopConsoleMonitoring(testName: "InfinityBugDetection", success: true)
}
```

## Troubleshooting

### Issue: No logs appearing in Console.app
**Solution:** Check subsystem filter - use exact string `com.showblender.HammerTime`

### Issue: TestRunLogger not auto-starting
**Solution:** Verify environment variables:
- `UITEST_EXECUTION=TRUE`
- `AUTO_START_TEST_LOGGER=TRUE`
- `UITEST_NAME=[testname]`

### Issue: Missing AXFocusDebugger logs
**Solution:** Enable with environment variable `AXFOCUS_DEBUGGER_VERBOSE=TRUE`

### Issue: Script can't find device
**Solution:** 
```bash
# List available devices
xcrun devicectl list devices

# Use specific device ID
./capture_uitest_logs.sh MyTest [device-id]
```

## Advanced Usage

### Custom Log Categories

Add your own unified logging categories:
```swift
private static let customLogger = Logger(
    subsystem: "com.showblender.HammerTime", 
    category: "CustomCategory"
)

customLogger.info("Custom log message")
```

### Programmatic Log Collection

```swift
// In your test
func collectLogsForTimeRange() {
    let startTime = ISO8601DateFormatter().string(from: Date())
    
    // Run your test
    
    let endTime = ISO8601DateFormatter().string(from: Date())
    
    // Collect logs for this time range
    // (Use xcrun devicectl log collect with --start and --end)
}
```

### Integration with CI/CD

```yaml
# GitHub Actions example
- name: Capture UITest Logs
  run: |
    ./capture_uitest_logs.sh ${{ matrix.test-name }} &
    LOG_PID=$!
    
    xcodebuild test \
      -project HammerTime.xcodeproj \
      -scheme HammerTime \
      -destination 'platform=tvOS Simulator,name=Apple TV' \
      -only-testing:HammerTimeUITests/${{ matrix.test-name }}
    
    kill $LOG_PID
    
- name: Upload Logs
  uses: actions/upload-artifact@v3
  with:
    name: uitest-logs-${{ matrix.test-name }}
    path: logs/UITestConsoleCapture/
```

## Best Practices

1. **Use descriptive test names** - They become part of log file names
2. **Enable console capture for debugging tests** - Especially for InfinityBug reproduction
3. **Filter logs by category** - Focus on relevant information
4. **Archive important logs** - Save successful reproduction logs for analysis
5. **Clean up old logs** - Console logs can consume significant disk space

## File Structure

```
HammerTime/
├── capture_uitest_logs.sh              # Automated log capture script
├── README_UITEST_CONSOLE_CAPTURE.md    # This guide
├── HammerTime/
│   ├── AppDelegate.swift               # Enhanced with UITest detection
│   ├── TestRunLogger.swift             # Enhanced with unified logging
│   └── AXFocusDebugger.swift          # Enhanced with unified logging
├── HammerTimeUITests/
│   └── FocusStressUITests+Extensions.swift # Console capture methods
└── logs/
    ├── UITestConsoleCapture/           # Script output directory
    └── UITestRunLogs-OnDevice/         # Device log files
```

This setup provides comprehensive console log capture for UITest execution, making it much easier to debug test failures and analyze InfinityBug reproduction attempts. 
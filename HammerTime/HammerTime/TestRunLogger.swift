//
//  TestRunLogger.swift
//  HammerTime
//
//  Comprehensive test run logging system for InfinityBug reproduction analysis.
//  Captures console output, test messages, system info, and timing data.
//  Works for both manual execution and automated UI test runs.

import Foundation
import UIKit
import os.log

/// Comprehensive test run logging system for InfinityBug analysis
/// 
/// **Features:**
/// - Automatic timestamped log files in logs/testRunLogs/
/// - Console output capture and redirection
/// - Test execution metadata and timing
/// - System information and environment capture
/// - Both manual and UI test execution support
/// - Structured log format for analysis tools
/// - **NEW**: Unified logging for UITest console capture
public final class TestRunLogger {
    
    // MARK: - Singleton Instance
    
    /// Shared logger instance for global access
    public static let shared = TestRunLogger()
    
    // MARK: - Unified Logging Support
    
    /// Unified logging subsystem for filtering UITest console output
    private static let logger = Logger(subsystem: "com.showblender.HammerTime", category: "TestRunLogger")
    private static let axLogger = Logger(subsystem: "com.showblender.HammerTime", category: "AXFocusDebugger")
    private static let uiTestLogger = Logger(subsystem: "com.showblender.HammerTime", category: "UITestExecution")
    
    // MARK: - Properties
    
    private var currentLogFile: URL?
    private var logFileHandle: FileHandle?
    private var isLogging = false
    private var startTime: Date?
    private var testName: String?
    
    /// Logger configuration for different execution contexts
    public struct LoggerConfig {
        let testName: String
        let executionContext: ExecutionContext
        let captureConsole: Bool
        let includeSystemInfo: Bool
        
        public init(testName: String, 
                   executionContext: ExecutionContext = .manual, 
                   captureConsole: Bool = true, 
                   includeSystemInfo: Bool = true) {
            self.testName = testName
            self.executionContext = executionContext
            self.captureConsole = captureConsole
            self.includeSystemInfo = includeSystemInfo
        }
    }
    
    /// Execution context for different test types
    public enum ExecutionContext: String, CaseIterable {
        case manual = "Manual"
        case uiTest = "UITest"
        case automation = "Automation"
        case debug = "Debug"
    }
    
    // MARK: - Initialization
    
    private init() {
        createLogsDirectoryIfNeeded()
    }
    
    // MARK: - Public Interface
    
    /// Starts logging for a test run with comprehensive metadata capture
    /// 
    /// - Parameter config: Logger configuration specifying test details
    /// - Returns: Success status of log initialization
    @discardableResult
    public func startLogging(config: LoggerConfig) -> Bool {
        guard !isLogging else {
            NSLog("TestRunLogger: Already logging - stop current session first")
            return false
        }
        
        let timestamp = generateTimestamp()
        let sanitizedTestName = sanitizeFileName(config.testName)
        let fileName = "\(timestamp)-\(sanitizedTestName).txt"  // Match existing format like "62325-1439DidNotRepro.txt"
        
        guard let logFile = createLogFile(named: fileName) else {
            NSLog("TestRunLogger: Failed to create log file: \(fileName)")
            return false
        }
        
        currentLogFile = logFile
        testName = config.testName
        startTime = Date()
        isLogging = true
        
        // Initialize log file with metadata header
        writeLogHeader(config: config, timestamp: timestamp)
        
        log("TEST-START: \(config.testName) (\(config.executionContext.rawValue))")
        
        return true
    }
    
    /// Stops logging and finalizes the log file with summary information
    /// 
    /// - Parameter testResult: Optional test result for summary
    public func stopLogging(testResult: TestResult? = nil) {
        guard isLogging else { return }
        
        let endTime = Date()
        let duration = startTime.map { endTime.timeIntervalSince($0) } ?? 0
        
        log("🏁 TEST-END: \(testName ?? "Unknown") - Duration: \(String(format: "%.2f", duration))s")
        
        if let result = testResult {
            writeTestResultSummary(result: result, duration: duration)
        }
        
        writeLogFooter(endTime: endTime, duration: duration)
        
        // Close file handle
        logFileHandle?.closeFile()
        logFileHandle = nil
        
        isLogging = false
        let finalLogFile = currentLogFile
        currentLogFile = nil
        startTime = nil
        testName = nil
        
        NSLog("TestRunLogger: Log saved to \(finalLogFile?.lastPathComponent ?? "unknown")")
        
        // Only consolidate logs for manual/automation runs.  tvOS UI-test sandbox blocks Documents access
        // and the consolidation attempt just emits errors, wasting time.
        if ProcessInfo.processInfo.environment["XCInjectBundleInto"] == nil {
            _ = consolidateLogsForRetrieval()
        }
    }
    
    /// Logs a message with timestamp and automatic file writing
    /// 
    /// - Parameter message: Message to log
    public func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logEntry = "[\(timestamp)] \(message)\n"
        
        // Write to file if logging is active
        if isLogging, let data = logEntry.data(using: .utf8) {
            logFileHandle?.write(data)
        }
        
        let isUITest = ProcessInfo.processInfo.environment["XCInjectBundleInto"] != nil

        if isUITest {
            // For UITest context: single output to avoid duplication
            print("TestRunLogger: \(message)")
        } else {
            // For manual/automation context: use NSLog only
            NSLog("TestRunLogger: \(message)")
        }
        
        // // Use unified logging for structured console capture
        // Self.logger.notice("\(message, privacy: .public)")
    }
    
    /// Logs a message specifically for UITest execution context
    /// 
    /// - Parameter message: Message to log during UITest
    public func logUITest(_ message: String) {
        log(message) // Use standard logging
        Self.uiTestLogger.notice("UITEST: \(message, privacy: .public)")
    }
    
    /// Logs accessibility debugging information with separate category
    /// 
    /// - Parameter message: AX debugging message
    public func logAXDebug(_ message: String) {
        log(message) // Use standard logging
        Self.axLogger.debug("AXDBG: \(message, privacy: .public)")
    }
    
    /// Logs system information for debugging and analysis
    public func logSystemInfo() {
        log("SYSTEM-INFO:")
        log("  Device: \(UIDevice.current.name)")
        log("  OS: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
        log("  Model: \(UIDevice.current.model)")
        log("  Memory: \(getMemoryInfo())")
        log("  VoiceOver: \(UIAccessibility.isVoiceOverRunning ? "ENABLED" : "DISABLED")")
        log("  Reduce Motion: \(UIAccessibility.isReduceMotionEnabled ? "ENABLED" : "DISABLED")")
    }
    
    /// Logs InfinityBug detection event with detailed context
    /// 
    /// - Parameters:
    ///   - eventType: Type of InfinityBug event detected
    ///   - details: Additional context and debugging information
    public func logInfinityBugEvent(eventType: String, details: [String: Any]) {
        log("INFINITYBUG-EVENT: \(eventType)")
        for (key, value) in details {
            log("  \(key): \(value)")
        }
    }
    
    /// Logs performance metrics for test analysis
    /// 
    /// - Parameter metrics: Performance metrics dictionary
    public func logPerformanceMetrics(_ metrics: [String: Any]) {
        log("PERFORMANCE-METRICS:")
        for (key, value) in metrics {
            log("  \(key): \(value)")
        }
    }
    
    /// Prints the actual log file location for manual retrieval
    /// 
    /// Use this method to find where the TestRunLogger is actually writing files
    /// since tvOS/iOS sandboxing may put them in unexpected locations.
    public func printLogFileLocation() {
        if let logFile = currentLogFile {
                    NSLog("CURRENT-LOG-LOCATION: \(logFile.path)")
        NSLog("PARENT-DIRECTORY: \(logFile.deletingLastPathComponent().path)")
    } else {
        NSLog("NO-ACTIVE-LOG: TestRunLogger not currently logging")
        }
        
        // Check all possible log locations
        printAllLogLocations()
    }
    
    /// Comprehensive log location discovery for troubleshooting
    /// 
    /// Searches all possible log directories and lists found files
    public func printAllLogLocations() {
        NSLog("COMPREHENSIVE-LOG-SEARCH:")
        
        let isUITest = ProcessInfo.processInfo.environment["XCInjectBundleInto"] != nil

        if isUITest {
            // In UI-test sandbox only tmp is accessible. Listing others just produces errors.
            let tempURL = FileManager.default.temporaryDirectory
            NSLog("TEMPORARY-DIRECTORY: \(tempURL.path)")
            listHammerTimeFilesInDirectory(tempURL, prefix: "  ")
            return
        }

        // Manual / automation context: list all potential directories

        // 1. Main HammerTimeLogs directory
        let logsURL = getLogsDirectoryURL()
        NSLog("1. MAIN-DIRECTORY: \(logsURL.path)")
        listFilesInDirectory(logsURL, prefix: "  ")

        // 2. UITestRunLogs subdirectory
        let testRunLogsURL = logsURL.appendingPathComponent("UITestRunLogs")
        NSLog("2. UITEST-DIRECTORY: \(testRunLogsURL.path)")
        listFilesInDirectory(testRunLogsURL, prefix: "  ")

        // 3. Documents root directory
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            NSLog("3. DOCUMENTS-ROOT: \(documentsURL.path)")
            listHammerTimeFilesInDirectory(documentsURL, prefix: "  ")
        }

        // 4. Temporary directory
        let tempURL = FileManager.default.temporaryDirectory
        NSLog("4. TEMPORARY-DIRECTORY: \(tempURL.path)")
        listHammerTimeFilesInDirectory(tempURL, prefix: "  ")
    }
    
    /// Lists all files in the specified directory
    /// 
    /// - Parameters:
    ///   - directoryURL: Directory to search
    ///   - prefix: Prefix for console output formatting
    private func listFilesInDirectory(_ directoryURL: URL, prefix: String) {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: directoryURL, 
                                                                   includingPropertiesForKeys: nil)
            if files.isEmpty {
                NSLog("\(prefix)No files found")
            } else {
                NSLog("\(prefix)\(files.count) files found:")
                for file in files.prefix(10) {
                    NSLog("\(prefix)  - \(file.lastPathComponent)")
                }
                if files.count > 10 {
                    NSLog("\(prefix)  ... and \(files.count - 10) more files")
                }
            }
        } catch {
            NSLog("\(prefix)Error accessing directory: \(error)")
        }
    }
    
    /// Lists HammerTime-related files in the specified directory
    /// 
    /// - Parameters:
    ///   - directoryURL: Directory to search
    ///   - prefix: Prefix for console output formatting
    private func listHammerTimeFilesInDirectory(_ directoryURL: URL, prefix: String) {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: directoryURL, 
                                                                   includingPropertiesForKeys: nil)
            let hammerTimeFiles = files.filter { file in
                let name = file.lastPathComponent.lowercased()
                return name.contains("hammer") || name.contains("manual") || name.contains("focus") || name.hasSuffix(".txt")
            }
            
            if hammerTimeFiles.isEmpty {
                NSLog("\(prefix)No HammerTime files found")
            } else {
                NSLog("\(prefix)\(hammerTimeFiles.count) HammerTime-related files found:")
                for file in hammerTimeFiles.prefix(10) {
                    NSLog("\(prefix)  - \(file.lastPathComponent)")
                }
                if hammerTimeFiles.count > 10 {
                    NSLog("\(prefix)  ... and \(hammerTimeFiles.count - 10) more files")
                }
            }
        } catch {
            NSLog("\(prefix)Error accessing directory: \(error)")
        }
    }
    
    // MARK: - Test Result Types
    
    /// Test result structure for comprehensive reporting
    public struct TestResult {
        let success: Bool
        let infinityBugReproduced: Bool
        let runLoopStalls: [TimeInterval]
        let phantomEvents: Int
        let focusChanges: Int
        let totalActions: Int
        let errorMessages: [String]
        let additionalMetrics: [String: Any]
        
        public init(success: Bool,
                   infinityBugReproduced: Bool = false,
                   runLoopStalls: [TimeInterval] = [],
                   phantomEvents: Int = 0,
                   focusChanges: Int = 0,
                   totalActions: Int = 0,
                   errorMessages: [String] = [],
                   additionalMetrics: [String: Any] = [:]) {
            self.success = success
            self.infinityBugReproduced = infinityBugReproduced
            self.runLoopStalls = runLoopStalls
            self.phantomEvents = phantomEvents
            self.focusChanges = focusChanges
            self.totalActions = totalActions
            self.errorMessages = errorMessages
            self.additionalMetrics = additionalMetrics
        }
    }
    
    // MARK: - Private Implementation
    
    /// Creates logs directory structure if it doesn't exist
    private func createLogsDirectoryIfNeeded() {
        let logsURL = getLogsDirectoryURL()
        
        do {
            // First ensure main HammerTimeLogs directory exists
            try FileManager.default.createDirectory(at: logsURL, 
                                                  withIntermediateDirectories: true, 
                                                  attributes: nil)
            log("MAIN-DIRECTORY: \(logsURL.path)")
            
            // Try to create UITestRunLogs subdirectory (but don't fail if it can't)
            let testRunLogsURL = logsURL.appendingPathComponent("UITestRunLogs")
            try FileManager.default.createDirectory(at: testRunLogsURL, 
                                                  withIntermediateDirectories: true, 
                                                  attributes: nil)
            log("SUB-DIRECTORY: \(testRunLogsURL.path)")
        } catch {
            log("DIRECTORY-WARNING: \(error)")
            NSLog("TestRunLogger: Directory creation warning (fallback available): \(error)")
        }
    }
    
    /// Creates a new log file with the specified name using multiple fallback strategies
    /// 
    /// - Parameter fileName: Name for the log file
    /// - Returns: URL of created log file, or nil if creation failed
    private func createLogFile(named fileName: String) -> URL? {
        // Strategy 1: Try UITestRunLogs subdirectory
        if let logFileURL = tryCreateLogFile(fileName, in: .uiTestRunLogs) {
            return logFileURL
        }
        
        // Strategy 2: Try main HammerTimeLogs directory
        if let logFileURL = tryCreateLogFile(fileName, in: .mainDirectory) {
            return logFileURL
        }
        
        // Strategy 3: Try Documents directory directly
        if let logFileURL = tryCreateLogFile(fileName, in: .documentsRoot) {
            return logFileURL
        }
        
        // Strategy 4: Use temporary directory
        if let logFileURL = tryCreateLogFile(fileName, in: .temporary) {
            return logFileURL
        }
        
        log("ALL-STRATEGIES-FAILED: Could not create log file anywhere")
        return nil
    }
    
    /// Directory strategies for log file creation
    private enum LogDirectoryStrategy {
        case uiTestRunLogs
        case mainDirectory
        case documentsRoot
        case temporary
    }
    
    /// Attempts to create a log file using the specified directory strategy
    /// 
    /// - Parameters:
    ///   - fileName: Name for the log file
    ///   - strategy: Directory strategy to use
    /// - Returns: URL of created log file, or nil if creation failed
    private func tryCreateLogFile(_ fileName: String, in strategy: LogDirectoryStrategy) -> URL? {
        let directoryURL: URL
        let strategyName: String
        
        switch strategy {
        case .uiTestRunLogs:
            directoryURL = getLogsDirectoryURL().appendingPathComponent("UITestRunLogs")
            strategyName = "UITestRunLogs"
        case .mainDirectory:
            directoryURL = getLogsDirectoryURL()
            strategyName = "HammerTimeLogs"
        case .documentsRoot:
            guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return nil
            }
            directoryURL = documentsURL
            strategyName = "Documents"
        case .temporary:
            directoryURL = FileManager.default.temporaryDirectory
            strategyName = "Temporary"
        }
        
        let logFileURL = directoryURL.appendingPathComponent(fileName)
        
        do {
            // Ensure parent directory exists (except for temporary)
            if strategy != .temporary {
                try FileManager.default.createDirectory(at: directoryURL, 
                                                      withIntermediateDirectories: true, 
                                                      attributes: nil)
            }
            
            // Create empty file
            let success = FileManager.default.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
            if !success {
                throw NSError(domain: "TestRunLogger", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create file"])
            }
            
            // Open file handle for writing
            logFileHandle = try FileHandle(forWritingTo: logFileURL)
            
            log("LOG-FILE-SUCCESS: \(strategyName) strategy - \(logFileURL.path)")
            return logFileURL
        } catch {
            log("STRATEGY-FAILED: \(strategyName) - \(error)")
            return nil
        }
    }
    
    /// Writes comprehensive header information to log file
    /// 
    /// - Parameters:
    ///   - config: Logger configuration
    ///   - timestamp: Test start timestamp
    private func writeLogHeader(config: LoggerConfig, timestamp: String) {
        let header = """
        ================================================================================
        HAMMERTIME INFINITYBUG TEST RUN LOG
        ================================================================================
        
        Test Name: \(config.testName)
        Execution Context: \(config.executionContext.rawValue)
        Start Time: \(timestamp)
        Log File: \(currentLogFile?.lastPathComponent ?? "unknown")
        
        Configuration:
        - Console Capture: \(config.captureConsole ? "ENABLED" : "DISABLED")
        - System Info: \(config.includeSystemInfo ? "ENABLED" : "DISABLED")
        
        ================================================================================
        
        """
        
        if let data = header.data(using: .utf8) {
            logFileHandle?.write(data)
        }
        
        // Add system info if requested
        if config.includeSystemInfo {
            logSystemInfo()
        }
    }
    
    /// Writes test result summary to log file
    /// 
    /// - Parameters:
    ///   - result: Test result data
    ///   - duration: Test execution duration
    private func writeTestResultSummary(result: TestResult, duration: TimeInterval) {
        log("TEST-RESULT-SUMMARY:")
        log("  Success: \(result.success ? "PASS" : "FAIL")")
        log("  InfinityBug Reproduced: \(result.infinityBugReproduced ? "YES" : "NO")")
        log("  Duration: \(String(format: "%.2f", duration))s")
        log("  Total Actions: \(result.totalActions)")
        log("  Focus Changes: \(result.focusChanges)")
        log("  Phantom Events: \(result.phantomEvents)")
        log("  RunLoop Stalls: \(result.runLoopStalls.count) (Max: \(result.runLoopStalls.max() ?? 0)ms)")
        
        if !result.errorMessages.isEmpty {
            log("  Errors:")
            for error in result.errorMessages {
                log("    - \(error)")
            }
        }
        
        if !result.additionalMetrics.isEmpty {
            log("  Additional Metrics:")
            for (key, value) in result.additionalMetrics {
                log("    \(key): \(value)")
            }
        }
    }
    
    /// Writes footer information to log file
    /// 
    /// - Parameters:
    ///   - endTime: Test end time
    ///   - duration: Test execution duration
    private func writeLogFooter(endTime: Date, duration: TimeInterval) {
        let footer = """
        
        ================================================================================
        TEST RUN COMPLETED
        ================================================================================
        
        End Time: \(ISO8601DateFormatter().string(from: endTime))
        Total Duration: \(String(format: "%.2f", duration)) seconds
        Log File: \(currentLogFile?.lastPathComponent ?? "unknown")
        
        ================================================================================
        
        """
        
        if let data = footer.data(using: .utf8) {
            logFileHandle?.write(data)
        }
    }
    
    /// Generates timestamp string for file naming
    /// 
    /// - Returns: Formatted timestamp string matching existing log format
    private func generateTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMddyy-HHmmss"
        return formatter.string(from: Date())
    }
    
    /// Sanitizes filename by removing invalid characters
    /// 
    /// - Parameter fileName: Original filename
    /// - Returns: Sanitized filename safe for filesystem
    private func sanitizeFileName(_ fileName: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/<>:\"|?*()")
        return fileName.components(separatedBy: invalidChars).joined(separator: "_")
    }
    
    /// Gets the logs directory URL with tvOS/iOS sandboxing support
    /// 
    /// - Returns: URL of logs directory that's guaranteed to be writable
    private func getLogsDirectoryURL() -> URL {
        // Prefer a tmp directory when running inside a UI-test sandbox – Documents is usually read-only.
        let isUITest = ProcessInfo.processInfo.environment["XCInjectBundleInto"] != nil
        if isUITest {
            let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("HammerTimeLogs")
            log("UITEST-MODE: Using tmp/HammerTimeLogs at \(tmpURL.path)")
            return tmpURL
        }

        // Otherwise attempt Documents → HammerTimeLogs
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let logsURL = documentsURL.appendingPathComponent("HammerTimeLogs")
            log("LOGS-PATH: Using Documents/HammerTimeLogs at \(logsURL.path)")
            return logsURL
        }

        // Ultimate fallback: tmp directory
        let fallbackURL = FileManager.default.temporaryDirectory.appendingPathComponent("HammerTimeLogs")
                    log("FALLBACK: Could not access Documents – using tmp at \(fallbackURL.path)")
        return fallbackURL
    }
    
    /// Gets current memory usage information
    /// 
    /// - Returns: Memory usage string
    private func getMemoryInfo() -> String {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let memoryMB = info.resident_size / (1024 * 1024)
            return "\(memoryMB) MB"
        } else {
            return "Unknown"
        }
    }
}

// MARK: - Convenience Extensions

extension TestRunLogger {
    
    /// Quick start for manual test execution
    /// 
    /// - Parameter testName: Name of the test being executed
    /// - Returns: Success status
    @discardableResult
    public func startManualTest(_ testName: String) -> Bool {
        let config = LoggerConfig(testName: testName, executionContext: .manual)
        return startLogging(config: config)
    }
    
    /// Quick start for UI test execution
    /// 
    /// - Parameter testName: Name of the UI test being executed
    /// - Returns: Success status
    @discardableResult
    public func startUITest(_ testName: String) -> Bool {
        let config = LoggerConfig(testName: testName, executionContext: .uiTest)
        return startLogging(config: config)
    }
    
    /// Quick start for UI test execution with automatic InfinityBug focus
    /// 
    /// - Parameter testMethodName: XCTest method name (e.g., "testDevTicket_EdgeAvoidanceNavigationPattern")
    /// - Returns: Success status
    @discardableResult
    public func startInfinityBugUITest(_ testMethodName: String) -> Bool {
        // Extract meaningful name from test method
        let cleanName = testMethodName
            .replacingOccurrences(of: "test", with: "")
            .replacingOccurrences(of: "DevTicket_", with: "")
            .replacingOccurrences(of: "Evolved", with: "")
            .replacingOccurrences(of: "InfinityBug", with: "IBug")
        
        let config = LoggerConfig(
            testName: cleanName,
            executionContext: .uiTest,
            captureConsole: true,
            includeSystemInfo: true
        )
        return startLogging(config: config)
    }
    
    /// Copies all HammerTime log files to an easily accessible location for retrieval
    /// 
    /// This method consolidates all log files from various locations into a single
    /// directory that can be easily accessed via Xcode's Devices and Simulators window.
    /// 
    /// - Returns: URL of the consolidated logs directory
    @discardableResult
    public func consolidateLogsForRetrieval() -> URL? {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            NSLog("CONSOLIDATE: Cannot access Documents directory")
            return nil
        }
        
        let consolidatedURL = documentsURL.appendingPathComponent("ConsolidatedHammerTimeLogs")
        
        do {
            // Create consolidated directory
            try FileManager.default.createDirectory(at: consolidatedURL, 
                                                  withIntermediateDirectories: true, 
                                                  attributes: nil)
            
            var totalFilesCopied = 0
            
            // Copy from main HammerTimeLogs directory
            totalFilesCopied += copyLogsFromDirectory(getLogsDirectoryURL(), 
                                                    to: consolidatedURL, 
                                                    sourceName: "MainLogs")
            
            // Copy from UITestRunLogs subdirectory
            let testRunLogsURL = getLogsDirectoryURL().appendingPathComponent("UITestRunLogs")
            totalFilesCopied += copyLogsFromDirectory(testRunLogsURL, 
                                                    to: consolidatedURL, 
                                                    sourceName: "UITestLogs")
            
            // Copy from temporary directory
            totalFilesCopied += copyHammerTimeLogsFromDirectory(FileManager.default.temporaryDirectory, 
                                                              to: consolidatedURL, 
                                                              sourceName: "TempLogs")
            
            NSLog("CONSOLIDATE-SUCCESS: \(totalFilesCopied) files copied to \(consolidatedURL.path)")
            NSLog("RETRIEVAL-INSTRUCTIONS:")
            NSLog("   1. Open Xcode → Window → Devices and Simulators")
            NSLog("   2. Select your Apple TV device")
            NSLog("   3. Click on 'Installed Apps' and find HammerTime")
            NSLog("   4. Click 'Download Container...' and save to your Mac")
            NSLog("   5. Look in Documents/ConsolidatedHammerTimeLogs/ for all log files")
            
            return consolidatedURL
        } catch {
            NSLog("CONSOLIDATE-FAILED: \(error)")
            return nil
        }
    }
    
    /// Copies log files from source directory to consolidated directory
    /// 
    /// - Parameters:
    ///   - sourceURL: Source directory URL
    ///   - destinationURL: Destination directory URL
    ///   - sourceName: Descriptive name for logging
    /// - Returns: Number of files copied
    private func copyLogsFromDirectory(_ sourceURL: URL, to destinationURL: URL, sourceName: String) -> Int {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: sourceURL, 
                                                                   includingPropertiesForKeys: nil)
            let logFiles = files.filter { $0.pathExtension.lowercased() == "txt" }
            
            var copiedCount = 0
            for file in logFiles {
                let destinationFile = destinationURL.appendingPathComponent("\(sourceName)_\(file.lastPathComponent)")
                do {
                    try FileManager.default.copyItem(at: file, to: destinationFile)
                    copiedCount += 1
                } catch {
                    NSLog("COPY-FAILED: \(file.lastPathComponent) - \(error)")
                }
            }
            
            if copiedCount > 0 {
                NSLog("COPIED: \(copiedCount) files from \(sourceName)")
            }
            return copiedCount
        } catch {
            NSLog("SOURCE-ACCESS-FAILED: \(sourceName) - \(error)")
            return 0
        }
    }
    
    /// Copies HammerTime-related log files from source directory to consolidated directory
    /// 
    /// - Parameters:
    ///   - sourceURL: Source directory URL
    ///   - destinationURL: Destination directory URL
    ///   - sourceName: Descriptive name for logging
    /// - Returns: Number of files copied
    private func copyHammerTimeLogsFromDirectory(_ sourceURL: URL, to destinationURL: URL, sourceName: String) -> Int {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: sourceURL, 
                                                                   includingPropertiesForKeys: nil)
            let hammerTimeFiles = files.filter { file in
                let name = file.lastPathComponent.lowercased()
                return (name.contains("hammer") || name.contains("manual") || name.contains("focus")) && 
                       file.pathExtension.lowercased() == "txt"
            }
            
            var copiedCount = 0
            for file in hammerTimeFiles {
                let destinationFile = destinationURL.appendingPathComponent("\(sourceName)_\(file.lastPathComponent)")
                do {
                    try FileManager.default.copyItem(at: file, to: destinationFile)
                    copiedCount += 1
                } catch {
                    NSLog("COPY-FAILED: \(file.lastPathComponent) - \(error)")
                }
            }
            
            if copiedCount > 0 {
                NSLog("COPIED: \(copiedCount) HammerTime files from \(sourceName)")
            }
            return copiedCount
        } catch {
            NSLog("SOURCE-ACCESS-FAILED: \(sourceName) - \(error)")
            return 0
        }
    }
} 
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
public final class TestRunLogger {
    
    // MARK: - Singleton Instance
    
    /// Shared logger instance for global access
    public static let shared = TestRunLogger()
    
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
        
        log("🚀 TEST-START: \(config.testName) (\(config.executionContext.rawValue))")
        
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
        
        // Also output to console for real-time monitoring
        NSLog("TestRunLogger: \(message)")
    }
    
    /// Logs system information for debugging and analysis
    public func logSystemInfo() {
        log("📊 SYSTEM-INFO:")
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
        log("🚨 INFINITYBUG-EVENT: \(eventType)")
        for (key, value) in details {
            log("  \(key): \(value)")
        }
    }
    
    /// Logs performance metrics for test analysis
    /// 
    /// - Parameter metrics: Performance metrics dictionary
    public func logPerformanceMetrics(_ metrics: [String: Any]) {
        log("⚡ PERFORMANCE-METRICS:")
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
            NSLog("📁 CURRENT-LOG-LOCATION: \(logFile.path)")
            NSLog("📁 PARENT-DIRECTORY: \(logFile.deletingLastPathComponent().path)")
        } else {
            NSLog("📁 NO-ACTIVE-LOG: TestRunLogger not currently logging")
        }
        
        let logsURL = getLogsDirectoryURL()
        NSLog("📁 LOGS-DIRECTORY: \(logsURL.path)")
        
        // List existing log files
        do {
            let testRunLogsURL = logsURL.appendingPathComponent("UITestRunLogs")
            let files = try FileManager.default.contentsOfDirectory(at: testRunLogsURL, 
                                                                   includingPropertiesForKeys: nil)
            NSLog("📁 EXISTING-LOGS: \(files.count) files")
            for file in files.prefix(5) {
                NSLog("📁   - \(file.lastPathComponent)")
            }
        } catch {
            NSLog("📁 LOG-DIRECTORY-ERROR: \(error)")
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
        let testRunLogsURL = logsURL.appendingPathComponent("UITestRunLogs")
        
        do {
            try FileManager.default.createDirectory(at: testRunLogsURL, 
                                                  withIntermediateDirectories: true, 
                                                  attributes: nil)
            log("✅ DIRECTORY-CREATED: \(testRunLogsURL.path)")
        } catch {
            log("❌ DIRECTORY-FAILED: \(error)")
            NSLog("TestRunLogger: Failed to create UITestRunLogs directory: \(error)")
        }
    }
    
    /// Creates a new log file with the specified name
    /// 
    /// - Parameter fileName: Name for the log file
    /// - Returns: URL of created log file, or nil if creation failed
    private func createLogFile(named fileName: String) -> URL? {
        let logsURL = getLogsDirectoryURL()
        let testRunLogsURL = logsURL.appendingPathComponent("UITestRunLogs")
        let logFileURL = testRunLogsURL.appendingPathComponent(fileName)
        
        do {
            // Ensure parent directory exists
            try FileManager.default.createDirectory(at: testRunLogsURL, 
                                                  withIntermediateDirectories: true, 
                                                  attributes: nil)
            
            // Create empty file
            let success = FileManager.default.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
            if !success {
                throw NSError(domain: "TestRunLogger", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create file"])
            }
            
            // Open file handle for writing
            logFileHandle = try FileHandle(forWritingTo: logFileURL)
            
            log("✅ LOG-FILE-CREATED: \(logFileURL.path)")
            return logFileURL
        } catch {
            log("❌ LOG-FILE-FAILED: \(error)")
            NSLog("TestRunLogger: Failed to create log file: \(error)")
            
            // Try fallback in temporary directory
            let tempLogURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            do {
                FileManager.default.createFile(atPath: tempLogURL.path, contents: nil, attributes: nil)
                logFileHandle = try FileHandle(forWritingTo: tempLogURL)
                log("✅ FALLBACK-LOG: \(tempLogURL.path)")
                return tempLogURL
            } catch {
                log("❌ FALLBACK-FAILED: \(error)")
                return nil
            }
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
        log("📋 TEST-RESULT-SUMMARY:")
        log("  Success: \(result.success ? "✅ PASS" : "❌ FAIL")")
        log("  InfinityBug Reproduced: \(result.infinityBugReproduced ? "✅ YES" : "❌ NO")")
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
        formatter.dateFormat = "MMddyy-HHmm"  // Match existing format like "62325-1439"
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
        // Always use app's Documents directory for guaranteed write access
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            // Ultimate fallback: temporary directory
            log("⚠️ FALLBACK: Using temporary directory for logs")
            return FileManager.default.temporaryDirectory.appendingPathComponent("HammerTimeLogs")
        }
        
        let logsURL = documentsURL.appendingPathComponent("HammerTimeLogs")
        log("📁 LOGS-PATH: Using Documents/HammerTimeLogs at \(logsURL.path)")
        
        return logsURL
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
} 
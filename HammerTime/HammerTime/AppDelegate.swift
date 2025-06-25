//
//  AppDelegate.swift
//  HammerTime
//
//  Created by Joseph McCraw on 6/13/25.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // --- Root View Controller Setup ---
        window = UIWindow(frame: UIScreen.main.bounds)
        
        // If a UI test is running and specifies a preset, launch directly into the
        // FocusStressViewController to bypass the main menu. This is the primary
        // entry point for all automated testing.
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-FocusStressPreset") || arguments.contains("-FocusStressMode") {
            // Instantiate with the configuration loaded from launch arguments.
            // This ensures the test runs with the exact configuration it expects.
            let config = FocusStressConfiguration.loadFromLaunchArguments()
            let focusStressVC = FocusStressViewController(configuration: config)
            window?.rootViewController = focusStressVC
        } else {
            // For a normal app launch, set up the main menu inside a navigation
            // controller to allow the user to select a test case.
            let menuVC = MainMenuViewController(style: .grouped)
            let nav = UINavigationController(rootViewController: menuVC)
            window?.rootViewController = nav
        }
        
        window?.makeKeyAndVisible()
        
        // Check for UITest execution and configure logging accordingly
        setupUITestLoggingIfNeeded()
        
        // Enable VoiceOver for UI testing if launch argument is present
        if CommandLine.arguments.contains("--enable-voiceover") {
            enableVoiceOverForTesting()
        }
        
        // Check environment variable as well
        if ProcessInfo.processInfo.environment["VOICEOVER_ENABLED"] == "1" {
            enableVoiceOverForTesting()
        }
        
        return true
    }
    
    /// Configures enhanced logging when launched from UITests
    private func setupUITestLoggingIfNeeded() {
        // Check if launched from UITest environment
        let isUITestExecution = ProcessInfo.processInfo.environment["UITEST_EXECUTION"] == "TRUE"
        let autoStartLogger = ProcessInfo.processInfo.environment["AUTO_START_TEST_LOGGER"] == "TRUE"
        let testName = ProcessInfo.processInfo.environment["UITEST_NAME"]
        
        if isUITestExecution {
            print("🧪 AppDelegate: UITest execution detected - configuring enhanced logging")
            
            // Configure verbose console logging
            if ProcessInfo.processInfo.environment["CONSOLE_LOGGING_ENABLED"] == "TRUE" {
                // Enable all NSLog output
                setenv("OS_ACTIVITY_MODE", "disable", 1) // Disable activity tracing for cleaner logs
                print("🧪 AppDelegate: Console logging enabled for UITest")
            }
            
            // Auto-start TestRunLogger if requested
            if autoStartLogger, let testName = testName {
                DispatchQueue.main.async {
                    let success = TestRunLogger.shared.startUITest(testName)
                    print("🧪 AppDelegate: Auto-started TestRunLogger for '\(testName)': \(success ? "SUCCESS" : "FAILED")")
                    
                    // Log the current log file location for reference
                    TestRunLogger.shared.printLogFileLocation()
                }
            }
            
            // Enable verbose AXFocusDebugger if requested
            if ProcessInfo.processInfo.environment["AXFOCUS_DEBUGGER_VERBOSE"] == "TRUE" {
                DispatchQueue.main.async {
                    AXFocusDebugger.shared.start()
                    print("🧪 AppDelegate: AXFocusDebugger started for UITest")
                }
            }
        }
    }

    /// Enable VoiceOver programmatically for UI testing
    private func enableVoiceOverForTesting() {
        #if DEBUG || TESTING
        print("VOICEOVER: Attempting to enable VoiceOver for testing...")
        
        // Method 1: Try private API approach
        if let voiceOverClass = NSClassFromString("UIAccessibilityVoiceOverController") {
            if let enableMethod = class_getClassMethod(voiceOverClass, NSSelectorFromString("enableVoiceOver")) {
                let implementation = method_getImplementation(enableMethod)
                typealias EnableVoiceOverFunction = @convention(c) (AnyClass, Selector) -> Void
                let enableVoiceOver = unsafeBitCast(implementation, to: EnableVoiceOverFunction.self)
                enableVoiceOver(voiceOverClass, NSSelectorFromString("enableVoiceOver"))
                print("SUCCESS: VoiceOver enabled via private API")
            } else {
                print("WARNING: Could not find enableVoiceOver method")
            }
        } else {
            print("WARNING: Could not find UIAccessibilityVoiceOverController class")
        }
        
        // Method 2: Post notification to announce VoiceOver is starting
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UIAccessibility.post(notification: .announcement, argument: "VoiceOver enabled for testing")
            print("ANNOUNCEMENT: Posted VoiceOver announcement")
        }
        #endif
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }


}


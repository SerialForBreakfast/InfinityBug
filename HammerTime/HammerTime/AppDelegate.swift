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
        // Override point for customization after application launch.
        
        // Programmatically set up the window to allow for launch argument-based routing.
        window = UIWindow(frame: UIScreen.main.bounds)

        // Check for the -FocusStressMode launch argument.
        // If present, launch directly into the FocusStressViewController for stress testing.
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-FocusStressMode") {
            NSLog("APP_DELEGATE: -FocusStressMode detected. Launching FocusStressViewController.")
            let stressVC = FocusStressViewController()
            window?.rootViewController = stressVC
        } else {
            // Otherwise, load the default ViewController from the Main storyboard.
            NSLog("APP_DELEGATE: No torture mode. Launching default ViewController.")
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let initialVC = storyboard.instantiateInitialViewController()
            window?.rootViewController = initialVC
        }
        #else
        // In RELEASE builds, always load the default ViewController.
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let initialVC = storyboard.instantiateInitialViewController()
        window?.rootViewController = initialVC
        #endif
        
        window?.makeKeyAndVisible()
        
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


//
//  VaultTrackerApp.swift
//  VaultTracker
//
//  Created by Caleb Ngai on 6/25/25.
//

import SwiftUI
import UIKit
import Foundation
import Firebase
import FirebaseCrashlytics

@main
struct VaultTrackerApp: App {
    @StateObject var authManager = AuthManager()
    
    init() {
        let runId = "pre-fix"
        let processInfo = ProcessInfo.processInfo
        let isRunningTests = processInfo.environment["XCTestConfigurationFilePath"] != nil
        let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") ?? "missing"
        let plistExists = plistPath != "missing" && FileManager.default.fileExists(atPath: plistPath)
        let plistDict = NSDictionary(contentsOfFile: plistPath) as? [String: Any]
        let googleAppId = plistDict?["GOOGLE_APP_ID"] as? String
        let googleAppIdHasPlaceholder = googleAppId?.contains("YOUR_") ?? true
        let googleAppIdLooksValid = googleAppId?.range(
            of: #"^\d+:[^:]+:ios:[A-Za-z0-9]+$"#,
            options: .regularExpression
        ) != nil
        let bundleId = Bundle.main.bundleIdentifier ?? "missing"
        let plistBundleId = plistDict?["BUNDLE_ID"] as? String ?? "missing"

        // #region agent log
        Self.agentDebugLog(
            runId: runId,
            hypothesisId: "H1",
            location: "MainView/VaultTrackerApp.swift:init:precheck",
            message: "Firebase configure precheck context",
            data: [
                "isRunningTests": String(isRunningTests),
                "bundleId": bundleId,
                "plistBundleId": plistBundleId
            ]
        )
        fputs("AGENTDBG H1 runId=\(runId) isRunningTests=\(isRunningTests) bundleId=\(bundleId) plistBundleId=\(plistBundleId)\n", stderr)
        // #endregion

        // #region agent log
        Self.agentDebugLog(
            runId: runId,
            hypothesisId: "H2",
            location: "MainView/VaultTrackerApp.swift:init:plist",
            message: "GoogleService-Info.plist lookup",
            data: [
                "plistPath": plistPath,
                "plistExists": String(plistExists),
                "hasDict": String(plistDict != nil)
            ]
        )
        fputs("AGENTDBG H2 runId=\(runId) plistPath=\(plistPath) plistExists=\(plistExists) hasDict=\(plistDict != nil)\n", stderr)
        // #endregion

        // #region agent log
        Self.agentDebugLog(
            runId: runId,
            hypothesisId: "H3",
            location: "MainView/VaultTrackerApp.swift:init:googleAppId",
            message: "GOOGLE_APP_ID format check",
            data: [
                "hasGoogleAppId": String(googleAppId != nil),
                "googleAppIdHasPlaceholder": String(googleAppIdHasPlaceholder),
                "googleAppIdLooksValid": String(googleAppIdLooksValid)
            ]
        )
        fputs("AGENTDBG H3 runId=\(runId) hasGoogleAppId=\(googleAppId != nil) hasPlaceholder=\(googleAppIdHasPlaceholder) looksValid=\(googleAppIdLooksValid)\n", stderr)
        // #endregion

        // #region agent log
        Self.agentDebugLog(
            runId: runId,
            hypothesisId: "H4",
            location: "MainView/VaultTrackerApp.swift:init:beforeConfigure",
            message: "About to call FirebaseApp.configure",
            data: ["willConfigure": "true"]
        )
        fputs("AGENTDBG H4 runId=\(runId) about_to_configure=true\n", stderr)
        // #endregion
        let shouldConfigureFirebase = !isRunningTests
        // #region agent log
        Self.agentDebugLog(
            runId: runId,
            hypothesisId: "H5",
            location: "MainView/VaultTrackerApp.swift:init:configureDecision",
            message: "Firebase configure decision",
            data: ["shouldConfigureFirebase": String(shouldConfigureFirebase)]
        )
        fputs("AGENTDBG H5 runId=\(runId) shouldConfigureFirebase=\(shouldConfigureFirebase)\n", stderr)
        // #endregion
        if shouldConfigureFirebase {
            FirebaseApp.configure()
        }
        if shouldConfigureFirebase {
#if DEBUG
            // Avoid non-fatal noise and uploads during local development; OSLog still captures `VTLogLive` output.
            Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
#else
            Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
#endif
        }
        Self.configureLedgerChrome()
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                switch authManager.authenticationState {
                case .authenticating:
                    LoadingView()
                case .authenticated:
                    mainView
                case .unauthenticated:
                    LoginView()
                        .environmentObject(authManager)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
    
    private var mainView: some View {
        TabView {
            NavigationView {
                HomeViewWrapper()
            }
            .tabItem {
                Image(systemName: "house")
                Text("Home")
            }

            NavigationView {
                AnalyticsView()
            }
            .tabItem {
                Image(systemName: "chart.pie.fill")
                Text("Analytics")
            }

            NavigationView {
                ProfileView()
            }
            .tabItem {
                Image(systemName: "person.crop.circle")
                Text("Profile")
            }
        }
        .tint(VTColors.primary)
        .environmentObject(authManager)
    }

    private static func configureLedgerChrome() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(VTColors.background)
        let titleColor = UIColor(VTColors.textPrimary)
        navAppearance.titleTextAttributes = [.foregroundColor: titleColor]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: titleColor]

        let navBar = UINavigationBar.appearance()
        navBar.standardAppearance = navAppearance
        navBar.scrollEdgeAppearance = navAppearance
        navBar.compactAppearance = navAppearance
        navBar.tintColor = UIColor(VTColors.primary)

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(VTColors.surfaceLow)

        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = tabAppearance
        tabBar.scrollEdgeAppearance = tabAppearance
        tabBar.unselectedItemTintColor = UIColor(VTColors.textSubdued)
        tabBar.tintColor = UIColor(VTColors.primary)
    }

    private static func agentDebugLog(
        runId: String,
        hypothesisId: String,
        location: String,
        message: String,
        data: [String: String]
    ) {
        let payload: [String: Any] = [
            "sessionId": "16bac3",
            "runId": runId,
            "hypothesisId": hypothesisId,
            "location": location,
            "message": message,
            "data": data,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]

        guard
            let encoded = try? JSONSerialization.data(withJSONObject: payload),
            let url = URL(string: "http://127.0.0.1:7369/ingest/f54b201f-c674-49be-bfcf-b2e5ccde3521")
        else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("16bac3", forHTTPHeaderField: "X-Debug-Session-Id")
        request.httpBody = encoded

        let semaphore = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { _, _, _ in
            semaphore.signal()
        }.resume()
        _ = semaphore.wait(timeout: .now() + 1)
    }
}

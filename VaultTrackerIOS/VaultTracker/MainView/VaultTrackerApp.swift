//
//  VaultTrackerApp.swift
//  VaultTracker
//
//  Created by Caleb Ngai on 6/25/25.
//

import SwiftUI
import UIKit
import Firebase
import FirebaseCrashlytics

@main
struct VaultTrackerApp: App {
    @StateObject var authManager = AuthManager()
    
    init() {
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let shouldConfigureFirebase = !isRunningTests
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
}

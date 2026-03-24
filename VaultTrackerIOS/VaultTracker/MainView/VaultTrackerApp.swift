//
//  VaultTrackerApp.swift
//  VaultTracker
//
//  Created by Caleb Ngai on 6/25/25.
//

import SwiftUI
import Firebase

@main
struct VaultTrackerApp: App {
    @StateObject var authManager = AuthManager()
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
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
        .environmentObject(authManager)
    }
}

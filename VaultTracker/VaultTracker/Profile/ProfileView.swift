//
//  ProfileView.swift
//  VaultTracker
//
//  Created by Caleb Ngai on 7/17/25.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        VStack {
            Spacer()
            Text("Welcome, \(authManager.user?.displayName ?? "User")!")
                .font(.title)
                .padding()
            
            Button(action: {
                do {
                    try authManager.signOut()
                } catch {
                    print("Error signing out: \(error.localizedDescription)")
                }
            }) {
                Text("Sign Out")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
            
            Spacer()
        }
        .navigationTitle("Profile")
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager())
}

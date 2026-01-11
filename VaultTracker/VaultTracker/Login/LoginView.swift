//
//  LoginView.swift
//  VaultTracker
//
//  Created by Caleb Ngai on 7/17/25.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        VStack {
            Spacer()
            Text("VaultTracker")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 50)
                .foregroundColor(.white) // Ensure text is visible on dark background
            
            // Google Sign-In Button
            Button(action: {
                Task {
                    do {
                        try await authManager.signInWithGoogle()
                    } catch {
                        print("Error signing in with Google: \(error.localizedDescription)")
                    }
                }
            }) {
                HStack {
                    Image(systemName: "g.circle.fill")
                        .resizable()
                        .frame(width: 24, height: 24)
                    Text("Sign in with Google")
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.white) // Changed to white for contrast
                .foregroundColor(.black) // Changed to black for contrast
                .cornerRadius(10)
            }
            .padding(.horizontal)
            
            // Apple Sign-In Button (Placeholder)
            Button(action: {
                Task {
                    do {
                        try await authManager.signInWithApple()
                    } catch {
                        print("Error signing in with Apple: \(error.localizedDescription)")
                    }
                }
            }) {
                HStack {
                    Image(systemName: "applelogo")
                        .resizable()
                        .frame(width: 24, height: 24)
                    Text("Sign in with Apple")
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.white) // Changed to white for contrast
                .foregroundColor(.black) // Changed to black for contrast
                .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
            Spacer()
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 1.0, green: 0.5, blue: 0.0), Color(red: 0.4, green: 0.2, blue: 0.0)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}

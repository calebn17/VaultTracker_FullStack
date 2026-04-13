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
                .foregroundStyle(VTColors.textPrimary)

            // Google Sign-In Button
            Button(action: {
                Task {
                    do {
                        try await authManager.signInWithGoogle()
                    } catch {
                        // AuthManager already logs sign-in failures
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
                .background(Color.white)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal)
            .accessibilityIdentifier("googleSignInButton")

            Spacer()

#if DEBUG
            Button(action: {
                authManager.signInDebug()
            }) {
                HStack {
                    Image(systemName: "ladybug.fill")
                    Text("Debug Login")
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(VTColors.surfaceHigh)
                .foregroundStyle(VTColors.primary)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
            .accessibilityIdentifier("debugLoginButton")
#endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VTColors.background.ignoresSafeArea())
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}

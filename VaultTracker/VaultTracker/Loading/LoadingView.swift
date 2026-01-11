import SwiftUI

struct LoadingView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("VaultTracker")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 50)
                .foregroundColor(.white)
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    LoadingView()
}
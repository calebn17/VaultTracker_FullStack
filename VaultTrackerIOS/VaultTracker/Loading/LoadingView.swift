import SwiftUI

struct LoadingView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("VaultTracker")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 50)
                .foregroundStyle(VTColors.textPrimary)
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: VTColors.primary))
                .scaleEffect(1.5)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("loadingView")
        .background(VTColors.background.ignoresSafeArea())
    }
}

#Preview {
    LoadingView()
}

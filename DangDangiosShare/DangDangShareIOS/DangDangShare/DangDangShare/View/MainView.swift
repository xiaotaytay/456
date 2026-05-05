import SwiftUI

struct MainView: View {
    @StateObject private var appState = AppState.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            RadarControlView()

            if appState.showToast {
                VStack {
                    Spacer()
                    Text(appState.toastMessage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(20)
                        .padding(.bottom, 80)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: appState.showToast)
            }
        }
        .preferredColorScheme(.dark)
    }
}

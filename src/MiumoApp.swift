import SwiftUI
import FirebaseCore

@main
struct MiumoApp: App {
    @StateObject private var firebase = FirebaseManager.shared
    @State private var isShowingSplash: Bool = true

    init() {
        FirebaseManager.shared.configureIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .top) {
                if isShowingSplash {
                    SplashView {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            isShowingSplash = false
                        }
                    }
                } else if firebase.isAuthenticated {
                    MainTabView()
                        .environmentObject(firebase)
                } else {
                    AuthFlowView()
                        .environmentObject(firebase)
                }

                // Global Non-Intrusive Toast Banner
                if let toast = firebase.toastMessage {
                    Text(toast)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(MiumoTheme.surfaceElevated)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(MiumoTheme.strokeSubtle, lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 6)
                        .padding(.top, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}

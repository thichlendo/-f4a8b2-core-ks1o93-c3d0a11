import SwiftUI

// MARK: - Native iOS Splash Screen (Port of SplashActivity.kt)
struct SplashView: View {
    let onFinished: () -> Void

    @State private var logoScale: CGFloat = 0.65
    @State private var logoOpacity: Double = 0.0
    @State private var pawRotation: Double = -12.0
    @State private var titleOffset: CGFloat = 22.0
    @State private var titleOpacity: Double = 0.0

    var body: some View {
        ZStack {
            MiumoTheme.canvas.ignoresSafeArea()

            // Ambient radial glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            MiumoTheme.accentPrimary.opacity(0.26),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 210
                    )
                )
                .frame(width: 420, height: 420)
                .blur(radius: 20)

            VStack(spacing: 24) {
                ZStack {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(MiumoTheme.primaryGradient)
                        .frame(width: 112, height: 112)
                        .shadow(color: MiumoTheme.accentPrimary.opacity(0.45), radius: 28, x: 0, y: 14)

                    // Cat silhouette & waving paw
                    ZStack {
                        Image(systemName: "cat.fill")
                            .font(.system(size: 50, weight: .bold))
                            .foregroundColor(.white)

                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding(7)
                            .background(MiumoTheme.heartRed)
                            .clipShape(Circle())
                            .rotationEffect(.degrees(pawRotation), anchor: .bottomLeading)
                            .offset(x: 34, y: -26)
                    }
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                VStack(spacing: 6) {
                    Text(AppConstants.appName)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(MiumoTheme.textPrimary)

                    Text("Kết nối khoảnh khắc tự nhiên")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(MiumoTheme.textSecondary)
                }
                .offset(y: titleOffset)
                .opacity(titleOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.65)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }

            withAnimation(.easeOut(duration: 0.5).delay(0.18)) {
                titleOffset = 0
                titleOpacity = 1.0
            }

            withAnimation(.easeInOut(duration: 0.42).repeatForever(autoreverses: true).delay(0.45)) {
                pawRotation = 22.0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                onFinished()
            }
        }
    }
}

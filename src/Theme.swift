import SwiftUI
import UIKit

// MARK: - MiuMo Native iOS HIG Design System (Liquid Obsidian & Indigo Glass)
enum MiumoTheme {
    // Canvas & Elevated Glass Surfaces
    static let canvas = Color(red: 0.043, green: 0.047, blue: 0.063)          // #0B0C10
    static let surfacePrimary = Color(red: 0.082, green: 0.090, blue: 0.118)  // #15171E
    static let surfaceElevated = Color(red: 0.118, green: 0.129, blue: 0.169) // #1E212B
    static let surfaceGlass = Color.white.opacity(0.06)

    // Borders & Hairlines
    static let separator = Color.white.opacity(0.09)
    static let strokeSubtle = Color.white.opacity(0.14)

    // Typography Colors
    static let textPrimary = Color(red: 0.961, green: 0.969, blue: 0.980)     // #F5F7FA
    static let textSecondary = Color(red: 0.580, green: 0.612, blue: 0.675)   // #949CAC
    static let textMuted = Color(red: 0.400, green: 0.431, blue: 0.494)       // #666E7E

    // Brand & Semantic Accents (Redesigned Native iOS Indigo-Coral Palette)
    static let accentPrimary = Color(red: 0.388, green: 0.400, blue: 0.945)   // #6366F1 Indigo
    static let accentSecondary = Color(red: 0.545, green: 0.361, blue: 0.965) // #8B5CF6 Violet
    static let heartRed = Color(red: 1.000, green: 0.216, blue: 0.373)        // #FF375F iOS Pink/Red
    static let repostGreen = Color(red: 0.188, green: 0.820, blue: 0.345)     // #30D158 iOS Green
    static let verifiedBlue = Color(red: 0.039, green: 0.518, blue: 1.000)    // #0A84FF iOS Blue
    static let warningAmber = Color(red: 1.000, green: 0.624, blue: 0.039)    // #FF9F0A

    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [accentPrimary, accentSecondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Relative Time Formatter
enum TimeFormatterHelper {
    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "dd/MM/yy"
        return df
    }()

    private static let clockFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df
    }()

    static func relativeTime(from timestampMillis: Int64) -> String {
        guard timestampMillis > 0 else { return "bây giờ" }
        let nowMillis = Int64(Date().timeIntervalSince1970 * 1000)
        let diffMillis = max(0, nowMillis - timestampMillis)
        let minutes = diffMillis / 60_000
        let hours = minutes / 60
        let days = hours / 24

        if minutes < 1 {
            return "bây giờ"
        } else if minutes < 60 {
            return "\(minutes) phút"
        } else if hours < 24 {
            return "\(hours) giờ"
        } else if days < 7 {
            return "\(days) ngày"
        } else {
            let date = Date(timeIntervalSince1970: TimeInterval(timestampMillis) / 1000.0)
            return dateFormatter.string(from: date)
        }
    }

    static func shortRelativeTime(from timestampMillis: Int64) -> String {
        guard timestampMillis > 0 else { return "bây giờ" }
        let nowMillis = Int64(Date().timeIntervalSince1970 * 1000)
        let diffMillis = max(0, nowMillis - timestampMillis)
        let minutes = diffMillis / 60_000
        let hours = minutes / 60
        let days = hours / 24

        if minutes < 1 {
            return "bây giờ"
        } else if minutes < 60 {
            return "\(minutes)p"
        } else if hours < 24 {
            return "\(hours)g"
        } else {
            return "\(days)ng"
        }
    }

    static func clockTime(from timestampMillis: Int64) -> String {
        guard timestampMillis > 0 else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(timestampMillis) / 1000.0)
        return clockFormatter.string(from: date)
    }
}

// MARK: - Memory Cached Avatar Image Loader & SwiftUI View
final class AvatarImageCache {
    static let shared = AvatarImageCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 48
    }

    func image(for url: String) -> UIImage? {
        cache.object(forKey: url as NSString)
    }

    func insert(_ image: UIImage, for url: String) {
        cache.setObject(image, forKey: url as NSString)
    }
}

struct MiumoAvatarView: View {
    let url: String
    let fallbackInitial: String
    var size: CGFloat = 44
    var showOnlineRing: Bool = false

    @State private var loadedImage: UIImage?

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            MiumoTheme.accentPrimary.opacity(0.28),
                            MiumoTheme.accentSecondary.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Text(fallbackInitial.isEmpty ? "M" : String(fallbackInitial.prefix(1)).uppercased())
                    .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                    .foregroundColor(MiumoTheme.textPrimary)
            }
        }
        .frame(width: size, height: size)
        .overlay(
            Circle()
                .stroke(
                    showOnlineRing ? MiumoTheme.accentPrimary : MiumoTheme.strokeSubtle,
                    lineWidth: showOnlineRing ? 2.0 : 1.0
                )
        )
        .onAppear(perform: loadAvatar)
        .onChange(of: url) { _ in
            loadAvatar()
        }
    }

    private func loadAvatar() {
        let cleanUrl = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUrl.isEmpty, let parsedURL = URL(string: cleanUrl) else {
            loadedImage = nil
            return
        }

        if let cached = AvatarImageCache.shared.image(for: cleanUrl) {
            loadedImage = cached
            return
        }

        var request = URLRequest(url: parsedURL)
        request.timeoutInterval = 8.0

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data, let uiImage = UIImage(data: data) else { return }
            AvatarImageCache.shared.insert(uiImage, for: cleanUrl)
            DispatchQueue.main.async {
                self.loadedImage = uiImage
            }
        }.resume()
    }
}

// MARK: - Verified Badge View
struct VerifiedBadgeView: View {
    var size: CGFloat = 15

    var body: some View {
        Image(systemName: "checkmark.seal.fill")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundColor(MiumoTheme.verifiedBlue)
    }
}

// MARK: - Interactive Cat Mascot Password Header (Reimagined for iOS)
struct PasswordMascotView: View {
    let isPasswordVisible: Bool
    @State private var bounceScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Circle()
                .fill(MiumoTheme.surfaceElevated)
                .frame(width: 68, height: 68)
                .overlay(
                    Circle()
                        .stroke(MiumoTheme.strokeSubtle, lineWidth: 1)
                )

            VStack(spacing: 4) {
                HStack(spacing: 16) {
                    // Left Ear
                    TriangleEar()
                        .fill(MiumoTheme.accentPrimary)
                        .frame(width: 14, height: 12)
                        .rotationEffect(.degrees(-12))
                    // Right Ear
                    TriangleEar()
                        .fill(MiumoTheme.accentSecondary)
                        .frame(width: 14, height: 12)
                        .rotationEffect(.degrees(12))
                }
                .offset(y: 4)

                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(MiumoTheme.textPrimary)
                        .frame(width: 42, height: 32)

                    if isPasswordVisible {
                        // Eyes open peeking
                        HStack(spacing: 10) {
                            Circle()
                                .fill(MiumoTheme.canvas)
                                .frame(width: 7, height: 7)
                                .overlay(
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 2.5, height: 2.5)
                                        .offset(x: -1, y: -1)
                                )
                            Circle()
                                .fill(MiumoTheme.canvas)
                                .frame(width: 7, height: 7)
                                .overlay(
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 2.5, height: 2.5)
                                        .offset(x: -1, y: -1)
                                )
                        }
                        .offset(y: -2)
                    } else {
                        // Paws covering eyes when typing secret password
                        HStack(spacing: 8) {
                            Capsule()
                                .fill(MiumoTheme.accentPrimary)
                                .frame(width: 12, height: 8)
                                .rotationEffect(.degrees(-15))
                            Capsule()
                                .fill(MiumoTheme.accentPrimary)
                                .frame(width: 12, height: 8)
                                .rotationEffect(.degrees(15))
                        }
                        .offset(y: -2)
                    }

                    // Cute cat nose
                    Circle()
                        .fill(MiumoTheme.heartRed)
                        .frame(width: 4, height: 4)
                        .offset(y: 5)
                }
            }
        }
        .scaleEffect(bounceScale)
        .onChange(of: isPasswordVisible) { _ in
            withAnimation(.spring(response: 0.26, dampingFraction: 0.55)) {
                bounceScale = 1.14
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.26, dampingFraction: 0.65)) {
                    bounceScale = 1.0
                }
            }
        }
    }
}

struct TriangleEar: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Interactive Circle Crop View (SwiftUI Port of CircleCropView.kt)
struct CircleCropAvatarView: View {
    let sourceImage: UIImage
    let onCancel: () -> Void
    let onSaveCropped: (UIImage) -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let cropDiameter: CGFloat = 280

    var body: some View {
        ZStack {
            MiumoTheme.canvas.ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(MiumoTheme.textPrimary)
                            .frame(width: 40, height: 40)
                            .background(MiumoTheme.surfaceElevated)
                            .clipShape(Circle())
                    }

                    Spacer()

                    Text("Căn chỉnh ảnh đại diện")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(MiumoTheme.textPrimary)

                    Spacer()

                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()

                ZStack {
                    Image(uiImage: sourceImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cropDiameter, height: cropDiameter)
                        .scaleEffect(scale)
                        .offset(offset)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2.5)
                        )
                        .shadow(color: Color.black.opacity(0.45), radius: 24, x: 0, y: 12)
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        lastScale = value
                                        scale = min(max(scale * delta, 1.0), 5.0)
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                        if scale > 4.0 {
                                            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                                scale = 4.0
                                            }
                                        }
                                    },
                                DragGesture()
                                    .onChanged { value in
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                        )
                }
                .frame(width: cropDiameter + 40, height: cropDiameter + 40)

                Text("Chụm hai ngón tay để phóng to hoặc kéo để di chuyển")
                    .font(.system(size: 13))
                    .foregroundColor(MiumoTheme.textSecondary)

                Spacer()

                Button {
                    let rendered = exportCroppedImage(outputSize: 512)
                    onSaveCropped(rendered)
                } label: {
                    Text("Lưu ảnh đại diện")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(MiumoTheme.primaryGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
    }

    private func exportCroppedImage(outputSize: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outputSize, height: outputSize))
        return renderer.image { context in
            let rect = CGRect(x: 0, y: 0, width: outputSize, height: outputSize)
            UIBezierPath(ovalIn: rect).addClip()

            let ratio = outputSize / cropDiameter
            let imgSize = sourceImage.size
            let aspect = max(cropDiameter / imgSize.width, cropDiameter / imgSize.height)
            let drawWidth = imgSize.width * aspect * scale * ratio
            let drawHeight = imgSize.height * aspect * scale * ratio

            let drawX = (outputSize - drawWidth) / 2.0 + (offset.width * ratio)
            let drawY = (outputSize - drawHeight) / 2.0 + (offset.height * ratio)

            sourceImage.draw(in: CGRect(x: drawX, y: drawY, width: drawWidth, height: drawHeight))
        }
    }
}

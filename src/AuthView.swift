import SwiftUI
import UIKit
import PhotosUI
import FirebaseAuth
import FirebaseDatabase

// MARK: - Root Authentication Container (Login, Register, Username Setup, Avatar Setup, Forgot/Reset Password)
enum AuthStep: Equatable {
    case login
    case register
    case usernameSetup
    case avatarSetup
    case forgotPassword
    case resetNewPassword
}

struct AuthFlowView: View {
    @EnvironmentObject var firebase: FirebaseManager
    @StateObject private var regState = RegistrationState()
    @State private var step: AuthStep = .login

    var body: some View {
        ZStack {
            MiumoTheme.canvas.ignoresSafeArea()

            switch step {
            case .login:
                LoginScreen(
                    onSwitchToRegister: {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.85)) {
                            step = .register
                        }
                    },
                    onForgotPassword: {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.85)) {
                            step = .forgotPassword
                        }
                    }
                )
                .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))

            case .register:
                RegisterScreen(
                    regState: regState,
                    onSwitchToLogin: {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.85)) {
                            step = .login
                        }
                    },
                    onContinueToUsername: {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.85)) {
                            step = .usernameSetup
                        }
                    }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            case .usernameSetup:
                UsernameSetupScreen(
                    regState: regState,
                    onBack: {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.85)) {
                            step = .register
                        }
                    },
                    onNextToAvatar: {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.85)) {
                            step = .avatarSetup
                        }
                    }
                )
                .transition(.move(edge: .trailing))

            case .avatarSetup:
                AvatarSetupScreen(
                    regState: regState,
                    onRestartRegister: {
                        withAnimation {
                            step = .register
                        }
                    }
                )
                .transition(.move(edge: .trailing))

            case .forgotPassword:
                ForgotPasswordScreen(
                    onBack: {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.85)) {
                            step = .login
                        }
                    },
                    onPhoneVerified: {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.85)) {
                            step = .resetNewPassword
                        }
                    }
                )
                .transition(.move(edge: .trailing))

            case .resetNewPassword:
                ResetNewPasswordScreen(
                    onComplete: {
                        firebase.isAuthenticated = true
                    }
                )
                .transition(.move(edge: .trailing))
            }
        }
    }
}

// MARK: - 1. Login Screen (Port of LoginActivity.kt)
struct LoginScreen: View {
    @EnvironmentObject var firebase: FirebaseManager
    let onSwitchToRegister: () -> Void
    let onForgotPassword: () -> Void

    @State private var identifier: String = ""
    @State private var password: String = ""
    @State private var isPasswordVisible: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Brand & Mascot Header
                VStack(spacing: 14) {
                    PasswordMascotView(isPasswordVisible: isPasswordVisible)

                    Text("Chào mừng trở lại \(AppConstants.appName)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(MiumoTheme.textPrimary)

                    Text("Đăng nhập bằng email hoặc @username của bạn")
                        .font(.system(size: 14))
                        .foregroundColor(MiumoTheme.textSecondary)
                }
                .padding(.top, 28)

                // Segmented Auth Switcher
                HStack(spacing: 0) {
                    Text("Đăng nhập")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(MiumoTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(MiumoTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Button(action: onSwitchToRegister) {
                        Text("Đăng ký")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(MiumoTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                    }
                }
                .padding(4)
                .background(MiumoTheme.surfacePrimary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // Input Card
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "at")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(MiumoTheme.textSecondary)
                            .frame(width: 24)

                        TextField("Email hoặc tên người dùng", text: $identifier)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .foregroundColor(MiumoTheme.textPrimary)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(MiumoTheme.surfacePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(MiumoTheme.strokeSubtle, lineWidth: 1)
                    )

                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(MiumoTheme.textSecondary)
                            .frame(width: 24)

                        Group {
                            if isPasswordVisible {
                                TextField("Mật khẩu", text: $password)
                            } else {
                                SecureField("Mật khẩu", text: $password)
                            }
                        }
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .foregroundColor(MiumoTheme.textPrimary)

                        Button {
                            isPasswordVisible.toggle()
                        } label: {
                            Image(systemName: isPasswordVisible ? "eye.fill" : "eye.slash.fill")
                                .font(.system(size: 16))
                                .foregroundColor(MiumoTheme.textSecondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(MiumoTheme.surfacePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(MiumoTheme.strokeSubtle, lineWidth: 1)
                    )

                    HStack {
                        Spacer()
                        Button("Quên mật khẩu?", action: onForgotPassword)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(MiumoTheme.accentPrimary)
                    }
                }

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(MiumoTheme.heartRed)
                        .multilineTextAlignment(.center)
                }

                Button(action: attemptLogin) {
                    ZStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Đăng nhập")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(MiumoTheme.primaryGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(isLoading)

                // Social Sign-in Row
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        Rectangle().fill(MiumoTheme.separator).frame(height: 1)
                        Text("Hoặc tiếp tục với")
                            .font(.system(size: 12))
                            .foregroundColor(MiumoTheme.textMuted)
                        Rectangle().fill(MiumoTheme.separator).frame(height: 1)
                    }

                    HStack(spacing: 12) {
                        Button {
                            firebase.showToast("Tính năng đăng nhập Google sắp ra mắt")
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "globe")
                                Text("Google")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(MiumoTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(MiumoTheme.surfacePrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(MiumoTheme.strokeSubtle, lineWidth: 1)
                            )
                        }

                        Button {
                            firebase.showToast("Tính năng đăng nhập Facebook sắp ra mắt")
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "person.2.fill")
                                Text("Facebook")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(MiumoTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(MiumoTheme.surfacePrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(MiumoTheme.strokeSubtle, lineWidth: 1)
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
    }

    private func attemptLogin() {
        errorMessage = nil
        let cleanId = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPass = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanId.isEmpty else {
            errorMessage = "Vui lòng nhập email hoặc tên người dùng"
            return
        }
        guard !cleanPass.isEmpty else {
            errorMessage = "Vui lòng nhập mật khẩu"
            return
        }

        isLoading = true
        firebase.signIn(identifier: cleanId, password: cleanPass) { result in
            isLoading = false
            if case .failure(let err) = result {
                errorMessage = "Đăng nhập thất bại: \(err.localizedDescription)"
            }
        }
    }
}

// MARK: - 2. Register Screen (Port of RegisterActivity.kt)
struct RegisterScreen: View {
    @EnvironmentObject var firebase: FirebaseManager
    @ObservedObject var regState: RegistrationState
    let onSwitchToLogin: () -> Void
    let onContinueToUsername: () -> Void

    @State private var selectedCountry: Country = PhoneInputHelper.countries[0]
    @State private var showCountryPicker: Bool = false
    @State private var rawPhone: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isPasswordVisible: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                VStack(spacing: 14) {
                    PasswordMascotView(isPasswordVisible: isPasswordVisible)

                    Text("Tạo tài khoản mới")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(MiumoTheme.textPrimary)

                    Text("Bắt đầu hành trình kết nối trên \(AppConstants.appName)")
                        .font(.system(size: 14))
                        .foregroundColor(MiumoTheme.textSecondary)
                }
                .padding(.top, 28)

                // Segmented Auth Switcher
                HStack(spacing: 0) {
                    Button(action: onSwitchToLogin) {
                        Text("Đăng nhập")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(MiumoTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                    }

                    Text("Đăng ký")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(MiumoTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(MiumoTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .padding(4)
                .background(MiumoTheme.surfacePrimary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(spacing: 14) {
                    // Phone Input with Country Code Picker
                    HStack(spacing: 10) {
                        Button {
                            showCountryPicker = true
                        } label: {
                            HStack(spacing: 6) {
                                Text(selectedCountry.flag)
                                Text(selectedCountry.dialCode)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(MiumoTheme.textPrimary)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(MiumoTheme.textSecondary)
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 52)
                            .background(MiumoTheme.surfacePrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(MiumoTheme.strokeSubtle, lineWidth: 1)
                            )
                        }

                        TextField("Số điện thoại", text: $rawPhone)
                            .keyboardType(.phonePad)
                            .foregroundColor(MiumoTheme.textPrimary)
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .background(MiumoTheme.surfacePrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(MiumoTheme.strokeSubtle, lineWidth: 1)
                            )
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 15))
                            .foregroundColor(MiumoTheme.textSecondary)
                            .frame(width: 24)

                        TextField("Địa chỉ Email", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .foregroundColor(MiumoTheme.textPrimary)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(MiumoTheme.surfacePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(MiumoTheme.strokeSubtle, lineWidth: 1)
                    )

                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 15))
                            .foregroundColor(MiumoTheme.textSecondary)
                            .frame(width: 24)

                        Group {
                            if isPasswordVisible {
                                TextField("Mật khẩu (tối thiểu 8 ký tự)", text: $password)
                            } else {
                                SecureField("Mật khẩu (tối thiểu 8 ký tự)", text: $password)
                            }
                        }
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .foregroundColor(MiumoTheme.textPrimary)

                        Button {
                            isPasswordVisible.toggle()
                        } label: {
                            Image(systemName: isPasswordVisible ? "eye.fill" : "eye.slash.fill")
                                .font(.system(size: 16))
                                .foregroundColor(MiumoTheme.textSecondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(MiumoTheme.surfacePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(MiumoTheme.strokeSubtle, lineWidth: 1)
                    )
                }

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(MiumoTheme.heartRed)
                }

                Button(action: proceedToUsername) {
                    Text("Tiếp tục")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(MiumoTheme.primaryGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                // Social Sign-up Row
                HStack(spacing: 10) {
                    ForEach(["Google", "Facebook", "X"], id: \.self) { provider in
                        Button {
                            firebase.showToast("Tính năng đăng ký \(provider) sắp ra mắt")
                        } label: {
                            Text(provider)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(MiumoTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(MiumoTheme.surfacePrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(MiumoTheme.strokeSubtle, lineWidth: 1)
                                )
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
        .confirmationDialog("Chọn quốc gia", isPresented: $showCountryPicker, titleVisibility: .visible) {
            ForEach(PhoneInputHelper.countries) { country in
                Button("\(country.flag) \(country.name) (\(country.dialCode))") {
                    selectedCountry = country
                }
            }
            Button("Đóng", role: .cancel) {}
        }
    }

    private func proceedToUsername() {
        errorMessage = nil
        guard PhoneInputHelper.isValidVietnamNumber(rawPhone) else {
            errorMessage = "Số điện thoại không hợp lệ"
            return
        }
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanEmail.contains("@") && cleanEmail.contains(".") else {
            errorMessage = "Email không hợp lệ"
            return
        }
        guard password.count >= 8 else {
            errorMessage = "Mật khẩu tối thiểu 8 ký tự"
            return
        }

        regState.phone = PhoneInputHelper.toE164(dialCode: selectedCountry.dialCode, rawNumber: rawPhone)
        regState.email = cleanEmail
        regState.password = password
        regState.isSocialSignup = false
        onContinueToUsername()
    }
}

// MARK: - 3. Username Setup Screen (Port of UsernameSetupActivity.kt)
struct UsernameSetupScreen: View {
    @EnvironmentObject var firebase: FirebaseManager
    @ObservedObject var regState: RegistrationState
    let onBack: () -> Void
    let onNextToAvatar: () -> Void

    @State private var usernameInput: String = ""
    @State private var isChecking: Bool = false
    @State private var isAvailable: Bool = false
    @State private var statusMessage: String = ""
    @State private var isStatusPositive: Bool = false
    @State private var suggestions: [String] = []

    private let usernamePattern = "^[a-z0-9._]{3,24}$"

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(MiumoTheme.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(MiumoTheme.surfacePrimary)
                        .clipShape(Circle())
                }
                Spacer()
                Text("Bước 2 / 3")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(MiumoTheme.textSecondary)
            }
            .padding(.top, 14)

            VStack(alignment: .leading, spacing: 8) {
                Text("Chọn định danh @username")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(MiumoTheme.textPrimary)

                Text("Tên định danh là duy nhất để bạn bè dễ dàng tìm thấy bạn trên \(AppConstants.appName).")
                    .font(.system(size: 14))
                    .foregroundColor(MiumoTheme.textSecondary)
            }

            HStack(spacing: 10) {
                Text("@")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(MiumoTheme.accentPrimary)

                TextField("ten_nguoi_dung", text: $usernameInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .foregroundColor(MiumoTheme.textPrimary)
                    .onChange(of: usernameInput) { newValue in
                        validateAndCheck(newValue)
                    }

                if isChecking {
                    ProgressView()
                        .scaleEffect(0.85)
                } else if !statusMessage.isEmpty {
                    Text(isStatusPositive ? "✓" : "✕")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isStatusPositive ? MiumoTheme.repostGreen : MiumoTheme.heartRed)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(MiumoTheme.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(MiumoTheme.strokeSubtle, lineWidth: 1)
            )

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isStatusPositive ? MiumoTheme.repostGreen : MiumoTheme.heartRed)
            }

            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Gợi ý có sẵn:")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(MiumoTheme.textSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(suggestions, id: \.self) { candidate in
                                Button {
                                    usernameInput = candidate
                                } label: {
                                    Text("@\(candidate)")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(MiumoTheme.textPrimary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(MiumoTheme.surfaceElevated)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
            }

            Spacer()

            Button {
                guard isAvailable else { return }
                regState.username = usernameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                onNextToAvatar()
            } label: {
                Text("Tiếp tục")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        isAvailable
                            ? AnyView(MiumoTheme.primaryGradient)
                            : AnyView(MiumoTheme.surfaceElevated)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(!isAvailable)
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 24)
    }

    private func validateAndCheck(_ raw: String) {
        let lower = raw.lowercased()
        if lower != raw {
            usernameInput = lower
            return
        }

        isAvailable = false
        suggestions = []

        guard !lower.isEmpty else {
            isChecking = false
            statusMessage = ""
            return
        }

        let regex = try? NSRegularExpression(pattern: usernamePattern)
        let range = NSRange(location: 0, length: lower.utf16.count)
        if regex?.firstMatch(in: lower, options: [], range: range) == nil {
            isChecking = false
            isStatusPositive = false
            statusMessage = "Chỉ dùng chữ thường, số, dấu chấm hoặc gạch dưới (3-24 ký tự)"
            return
        }

        isChecking = true
        statusMessage = "Đang kiểm tra..."
        isStatusPositive = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            guard self.usernameInput == lower else { return }
            firebase.checkUsernameAvailability(lower) { free in
                self.isChecking = false
                if free {
                    self.isAvailable = true
                    self.isStatusPositive = true
                    self.statusMessage = "Bạn có thể dùng @\(lower)"
                } else {
                    self.isAvailable = false
                    self.isStatusPositive = false
                    self.statusMessage = "Tên @\(lower) đã có người sử dụng"
                    self.suggestions = [
                        "\(lower)_\(Int.random(in: 10...99))",
                        "\(lower).\(Int.random(in: 100...999))",
                        "miumo_\(lower)"
                    ]
                }
            }
        }
    }
}

// MARK: - 4. Avatar & DisplayName Setup Screen (Port of AvatarSetupActivity.kt)
struct AvatarSetupScreen: View {
    @EnvironmentObject var firebase: FirebaseManager
    @ObservedObject var regState: RegistrationState
    let onRestartRegister: () -> Void

    @State private var displayName: String = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isSubmitting: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                Button("Bỏ qua") {
                    selectedImage = nil
                    completeSignup()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(MiumoTheme.textSecondary)
            }
            .padding(.top, 16)

            VStack(spacing: 8) {
                Text("Hoàn thiện hồ sơ")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(MiumoTheme.textPrimary)

                Text("Thêm ảnh đại diện và tên hiển thị để mọi người nhận ra bạn.")
                    .font(.system(size: 14))
                    .foregroundColor(MiumoTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            PhotosPicker(selection: $selectedItem, matching: .images) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(MiumoTheme.primaryGradient.opacity(0.25))
                            .frame(width: 116, height: 116)

                        if let img = selectedImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 116, height: 116)
                                .clipShape(Circle())
                        } else {
                            Text(String((regState.username.first ?? "M")).uppercased())
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundColor(MiumoTheme.textPrimary)
                        }

                        Circle()
                            .stroke(MiumoTheme.accentPrimary, lineWidth: 2)
                            .frame(width: 116, height: 116)
                    }

                    Text("Chọn ảnh đại diện")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(MiumoTheme.accentPrimary)
                }
            }
            .onChange(of: selectedItem) { newItem in
                guard let newItem = newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let uiImg = UIImage(data: data) {
                        await MainActor.run {
                            selectedImage = uiImg
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Tên hiển thị")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(MiumoTheme.textSecondary)

                TextField("Tên hiển thị của bạn", text: $displayName)
                    .foregroundColor(MiumoTheme.textPrimary)
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(MiumoTheme.surfacePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(MiumoTheme.strokeSubtle, lineWidth: 1)
                    )
            }

            Spacer()

            Button(action: completeSignup) {
                ZStack {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text("Hoàn tất đăng ký")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(MiumoTheme.primaryGradient)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(isSubmitting)
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 24)
        .onAppear {
            if displayName.isEmpty {
                displayName = regState.username
            }
        }
    }

    private func completeSignup() {
        guard !regState.email.isEmpty, !regState.password.isEmpty, !regState.username.isEmpty else {
            firebase.showToast("Thiếu thông tin đăng ký, vui lòng thử lại")
            onRestartRegister()
            return
        }

        isSubmitting = true
        firebase.completeRegistration(
            state: regState,
            displayName: displayName,
            avatarImage: selectedImage
        ) { result in
            isSubmitting = false
            if case .failure(let err) = result {
                firebase.showToast("Đăng ký thất bại: \(err.localizedDescription)")
            }
        }
    }
}

// MARK: - 5. Forgot Password Screen (Port of ForgotPasswordActivity.kt)
struct ForgotPasswordScreen: View {
    @EnvironmentObject var firebase: FirebaseManager
    let onBack: () -> Void
    let onPhoneVerified: () -> Void

    @State private var mode: RecoveryMode = .email
    @State private var email: String = ""
    @State private var selectedCountry: Country = PhoneInputHelper.countries[0]
    @State private var rawPhone: String = ""
    @State private var verificationId: String?
    @State private var otpCode: String = ""
    @State private var sentInfoText: String = ""
    @State private var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(MiumoTheme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(MiumoTheme.surfacePrimary)
                    .clipShape(Circle())
            }
            .padding(.top, 14)

            Text("Khôi phục mật khẩu")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(MiumoTheme.textPrimary)

            Picker("Phương thức", selection: $mode) {
                ForEach(RecoveryMode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)

            if mode == .email {
                TextField("Nhập email đã đăng ký", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .foregroundColor(MiumoTheme.textPrimary)
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(MiumoTheme.surfacePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                HStack(spacing: 10) {
                    Text("\(selectedCountry.flag) \(selectedCountry.dialCode)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(MiumoTheme.textPrimary)
                        .padding(.horizontal, 14)
                        .frame(height: 52)
                        .background(MiumoTheme.surfacePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    TextField("Số điện thoại", text: $rawPhone)
                        .keyboardType(.phonePad)
                        .foregroundColor(MiumoTheme.textPrimary)
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(MiumoTheme.surfacePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }

            Button {
                if mode == .email {
                    sendEmailReset()
                } else {
                    sendPhoneOtp()
                }
            } label: {
                ZStack {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(mode == .email ? "Gửi liên kết đặt lại" : "Gửi mã xác minh OTP")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(MiumoTheme.primaryGradient)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(isLoading)

            if verificationId != nil && mode == .phone {
                VStack(alignment: .leading, spacing: 12) {
                    Text(sentInfoText)
                        .font(.system(size: 13))
                        .foregroundColor(MiumoTheme.textSecondary)

                    TextField("Nhập mã OTP gồm 6 chữ số", text: $otpCode)
                        .keyboardType(.numberPad)
                        .foregroundColor(MiumoTheme.textPrimary)
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(MiumoTheme.surfacePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Button(action: verifyOtp) {
                        Text("Xác nhận mã OTP")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(MiumoTheme.repostGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func sendEmailReset() {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanEmail.contains("@") else {
            firebase.showToast("Vui lòng nhập email hợp lệ")
            return
        }
        isLoading = true
        Auth.auth().sendPasswordReset(withEmail: cleanEmail) { error in
            isLoading = false
            if let error = error {
                firebase.showToast("Lỗi: \(error.localizedDescription)")
            } else {
                firebase.showToast("Đã gửi liên kết đặt lại mật khẩu tới \(cleanEmail)")
                onBack()
            }
        }
    }

    private func sendPhoneOtp() {
        guard PhoneInputHelper.isValidVietnamNumber(rawPhone) else {
            firebase.showToast("Số điện thoại không hợp lệ")
            return
        }
        let e164 = PhoneInputHelper.toE164(dialCode: selectedCountry.dialCode, rawNumber: rawPhone)
        isLoading = true
        PhoneAuthProvider.provider().verifyPhoneNumber(e164, uiDelegate: nil) { id, error in
            isLoading = false
            if let error = error {
                firebase.showToast("Gửi mã thất bại: \(error.localizedDescription)")
            } else if let id = id {
                verificationId = id
                sentInfoText = "Mã xác minh gồm 6 chữ số đã được gửi tới \(e164)"
            }
        }
    }

    private func verifyOtp() {
        guard let verId = verificationId, otpCode.count == 6 else {
            firebase.showToast("Nhập đủ 6 chữ số")
            return
        }
        isLoading = true
        let credential = PhoneAuthProvider.provider().credential(withVerificationID: verId, verificationCode: otpCode)
        Auth.auth().signIn(with: credential) { _, error in
            isLoading = false
            if let error = error {
                firebase.showToast("Mã xác minh không đúng: \(error.localizedDescription)")
            } else {
                onPhoneVerified()
            }
        }
    }
}

// MARK: - 6. Reset New Password Screen (Port of ResetNewPasswordActivity.kt)
struct ResetNewPasswordScreen: View {
    @EnvironmentObject var firebase: FirebaseManager
    let onComplete: () -> Void

    @State private var newPassword: String = ""
    @State private var isSaving: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Spacer()
                Button("Bỏ qua", action: onComplete)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(MiumoTheme.textSecondary)
            }
            .padding(.top, 16)

            Text("Đặt mật khẩu mới")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(MiumoTheme.textPrimary)

            SecureField("Mật khẩu mới (từ 8 ký tự trở lên)", text: $newPassword)
                .foregroundColor(MiumoTheme.textPrimary)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(MiumoTheme.surfacePrimary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button {
                guard newPassword.count >= 8 else {
                    firebase.showToast("Mật khẩu phải từ 8 ký tự trở lên")
                    return
                }
                guard let user = Auth.auth().currentUser else {
                    onComplete()
                    return
                }
                isSaving = true
                user.updatePassword(to: newPassword) { error in
                    isSaving = false
                    if let error = error {
                        firebase.showToast("Lỗi đổi mật khẩu: \(error.localizedDescription)")
                    } else {
                        firebase.showToast("Đã đổi mật khẩu thành công")
                        onComplete()
                    }
                }
            } label: {
                ZStack {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text("Cập nhật mật khẩu")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(MiumoTheme.primaryGradient)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

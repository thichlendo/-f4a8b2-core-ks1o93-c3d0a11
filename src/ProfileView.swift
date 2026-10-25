import SwiftUI
import UIKit
import PhotosUI
import FirebaseDatabase

// MARK: - Own Profile Screen (Port of MainActivity Profile Tab, EditProfileSheet, SettingsSheet, EditAvatarActivity)
struct OwnProfileScreen: View {
    @EnvironmentObject var firebase: FirebaseManager
    let onOpenComposer: () -> Void
    let onOpenComments: (Post) -> Void
    let onOpenOptions: (Post) -> Void
    let onOpenSearch: () -> Void
    let onSelectUser: (String) -> Void

    @State private var selectedFilter: ProfileFilter = .posts
    @State private var showEditProfileSheet: Bool = false
    @State private var showSettingsSheet: Bool = false
    @State private var showFollowListMode: FollowListMode?
    @State private var pickedAvatarItem: PhotosPickerItem?
    @State private var rawAvatarForCrop: UIImage?

    private var filteredPosts: [Post] {
        let uid = firebase.currentUserId
        switch selectedFilter {
        case .posts:
            return firebase.allPosts.filter { $0.authorId == uid }
        case .videos:
            return firebase.allPosts.filter { $0.authorId == uid && $0.hasVideo }
        case .reposts:
            return firebase.allPosts.filter { firebase.myRepostedPostIds.contains($0.id) }
        case .tagged:
            return firebase.allPosts.filter { $0.taggedUserIds.contains(uid) }
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Top Action Header
                HStack {
                    Text("@\(firebase.currentUser?.username ?? "miumo")")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(MiumoTheme.textPrimary)

                    Spacer()

                    Button(action: onOpenSearch) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(MiumoTheme.textPrimary)
                            .frame(width: 38, height: 38)
                            .background(MiumoTheme.surfacePrimary)
                            .clipShape(Circle())
                    }

                    Button {
                        showSettingsSheet = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(MiumoTheme.textPrimary)
                            .frame(width: 38, height: 38)
                            .background(MiumoTheme.surfacePrimary)
                            .clipShape(Circle())
                    }
                }
                .padding(.top, 12)

                // Hero Profile Card
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 16) {
                        PhotosPicker(selection: $pickedAvatarItem, matching: .images) {
                            ZStack(alignment: .bottomTrailing) {
                                MiumoAvatarView(
                                    url: firebase.currentUser?.avatarUrl ?? "",
                                    fallbackInitial: firebase.currentUser?.avatarInitial ?? "M",
                                    size: 78
                                )

                                Image(systemName: "camera.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(MiumoTheme.accentPrimary)
                                    .background(Circle().fill(MiumoTheme.canvas))
                            }
                        }
                        .onChange(of: pickedAvatarItem) { newItem in
                            guard let newItem = newItem else { return }
                            Task {
                                if let data = try? await newItem.loadTransferable(type: Data.self),
                                   let uiImg = UIImage(data: data) {
                                    await MainActor.run {
                                        rawAvatarForCrop = uiImg
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(firebase.currentUser?.effectiveDisplayName ?? "Thành viên MiuMo")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(MiumoTheme.textPrimary)

                                if firebase.currentUser?.verified == true {
                                    VerifiedBadgeView(size: 17)
                                }
                            }

                            Text("@\(firebase.currentUser?.username ?? "miumo")")
                                .font(.system(size: 14))
                                .foregroundColor(MiumoTheme.textSecondary)
                        }
                    }

                    Text(
                        (firebase.currentUser?.bio.isEmpty == false)
                            ? firebase.currentUser!.bio
                            : "Chạm vào Chỉnh sửa trang cá nhân để thêm tiểu sử."
                    )
                    .font(.system(size: 14))
                    .foregroundColor(MiumoTheme.textPrimary)

                    // Metrics Strip
                    HStack(spacing: 0) {
                        statItem(
                            value: "\(firebase.allPosts.filter { $0.authorId == firebase.currentUserId }.count)",
                            label: "Bài viết",
                            action: nil
                        )

                        Divider().frame(height: 26).background(MiumoTheme.separator)

                        statItem(
                            value: "\(firebase.myFollowerIds.count)",
                            label: "Người theo dõi"
                        ) {
                            showFollowListMode = .followers
                        }

                        Divider().frame(height: 26).background(MiumoTheme.separator)

                        statItem(
                            value: "\(firebase.myFollowingIds.count)",
                            label: "Đang theo dõi"
                        ) {
                            showFollowListMode = .following
                        }
                    }
                    .padding(.vertical, 10)
                    .background(MiumoTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // Action Buttons
                    HStack(spacing: 10) {
                        Button {
                            showEditProfileSheet = true
                        } label: {
                            Text("Chỉnh sửa trang cá nhân")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(MiumoTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(MiumoTheme.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        Button {
                            let uname = firebase.currentUser?.username ?? ""
                            let av = UIActivityViewController(
                                activityItems: ["Kết nối với tôi trên MiuMo: @\(uname)"],
                                applicationActivities: nil
                            )
                            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let root = scene.windows.first?.rootViewController {
                                root.present(av, animated: true)
                            }
                        } label: {
                            Text("Chia sẻ hồ sơ")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(MiumoTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(MiumoTheme.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
                .padding(18)
                .background(MiumoTheme.surfacePrimary)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(MiumoTheme.strokeSubtle, lineWidth: 1)
                )

                // Segmented Filter Bar (Posts, Videos, Reposts, Tagged)
                HStack(spacing: 6) {
                    ForEach(ProfileFilter.allCases, id: \.self) { filter in
                        let isSelected = selectedFilter == filter
                        Button {
                            withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) {
                                selectedFilter = filter
                            }
                        } label: {
                            Text(filter.rawValue)
                                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                                .foregroundColor(isSelected ? .white : MiumoTheme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                                .background(
                                    isSelected
                                        ? AnyView(MiumoTheme.primaryGradient)
                                        : AnyView(Color.clear)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        }
                    }
                }
                .padding(4)
                .background(MiumoTheme.surfacePrimary)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                if filteredPosts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 36))
                            .foregroundColor(MiumoTheme.textMuted)
                        Text("Chưa có nội dung trong mục \(selectedFilter.rawValue)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(MiumoTheme.textPrimary)
                        Button("Tạo bài viết đầu tiên", action: onOpenComposer)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(MiumoTheme.accentPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(filteredPosts) { post in
                            PostCardView(
                                post: post,
                                onLike: { firebase.toggleLike(post) },
                                onComment: { onOpenComments(post) },
                                onRepost: { firebase.toggleRepost(post) },
                                onShare: {},
                                onMore: { onOpenOptions(post) },
                                onAuthorTap: { onSelectUser(post.authorId) }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        .sheet(isPresented: $showEditProfileSheet) {
            EditProfileSheet()
                .environmentObject(firebase)
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsBottomSheet()
                .environmentObject(firebase)
        }
        .sheet(
            isPresented: Binding(
                get: { showFollowListMode != nil },
                set: { if !$0 { showFollowListMode = nil } }
            )
        ) {
            if let mode = showFollowListMode {
                FollowListScreen(
                    targetUserId: firebase.currentUserId,
                    username: firebase.currentUser?.username ?? "",
                    initialMode: mode,
                    onSelectUser: onSelectUser
                )
                .environmentObject(firebase)
            }
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { rawAvatarForCrop != nil },
                set: { if !$0 { rawAvatarForCrop = nil } }
            )
        ) {
            if let img = rawAvatarForCrop {
                CircleCropAvatarView(
                    sourceImage: img,
                    onCancel: { rawAvatarForCrop = nil },
                    onSaveCropped: { cropped in
                        rawAvatarForCrop = nil
                        firebase.updateAvatarImage(cropped) { _ in }
                    }
                )
            }
        }
    }

    private func statItem(value: String, label: String, action: (() -> Void)?) -> some View {
        Button {
            action?()
        } label: {
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(MiumoTheme.textPrimary)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(MiumoTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .disabled(action == nil)
    }
}

// MARK: - Edit Profile Sheet (Port of bottom_sheet_edit_profile)
struct EditProfileSheet: View {
    @EnvironmentObject var firebase: FirebaseManager
    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String = ""
    @State private var username: String = ""
    @State private var bio: String = ""

    var body: some View {
        NavigationView {
            ZStack {
                MiumoTheme.canvas.ignoresSafeArea()

                VStack(spacing: 18) {
                    MiumoAvatarView(
                        url: firebase.currentUser?.avatarUrl ?? "",
                        fallbackInitial: firebase.currentUser?.avatarInitial ?? "M",
                        size: 76
                    )
                    .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tên hiển thị")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(MiumoTheme.textSecondary)
                        TextField("Tên hiển thị", text: $displayName)
                            .foregroundColor(MiumoTheme.textPrimary)
                            .padding(.horizontal, 14)
                            .frame(height: 48)
                            .background(MiumoTheme.surfacePrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tên người dùng (@username)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(MiumoTheme.textSecondary)
                        TextField("username", text: $username)
                            .textInputAutocapitalization(.never)
                            .foregroundColor(MiumoTheme.textPrimary)
                            .padding(.horizontal, 14)
                            .frame(height: 48)
                            .background(MiumoTheme.surfacePrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tiểu sử")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(MiumoTheme.textSecondary)
                        TextField("Giới thiệu ngắn về bạn...", text: $bio)
                            .foregroundColor(MiumoTheme.textPrimary)
                            .padding(.horizontal, 14)
                            .frame(height: 48)
                            .background(MiumoTheme.surfacePrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Chỉnh sửa hồ sơ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                        .foregroundColor(MiumoTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        guard username.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 else {
                            firebase.showToast("Tên người dùng tối thiểu 3 ký tự")
                            return
                        }
                        firebase.updateProfile(displayName: displayName, username: username, bio: bio) { ok in
                            if ok { dismiss() }
                        }
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(MiumoTheme.accentPrimary)
                }
            }
            .onAppear {
                if let u = firebase.currentUser {
                    displayName = u.displayName
                    username = u.username
                    bio = u.bio
                }
            }
        }
    }
}

// MARK: - Settings Bottom Sheet (Port of bottom_sheet_settings)
struct SettingsBottomSheet: View {
    @EnvironmentObject var firebase: FirebaseManager
    @Environment(\.dismiss) private var dismiss
    @State private var showLogoutConfirm: Bool = false

    var body: some View {
        NavigationView {
            ZStack {
                MiumoTheme.canvas.ignoresSafeArea()

                VStack(spacing: 12) {
                    settingsRow(icon: "heart.fill", title: "Bài viết đã thích") {
                        firebase.showToast("Danh sách bài viết đã thích")
                    }
                    settingsRow(icon: "bookmark.fill", title: "Bài viết đã lưu") {
                        firebase.showToast("Danh sách bài viết đã lưu")
                    }
                    settingsRow(icon: "lock.shield.fill", title: "Quyền riêng tư & Bảo mật") {
                        firebase.showToast("Tài khoản của bạn được bảo vệ bởi Firebase Auth")
                    }
                    settingsRow(icon: "info.circle.fill", title: "Giới thiệu \(AppConstants.appName)") {
                        firebase.showToast("\(AppConstants.appName) iOS Native Edition v1.0")
                    }

                    Spacer()

                    Button {
                        showLogoutConfirm = true
                    } label: {
                        Text("Đăng xuất khỏi tài khoản")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(MiumoTheme.heartRed)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(MiumoTheme.surfacePrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(20)
            }
            .navigationTitle("Cài đặt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                        .foregroundColor(MiumoTheme.textSecondary)
                }
            }
            .alert("Đăng xuất khỏi tài khoản của bạn?", isPresented: $showLogoutConfirm) {
                Button("Hủy", role: .cancel) {}
                Button("Đăng xuất", role: .destructive) {
                    dismiss()
                    firebase.signOut()
                }
            } message: {
                Text("Bạn có thể đăng nhập lại bất cứ lúc nào bằng tài khoản \(AppConstants.appName).")
            }
        }
    }

    private func settingsRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(MiumoTheme.accentPrimary)
                    .frame(width: 28)

                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(MiumoTheme.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(MiumoTheme.textMuted)
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(MiumoTheme.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

// MARK: - Other User Profile Screen (Port of UserProfileActivity.kt)
struct UserProfileScreen: View {
    @EnvironmentObject var firebase: FirebaseManager
    @Environment(\.dismiss) private var dismiss
    let targetUserId: String

    @State private var targetUser: User?
    @State private var followerCount: Int = 0
    @State private var followingCount: Int = 0
    @State private var selectedFilter: ProfileFilter = .posts
    @State private var showChat: Bool = false
    @State private var showFollowListMode: FollowListMode?

    private var isFollowing: Bool {
        firebase.myFollowingIds.contains(targetUserId)
    }

    private var userPosts: [Post] {
        switch selectedFilter {
        case .posts:
            return firebase.allPosts.filter { $0.authorId == targetUserId && $0.visibility != "private" }
        case .videos:
            return firebase.allPosts.filter { $0.authorId == targetUserId && $0.hasVideo }
        case .reposts:
            return firebase.allPosts.filter { $0.authorId == targetUserId }
        case .tagged:
            return firebase.allPosts.filter { $0.taggedUserIds.contains(targetUserId) }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                MiumoTheme.canvas.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 16) {
                                MiumoAvatarView(
                                    url: targetUser?.avatarUrl ?? "",
                                    fallbackInitial: targetUser?.avatarInitial ?? "M",
                                    size: 74
                                )

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(targetUser?.effectiveDisplayName ?? "Người dùng")
                                            .font(.system(size: 20, weight: .bold, design: .rounded))
                                            .foregroundColor(MiumoTheme.textPrimary)

                                        if targetUser?.verified == true {
                                            VerifiedBadgeView(size: 16)
                                        }
                                    }

                                    Text("@\(targetUser?.username ?? "")")
                                        .font(.system(size: 14))
                                        .foregroundColor(MiumoTheme.textSecondary)
                                }
                            }

                            Text(targetUser?.bio.isEmpty == false ? targetUser!.bio : "Chưa có tiểu sử.")
                                .font(.system(size: 14))
                                .foregroundColor(MiumoTheme.textPrimary)

                            HStack(spacing: 24) {
                                VStack(spacing: 2) {
                                    Text("\(userPosts.count)")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(MiumoTheme.textPrimary)
                                    Text("Bài viết")
                                        .font(.system(size: 12))
                                        .foregroundColor(MiumoTheme.textSecondary)
                                }

                                Button {
                                    showFollowListMode = .followers
                                } label: {
                                    VStack(spacing: 2) {
                                        Text("\(followerCount)")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(MiumoTheme.textPrimary)
                                        Text("Người theo dõi")
                                            .font(.system(size: 12))
                                            .foregroundColor(MiumoTheme.textSecondary)
                                    }
                                }

                                Button {
                                    showFollowListMode = .following
                                } label: {
                                    VStack(spacing: 2) {
                                        Text("\(followingCount)")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(MiumoTheme.textPrimary)
                                        Text("Đang theo dõi")
                                            .font(.system(size: 12))
                                            .foregroundColor(MiumoTheme.textSecondary)
                                    }
                                }
                            }

                            HStack(spacing: 10) {
                                Button {
                                    firebase.toggleFollow(targetUid: targetUserId)
                                } label: {
                                    Text(isFollowing ? "Đang theo dõi" : "Theo dõi")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 42)
                                        .background(
                                            isFollowing
                                                ? AnyView(MiumoTheme.surfaceElevated)
                                                : AnyView(MiumoTheme.primaryGradient)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }

                                Button {
                                    showChat = true
                                } label: {
                                    Text("Nhắn tin")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(MiumoTheme.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 42)
                                        .background(MiumoTheme.surfaceElevated)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                            }
                        }
                        .padding(18)
                        .background(MiumoTheme.surfacePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                        LazyVStack(spacing: 14) {
                            ForEach(userPosts) { post in
                                PostCardView(
                                    post: post,
                                    onLike: { firebase.toggleLike(post) },
                                    onComment: {},
                                    onRepost: { firebase.toggleRepost(post) },
                                    onShare: {},
                                    onMore: {},
                                    onAuthorTap: {}
                                )
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle(targetUser?.username ?? "Hồ sơ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                        .foregroundColor(MiumoTheme.textSecondary)
                }
            }
            .sheet(isPresented: $showChat) {
                ChatScreen(otherUid: targetUserId)
                    .environmentObject(firebase)
            }
            .sheet(
                isPresented: Binding(
                    get: { showFollowListMode != nil },
                    set: { if !$0 { showFollowListMode = nil } }
                )
            ) {
                if let mode = showFollowListMode {
                    FollowListScreen(
                        targetUserId: targetUserId,
                        username: targetUser?.username ?? "",
                        initialMode: mode,
                        onSelectUser: { _ in }
                    )
                    .environmentObject(firebase)
                }
            }
            .onAppear(perform: loadTargetUser)
        }
    }

    private func loadTargetUser() {
        let db = Database.database(url: AppConstants.databaseURL).reference()
        db.child("users").child(targetUserId).observe(.value) { snap in
            guard let dict = snap.value as? [String: Any] else { return }
            let u = User.fromDictionary(dict, fallbackUid: targetUserId)
            DispatchQueue.main.async {
                self.targetUser = u
            }
        }
        db.child("followers").child(targetUserId).observe(.value) { snap in
            DispatchQueue.main.async {
                self.followerCount = Int(snap.childrenCount)
            }
        }
        db.child("following").child(targetUserId).observe(.value) { snap in
            DispatchQueue.main.async {
                self.followingCount = Int(snap.childrenCount)
            }
        }
    }
}

// MARK: - Followers / Following List Screen (Port of FollowListActivity.kt)
struct FollowListScreen: View {
    @EnvironmentObject var firebase: FirebaseManager
    @Environment(\.dismiss) private var dismiss
    let targetUserId: String
    let username: String
    let initialMode: FollowListMode
    let onSelectUser: (String) -> Void

    @State private var currentMode: FollowListMode = .followers
    @State private var users: [UserResult] = []
    @State private var followersCount: Int = 0
    @State private var followingCount: Int = 0

    var body: some View {
        NavigationView {
            ZStack {
                MiumoTheme.canvas.ignoresSafeArea()

                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Button {
                            currentMode = .followers
                            loadList(mode: .followers)
                        } label: {
                            Text("\(followersCount) người theo dõi")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(currentMode == .followers ? .white : MiumoTheme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                                .background(
                                    currentMode == .followers
                                        ? AnyView(MiumoTheme.primaryGradient)
                                        : AnyView(MiumoTheme.surfacePrimary)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }

                        Button {
                            currentMode = .following
                            loadList(mode: .following)
                        } label: {
                            Text("\(followingCount) đang theo dõi")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(currentMode == .following ? .white : MiumoTheme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                                .background(
                                    currentMode == .following
                                        ? AnyView(MiumoTheme.primaryGradient)
                                        : AnyView(MiumoTheme.surfacePrimary)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(users) { user in
                                UserRowItemView(
                                    user: user,
                                    currentUserId: firebase.currentUserId,
                                    isFollowing: firebase.myFollowingIds.contains(user.uid),
                                    onFollowToggle: {
                                        firebase.toggleFollow(targetUid: user.uid)
                                        loadCounts()
                                    },
                                    onRowTap: {
                                        dismiss()
                                        onSelectUser(user.uid)
                                    }
                                )
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("@\(username)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                        .foregroundColor(MiumoTheme.textSecondary)
                }
            }
            .onAppear {
                currentMode = initialMode
                loadCounts()
                loadList(mode: initialMode)
            }
        }
    }

    private func loadCounts() {
        let db = Database.database(url: AppConstants.databaseURL).reference()
        db.child("followers").child(targetUserId).observeSingleEvent(of: .value) { snap in
            DispatchQueue.main.async {
                self.followersCount = Int(snap.childrenCount)
            }
        }
        db.child("following").child(targetUserId).observeSingleEvent(of: .value) { snap in
            DispatchQueue.main.async {
                self.followingCount = Int(snap.childrenCount)
            }
        }
    }

    private func loadList(mode: FollowListMode) {
        let node = mode == .followers ? "followers" : "following"
        let db = Database.database(url: AppConstants.databaseURL).reference()
        db.child(node).child(targetUserId).observeSingleEvent(of: .value) { snap in
            let uids = (snap.children.allObjects as? [DataSnapshot] ?? []).map { $0.key }
            guard !uids.isEmpty else {
                DispatchQueue.main.async { self.users = [] }
                return
            }

            var loadedUsers: [UserResult] = []
            let group = DispatchGroup()

            for uid in uids {
                group.enter()
                db.child("users").child(uid).observeSingleEvent(of: .value) { userSnap in
                    if let dict = userSnap.value as? [String: Any] {
                        let u = User.fromDictionary(dict, fallbackUid: uid)
                        loadedUsers.append(
                            UserResult(
                                uid: uid,
                                username: u.username,
                                displayName: u.displayName,
                                verified: u.verified,
                                avatarUrl: u.avatarUrl
                            )
                        )
                    }
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                self.users = loadedUsers
            }
        }
    }
}

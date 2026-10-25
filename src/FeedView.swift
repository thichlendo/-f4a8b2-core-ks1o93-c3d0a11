import SwiftUI
import UIKit
import PhotosUI
import FirebaseDatabase

// MARK: - Main Tab Shell & Home Feed (Port of MainActivity.kt, PostAdapter.kt, CommentAdapter.kt)
struct MainTabView: View {
    @EnvironmentObject var firebase: FirebaseManager
    @State private var selectedTab: MiumoTab = .home
    @State private var showComposerSheet: Bool = false
    @State private var showSearchSheet: Bool = false
    @State private var showMessagesSheet: Bool = false
    @State private var activeCommentPost: Post?
    @State private var activeOptionsPost: Post?
    @State private var selectedProfileUid: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            MiumoTheme.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                if selectedTab == .home || selectedTab == .video {
                    topNavigationBar
                }

                Group {
                    switch selectedTab {
                    case .home:
                        HomeFeedScreen(
                            onOpenComposer: { showComposerSheet = true },
                            onOpenComments: { post in activeCommentPost = post },
                            onOpenOptions: { post in activeOptionsPost = post },
                            onSelectAuthor: { uid in
                                if uid == firebase.currentUserId {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                                        selectedTab = .profile
                                    }
                                } else {
                                    selectedProfileUid = uid
                                }
                            }
                        )
                    case .video:
                        VideoFeedScreen(
                            onOpenComments: { post in activeCommentPost = post },
                            onSelectAuthor: { uid in
                                if uid == firebase.currentUserId {
                                    selectedTab = .profile
                                } else {
                                    selectedProfileUid = uid
                                }
                            }
                        )
                    case .activity:
                        ActivityCenterScreen(
                            onSelectAuthor: { uid in
                                selectedProfileUid = uid
                            }
                        )
                    case .profile:
                        OwnProfileScreen(
                            onOpenComposer: { showComposerSheet = true },
                            onOpenComments: { post in activeCommentPost = post },
                            onOpenOptions: { post in activeOptionsPost = post },
                            onOpenSearch: { showSearchSheet = true },
                            onSelectUser: { uid in
                                if uid != firebase.currentUserId {
                                    selectedProfileUid = uid
                                }
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Custom Native iOS Floating Tab Bar with Center Compose Button
            bottomTabBar
        }
        .sheet(isPresented: $showComposerSheet) {
            CreatePostSheet()
                .environmentObject(firebase)
        }
        .sheet(isPresented: $showSearchSheet) {
            UserSearchSheet { uid in
                showSearchSheet = false
                if uid == firebase.currentUserId {
                    selectedTab = .profile
                } else {
                    selectedProfileUid = uid
                }
            }
            .environmentObject(firebase)
        }
        .sheet(isPresented: $showMessagesSheet) {
            MessagesListScreen()
                .environmentObject(firebase)
        }
        .sheet(item: $activeCommentPost) { post in
            CommentsBottomSheet(post: post)
                .environmentObject(firebase)
        }
        .confirmationDialog(
            "Tùy chọn bài viết",
            isPresented: Binding(
                get: { activeOptionsPost != nil },
                set: { if !$0 { activeOptionsPost = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let post = activeOptionsPost {
                Button("Sao chép nội dung bài viết") {
                    UIPasteboard.general.string = post.content
                    firebase.showToast("Đã sao chép liên kết bài viết")
                }
                if post.authorId == firebase.currentUserId {
                    Button("Xóa bài viết", role: .destructive) {
                        firebase.deletePost(post)
                    }
                }
                Button("Hủy", role: .cancel) {}
            }
        }
        .sheet(
            isPresented: Binding(
                get: { selectedProfileUid != nil },
                set: { if !$0 { selectedProfileUid = nil } }
            )
        ) {
            if let targetUid = selectedProfileUid {
                UserProfileScreen(targetUserId: targetUid)
                    .environmentObject(firebase)
            }
        }
    }

    // MARK: - Top Navigation Bar
    private var topNavigationBar: some View {
        HStack(spacing: 14) {
            Button {
                showSearchSheet = true
                firebase.loadAllUsersForSearch()
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(MiumoTheme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(MiumoTheme.surfacePrimary)
                    .clipShape(Circle())
            }

            Spacer()

            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(MiumoTheme.primaryGradient)
                        .frame(width: 30, height: 30)
                    Image(systemName: "cat.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }

                Text(AppConstants.appName)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundColor(MiumoTheme.textPrimary)
            }

            Spacer()

            Button {
                showMessagesSheet = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(MiumoTheme.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(MiumoTheme.surfacePrimary)
                        .clipShape(Circle())

                    if firebase.hasUnreadMessages {
                        Circle()
                            .fill(MiumoTheme.heartRed)
                            .frame(width: 10, height: 10)
                            .offset(x: -2, y: 2)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(MiumoTheme.canvas.opacity(0.95))
    }

    // MARK: - Bottom Tab Bar
    private var bottomTabBar: some View {
        HStack(spacing: 0) {
            tabBarButton(tab: .home, icon: "house", activeIcon: "house.fill")
            tabBarButton(tab: .video, icon: "play.rectangle", activeIcon: "play.rectangle.fill")

            // Center Compose CTA
            Button {
                showComposerSheet = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(MiumoTheme.primaryGradient)
                        .frame(width: 52, height: 40)
                        .shadow(color: MiumoTheme.accentPrimary.opacity(0.45), radius: 10, x: 0, y: 4)

                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)

            tabBarButton(tab: .activity, icon: "heart", activeIcon: "heart.fill")
            tabBarButton(tab: .profile, icon: "person.crop.circle", activeIcon: "person.crop.circle.fill")
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 22)
        .background(
            MiumoTheme.surfacePrimary
                .overlay(
                    Rectangle()
                        .fill(MiumoTheme.separator)
                        .frame(height: 0.5),
                    alignment: .top
                )
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabBarButton(tab: MiumoTab, icon: String, activeIcon: String) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? activeIcon : icon)
                    .font(.system(size: 20, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? MiumoTheme.textPrimary : MiumoTheme.textSecondary)
                    .scaleEffect(isSelected ? 1.08 : 1.0)

                Circle()
                    .fill(isSelected ? MiumoTheme.accentPrimary : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
    }
}

// MARK: - Home Feed Screen
struct HomeFeedScreen: View {
    @EnvironmentObject var firebase: FirebaseManager
    let onOpenComposer: () -> Void
    let onOpenComments: (Post) -> Void
    let onOpenOptions: (Post) -> Void
    let onSelectAuthor: (String) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 14) {
                // Inline Composer Trigger Card
                Button(action: onOpenComposer) {
                    HStack(spacing: 12) {
                        MiumoAvatarView(
                            url: firebase.currentUser?.avatarUrl ?? "",
                            fallbackInitial: firebase.currentUser?.avatarInitial ?? "M",
                            size: 42
                        )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(firebase.currentUser?.username.isEmpty == false ? "@\(firebase.currentUser!.username)" : "Bạn ơi")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(MiumoTheme.textPrimary)

                            Text("Có gì mới? Chia sẻ khoảnh khắc ngay...")
                                .font(.system(size: 14))
                                .foregroundColor(MiumoTheme.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 18))
                            .foregroundColor(MiumoTheme.accentPrimary)
                    }
                    .padding(16)
                    .background(MiumoTheme.surfacePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(MiumoTheme.strokeSubtle, lineWidth: 1)
                    )
                }

                if firebase.allPosts.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "sparkles.rectangle.stack")
                            .font(.system(size: 42))
                            .foregroundColor(MiumoTheme.textMuted)
                        Text("Chưa có bài viết nào trên bảng tin")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(MiumoTheme.textPrimary)
                        Text("Hãy là người đầu tiên chia sẻ bài viết trên \(AppConstants.appName)!")
                            .font(.system(size: 13))
                            .foregroundColor(MiumoTheme.textSecondary)
                    }
                    .padding(.vertical, 64)
                } else {
                    ForEach(firebase.allPosts) { post in
                        PostCardView(
                            post: post,
                            onLike: { firebase.toggleLike(post) },
                            onComment: { onOpenComments(post) },
                            onRepost: { firebase.toggleRepost(post) },
                            onShare: { sharePost(post) },
                            onMore: { onOpenOptions(post) },
                            onAuthorTap: { onSelectAuthor(post.authorId) }
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }

    private func sharePost(_ post: Post) {
        let av = UIActivityViewController(activityItems: [post.content], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }
}

// MARK: - Redesigned Native iOS Post Card (Port of PostAdapter.kt)
struct PostCardView: View {
    @EnvironmentObject var firebase: FirebaseManager
    let post: Post
    let onLike: () -> Void
    let onComment: () -> Void
    let onRepost: () -> Void
    let onShare: () -> Void
    let onMore: () -> Void
    let onAuthorTap: () -> Void

    @State private var likeBounce: CGFloat = 1.0
    @State private var repostRotation: Double = 0.0

    private var author: User? {
        firebase.authorCache[post.authorId]
    }

    private var visibilityLabel: String {
        switch post.visibility {
        case "friends": return " · Bạn bè"
        case "private": return " · Riêng tư"
        default: return ""
        }
    }

    private var isLiked: Bool {
        firebase.myLikedPostIds.contains(post.id)
    }

    private var isReposted: Bool {
        firebase.myRepostedPostIds.contains(post.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                Button(action: onAuthorTap) {
                    ZStack(alignment: .bottomTrailing) {
                        MiumoAvatarView(
                            url: author?.avatarUrl ?? "",
                            fallbackInitial: author?.avatarInitial ?? "M",
                            size: 42
                        )

                        if post.authorId != firebase.currentUserId && !firebase.myFollowingIds.contains(post.authorId) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 15))
                                .foregroundColor(MiumoTheme.accentPrimary)
                                .background(Circle().fill(MiumoTheme.canvas))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Button(action: onAuthorTap) {
                        HStack(spacing: 5) {
                            Text(author?.username.isEmpty == false ? author!.username : "miumo_user")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(MiumoTheme.textPrimary)

                            if author?.verified == true {
                                VerifiedBadgeView(size: 14)
                            }
                        }
                    }

                    Text(TimeFormatterHelper.relativeTime(from: post.timestamp) + visibilityLabel)
                        .font(.system(size: 12))
                        .foregroundColor(MiumoTheme.textSecondary)
                }

                Spacer()

                Button(action: onMore) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(MiumoTheme.textSecondary)
                        .frame(width: 34, height: 34)
                }
            }

            // Content Text
            if !post.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(post.content)
                    .font(.system(size: 15))
                    .foregroundColor(MiumoTheme.textPrimary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Attached Media Image
            if !post.imageUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let mediaURL = URL(string: post.imageUrl) {
                AsyncImage(url: mediaURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: 340)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    case .failure:
                        EmptyView()
                    case .empty:
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(MiumoTheme.surfaceElevated)
                            .frame(height: 200)
                            .overlay(ProgressView())
                    @unknown default:
                        EmptyView()
                    }
                }
            }

            // Action Bar: Like, Comment, Repost, Share
            HStack(spacing: 26) {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.5)) {
                        likeBounce = 1.32
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                            likeBounce = 1.0
                        }
                    }
                    onLike()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(isLiked ? MiumoTheme.heartRed : MiumoTheme.textPrimary)
                            .scaleEffect(likeBounce)

                        let count = firebase.likeCounts[post.id] ?? 0
                        if count > 0 {
                            Text("\(count)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(isLiked ? MiumoTheme.heartRed : MiumoTheme.textSecondary)
                        }
                    }
                }

                Button(action: onComment) {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.right")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(MiumoTheme.textPrimary)

                        let count = firebase.commentCounts[post.id] ?? 0
                        if count > 0 {
                            Text("\(count)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(MiumoTheme.textSecondary)
                        }
                    }
                }

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        repostRotation += 360
                    }
                    onRepost()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.2.squarepath")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(isReposted ? MiumoTheme.repostGreen : MiumoTheme.textPrimary)
                            .rotationEffect(.degrees(repostRotation))

                        let count = firebase.repostCounts[post.id] ?? 0
                        if count > 0 {
                            Text("\(count)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(isReposted ? MiumoTheme.repostGreen : MiumoTheme.textSecondary)
                        }
                    }
                }

                Button(action: onShare) {
                    Image(systemName: "paperplane")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(MiumoTheme.textPrimary)
                }

                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(MiumoTheme.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(MiumoTheme.strokeSubtle, lineWidth: 1)
        )
        .onAppear {
            firebase.preloadAuthorIfNeeded(post.authorId)
        }
    }
}

// MARK: - Create Post Sheet (Port of bottom_sheet_create_post)
struct CreatePostSheet: View {
    @EnvironmentObject var firebase: FirebaseManager
    @Environment(\.dismiss) private var dismiss

    @State private var content: String = ""
    @State private var isPrivate: Bool = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isPosting: Bool = false

    var body: some View {
        NavigationView {
            ZStack {
                MiumoTheme.canvas.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 12) {
                        MiumoAvatarView(
                            url: firebase.currentUser?.avatarUrl ?? "",
                            fallbackInitial: firebase.currentUser?.avatarInitial ?? "M",
                            size: 44
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Text(firebase.currentUser?.username ?? "miumo")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(MiumoTheme.textPrimary)

                                if firebase.currentUser?.verified == true {
                                    VerifiedBadgeView(size: 14)
                                }
                            }

                            TextEditor(text: $content)
                                .frame(minHeight: 110)
                                .scrollContentBackground(.hidden)
                                .foregroundColor(MiumoTheme.textPrimary)
                                .font(.system(size: 16))
                                .overlay(
                                    Group {
                                        if content.isEmpty {
                                            Text("Có gì mới? Chia sẻ suy nghĩ của bạn...")
                                                .foregroundColor(MiumoTheme.textMuted)
                                                .font(.system(size: 16))
                                                .padding(.top, 8)
                                                .padding(.leading, 4)
                                        }
                                    },
                                    alignment: .topLeading
                                )
                        }
                    }

                    if let image = selectedImage {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 210)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                            Button {
                                selectedImage = nil
                                selectedItem = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .padding(10)
                            }
                        }
                    }

                    HStack(spacing: 16) {
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            HStack(spacing: 6) {
                                Image(systemName: "photo.fill")
                                Text("Đính kèm ảnh")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(MiumoTheme.accentPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(MiumoTheme.surfacePrimary)
                            .clipShape(Capsule())
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

                        Spacer()

                        Toggle("Chỉ mình tôi", isOn: $isPrivate)
                            .labelsHidden()
                            .tint(MiumoTheme.accentPrimary)

                        Text(isPrivate ? "Riêng tư" : "Công khai")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(MiumoTheme.textSecondary)
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Bài viết mới")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                        .foregroundColor(MiumoTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        submit()
                    } label: {
                        if isPosting {
                            ProgressView()
                        } else {
                            Text("Đăng")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(MiumoTheme.accentPrimary)
                        }
                    }
                    .disabled(isPosting)
                }
            }
        }
    }

    private func submit() {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || selectedImage != nil else {
            firebase.showToast("Vui lòng nhập nội dung bài viết")
            return
        }
        isPosting = true
        let visibility = isPrivate ? "private" : "public"
        firebase.createPost(content: trimmed, visibility: visibility, image: selectedImage) { _ in
            isPosting = false
            dismiss()
        }
    }
}

// MARK: - Comments Bottom Sheet (Port of CommentAdapter.kt & openComments)
struct CommentsBottomSheet: View {
    @EnvironmentObject var firebase: FirebaseManager
    @Environment(\.dismiss) private var dismiss
    let post: Post

    @State private var comments: [Comment] = []
    @State private var commentInput: String = ""
    @State private var likedCommentIds: Set<String> = []

    private var commentsRef: DatabaseReference {
        Database.database(url: AppConstants.databaseURL).reference().child("post_comments").child(post.id)
    }

    var body: some View {
        NavigationView {
            ZStack {
                MiumoTheme.canvas.ignoresSafeArea()

                VStack(spacing: 0) {
                    if comments.isEmpty {
                        Spacer()
                        VStack(spacing: 10) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 36))
                                .foregroundColor(MiumoTheme.textMuted)
                            Text("Chưa có bình luận nào")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(MiumoTheme.textPrimary)
                            Text("Hãy để lại bình luận đầu tiên cho bài viết này.")
                                .font(.system(size: 13))
                                .foregroundColor(MiumoTheme.textSecondary)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 14) {
                                ForEach(comments) { comment in
                                    let author = firebase.authorCache[comment.authorId]
                                    HStack(alignment: .top, spacing: 12) {
                                        MiumoAvatarView(
                                            url: author?.avatarUrl ?? "",
                                            fallbackInitial: author?.avatarInitial ?? "M",
                                            size: 36
                                        )

                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(spacing: 6) {
                                                Text(author?.username ?? "MiuMo User")
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(MiumoTheme.textPrimary)

                                                Text(TimeFormatterHelper.shortRelativeTime(from: comment.timestamp))
                                                    .font(.system(size: 12))
                                                    .foregroundColor(MiumoTheme.textMuted)
                                            }

                                            Text(comment.content)
                                                .font(.system(size: 14))
                                                .foregroundColor(MiumoTheme.textPrimary)

                                            HStack(spacing: 14) {
                                                Button("Trả lời") {
                                                    let handle = author?.username ?? String(comment.authorId.prefix(6))
                                                    commentInput = "@\(handle) "
                                                }
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(MiumoTheme.textSecondary)
                                            }
                                            .padding(.top, 2)
                                        }

                                        Spacer()

                                        Button {
                                            if likedCommentIds.contains(comment.id) {
                                                likedCommentIds.remove(comment.id)
                                            } else {
                                                likedCommentIds.insert(comment.id)
                                            }
                                        } label: {
                                            Image(systemName: likedCommentIds.contains(comment.id) ? "heart.fill" : "heart")
                                                .font(.system(size: 14))
                                                .foregroundColor(likedCommentIds.contains(comment.id) ? MiumoTheme.heartRed : MiumoTheme.textSecondary)
                                        }
                                    }
                                    .padding(12)
                                    .background(MiumoTheme.surfacePrimary)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .onAppear {
                                        firebase.preloadAuthorIfNeeded(comment.authorId)
                                    }
                                }
                            }
                            .padding(16)
                        }
                    }

                    // Comment Input Bar
                    HStack(spacing: 10) {
                        TextField("Thêm bình luận...", text: $commentInput)
                            .foregroundColor(MiumoTheme.textPrimary)
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                            .background(MiumoTheme.surfaceElevated)
                            .clipShape(Capsule())

                        Button(action: sendComment) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(MiumoTheme.accentPrimary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(MiumoTheme.surfacePrimary)
                }
            }
            .navigationTitle("Bình luận")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                        .foregroundColor(MiumoTheme.textSecondary)
                }
            }
            .onAppear(perform: listenComments)
        }
    }

    private func listenComments() {
        commentsRef.observe(.value) { snapshot in
            var loaded: [Comment] = []
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                guard let dict = child.value as? [String: Any] else { continue }
                loaded.append(Comment.fromDictionary(dict, fallbackId: child.key))
            }
            loaded.sort { $0.timestamp < $1.timestamp }
            DispatchQueue.main.async {
                self.comments = loaded
            }
        }
    }

    private func sendComment() {
        let trimmed = commentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !firebase.currentUserId.isEmpty,
              let cid = commentsRef.childByAutoId().key else { return }

        let comment = Comment(
            id: cid,
            content: trimmed,
            authorId: firebase.currentUserId,
            timestamp: Int64(Date().timeIntervalSince1970 * 1000)
        )
        commentsRef.child(cid).setValue(comment.toDictionary())
        commentInput = ""
    }
}

// MARK: - User Search Sheet (Port of UserSearchAdapter.kt)
struct UserSearchSheet: View {
    @EnvironmentObject var firebase: FirebaseManager
    @Environment(\.dismiss) private var dismiss
    let onSelectUser: (String) -> Void

    @State private var query: String = ""

    private var filteredUsers: [UserResult] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return firebase.allUsers }
        return firebase.allUsers.filter {
            $0.username.lowercased().contains(q) || $0.displayName.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                MiumoTheme.canvas.ignoresSafeArea()

                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(MiumoTheme.textSecondary)

                        TextField("Tìm kiếm người dùng @username...", text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .foregroundColor(MiumoTheme.textPrimary)

                        if !query.isEmpty {
                            Button {
                                query = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(MiumoTheme.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .background(MiumoTheme.surfacePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredUsers) { user in
                                UserRowItemView(
                                    user: user,
                                    currentUserId: firebase.currentUserId,
                                    isFollowing: firebase.myFollowingIds.contains(user.uid),
                                    onFollowToggle: { firebase.toggleFollow(targetUid: user.uid) },
                                    onRowTap: { onSelectUser(user.uid) }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .navigationTitle("Khám phá")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                        .foregroundColor(MiumoTheme.textSecondary)
                }
            }
            .onAppear {
                firebase.loadAllUsersForSearch()
            }
        }
    }
}

struct UserRowItemView: View {
    let user: UserResult
    let currentUserId: String
    let isFollowing: Bool
    let onFollowToggle: () -> Void
    let onRowTap: () -> Void

    @State private var followerCountText: String = "Đang tải..."

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onRowTap) {
                HStack(spacing: 12) {
                    MiumoAvatarView(
                        url: user.avatarUrl,
                        fallbackInitial: user.avatarInitial,
                        size: 46
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            Text(user.username)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(MiumoTheme.textPrimary)

                            if user.verified {
                                VerifiedBadgeView(size: 14)
                            }
                        }

                        Text(user.effectiveDisplayName)
                            .font(.system(size: 13))
                            .foregroundColor(MiumoTheme.textSecondary)

                        Text(followerCountText)
                            .font(.system(size: 12))
                            .foregroundColor(MiumoTheme.textMuted)
                    }
                }
            }

            Spacer()

            if user.uid != currentUserId {
                Button(action: onFollowToggle) {
                    Text(isFollowing ? "Đang theo dõi" : "Theo dõi")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isFollowing ? MiumoTheme.textSecondary : .white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            isFollowing
                                ? AnyView(MiumoTheme.surfaceElevated)
                                : AnyView(MiumoTheme.primaryGradient)
                        )
                        .clipShape(Capsule())
                }
            }
        }
        .padding(14)
        .background(MiumoTheme.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onAppear {
            Database.database(url: AppConstants.databaseURL)
                .reference()
                .child("followers")
                .child(user.uid)
                .observeSingleEvent(of: .value) { snap in
                    DispatchQueue.main.async {
                        self.followerCountText = "\(snap.childrenCount) người theo dõi"
                    }
                }
        }
    }
}

// MARK: - Video & Activity Tabs
struct VideoFeedScreen: View {
    @EnvironmentObject var firebase: FirebaseManager
    let onOpenComments: (Post) -> Void
    let onSelectAuthor: (String) -> Void

    private var mediaPosts: [Post] {
        firebase.allPosts.filter { $0.hasVideo || !$0.imageUrl.isEmpty }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 14) {
                if mediaPosts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "film.stack")
                            .font(.system(size: 44))
                            .foregroundColor(MiumoTheme.textMuted)
                        Text("Thước phim & Khoảnh khắc hình ảnh")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(MiumoTheme.textPrimary)
                        Text("Các bài đăng có hình ảnh và video sẽ xuất hiện tại đây.")
                            .font(.system(size: 13))
                            .foregroundColor(MiumoTheme.textSecondary)
                    }
                    .padding(.vertical, 80)
                } else {
                    ForEach(mediaPosts) { post in
                        PostCardView(
                            post: post,
                            onLike: { firebase.toggleLike(post) },
                            onComment: { onOpenComments(post) },
                            onRepost: { firebase.toggleRepost(post) },
                            onShare: {},
                            onMore: {},
                            onAuthorTap: { onSelectAuthor(post.authorId) }
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }
}

struct ActivityCenterScreen: View {
    @EnvironmentObject var firebase: FirebaseManager
    let onSelectAuthor: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hoạt động")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(MiumoTheme.textPrimary)
                .padding(.horizontal, 20)
                .padding(.top, 16)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(Array(firebase.myFollowerIds), id: \.self) { followerUid in
                        let user = firebase.authorCache[followerUid]
                        HStack(spacing: 12) {
                            MiumoAvatarView(
                                url: user?.avatarUrl ?? "",
                                fallbackInitial: user?.avatarInitial ?? "M",
                                size: 44
                            )

                            VStack(alignment: .leading, spacing: 3) {
                                Text(user?.username ?? "Thành viên MiuMo")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(MiumoTheme.textPrimary)
                                Text("Đã bắt đầu theo dõi bạn")
                                    .font(.system(size: 13))
                                    .foregroundColor(MiumoTheme.textSecondary)
                            }

                            Spacer()

                            Button {
                                onSelectAuthor(followerUid)
                            } label: {
                                Text("Xem")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(MiumoTheme.accentPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(MiumoTheme.surfaceElevated)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(14)
                        .background(MiumoTheme.surfacePrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .onAppear {
                            firebase.preloadAuthorIfNeeded(followerUid)
                        }
                    }

                    if firebase.myFollowerIds.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "bell.badge")
                                .font(.system(size: 40))
                                .foregroundColor(MiumoTheme.textMuted)
                            Text("Chưa có thông báo mới")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(MiumoTheme.textPrimary)
                            Text("Khi có người tương tác hoặc theo dõi bạn, thông báo sẽ hiển thị tại đây.")
                                .font(.system(size: 13))
                                .foregroundColor(MiumoTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 80)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
        }
    }
}

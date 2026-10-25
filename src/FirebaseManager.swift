import Foundation
import SwiftUI
import UIKit
import FirebaseCore
import FirebaseAuth
import FirebaseDatabase

// MARK: - Verified Status Cache (Port of VerifiedCache.kt)
final class VerifiedCache {
    static let shared = VerifiedCache()
    private var cache: [String: Bool] = [:]
    private var loading: Set<String> = []
    private var listeners: [String: [(Bool) -> Void]] = [:]

    private init() {}

    func get(_ uid: String) -> Bool? {
        return cache[uid]
    }

    func preload(_ uid: String, onLoaded: ((Bool) -> Void)? = nil) {
        if let existing = cache[uid] {
            onLoaded?(existing)
            return
        }
        if let onLoaded = onLoaded {
            listeners[uid, default: []].append(onLoaded)
        }
        guard !uid.isEmpty, !loading.contains(uid) else { return }
        loading.insert(uid)

        Database.database(url: AppConstants.databaseURL)
            .reference()
            .child("users")
            .child(uid)
            .child("verified")
            .observeSingleEvent(of: .value) { snapshot in
                let isVerified = (snapshot.value as? Bool) ?? false
                self.cache[uid] = isVerified
                self.loading.remove(uid)
                let callbacks = self.listeners.removeValue(forKey: uid) ?? []
                callbacks.forEach { $0(isVerified) }
            } withCancel: { _ in
                self.cache[uid] = false
                self.loading.remove(uid)
                let callbacks = self.listeners.removeValue(forKey: uid) ?? []
                callbacks.forEach { $0(false) }
            }
    }

    func clear() {
        cache.removeAll()
        loading.removeAll()
        listeners.removeAll()
    }
}

// MARK: - Cloudinary Unsigned Upload Service (Port of MediaManager xvo14gi5 / miumo_preset)
enum CloudinaryUploader {
    static func uploadImage(_ image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let jpegData = image.jpegData(compressionQuality: 0.88) else {
            completion(.failure(NSError(domain: "Cloudinary", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không thể nén ảnh"])))
            return
        }

        let urlString = "https://api.cloudinary.com/v1_1/\(AppConstants.cloudinaryCloudName)/image/upload"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "Cloudinary", code: -2, userInfo: [NSLocalizedDescriptionKey: "URL tải ảnh không hợp lệ"])))
            return
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        // upload_preset field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"upload_preset\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(AppConstants.cloudinaryUnsignedPreset)\r\n".data(using: .utf8)!)

        // file field
        let filename = "miumo_\(Int(Date().timeIntervalSince1970)).jpg"
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(jpegData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard
                let data = data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let secureUrl = json["secure_url"] as? String
            else {
                let message = "Tải ảnh lên thất bại"
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "Cloudinary", code: -3, userInfo: [NSLocalizedDescriptionKey: message])))
                }
                return
            }
            DispatchQueue.main.async {
                completion(.success(secureUrl))
            }
        }.resume()
    }
}

// MARK: - Central Firebase Realtime Database & Auth Store
final class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()

    @Published var currentUserId: String = ""
    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false

    @Published var allPosts: [Post] = []
    @Published var likeCounts: [String: Int] = [:]
    @Published var myLikedPostIds: Set<String> = []
    @Published var commentCounts: [String: Int] = [:]
    @Published var repostCounts: [String: Int] = [:]
    @Published var myRepostedPostIds: Set<String> = []

    @Published var myFollowerIds: Set<String> = []
    @Published var myFollowingIds: Set<String> = []
    @Published var conversations: [Conversation] = []
    @Published var hasUnreadMessages: Bool = false

    @Published var authorCache: [String: User] = [:]
    @Published var allUsers: [UserResult] = []
    @Published var toastMessage: String?

    private var dbRef: DatabaseReference {
        Database.database(url: AppConstants.databaseURL).reference()
    }

    private var isConfigured = false

    private init() {
        configureIfNeeded()
    }

    func configureIfNeeded() {
        guard !isConfigured else { return }
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        isConfigured = true

        if let user = Auth.auth().currentUser {
            self.currentUserId = user.uid
            self.isAuthenticated = true
            startRealtimeListeners()
        }
    }

    func showToast(_ message: String) {
        DispatchQueue.main.async {
            self.toastMessage = message
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                if self.toastMessage == message {
                    self.toastMessage = nil
                }
            }
        }
    }

    // MARK: - Realtime Listeners
    func startRealtimeListeners() {
        guard !currentUserId.isEmpty else { return }
        listenCurrentUserProfile()
        listenPosts()
        listenEngagement()
        listenConversations()
    }

    private func listenCurrentUserProfile() {
        dbRef.child("users").child(currentUserId).observe(.value) { [weak self] snapshot in
            guard let self = self, let dict = snapshot.value as? [String: Any] else { return }
            let user = User.fromDictionary(dict, fallbackUid: self.currentUserId)
            DispatchQueue.main.async {
                self.currentUser = user
                self.authorCache[self.currentUserId] = user
            }
        }

        dbRef.child("followers").child(currentUserId).observe(.value) { [weak self] snapshot in
            var ids = Set<String>()
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                ids.insert(child.key)
            }
            DispatchQueue.main.async {
                self?.myFollowerIds = ids
            }
        }

        dbRef.child("following").child(currentUserId).observe(.value) { [weak self] snapshot in
            var ids = Set<String>()
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                ids.insert(child.key)
            }
            DispatchQueue.main.async {
                self?.myFollowingIds = ids
            }
        }
    }

    private func listenPosts() {
        dbRef.child("posts").observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            var loaded: [Post] = []
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                guard let dict = child.value as? [String: Any] else { continue }
                let post = Post.fromDictionary(dict, fallbackId: child.key)
                if post.visibility != "private" || post.authorId == self.currentUserId {
                    loaded.append(post)
                    self.preloadAuthorIfNeeded(post.authorId)
                }
            }
            loaded.sort { $0.timestamp > $1.timestamp }
            DispatchQueue.main.async {
                self.allPosts = loaded
            }
        }
    }

    func preloadAuthorIfNeeded(_ uid: String) {
        guard !uid.isEmpty, authorCache[uid] == nil else { return }
        dbRef.child("users").child(uid).observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let dict = snapshot.value as? [String: Any] else { return }
            let user = User.fromDictionary(dict, fallbackUid: uid)
            DispatchQueue.main.async {
                self?.authorCache[uid] = user
            }
        }
    }

    private func listenEngagement() {
        dbRef.child("post_likes").observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            var counts: [String: Int] = [:]
            var liked = Set<String>()
            for postSnap in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                let postId = postSnap.key
                counts[postId] = Int(postSnap.childrenCount)
                if postSnap.hasChild(self.currentUserId) {
                    liked.insert(postId)
                }
            }
            DispatchQueue.main.async {
                self.likeCounts = counts
                self.myLikedPostIds = liked
            }
        }

        dbRef.child("post_comments").observe(.value) { [weak self] snapshot in
            var counts: [String: Int] = [:]
            for postSnap in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                counts[postSnap.key] = Int(postSnap.childrenCount)
            }
            DispatchQueue.main.async {
                self?.commentCounts = counts
            }
        }

        dbRef.child("post_reposts").observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            var counts: [String: Int] = [:]
            var reposted = Set<String>()
            for postSnap in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                let postId = postSnap.key
                counts[postId] = Int(postSnap.childrenCount)
                if postSnap.hasChild(self.currentUserId) {
                    reposted.insert(postId)
                }
            }
            DispatchQueue.main.async {
                self.repostCounts = counts
                self.myRepostedPostIds = reposted
            }
        }
    }

    private func listenConversations() {
        dbRef.child("user_conversations").child(currentUserId).observe(.value) { [weak self] snapshot in
            var list: [Conversation] = []
            var unreadFound = false
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                guard let dict = child.value as? [String: Any] else { continue }
                let conv = Conversation.fromDictionary(dict, fallbackOtherUid: child.key)
                list.append(conv)
                if conv.unreadCount > 0 {
                    unreadFound = true
                }
            }
            list.sort { $0.lastMessageTime > $1.lastMessageTime }
            DispatchQueue.main.async {
                self?.conversations = list
                self?.hasUnreadMessages = unreadFound
            }
        }
    }

    // MARK: - Auth Actions (Login via Email OR @username)
    func signIn(identifier: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("@") && trimmed.contains(".") && !trimmed.hasPrefix("@") {
            signInWithEmail(email: trimmed, password: password, completion: completion)
        } else {
            let cleanUsername = trimmed.replacingOccurrences(of: "@", with: "").lowercased()
            dbRef.child("usernames").child(cleanUsername).observeSingleEvent(of: .value) { [weak self] snap in
                guard let self = self else { return }
                guard let uid = snap.value as? String, !uid.isEmpty else {
                    completion(.failure(NSError(domain: "Auth", code: 404, userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy tài khoản @\(cleanUsername)"])))
                    return
                }
                self.dbRef.child("users").child(uid).child("email").observeSingleEvent(of: .value) { emailSnap in
                    guard let email = emailSnap.value as? String, !email.isEmpty else {
                        completion(.failure(NSError(domain: "Auth", code: 400, userInfo: [NSLocalizedDescriptionKey: "Tài khoản này chưa liên kết email"])))
                        return
                    }
                    self.signInWithEmail(email: email, password: password, completion: completion)
                }
            }
        }
    }

    private func signInWithEmail(email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let uid = result?.user.uid else { return }
            DispatchQueue.main.async {
                self?.currentUserId = uid
                self?.isAuthenticated = true
                self?.startRealtimeListeners()
                completion(.success(()))
            }
        }
    }

    func checkUsernameAvailability(_ username: String, completion: @escaping (Bool) -> Void) {
        dbRef.child("usernames").child(username.lowercased()).observeSingleEvent(of: .value) { snapshot in
            DispatchQueue.main.async {
                completion(!snapshot.exists())
            }
        }
    }

    func completeRegistration(
        state: RegistrationState,
        displayName: String,
        avatarImage: UIImage?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        Auth.auth().createUser(withEmail: state.email, password: state.password) { [weak self] result, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let self = self, let uid = result?.user.uid else { return }

            let finalizeSave: (String) -> Void = { avatarUrl in
                let now = Int64(Date().timeIntervalSince1970 * 1000)
                let finalDisplay = displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? state.username : displayName
                let newUser = User(
                    uid: uid,
                    username: state.username,
                    displayName: finalDisplay,
                    bio: "",
                    email: state.email,
                    phone: state.phone,
                    avatarUrl: avatarUrl,
                    verified: false,
                    createdAt: now,
                    usernameChangedAt: now,
                    displayNameChangedAt: now
                )

                self.dbRef.child("users").child(uid).setValue(newUser.toDictionary()) { err, _ in
                    if let err = err {
                        DispatchQueue.main.async { completion(.failure(err)) }
                        return
                    }
                    self.dbRef.child("usernames").child(state.username).setValue(uid)
                    DispatchQueue.main.async {
                        state.clear()
                        self.currentUserId = uid
                        self.currentUser = newUser
                        self.isAuthenticated = true
                        self.startRealtimeListeners()
                        completion(.success(()))
                    }
                }
            }

            if let image = avatarImage {
                CloudinaryUploader.uploadImage(image) { uploadResult in
                    switch uploadResult {
                    case .success(let url):
                        finalizeSave(url)
                    case .failure:
                        finalizeSave("")
                    }
                }
            } else {
                finalizeSave("")
            }
        }
    }

    func signOut() {
        try? Auth.auth().signOut()
        currentUserId = ""
        currentUser = nil
        isAuthenticated = false
    }

    // MARK: - Post & Engagement Operations
    func createPost(content: String, visibility: String, image: UIImage?, completion: @escaping (Bool) -> Void) {
        guard !currentUserId.isEmpty, let postId = dbRef.child("posts").childByAutoId().key else {
            completion(false)
            return
        }

        let savePostRecord: (String) -> Void = { [weak self] imageUrl in
            guard let self = self else { return }
            let post = Post(
                id: postId,
                authorId: self.currentUserId,
                content: content,
                imageUrl: imageUrl,
                timestamp: Int64(Date().timeIntervalSince1970 * 1000),
                visibility: visibility
            )
            self.dbRef.child("posts").child(postId).setValue(post.toDictionary()) { error, _ in
                DispatchQueue.main.async {
                    if error == nil {
                        self.showToast("Đã đăng bài viết")
                        completion(true)
                    } else {
                        self.showToast("Lỗi khi đăng bài")
                        completion(false)
                    }
                }
            }
        }

        if let image = image {
            CloudinaryUploader.uploadImage(image) { [weak self] result in
                switch result {
                case .success(let url):
                    savePostRecord(url)
                case .failure(let err):
                    self?.showToast("Lỗi tải ảnh: \(err.localizedDescription)")
                    completion(false)
                }
            }
        } else {
            savePostRecord("")
        }
    }

    func deletePost(_ post: Post) {
        guard post.authorId == currentUserId else { return }
        dbRef.child("posts").child(post.id).removeValue { [weak self] _, _ in
            self?.showToast("Đã xóa bài viết")
        }
    }

    func toggleLike(_ post: Post) {
        guard !currentUserId.isEmpty else { return }
        let ref = dbRef.child("post_likes").child(post.id).child(currentUserId)
        if myLikedPostIds.contains(post.id) {
            myLikedPostIds.remove(post.id)
            likeCounts[post.id] = max(0, (likeCounts[post.id] ?? 1) - 1)
            ref.removeValue()
        } else {
            myLikedPostIds.insert(post.id)
            likeCounts[post.id] = (likeCounts[post.id] ?? 0) + 1
            ref.setValue(true)
        }
    }

    func toggleRepost(_ post: Post) {
        guard !currentUserId.isEmpty else { return }
        let ref = dbRef.child("post_reposts").child(post.id).child(currentUserId)
        if myRepostedPostIds.contains(post.id) {
            myRepostedPostIds.remove(post.id)
            repostCounts[post.id] = max(0, (repostCounts[post.id] ?? 1) - 1)
            ref.removeValue()
        } else {
            myRepostedPostIds.insert(post.id)
            repostCounts[post.id] = (repostCounts[post.id] ?? 0) + 1
            ref.setValue(Int64(Date().timeIntervalSince1970 * 1000))
        }
    }

    // MARK: - Follow & Profile Operations
    func toggleFollow(targetUid: String) {
        guard !currentUserId.isEmpty, targetUid != currentUserId else { return }
        let followingRef = dbRef.child("following").child(currentUserId).child(targetUid)
        let followerRef = dbRef.child("followers").child(targetUid).child(currentUserId)

        if myFollowingIds.contains(targetUid) {
            myFollowingIds.remove(targetUid)
            followingRef.removeValue()
            followerRef.removeValue()
        } else {
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            myFollowingIds.insert(targetUid)
            followingRef.setValue(now)
            followerRef.setValue(now)
        }
    }

    func updateProfile(displayName: String, username: String, bio: String, completion: @escaping (Bool) -> Void) {
        guard !currentUserId.isEmpty else { return }
        let updates: [String: Any] = [
            "displayName": displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            "username": username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            "bio": bio.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        dbRef.child("users").child(currentUserId).updateChildValues(updates) { [weak self] error, _ in
            DispatchQueue.main.async {
                if error == nil {
                    self?.showToast("Đã cập nhật trang cá nhân")
                    completion(true)
                } else {
                    self?.showToast("Cập nhật thất bại")
                    completion(false)
                }
            }
        }
    }

    func updateAvatarImage(_ croppedImage: UIImage, completion: @escaping (Bool) -> Void) {
        guard !currentUserId.isEmpty else {
            completion(false)
            return
        }
        CloudinaryUploader.uploadImage(croppedImage) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let avatarUrl):
                self.dbRef.child("users").child(self.currentUserId).child("avatarUrl").setValue(avatarUrl) { error, _ in
                    DispatchQueue.main.async {
                        if error == nil {
                            self.showToast("Đã lưu ảnh đại diện")
                            completion(true)
                        } else {
                            self.showToast("Lỗi lưu ảnh đại diện")
                            completion(false)
                        }
                    }
                }
            case .failure(let err):
                self.showToast("Tải ảnh lên thất bại: \(err.localizedDescription)")
                completion(false)
            }
        }
    }

    func loadAllUsersForSearch() {
        dbRef.child("users").observeSingleEvent(of: .value) { [weak self] snapshot in
            var results: [UserResult] = []
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                guard let dict = child.value as? [String: Any] else { continue }
                let user = User.fromDictionary(dict, fallbackUid: child.key)
                results.append(
                    UserResult(
                        uid: user.uid,
                        username: user.username,
                        displayName: user.displayName,
                        verified: user.verified,
                        avatarUrl: user.avatarUrl
                    )
                )
            }
            DispatchQueue.main.async {
                self?.allUsers = results
            }
        }
    }
}

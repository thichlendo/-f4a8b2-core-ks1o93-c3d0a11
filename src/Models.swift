import Foundation
import SwiftUI

// MARK: - App Configuration Constants
enum AppConstants {
    static let appName = "MioMo"
    static let cloudinaryCloudName = "xvo14gi5"
    static let cloudinaryUnsignedPreset = "miumo_preset"
    static let oneSignalAppId = "dbaf3a86-b7d2-4fc6-b7d1-26045174f48c"
    static let databaseURL = "https://miumo-61696-default-rtdb.asia-southeast1.firebasedatabase.app"
}

// MARK: - Navigation & Filter Enums
enum MiumoTab: String, CaseIterable {
    case home = "Bảng tin"
    case video = "Thước phim"
    case activity = "Hoạt động"
    case profile = "Hồ sơ"
}

enum ProfileFilter: String, CaseIterable {
    case posts = "Bài viết"
    case videos = "Thước phim"
    case reposts = "Đăng lại"
    case tagged = "Gắn thẻ"
}

enum FollowListMode: String, CaseIterable {
    case followers = "followers"
    case following = "following"
}

enum RecoveryMode: String, CaseIterable {
    case email = "Email"
    case phone = "Số điện thoại"
}

// MARK: - User Model
struct User: Identifiable, Codable, Equatable {
    var id: String { uid }
    var uid: String = ""
    var username: String = ""
    var displayName: String = ""
    var bio: String = ""
    var email: String = ""
    var phone: String = ""
    var avatarUrl: String = ""
    var verified: Bool = false
    var createdAt: Int64 = 0
    var usernameChangedAt: Int64 = 0
    var displayNameChangedAt: Int64 = 0

    var effectiveDisplayName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? username : displayName
    }

    var avatarInitial: String {
        let base = effectiveDisplayName.isEmpty ? "M" : effectiveDisplayName
        return String(base.prefix(1)).uppercased()
    }

    func toDictionary() -> [String: Any] {
        return [
            "uid": uid,
            "username": username,
            "displayName": displayName,
            "bio": bio,
            "email": email,
            "phone": phone,
            "avatarUrl": avatarUrl,
            "verified": verified,
            "createdAt": createdAt,
            "usernameChangedAt": usernameChangedAt,
            "displayNameChangedAt": displayNameChangedAt
        ]
    }

    static func fromDictionary(_ dict: [String: Any], fallbackUid: String = "") -> User {
        return User(
            uid: (dict["uid"] as? String) ?? fallbackUid,
            username: (dict["username"] as? String) ?? "",
            displayName: (dict["displayName"] as? String) ?? "",
            bio: (dict["bio"] as? String) ?? "",
            email: (dict["email"] as? String) ?? "",
            phone: (dict["phone"] as? String) ?? "",
            avatarUrl: (dict["avatarUrl"] as? String) ?? "",
            verified: (dict["verified"] as? Bool) ?? false,
            createdAt: (dict["createdAt"] as? Int64) ?? Int64(dict["createdAt"] as? Int ?? 0),
            usernameChangedAt: (dict["usernameChangedAt"] as? Int64) ?? Int64(dict["usernameChangedAt"] as? Int ?? 0),
            displayNameChangedAt: (dict["displayNameChangedAt"] as? Int64) ?? Int64(dict["displayNameChangedAt"] as? Int ?? 0)
        )
    }
}

// MARK: - User Search Result
struct UserResult: Identifiable, Equatable {
    var id: String { uid }
    var uid: String
    var username: String
    var displayName: String
    var verified: Bool
    var avatarUrl: String

    var effectiveDisplayName: String {
        displayName.isEmpty ? "@\(username)" : displayName
    }

    var avatarInitial: String {
        let name = displayName.isEmpty ? username : displayName
        return String((name.first ?? "M")).uppercased()
    }
}

// MARK: - Post Model
struct Post: Identifiable, Codable, Equatable {
    var id: String = ""
    var authorId: String = ""
    var content: String = ""
    var imageUrl: String = ""
    var timestamp: Int64 = 0
    var visibility: String = "public"
    var hasVideo: Bool = false
    var taggedUserIds: [String] = []

    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "authorId": authorId,
            "content": content,
            "imageUrl": imageUrl,
            "timestamp": timestamp,
            "visibility": visibility,
            "hasVideo": hasVideo,
            "taggedUserIds": taggedUserIds
        ]
    }

    static func fromDictionary(_ dict: [String: Any], fallbackId: String = "") -> Post {
        return Post(
            id: (dict["id"] as? String) ?? fallbackId,
            authorId: (dict["authorId"] as? String) ?? "",
            content: (dict["content"] as? String) ?? "",
            imageUrl: (dict["imageUrl"] as? String) ?? "",
            timestamp: (dict["timestamp"] as? Int64) ?? Int64(dict["timestamp"] as? Int ?? 0),
            visibility: (dict["visibility"] as? String) ?? "public",
            hasVideo: (dict["hasVideo"] as? Bool) ?? false,
            taggedUserIds: (dict["taggedUserIds"] as? [String]) ?? []
        )
    }
}

// MARK: - Comment Model
struct Comment: Identifiable, Codable, Equatable {
    var id: String = ""
    var content: String = ""
    var authorId: String = ""
    var timestamp: Int64 = 0

    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "content": content,
            "authorId": authorId,
            "timestamp": timestamp
        ]
    }

    static func fromDictionary(_ dict: [String: Any], fallbackId: String = "") -> Comment {
        return Comment(
            id: (dict["id"] as? String) ?? fallbackId,
            content: (dict["content"] as? String) ?? "",
            authorId: (dict["authorId"] as? String) ?? "",
            timestamp: (dict["timestamp"] as? Int64) ?? Int64(dict["timestamp"] as? Int ?? 0)
        )
    }
}

// MARK: - Direct Message Model
struct Message: Identifiable, Codable, Equatable {
    var id: String = ""
    var senderId: String = ""
    var content: String = ""
    var timestamp: Int64 = 0

    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "senderId": senderId,
            "content": content,
            "timestamp": timestamp
        ]
    }

    static func fromDictionary(_ dict: [String: Any], fallbackId: String = "") -> Message {
        return Message(
            id: (dict["id"] as? String) ?? fallbackId,
            senderId: (dict["senderId"] as? String) ?? "",
            content: (dict["content"] as? String) ?? "",
            timestamp: (dict["timestamp"] as? Int64) ?? Int64(dict["timestamp"] as? Int ?? 0)
        )
    }
}

// MARK: - Conversation Summary Model
struct Conversation: Identifiable, Codable, Equatable {
    var id: String { otherUid }
    var otherUid: String = ""
    var otherUsername: String = ""
    var otherDisplayName: String = ""
    var otherAvatarUrl: String = ""
    var lastMessage: String = ""
    var lastMessageTime: Int64 = 0
    var unreadCount: Int = 0

    var effectiveName: String {
        otherDisplayName.isEmpty ? otherUsername : otherDisplayName
    }

    var avatarInitial: String {
        let base = effectiveName.isEmpty ? "M" : effectiveName
        return String(base.prefix(1)).uppercased()
    }

    func toDictionary() -> [String: Any] {
        return [
            "otherUid": otherUid,
            "otherUsername": otherUsername,
            "otherDisplayName": otherDisplayName,
            "otherAvatarUrl": otherAvatarUrl,
            "lastMessage": lastMessage,
            "lastMessageTime": lastMessageTime,
            "unreadCount": unreadCount
        ]
    }

    static func fromDictionary(_ dict: [String: Any], fallbackOtherUid: String = "") -> Conversation {
        return Conversation(
            otherUid: (dict["otherUid"] as? String) ?? fallbackOtherUid,
            otherUsername: (dict["otherUsername"] as? String) ?? "",
            otherDisplayName: (dict["otherDisplayName"] as? String) ?? "",
            otherAvatarUrl: (dict["otherAvatarUrl"] as? String) ?? "",
            lastMessage: (dict["lastMessage"] as? String) ?? "",
            lastMessageTime: (dict["lastMessageTime"] as? Int64) ?? Int64(dict["lastMessageTime"] as? Int ?? 0),
            unreadCount: (dict["unreadCount"] as? Int) ?? 0
        )
    }
}

// MARK: - Country & Phone Helper
struct Country: Identifiable, Equatable {
    var id: String { dialCode }
    let flag: String
    let name: String
    let dialCode: String
}

enum PhoneInputHelper {
    static let countries: [Country] = [
        Country(flag: "🇻🇳", name: "Việt Nam", dialCode: "+84"),
        Country(flag: "🇺🇸", name: "Hoa Kỳ", dialCode: "+1"),
        Country(flag: "🇯🇵", name: "Nhật Bản", dialCode: "+81"),
        Country(flag: "🇰🇷", name: "Hàn Quốc", dialCode: "+82")
    ]

    static func toE164(dialCode: String, rawNumber: String) -> String {
        let trimmed = rawNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutLeadingZeros = String(trimmed.drop(while: { $0 == "0" }))
        let digits = withoutLeadingZeros.filter { $0.isNumber }
        return dialCode + digits
    }

    static func isValidVietnamNumber(_ rawNumber: String) -> Bool {
        let trimmed = rawNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutLeadingZeros = String(trimmed.drop(while: { $0 == "0" }))
        let digits = withoutLeadingZeros.filter { $0.isNumber }
        return (8...10).contains(digits.count)
    }
}

// MARK: - Registration State Container
final class RegistrationState: ObservableObject {
    @Published var phone: String = ""
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var username: String = ""
    @Published var isSocialSignup: Bool = false
    @Published var socialProvider: String = ""

    func clear() {
        phone = ""
        email = ""
        password = ""
        username = ""
        isSocialSignup = false
        socialProvider = ""
    }
}

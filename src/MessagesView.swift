import SwiftUI
import FirebaseDatabase

// MARK: - Direct Messages List & Real-Time Chat (Port of MessagesListActivity.kt & ChatActivity.kt)
struct MessagesListScreen: View {
    @EnvironmentObject var firebase: FirebaseManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedOtherUid: String?

    var body: some View {
        NavigationView {
            ZStack {
                MiumoTheme.canvas.ignoresSafeArea()

                if firebase.conversations.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "bubble.left.and.exclamationmark.bubble.right")
                            .font(.system(size: 44))
                            .foregroundColor(MiumoTheme.textMuted)
                        Text("Chưa có cuộc trò chuyện nào")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(MiumoTheme.textPrimary)
                        Text("Truy cập hồ sơ của bạn bè và nhấn Nhắn tin để bắt đầu trò chuyện.")
                            .font(.system(size: 13))
                            .foregroundColor(MiumoTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 36)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(firebase.conversations) { conv in
                                Button {
                                    selectedOtherUid = conv.otherUid
                                } label: {
                                    HStack(spacing: 14) {
                                        MiumoAvatarView(
                                            url: conv.otherAvatarUrl,
                                            fallbackInitial: conv.avatarInitial,
                                            size: 52,
                                            showOnlineRing: conv.unreadCount > 0
                                        )

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(conv.effectiveName)
                                                .font(.system(size: 16, weight: conv.unreadCount > 0 ? .bold : .semibold))
                                                .foregroundColor(MiumoTheme.textPrimary)

                                            Text(conv.lastMessage)
                                                .font(.system(size: 14))
                                                .foregroundColor(conv.unreadCount > 0 ? MiumoTheme.textPrimary : MiumoTheme.textSecondary)
                                                .lineLimit(1)
                                        }

                                        Spacer()

                                        VStack(alignment: .trailing, spacing: 6) {
                                            Text(TimeFormatterHelper.clockTime(from: conv.lastMessageTime))
                                                .font(.system(size: 12))
                                                .foregroundColor(MiumoTheme.textMuted)

                                            if conv.unreadCount > 0 {
                                                Circle()
                                                    .fill(MiumoTheme.accentPrimary)
                                                    .frame(width: 10, height: 10)
                                            }
                                        }
                                    }
                                    .padding(14)
                                    .background(MiumoTheme.surfacePrimary)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Tin nhắn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                        .foregroundColor(MiumoTheme.textSecondary)
                }
            }
            .sheet(
                isPresented: Binding(
                    get: { selectedOtherUid != nil },
                    set: { if !$0 { selectedOtherUid = nil } }
                )
            ) {
                if let uid = selectedOtherUid {
                    ChatScreen(otherUid: uid)
                        .environmentObject(firebase)
                }
            }
        }
    }
}

// MARK: - 1-on-1 Chat View (Port of ChatActivity.kt & ChatAdapter.kt)
struct ChatScreen: View {
    @EnvironmentObject var firebase: FirebaseManager
    @Environment(\.dismiss) private var dismiss
    let otherUid: String

    @State private var otherUser: User?
    @State private var messages: [Message] = []
    @State private var messageText: String = ""

    private var chatId: String {
        let myId = firebase.currentUserId
        return myId < otherUid ? "\(myId)_\(otherUid)" : "\(otherUid)_\(myId)"
    }

    private var messagesRef: DatabaseReference {
        Database.database(url: AppConstants.databaseURL).reference().child("messages").child(chatId)
    }

    var body: some View {
        NavigationView {
            ZStack {
                MiumoTheme.canvas.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Chat Messages ScrollView
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(messages) { msg in
                                    let isSentByMe = msg.senderId == firebase.currentUserId
                                    HStack {
                                        if isSentByMe { Spacer(minLength: 56) }

                                        VStack(alignment: isSentByMe ? .trailing : .leading, spacing: 4) {
                                            Text(msg.content)
                                                .font(.system(size: 15))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 10)
                                                .background(
                                                    isSentByMe
                                                        ? AnyView(MiumoTheme.primaryGradient)
                                                        : AnyView(MiumoTheme.surfaceElevated)
                                                )
                                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                                            Text(TimeFormatterHelper.clockTime(from: msg.timestamp))
                                                .font(.system(size: 11))
                                                .foregroundColor(MiumoTheme.textMuted)
                                        }

                                        if !isSentByMe { Spacer(minLength: 56) }
                                    }
                                    .id(msg.id)
                                }
                            }
                            .padding(16)
                        }
                        .onChange(of: messages.count) { _ in
                            if let lastId = messages.last?.id {
                                withAnimation {
                                    proxy.scrollTo(lastId, anchor: .bottom)
                                }
                            }
                        }
                    }

                    // Composer Input Bar
                    HStack(spacing: 10) {
                        TextField("Nhắn tin...", text: $messageText)
                            .foregroundColor(MiumoTheme.textPrimary)
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                            .background(MiumoTheme.surfaceElevated)
                            .clipShape(Capsule())

                        Button(action: sendMessage) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(MiumoTheme.primaryGradient)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(MiumoTheme.surfacePrimary)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") { dismiss() }
                        .foregroundColor(MiumoTheme.textSecondary)
                }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        MiumoAvatarView(
                            url: otherUser?.avatarUrl ?? "",
                            fallbackInitial: otherUser?.avatarInitial ?? "M",
                            size: 30
                        )
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 4) {
                                Text(otherUser?.effectiveDisplayName ?? "Trò chuyện")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(MiumoTheme.textPrimary)
                                if otherUser?.verified == true {
                                    VerifiedBadgeView(size: 12)
                                }
                            }
                            if let uname = otherUser?.username, !uname.isEmpty {
                                Text("@\(uname)")
                                    .font(.system(size: 11))
                                    .foregroundColor(MiumoTheme.textSecondary)
                            }
                        }
                    }
                }
            }
            .onAppear {
                loadHeaderUser()
                listenMessages()
                markConversationAsRead()
            }
        }
    }

    private func loadHeaderUser() {
        Database.database(url: AppConstants.databaseURL)
            .reference()
            .child("users")
            .child(otherUid)
            .observeSingleEvent(of: .value) { snapshot in
                guard let dict = snapshot.value as? [String: Any] else { return }
                let user = User.fromDictionary(dict, fallbackUid: otherUid)
                DispatchQueue.main.async {
                    self.otherUser = user
                }
            }
    }

    private func listenMessages() {
        messagesRef.observe(.value) { snapshot in
            var loaded: [Message] = []
            for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                guard let dict = child.value as? [String: Any] else { continue }
                loaded.append(Message.fromDictionary(dict, fallbackId: child.key))
            }
            loaded.sort { $0.timestamp < $1.timestamp }
            DispatchQueue.main.async {
                self.messages = loaded
                self.markConversationAsRead()
            }
        }
    }

    private func markConversationAsRead() {
        guard !firebase.currentUserId.isEmpty else { return }
        Database.database(url: AppConstants.databaseURL)
            .reference()
            .child("user_conversations")
            .child(firebase.currentUserId)
            .child(otherUid)
            .child("unreadCount")
            .setValue(0)
    }

    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !firebase.currentUserId.isEmpty,
              let msgId = messagesRef.childByAutoId().key else { return }

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let msg = Message(
            id: msgId,
            senderId: firebase.currentUserId,
            content: trimmed,
            timestamp: now
        )
        messageText = ""
        messagesRef.child(msgId).setValue(msg.toDictionary())

        let convRef = Database.database(url: AppConstants.databaseURL).reference().child("user_conversations")
        let myConv = Conversation(
            otherUid: otherUid,
            otherUsername: otherUser?.username ?? "",
            otherDisplayName: otherUser?.displayName ?? "",
            otherAvatarUrl: otherUser?.avatarUrl ?? "",
            lastMessage: trimmed,
            lastMessageTime: now,
            unreadCount: 0
        )
        convRef.child(firebase.currentUserId).child(otherUid).setValue(myConv.toDictionary())

        let me = firebase.currentUser
        convRef.child(otherUid).child(firebase.currentUserId).child("unreadCount").observeSingleEvent(of: .value) { snap in
            let currentUnread = (snap.value as? Int) ?? 0
            let theirConv = Conversation(
                otherUid: self.firebase.currentUserId,
                otherUsername: me?.username ?? "",
                otherDisplayName: me?.displayName ?? "",
                otherAvatarUrl: me?.avatarUrl ?? "",
                lastMessage: trimmed,
                lastMessageTime: now,
                unreadCount: currentUnread + 1
            )
            convRef.child(self.otherUid).child(self.firebase.currentUserId).setValue(theirConv.toDictionary())
        }
    }
}

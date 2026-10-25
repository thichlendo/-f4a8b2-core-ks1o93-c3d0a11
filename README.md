# MioMo — Native iOS (SwiftUI)

Ứng dụng mạng xã hội **MioMo** phiên bản Native iOS được xây dựng hoàn toàn bằng **Swift & SwiftUI** kết hợp **Firebase Auth**, **Firebase Realtime Database** và **Cloudinary**.

## Cấu trúc mã nguồn iOS (`src/`)

- `src/MiumoApp.swift` — Điểm khởi chạy `@main`, quản lý luồng `SplashView` → `AuthFlowView` → `MainTabView` và thông báo nổi toàn cục.
- `src/Models.swift` — Toàn bộ cấu trúc dữ liệu (`User`, `Post`, `Comment`, `Message`, `Conversation`, `UserResult`, `RegistrationState`, `PhoneInputHelper`).
- `src/Theme.swift` — Hệ thống thiết kế chuẩn Apple Human Interface Guidelines (Liquid Obsidian & Indigo Glass), `MiumoAvatarView` (memory cache), `PasswordMascotView` (mèo che mắt khi nhập mật khẩu), và `CircleCropAvatarView` (cắt ảnh đại diện tròn đa điểm).
- `src/FirebaseManager.swift` — Xử lý xác thực Firebase Auth (đăng nhập bằng Email hoặc `@username`), Realtime Database, `VerifiedCache`, và upload ảnh trực tiếp lên Cloudinary (`xvo14gi5` / `miumo_preset`).
- `src/SplashView.swift` — Màn hình chào mừng với hiệu ứng linh vật mèo vẫy tay.
- `src/AuthView.swift` — Luồng Đăng nhập, Đăng ký 3 bước (SĐT +84, kiểm tra `@username` thời gian thực kèm gợi ý, chọn ảnh đại diện), Quên mật khẩu (Email / OTP SĐT) và Đặt lại mật khẩu mới.
- `src/FeedView.swift` — Bảng tin chính, tạo bài viết mới (kèm ảnh & chế độ Công khai/Riêng tư), bình luận, thả tim, đăng lại, tìm kiếm người dùng, Thước phim & Hoạt động.
- `src/MessagesView.swift` — Danh sách hội thoại thời gian thực và màn hình nhắn tin 1-1 (`ChatScreen`).
- `src/ProfileView.swift` — Trang cá nhân chính chủ, trang cá nhân người dùng khác, danh sách Người theo dõi / Đang theo dõi, chỉnh sửa hồ sơ và cài đặt.
- `src/GoogleService-Info.plist` — Cấu hình kết nối Firebase iOS.

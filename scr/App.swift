import SwiftUI

@main
struct MiumoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Miumo iOS")
                .font(.largeTitle)
                .bold()
            Text("Ứng dụng chạy thành công!")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

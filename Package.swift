// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Miumo",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .executable(
            name: "Miumo",
            targets: ["Miumo"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.20.0")
    ],
    targets: [
        .executableTarget(
            name: "Miumo",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseDatabase", package: "firebase-ios-sdk")
            ],
            path: "src"
        )
    ]
)

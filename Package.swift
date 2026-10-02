// swift-tools-version:5.9
// Chỉ dùng để chạy nhanh test của bộ xử lý gõ: `xcrun swift test`.
// App được build bằng GTV.xcodeproj (sinh từ project.yml).
import PackageDescription

let package = Package(
    name: "GTV",
    platforms: [.macOS(.v12)],
    targets: [
        .target(name: "VietEngine"),
        .testTarget(name: "VietEngineTests", dependencies: ["VietEngine"]),
    ]
)

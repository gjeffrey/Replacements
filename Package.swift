// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "Replacements",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "Replacements", targets: ["ReplacementsApp"]),
               .executable(name: "ReplacementProbe", targets: ["ReplacementProbe"])],
    targets: [
        .target(name: "ReplacementCore"),
        .target(name: "KeyboardBridge", publicHeadersPath: "include", linkerSettings: [.linkedFramework("Foundation"), .linkedLibrary("sqlite3")]),
        .target(name: "ReplacementNative", dependencies: ["ReplacementCore", "KeyboardBridge"]),
        .executableTarget(name: "ReplacementsApp", dependencies: ["ReplacementCore", "ReplacementNative"]),
        .executableTarget(name: "ReplacementProbe", dependencies: ["ReplacementCore", "ReplacementNative"]),
        .testTarget(name: "ReplacementCoreTests", dependencies: ["ReplacementCore"]),
        .testTarget(name: "ReplacementNativeTests", dependencies: ["KeyboardBridge"])
    ], swiftLanguageModes: [.v5]
)

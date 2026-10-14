// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "Replacements",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "Replacements", targets: ["ReplacementsApp"]),
               .executable(name: "ReplacementProbe", targets: ["ReplacementProbe"])],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")],
    targets: [
        .target(name: "ReplacementCore"),
        .target(name: "KeyboardBridge", publicHeadersPath: "include", linkerSettings: [.linkedFramework("Foundation"), .linkedLibrary("sqlite3")]),
        .target(name: "ReplacementNative", dependencies: ["ReplacementCore", "KeyboardBridge"]),
        .executableTarget(name: "ReplacementsApp", dependencies: ["ReplacementCore", "ReplacementNative", .product(name: "Sparkle", package: "Sparkle")], linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .executableTarget(name: "ReplacementProbe", dependencies: ["ReplacementCore", "ReplacementNative"]),
        .testTarget(name: "ReplacementCoreTests", dependencies: ["ReplacementCore"]),
        .testTarget(name: "ReplacementNativeTests", dependencies: ["KeyboardBridge", "ReplacementNative", "ReplacementCore"]),
        .testTarget(name: "ReplacementsAppTests", dependencies: ["ReplacementsApp", "ReplacementCore"])
    ], swiftLanguageModes: [.v5]
)

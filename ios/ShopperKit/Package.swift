// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ShopperKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "ShopperKit", targets: ["ShopperKit"])],
    targets: [
        .target(name: "ShopperKit"),
        .executableTarget(name: "ocrdump", dependencies: ["ShopperKit"]),
        .testTarget(
            name: "ShopperKitTests",
            dependencies: ["ShopperKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)

// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "VPetApple",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "PetCore", targets: ["PetCore"]), .library(name: "PetRendering", targets: ["PetRendering"])],
    targets: [
        .target(name: "PetCore"),
        .target(name: "PetRendering", dependencies: ["PetCore"]),
        .testTarget(name: "PetCoreTests", dependencies: ["PetCore"]),
        .testTarget(name: "PetRenderingTests", dependencies: ["PetRendering"])
    ]
)

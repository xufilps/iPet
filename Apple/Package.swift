// swift-tools-version: 6.0
// iPet: native Swift adaptation of VPet; see NOTICE and LICENSE.
// SPDX-License-Identifier: Apache-2.0
import PackageDescription
let package = Package(
    name: "iPet",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "PetCore", targets: ["PetCore"]), .library(name: "PetRendering", targets: ["PetRendering"])],
    targets: [
        .target(name: "PetCore"),
        .target(name: "PetRendering", dependencies: ["PetCore"]),
        .testTarget(name: "PetCoreTests", dependencies: ["PetCore"]),
        .testTarget(name: "PetRenderingTests", dependencies: ["PetRendering"])
    ]
)

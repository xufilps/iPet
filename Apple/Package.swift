// swift-tools-version: 6.0
// iPet: native Swift adaptation of VPet; see NOTICE and LICENSE.
// SPDX-License-Identifier: Apache-2.0
import PackageDescription
let package = Package(
    name: "iPet",
    platforms: [.macOS("26.0"), .iOS("26.0")],
    products: [.library(name: "PetMacInput", targets: ["PetMacInput"]), .library(name: "PetCore", targets: ["PetCore"]), .library(name: "PetRendering", targets: ["PetRendering"])],
    targets: [
        .target(name: "PetCore"),
        .target(name: "PetMacInput", dependencies: ["PetCore"]),
        .testTarget(name: "PetMacInputTests", dependencies: ["PetMacInput", "PetCore"]),
        .target(name: "PetRendering", dependencies: ["PetCore"]),
        .testTarget(name: "PetCoreTests", dependencies: ["PetCore"]),
        .testTarget(name: "PetRenderingTests", dependencies: ["PetRendering"])
    ]
)

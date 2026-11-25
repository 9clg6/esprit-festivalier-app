// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EFKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "EFDomain", targets: ["EFDomain"]),
        .library(name: "EFData", targets: ["EFData"]),
        .library(name: "EFDesign", targets: ["EFDesign"])
    ],
    targets: [
        .target(name: "EFDomain"),
        .target(name: "EFData", dependencies: ["EFDomain"], resources: [.process("Resources")]),
        .target(name: "EFDesign", resources: [.copy("Resources/Fonts")]),
        .testTarget(name: "EFDomainTests", dependencies: ["EFDomain"]),
        .testTarget(name: "EFDataTests", dependencies: ["EFData", "EFDomain"]),
        .testTarget(name: "EFDesignTests", dependencies: ["EFDesign"])
    ]
)

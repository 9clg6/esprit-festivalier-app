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
        .target(name: "EFData", dependencies: ["EFDomain"]),
        .target(name: "EFDesign")
    ]
)

// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Luban",
    platforms: [.iOS(.v13), .macOS(.v10_15)],
    products: [
        .library(name: "Luban", targets: ["Luban"])
    ],
    targets: [
        .target(name: "Luban")
    ]
)

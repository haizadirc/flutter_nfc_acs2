// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "flutter_nfc_acs2",
    platforms: [
        .iOS("12.0")
    ],
    products: [
        .library(
            name: "flutter_nfc_acs2",
            targets: ["flutter_nfc_acs2"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "flutter_nfc_acs2",
            dependencies: [],
            path: "Classes",
            publicHeadersPath: "."
        )
    ]
)

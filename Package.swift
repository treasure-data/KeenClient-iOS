// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "KeenClientTD",
    platforms: [
        .iOS(.v12),
        .tvOS(.v12),
    ],
    products: [
        .library(
            name: "KeenClientTD",
            targets: ["KeenClientTD"]),
    ],
    dependencies: [
    ],
    targets: [
      .target(
            name: "KeenClientTD",
            dependencies: [],
            path: ".",
            exclude: [
                "KeenClient.xcodeproj/",
                "KeenClientExample/",
                "KeenClientTD.podspec",
                "KeenClientTests",
                "Library/Headers/OCMock/",
                "Library/libOCMock.a",
                "Makefile",
                "README.md",
                "docs",
                "generate_docs.sh",
            ],
            sources: [
                "KeenClient/",
                "Library/sqlite-amalgamation/",
            ],
            resources: [.copy("PrivacyInfo.xcprivacy")],
            publicHeadersPath: "KeenClient",
            cxxSettings: [
                .headerSearchPath("Library/sqlite-amalgamation"),
                .headerSearchPath("KeenClient"),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx1z
)

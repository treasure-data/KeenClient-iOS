// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "KeenClientTD",
    platforms: [
        .macOS(.v10_10),
        .iOS(.v11),
        .tvOS(.v9),
        .watchOS(.v2)
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
            dependencies: [
            ],
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
            publicHeadersPath: "KeenClient",
            cxxSettings: [
                .headerSearchPath("Library/sqlite-amalgamation"),
                .headerSearchPath("KeenClient"),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx1z
)

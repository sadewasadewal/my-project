// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ArtworkEditor",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "ArtworkEditor",
            targets: ["ArtworkEditor"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ArtworkEditor",
            dependencies: [],
            path: "Sources",
            exclude: ["App/ArtworkEditorApp.swift"]
        )
    ]
)

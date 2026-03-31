// swift-tools-version: 5.10

import PackageDescription

let package = Package(
  name: "ancla-core-package",
  products: [
    .library(
      name: "AnclaCore",
      targets: ["AnclaCore"]
    )
  ],
  targets: [
    .target(
      name: "AnclaCore",
      path: "ancla-shared",
      exclude: [
        "ancla-activity-selection.swift",
        "ancla-services.swift",
        "ancla-store.swift"
      ],
      sources: [
        "ancla-core.swift",
        "ancla-dependencies.swift",
        "ancla-models.swift"
      ]
    ),
    .testTarget(
      name: "AnclaCoreTests",
      dependencies: ["AnclaCore"],
      path: "ancla-core-tests"
    )
  ]
)

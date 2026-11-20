// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "cupertino_bottom_nav_bar",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(name: "cupertino-bottom-nav-bar", targets: ["cupertino_bottom_nav_bar"])
  ],
  dependencies: [
    .package(name: "FlutterFramework", path: "../FlutterFramework")
  ],
  targets: [
    .target(
      name: "cupertino_bottom_nav_bar",
      dependencies: [
        .product(name: "FlutterFramework", package: "FlutterFramework")
      ],
      resources: [
        .process("PrivacyInfo.xcprivacy")
      ]
    )
  ]
)

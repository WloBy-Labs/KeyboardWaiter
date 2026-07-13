// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "keyboard_waiter",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "KeyboardWaiterCore",
            targets: ["KeyboardWaiterCore"]),
        .executable(
            name: "KeyboardWaiter",
            targets: ["KeyboardWaiterApp"])
    ],
    targets: [
        .target(
            name: "KeyboardWaiterCore",
            path: "Sources/KeyboardWaiterCore"),
        .executableTarget(
            name: "KeyboardWaiterApp",
            dependencies: ["KeyboardWaiterCore"],
            path: "Sources/KeyboardWaiterApp"),
        .testTarget(
            name: "KeyboardWaiterCoreTests",
            dependencies: ["KeyboardWaiterCore"],
            path: "Tests/KeyboardWaiterCoreTests")
    ]
)

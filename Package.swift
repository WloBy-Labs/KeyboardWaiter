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
        .library(
            name: "KeyboardWaiterPet",
            targets: ["KeyboardWaiterPet"]),
        .executable(
            name: "KeyboardWaiter",
            targets: ["KeyboardWaiterApp"])
    ],
    targets: [
        .target(
            name: "KeyboardWaiterCore",
            path: "Sources/KeyboardWaiterCore"),
        // 宠物模块：依赖 Core，Core 不认识它。
        // 拆掉宠物 = 删掉这个 target、下面 App 的依赖、Sources/KeyboardWaiterPet 目录、
        // 以及 main.swift 里那三行装配代码。
        .target(
            name: "KeyboardWaiterPet",
            dependencies: ["KeyboardWaiterCore"],
            path: "Sources/KeyboardWaiterPet"),
        .executableTarget(
            name: "KeyboardWaiterApp",
            dependencies: ["KeyboardWaiterCore", "KeyboardWaiterPet"],
            path: "Sources/KeyboardWaiterApp"),
        .testTarget(
            name: "KeyboardWaiterCoreTests",
            dependencies: ["KeyboardWaiterCore"],
            path: "Tests/KeyboardWaiterCoreTests"),
        .testTarget(
            name: "KeyboardWaiterPetTests",
            dependencies: ["KeyboardWaiterPet"],
            path: "Tests/KeyboardWaiterPetTests")
    ]
)

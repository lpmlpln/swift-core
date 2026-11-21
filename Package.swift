// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MealPlannerCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(name: "MealPlannerCore", targets: ["MealPlannerCore"]),
    ],
    targets: [
        .target(
            name: "MealPlannerCore",
            path: "Sources/MealPlannerCore"
        ),
        .testTarget(
            name: "MealPlannerCoreTests",
            dependencies: ["MealPlannerCore"],
            path: "Tests/MealPlannerCoreTests"
        ),
    ]
)

// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "MLXLLM",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(
            name: "MLXLLM",
            targets: [
                "MLXLLM"
            ]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/huggingface/swift-transformers.git", branch: "main"),
        .package(url: "https://github.com/ml-explore/mlx-swift.git", branch: "main"),
        .package(url: "https://github.com/SwiftUIX/SwiftUIX.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "MLXLLM",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXOptimizers", package: "mlx-swift"),
                .product(name: "MLXFFT", package: "mlx-swift"),
                "SwiftUIX",
                .product(name: "Transformers", package: "swift-transformers"),
            ],
            path: "Sources"
        )
    ]
)


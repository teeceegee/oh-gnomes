// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OhGnomes",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "GnomesCore", targets: ["GnomesCore"]),
        .library(name: "GnomesContracts", targets: ["GnomesContracts"]),
        .library(name: "GnomesSimulation", targets: ["GnomesSimulation"]),
        .library(name: "GnomesEconomy", targets: ["GnomesEconomy"]),
        .library(name: "GnomesPersistence", targets: ["GnomesPersistence"]),
        .library(name: "GnomesServer", targets: ["GnomesServer"]),
        .library(name: "GnomesPresentation", targets: ["GnomesPresentation"]),
        .library(name: "GnomesAudio", targets: ["GnomesAudio"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swhitty/FlyingFox.git", from: "0.16.0")
    ],
    targets: [
        .target(
            name: "GnomesCore",
            dependencies: [],
            resources: [.process("Resources")]
        ),
        .target(
            name: "GnomesContracts",
            dependencies: ["GnomesCore"]
        ),
        .target(
            name: "GnomesSimulation",
            dependencies: ["GnomesCore"]
        ),
        .target(
            name: "GnomesEconomy",
            dependencies: ["GnomesCore"]
        ),
        .target(
            name: "GnomesPersistence",
            dependencies: ["GnomesCore"]
        ),
        .target(
            name: "GnomesServer",
            dependencies: [
                "GnomesCore",
                "GnomesContracts",
                "GnomesEconomy",
                "GnomesSimulation",
                "GnomesPersistence",
                .product(name: "FlyingFox", package: "FlyingFox")
            ]
        ),
        .target(
            name: "GnomesPresentation",
            dependencies: ["GnomesCore", "GnomesContracts", "GnomesSimulation"]
        ),
        .target(
            name: "GnomesPresentation3D",
            dependencies: ["GnomesCore", "GnomesContracts", "GnomesSimulation"]
        ),
        .target(
            name: "GnomesAudio",
            dependencies: ["GnomesCore", "GnomesContracts", "GnomesSimulation"]
        ),
        .executableTarget(
            name: "OhGnomesApp",
            dependencies: [
                "GnomesCore",
                "GnomesContracts",
                "GnomesSimulation",
                "GnomesEconomy",
                "GnomesPersistence",
                "GnomesServer",
                "GnomesPresentation",
                "GnomesPresentation3D",
                "GnomesAudio",
                .product(name: "FlyingFox", package: "FlyingFox")
            ]
        ),
        .testTarget(
            name: "GnomesCoreTests",
            dependencies: ["GnomesCore"]
        ),
        .testTarget(
            name: "GnomesContractsTests",
            dependencies: ["GnomesContracts"]
        ),
        .testTarget(
            name: "GnomesSimulationTests",
            dependencies: ["GnomesSimulation", "GnomesCore"]
        ),
        .testTarget(
            name: "GnomesEconomyTests",
            dependencies: ["GnomesEconomy", "GnomesCore"]
        ),
        .testTarget(
            name: "GnomesPersistenceTests",
            dependencies: ["GnomesPersistence", "GnomesCore"]
        ),
        .testTarget(
            name: "GnomesServerTests",
            dependencies: ["GnomesServer", "GnomesCore", "GnomesContracts", "GnomesEconomy", "GnomesSimulation"]
        ),
        .testTarget(
            name: "GnomesPresentationTests",
            dependencies: ["GnomesPresentation", "GnomesCore", "GnomesContracts", "GnomesSimulation"]
        ),
        .testTarget(
            name: "GnomesPresentation3DTests",
            dependencies: ["GnomesPresentation3D", "GnomesCore", "GnomesContracts", "GnomesSimulation"]
        ),
        .testTarget(
            name: "GnomesAudioTests",
            dependencies: ["GnomesAudio", "GnomesCore", "GnomesSimulation"]
        ),
        .testTarget(
            name: "ContentTests",
            dependencies: ["GnomesCore", "GnomesSimulation", "GnomesAudio"]
        ),
    ]
)

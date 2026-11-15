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
    ],
    dependencies: [],
    targets: [
        .target(
            name: "GnomesCore",
            dependencies: []
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
            dependencies: ["GnomesCore", "GnomesContracts"]
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
    ]
)

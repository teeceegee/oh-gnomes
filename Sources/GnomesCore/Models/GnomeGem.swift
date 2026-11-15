import Foundation

public struct GnomeGem: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let colorHex: String
    public let shape: GemShape
    public let iconSymbol: String

    public enum GemShape: String, Codable, Sendable, CaseIterable {
        case diamond
        case star
        case hexagon
        case triangle
        case circle
        case heart
        case shield
        case clover
    }

    public init(id: String, name: String, colorHex: String, shape: GemShape, iconSymbol: String) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.shape = shape
        self.iconSymbol = iconSymbol
    }

    /// Predefined registry of 20 visually distinctive Gnome Gems (colour + shape/symbol redundancy)
    public static let standardPalette: [GnomeGem] = [
        GnomeGem(id: "gem_01", name: "Ruby Star", colorHex: "#E63946", shape: .star, iconSymbol: "★"),
        GnomeGem(id: "gem_02", name: "Sapphire Diamond", colorHex: "#1D3557", shape: .diamond, iconSymbol: "◆"),
        GnomeGem(id: "gem_03", name: "Emerald Hexagon", colorHex: "#2A9D8F", shape: .hexagon, iconSymbol: "⬡"),
        GnomeGem(id: "gem_04", name: "Amber Triangle", colorHex: "#F4A261", shape: .triangle, iconSymbol: "▲"),
        GnomeGem(id: "gem_05", name: "Amethyst Heart", colorHex: "#8338EC", shape: .heart, iconSymbol: "♥"),
        GnomeGem(id: "gem_06", name: "Topaz Circle", colorHex: "#FFB703", shape: .circle, iconSymbol: "●"),
        GnomeGem(id: "gem_07", name: "Aquamarine Shield", colorHex: "#457B9D", shape: .shield, iconSymbol: "🛡"),
        GnomeGem(id: "gem_08", name: "Jade Clover", colorHex: "#38B000", shape: .clover, iconSymbol: "♣"),
        GnomeGem(id: "gem_09", name: "Rose Quartz Diamond", colorHex: "#FF006E", shape: .diamond, iconSymbol: "◈"),
        GnomeGem(id: "gem_10", name: "Tanzanite Star", colorHex: "#3A0CA3", shape: .star, iconSymbol: "✶"),
        GnomeGem(id: "gem_11", name: "Citrine Hexagon", colorHex: "#FB8500", shape: .hexagon, iconSymbol: "⬢"),
        GnomeGem(id: "gem_12", name: "Turquoise Triangle", colorHex: "#06D6A0", shape: .triangle, iconSymbol: "△"),
        GnomeGem(id: "gem_13", name: "Garnet Heart", colorHex: "#9B2226", shape: .heart, iconSymbol: "❣"),
        GnomeGem(id: "gem_14", name: "Cobalt Circle", colorHex: "#0077B6", shape: .circle, iconSymbol: "◉"),
        GnomeGem(id: "gem_15", name: "Obsidian Shield", colorHex: "#2B2D42", shape: .shield, iconSymbol: "⚔"),
        GnomeGem(id: "gem_16", name: "Peridot Clover", colorHex: "#70E000", shape: .clover, iconSymbol: "☘"),
        GnomeGem(id: "gem_17", name: "Coral Star", colorHex: "#E76F51", shape: .star, iconSymbol: "✦"),
        GnomeGem(id: "gem_18", name: "Violet Diamond", colorHex: "#7209B7", shape: .diamond, iconSymbol: "◇"),
        GnomeGem(id: "gem_19", name: "Sunny Hexagon", colorHex: "#FFD166", shape: .hexagon, iconSymbol: "⬡"),
        GnomeGem(id: "gem_20", name: "Ocean Shield", colorHex: "#0096C7", shape: .shield, iconSymbol: "⛨")
    ]
}

import Foundation

public struct GnomeVisualProfile: Codable, Sendable, Equatable {
    public enum HatStyle: String, Codable, Sendable, CaseIterable {
        case pointy
        case wizardTall
        case wideBrim
        case bowler
        case beret
    }

    public enum BeardStyle: String, Codable, Sendable, CaseIterable {
        case longFlowing
        case bushy
        case braided
        case trimmed
        case handlebar
    }

    public enum Accessory: String, Codable, Sendable, CaseIterable {
        case none
        case monocle
        case goggles
        case trowel
        case pipe
        case flower
        case lantern
        case magnifyingGlass
    }

    public let hatStyle: HatStyle
    public let beardStyle: BeardStyle
    public let accessory: Accessory
    public let hatColorHex: String
    public let tunicColorHex: String
    public let beardColorHex: String
    public let heightScale: Double
    public let widthScale: Double

    public init(
        hatStyle: HatStyle,
        beardStyle: BeardStyle,
        accessory: Accessory,
        hatColorHex: String,
        tunicColorHex: String,
        beardColorHex: String,
        heightScale: Double,
        widthScale: Double
    ) {
        self.hatStyle = hatStyle
        self.beardStyle = beardStyle
        self.accessory = accessory
        self.hatColorHex = hatColorHex
        self.tunicColorHex = tunicColorHex
        self.beardColorHex = beardColorHex
        self.heightScale = heightScale
        self.widthScale = widthScale
    }

    /// Deterministically derives a unique visual profile for any gnome from its ID & traits
    public static func profile(for gnome: Gnome) -> GnomeVisualProfile {
        let numStr = gnome.id.replacingOccurrences(of: "gnome_", with: "")
        let index = max(0, (Int(numStr) ?? abs(gnome.id.hashValue)) - 1)

        let hatStyles = HatStyle.allCases
        let beardStyles = BeardStyle.allCases
        let accessories = Accessory.allCases

        let hatColors = [
            "#e74c3c", "#3498db", "#2ecc71", "#f39c12", "#9b59b6", "#1abc9c",
            "#e67e22", "#d35400", "#c0392b", "#2980b9", "#27ae60", "#8e44ad",
            "#e84393", "#00b894", "#fdcb6e", "#0984e3"
        ]
        let tunicColors = [
            "#2c3e50", "#1e3799", "#0c2461", "#4a69bd", "#b71540", "#079992",
            "#3c6382", "#38ada9", "#e55039", "#6a89cc", "#60a3bc", "#78e08f"
        ]
        let beardColors = ["#ffffff", "#f1f2f6", "#dfe4ea", "#ced6e0", "#d1ccc0", "#eccc68"]

        let hatStyle = hatStyles[index % hatStyles.count]
        let beardStyle = beardStyles[(index / hatStyles.count + index) % beardStyles.count]
        let accessory = accessories[(index * 3 + 1) % accessories.count]
        let hatColor = hatColors[index % hatColors.count]
        let tunicColor = tunicColors[(index * 5 + 2) % tunicColors.count]
        let beardColor = beardColors[index % beardColors.count]

        // Vary build subtly by archetype/attributes
        let heightScale = 0.88 + (gnome.baselineAttributes.speed * 0.24)
        let widthScale = 0.88 + (gnome.baselineAttributes.stamina * 0.26)

        return GnomeVisualProfile(
            hatStyle: hatStyle,
            beardStyle: beardStyle,
            accessory: accessory,
            hatColorHex: hatColor,
            tunicColorHex: tunicColor,
            beardColorHex: beardColor,
            heightScale: heightScale,
            widthScale: widthScale
        )
    }
}

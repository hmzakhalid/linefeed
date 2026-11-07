/// Linefeed's colors. The app, the generated icons, and the website's
/// `site/src/brand-tokens.css` all come from these values.
public enum BrandPalette {
    public struct Color: Equatable, Sendable {
        public let red: Double
        public let green: Double
        public let blue: Double

        public init(hex: UInt32) {
            red = Double((hex >> 16) & 0xFF) / 255
            green = Double((hex >> 8) & 0xFF) / 255
            blue = Double(hex & 0xFF) / 255
        }

        public var hex: String {
            let components = [red, green, blue].map { Int(($0 * 255).rounded()) }
            return "#" + components.map { String(format: "%02x", $0) }.joined()
        }
    }

    public static let ink = Color(hex: 0x12110F)
    public static let inkSoft = Color(hex: 0x292621)
    public static let graphite = Color(hex: 0x1C1A17)
    public static let ash = Color(hex: 0x746E67)
    public static let ashLight = Color(hex: 0xAAA39B)
    public static let paper = Color(hex: 0xF7F1EB)
    public static let paperBright = Color(hex: 0xFDFAF6)
    public static let paperDeep = Color(hex: 0xE9E2DA)
    public static let red = Color(hex: 0xD4212B)
    public static let redDark = Color(hex: 0xAD151D)
    public static let redWash = Color(hex: 0xEED4D1)

    /// Every token by the name the website uses for it.
    public static let tokens: [(name: String, color: Color)] = [
        ("paper", paper), ("paper-bright", paperBright), ("paper-deep", paperDeep),
        ("ink", ink), ("ink-soft", inkSoft), ("graphite", graphite),
        ("ash", ash), ("ash-light", ashLight),
        ("red", red), ("red-dark", redDark), ("red-wash", redWash),
    ]
}

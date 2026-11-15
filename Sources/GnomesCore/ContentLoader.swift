import Foundation

public struct CommentaryCorpus: Codable, Sendable, Equatable {
    public let openings: [String]
    public let overtakes: [String]
    public let stumbles: [String]
    public let springLaunchers: [String]
    public let mudSplashes: [String]
    public let sprinklers: [String]
    public let collisions: [String]
    public let photoFinishes: [String]
    public let winnerCelebrations: [String]

    public init(
        openings: [String],
        overtakes: [String],
        stumbles: [String],
        springLaunchers: [String],
        mudSplashes: [String],
        sprinklers: [String],
        collisions: [String],
        photoFinishes: [String],
        winnerCelebrations: [String]
    ) {
        self.openings = openings
        self.overtakes = overtakes
        self.stumbles = stumbles
        self.springLaunchers = springLaunchers
        self.mudSplashes = mudSplashes
        self.sprinklers = sprinklers
        self.collisions = collisions
        self.photoFinishes = photoFinishes
        self.winnerCelebrations = winnerCelebrations
    }
}

public enum ContentLoader {
    public static var resourcesBundle: Bundle {
        return Bundle.module
    }

    private static func findContentURL(subpath: String) -> URL? {
        // 1. Try Bundle.module if available
        #if SWIFT_PACKAGE
        if let bundleUrl = Bundle.module.url(forResource: (subpath as NSString).deletingPathExtension,
                                             withExtension: (subpath as NSString).pathExtension) {
            return bundleUrl
        }
        #endif

        // 2. Try environment variable override
        if let envDir = ProcessInfo.processInfo.environment["OH_GNOMES_CONTENT_DIR"] {
            let envUrl = URL(fileURLWithPath: envDir).appendingPathComponent(subpath)
            if FileManager.default.fileExists(atPath: envUrl.path) {
                return envUrl
            }
        }

        // 3. Fallback to local workspace Content/ directory
        let localCandidate = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Content")
            .appendingPathComponent(subpath)
        if FileManager.default.fileExists(atPath: localCandidate.path) {
            return localCandidate
        }

        return nil
    }

    /// Loads the standard roster of 48 gnomes
    public static func loadGnomes() throws -> [Gnome] {
        guard let url = findContentURL(subpath: "Gnomes/gnomes.json") else {
            throw NSError(domain: "ContentLoader", code: 404, userInfo: [NSLocalizedDescriptionKey: "Gnomes content file not found"])
        }
        let data = try Data(contentsOf: url)
        return try loadGnomes(from: data)
    }

    public static func loadGnomes(from data: Data) throws -> [Gnome] {
        let decoder = JSONDecoder()
        return try decoder.decode([Gnome].self, from: data)
    }

    /// Loads the procedural commentary corpus
    public static func loadCommentaryCorpus() throws -> CommentaryCorpus {
        guard let url = findContentURL(subpath: "Commentary/commentary_corpus.json") else {
            throw NSError(domain: "ContentLoader", code: 404, userInfo: [NSLocalizedDescriptionKey: "Commentary corpus file not found"])
        }
        let data = try Data(contentsOf: url)
        return try loadCommentaryCorpus(from: data)
    }

    public static func loadCommentaryCorpus(from data: Data) throws -> CommentaryCorpus {
        let decoder = JSONDecoder()
        return try decoder.decode(CommentaryCorpus.self, from: data)
    }
}

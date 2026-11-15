import Foundation
import GnomesCore

public enum CourseLoader {
    private static func findCourseURL() -> URL? {
        #if SWIFT_PACKAGE
        if let bundleUrl = ContentLoader.resourcesBundle.url(forResource: "courses", withExtension: "json") {
            return bundleUrl
        }
        #endif

        if let envDir = ProcessInfo.processInfo.environment["OH_GNOMES_CONTENT_DIR"] {
            let envUrl = URL(fileURLWithPath: envDir).appendingPathComponent("Courses/courses.json")
            if FileManager.default.fileExists(atPath: envUrl.path) {
                return envUrl
            }
        }

        let localCandidate = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Content/Courses/courses.json")
        if FileManager.default.fileExists(atPath: localCandidate.path) {
            return localCandidate
        }

        return nil
    }

    /// Loads the standard courses from bundled or workspace content
    public static func loadCourses() throws -> [Course] {
        guard let url = findCourseURL() else {
            // Default built-in fallback
            return [Course.gardenGrandPrix]
        }
        let data = try Data(contentsOf: url)
        return try loadCourses(from: data)
    }

    public static func loadCourses(from data: Data) throws -> [Course] {
        let decoder = JSONDecoder()
        return try decoder.decode([Course].self, from: data)
    }
}

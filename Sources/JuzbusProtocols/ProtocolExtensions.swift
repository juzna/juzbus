import Foundation
import os.log

/// Common constants for juzbus
public enum JuzbusConstants {
    /// The mach service name for the directory service
    public static let machServiceName = "cz.juzna.juzbus"

    /// Maximum length for instance names
    public static let maxInstanceNameLength = 64

    /// Default timeout for XPC operations (in seconds)
    public static let defaultTimeout: TimeInterval = 10.0

    /// Logging subsystem
    public static let logSubsystem = "cz.juzna.juzbus"
}

/// Logging categories
public enum JuzbusLogCategory {
    public static let directory = "directory"
    public static let client = "client"
    public static let instance = "instance"
}

/// Helper extension for creating loggers
public extension OSLog {
    static func juzbus(category: String) -> OSLog {
        return OSLog(subsystem: JuzbusConstants.logSubsystem, category: category)
    }
}

/// Common errors
public enum JuzbusError: Error, LocalizedError {
    case invalidInstanceName(String)
    case instanceNotFound(String)
    case duplicateInstance(String)
    case connectionFailed(String)
    case timeout
    case invalidCommand

    public var errorDescription: String? {
        switch self {
        case .invalidInstanceName(let name):
            return "Invalid instance name: '\(name)'"
        case .instanceNotFound(let name):
            return "Instance not found: '\(name)'"
        case .duplicateInstance(let name):
            return "Instance name already registered: '\(name)'"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .timeout:
            return "Operation timed out"
        case .invalidCommand:
            return "Invalid command"
        }
    }
}

/// Validation helpers
public extension String {
    /// Validates if the string is a valid instance name.
    /// Valid names contain only alphanumeric characters, hyphens, and underscores,
    /// and must not exceed the maximum length.
    var isValidInstanceName: Bool {
        guard !isEmpty && count <= JuzbusConstants.maxInstanceNameLength else {
            return false
        }

        let validCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return self.unicodeScalars.allSatisfy { validCharacters.contains($0) }
    }
}

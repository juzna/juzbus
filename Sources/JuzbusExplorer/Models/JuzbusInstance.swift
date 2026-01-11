import Foundation

/// Represents a Juzbus instance
struct JuzbusInstance: Identifiable, Equatable, Hashable {
    let id: String  // instance name

    var name: String {
        id
    }
}

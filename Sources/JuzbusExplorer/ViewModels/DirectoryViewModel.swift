import Foundation
import SwiftUI
import JuzbusProtocols

/// ViewModel for managing directory service connection and instance list
@MainActor
class DirectoryViewModel: ObservableObject {
    @Published var instances: [JuzbusInstance] = []
    @Published var connectionState: ConnectionState = .disconnected
    @Published var errorMessage: String?

    private let directoryService = DirectoryService()

    /// Connects to the directory service
    func connect() async {
        do {
            errorMessage = nil
            connectionState = .connecting
            try await directoryService.connect()
            connectionState = .connected
            await refresh()
        } catch {
            connectionState = .error
            errorMessage = error.localizedDescription
        }
    }

    /// Refreshes the list of instances
    func refresh() async {
        guard connectionState == .connected else {
            return
        }

        do {
            errorMessage = nil
            let instanceNames = try await directoryService.listInstances()
            instances = instanceNames.map { JuzbusInstance(id: $0) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Gets the endpoint for a specific instance
    func endpoint(for instanceName: String) async throws -> NSXPCListenerEndpoint {
        try await directoryService.endpoint(for: instanceName)
    }

    /// Disconnects from the directory service
    func disconnect() {
        directoryService.disconnect()
        connectionState = .disconnected
        instances = []
    }

    deinit {
        // Disconnect happens automatically when connection is deallocated
    }
}

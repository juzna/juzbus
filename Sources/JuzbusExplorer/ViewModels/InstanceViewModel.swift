import Foundation
import SwiftUI
import JuzbusProtocols

/// ViewModel for managing instance connection and command execution
@MainActor
class InstanceViewModel: ObservableObject {
    @Published var commandHistory: [CommandExecution] = []
    @Published var isExecuting: Bool = false
    @Published var errorMessage: String?

    let instanceName: String
    private var instanceService: InstanceService?

    private let maxHistoryEntries = 100

    init(instanceName: String) {
        self.instanceName = instanceName
    }

    /// Connects to an instance via its endpoint
    func connect(endpoint: NSXPCListenerEndpoint) async {
        do {
            errorMessage = nil
            let service = InstanceService()
            try await service.connect(endpoint: endpoint)
            instanceService = service
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Sends a command to the instance
    func sendCommand(_ command: String) async {
        guard let instanceService = instanceService else {
            errorMessage = "Not connected to instance"
            return
        }

        guard !command.isEmpty else {
            return
        }

        isExecuting = true
        errorMessage = nil

        do {
            let response = try await instanceService.runCommand(command)
            let execution = CommandExecution(
                command: command,
                response: response,
                timestamp: Date()
            )
            commandHistory.append(execution)

            // Limit history size
            if commandHistory.count > maxHistoryEntries {
                commandHistory.removeFirst(commandHistory.count - maxHistoryEntries)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isExecuting = false
    }

    /// Disconnects from the instance
    func disconnect() {
        instanceService?.disconnect()
        instanceService = nil
    }

    deinit {
        // Disconnect happens automatically when connection is deallocated
    }
}

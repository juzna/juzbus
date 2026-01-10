import Foundation
import JuzbusProtocols

// Parse command-line arguments
guard let command = Command.parse(CommandLine.arguments) else {
    exit(1)
}

// Handle the command
switch command {
case .help:
    Command.showHelp()
    exit(0)

case .list:
    do {
        let directoryClient = try DirectoryClient()
        defer { directoryClient.disconnect() }

        let result = directoryClient.listInstances()

        switch result {
        case .success(let instances):
            if instances.isEmpty {
                print("No instances registered")
            } else {
                print("Registered instances (\(instances.count)):")
                for instance in instances {
                    print("  \(instance)")
                }
            }
            exit(0)

        case .failure(let error):
            print("Error: \(error.localizedDescription)")
            exit(1)
        }

    } catch {
        print("Error: Failed to connect to directory service")
        print("Make sure the directory service is running:")
        print("  launchctl load ~/Library/LaunchAgents/cz.juzna.juzbus.plist")
        exit(1)
    }

case .exec(let instanceName, let commandString):
    do {
        // Connect to directory
        let directoryClient = try DirectoryClient()
        defer { directoryClient.disconnect() }

        // Get endpoint for the instance
        let endpointResult = directoryClient.endpoint(for: instanceName)

        switch endpointResult {
        case .success(let endpoint):
            // Connect to the instance
            let instanceClient = try InstanceClient(endpoint: endpoint)
            defer { instanceClient.disconnect() }

            // Run the command
            let commandResult = instanceClient.runCommand(commandString)

            switch commandResult {
            case .success(let response):
                print(response)
                exit(0)

            case .failure(let error):
                print("Error: \(error.localizedDescription)")
                exit(1)
            }

        case .failure(let error):
            if case JuzbusError.instanceNotFound(let name) = error {
                print("Error: Instance '\(name)' not found")
                print("Use 'juzbus list' to see available instances")
                exit(2)
            } else {
                print("Error: \(error.localizedDescription)")
                exit(1)
            }
        }

    } catch {
        print("Error: Failed to connect to directory service")
        print("Make sure the directory service is running:")
        print("  launchctl load ~/Library/LaunchAgents/cz.juzna.juzbus.plist")
        exit(1)
    }
}

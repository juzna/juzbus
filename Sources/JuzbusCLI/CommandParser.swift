import Foundation

/// Represents the commands that can be executed by the CLI.
enum Command {
    case list
    case exec(instanceName: String, command: String)
    case help

    /// Parses command-line arguments into a Command.
    static func parse(_ args: [String]) -> Command? {
        // Skip the first argument (program name)
        let arguments = Array(args.dropFirst())

        guard !arguments.isEmpty else {
            return .help
        }

        let subcommand = arguments[0].lowercased()

        switch subcommand {
        case "list", "ls":
            return .list

        case "exec", "run":
            guard arguments.count >= 3 else {
                print("Error: 'exec' requires an instance name and command")
                print("Usage: juzbus exec <instance-name> <command>")
                return nil
            }
            let instanceName = arguments[1]
            let command = arguments[2...].joined(separator: " ")
            return .exec(instanceName: instanceName, command: command)

        case "help", "--help", "-h":
            return .help

        default:
            print("Error: Unknown command '\(subcommand)'")
            return .help
        }
    }

    /// Displays help information.
    static func showHelp() {
        print("""
        juzbus - Control and communicate with running application instances

        USAGE:
            juzbus <command> [arguments]

        COMMANDS:
            list                          List all registered instances
            exec <instance> <command>     Send a command to a specific instance

        EXAMPLES:
            juzbus list
            juzbus exec my-app ping
            juzbus exec window-1 "echo Hello, World!"

        OPTIONS:
            -h, --help                    Show this help message
        """)
    }
}

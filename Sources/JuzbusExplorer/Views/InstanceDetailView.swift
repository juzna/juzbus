import SwiftUI

struct InstanceDetailView: View {
    @ObservedObject var viewModel: InstanceViewModel
    @State private var commandText: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "app.fill")
                    .foregroundColor(.blue)
                Text(viewModel.instanceName)
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Command history
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        if viewModel.commandHistory.isEmpty {
                            emptyHistoryView
                        } else {
                            ForEach(viewModel.commandHistory) { execution in
                                commandHistoryRow(execution)
                                    .id(execution.id)
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.commandHistory.count) {
                    if let lastId = viewModel.commandHistory.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Error banner
            if let errorMessage = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                    Spacer()
                    Button("Dismiss") {
                        viewModel.errorMessage = nil
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                }
                .padding()
                .background(Color.red.opacity(0.1))

                Divider()
            }

            // Command input
            HStack(spacing: 12) {
                TextField("Enter command (e.g., ping, echo hello, uptime)...", text: $commandText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFieldFocused)
                    .disabled(viewModel.isExecuting)
                    .onSubmit {
                        sendCommand()
                    }

                Button(action: sendCommand) {
                    if viewModel.isExecuting {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 60)
                    } else {
                        Text("Send")
                            .frame(width: 60)
                    }
                }
                .disabled(commandText.isEmpty || viewModel.isExecuting)
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }

    @ViewBuilder
    private var emptyHistoryView: some View {
        VStack(spacing: 12) {
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No commands executed yet")
                .font(.body)
                .foregroundColor(.secondary)
            Text("Try sending: ping, echo hello, uptime")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @ViewBuilder
    private func commandHistoryRow(_ execution: CommandExecution) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Timestamp
            Text(execution.timestamp, style: .time)
                .font(.caption)
                .foregroundColor(.secondary)

            // Command
            HStack {
                Image(systemName: "chevron.right")
                    .foregroundColor(.blue)
                    .font(.caption)
                Text(execution.command)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.blue)
            }

            // Response
            Text(execution.response)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(6)
        }
        .padding(.vertical, 4)
    }

    private func sendCommand() {
        let cmd = commandText
        commandText = ""
        viewModel.errorMessage = nil

        Task {
            await viewModel.sendCommand(cmd)
            // Keep focus on the input field
            isTextFieldFocused = true
        }
    }
}

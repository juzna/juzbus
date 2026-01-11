import SwiftUI

struct InstanceListView: View {
    @ObservedObject var directoryViewModel: DirectoryViewModel
    @Binding var selectedInstance: JuzbusInstance?

    var body: some View {
        List(directoryViewModel.instances, selection: $selectedInstance) { instance in
            HStack {
                Image(systemName: "app.fill")
                    .foregroundColor(.blue)
                Text(instance.name)
            }
            .tag(instance)
        }
        .navigationTitle("Juzbus Instances")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    Task {
                        await directoryViewModel.refresh()
                    }
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }

            ToolbarItem(placement: .status) {
                connectionStatusView
            }
        }
        .overlay {
            if directoryViewModel.instances.isEmpty {
                emptyStateView
            }
        }
        .refreshable {
            await directoryViewModel.refresh()
        }
    }

    @ViewBuilder
    private var connectionStatusView: some View {
        switch directoryViewModel.connectionState {
        case .connected:
            Label("Connected", systemImage: "circle.fill")
                .foregroundColor(.green)
                .font(.caption)
        case .connecting:
            Label("Connecting", systemImage: "circle.fill")
                .foregroundColor(.orange)
                .font(.caption)
        case .disconnected:
            Label("Disconnected", systemImage: "circle.fill")
                .foregroundColor(.gray)
                .font(.caption)
        case .error:
            Label("Error", systemImage: "circle.fill")
                .foregroundColor(.red)
                .font(.caption)
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            if let errorMessage = directoryViewModel.errorMessage {
                Text(errorMessage)
                    .font(.body)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)

                Button("Retry") {
                    Task {
                        await directoryViewModel.connect()
                    }
                }
                .buttonStyle(.bordered)
            } else {
                Text("No instances found")
                    .font(.body)
                    .foregroundColor(.secondary)

                Text("Start an instance with juzbus-example")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

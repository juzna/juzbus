import SwiftUI

struct ContentView: View {
    @StateObject private var directoryViewModel = DirectoryViewModel()
    @State private var selectedInstance: JuzbusInstance?
    @State private var instanceViewModel: InstanceViewModel?

    var body: some View {
        NavigationSplitView {
            InstanceListView(
                directoryViewModel: directoryViewModel,
                selectedInstance: $selectedInstance
            )
        } detail: {
            if let instanceViewModel = instanceViewModel {
                InstanceDetailView(viewModel: instanceViewModel)
            } else {
                VStack {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select an instance")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .task {
            await directoryViewModel.connect()
        }
        .onChange(of: selectedInstance) {
            Task {
                await handleInstanceSelection(selectedInstance)
            }
        }
    }

    private func handleInstanceSelection(_ instance: JuzbusInstance?) async {
        // Disconnect from previous instance
        instanceViewModel?.disconnect()
        instanceViewModel = nil

        guard let instance = instance else {
            return
        }

        // Connect to new instance
        let viewModel = InstanceViewModel(instanceName: instance.name)

        do {
            let endpoint = try await directoryViewModel.endpoint(for: instance.name)
            await viewModel.connect(endpoint: endpoint)
            instanceViewModel = viewModel
        } catch {
            // Error connecting to instance
            print("Error connecting to instance: \(error)")
        }
    }
}

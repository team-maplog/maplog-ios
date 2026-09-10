import SwiftUI

struct SocialConnectionsView: View {
    @StateObject private var viewModel: SocialConnectionsViewModel

    init(repository: any SocialConnectionRepository) {
        _viewModel = StateObject(wrappedValue: SocialConnectionsViewModel(repository: repository))
    }

    var body: some View {
        List {
            if viewModel.isLoading && !viewModel.hasLoaded {
                ProgressView("연결 계정 확인 중")
            }
            if let error = viewModel.error {
                Section {
                    Text(error.message)
                    if error.recoveryAction == .retry {
                        Button("다시 시도") { Task { await viewModel.load() } }
                    }
                }
            }
            if viewModel.hasLoaded && viewModel.connections.isEmpty {
                Text("연결된 소셜 계정이 없어요.").foregroundStyle(.secondary)
            }
            ForEach(viewModel.connections) { connection in
                HStack {
                    Text(connection.displayName)
                    Spacer()
                    Text(connection.isConnected ? "연결됨" : "연결 안 됨")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("소셜 계정 관리")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}

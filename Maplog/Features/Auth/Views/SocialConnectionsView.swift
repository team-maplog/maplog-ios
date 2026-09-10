import SwiftUI

struct SocialConnectionsView: View {
    @State private var pendingDisconnection: SocialConnection?
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
            if let error = viewModel.disconnectError {
                Section {
                    Text(error.message).foregroundStyle(.secondary)
                    if error.recoveryAction == .retry {
                        Button("목록 새로고침") { Task { await viewModel.load() } }
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
                    if viewModel.disconnectingProvider == connection.provider {
                        ProgressView().accessibilityLabel("연결 해제 중")
                    } else if connection.isConnected {
                        Button("연결 해제", role: .destructive) {
                            pendingDisconnection = connection
                        }
                        .disabled(viewModel.isLoading || viewModel.disconnectingProvider != nil)
                    } else {
                        Text("연결 안 됨").foregroundStyle(.secondary)
                    }
                }
            }
        }
        .confirmationDialog(
            "소셜 계정 연결을 해제할까요?",
            isPresented: Binding(
                get: { pendingDisconnection != nil },
                set: { if !$0 { pendingDisconnection = nil } }
            ),
            presenting: pendingDisconnection
        ) { connection in
            Button("연결 해제", role: .destructive) {
                Task { await viewModel.disconnect(connection) }
            }
            Button("취소", role: .cancel) { pendingDisconnection = nil }
        } message: { connection in
            Text("해제하면 \(connection.displayName) 계정으로 로그인할 수 없어요.")
        }
        .navigationTitle("소셜 계정 관리")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}

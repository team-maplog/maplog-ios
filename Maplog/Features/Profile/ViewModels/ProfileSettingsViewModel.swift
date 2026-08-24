import Foundation

@MainActor
final class ProfileSettingsViewModel: ObservableObject {
    @Published private(set) var isDeletingAccount = false
    @Published private(set) var deleteErrorMessage: String?

    private let profileRepository: any ProfileRepository

    init(
        profileRepository: any ProfileRepository
    ) {
        self.profileRepository = profileRepository
    }

    func deleteAccount() async -> Bool {
        guard !isDeletingAccount else {
            return false
        }

        deleteErrorMessage = nil
        isDeletingAccount = true

        defer {
            isDeletingAccount = false
        }

        do {
            try await profileRepository.deleteMyProfile()
            return true
        } catch {
            let presentation = ProfileErrorPolicy.presentation(for: error)
            deleteErrorMessage = presentation.recoveryAction == .signIn
                ? presentation.message
                : "회원 탈퇴를 처리하지 못했어요. 잠시 후 다시 시도해 주세요."
            return false
        }
    }
}

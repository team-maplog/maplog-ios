import Foundation
import UIKit

@MainActor
final class ProfileEditViewModel: ObservableObject {
    @Published var nickname: String
    @Published var bio: String
    @Published private(set) var avatarPreviewImageData: Data?
    @Published private(set) var isSaving = false
    @Published private(set) var formMessage: String?
    @Published private(set) var nicknameMessage: String?
    @Published private(set) var bioMessage: String?
    @Published private(set) var recoveryAction: ErrorPresentation.RecoveryAction?

    private let profileRepository: any ProfileRepository
    private var newProfileImageData: Data?

    init(
        profile: ProfileHeaderViewData,
        avatarImageData: Data?,
        profileRepository: any ProfileRepository
    ) {
        self.nickname = profile.nickname
        self.bio = profile.bio
        self.avatarPreviewImageData = avatarImageData
        self.profileRepository = profileRepository
    }

    func selectProfileImage(
        data: Data
    ) {
        guard let image = UIImage(data: data),
              let jpegData = image.jpegData(
                compressionQuality: 0.85
              )
        else {
            apply(
                ProfileEditErrorPresentation(
                    formMessage: "선택한 사진을 읽지 못했어요. 다른 사진을 선택해 주세요.",
                    nicknameMessage: nil,
                    bioMessage: nil,
                    recoveryAction: .none
                )
            )
            return
        }

        clearMessages()
        newProfileImageData = jpegData
        avatarPreviewImageData = jpegData
    }

    func handleProfileImageLoadingFailure() {
        apply(
            ProfileEditErrorPresentation(
                formMessage: "선택한 사진을 읽지 못했어요. 다른 사진을 선택해 주세요.",
                nicknameMessage: nil,
                bioMessage: nil,
                recoveryAction: .none
            )
        )
    }

    func save() async -> Bool {
        guard !isSaving else {
            return false
        }

        clearMessages()

        let trimmedNickname = nickname.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let trimmedBio = bio.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        nicknameMessage = AuthValidation.nicknameError(
            for: trimmedNickname
        )
        bioMessage = trimmedBio.count > 150
            ? "소개는 150자 이하로 입력해 주세요."
            : nil

        guard nicknameMessage == nil,
              bioMessage == nil
        else {
            return false
        }

        isSaving = true
        defer {
            isSaving = false
        }

        do {
            _ = try await profileRepository.updateMyProfile(
                ProfileUpdate(
                    nickname: trimmedNickname,
                    bio: trimmedBio,
                    newProfileImageData: newProfileImageData
                )
            )
            return true
        } catch {
            apply(
                ProfileEditErrorPolicy.presentation(
                    for: error
                )
            )
            return false
        }
    }

    func clearMessages() {
        formMessage = nil
        nicknameMessage = nil
        bioMessage = nil
        recoveryAction = nil
    }

    private func apply(
        _ presentation: ProfileEditErrorPresentation
    ) {
        formMessage = presentation.formMessage
        nicknameMessage = presentation.nicknameMessage
        bioMessage = presentation.bioMessage
        recoveryAction = presentation.recoveryAction
    }
}

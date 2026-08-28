import PhotosUI
import SwiftUI
import UIKit

struct ProfileEditFeatureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.maplogLogout) private var performLogout

    private let onSaved: () async -> Void

    @StateObject private var viewModel: ProfileEditViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?

    init(
        profile: ProfileHeaderViewData,
        avatarImageData: Data?,
        profileRepository: any ProfileRepository,
        onSaved: @escaping () async -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: ProfileEditViewModel(
                profile: profile,
                avatarImageData: avatarImageData,
                profileRepository: profileRepository
            )
        )
        self.onSaved = onSaved
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                ProfileEditAvatarSection(
                    imageData: viewModel.avatarPreviewImageData,
                    selectedPhotoItem: $selectedPhotoItem
                )

                VStack(spacing: 18) {
                    ProfileEditTextField(
                        title: "닉네임",
                        prompt: "닉네임을 입력하세요",
                        text: $viewModel.nickname,
                        message: viewModel.nicknameMessage
                    )

                    ProfileEditBioField(
                        text: $viewModel.bio,
                        message: viewModel.bioMessage
                    )
                }

                ProfileEditFormMessage(
                    message: viewModel.formMessage,
                    recoveryAction: viewModel.recoveryAction,
                    onRetry: save,
                    onSignIn: performLogout
                )

                Button(action: save) {
                    Group {
                        if viewModel.isSaving {
                            ProgressView()
                                .tint(Color.maplogInk)
                        } else {
                            Text("저장")
                                .font(.headline.weight(.bold))
                        }
                    }
                    .foregroundStyle(Color.maplogOnPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.maplogLime, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSaving)
                .opacity(viewModel.isSaving ? 0.7 : 1)
            }
            .padding(.horizontal, MaplogSpacing.page)
            .padding(.top, 24)
            .maplogListBottomPadding()
        }
        .background(Color.maplogSurface)
        .navigationTitle("프로필 편집")
        .navigationBarTitleDisplayMode(.inline)
        .maplogTabBarHidden()
        .onChange(of: selectedPhotoItem) { _, item in
            loadSelectedPhoto(item)
        }
    }

    private func loadSelectedPhoto(
        _ item: PhotosPickerItem?
    ) {
        Task {
            do {
                guard let item,
                      let data = try await item.loadTransferable(
                        type: Data.self
                      )
                else {
                    return
                }

                viewModel.selectProfileImage(data: data)
            } catch {
                viewModel.handleProfileImageLoadingFailure()
            }
        }
    }

    private func save() {
        Task {
            guard await viewModel.save() else {
                return
            }

            await onSaved()
            dismiss()
        }
    }
}

private struct ProfileEditAvatarSection: View {
    let imageData: Data?
    @Binding var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 12) {
            Group {
                if let imageData,
                   let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Color.maplogOlive)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.maplogLime.opacity(0.35))
                }
            }
            .frame(width: 104, height: 104)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(Color.maplogLime, lineWidth: 3)
            }

            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label("사진 변경", systemImage: "camera.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.maplogInk)
                    .padding(.horizontal, 16)
                    .frame(height: 40)
                    .background(Color.maplogCanvas, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ProfileEditTextField: View {
    let title: String
    let prompt: String
    @Binding var text: String
    let message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.maplogInk)

            TextField(prompt, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(
                    Color.maplogCanvas,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )

            ProfileEditFieldMessage(message: message)
        }
    }
}

private struct ProfileEditBioField: View {
    @Binding var text: String
    let message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("소개")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.maplogInk)

                Spacer()

                Text("\(text.count)/150")
                    .font(.caption)
                    .foregroundStyle(Color.maplogMuted)
            }

            TextField(
                "소개를 입력하세요",
                text: $text,
                axis: .vertical
            )
            .lineLimit(3...5)
            .padding(14)
            .background(
                Color.maplogCanvas,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )

            ProfileEditFieldMessage(message: message)
        }
    }
}

private struct ProfileEditFieldMessage: View {
    let message: String?

    var body: some View {
        if let message {
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }
}

private struct ProfileEditFormMessage: View {
    let message: String?
    let recoveryAction: ErrorPresentation.RecoveryAction?
    let onRetry: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        if let message {
            VStack(spacing: 8) {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)

                switch recoveryAction {
                case .retry:
                    Button("다시 시도", action: onRetry)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.maplogOlive)

                case .signIn:
                    Button("로그인으로 이동", action: onSignIn)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.maplogOlive)

                case .some(.none), nil:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

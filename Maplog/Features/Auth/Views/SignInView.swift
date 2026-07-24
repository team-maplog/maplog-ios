//
//  SignInView.swift
//  Maplog
//
//  Created by 한채림 on 7/24/26.
// 로그인 성공 후 AuthSessionStore 상태 변화가 RootView를 자동으로 전환
//safeAreaInset으로 로그인 버튼을 화면 하단에 고정한다. 키보드·오류 문구 때문에 내용이 길어져도 버튼이 자연스럽게 유지.

import SwiftUI

struct SignInView: View {
    @StateObject private var viewModel: SignInViewModel // @StateObject로 ViewModel을 이 화면이 소유

    init(
        authRepository: any AuthRepository,
        authSessionStore: AuthSessionStore
    ) {
        _viewModel = StateObject(wrappedValue: SignInViewModel(authRepository: authRepository, authSessionStore: authSessionStore))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: MaplogSpacing.large) {
                Text("다시 만나서 반가워요")
                    .font(MaplogFont.screenTitle)
                    .foregroundStyle(Color.maplogInk)

                Text("이메일과 비밀번호를 입력해 주세요.")
                    .font(MaplogFont.callout)
                    .foregroundStyle(Color.maplogMuted)

                emailField
                passwordField

                if let formError = viewModel.formError {
                    Text(formError)
                        .font(MaplogFont.caption)
                        .foregroundStyle(Color.maplogDanger)
                }
            }
            .padding(.horizontal, MaplogSpacing.xLarge)
            .padding(.top, MaplogSpacing.xLarge)
            .padding(.bottom, MaplogSpacing.xxxLarge)
        }
        .background(Color.maplogSurface)
        .navigationTitle("이메일 로그인")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button(action: requestSignIn) {
                if viewModel.isLoading
                {
                    ProgressView()
                        .tint(Color.maplogInk)
                        .frame(maxWidth: .infinity)
                } else {
                    Label(
                        primaryButtonTitle,
                        systemImage: "arrow.right.circle.fill")
                }
            }
            .buttonStyle(
                MaplogButtonStyle(
                    variant: .primary,
                    size: .large,
                    fullWidth: true
                )
            )
            .disabled(viewModel.isLoading)
            .padding(.horizontal, MaplogSpacing.xLarge)
            .padding(.vertical, MaplogSpacing.medium)
            .background(Color.maplogSurface)
        }
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
            Text("이메일")
                .font(MaplogFont.caption)
                .foregroundStyle(Color.maplogMuted)

            TextField(
                "email@maplog.app",
                text: $viewModel.email
            )
            .keyboardType(.emailAddress)
            .textContentType(.username)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(MaplogFont.body)
            .foregroundStyle(Color.maplogInk)
            .padding(.horizontal, MaplogSpacing.medium)
            .frame(height: 54)
            .background(Color.maplogSurfaceRaised)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: MaplogRadius.medium,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: MaplogRadius.medium,
                    style: .continuous
                )
                .stroke(
                    viewModel.emailError == nil
                    ? Color.maplogBorder
                    : Color.maplogDanger,
                    lineWidth: 1
                )
            }
            if let emailError = viewModel.emailError {
                Text(emailError)
                    .font(MaplogFont.caption)
                    .foregroundStyle(Color.maplogDanger)
            }
        }
    }
    private var passwordField: some View {
        VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
            Text("비밀번호")
                .font(MaplogFont.caption)
                .foregroundStyle(Color.maplogMuted)

            SecureField(
                "비밀번호를 입력해주세요",
                text: $viewModel.password
            )
            .textContentType(.password)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(MaplogFont.body)
            .foregroundStyle(Color.maplogInk)
            .padding(.horizontal, MaplogSpacing.medium)
            .frame(height: 54)
            .background(Color.maplogSurfaceRaised)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: MaplogRadius.medium,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: MaplogRadius.medium,
                    style: .continuous
                )
                .stroke(
                    viewModel.passwordError == nil
                    ? Color.maplogBorder
                    : Color.maplogDanger,
                    lineWidth: 1
                )
            }

            if let passwordError = viewModel.passwordError {
                Text(passwordError)
                    .font(MaplogFont.caption)
                    .foregroundStyle(Color.maplogDanger)
            }
        }
    }

    private var primaryButtonTitle: String {
        viewModel.recoveryAction == .retry ? "다시 시도" : "로그인하고 시작하기"
    }

    private func requestSignIn() {
        Task {
            await viewModel.signIn()
        }
    }
}

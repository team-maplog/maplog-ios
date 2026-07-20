//
//  SignupView.swift
//  Maplog
//
//  Created by 한채림 on 7/19/26.
//

import SwiftUI

struct SignupView: View {
    //    @State private var email = ""
    //    @State private var password = ""
    //    @State private var passwordConfirmation = ""
    //    @State private var nickname = ""
    //    @State private var hasAcceptedTerms = false
    
    @StateObject private var viewModel: AuthViewModel
    
    init(authSessionStore: AuthSessionStore) {
        _viewModel = StateObject(wrappedValue: AuthViewModel(authSessionStore: authSessionStore))
    }
    
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: MaplogSpacing.xLarge) {
                VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                    Text("이메일 주소")
                        .font(MaplogFont.bodyStrong)
                        .foregroundStyle(Color.maplogInk)
                    
                    TextField(
                        "이메일 주소",
                        text: $viewModel.email,
                        prompt: Text("example@mail.com")
                            .foregroundStyle(Color.maplogSubtle)
                    )
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(MaplogFont.body)
                        .foregroundStyle(Color.maplogInk)
                        .padding(.horizontal, MaplogSpacing.medium)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.maplogSurfaceRaised, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(Color.maplogLine.opacity(0.48), lineWidth: 1)
                        }
                    
                    if let error = viewModel.emailError {
                        Text(error)
                            .font(MaplogFont.caption)
                            .foregroundStyle(Color.maplogDanger)
                    }
                    
                }
                
                VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                    Text("비밀번호")
                        .font(MaplogFont.bodyStrong)
                        .foregroundStyle(Color.maplogInk)
                    
                    SecureField("8자 이상 입력해주세요", text: $viewModel.password)
                        .textContentType(.newPassword)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(MaplogFont.body)
                        .foregroundStyle(Color.maplogInk)
                        .padding(.horizontal, MaplogSpacing.medium)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.maplogSurfaceRaised, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(Color.maplogLine.opacity(0.48), lineWidth: 1)
                        }
                    
                    if let error = viewModel.passwordError {
                        Text(error)
                            .font(MaplogFont.caption)
                            .foregroundStyle(Color.maplogDanger)
                    }
                }
                
                VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                    Text("비밀번호 확인")
                        .font(MaplogFont.bodyStrong)
                        .foregroundStyle(Color.maplogInk)
                    
                    SecureField("비밀번호를 한 번 더 입력해주세요", text: $viewModel.passwordConfirmation)
                        .textContentType(.newPassword)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(MaplogFont.body)
                        .foregroundStyle(Color.maplogInk)
                        .padding(.horizontal, MaplogSpacing.medium)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.maplogSurfaceRaised, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(Color.maplogLine.opacity(0.48), lineWidth: 1)
                        }
                    
                    if let error = viewModel.passwordConfirmationError {
                        Text(error)
                            .font(MaplogFont.caption)
                            .foregroundStyle(Color.maplogDanger)
                    }
                }
                
                VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                    Text("닉네임")
                        .font(MaplogFont.bodyStrong)
                        .foregroundStyle(Color.maplogInk)
                    
                    TextField("사용할 닉네임을 입력해주세요", text: $viewModel.nickname)
                        .textContentType(.nickname)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(MaplogFont.body)
                        .foregroundStyle(Color.maplogInk)
                        .padding(.horizontal, MaplogSpacing.medium)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.maplogSurfaceRaised, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(Color.maplogLine.opacity(0.48), lineWidth: 1)
                        }
                    
                    if let error = viewModel.nicknameError {
                        Text(error)
                            .font(MaplogFont.caption)
                            .foregroundStyle(Color.maplogDanger)
                    }
                }
                
                VStack(spacing: MaplogSpacing.medium) {
                    
                    VStack(alignment: .leading, spacing: MaplogSpacing.xxSmall) {
                        Button {
                            viewModel.termsAgreed.toggle()
                        } label: {
                            HStack(spacing: MaplogSpacing.small) {
                                Image(systemName: viewModel.termsAgreed ? "checkmark" : "")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.maplogInk)
                                    .frame(width: 24, height: 24)
                                    .background(viewModel.termsAgreed ? Color.maplogLime : Color.maplogSurface, in: Circle())
                                    .overlay {
                                        Circle()
                                            .stroke(viewModel.termsAgreed ? Color.maplogLime : Color.maplogOlive.opacity(0.38), lineWidth: 1)
                                    }
                                
                                Text("이용약관 동의 (필수)")
                                    .font(MaplogFont.callout)
                                    .foregroundStyle(Color.maplogInk)
                                
                                Spacer(minLength: 0)
                            }
                            .frame(minHeight: MaplogSize.minimumTapTarget)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("이용약관 동의")
                        .accessibilityValue(viewModel.termsAgreed ? "동의함" : "동의하지 않음")
                        
                        if let error = viewModel.termsError {
                                Text(error)
                                    .font(MaplogFont.caption)
                                    .foregroundStyle(Color.maplogDanger)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: MaplogSpacing.xxSmall) {
                            Button {
                                viewModel.privacyPolicyAgreed.toggle()
                            } label: {
                                HStack(spacing: MaplogSpacing.small) {
                                    Image(systemName: viewModel.privacyPolicyAgreed ? "checkmark" : "")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.maplogInk)
                                        .frame(width: 24, height: 24)
                                        .background(viewModel.privacyPolicyAgreed ? Color.maplogLime : Color.maplogSurface, in: Circle())
                                        .overlay {
                                            Circle()
                                                .stroke(viewModel.privacyPolicyAgreed ? Color.maplogLime : Color.maplogOlive.opacity(0.38), lineWidth: 1)
                                        }
                                    
                                    Text("개인정보 처리방침 동의 (필수)")
                                        .font(MaplogFont.callout)
                                        .foregroundStyle(Color.maplogInk)
                                    
                                    Spacer(minLength: 0)
                                }
                                
                                .frame(minHeight: MaplogSize.minimumTapTarget)
                                .contentShape(Rectangle())
                                
                                
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("개인정보 처리방침 동의")
                            .accessibilityValue(viewModel.privacyPolicyAgreed ? "동의함" : "동의하지 않음")
                            
                            if let error = viewModel.privacyPolicyError{
                                Text(error)
                                    .font(MaplogFont.caption)
                                    .foregroundStyle(Color.maplogDanger)
                            }
                        }
                    
                    
                    
                    
                    Button {
                        // API 연결 단계에서 회원가입 요청을 추가합니다.
                        Task {
                            await viewModel.signUp()
                        }
                    } label: {
                        Text("가입 완료")
                        
                    }
                    .buttonStyle(MaplogButtonStyle(variant: .primary, size: .large, fullWidth: true))
                    .disabled(viewModel.isLoading)
                    
                    if let error = viewModel.signupError {
                        Text(error)
                            .font(MaplogFont.caption)
                            .foregroundStyle(Color.maplogDanger)
                    }
                    
                    HStack(spacing: MaplogSpacing.xxSmall) {
                        Spacer()
                        Text("이미 계정이 있으신가요?")
                            .font(MaplogFont.caption)
                            .foregroundStyle(Color.maplogMuted)
                        Button("로그인하기") {
                            // 로그인 화면 연결 단계에서 NavigationLink로 교체합니다.
                        }
                        .font(MaplogFont.caption)
                        .foregroundStyle(Color.maplogInk)
                        .buttonStyle(.plain)
                        Spacer()
                    }
                }
                .padding(.top, MaplogSpacing.medium)
            }
            .padding(.horizontal, MaplogSpacing.xLarge)
            .padding(.top, MaplogSpacing.xLarge)
            .padding(.bottom, MaplogSpacing.xxxLarge)
            .navigationTitle("회원가입")
            .navigationBarTitleDisplayMode(.inline)
        }
        .background(Color.maplogSurface)
    }
}

//#Preview("회원가입 이동 흐름") {
//    NavigationStack {
//        NavigationLink("회원가입 화면 열기") {
//            SignupView()
//        }
//        .navigationTitle("로그인")
//    }
//}

#Preview("회원가입 화면") {
    NavigationStack {
        SignupView(authSessionStore: AuthSessionStore())
    }
}

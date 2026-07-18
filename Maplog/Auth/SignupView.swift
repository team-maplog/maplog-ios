//
//  SignupView.swift
//  Maplog
//
//  Created by 한채림 on 7/19/26.
//

import SwiftUI

struct SignupView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirmation = ""
    @State private var nickname = ""
    @State private var hasAcceptedTerms = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: MaplogSpacing.xLarge) {
                VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                    Text("이메일 주소")
                        .font(MaplogFont.bodyStrong)
                        .foregroundStyle(Color.maplogInk)

                    TextField("example@mail.com", text: $email)
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
                }

                VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                    Text("비밀번호")
                        .font(MaplogFont.bodyStrong)
                        .foregroundStyle(Color.maplogInk)

                    SecureField("8자 이상 입력해주세요", text: $password)
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
                }

                VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                    Text("비밀번호 확인")
                        .font(MaplogFont.bodyStrong)
                        .foregroundStyle(Color.maplogInk)

                    SecureField("비밀번호를 한 번 더 입력해주세요", text: $passwordConfirmation)
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
                }

                VStack(alignment: .leading, spacing: MaplogSpacing.xSmall) {
                    Text("닉네임")
                        .font(MaplogFont.bodyStrong)
                        .foregroundStyle(Color.maplogInk)

                    TextField("사용할 닉네임을 입력해주세요", text: $nickname)
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
                }

                VStack(spacing: MaplogSpacing.medium) {
                    Button {
                        hasAcceptedTerms.toggle()
                    } label: {
                        HStack(spacing: MaplogSpacing.small) {
                            Image(systemName: hasAcceptedTerms ? "checkmark" : "")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.maplogInk)
                                .frame(width: 24, height: 24)
                                .background(hasAcceptedTerms ? Color.maplogLime : Color.maplogSurface, in: Circle())
                                .overlay {
                                    Circle()
                                        .stroke(hasAcceptedTerms ? Color.maplogLime : Color.maplogOlive.opacity(0.38), lineWidth: 1)
                                }

                            Text("이용약관 및 개인정보 처리방침 동의 (필수)")
                                .font(MaplogFont.callout)
                                .foregroundStyle(Color.maplogInk)

                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: MaplogSize.minimumTapTarget)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("이용약관 및 개인정보 처리방침 동의")
                    .accessibilityValue(hasAcceptedTerms ? "동의함" : "동의하지 않음")

                    Button {
                        // API 연결 단계에서 회원가입 요청을 추가합니다.
                    } label: {
                        Text("가입 완료")
                    }
                    .buttonStyle(MaplogButtonStyle(variant: .primary, size: .large, fullWidth: true))

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
        SignupView()
    }
}

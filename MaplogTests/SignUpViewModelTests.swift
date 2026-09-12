import XCTest

@testable import Maplog

@MainActor
final class SignUpViewModelTests: XCTestCase {
    func testValidFormEnablesSubmission() {
        let viewModel = makeViewModel()

        fillValidForm(in: viewModel)

        SignUpField.allCases.forEach(viewModel.didFinishEditing)

        XCTAssertTrue(viewModel.canSubmit)
        XCTAssertNil(viewModel.emailError)
        XCTAssertNil(viewModel.passwordError)
        XCTAssertNil(viewModel.passwordConfirmationError)
        XCTAssertNil(viewModel.nicknameError)
    }

    func testChangingPasswordRevalidatesTouchedConfirmation() {
        let viewModel = makeViewModel()

        viewModel.password = "maplog!123"
        viewModel.passwordConfirmation = "maplog!123"
        viewModel.didFinishEditing(.passwordConfirmation)
        XCTAssertNil(viewModel.passwordConfirmationError)

        viewModel.password = "changed!123"

        XCTAssertEqual(
            viewModel.passwordConfirmationError,
            "비밀번호가 일치하지 않습니다."
        )
    }

    func testInvalidFormDoesNotRequestSignUp() async {
        let repository = SignUpAuthRepositorySpy()
        let viewModel = SignUpViewModel(
            authRepository: repository,
            authSession: SignUpAuthSessionSpy()
        )

        await viewModel.signUp()

        let signUpCallCount = await repository.signUpCallCount()
        XCTAssertEqual(signUpCallCount, 0)
        XCTAssertEqual(viewModel.emailError, "이메일을 입력해주세요.")
        XCTAssertEqual(viewModel.passwordError, "비밀번호를 입력해주세요.")
    }

    func testValidFormSendsCredentialsAndStartsSession() async {
        let repository = SignUpAuthRepositorySpy()
        let session = SignUpAuthSessionSpy()
        let viewModel = SignUpViewModel(
            authRepository: repository,
            authSession: session
        )
        fillValidForm(in: viewModel)

        await viewModel.signUp()

        let credentials = await repository.latestSignUpCredentials()
        XCTAssertEqual(credentials?.email, "chaerim@maplog.app")
        XCTAssertEqual(credentials?.nickname, "채림")
        XCTAssertEqual(session.replacedTokens.count, 1)
    }

    func testCommonValidationFailureMapsEachFieldMessage() {
        let error = APIError.server(
            statusCode: 400,
            response: APIErrorResponse(
                successFlag: false,
                code: "COMMON-014",
                message: "입력값이 올바르지 않습니다.",
                data: [
                    FieldValidationError(
                        field: "email",
                        rejectedValue: nil,
                        message: "이미 사용 중인 이메일입니다."
                    ),
                    FieldValidationError(
                        field: "nickname",
                        rejectedValue: nil,
                        message: "이미 사용 중인 닉네임입니다."
                    )
                ]
            )
        )

        let presentation = SignUpErrorPolicy.presentation(for: error)

        XCTAssertEqual(presentation.emailMessage, "이미 사용 중인 이메일입니다.")
        XCTAssertEqual(presentation.nicknameMessage, "이미 사용 중인 닉네임입니다.")
        XCTAssertNil(presentation.formMessage)
    }

    func testSuccessFeedbackAppearsOnlyAfterFinishingEachField() {
        let viewModel = makeViewModel()
        fillValidForm(in: viewModel)
        XCTAssertNil(viewModel.emailFeedback)
        XCTAssertNil(viewModel.passwordFeedback)
        XCTAssertNil(viewModel.passwordConfirmationFeedback)
        XCTAssertNil(viewModel.nicknameFeedback)

        SignUpField.allCases.forEach(viewModel.didFinishEditing)

        XCTAssertEqual(viewModel.emailFeedback, "올바른 이메일 형식입니다.")
        XCTAssertEqual(viewModel.passwordFeedback, "사용 가능한 비밀번호입니다.")
        XCTAssertEqual(viewModel.passwordConfirmationFeedback, "비밀번호가 일치합니다.")
        XCTAssertEqual(viewModel.nicknameFeedback, "올바른 닉네임 형식입니다.")
    }

    func testEditingAgainClearsPreviousSuccessUntilFinished() {
        let viewModel = makeViewModel()
        viewModel.email = "first@maplog.app"
        viewModel.didFinishEditing(.email)

        viewModel.email = "second@maplog.app"
        XCTAssertNil(viewModel.emailFeedback)
        viewModel.didFinishEditing(.email)
        XCTAssertEqual(viewModel.emailFeedback, "올바른 이메일 형식입니다.")

        viewModel.email = "invalid"
        XCTAssertEqual(viewModel.emailFeedback, "올바른 이메일 주소를 입력해주세요.")
    }

    func testPasswordChangeReplacesConfirmationSuccessWithMismatch() {
        let viewModel = makeViewModel()
        fillValidForm(in: viewModel)
        viewModel.didFinishEditing(.passwordConfirmation)
        XCTAssertEqual(viewModel.passwordConfirmationFeedback, "비밀번호가 일치합니다.")

        viewModel.password = "changed!123"
        XCTAssertEqual(viewModel.passwordConfirmationFeedback, "비밀번호가 일치하지 않습니다.")
    }

    func testEmptyFinishedFieldsShowErrorsInsteadOfSuccess() {
        let viewModel = makeViewModel()
        SignUpField.allCases.forEach(viewModel.didFinishEditing)
        XCTAssertEqual(viewModel.emailFeedback, viewModel.emailError)
        XCTAssertEqual(viewModel.passwordFeedback, viewModel.passwordError)
        XCTAssertEqual(viewModel.passwordConfirmationFeedback, viewModel.passwordConfirmationError)
        XCTAssertEqual(viewModel.nicknameFeedback, viewModel.nicknameError)
        XCTAssertNotNil(viewModel.emailFeedback)
        XCTAssertNotNil(viewModel.nicknameFeedback)
    }

    private func makeViewModel() -> SignUpViewModel {
        SignUpViewModel(
            authRepository: SignUpAuthRepositorySpy(),
            authSession: SignUpAuthSessionSpy()
        )
    }

    private func fillValidForm(in viewModel: SignUpViewModel) {
        viewModel.email = "chaerim@maplog.app"
        viewModel.password = "maplog!123"
        viewModel.passwordConfirmation = "maplog!123"
        viewModel.nickname = "채림"
        viewModel.toggleTermsAgreement()
        viewModel.togglePrivacyPolicyAgreement()
    }
}

private actor SignUpAuthRepositorySpy: AuthRepository {
    private var credentials: [SignUpCredentials] = []

    func signUp(
        credentials: SignUpCredentials
    ) async throws -> AuthToken {
        self.credentials.append(credentials)
        return AuthToken(
            accessToken: "test-access-token",
            refreshToken: "test-refresh-token"
        )
    }

    func signIn(
        credentials: SignInCredentials
    ) async throws -> AuthToken {
        AuthToken(
            accessToken: "test-access-token",
            refreshToken: "test-refresh-token"
        )
    }

    func signOut() async throws { }

    func reissueToken() async throws -> AuthToken {
        AuthToken(
            accessToken: "test-access-token",
            refreshToken: "test-refresh-token"
        )
    }

    func signUpCallCount() -> Int {
        credentials.count
    }

    func latestSignUpCredentials() -> SignUpCredentials? {
        credentials.last
    }
}

@MainActor
private final class SignUpAuthSessionSpy: AuthSessionManaging {
    private(set) var replacedTokens: [AuthToken] = []

    func currentAccessToken() throws -> String? {
        nil
    }

    func currentRefreshToken() throws -> String? {
        nil
    }

    func startSession(with token: AuthToken) throws {
        replacedTokens.append(token)
    }

    func replaceTokens(
        with token: AuthToken
    ) throws {
        replacedTokens.append(token)
    }

    func endSession() throws { }
}

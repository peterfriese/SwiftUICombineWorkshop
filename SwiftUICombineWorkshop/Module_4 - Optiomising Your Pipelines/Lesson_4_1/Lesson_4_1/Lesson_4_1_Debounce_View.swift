/// Lesson 4.1: Using the `debounce` operator to avoid spamming the server by sending requests only when the user stops typing
///
/// Steps:
/// 1. Add the `debounce` operator to all pipelines that map user input to network calls

import SwiftUI
import Combine

private enum AuthenticationState {
    case unauthenticated
    case authenticating
    case authenticated
}

private struct UserNameAvailableMessage: Codable {
    var isAvailable: Bool
    var userName: String
}

private enum NetworkError: Error {
    case transportError(Error)
    case serverError(statusCode: Int)
    case noData
    case decodingError(Error)
    case encodingError(Error)
}

private enum PasswordCheck {
    case valid
    case empty
    case noMatch
    case notLongEnough
}


private class SignupViewModel: ObservableObject {
    // MARK: - Input
    @Published var username = ""
    @Published var password = ""
    @Published var confirmPassword  = ""
    
    // MARK: - Output
    @Published var isUsernameValid = false
    @Published var isUsernameAvailable = false
    @Published var isPasswordEmpty = true
    @Published var isPasswordMatched = false
    @Published var isPasswordLengthSufficient = false
    @Published var isValid  = false
    @Published var errorMessage  = ""
    @Published var authenticationState = AuthenticationState.unauthenticated
    
    lazy var isPasswordValidPublisher: AnyPublisher<PasswordCheck, Never>  = {
        Publishers.CombineLatest3($isPasswordEmpty, $isPasswordMatched, $isPasswordLengthSufficient)
            .map { (isPasswordEmpty, isPasswordMatched, isPasswordLengthSufficient) in
                if isPasswordEmpty {
                    return .empty
                }
                else if !isPasswordMatched {
                    return .noMatch
                }
                else if !isPasswordLengthSufficient {
                    return .notLongEnough
                }
                else {
                    return .valid
                }
            }
            .eraseToAnyPublisher()
    }()

    init() {
        $username
            .map { value in
                value.count >= 3
            }
            .assign(to: &$isUsernameValid)
        
        $username
            .debounce(for: 0.8, scheduler: DispatchQueue.main)
            .flatMap { value in
                self.checkUserNameAvailable(userName: value)
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$isUsernameAvailable)
        
        $password
            .map { $0.isEmpty }
            .assign(to: &$isPasswordEmpty)
        
        $password
            .combineLatest($confirmPassword)
            .map { (password, confirmPassword) in
                password == confirmPassword
            }
            .assign(to: &$isPasswordMatched)
        
        $password
            .map { $0.count >= 6 }
            .assign(to: &$isPasswordLengthSufficient)
        
        Publishers.CombineLatest3($isUsernameValid, $isUsernameAvailable, isPasswordValidPublisher)
            .map { (isUsernameValid, isUsernameAvailable, isPasswordValid) in
                isUsernameValid && isUsernameAvailable && (isPasswordValid == .valid)
            }
            .assign(to: &$isValid)
        
        Publishers.CombineLatest3($isUsernameValid, $isUsernameAvailable, isPasswordValidPublisher)
            .map { isUsernameValid, isUsernameAvailable, isPasswordValid in
                if !isUsernameValid {
                    return "Username is invalid. Must be more than 2 characters"
                }
                else if !isUsernameAvailable {
                    return "This username is not available!"
                }
                else if isPasswordValid != .valid {
                    switch isPasswordValid {
                    case .noMatch:
                        return "Passwords don't match"
                    case .empty:
                        return "Password must not be empty"
                    case .notLongEnough:
                        return "Password not long enough. Must at least be 6 characters"
                    default:
                        return ""
                    }
                }
                else {
                    return ""
                }
            }
            .assign(to: &$errorMessage)
    }
    
    func checkUserNameAvailable(userName: String) -> AnyPublisher<Bool, Never> {
        guard let url = URL(string: "http://127.0.0.1:8080/isUserNameAvailable?userName=\(userName)") else {
            return Just(false).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: UserNameAvailableMessage.self, decoder: JSONDecoder())
            .map(\.isAvailable)
            .replaceError(with: false)
            .eraseToAnyPublisher()
    }
    
}

private enum FocusableField: Hashable {
    case username
    case password
    case confirmPassword
}

struct Lesson_4_1_Debounce_View: View {
    @StateObject fileprivate var viewModel = SignupViewModel()
    
    @FocusState private var focus: FocusableField?
    
    var heroImage: some View {
        Image("SignUp")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(minHeight: 100)
    }
    
    var title: some View {
        Text("Sign up")
            .font(.largeTitle)
            .fontWeight(.bold)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    var errorLabel: some View {
        Group {
            if !viewModel.errorMessage.isEmpty {
                HStack {
                    Text(viewModel.errorMessage)
                        .foregroundColor(Color(UIColor.systemRed))
                    Spacer()
                }
            }
            else {
                EmptyView()
            }
        }
    }
    
    var signupButton: some View {
        Button(action: {} ) {
            if viewModel.authenticationState != .authenticating {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .frame(maxWidth: .infinity)
            }
        }
        .disabled(!viewModel.isValid)
        .frame(maxWidth: .infinity)
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
    
    var loginInstead: some View {
        HStack {
            Text("Already have an account?")
            Button(action: {}) {
                Text("Login")
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
        }
        .padding([.top, .bottom], 50)
    }
    
    var body: some View {
        VStack {
            heroImage
            title
            
            FormRow(systemImage: "person") {
                TextField("Username", text: $viewModel.username)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .focused($focus, equals: .username)
                    .submitLabel(.next)
                    .onSubmit {
                        self.focus = .password
                    }
            }
            
            FormRow(systemImage: "lock") {
                SecureField("Password", text: $viewModel.password)
                    .focused($focus, equals: .password)
                    .submitLabel(.next)
                    .onSubmit {
                        self.focus = .confirmPassword
                    }
            }
            
            FormRow(systemImage: "lock") {
                SecureField("Confirm password", text: $viewModel.confirmPassword)
                    .focused($focus, equals: .confirmPassword)
                    .submitLabel(.go)
                    .onSubmit {
                        // signUpWithEmailPassword()
                    }
            }
            
            errorLabel
            signupButton
            loginInstead
        }
        .padding(.horizontal, 32)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Lesson_4_1_Debounce_View()
    }
}

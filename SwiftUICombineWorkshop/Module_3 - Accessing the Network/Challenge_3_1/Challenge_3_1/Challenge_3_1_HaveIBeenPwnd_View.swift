/// Challenge 4.1: Call the HaveIBeenPwned API to find out if the provided password has been compromised.
///
/// Steps:
/// 1. Introduce a new published property `isPasswordPwned`
/// 2. Create a new function `checkHaveIBeenPwned` that calls `https://api.pwnedpasswords.com/range/` to check
///    if the provided password has been compromised
/// 3. Enhance the pipelines that drive `isValid` and `errorMessage` to include events sent from `checkHaveIBeenPwned`

import SwiftUI
import Combine
import CommonCrypto

extension String {
    func sha1() -> String {
        let data = Data(self.utf8)
        var digest = [UInt8](repeating: 0, count:Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &digest)
        }
        let hexBytes = digest.map { String(format: "%02hhx", $0) }
        return hexBytes.joined()
    }
}

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
    @Published var isPasswordPwned = false
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
            .flatMap { value in
                self.checkUserNameAvailable(userName: value)
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$isUsernameAvailable)
        
        $password
            .dropFirst()
            .removeDuplicates()
            .flatMap { value in
                self.checkHaveIBeenPwned(password: value)
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$isPasswordPwned)
        
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
        
        Publishers.CombineLatest4($isUsernameValid, $isUsernameAvailable, isPasswordValidPublisher, $isPasswordPwned)
            .map { (isUsernameValid, isUsernameAvailable, isPasswordValid, isPasswordPwned) in
                isUsernameValid && isUsernameAvailable && (isPasswordValid == .valid) && !isPasswordPwned
            }
            .assign(to: &$isValid)
        
        Publishers.CombineLatest4($isUsernameValid, $isUsernameAvailable, isPasswordValidPublisher, $isPasswordPwned)
            .map { isUsernameValid, isUsernameAvailable, isPasswordValid, isPasswordPwned in
                if !isUsernameValid {
                    return "Username is invalid. Must be more than 2 characters"
                }
                else if !isUsernameAvailable {
                    return "This username is not available!"
                }
                else if isPasswordPwned {
                    return "This password has been compromised before. Choose another one!"
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
    
    func checkHaveIBeenPwned(password: String) -> AnyPublisher<Bool, Never> {
        let hash = password.sha1().uppercased()
        let prefix = hash.prefix(5)
        let index = hash.index(hash.startIndex, offsetBy: 5)
        let suffix = hash.suffix(from: index)
        print("password: \(password) | hash: \(hash) | prefix: \(prefix) | suffix: \(suffix)")
        
        guard let url = URL(string: "https://api.pwnedpasswords.com/range/\(prefix)") else {
            return Just(false).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .tryMap { data in
                String(decoding: data, as: UTF8.self)
            }
            .map { pwnedPasswords in
                pwnedPasswords.contains(suffix)
            }
            .replaceError(with: false)
            .eraseToAnyPublisher()
    }
}

private enum FocusableField: Hashable {
    case username
    case password
    case confirmPassword
}

struct Challenge_3_1_HaveIBeenPwnd_View: View {
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
        Challenge_3_1_HaveIBeenPwnd_View()
    }
}

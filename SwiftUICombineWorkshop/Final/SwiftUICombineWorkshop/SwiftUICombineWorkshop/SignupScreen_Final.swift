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

private extension Publisher {
  func asResult() -> AnyPublisher<Result<Output, Failure>, Never> {
    self
      .map(Result.success)
      .catch { error in
        Just(.failure(error))
      }
      .eraseToAnyPublisher()
  }
}

typealias Available = Result<Bool, Error>

private enum AuthenticationState {
    case unauthenticated
    case authenticating
    case authenticated
}

private struct UserNameAvailableMessage: Codable {
    var isAvailable: Bool
    var userName: String
}

struct APIErrorMessage: Decodable {
  var error: Bool
  var reason: String
}

enum APIError: LocalizedError {
  case invalidRequestError(String)
  case transportError(Error)
  case invalidResponse
  case validationError(String)
  case decodingError(Error)
  case serverError(statusCode: Int, reason: String? = nil, retryAfter: String? = nil)

  var errorDescription: String? {
    switch self {
    case .invalidRequestError(let message):
      return "Invalid request: \(message)"
    case .transportError(let error):
      return "Transport error: \(error)"
    case .invalidResponse:
      return "Invalid response"
    case .validationError(let reason):
      return "Validation Error: \(reason)"
    case .decodingError:
      return "The server returned data in an unexpected format. Try updating the app."
    case .serverError(let statusCode, let reason, let retryAfter):
      return "Server error with code \(statusCode), reason: \(reason ?? "no reason given"), retry after: \(retryAfter ?? "no retry after provided")"
    }
  }
}

private enum PasswordCheck {
    case valid
    case empty
    case noMatch
    case notLongEnough
}

private class LoginViewModel: ObservableObject {
    // MARK: - Input
    @Published var username = ""
    @Published var password = ""
    @Published var confirmPassword  = ""
    
    // MARK: - Output
    @Published var isUsernameValid = false
    @Published var isPasswordEmpty = true
    @Published var isPasswordMatched = false
    @Published var isPasswordLengthSufficient = false
    @Published var isPasswordPwned = false
    @Published var isValid  = false
    @Published var errorMessage  = ""
    @Published var authenticationState = AuthenticationState.unauthenticated
    
    lazy var isUsernameAvailablePublisher: AnyPublisher<Available, Never> = {
        $username
            .print("1: ")
            .dropFirst()
            .debounce(for: 0.8, scheduler: DispatchQueue.main)
            .removeDuplicates()
            .print("2: ")
            .flatMap { value in
                self.checkUserNameAvailable(userName: value)
                    .asResult()
            }
            .receive(on: DispatchQueue.main)
            .share()
            .eraseToAnyPublisher()
    }()
    
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
    
    lazy var isFormValidPublisher: AnyPublisher<Bool, Never> = {
        isUsernameAvailablePublisher
            .map { result -> Bool in
                if case .failure(let error) = result {
                    if case APIError.transportError(_) = error {
                        return true
                    }
                    return false
                }
                if case .success(let isAvailable) = result {
                    return isAvailable
                }
                return true
            }
            .print("isUsernameAvailablePublisher")
            .combineLatest($isUsernameValid, isPasswordValidPublisher, $isPasswordPwned) { (isUsernameAvailable, isUsernameValid, isPasswordValid, isPasswordPwned) in
                isUsernameAvailable && isUsernameValid && (isPasswordValid == .valid) && !isPasswordPwned
            }
            .print("isFormValidPublisher")
            .eraseToAnyPublisher()
    }()
    
    lazy var errorMessagePublisher: AnyPublisher<String, Never> = {
        isUsernameAvailablePublisher
            .map { result -> String in
                switch result {
                case .failure(let error):
                    if case APIError.transportError(_) = error {
                        return ""
                    }
                    else if case APIError.validationError(let reason) = error {
                        return reason
                    }
                    else {
                        return error.localizedDescription
                    }
                case .success(let isAvailable):
                    return isAvailable ? "" : "This username is not available"
                }
            }
            .combineLatest($isUsernameValid, isPasswordValidPublisher, $isPasswordPwned) { isUsernameAvailableMessage, isUsernameValid, isPasswordValid, isPasswordPwned in
                if !isUsernameAvailableMessage.isEmpty {
                    return isUsernameAvailableMessage
                }
                else if !isUsernameValid {
                    return "Username is invalid. Must be more than 2 characters"
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
            .eraseToAnyPublisher()
    }()
    
    init() {
        $username
            .map { value in
                value.count >= 3
            }
            .assign(to: &$isUsernameValid)
        
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
        
        isFormValidPublisher
            .assign(to: &$isValid)
        
        errorMessagePublisher
            .assign(to: &$errorMessage)
    }
    
    func checkUserNameAvailable(userName: String) -> AnyPublisher<Bool, Error> {
        guard let url = URL(string: "http://127.0.0.1:8080/isUserNameAvailable?userName=\(userName)") else {
            return Fail(error: APIError.invalidRequestError("URL invalid"))
                .eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            // handle URL errors (most likely not able to connect to the server)
            .mapError { error -> Error in
                return APIError.transportError(error)
            }
        
            // handle all other errors
            .tryMap { (data, response) -> (data: Data, response: URLResponse) in
                print("Received response from server, now checking status code")
                
                guard let urlResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }
                
                if (200..<300) ~= urlResponse.statusCode {
                }
                else {
                    let decoder = JSONDecoder()
                    let apiError = try decoder.decode(APIErrorMessage.self,
                                                      from: data)
                    
                    if urlResponse.statusCode == 400 {
                        throw APIError.validationError(apiError.reason)
                    }
                }
                return (data, response)
            }
            .map(\.data)
            .decode(type: UserNameAvailableMessage.self, decoder: JSONDecoder())
            .map(\.isAvailable)
            .print()
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

struct SignupScreen_Final: View {
    @StateObject fileprivate var viewModel = LoginViewModel()
    
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

struct SignupScreen_Final_Previews: PreviewProvider {
    static var previews: some View {
        SignupScreen_Final()
    }
}

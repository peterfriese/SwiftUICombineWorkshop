/// Lesson 3.1: Fetching data with URLSession, and using callbacks to return the data to the caller
///
/// Walkthrough:
/// 1. We use `LoginViewModel.checkUserNameAvailable` to fetch data
/// 2. `checkUserNameAvailable` has a completion handler which we use to return the data to the caller
/// 3. Inside `SignupViewModel.init`, we set up another pipeline to map `username` to `isUsernameAvailable`
/// 4. This pipeline uses `flatMap` to call `checkUserNameAvailable`
/// 5. To bridge between the Combine pipeline and the callback handler, we use a `Future`
/// 6. In the next lesson, we will look at how to use Combine to make network calls

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
            .flatMap { value in
                Future { promise in
                    self.checkUserNameAvailable(userName: value) { result in
                        promise(result)
                    }
                }
                .replaceError(with: false)
            }
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
    
    func checkUserNameAvailable(userName: String, completion: @escaping (Result<Bool, NetworkError>) -> Void) {
        let url = URL(string: "http://127.0.0.1:8080/isUserNameAvailable?userName=\(userName)")!
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(.transportError(error)))
                return
            }
            
            if let response = response as? HTTPURLResponse, !(200...299).contains(response.statusCode) {
                completion(.failure(.serverError(statusCode: response.statusCode)))
                return
            }
            
            guard let data = data else {
                completion(.failure(.noData))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let userAvailableMessage = try decoder.decode(UserNameAvailableMessage.self, from: data)
                completion(.success(userAvailableMessage.isAvailable))
            }
            catch {
                completion(.failure(.decodingError(error)))
            }
        }
        
        task.resume()
    }
}

private enum FocusableField: Hashable {
    case username
    case password
    case confirmPassword
}


struct Lesson_3_1_NetworkURLSession_View: View {
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
        Lesson_3_1_NetworkURLSession_View()
    }
}

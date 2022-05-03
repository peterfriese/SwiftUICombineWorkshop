/// Lesson 2.3: Display validation messages
///
/// Steps:
/// 1. For each of the password publishers, create a pipeline that maps the bool to an error message
/// 2. Observe: this does't yield the expected result
///
/// 3. Use `Publishers.CombineLatest3` instead and process the inputs in the order they appear on screen

import SwiftUI
import Combine

private enum AuthenticationState {
    case unauthenticated
    case authenticating
    case authenticated
}

private class SignupViewModel: ObservableObject {
    // MARK: - Input
    @Published var username = ""
    @Published var password = ""
    @Published var confirmPassword  = ""
    
    // MARK: - Output
    @Published var isUsernameValid = false
    @Published var isPasswordEmpty = true
    @Published var isPasswordMatched = false
    @Published var isValid  = false
    @Published var errorMessage  = ""
    @Published var authenticationState = AuthenticationState.unauthenticated
    
    init() {
        $username
            .map { value in
                value.count >= 3
            }
            .assign(to: &$isUsernameValid)
        
        $password
            .map { $0.isEmpty }
            .assign(to: &$isPasswordEmpty)
        
        $password
            .combineLatest($confirmPassword)
            .map { (password, confirmPassword) in
                password == confirmPassword
            }
            .assign(to: &$isPasswordMatched)
        
        Publishers.CombineLatest3($isUsernameValid, $isPasswordEmpty, $isPasswordMatched)
            .map { (isUsernameValid, isPasswordEmpty, isPasswordMatched) in
                isUsernameValid && !isPasswordEmpty && isPasswordMatched
            }
            .assign(to: &$isValid)
        
        // running pipelines on each individual publisher doesn't result in the desired outcome...
        
//        $isPasswordMatched
//            .map { !$0 ? "Passwords don't match" : ""  }
//            .assign(to: &$errorMessage)
//
//        $isPasswordEmpty
//            .map { $0 ? "Password must not be empty" : "" }
//            .assign(to: &$errorMessage)
//
//        $isUsernameValid
//            .map { !$0 ? "Username is invalid. Must be more than 2 characters" : "" }
//            .assign(to: &$errorMessage)
        
        Publishers.CombineLatest3($isUsernameValid, $isPasswordEmpty, $isPasswordMatched)
            .map { isUsernameValid, isPasswordEmpty, isPasswordMatched in
                if !isUsernameValid {
                    return "Username is invalid. Must be more than 2 characters"
                }
                else if isPasswordEmpty {
                    return "Password must not be empty"
                }
                else if !isPasswordMatched {
                    return "Passwords don't match"
                }
                else {
                    return ""
                }
            }
            .assign(to: &$errorMessage)
    }
}

private enum FocusableField: Hashable {
    case username
    case password
    case confirmPassword
}

struct Lesson_2_3_ShowErrorMessages_View: View {
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
        Lesson_2_3_ShowErrorMessages_View()
    }
}

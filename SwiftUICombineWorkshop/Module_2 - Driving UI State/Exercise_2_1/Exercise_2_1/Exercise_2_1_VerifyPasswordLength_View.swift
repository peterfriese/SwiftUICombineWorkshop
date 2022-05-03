/// Exercise 2.1: Verify the password has at least 6 characters
///
/// Steps:
/// 1. Add another pipeline to verify the password has at least 6 characters
/// 2. Update the pipelines that drive the `isValid` and `errorMessage` properties to include the
///    result of the new pipeline as well (hint: use `CombineLatest4`)

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
    @Published var isPasswordLengthSufficient = false
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
        
        $password
            .map { $0.count >= 6 }
            .assign(to: &$isPasswordLengthSufficient)
        
        Publishers.CombineLatest4($isUsernameValid, $isPasswordEmpty, $isPasswordMatched, $isPasswordLengthSufficient)
            .map { (isUsernameValid, isPasswordEmpty, isPasswordMatched, isPasswordLengthSufficient) in
                isUsernameValid && !isPasswordEmpty && isPasswordMatched && isPasswordLengthSufficient
            }
            .assign(to: &$isValid)
        
        Publishers.CombineLatest4($isUsernameValid, $isPasswordEmpty, $isPasswordMatched, $isPasswordLengthSufficient)
            .map { isUsernameValid, isPasswordEmpty, isPasswordMatched, isPasswordLengthSufficient in
                if !isUsernameValid {
                    return "Username is invalid. Must be more than 2 characters"
                }
                else if isPasswordEmpty {
                    return "Password must not be empty"
                }
                else if !isPasswordLengthSufficient {
                    return "Password must have at least 6 characters!"
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

struct Exercise_2_1_VerifyPasswordLength_View: View {
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
        Exercise_2_1_VerifyPasswordLength_View()
    }
}

/// Exercise: Display the length (in characters) of the username the user enters
///
/// Steps:
/// 1. Add a published property to the view model
/// 2. Use string interpolation to display the value of the property in the output `Text` view
/// 3. Create another Combine pipeline on `$username` that determines the character count and assigns the
///    result to the published property

import SwiftUI

private class ViewModel: ObservableObject {
    @Published var username: String = ""
    @Published var isUsernameValid: Bool
    @Published var numberOfCharacters = 0
    
    init() {
        isUsernameValid = false
        $username
            .map { value in
                value.count >= 3
            }
            .assign(to: &$isUsernameValid)
        
        $username
            .map { value in
                value.count
            }
            .assign(to: &$numberOfCharacters)
    }
}

struct Exercise_1_1_ShowCharacterCount_View: View {
    @StateObject fileprivate var viewModel = ViewModel()
    
    var body: some View {
        VStack(alignment: .leading) {
            TextField("Username", text: $viewModel.username)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
            Text("You entered [\(viewModel.username)]")
            Text("This username has **\(viewModel.numberOfCharacters) characters** and is **\(viewModel.isUsernameValid ? "valid" : "not valid")**")
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Exercise_1_1_ShowCharacterCount_View()
    }
}

/// Lesson 1.3: Set up a Combine pipeline to determine whether the username is valid
///
/// Steps:
/// 1. Create an initialiser in the view model
/// 2. Set up a Combine pipeline on `$username` that determines whether the character count is at least 3
/// 3. Assing the result of the pipeline to `$isUsernameValid`
/// 4. Remove the `onChange(of:)` view modifier

import SwiftUI

private class ViewModel: ObservableObject {
    @Published var username: String = ""
    @Published var isUsernameValid = false
    
    init() {
        $username
            .map { value in
                value.count >= 3
            }
            .assign(to: &$isUsernameValid)
    }
}

struct Lesson_1_3_SimplePipeline_View: View {
    @StateObject fileprivate var viewModel = ViewModel()
    
    var body: some View {
        VStack(alignment: .leading) {
            TextField("Username", text: $viewModel.username)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
            Text("You entered [\(viewModel.username)]")
            Text("This username is **\(viewModel.isUsernameValid ? "valid" : "not valid")**")
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Lesson_1_3_SimplePipeline_View()
    }
}

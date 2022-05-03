/// Lesson 1.2: Use a view model to determine whether the username is valid
///
/// Steps:
/// 1. Introduce a private view model (conforming to `ObservableObject`)
/// 2. Move both `@State` properties into the view model, making them `@Published`
/// 3. Instantiate the view model as a `@StateObject`
/// 4. Update the view to make use of the properties in the view model

import SwiftUI

private class ViewModel: ObservableObject {
    @Published var username: String = ""
    @Published var isUsernameValid = false
}

struct Lesson_1_2_ViewModel_View: View {
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
        .onChange(of: viewModel.username) { newValue in
            viewModel.isUsernameValid = newValue.count >= 3
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Lesson_1_2_ViewModel_View()
    }
}

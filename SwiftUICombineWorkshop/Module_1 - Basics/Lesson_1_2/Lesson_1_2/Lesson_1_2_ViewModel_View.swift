/// Lesson 1.2: Use a view model to determine whether the username is valid
///
/// Steps:
/// 1. Introduce a private view model (conforming to `ObservableObject`)
/// 2. Move both `@State` properties into the view model, making them `@Published`
/// 3. Instantiate the view model as a `@StateObject`
/// 4. Update the view to make use of the properties in the view model

import SwiftUI

struct Lesson_1_2_ViewModel_View: View {
    @State var username: String = ""
    @State var isUsernameValid = false
    
    var body: some View {
        VStack(alignment: .leading) {
            TextField("Username", text: $username)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
            Text("You entered [\(username)]")
            Text("This username is **\(isUsernameValid ? "valid" : "not valid")**")
        }
        .padding()
        .onChange(of: username) { newValue in
            isUsernameValid = newValue.count >= 3
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Lesson_1_2_ViewModel_View()
    }
}

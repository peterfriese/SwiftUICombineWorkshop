/// Lesson 1.1: Use the `onChange(of:)` view modifier to determine whether the username the
/// user entered has at least 3 characters.
///
/// Steps:
/// 1. Add a new `@State` property to the view to express whether the username is valid
/// 2. Add a new `Text` that shows a text saying whether the username is valid
/// 3. Use the `onChange(of:)` view modifier to update the `@State` property whenever
///    the `username` property changes

import SwiftUI

struct Lesson_1_1_OnChangeOf_View: View {
    @State var username: String = ""
    
    var body: some View {
        VStack(alignment: .leading) {
            TextField("Username", text: $username)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
            Text("You entered [\(username)]")
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Lesson_1_1_OnChangeOf_View()
    }
}

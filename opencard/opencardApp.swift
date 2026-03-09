import SwiftUI

@main
struct opencardApp: App {
    // Ta linia musi tu być! Nasłuchuje zmian w pamięci telefonu.
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false

    var body: some Scene {
        WindowGroup {
            // Jeśli isLoggedIn zmieni się na true w LoginView,
            // ten blok kodu natychmiast podmieni widok.
            if isLoggedIn {
                HomeView()
            } else {
                LoginView()
            }
        }
    }
}

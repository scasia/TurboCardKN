import SwiftUI

// --- MODELE ---
struct LoginResponse: Codable {
    let idOsoby: Int
    let typKarty: String
    let typKartyNazwa: String
    let hashKarty: String
    let numerKarty: String
    let urlTlaKarty1Plan: String?
    let urlTlaKarty2Plan: String?
    let urlTlaKarty3Plan: String?
}

struct LoginView: View {
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @AppStorage("userHash") var userHash: String = ""
    
    // Obsługa popupa przy pierwszym uruchomieniu
    @AppStorage("hasSeenWarning") var hasSeenWarning: Bool = false
    @State private var showFirstRunAlert = false
    
    // Stan akceptacji regulaminu/ticka
    @State private var isAccepted = true
    
    @State private var selectedDomain = "mojakn.pl"
    @State private var email = ""
    @State private var password = ""
    @State private var isLoggingIn = false
    @State private var errorMessage: String?
    
    let domains = ["mojakn.pl"]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Serwer")) {
                    Picker("Domena", selection: $selectedDomain) {
                        ForEach(domains, id: \.self) { Text($0) }
                    }
                }

                Section(header: Text("Poświadczenia")) {
                    TextField("Email / Login", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    SecureField("Hasło", text: $password)
                }
                
                // --- SEKCJA AKCEPTACJI (TICK) ---
                Section {
                    Toggle(isOn: $isAccepted) {
                        Text("Zapoznałxm się z plikiem README na GitHubie projektu i rozumiem, że aplikacja jest zwykłym PoC napisanym w Gemini. Nie oczekuję, że moje dane będą bezpieczne. Rozumiem również, że korzystając z tej aplikacji, mogę łamać regulamin aplikacji MojaKN, co może skutkować banem. Korzystam z niej na własną odpowiedzialność.")
                            .font(.subheadline)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }

                Section {
                    Button(action: { Task { await login() } }) {
                        if isLoggingIn {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Zaloguj")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    // PRZYCISK WYŁĄCZONY JEŚLI TICK NIE JEST ZAZNACZONY
                    .disabled(isLoggingIn || email.isEmpty || password.isEmpty || !isAccepted)
                }
            }
            .navigationTitle("TurboCardKN project")
            // LOGIKA POKAZYWANIA POPUPA
            .onAppear {
                if !hasSeenWarning {
                    showFirstRunAlert = true
                }
            }
            .alert(isPresented: $showFirstRunAlert) {
                Alert(
                    title: Text("PRZECZYTAJ TO!"),
                    message: Text("""
            Ta aplikacja jest hobbystycznym, nieoficjalnym klientem systemu MojaKN, którego celem jest stworzenie lekkiej i szybkiej alternatywy dla oficjalnej aplikacji. 

            Obecna wersja została w około 80% napisana przy pomocy Gemini i ma charakter proof-of-concept. W przyszłości planowany jest pełny rewrite projektu.

            Projekt nie zawiera żadnego kodu skopiowanego z oficjalnej aplikacji MojaKN. Podczas jego tworzenia nie przeprowadzono dekompilacji ani inżynierii wstecznej oryginalnej aplikacji. Aplikacja nie służy do nadużywania systemu i wymaga posiadania pełnoprawnego konta użytkownika.

            Aplikacja może zawierać błędy i nie jest gwarantowana jej niezawodność. Może również w dowolnym momencie przestać działać w wyniku zmian po stronie usług MojaKN. Autorka nie ponosi odpowiedzialności za niezarejestrowane bilety komunikacyjne lub parkingowe, blokady kont użytkowników ani jakiekolwiek inne problemy wynikające z korzystania z aplikacji.

            Projekt nie jest w żaden sposób powiązany ani wspierany przez miasto Nowy Sącz, MPK Nowy Sącz, qb sp. z o.o., projekt OneCard ani żadnych ich partnerów.

            Autorka nie czerpie żadnych korzyści finansowych z tworzenia tej aplikacji. 

            Razem zbudujmy turbo polskę!

            """),
                    dismissButton: .default(Text("Rozumiem, chcę skorzystać z aplikacji."), action: {
                        hasSeenWarning = true
                    })
                )
            }
        }
        .navigationViewStyle(.stack)
    }

    // --- LOGIKA LOGOWANIA ---
    func login() async {
        isLoggingIn = true
        errorMessage = nil
        
        var components = URLComponents()
        components.scheme = "https"
        components.host = selectedDomain
        components.path = "/kartyMobileEndpoint.qbpage"
        components.queryItems = [
            URLQueryItem(name: "action", value: "LOGIN"),
            URLQueryItem(name: "login", value: email),
            URLQueryItem(name: "password", value: password),
            URLQueryItem(name: "iLogin", value: "doIt"),
            URLQueryItem(name: "setLanguage", value: "pl"),
            URLQueryItem(name: "systemInfo", value: "ios")
        ]

        guard let url = components.url else {
            isLoggingIn = false
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            guard let responseString = String(data: data, encoding: .utf8) else {
                errorMessage = "Błąd dekodowania odpowiedzi."
                isLoggingIn = false
                return
            }

            if responseString.contains("BRAK_KLIENTA") {
                errorMessage = "Błędny login lub hasło."
            } else {
                let decodedData = try JSONDecoder().decode(LoginResponse.self, from: data)
                
                await MainActor.run {
                    self.userHash = decodedData.hashKarty
                    self.isLoggedIn = true
                }
            }
        } catch {
            errorMessage = "Błąd połączenia z serwerem."
        }
        
        isLoggingIn = false
    }
}
#Preview {
    LoginView()
}

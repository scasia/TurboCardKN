import SwiftUI

// 1. Model odpowiedzi
struct MPKResponse: Codable {
    let status: String
    let tytulKomunikatu: String
    let trescKomunikatu: String
}

struct TicketView: View {
    @State private var isScanning = false
    @State private var isProcessing = false
    @State private var scanResult = ""
    @State private var apiStatus = "Zeskanuj kod QR z autobusu"
    @State private var lastResponse: MPKResponse?
    @AppStorage("userHash") var userHash = ""

    let domain = "mojakn.pl"
    
    let importantNote = "UWAGA! TYLKO SKANOWANIE BILETÓW. ToS MPK WYMAGA ORYGINALNEJ APLIKACJI. W PRZYPADKU KONTROLI BILETOW, URUCHOM ORYGINALNA MOJAKN. Nie martw się, bilety zeskanowane tutaj, pojawią się również tam."


    var body: some View {
        VStack(spacing: 20) {
            // Nagłówek statusu
            VStack(spacing: 10) {
                Text(apiStatus)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                if let response = lastResponse {
                    Text(response.status == "SUKCES" ? "✅" : "❌")
                        .font(.system(size: 50))
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(15)
            .padding(.horizontal)

            // --- SEKCJA NA WAŻNĄ WIADOMOŚĆ (BOLD) ---
            
            .padding(.horizontal)
            // ---------------------------------------

            if isScanning {
                ScannerView { result in
                    if !isProcessing {
                        isProcessing = true
                        self.scanResult = result
                        self.isScanning = false
                        
                        Task {
                            await handleScannedQR(qrText: result)
                            try? await Task.sleep(nanoseconds: 2 * 1000_000_000)
                            isProcessing = false
                        }
                    }
                }
                .frame(height: 300)
                .cornerRadius(15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.red, lineWidth: 4)
                )
                .padding()
                
                Button("Anuluj") {
                    isScanning = false
                }
                .foregroundColor(.red)
                
            } else {
                Button(action: {
                    lastResponse = nil
                    apiStatus = "Skanowanie..."
                    isScanning = true
                }) {
                    VStack(spacing: 15) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 60))
                        Text("ZESKANUJ KOD QR")
                            .fontWeight(.bold)
                    }
                    .frame(width: 250, height: 250)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .clipShape(Circle())
                    .shadow(radius: 10)
                }
                .disabled(isProcessing)
            }
            VStack {
                Text(importantNote)
                    .font(.system(size: 14, weight: .black)) // Extra bold
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.red, lineWidth: 2)
                    )
            }
            Spacer()
        }
        .navigationTitle("Bilet MPK")
    }

    func handleScannedQR(qrText: String) async {
        await MainActor.run { apiStatus = "Łączenie z serwerem..." }
        
        var components = URLComponents()
        components.scheme = "https"
        components.host = domain
        components.path = "/kartyMobileEndpoint.qbpage"
        components.queryItems = [
            URLQueryItem(name: "action", value: "OBSLUZ_ZESKANOWANY_QR"),
            URLQueryItem(name: "hash", value: userHash),
            URLQueryItem(name: "qr", value: qrText),
            URLQueryItem(name: "setLanguage", value: "pl"),
            URLQueryItem(name: "systemInfo", value: "ios")
        ]

        guard let url = components.url else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let decoded = try? JSONDecoder().decode(MPKResponse.self, from: data) {
                await MainActor.run {
                    self.lastResponse = decoded
                    self.apiStatus = "\(decoded.tytulKomunikatu)\n\(decoded.trescKomunikatu)"
                }
            }
        } catch {
            await MainActor.run { self.apiStatus = "Błąd połączenia" }
        }
    }
}

#Preview {
    NavigationView {
        TicketView()
    }
}

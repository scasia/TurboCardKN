import SwiftUI
import CoreImage

// 1. Model danych
struct UserProfile: Codable {
    let imie: String
    let nazwisko: String
    let pin: Int
    let urlZdjecia: String
    let kartaTransfer: KartaTransfer
    
    struct KartaTransfer: Codable {
        let numerKarty: String
    }
}

struct HomeView: View {
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @AppStorage("userHash") var userHash = ""
    @State private var profile: UserProfile?
    
    @State private var showBarcode = false
    @State private var showQR = false
    
    let domain = "mojakn.pl"
    let context = CIContext()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 25) {
                    if let user = profile {
                        // --- PROFIL ---
                        HStack(alignment: .center, spacing: 15) {
                            AsyncImage(url: URL(string: "https://\(domain)/\(user.urlZdjecia)")) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: { ProgressView() }
                            .frame(width: 90, height: 110).cornerRadius(10).clipped()

                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(user.imie) \(user.nazwisko)")
                                    .font(.title3).bold()
                                
                                Text("Nr: \(user.kartaTransfer.numerKarty)")
                                    .font(.subheadline).foregroundColor(.primary)
                                
                                Text("PIN: \(String(user.pin))")
                                    .font(.caption).bold()
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.15)).cornerRadius(5)
                            }
                            Spacer()
                        }
                        .padding().background(Color(.secondarySystemBackground)).cornerRadius(15).padding(.horizontal)

                        // --- PRZYCISKI KODÓW ---
                        HStack(spacing: 20) {
                            Button("Kod kreskowy") {
                                withAnimation { showBarcode.toggle(); showQR = false }
                            }.buttonStyle(.bordered)

                            Button("Kod QR") {
                                withAnimation { showQR.toggle(); showBarcode = false }
                            }.buttonStyle(.bordered)
                        }
                        
                        // --- PRZYCISK MPK ---
                        NavigationLink(destination: ParkingView()) {
                            HStack {
                                Image(systemName: "car.2.fill")
                                Text("Parking")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                        NavigationLink(destination: TicketView()) {
                            HStack {
                                Image(systemName: "bus.fill")
                                Text("Bilety MPK")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }


                        // --- GENEROWANIE KODÓW ---
                        if showBarcode {
                            VStack(spacing: 10) {
                                if let barcode = generateBarcode(from: user.kartaTransfer.numerKarty) {
                                    Image(uiImage: barcode)
                                        .resizable()
                                        .interpolation(.none)
                                        .frame(height: 90)
                                        .padding(.horizontal)
                                    Text(user.kartaTransfer.numerKarty)
                                        .font(.system(.caption, design: .monospaced))
                                }
                            }
                        }

                        if showQR {
                            VStack(spacing: 10) {
                                if let qrcode = generateQRCode(from: user.kartaTransfer.numerKarty) {
                                    Image(uiImage: qrcode)
                                        .resizable()
                                        .interpolation(.none)
                                        .frame(width: 200, height: 200)
                                }
                                Text(user.kartaTransfer.numerKarty)
                                    .font(.system(.caption, design: .monospaced))
                            }
                        }

                        Spacer(minLength: 30)

                        Button("Wyloguj") { isLoggedIn = false }
                            .foregroundColor(.red)

                    } else {
                        ProgressView("Ładowanie profilu...").padding()
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Moja Karta")
            .task { await fetchMinimalProfile() }
        }
        .navigationViewStyle(.stack)
    }

    // --- GENERATORY (isoLatin1 dla identycznych bajtów) ---

    func generateBarcode(from string: String) -> UIImage? {
        guard let data = string.data(using: .isoLatin1) else { return nil }
        guard let filter = CIFilter(name: "CICode128BarcodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue(0, forKey: "inputQuietSpace")

        if let outputImage = filter.outputImage {
            if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: cgimg)
            }
        }
        return nil
    }

    func generateQRCode(from string: String) -> UIImage? {
        guard let data = string.data(using: .isoLatin1) else { return nil }
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        if let outputImage = filter.outputImage {
            if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: cgimg)
            }
        }
        return nil
    }

    func fetchMinimalProfile() async {
        let urlString = "https://\(domain)/kartyMobileEndpoint.qbpage?action=WYSZUKAJ_KLIENTA_I_JEGO_RODZINE_PO_HASHU&hash=\(userHash)&wybranyUserHash=\(userHash)&setLanguage=pl&systemInfo=ios"
        guard let url = URL(string: urlString) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode([UserProfile].self, from: data)
            await MainActor.run { self.profile = decoded.first }
        } catch { print("❌ Błąd: \(error.localizedDescription)") }
    }
}


#Preview {
    HomeView()
}

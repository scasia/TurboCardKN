//
//  ParkingOffer.swift
//  opencard
//
//  Created by kasia on 09/03/2026.
//


import SwiftUI

// --- MODELE DANYCH (Trzymamy je tutaj, żeby nie tworzyć zbędnych folderów) ---

struct ParkingOffer: Codable {
    let blachy: [Plate]
    let numerTablicyNaDarmowyCzas: [String: Int]?
}

struct Plate: Codable, Identifiable {
    let id: Int
    let numerKarty: String // To jest numer rejestracyjny
}

struct SimpleResponse: Codable {
    let success: String
}

// --- WIDOK PARKINGU ---

struct ParkingView: View {
    @State private var offer: ParkingOffer?
    @State private var newPlate: String = ""
    @State private var parkingStatus = "Pobieranie oferty..."
    @State private var isWorking = false
    @AppStorage("userHash") var userHash = ""
    let domain = "mojakn.pl"


    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                
                // --- SEKCJA 1: TWOJE POJAZDY ---
                VStack(alignment: .leading, spacing: 10) {
                    Text("TWOJE POJAZDY")
                        .font(.caption).bold().foregroundColor(.secondary)
                    
                    if let blachy = offer?.blachy, !blachy.isEmpty {
                        ForEach(blachy) { plate in
                            HStack {
                                Image(systemName: "car.fill")
                                Text(plate.numerKarty)
                                    .font(.system(.title3, design: .monospaced)).bold()
                                Spacer()
                                
                                Button("Start 120min") {
                                    Task { await startParking(for: plate.numerKarty) }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                                .disabled(isWorking)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.05))
                            .cornerRadius(10)
                        }
                    } else if offer != nil {
                        Text("Brak zapisanych tablic").italic().padding()
                    } else {
                        ProgressView()
                    }
                }
                .padding(.horizontal)

                // --- SEKCJA 2: DODAJ NOWĄ TABLICĘ ---
                VStack(spacing: 15) {
                    Text("DODAJ NOWY POJAZD")
                        .font(.caption).bold().foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    TextField("Np. K1FRIZ", text: $newPlate)
                        .textFieldStyle(.plain)
                        .font(.system(size: 25, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3)))
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)

                    Button(action: { Task { await addNewPlate() } }) {
                        if isWorking {
                            ProgressView().tint(.white)
                        } else {
                            Label("Dodaj do konta", systemImage: "plus.app.fill")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(newPlate.count < 3 ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(newPlate.count < 3 || isWorking)
                }
                .padding()
                .background(Color.gray.opacity(0.08))
                .cornerRadius(15)
                .padding(.horizontal)

                // --- STATUS OPERACJI ---
                Text(parkingStatus)
                    .font(.footnote)
                    .foregroundColor(.blue)
                    .multilineTextAlignment(.center)
                    .padding()

                Spacer()
            }
            .padding(.vertical)
        }
        .navigationTitle("Parkingi")
        .task { await fetchParkingOffer() }
    }

    // --- LOGIKA API ---

    // 1. Pobieranie listy blach
    func fetchParkingOffer() async {
        let urlString = "https://\(domain)/kartyMobileEndpoint.qbpage?action=POBIERZ_OFERTE_PARKINGI&hash=\(userHash)&hashKlienta=\(userHash)&setLanguage=pl&systemInfo=ios"
        guard let url = URL(string: urlString) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(ParkingOffer.self, from: data)
            await MainActor.run {
                self.offer = decoded
                self.parkingStatus = "Lista pojazdów zaktualizowana"
            }
        } catch {
            print("❌ Błąd: \(error)")
            await MainActor.run { self.parkingStatus = "Błąd pobierania danych" }
        }
    }

    // 2. Dodawanie blachy (Multipart Form Data)
    func addNewPlate() async {
        isWorking = true
        let urlString = "https://\(domain)/n-karta.qbpage?actionPerformed=DodajKarte&hashKlienta=\(userHash)&appOrder=true"
        guard let url = URL(string: urlString) else { return }
        
        let boundary = "dart-http-boundary-BetterClient"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        let fields = [
            "iTypKarty": "NUMER_REJSTRACYJNY",
            "iNumerKarty": newPlate.uppercased(),
            "iNumerKartyPowtorz": newPlate.uppercased()
        ]

        for (key, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Response: \(responseString)")
                if responseString.contains("DODANO") {
                    await MainActor.run {
                        self.parkingStatus = "✅ Dodano tablicę \(newPlate)"
                        self.newPlate = ""
                    }
                    await fetchParkingOffer()
                }
            }
        } catch {
            await MainActor.run { self.parkingStatus = "❌ Błąd dodawania" }
        }
        isWorking = false
    }

    // 3. Start parkowania
    func startParking(for plate: String) async {
        isWorking = true
        let urlString = "https://\(domain)/n-bilety.qbpage?actionPerformed=zapisBiletuMobilnego&hashKlienta=\(userHash)"
        guard let url = URL(string: urlString) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let decoded = try? JSONDecoder().decode(SimpleResponse.self, from: data) {
                await MainActor.run {
                    self.parkingStatus = decoded.success == "ROZPOCZETO_PARKOWANIE" 
                        ? "✅ Zaparkowano \(plate)!" 
                        : "Info: \(decoded.success)"
                }
            }
        } catch {
            await MainActor.run { self.parkingStatus = "Błąd rejestracji" }
        }
        isWorking = false
    }
}

#Preview {
    ParkingView()
}

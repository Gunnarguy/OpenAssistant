import SwiftUI

struct SettingsView: View {
    @AppStorage("OpenAI_API_Key") private var apiKey: String = ""
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        VStack {
            SecureField("Enter API Key", text: $apiKey)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .autocapitalization(.none)
                .disableAutocorrection(true)

            Toggle("Dark Mode", isOn: $isDarkMode)
                .padding()

            Button("Save") {
                saveSettings()
            }
            .padding()
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Settings"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
        .navigationBarTitle("Settings")
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }

    private func saveSettings() {
        alertMessage = apiKey.isEmpty ? "API Key cannot be empty." : "Settings saved successfully."
        showAlert = true
        if !apiKey.isEmpty {
            print("API Key saved: \(apiKey)")
        }
        print("Dark Mode: \(isDarkMode)")
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}

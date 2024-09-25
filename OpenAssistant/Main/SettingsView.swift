import SwiftUI

struct SettingsView: View {
    @AppStorage("OpenAI_API_Key") private var apiKey: String = ""
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isApiKeyValid = true

    var body: some View {
        VStack {
            apiKeySection
            darkModeToggle
            saveButton
        }
        .padding()
        .navigationBarTitle("Settings")
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Settings"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    // MARK: - Sections

    private var apiKeySection: some View {
        VStack(alignment: .leading) {
            Text("API Key")
                .font(.headline)
            SecureField("Enter API Key", text: $apiKey, onCommit: validateApiKey)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }

    private var darkModeToggle: some View {
        Toggle("Dark Mode", isOn: $isDarkMode)
            .padding()
    }

    private var saveButton: some View {
        Button(action: saveSettings) {
            Text("Save")
        }
    }

    // MARK: - Helper Methods

    private func validateApiKey() {
        isApiKeyValid = !apiKey.isEmpty
    }

    private func saveSettings() {
        validateApiKey()
        if isApiKeyValid {
            alertMessage = "Settings saved successfully."
            print("API Key saved: \(apiKey)")
        } else {
            alertMessage = "API Key cannot be empty."
        }
        showAlert = true
        print("Dark Mode: \(isDarkMode)")
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
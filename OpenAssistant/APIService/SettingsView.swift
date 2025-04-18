import Foundation
import Combine
import SwiftUI

struct SettingsView: View {
    @AppStorage("OpenAI_API_Key") private var apiKey: String = ""
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isApiKeyValid = true
    @EnvironmentObject var assistantManagerViewModel: AssistantManagerViewModel
    @Environment(\.presentationMode) var presentationMode

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            apiKeySection
            darkModeToggle
            saveButton
            Spacer()
        }
        .padding()
        .navigationBarTitle("Settings", displayMode: .inline)
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Settings"), 
                message: Text(alertMessage), 
                dismissButton: .default(Text("OK"))
            )
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
            .padding(.vertical)
    }

    private var saveButton: some View {
        Button(action: saveSettings) {
            Text("Save")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }

    // MARK: - Helper Methods

    private func validateApiKey() {
        isApiKeyValid = !apiKey.isEmpty
    }

    private func saveSettings() {
        validateApiKey()
        if isApiKeyValid {
            alertMessage = "Settings saved successfully."
            #if DEBUG
            print("API Key saved: \(apiKey)")
            #endif

            // Notify other views to refresh data after API key is saved
            NotificationCenter.default.post(name: .settingsUpdated, object: nil)

            // Dismiss the settings view if presented modally
            presentationMode.wrappedValue.dismiss()
        } else {
            alertMessage = "API Key cannot be empty."
        }
        showAlert = true
        #if DEBUG
        print("Dark Mode: \(isDarkMode)")
        #endif
    }
}

// MARK: - Previews
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AssistantManagerViewModel())
    }
}

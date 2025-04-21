import Combine
import Foundation
import SwiftUI

struct SettingsView: View {
    @AppStorage("OpenAI_API_Key") private var apiKey: String = ""
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @AppStorage("OpenAI_Default_Model") private var defaultModel: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isApiKeyValid = true
    @EnvironmentObject var assistantManagerViewModel: AssistantManagerViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            modelSelectionSection  // Default model picker
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
        // Load models when view appears and ensure defaultModel is valid
        .onAppear {
            assistantManagerViewModel.fetchAvailableModels()
        }
        .onChange(of: assistantManagerViewModel.availableModels) { models in
            // Only keep reasoning-capable models
            let reasoningModels = models.filter { BaseViewModel.isReasoningModel($0) }
            // If current defaultModel is no longer valid, reset to first available
            if !reasoningModels.contains(defaultModel) {
                defaultModel = reasoningModels.first ?? ""
            }
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

    // MARK: - Default Model Section
    private var modelSelectionSection: some View {
        VStack(alignment: .leading) {
            Text("Default Model")
                .font(.headline)
            if assistantManagerViewModel.availableModels.isEmpty {
                ProgressView().onAppear { assistantManagerViewModel.fetchAvailableModels() }
            } else {
                Picker("Model", selection: $defaultModel) {
                    ForEach(assistantManagerViewModel.availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
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
            #if DEBUG
                print("API Key saved: \(apiKey)")
            #endif

            // Notify other views to refresh data after API key is saved
            NotificationCenter.default.post(name: .settingsUpdated, object: nil)

            // Dismiss the settings view
            dismiss()
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

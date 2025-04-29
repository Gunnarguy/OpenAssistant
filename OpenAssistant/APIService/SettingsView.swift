import Combine
import Foundation
import SwiftUI

struct SettingsView: View {
    @AppStorage("OpenAI_API_Key") private var apiKey: String = ""
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @AppStorage("OpenAI_Default_Model") private var defaultModel: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    // Removed isApiKeyValid state as validation happens on save
    @EnvironmentObject var assistantManagerViewModel: AssistantManagerViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) var openURL  // Environment value to open URLs

    // MARK: - Body
    var body: some View {
        // Use Form for standard settings layout
        Form {
            apiKeySection
            modelSelectionSection
            appearanceSection
        }
        .navigationBarTitle("Settings", displayMode: .inline)
        .preferredColorScheme(isDarkMode ? .dark : .light)
        // Add a Done button to save and dismiss
        .navigationBarItems(trailing: Button("Done", action: saveSettings))
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Settings"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    // Dismiss only if API key is valid after showing the alert
                    if !apiKey.isEmpty {
                        dismiss()
                    }
                }
            )
        }
        // Load models when view appears and ensure defaultModel is valid
        .onAppear {
            assistantManagerViewModel.fetchAvailableModels()
        }
        .onChange(of: assistantManagerViewModel.availableModels) { models in
            // Filter for reasoning-capable models
            let reasoningModels = models.filter { BaseViewModel.isReasoningModel($0) }
            // Update default model if the current one is not in the filtered list
            if !reasoningModels.contains(defaultModel) || defaultModel.isEmpty {
                defaultModel = reasoningModels.first ?? ""
            }
        }
    }

    // MARK: - Sections

    // Section for API Key settings
    private var apiKeySection: some View {
        Section(header: Text("API Key")) {
            SecureField("Enter OpenAI API Key", text: $apiKey)
            // Link to OpenAI API key page
            Link(
                "Get your API key here",
                destination: URL(
                    string: "https://platform.openai.com/settings/organization/api-keys")!
            )
            .foregroundColor(.blue)  // Standard link color
        }
    }

    // Section for selecting the default model
    private var modelSelectionSection: some View {
        Section(header: Text("Default Model")) {
            if assistantManagerViewModel.availableModels.isEmpty {
                // Show progress indicator while loading models
                HStack {
                    Text("Loading models...")
                    ProgressView()
                }
                .onAppear { assistantManagerViewModel.fetchAvailableModels() }
            } else {
                // Picker for model selection
                Picker("Model", selection: $defaultModel) {
                    // Iterate over available reasoning models
                    ForEach(
                        assistantManagerViewModel.availableModels.filter {
                            BaseViewModel.isReasoningModel($0)
                        }, id: \.self
                    ) { model in
                        Text(model).tag(model)
                    }
                }
                // Use MenuPickerStyle for dropdown appearance
                .pickerStyle(MenuPickerStyle())
            }
        }
    }

    // Section for appearance settings like Dark Mode
    private var appearanceSection: some View {
        Section(header: Text("Appearance")) {
            Toggle("Dark Mode", isOn: $isDarkMode)
        }
    }

    // Removed saveButton view as it's replaced by the navigation bar item

    // MARK: - Helper Methods

    // Validate API Key (simple check for non-empty)
    private func validateApiKey() -> Bool {
        return !apiKey.isEmpty
    }

    // Save settings function triggered by the Done button
    private func saveSettings() {
        if validateApiKey() {
            alertMessage = "Settings saved successfully."
            #if DEBUG
                print("API Key saved: \(apiKey)")
                print("Default Model saved: \(defaultModel)")
                print("Dark Mode: \(isDarkMode)")
            #endif

            // Notify other parts of the app that settings have been updated
            NotificationCenter.default.post(name: .settingsUpdated, object: nil)

            // Show success alert (dismissal happens in the alert's dismissButton action)
            showAlert = true

        } else {
            alertMessage = "API Key cannot be empty."
            // Show error alert
            showAlert = true
        }
    }
}

// MARK: - Previews
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        // Embed in NavigationView for previewing navigation bar items
        NavigationView {
            SettingsView()
                .environmentObject(AssistantManagerViewModel())  // Provide the view model
        }
    }
}

import Combine
import Foundation
import SwiftUI

struct SettingsView: View {
    @AppStorage("OpenAI_API_Key") private var apiKey: String = ""
    // Use AppearanceMode enum for storing preference
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode.RawValue =
        AppearanceMode.system.rawValue
    // Removed defaultModel AppStorage
    @State private var showAlert = false
    @State private var alertMessage = ""
    // Removed isApiKeyValid state as validation happens on save
    @EnvironmentObject var assistantManagerViewModel: AssistantManagerViewModel  // Keep if needed elsewhere, otherwise consider removing if only used for models
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) var openURL  // Environment value to open URLs

    // MARK: - Body
    var body: some View {
        // Use Form for standard settings layout
        Form {
            apiKeySection  // Section for API Key
            appearanceSection  // Section for Appearance
        }
        .navigationBarTitle("Settings", displayMode: .inline)
        // Apply preferred color scheme based on selection using the global enum's helper
        .preferredColorScheme((AppearanceMode(rawValue: appearanceMode) ?? .system).colorScheme)
        // Removed the Done button from navigationBarItems
        // .navigationBarItems(trailing: Button("Done", action: saveSettings))
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Settings"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    // Dismiss only if API key is valid after showing the alert
                    // This ensures the view stays if the key was invalid,
                    // or dismisses after confirming a successful save.
                    // Check if the save was successful before dismissing
                    if alertMessage == "Settings saved successfully." {
                        dismiss()
                    }
                }
            )
        }
        // Removed model loading logic from onAppear and onChange
        // .onAppear { ... } // Removed fetchAvailableModels call
        // .onChange(of: assistantManagerViewModel.availableModels) { ... } // Removed entire onChange block
    }

    // MARK: - Sections

    // Section for API Key settings with an icon and save button
    private var apiKeySection: some View {
        // Use Label in the Section header for text and icon
        Section(header: Label("API Key", systemImage: "key.fill")) {
            SecureField("Enter OpenAI API Key", text: $apiKey)
                .textContentType(.password)  // Helps with password managers

            // Link to OpenAI API key page
            Link(
                "Get your API key here",
                destination: URL(
                    string: "https://platform.openai.com/settings/organization/api-keys")!
            )
            .foregroundColor(.blue)  // Standard link color
            .padding(.bottom)  // Add some space before the button

            // Button to save the API Key and other settings
            Button("Save Settings", action: saveSettings)
                .frame(maxWidth: .infinity, alignment: .center)  // Center the button
            // Optionally apply a prominent style
            // .buttonStyle(.borderedProminent)
        }
    }

    // Removed modelSelectionSection view

    // Section for appearance settings like Dark Mode
    private var appearanceSection: some View {
        // Use Label in the Section header for text and icon
        Section(header: Label("Appearance", systemImage: "paintbrush.fill")) {
            // Picker to select the appearance mode
            Picker("Theme", selection: $appearanceMode) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode.rawValue)
                }
            }
            // Use MenuPickerStyle for dropdown appearance
            .pickerStyle(MenuPickerStyle())
        }
    }

    // Removed saveButton view as it's replaced by the navigation bar item

    // MARK: - Helper Methods

    // Validate API Key (simple check for non-empty)
    private func validateApiKey() -> Bool {
        return !apiKey.isEmpty
    }

    // Save settings function triggered by the button
    private func saveSettings() {
        if validateApiKey() {
            alertMessage = "Settings saved successfully."
            #if DEBUG
                print("API Key saved: \(apiKey)")
                // Removed default model print statement
                // Log the selected appearance mode
                print("Appearance Mode: \(appearanceMode)")
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

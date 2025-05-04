import SwiftUI

// MARK: - Assistant Tools Section View
/// A view section for managing the capabilities (tools) of an assistant.
struct AssistantToolsSectionView: View {
    /// Binding to the assistant object being edited.
    @Binding var assistant: Assistant

    var body: some View {
        Section(header: Text("Capabilities")) {  // Consistent header
            // Toggle for enabling/disabling File Search capability.
            Toggle(isOn: toolBinding(for: "file_search")) {
                Label("Enable File Search", systemImage: "doc.text.magnifyingglass")
            }
            // Toggle for enabling/disabling Code Interpreter capability.
            Toggle(isOn: toolBinding(for: "code_interpreter")) {
                Label("Enable Code Interpreter", systemImage: "curlybraces.square")
            }
        }
    }

    /// Creates a binding to manage the enabled state of a specific tool type.
    /// - Parameter type: The type identifier string of the tool (e.g., "file_search").
    /// - Returns: A `Binding<Bool>` that reflects whether the tool is enabled.
    private func toolBinding(for type: String) -> Binding<Bool> {
        Binding(
            get: {
                // Check if the assistant's tools array contains a tool of the specified type.
                assistant.tools.contains { $0.type == type }
            },
            set: { isEnabled in
                // Update the tool's state based on the toggle's new value.
                updateToolState(isEnabled: isEnabled, type: type)
            }
        )
    }

    /// Adds or removes a tool from the assistant's tool list based on the toggle state.
    /// - Parameters:
    ///   - isEnabled: The new state from the toggle.
    ///   - type: The type identifier string of the tool.
    private func updateToolState(isEnabled: Bool, type: String) {
        if isEnabled {
            // If enabled and not already present, add the tool.
            if !assistant.tools.contains(where: { $0.type == type }) {
                assistant.tools.append(Tool(type: type))
            }
        } else {
            // If disabled, remove the tool.
            assistant.tools.removeAll { $0.type == type }
        }
    }
}

// MARK: - Previews
struct AssistantToolsSectionView_Previews: PreviewProvider {
    // Mock assistant with no tools enabled
    @State static var noToolsAssistant = Assistant(  // Use @State for mutable binding
        id: "1", object: "assistant", created_at: 0,
        name: "Sample No Tools", model: "gpt-3.5-turbo",
        tools: [], top_p: 1.0, temperature: 1.0
    )
    // Mock assistant with all tools enabled
    @State static var allToolsAssistant = Assistant(  // Use @State for mutable binding
        id: "2", object: "assistant", created_at: 0,
        name: "Sample All Tools", model: "gpt-3.5-turbo",
        tools: [Tool(type: "file_search"), Tool(type: "code_interpreter")],
        top_p: 1.0, temperature: 1.0
    )

    static var previews: some View {
        // Preview for assistant with no tools
        NavigationView {  // Wrap in NavigationView for context
            Form {  // Wrap in Form for standard styling
                AssistantToolsSectionView(assistant: $noToolsAssistant)  // Use binding
            }
            .navigationTitle("Capabilities (None)")  // Add title
        }
        .previewDisplayName("Tools Section (No Tools)")

        // Preview for assistant with all tools
        NavigationView {  // Wrap in NavigationView for context
            Form {  // Wrap in Form for standard styling
                AssistantToolsSectionView(assistant: $allToolsAssistant)  // Use binding
            }
            .navigationTitle("Capabilities (All)")  // Add title
        }
        .previewDisplayName("Tools Section (All Tools)")
    }
}

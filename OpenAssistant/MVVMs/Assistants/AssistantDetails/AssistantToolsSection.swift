import SwiftUI

// MARK: - Assistant Tools Section View
/// A view section for managing the capabilities (tools) of an assistant.
struct AssistantToolsSectionView: View {
    /// Binding to the assistant object being edited.
    @Binding var assistant: Assistant

    var body: some View {
        Section(header: Text("Capabilities")) { // Consistent header
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

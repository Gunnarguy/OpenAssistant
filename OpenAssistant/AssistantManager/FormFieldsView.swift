//
//  FormFieldsView.swift
//  OpenAssistant
//
//  Created by Gunnar Hostetler on 9/18/24.
//

import Foundation
import SwiftUI
import Combine

struct FormFieldsView: View {
    @Binding var assistant: Assistant
    
    var body: some View {
        Form {
            Section(header: Text("Basic Information")) {
                TextField("Name", text: $assistant.name)
                TextField("Instructions", text: Binding($assistant.instructions, default: ""))
                TextField("Model", text: $assistant.model)
                TextField("Description", text: Binding($assistant.description, default: ""))
            }
        }
    }
}

struct SlidersView: View {
    @Binding var assistant: Assistant
    
    var body: some View {
        VStack {
            Slider(value: $assistant.temperature, in: 0...2, step: 0.1) {
                Text("Temperature")
            }
            Slider(value: $assistant.top_p, in: 0...1, step: 0.1) {
                Text("Top P")
            }
        }
    }
}

struct ActionButtonsView: View {
    let updateAction: () -> Void
    let deleteAction: () -> Void
    
    var body: some View {
        HStack {
            Button(action: {
                updateAction()
                NotificationCenter.default.post(name: .assistantUpdated, object: nil)
            }) {
                Text("Update")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            Button(action: {
                deleteAction()
                NotificationCenter.default.post(name: .assistantDeleted, object: nil)
            }) {
                Text("Delete")
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
    }
}

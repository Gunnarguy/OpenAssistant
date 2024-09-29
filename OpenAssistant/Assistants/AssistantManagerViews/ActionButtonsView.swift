import SwiftUI

struct ActionButtonsView: View {
    @Binding var refreshTrigger: Bool
    var updateAction: () -> Void
    var deleteAction: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: updateAction) {
                Text("Update")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            Button(action: deleteAction) {
                Text("Delete")
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
    }
}

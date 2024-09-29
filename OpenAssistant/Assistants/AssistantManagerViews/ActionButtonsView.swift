import SwiftUI

struct ActionButtonsView: View {
    @Binding var refreshTrigger: Bool
    var updateAction: () -> Void
    var deleteAction: () -> Void

    var body: some View {
        HStack {
            Button(action: updateAction) {
                Text("Update")
            }
            Button(action: deleteAction) {
                Text("Delete")
            }
        }
    }
}

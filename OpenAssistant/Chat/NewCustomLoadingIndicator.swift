import SwiftUI

struct LoadingProgressView: View {
    @ObservedObject var viewModel: ChatViewModel
    private let totalSteps = LoadingState.allCases.count - 1
    
    var body: some View {
        VStack(spacing: 8) {
            ProgressView(value: Double(viewModel.stepCounter), total: Double(totalSteps))
                .tint(.blue)
                .frame(maxWidth: 200)
            
            Text(viewModel.loadingState.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.systemBackground))
                .shadow(radius: 2)
        )
    }
}

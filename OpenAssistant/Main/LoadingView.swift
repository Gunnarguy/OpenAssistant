import Foundation
import Combine
import SwiftUI

// MARK: - LoadingView

/// A view that displays a loading indicator with a message.
struct LoadingView: View {
    
    // MARK: - Constants
    
    private enum Constants {
        static let loadingText = "Loading..."
        static let textColor = Color.blue
        static let backgroundColor = Color.white.opacity(0.8)
        static let fontSize: Font = .largeTitle
        static let progressViewScale: CGFloat = 2.0
        static let padding: CGFloat = 16.0
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack {
            Text(Constants.loadingText)
                .font(Constants.fontSize)
                .foregroundColor(Constants.textColor)
                .padding(Constants.padding)
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Constants.textColor))
                .scaleEffect(Constants.progressViewScale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Constants.backgroundColor)
        .edgesIgnoringSafeArea(.all)
    }
}

// MARK: - Preview

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingView()
    }
}

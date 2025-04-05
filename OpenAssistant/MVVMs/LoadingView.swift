import SwiftUI

// MARK: - LoadingView

/// A view that displays a loading indicator with a message.
struct LoadingView: View {
    // MARK: - Properties
    
    var message: String
    var tint: Color
    
    // MARK: - Initialization
    
    init(message: String = "Loading...", tint: Color = .blue) {
        self.message = message
        self.tint = tint
    }
    
    // MARK: - Constants
    
    private struct Constants {
        static let backgroundColor = Color.white.opacity(0.8)
        static let fontSize: Font = .title
        static let progressViewScale: CGFloat = 2.0
        static let padding: CGFloat = 16.0
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: Constants.padding) {
            Text(message)
                .font(Constants.fontSize)
                .foregroundColor(tint)
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: tint))
                .scaleEffect(Constants.progressViewScale)
        }
        .padding(Constants.padding * 2)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Constants.backgroundColor)
                .shadow(radius: 5)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.3))
        .edgesIgnoringSafeArea(.all)
    }
}

// MARK: - Preview

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LoadingView()
                .previewDisplayName("Default")
            
            LoadingView(message: "Processing...", tint: .green)
                .preferredColorScheme(.dark)
                .previewDisplayName("Custom")
        }
    }
}

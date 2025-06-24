import SwiftUI

// MARK: - LoadingView

/// A view that displays a loading indicator with a message.
struct LoadingView: View {
    // MARK: - Properties

    var message: String
    var tint: Color

    // MARK: - Initialization

    init(message: String = "Loading...", tint: Color = .accentColor) {
        self.message = message
        self.tint = tint
    }

    // MARK: - Constants

    private struct Constants {
        static let cornerRadius: CGFloat = 20
        static let shadowRadius: CGFloat = 10
        static let padding: CGFloat = 24.0
        static let spacing: CGFloat = 20.0
        static let progressViewScale: CGFloat = 1.5
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Blurred background
            VisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: Constants.spacing) {
                Text(message)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(tint)
                    .multilineTextAlignment(.center)

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: tint))
                    .scaleEffect(Constants.progressViewScale)
            }
            .padding(Constants.padding)
            .background(
                RoundedRectangle(cornerRadius: Constants.cornerRadius)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(radius: Constants.shadowRadius)
            )
            .padding()
        }
    }
}

// MARK: - VisualEffectView for background blur
struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?
    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIVisualEffectView {
        UIVisualEffectView()
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<Self>) {
        uiView.effect = effect
    }
}

// MARK: - Preview

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LoadingView()
                .previewDisplayName("Default")

            LoadingView(message: "Processing your request, please wait...", tint: .purple)
                .preferredColorScheme(.dark)
                .previewDisplayName("Custom Dark")
        }
    }
}

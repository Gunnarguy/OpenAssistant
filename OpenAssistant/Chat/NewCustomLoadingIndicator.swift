import SwiftUI

struct NewCustomLoadingIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        VStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(AngularGradient(gradient: Gradient(colors: [.blue.opacity(0.6), .green.opacity(0.6), .blue.opacity(0.6)]), center: .center), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 30, height: 30)
                .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                .animation(Animation.linear(duration: 2).repeatForever(autoreverses: false), value: isAnimating)
                .onAppear {
                    isAnimating = true
                }
        }
    }
}

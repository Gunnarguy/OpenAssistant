import SwiftUI

struct CustomProgressView: View {
    let stepCounter: Int

    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .trim(from: 0, to: CGFloat(stepCounter) / 6.0)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [.blue, .green, .blue]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(Angle(degrees: -90))
                    .frame(width: 50, height: 50)
                    .animation(.easeInOut(duration: 0.5), value: stepCounter)
                Text("\(stepCounter)/6")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

import Foundation
import Combine
import SwiftUI

struct WaveLoadingIndicator: View {
    @State private var waveOffset = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<5) { index in
                Capsule()
                    .fill(Color.blue)
                    .frame(width: 8, height: 20)
                    .scaleEffect(y: waveOffset ? 0.5 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(0.1 * Double(index)),
                        value: waveOffset
                    )
            }
        }
        .onAppear {
            waveOffset.toggle()
        }
    }
}

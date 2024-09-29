import Foundation
import Combine
import SwiftUI

struct LoadingView: View {
    var body: some View {
        VStack {
            Text("Loading...")
                .font(.largeTitle)
                .foregroundColor(.blue)
                .padding()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.8))
        .edgesIgnoringSafeArea(.all)
    }
}

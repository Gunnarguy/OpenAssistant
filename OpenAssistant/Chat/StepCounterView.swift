import SwiftUI

struct StepCounterView: View {
    let stepCounter: Int

    var body: some View {
        if FeatureFlags.enableNewFeature {
            Text("Step: \(stepCounter)")
                .font(.footnote)
                .foregroundColor(.gray)
        } else {
            EmptyView()
        }
    }
}

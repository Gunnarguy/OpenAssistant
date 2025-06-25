import SwiftUI

struct CreditsView: View {
    @StateObject private var iap = IAPManager.shared
    @AppStorage("tokenBalance") private var tokenBalance: Int = 0

    var body: some View {
        List {
            Section(header: Text("Your Balance")) {
                Text("\(tokenBalance) tokens")
            }
            Section(header: Text("Buy Tokens")) {
                ForEach(iap.products) { product in
                    Button(product.displayName) {
                        Task { await iap.purchase(product) }
                    }
                }
            }
        }
        .navigationTitle("Credits")
        .task { await iap.loadProducts() }
        .onAppear { iap.startObservingTransactions() }
    }
}

struct CreditsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CreditsView()
        }
    }
}

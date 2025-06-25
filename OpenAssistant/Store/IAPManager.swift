import Foundation
import StoreKit
import SwiftUI

@MainActor
final class IAPManager: ObservableObject {
    static let shared = IAPManager()

    @Published private(set) var products: [Product] = []
    @AppStorage("tokenBalance") private var tokenBalance: Int = 0

    private init() {}

    func loadProducts() async {
        do {
            let ids: [String] = ["TokenPackSmall", "TokenPackLarge"]
            products = try await Product.products(for: ids)
        } catch {
            print("IAPManager: Failed loading products - \(error)")
        }
    }

    func startObservingTransactions() {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(transactionResult: result)
            }
        }
    }

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            await handle(transactionResult: result)
        } catch {
            print("IAPManager: Purchase failed - \(error.localizedDescription)")
        }
    }

    private func handle(transactionResult: Product.PurchaseResult) async {
        switch transactionResult {
        case .success(let verification):
            do {
                let transaction = try verification.payloadValue
                await transaction.finish()
                await grantTokens(for: transaction.productID)
            } catch {
                print("IAPManager: Transaction verification failed - \(error)")
            }
        default:
            break
        }
    }

    private func grantTokens(for productID: String) async {
        switch productID {
        case "TokenPackSmall":
            tokenBalance += 1000
        case "TokenPackLarge":
            tokenBalance += 5000
        default:
            break
        }
    }
}

import Foundation
import RevenueCat
import SwiftUI

final class TipJarViewModel: TipJarView.Model {
  private let productIdentifiers = [
    "me.jgrenier.AudioBS.tip_small",
    "me.jgrenier.AudioBS.tip_medium",
    "me.jgrenier.AudioBS.tip_large",
  ]

  private var storeProducts: [StoreProduct] = []

  init() {
    super.init()
    loadProducts()
  }

  override func onTipSelected(_ tip: Tip) {
    guard let storeProduct = storeProducts.first(where: { $0.productIdentifier == tip.id }) else {
      return
    }
    purchaseTip(storeProduct)
  }

  private func loadProducts() {
    Task {
      let products = await Purchases.shared.products(productIdentifiers)
      storeProducts = products.sorted { lhs, rhs in
        return lhs.price < rhs.price
      }

      tips = storeProducts.map { product in
        Tip(
          id: product.productIdentifier,
          title: product.localizedTitle,
          description: product.localizedDescription,
          price: product.localizedPriceString
        )
      }
    }
  }

  private func purchaseTip(_ product: StoreProduct) {
    isPurchasing = true
    lastPurchaseSuccess = false

    Task {
      do {
        let result = try await Purchases.shared.purchase(product: product)

        if !result.userCancelled {
          lastPurchaseSuccess = true

          Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            lastPurchaseSuccess = false
          }
        }
      } catch {
        print("Failed to purchase tip: \(error.localizedDescription)")
      }

      isPurchasing = false
    }
  }
}

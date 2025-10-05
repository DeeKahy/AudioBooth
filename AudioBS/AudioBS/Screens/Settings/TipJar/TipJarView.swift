import Combine
import RevenueCat
import StoreKit
import SwiftUI

struct TipJarView: View {
  @ObservedObject var model: Model

  var body: some View {
    if !model.tips.isEmpty {
      Section("Support Development") {
        VStack(spacing: 16) {
          HStack(spacing: 12) {
            ForEach(model.tips) { tip in
              Button(action: { model.onTipSelected(tip) }) {
                VStack(spacing: 8) {
                  Text(tip.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                  Text(tip.price)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                  Text(tip.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }
                .allowsTightening(true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 20)
                .padding(.horizontal, 8)
                .background(
                  RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                )
                .overlay(
                  RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color(.systemGray5), lineWidth: 1)
                )
              }
              .buttonStyle(.plain)
              .disabled(model.isPurchasing)
              .opacity(model.isPurchasing ? 0.6 : 1.0)
            }
          }

          if model.lastPurchaseSuccess {
            HStack(spacing: 8) {
              Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.body)
              Text("Thank you for your support!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
            .transition(.scale.combined(with: .opacity))
          }
        }
      }
      .animation(.easeInOut(duration: 0.3), value: model.lastPurchaseSuccess)
    }
  }
}

extension TipJarView {
  @Observable
  class Model: ObservableObject {
    struct Tip: Identifiable {
      let id: String
      let title: String
      let description: String
      let price: String
    }

    var tips: [Tip]
    var isPurchasing: Bool
    var lastPurchaseSuccess: Bool

    func onTipSelected(_ tip: Tip) {}

    init(
      tips: [Tip] = [],
      isPurchasing: Bool = false,
      lastPurchaseSuccess: Bool = false
    ) {
      self.tips = tips
      self.isPurchasing = isPurchasing
      self.lastPurchaseSuccess = lastPurchaseSuccess
    }
  }
}

extension TipJarView.Model {
  static var mock = TipJarView.Model(
    tips: [
      Tip(
        id: "tip_small",
        title: "Buy Me a Coffee ☕",
        description: "A small way to say thanks!",
        price: "$2.99"
      ),
      Tip(
        id: "tip_medium",
        title: "Buy Me Lunch 🍕",
        description: "Your support means a lot!",
        price: "$4.99"
      ),
      Tip(
        id: "tip_large",
        title: "Buy Me Dinner 🍱",
        description: "You‘re amazing! Thank you!",
        price: "$9.99"
      ),
    ]
  )
}
//
//#Preview("TipJar - Loading") {
//  TipJarView(model: .init(isLoading: true))
//}
//
//#Preview("TipJar - Empty") {
//  TipJarView(model: .init())
//}

#Preview("TipJar") {
  TipJarView(model: .mock)
    .padding()
}

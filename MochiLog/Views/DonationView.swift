import Combine
import StoreKit
import SwiftUI

/// 寄付（アプリ内課金）を管理するクラス
@MainActor
final class DonationManager: ObservableObject {
  static let shared = DonationManager()

  @Published private(set) var products: [Product] = []
  @Published private(set) var purchasedProductIDs = Set<String>()

  private let productIDs = [
    "net.ryuya-dev.net.mochilog.donation.small",
    "net.ryuya-dev.net.mochilog.donation.medium",
    "net.ryuya-dev.net.mochilog.donation.large",
  ]

  private var updates: Task<Void, Never>? = nil

  init() {
    updates = Task {
      for await update in Transaction.updates {
        if case .verified(let transaction) = update {
          await transaction.finish()
          await updatePurchasedProducts()
        }
      }
    }
  }

  deinit {
    updates?.cancel()
  }

  /// 商品情報を取得
  func fetchProducts() async {
    do {
      let storeProducts = try await Product.products(for: productIDs)
      self.products = storeProducts.sorted(by: { $0.price < $1.price })
    } catch {
      print("Failed to fetch products: \(error)")
    }
  }

  /// 購入処理
  func purchase(_ product: Product) async throws -> Bool {
    let result = try await product.purchase()

    switch result {
    case .success(let verification):
      switch verification {
      case .verified(let transaction):
        await transaction.finish()
        await updatePurchasedProducts()
        return true
      case .unverified:
        return false
      }
    case .pending, .userCancelled:
      return false
    @unknown default:
      return false
    }
  }

  /// 購入済み商品の更新
  func updatePurchasedProducts() async {
    for await result in Transaction.currentEntitlements {
      if case .verified(let transaction) = result {
        purchasedProductIDs.insert(transaction.productID)
      }
    }
  }
}

/// 寄付画面
struct DonationView: View {
  @StateObject private var donationManager = DonationManager.shared
  @Environment(\.dismiss) private var dismiss
  @State private var isPurchasing = false
  @State private var showingError = false

  var body: some View {
    NavigationStack {
      List {
        Section {
          VStack(spacing: 16) {
            Image(systemName: "heart.fill")
              .font(.system(size: 60))
              .foregroundColor(.red)
              .padding(.top)

            Text(String(localized: "donation_description"))
              .font(.body)
              .multilineTextAlignment(.center)
              .padding(.horizontal)
          }
          .frame(maxWidth: .infinity)
          .listRowBackground(Color.clear)
        }

        Section(String(localized: "donation_options")) {
          if donationManager.products.isEmpty {
            ProgressView()
              .frame(maxWidth: .infinity)
          } else {
            ForEach(donationManager.products) { product in
              Button {
                Task {
                  await purchase(product)
                }
              } label: {
                HStack {
                  VStack(alignment: .leading) {
                    Text(product.displayName)
                      .font(.headline)
                    Text(product.description)
                      .font(.caption)
                      .foregroundColor(.secondary)
                  }
                  Spacer()
                  Text(product.displayPrice)
                    .bold()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
              }
              .disabled(isPurchasing)
            }
          }
        }
      }
      .navigationTitle(String(localized: "donation_title"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(String(localized: "close")) {
            dismiss()
          }
        }
      }
      .task {
        await donationManager.fetchProducts()
      }
      .alert(String(localized: "error"), isPresented: $showingError) {
        Button(String(localized: "ok"), role: .cancel) {}
      } message: {
        Text(String(localized: "purchase_error_message"))
      }
      .overlay {
        if isPurchasing {
          ZStack {
            Color.black.opacity(0.2)
              .ignoresSafeArea()
            ProgressView()
              .padding()
              .background(.ultraThinMaterial)
              .cornerRadius(8)
          }
        }
      }
    }
  }

  private func purchase(_ product: Product) async {
    isPurchasing = true
    defer { isPurchasing = false }

    do {
      let success = try await donationManager.purchase(product)
      if success {
        dismiss()
      }
    } catch {
      showingError = true
    }
  }
}

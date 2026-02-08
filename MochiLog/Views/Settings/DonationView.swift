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
    "net.ryuya_dev.net.mochilog.donation.small",
    "net.ryuya_dev.net.mochilog.donation.medium",
    "net.ryuya_dev.net.mochilog.donation.large",
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
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var isPurchasing = false
  @State private var showingError = false
  @State private var showingThankYouFullScreen = false

  var body: some View {
    NavigationStack {
      List {
        Section {
          VStack(spacing: 16) {
            Image(systemName: "heart.fill")
              .font(.system(size: 60))
              .foregroundColor(.red)
              .padding(.top)

            Text(String(localized: "donation_description", table: "Settings"))
              .font(.body)
              .multilineTextAlignment(.center)
              .padding(.horizontal)
          }
          .frame(maxWidth: .infinity)
          .listRowBackground(Color.clear)
        }

        Section(String(localized: "donation_options", table: "Settings")) {
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
      .navigationTitle(String(localized: "donation_title", table: "Settings"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(String(localized: "close", table: "Common")) {
            dismiss()
          }
        }
      }
      .task {
        await donationManager.fetchProducts()
      }
      .alert(String(localized: "error", table: "Common"), isPresented: $showingError) {
        Button(String(localized: "ok", table: "Common"), role: .cancel) {}
      } message: {
        Text(String(localized: "purchase_error_message", table: "Settings"))
      }
      .fullScreenCover(isPresented: compactThankYouBinding) {
        ThankYouFullScreenView {
          showingThankYouFullScreen = false
          dismiss()
        }
      }
      .sheet(isPresented: regularThankYouBinding) {
        ThankYouFullScreenView {
          showingThankYouFullScreen = false
          dismiss()
        }
        .presentationDetents([.large])
        .presentationCornerRadius(28)
        .presentationDragIndicator(.visible)
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
        showingThankYouFullScreen = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
          if showingThankYouFullScreen {
            showingThankYouFullScreen = false
            dismiss()
          }
        }
      }
    } catch {
      showingError = true
    }
  }

  private var compactThankYouBinding: Binding<Bool> {
    Binding(
      get: { showingThankYouFullScreen && horizontalSizeClass != .regular },
      set: { newValue in
        showingThankYouFullScreen = newValue
      }
    )
  }

  private var regularThankYouBinding: Binding<Bool> {
    Binding(
      get: { showingThankYouFullScreen && horizontalSizeClass == .regular },
      set: { newValue in
        showingThankYouFullScreen = newValue
      }
    )
  }
}

private struct ThankYouFullScreenView: View {
  let onClose: () -> Void

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [
          Color(red: 0.00, green: 0.36, blue: 0.30),
          Color(red: 0.04, green: 0.62, blue: 0.47),
          Color(red: 0.10, green: 0.78, blue: 0.55),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      VStack(spacing: 20) {
        Spacer()

        ZStack {
          Circle()
            .fill(Color.white.opacity(0.18))
            .frame(width: 120, height: 120)
          Circle()
            .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
            .frame(width: 120, height: 120)
          Image(systemName: "heart.fill")
            .font(.system(size: 48, weight: .semibold))
            .foregroundStyle(.white)
        }
        .shadow(color: Color.black.opacity(0.25), radius: 20, x: 0, y: 12)

        VStack(spacing: 8) {
          Text(String(localized: "donation_thanks_title", table: "Settings"))
            .font(.title2.bold())
            .foregroundColor(.white)
          Text(String(localized: "donation_thanks_message", table: "Settings"))
            .font(.body)
            .foregroundColor(.white.opacity(0.95))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
        }

        Spacer()

        Button(action: onClose) {
          Text(String(localized: "close", table: "Common"))
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white)
            .foregroundColor(Color(red: 0.02, green: 0.55, blue: 0.42))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 6)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
      }
    }
  }
}

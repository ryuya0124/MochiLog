import SwiftUI

// MARK: - チュートリアルビュー
struct TutorialView: View {
  @Environment(\.dismiss) private var dismiss
  @StateObject private var appSettings = AppSettings.shared
  @State private var currentPage = 0

  private let pages: [TutorialPage] = [
    TutorialPage(
      icon: "hand.wave.fill",
      iconColor: .green,
      titleKey: "tutorial_welcome",
      descriptionKey: "tutorial_step1_description",
      imageName: nil
    ),
    TutorialPage(
      icon: "gear",
      iconColor: .gray,
      titleKey: "tutorial_step1_title",
      descriptionKey: "tutorial_step1_description",
      imageName: nil
    ),
    TutorialPage(
      icon: "square.and.arrow.up",
      iconColor: .blue,
      titleKey: "tutorial_step2_title",
      descriptionKey: "tutorial_step2_description",
      imageName: nil
    ),
    TutorialPage(
      icon: "chart.line.uptrend.xyaxis",
      iconColor: .green,
      titleKey: "tutorial_step3_title",
      descriptionKey: "tutorial_step3_description",
      imageName: nil
    ),
  ]

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        // ページインジケーター
        HStack(spacing: 8) {
          ForEach(0..<pages.count, id: \.self) { index in
            Circle()
              .fill(index == currentPage ? Color.green : Color.gray.opacity(0.3))
              .frame(width: 8, height: 8)
              .animation(.easeInOut, value: currentPage)
          }
        }
        .padding(.top, 20)

        // コンテンツ
        TabView(selection: $currentPage) {
          ForEach(0..<pages.count, id: \.self) { index in
            TutorialPageView(page: pages[index])
              .tag(index)
          }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))

        // ボタン
        VStack(spacing: 16) {
          if currentPage < pages.count - 1 {
            Button(action: {
              withAnimation {
                currentPage += 1
              }
            }) {
              Text(String(localized: "next"))
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(14)
            }
          } else {
            Button(action: {
              appSettings.completeTutorial()
              dismiss()
            }) {
              Text(String(localized: "got_it"))
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(14)
            }
          }

          if currentPage > 0 {
            Button(action: {
              withAnimation {
                currentPage -= 1
              }
            }) {
              Text(String(localized: "back"))
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
          }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
      }
      .navigationTitle(String(localized: "tutorial"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(String(localized: "close")) {
            dismiss()
          }
        }
      }
    }
  }
}

// MARK: - チュートリアルページデータ
struct TutorialPage {
  let icon: String
  let iconColor: Color
  let titleKey: String
  let descriptionKey: String
  let imageName: String?
}

// MARK: - チュートリアルページビュー
struct TutorialPageView: View {
  let page: TutorialPage

  var body: some View {
    VStack(spacing: 32) {
      Spacer()

      // アイコン
      ZStack {
        Circle()
          .fill(page.iconColor.opacity(0.15))
          .frame(width: 120, height: 120)

        Image(systemName: page.icon)
          .font(.system(size: 50))
          .foregroundStyle(page.iconColor)
      }

      // テキスト
      VStack(spacing: 16) {
        Text(String(localized: String.LocalizationValue(page.titleKey)))
          .font(.title)
          .fontWeight(.bold)
          .multilineTextAlignment(.center)

        Text(String(localized: String.LocalizationValue(page.descriptionKey)))
          .font(.body)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 24)
      }

      Spacer()
      Spacer()
    }
    .padding()
  }
}

#Preview {
  TutorialView()
}

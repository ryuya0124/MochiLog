import SwiftUI

struct LanguageSettingsView: View {
  var isEmbedded = false
  @ObservedObject private var languageSettings = LanguageSettings.shared

  var body: some View {
    List {
      Section {
        ForEach(AppLanguage.allCases) { language in
          Button {
            languageSettings.selection = language
          } label: {
            HStack {
              Text(language.name)
                .foregroundStyle(Color.primary)
              Spacer()
              if languageSettings.selection == language {
                Image(systemName: "checkmark")
                  .accessibilityLabel(L10n.string("language_selected", table: "Language"))
              }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
          }
          .accessibilityIdentifier("language.\(language.rawValue)")
        }
      } footer: {
        Text(L10n.string("language_description", table: "Language"))
      }
    }
    .modifier(LanguageNavigationTitle(isEmbedded: isEmbedded))
  }
}

private struct LanguageNavigationTitle: ViewModifier {
  let isEmbedded: Bool
  @ViewBuilder func body(content: Content) -> some View {
    if isEmbedded {
      content
    } else {
      content.navigationTitle(L10n.string("language_title", table: "Language"))
    }
  }
}

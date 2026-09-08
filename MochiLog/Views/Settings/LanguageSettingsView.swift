import SwiftUI

struct LanguageSettingsView: View {
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
    .navigationTitle(L10n.string("language_title", table: "Language"))
  }
}

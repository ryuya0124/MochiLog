import SwiftUI

/// Simple viewer for the Terms of Use markdown, reusing the same layout as PrivacyPolicyView
struct TermsOfUseView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var blocks: [Block] = []
  @State private var headerTitle: String? = nil

  private enum Block: Identifiable {
    case heading(level: Int, text: String)
    case paragraph(AttributedString)
    case empty

    var id: UUID { UUID() }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 18) {
          HStack(spacing: 12) {
            Image(systemName: "doc.text")
              .font(.system(size: 34, weight: .semibold))
              .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
              Text(headerTitle ?? String(localized: "terms_of_use_title", table: "Legal"))
                .font(.title2)
                .fontWeight(.semibold)
              Text(String(localized: "terms_of_use_subtitle", table: "Legal"))
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()
          }
          .padding(.horizontal)

          VStack(spacing: 12) {
            ForEach(blocks) { block in
              switch block {
              case .heading(let level, let text):
                Text(text)
                  .font(level <= 2 ? .headline : .subheadline)
                  .fontWeight(.semibold)
                  .foregroundColor(level <= 2 ? Color.primary : Color.secondary)
                  .frame(maxWidth: .infinity, alignment: .leading)

              case .paragraph(let attributed):
                Text(attributed)
                  .frame(maxWidth: .infinity, alignment: .leading)

              case .empty:
                Spacer().frame(height: 8)
              }
            }
          }
          .padding()
          .background(.regularMaterial)
          .cornerRadius(12)
          .padding(.horizontal)
          .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
        }
        .padding(.vertical)
      }
      .navigationTitle("")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(String(localized: "close", table: "Common")) { dismiss() }
        }
      }
      .task {
        await loadMarkdownBlocks()
      }
    }
  }

  private func loadMarkdownBlocks() async {
    blocks = []
    headerTitle = nil
    let resourceName = selectedResourceName()
    guard let url = Bundle.main.url(forResource: resourceName, withExtension: "md") else {
      blocks = [
        .paragraph(AttributedString(String(localized: "terms_of_use_unavailable", table: "Legal")))
      ]
      return
    }

    guard let data = try? Data(contentsOf: url), let str = String(data: data, encoding: .utf8)
    else {
      blocks = [
        .paragraph(AttributedString(String(localized: "terms_of_use_unavailable", table: "Legal")))
      ]
      return
    }

    var normalized = str
    if normalized.hasPrefix("## ") {
      normalized = "\n" + normalized
    }
    normalized = normalized.replacingOccurrences(of: "\n## ", with: "\n\n## ")
    normalized = normalized.replacingOccurrences(of: "\n### ", with: "\n\n### ")

    let paragraphs = normalized.components(separatedBy: "\n\n")

    for (index, para) in paragraphs.enumerated() {
      let trimmed = para.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmed.isEmpty {
        blocks.append(.empty)
        continue
      }

      if trimmed.hasPrefix("# ") {
        let text = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        headerTitle = text
        continue
      } else if trimmed.hasPrefix("## ") {
        let text = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        blocks.append(.heading(level: 2, text: text))
        continue
      } else if trimmed.hasPrefix("### ") {
        let text = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
        blocks.append(.heading(level: 3, text: text))
        continue
      }

      if let attr = try? AttributedString(markdown: trimmed) {
        blocks.append(.paragraph(attr))
      } else {
        blocks.append(.paragraph(AttributedString(trimmed)))
      }

      if index < paragraphs.count - 1 {
        blocks.append(.empty)
      }
    }
  }

  private func selectedResourceName() -> String {
    let preferred = Locale.preferredLanguages.first ?? Locale.current.identifier
    if preferred.starts(with: "en") {
      // if English resource exists, prefer it
      if Bundle.main.url(forResource: "TermsOfUse_en", withExtension: "md") != nil {
        return "TermsOfUse_en"
      }
    }
    return "TermsOfUse"
  }
}

#Preview {
  TermsOfUseView()
}

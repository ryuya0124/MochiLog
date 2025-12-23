import SwiftUI

struct PrivacyPolicyView: View {
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
          // Decorative header
          HStack(spacing: 12) {
            Image(systemName: "shield.checkerboard")
              .font(.system(size: 36, weight: .semibold))
              .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
              Text(headerTitle ?? String(localized: "privacy_policy_title"))
                .font(.title2)
                .fontWeight(.semibold)
              Text(String(localized: "privacy_policy_subtitle"))
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()
          }
          .padding(.horizontal)

          // Content card
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
          .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        .padding(.vertical)
      }
      .navigationTitle("")
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(String(localized: "close")) { dismiss() }
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
    guard let url = Bundle.main.url(forResource: "PrivacyPolicy", withExtension: "md") else {
      blocks = [.paragraph(AttributedString(String(localized: "privacy_policy_unavailable")))]
      return
    }

    guard let data = try? Data(contentsOf: url), let raw = String(data: data, encoding: .utf8)
    else {
      blocks = [.paragraph(AttributedString(String(localized: "privacy_policy_unavailable")))]
      return
    }

    // Split by blank lines into paragraphs
    let paragraphs = raw.components(separatedBy: "\n\n")

    for (index, para) in paragraphs.enumerated() {
      let trimmed = para.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmed.isEmpty {
        blocks.append(.empty)
        continue
      }

      // Check for heading markers
      if trimmed.hasPrefix("# ") {
        let text = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        headerTitle = text
        // Skip including top-level as a block; header rendered already
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

      // For normal paragraphs, use AttributedString to preserve inline markdown (bold/italic/links)
      if let attr = try? AttributedString(markdown: trimmed) {
        blocks.append(.paragraph(attr))
      } else {
        blocks.append(.paragraph(AttributedString(trimmed)))
      }

      // Preserve a small spacer between paragraphs
      if index < paragraphs.count - 1 {
        blocks.append(.empty)
      }
    }
  }
}

#Preview {
  PrivacyPolicyView()
}

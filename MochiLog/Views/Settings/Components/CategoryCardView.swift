import SwiftUI

// MARK: - カテゴリカードビュー
struct CategoryCardView: View {
  let category: SettingsCategory
  let isSelected: Bool

  var body: some View {
    HStack(spacing: 16) {
      Image(systemName: category.icon)
        .font(.system(size: 28))
        .foregroundStyle(isSelected ? .white : .primary)
        .frame(width: 44, height: 44)

      Text(category.title)
        .font(.headline)
        .foregroundStyle(isSelected ? .white : .primary)

      Spacer()
    }
    .padding()
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
    )
  }
}

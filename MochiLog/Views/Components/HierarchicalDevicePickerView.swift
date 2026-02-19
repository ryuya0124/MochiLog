import SwiftUI

struct HierarchicalDevicePickerView: View {
  @Environment(\.dismiss) private var dismiss
  let initialCategory: DeviceLibrary.Category?
  let lockCategory: Bool
  /// nilの場合は全カテゴリを表示。指定した場合はそのカテゴリのみ表示する
  let allowedCategories: [DeviceLibrary.Category]?
  let onSelect: (String, String) -> Void  // (deviceName, identifier)

  @State private var selectedCategory: DeviceLibrary.Category?
  @State private var selectedSeries: String?

  init(
    initialCategory: DeviceLibrary.Category? = nil,
    lockCategory: Bool = false,
    allowedCategories: [DeviceLibrary.Category]? = nil,
    onSelect: @escaping (String, String) -> Void
  ) {
    self.initialCategory = initialCategory
    self.lockCategory = lockCategory
    self.allowedCategories = allowedCategories
    self.onSelect = onSelect
    self._selectedCategory = State(initialValue: initialCategory)
  }

  private var displayCategories: [DeviceLibrary.Category] {
    if let allowed = allowedCategories {
      return DeviceLibrary.Category.allCases.filter { allowed.contains($0) }
    }
    return DeviceLibrary.Category.allCases
  }

  var body: some View {
    NavigationStack {
      List {
        if selectedCategory == nil {
          Section(String(localized: "select_category", table: "Common")) {
            ForEach(displayCategories) { category in
              Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                  selectedCategory = category
                }
              } label: {
                HStack {
                  Text(category.localizedName)
                  Spacer()
                  Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }
              .foregroundStyle(.primary)
            }
          }
        } else if selectedSeries == nil {
          Section {
            if !lockCategory {
              Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                  selectedCategory = nil
                }
              } label: {
                Label(String(localized: "back", table: "Common"), systemImage: "chevron.left")
              }
            }

            let seriesList = DeviceLibrary.getSeries(for: selectedCategory!)
            ForEach(seriesList, id: \.self) { series in
              Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                  selectedSeries = series
                }
              } label: {
                HStack {
                  Text(
                    series == "Standard"
                      ? String(localized: "standard_models", table: "Common") : series)
                  Spacer()
                  Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }
              .foregroundStyle(.primary)
            }
          } header: {
            Text(selectedCategory!.localizedName)
          }
        } else {
          Section {
            Button {
              withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedSeries = nil
              }
            } label: {
              Label(String(localized: "back", table: "Common"), systemImage: "chevron.left")
            }

            let models = DeviceLibrary.getModels(for: selectedCategory!, series: selectedSeries!)
            ForEach(models, id: \.self) { model in
              Button {
                if let identifier = DeviceLibrary.getFirstIdentifier(for: model) {
                  onSelect(model, identifier)
                  dismiss()
                }
              } label: {
                Text(model)
              }
              .foregroundStyle(.primary)
            }
          } header: {
            Text(
              "\(selectedCategory!.localizedName) > \(selectedSeries == "Standard" ? String(localized: "standard_models", table: "Common") : selectedSeries!)"
            )
          }
        }
      }
      .navigationTitle(String(localized: "select_device", table: "Common"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(String(localized: "cancel", table: "Common")) {
            dismiss()
          }
        }
      }
    }
  }
}

#Preview {
  HierarchicalDevicePickerView(initialCategory: .iphone, lockCategory: true) { name, id in
    print("Selected: \(name) (\(id))")
  }
}

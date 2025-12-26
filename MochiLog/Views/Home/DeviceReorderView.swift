import SwiftUI

struct DeviceReorderView: View {
  @Environment(\.dismiss) private var dismiss
  @State var items: [String]
  var onSave: ([String]) -> Void

  var body: some View {
    NavigationStack {
      List {
        ForEach(items, id: \.self) { item in
          Text(item)
        }
        .onMove(perform: move)
      }
      .navigationTitle(String(localized: "sort_devices"))
      .navigationBarTitleDisplayMode(.inline)
      .environment(\.editMode, .constant(.active))
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(String(localized: "cancel")) {
            dismiss()
          }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(String(localized: "save")) {
            onSave(items)
            dismiss()
          }
        }
      }
    }
  }

  private func move(from source: IndexSet, to destination: Int) {
    items.move(fromOffsets: source, toOffset: destination)
  }
}

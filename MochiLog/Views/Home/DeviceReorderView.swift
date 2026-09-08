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
      .navigationTitle(L10n.string("sort_devices", table: "Home"))
      .navigationBarTitleDisplayMode(.inline)
      .environment(\.editMode, .constant(.active))
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(L10n.string("cancel", table: "Common")) {
            dismiss()
          }
          .tint(.primary)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(L10n.string("save", table: "Common")) {
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

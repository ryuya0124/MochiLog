import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - YAML Document Type
struct YAMLDocument: FileDocument {
  static var readableContentTypes: [UTType] { [.yaml] }

  var yaml: String

  init(yaml: String) {
    self.yaml = yaml
  }

  init(configuration: ReadConfiguration) throws {
    guard let data = configuration.file.regularFileContents,
      let string = String(data: data, encoding: .utf8)
    else {
      throw CocoaError(.fileReadCorruptFile)
    }
    yaml = string
  }

  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    let data = yaml.data(using: .utf8)!
    return .init(regularFileWithContents: data)
  }
}

// MARK: - UTType Extension
extension UTType {
  static var yaml: UTType {
    UTType(importedAs: "public.yaml")
  }
}

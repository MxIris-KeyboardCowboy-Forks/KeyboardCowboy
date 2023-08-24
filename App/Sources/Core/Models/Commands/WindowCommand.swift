import Foundation

struct WindowCommand: MetaDataProviding {
  enum Kind: String, Identifiable, Codable, CaseIterable {
    var id: String { rawValue }
    case center
    case moveToNextDisplay

    var displayValue: String {
      switch self {
      case .center:
        return "Center Window"
      case .moveToNextDisplay:
        return "Move to Next Display"
      }
    }
  }
  var kind: Kind
  var meta: Command.MetaData

  init(id: String = UUID().uuidString, name: String, kind: Kind, notification: Bool) {
    self.kind = kind
    self.meta = Command.MetaData(id: id, name: name, isEnabled: true, notification: notification)
  }
}
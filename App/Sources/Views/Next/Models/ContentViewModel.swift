import SwiftUI

struct ContentViewModel: Identifiable, Hashable {
  let id: String
  let name: String
  let images: [Image]
  let binding: String?
  let badge: Int
  let badgeOpacity: Double

  struct Image: Identifiable, Hashable {
    let id: String
    let offset: Double
    let nsImage: NSImage
  }
}
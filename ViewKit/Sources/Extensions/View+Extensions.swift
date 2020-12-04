import SwiftUI

public extension View {
  func erase() -> AnyView {
    AnyView(self)
  }

  func pointerHandOnHover() -> some View {
    onHover(perform: { hovering in
      if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
    })
  }

  func onDrop(_ isTargeted: Binding<Bool>?, _ handler: @escaping ([URL]) -> Void) -> some View {
    onDrop(
      of: [.fileURL, .application, .text, .utf8PlainText],
      isTargeted: isTargeted,
      perform: { providers in
        var urls = Set<URL>()
        var counter = 0
        let completion = {
          counter -= 1
          if counter == 0 {
            handler(Array(urls))
          }
        }

        for provider in providers {
          // Try and decode URL's
          if provider.canLoadObject(ofClass: URL.self) {
            counter += 1
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
              if let newUrl = url {
                urls.insert(newUrl)
              }
              completion()
            }
          }

          // Try and decode Strings
          if provider.canLoadObject(ofClass: String.self) {
            counter += 1
            _ = provider.loadObject(ofClass: String.self) { string, _ in
              if let string = string,
                 let url = URL(string: string) {
                urls.insert(url)
              }
              completion()
            }
          }
        }
        return true
      })
  }
}
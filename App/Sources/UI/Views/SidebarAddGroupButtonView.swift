import SwiftUI

struct SidebarAddGroupButtonView: View {
  @Binding private var isVisible: Bool
  private var namespace: Namespace.ID
  private var onAction: () -> Void

  init(isVisible: Binding<Bool>,
       namespace: Namespace.ID,
       onAction: @escaping () -> Void) {
    self._isVisible = isVisible
    self.namespace = namespace
    self.onAction = onAction
  }

  @ViewBuilder
  var body: some View {
    if isVisible {
      Button(action: {
        onAction()
      }) {
        Image(systemName: "plus.circle")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(height: 10)
          .padding(2)
      }
      .buttonStyle(.gradientStyle(config: .init(nsColor: .systemGreen, grayscaleEffect: true)))
      .padding(.leading, 6)
      .padding(.bottom, 6)
      .matchedGeometryEffect(id: "add-group-button", in: namespace)
    } else {
      EmptyView()
    }
  }
}
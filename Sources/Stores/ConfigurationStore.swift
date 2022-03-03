import Combine
import Foundation
import SwiftUI

final class ConfigurationStore: ObservableObject {
  private var subscription: AnyCancellable?
  @Published private(set) var configurations = [Configuration]()
  @Published private(set) var selectedConfiguration: Configuration = .empty()
  @AppStorage("selectedConfiguration") private(set) var selectedId: String = ""

  @discardableResult
  func updateConfigurations(_ configurations: [Configuration]) -> Self {
    self.configurations = configurations

    if selectedId.isEmpty, let configuration = configurations.first(where: { $0.id == selectedId }) {
      self.selectedConfiguration = configuration
      self.selectedId = configuration.id
    } else if let configuration = configurations.first  {
      self.selectedConfiguration = configuration
      self.selectedId = configuration.id
    } else {
      assertionFailure("We should never end up here.")
    }
    return self
  }

  func select(_ configuration: Configuration) {
    selectedId = configuration.id
    selectedConfiguration = configuration
  }

  func add(_ configuration: Configuration) {
    configurations.append(configuration)
  }

  func remove(_ configuration: Configuration) {
    configurations.removeAll(where: { $0.id == configuration.id })
  }

  func update(_ configuration: Configuration) {
    guard let index = configurations.firstIndex(where: { $0.id == configuration.id }) else {
      return
    }
    var newConfigurations = self.configurations
    newConfigurations[index] = configuration
    select(configuration)
    self.configurations = newConfigurations
  }
}
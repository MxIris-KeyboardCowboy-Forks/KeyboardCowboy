import Combine
import Cocoa
import SwiftUI
import LaunchArguments
import Inject

let isRunningPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != nil
let launchArguments = LaunchArgumentsController<LaunchArgument>()

enum AppEnvironment: String, Hashable, Identifiable {
  var id: String { rawValue }

  case development
  case production
}

enum AppScene {
  case mainWindow
  case addGroup
  case editGroup(GroupViewModel.ID)
}

@main
struct KeyboardCowboy: App {
  @FocusState var containerFocus: ContainerView.Focus?
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  private let sidebarCoordinator: SidebarCoordinator
  private let configurationCoordinator: ConfigurationCoordinator
  private let contentCoordinator: ContentCoordinator
  private let detailCoordinator: DetailCoordinator

  private let contentStore: ContentStore
  private let groupStore: GroupStore
  private let scriptEngine: ScriptEngine
  private let engine: KeyboardCowboyEngine
#if DEBUG
  static let config: AppPreferences = .designTime()
  static let env: AppEnvironment = .development
#else
  static let config: AppPreferences = .user()
  static let env: AppEnvironment = .production
#endif

  private var open: Bool = true

  @Environment(\.openWindow) private var openWindow
  @Environment(\.scenePhase) private var scenePhase

  init() {
    let scriptEngine = ScriptEngine(workspace: .shared)
    let keyboardShortcutsCache = KeyboardShortcutsCache()
    let applicationStore = ApplicationStore()
    let shortcutStore = ShortcutStore(engine: scriptEngine)
    let contentStore = ContentStore(Self.config,
                                    applicationStore: applicationStore,
                                    keyboardShortcutsCache: keyboardShortcutsCache,
                                    shortcutStore: shortcutStore,
                                    scriptEngine: scriptEngine, workspace: .shared)
    let groupIdsPublisher = GroupIdsPublisher(.init(ids: []))
    let workflowIdsPublisher = ContentSelectionIdsPublisher(.init(groupIds: [], workflowIds: []))
    let contentCoordinator = ContentCoordinator(
      contentStore.groupStore,
      applicationStore: applicationStore,
      selectionPublisher: workflowIdsPublisher)
    let keyCodeStore = KeyCodesStore()
    let keyboardEngine = KeyboardEngine(store: keyCodeStore)
    let engine = KeyboardCowboyEngine(contentStore,
                                      keyboardEngine: keyboardEngine,
                                      keyboardShortcutsCache: keyboardShortcutsCache,
                                      scriptEngine: scriptEngine,
                                      shortcutStore: shortcutStore,
                                      workspace: .shared)

    self.sidebarCoordinator = SidebarCoordinator(contentStore.groupStore,
                                                 applicationStore: applicationStore,
                                                 groupIdsPublisher: groupIdsPublisher,
                                                 workflowIdsPublisher: workflowIdsPublisher)
    self.contentCoordinator = contentCoordinator
    self.configurationCoordinator = ConfigurationCoordinator(store: contentStore.configurationStore)
    self.detailCoordinator = DetailCoordinator(applicationStore: applicationStore,
                                               commandEngine: CommandEngine(NSWorkspace.shared,
                                                                            scriptEngine: scriptEngine,
                                                                            keyboardEngine: keyboardEngine),
                                               contentStore: contentStore,
                                               keyboardCowboyEngine: engine,
                                               groupStore: contentStore.groupStore)

    self.contentStore = contentStore
    self.groupStore = contentStore.groupStore
    self.engine = engine
    self.scriptEngine = scriptEngine

    Benchmark.isEnabled = launchArguments.isEnabled(.benchmark)

    if launchArguments.isEnabled(.injection) { _ = Inject.load }

    contentCoordinator.subscribe(to: groupIdsPublisher.$model)
    detailCoordinator.subscribe(to: workflowIdsPublisher.$model)
  }

  var body: some Scene {
    AppMenuBar { action in
      switch action {
      case .openMainWindow:
        handleScene(.mainWindow)
      case .reveal:
        NSWorkspace.shared.selectFile(Bundle.main.bundlePath, inFileViewerRootedAtPath: "")
      }
    }

    WindowGroup(id: KeyboardCowboy.mainWindowIdentifier) {
      applyEnvironmentObjects(
        ContainerView(focus: $containerFocus) { action in
          switch action {
          case .openScene(let scene):
            handleScene(scene)
          case .sidebar(let sidebarAction):
            switch sidebarAction {
            case .openScene(let scene):
              handleScene(scene)
            default:
              sidebarCoordinator.handle(sidebarAction)
            }
          case .content(let contentAction):
            Task {
              await contentCoordinator.handle(contentAction)
              if case .addWorkflow = contentAction {
                containerFocus = .content
              }
            }
          case .detail(let detailAction):
            detailCoordinator.handle(detailAction)
            contentCoordinator.handle(detailAction)
          }
        }
      )
    }
    .windowStyle(.hiddenTitleBar)

    NewCommandWindow(contentStore: contentStore) { workflowId, commandId, title, payload in
      let groupIds = contentCoordinator.selectionPublisher.model.groupIds
      Task {
        await detailCoordinator.addOrUpdateCommand(payload, workflowId: workflowId,
                                                   title: title, commandId: commandId)
        await contentCoordinator.handle(.selectWorkflow(models: [workflowId], inGroups: groupIds))
      }
    }

    EditWorkflowGroupWindow(contentStore)
      .windowResizability(.contentSize)
      .windowStyle(.hiddenTitleBar)
      .defaultPosition(.topTrailing)
      .defaultSize(.init(width: 520, height: 280))
  }

  private func handleScene(_ scene: AppScene) {
    guard !isRunningPreview else { return }
    switch scene {
    case .mainWindow:
      if let mainWindow = KeyboardCowboy.mainWindow {
        mainWindow.makeKeyAndOrderFront(nil)
      } else {
        openWindow(id: KeyboardCowboy.mainWindowIdentifier)
      }
      KeyboardCowboy.activate()
    case .addGroup:
      openWindow(value: EditWorkflowGroupWindow.Context.add(WorkflowGroup.empty()))
    case .editGroup(let groupId):
      if let workflowGroup = groupStore.group(withId: groupId) {
        openWindow(value: EditWorkflowGroupWindow.Context.edit(workflowGroup))
      } else {
        assertionFailure("Unable to find workflow group")
      }
    }
  }
}

class AppDelegate: NSObject, NSApplicationDelegate {
  lazy var windowController = NSWindowController(window: notificationWindow)
  lazy var coordinator = NotificationCoordinator(.init())
  lazy var notificationWindow: NotificationWindow = {
    NotificationWindow(contentRect: .init(origin: .init(x: 8, y: 0),
                                          size: .init(width: 1000, height: 100)), content: {
      NotificationListView(publisher: self.coordinator.publisher)
    })
  }()

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    switch KeyboardCowboy.env {
    case .development:
      guard !isRunningPreview else { return }
      KeyboardCowboy.activate()

      return
      self.windowController.showWindow(nil)

      withAnimation {
        let newPayload: [NotificationViewModel] = [
          .init(id: UUID().uuidString,
                icon: IconViewModel(bundleIdentifier: "com.apple.Finder",
                                    path: "/System/Library/CoreServices/Finder.app"),
                name: "Finder",
                result: .success),
          .init(id: UUID().uuidString,
                icon: IconViewModel(bundleIdentifier: "com.apple.Calendar",
                                    path: "/System/Library/CoreServices/Calendar.app"),
                name: "Calendar",
                result: .success)
        ]
        self.coordinator.publisher.publish(newPayload)

        guard let intrinsicContentSize = self.notificationWindow.contentView?.intrinsicContentSize else { return }

        let rect = CGRect(origin: .init(x: 8, y: intrinsicContentSize.height + 8),
                          size: intrinsicContentSize)
        self.windowController.window?.animator().setFrame(rect, display: true, animate: true)
      }
    case .production:
      KeyboardCowboy.mainWindow?.close()
    }
  }
}

private extension KeyboardCowboy {
  func applyEnvironmentObjects<Content: View>(_ content: @autoclosure () -> Content) -> some View {
    content()
      .environmentObject(contentStore.configurationStore)
      .environmentObject(contentStore.applicationStore)
      .environmentObject(contentStore.groupStore)
      .environmentObject(configurationCoordinator.publisher)
      .environmentObject(sidebarCoordinator.publisher)
      .environmentObject(sidebarCoordinator.workflowIdsPublisher)
      .environmentObject(sidebarCoordinator.groupIdsPublisher)
      .environmentObject(contentCoordinator.publisher)
      .environmentObject(contentCoordinator.selectionPublisher)
      .environmentObject(detailCoordinator.statePublisher)
      .environmentObject(detailCoordinator.detailPublisher)
      .environmentObject(contentStore.recorderStore)
      .environmentObject(OpenPanelController())
  }
}
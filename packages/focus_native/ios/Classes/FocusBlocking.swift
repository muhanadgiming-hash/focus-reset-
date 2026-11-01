import Flutter
import UIKit
#if canImport(FamilyControls) && canImport(ManagedSettings) && canImport(SwiftUI)
import FamilyControls
import ManagedSettings
import SwiftUI
#endif

/// App blocking during focus sessions with Apple's Screen Time API
/// (FamilyControls + ManagedSettings).
///
/// Requires iOS 16+ and the `com.apple.developer.family-controls`
/// entitlement, which Apple must approve for App Store distribution.
/// Without it, authorization fails and the app reports blocking as
/// unavailable — it never pretends to block.
///
/// The chosen apps are opaque tokens: they stay on the device and are never
/// sent to Dart, the server or anyone else.
enum FocusBlocking {
  static let selectionKey = "focus_reset.blocking.selection"

  static let methods: Set<String> = [
    "blockingStatus", "requestBlocking", "pickBlockedApps", "blockedCounts", "startShield", "stopShield",
  ]

  /// Returns false when [method] is not an app-blocking method.
  static func handle(_ method: String, _ args: [String: Any], _ result: @escaping FlutterResult) -> Bool {
    guard methods.contains(method) else { return false }
    #if canImport(FamilyControls) && canImport(ManagedSettings) && canImport(SwiftUI)
    if #available(iOS 16.0, *) {
      BlockingImpl.handle(method, args, result)
      return true
    }
    #endif
    switch method {
    case "blockingStatus": result("unsupported")
    case "blockedCounts", "pickBlockedApps": result(nil)
    default: result(false)
    }
    return true
  }
}

#if canImport(FamilyControls) && canImport(ManagedSettings) && canImport(SwiftUI)
@available(iOS 16.0, *)
private enum BlockingImpl {
  static let store = ManagedSettingsStore()

  static func load() -> FamilyActivitySelection {
    guard
      let data = UserDefaults.standard.data(forKey: FocusBlocking.selectionKey),
      let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    else { return FamilyActivitySelection() }
    return selection
  }

  static func save(_ selection: FamilyActivitySelection) {
    if let data = try? JSONEncoder().encode(selection) {
      UserDefaults.standard.set(data, forKey: FocusBlocking.selectionKey)
    }
  }

  static func counts(_ s: FamilyActivitySelection) -> [String: Int] {
    ["apps": s.applicationTokens.count, "categories": s.categoryTokens.count, "sites": s.webDomainTokens.count]
  }

  static func status() -> String {
    switch AuthorizationCenter.shared.authorizationStatus {
    case .approved: return "authorized"
    case .denied: return "denied"
    case .notDetermined: return "notDetermined"
    @unknown default: return "unknown"
    }
  }

  static func handle(_ method: String, _ args: [String: Any], _ result: @escaping FlutterResult) {
    switch method {
    case "blockingStatus":
      result(status())

    case "requestBlocking":
      Task { @MainActor in
        do {
          try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
          result(status() == "authorized")
        } catch {
          // Typically: the build lacks the Family Controls entitlement.
          result(false)
        }
      }

    case "blockedCounts":
      result(counts(load()))

    case "pickBlockedApps":
      guard let top = topViewController() else {
        result(nil)
        return
      }
      var host: UIViewController?
      let view = PickerView(
        initial: load(),
        doneTitle: args["done"] as? String ?? "Done",
        cancelTitle: args["cancel"] as? String ?? "Cancel"
      ) { picked in
        host?.dismiss(animated: true)
        if let picked = picked {
          save(picked)
          result(counts(picked))
        } else {
          result(nil)
        }
      }
      let controller = UIHostingController(rootView: view)
      controller.isModalInPresentation = true
      host = controller
      top.present(controller, animated: true)

    case "startShield":
      let s = load()
      if s.applicationTokens.isEmpty && s.categoryTokens.isEmpty && s.webDomainTokens.isEmpty {
        result(false)
        return
      }
      store.shield.applications = s.applicationTokens.isEmpty ? nil : s.applicationTokens
      store.shield.applicationCategories = s.categoryTokens.isEmpty ? nil : .specific(s.categoryTokens)
      store.shield.webDomains = s.webDomainTokens.isEmpty ? nil : s.webDomainTokens
      result(true)

    case "stopShield":
      store.clearAllSettings()
      result(true)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  static func topViewController() -> UIViewController? {
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
    var top = (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
}

@available(iOS 16.0, *)
private struct PickerView: View {
  @State private var selection: FamilyActivitySelection
  let doneTitle: String
  let cancelTitle: String
  let onFinish: (FamilyActivitySelection?) -> Void

  init(
    initial: FamilyActivitySelection,
    doneTitle: String,
    cancelTitle: String,
    onFinish: @escaping (FamilyActivitySelection?) -> Void
  ) {
    _selection = State(initialValue: initial)
    self.doneTitle = doneTitle
    self.cancelTitle = cancelTitle
    self.onFinish = onFinish
  }

  var body: some View {
    NavigationView {
      FamilyActivityPicker(selection: $selection)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button(cancelTitle) { onFinish(nil) }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button(doneTitle) { onFinish(selection) }
          }
        }
    }
  }
}
#endif

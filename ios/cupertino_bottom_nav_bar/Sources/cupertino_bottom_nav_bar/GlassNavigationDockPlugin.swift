import Flutter
import UIKit

/// Registers the package's presentation-only UIKit navigation dock.
///
/// Flutter owns resolved destination data, accepted selection and routes.
/// iOS versions before 26 report no native glass support so callers can retain
/// their portable Flutter renderer.
public final class GlassNavigationDockPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    registrar.register(
      GlassNavigationDockFactory(registrar: registrar),
      withId: "cupertino_bottom_nav_bar/native_navigation_dock"
    )
  }
}

/// Implements presentation-only native navigation for the package.
/// Flutter continues to own destination data, navigation and page lifetimes.
private final class GlassNavigationDockFactory: NSObject, FlutterPlatformViewFactory {
  private weak var registrar: FlutterPluginRegistrar?
  private let messenger: FlutterBinaryMessenger
  private let discovery: FlutterMethodChannel

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    messenger = registrar.messenger()
    discovery = FlutterMethodChannel(
      name: "cupertino_bottom_nav_bar/native_navigation", binaryMessenger: messenger
    )
    super.init()
    discovery.setMethodCallHandler { call, result in
      guard call.method == "supportsGlass" else {
        result(FlutterMethodNotImplemented)
        return
      }
      if #available(iOS 26.0, *) {
        result(true)
      } else {
        result(false)
      }
    }
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?
  ) -> FlutterPlatformView {
    if #available(iOS 26.0, *) {
      return GlassNavigationDockPlatformView(
        frame: frame, viewId: viewId, messenger: messenger, arguments: args,
        parentProvider: { [weak registrar] in registrar?.viewController }
      )
    }
    return GlassNavigationUnsupportedDockView(frame: frame)
  }
}

private final class GlassNavigationUnsupportedDockView: NSObject, FlutterPlatformView {
  private let surface: UIView

  init(frame: CGRect) {
    surface = UIView(frame: frame)
    super.init()
    surface.isUserInteractionEnabled = false
    surface.accessibilityElementsHidden = true
  }

  func view() -> UIView { surface }
}

@available(iOS 26.0, *)
private final class GlassNavigationDockPlatformView: NSObject, FlutterPlatformView {
  private let surface: GlassNavigationDockHostView

  init(
    frame: CGRect, viewId: Int64, messenger: FlutterBinaryMessenger, arguments: Any?,
    parentProvider: @escaping () -> UIViewController?
  ) {
    surface = GlassNavigationDockHostView(
      frame: frame, viewId: viewId, messenger: messenger, arguments: arguments,
      parentProvider: parentProvider
    )
    super.init()
  }

  func view() -> UIView { surface }

  deinit { surface.dispose() }
}

@available(iOS 26.0, *)
private struct GlassNavigationDockPayload {
  struct Item {
    let label: String
    let semanticLabel: String
    let badge: String?
    let enabled: Bool
    let iconData: Data
    let selectedIconData: Data
    let originalImage: Bool
    let icon: UIImage
    let selectedIcon: UIImage
  }

  let items: [Item]
  let selectedIndex: Int
  let semanticLabel: String?
  let selectedARGB: UInt32
  let foregroundARGB: UInt32
  let badgeARGB: UInt32
  let badgeForegroundARGB: UInt32
  let style: UIUserInterfaceStyle
  let labelSize: CGFloat
  let captionMaxWidth: CGFloat
  let imageScale: CGFloat
  let reduceMotion: Bool
  let visible: Bool

  init?(_ arguments: Any?) {
    guard let values = arguments as? [String: Any],
      let sourceItems = values["items"] as? [[String: Any]],
      (3...5).contains(sourceItems.count),
      let selectedIndex = (values["selectedIndex"] as? NSNumber)?.intValue,
      sourceItems.indices.contains(selectedIndex),
      let selected = values["selectedColor"] as? NSNumber,
      let foreground = values["foregroundColor"] as? NSNumber,
      let badge = values["badgeColor"] as? NSNumber,
      let badgeForeground = values["badgeForegroundColor"] as? NSNumber,
      let brightness = values["brightness"] as? String,
      brightness == "light" || brightness == "dark",
      let labelSize = (values["labelSize"] as? NSNumber)?.doubleValue,
      labelSize.isFinite, labelSize > 0,
      let captionMaxWidth = (values["captionMaxWidth"] as? NSNumber)?.doubleValue,
      captionMaxWidth.isFinite, captionMaxWidth > 0,
      let imageScale = (values["imageScale"] as? NSNumber)?.doubleValue,
      imageScale.isFinite, imageScale > 0,
      let reduceMotion = values["reduceMotion"] as? Bool,
      let visible = values["visible"] as? Bool
    else { return nil }

    var items: [Item] = []
    for item in sourceItems {
      guard let label = item["label"] as? String,
        let semanticLabel = item["semanticLabel"] as? String,
        let enabled = item["enabled"] as? Bool,
        let originalImage = item["originalImage"] as? Bool,
        let iconData = (item["icon"] as? FlutterStandardTypedData)?.data,
        let selectedIconData = (item["selectedIcon"] as? FlutterStandardTypedData)?.data,
        let icon = UIImage(data: iconData, scale: CGFloat(imageScale)),
        let selectedIcon = UIImage(data: selectedIconData, scale: CGFloat(imageScale))
      else { return nil }
      let renderingMode: UIImage.RenderingMode = originalImage ? .alwaysOriginal : .alwaysTemplate
      items.append(
        Item(
          label: label, semanticLabel: semanticLabel, badge: item["badge"] as? String,
          enabled: enabled, iconData: iconData, selectedIconData: selectedIconData,
          originalImage: originalImage, icon: icon.withRenderingMode(renderingMode),
          selectedIcon: selectedIcon.withRenderingMode(renderingMode)
        )
      )
    }
    self.items = items
    self.selectedIndex = selectedIndex
    semanticLabel = values["semanticLabel"] as? String
    selectedARGB = UInt32(truncatingIfNeeded: selected.uint64Value)
    foregroundARGB = UInt32(truncatingIfNeeded: foreground.uint64Value)
    badgeARGB = UInt32(truncatingIfNeeded: badge.uint64Value)
    badgeForegroundARGB = UInt32(truncatingIfNeeded: badgeForeground.uint64Value)
    style = brightness == "dark" ? .dark : .light
    self.labelSize = CGFloat(labelSize)
    self.captionMaxWidth = CGFloat(captionMaxWidth)
    self.imageScale = CGFloat(imageScale)
    self.reduceMotion = reduceMotion
    self.visible = visible
  }

  var captionsFit: Bool {
    let font = UIFont.systemFont(ofSize: labelSize)
    return items.allSatisfy {
      ($0.label as NSString).size(withAttributes: [.font: font]).width <= captionMaxWidth
    }
  }

  func hasSameAppearance(as other: GlassNavigationDockPayload?) -> Bool {
    guard let other else { return false }
    return selectedARGB == other.selectedARGB && foregroundARGB == other.foregroundARGB
      && badgeARGB == other.badgeARGB && badgeForegroundARGB == other.badgeForegroundARGB
      && labelSize == other.labelSize && style == other.style
  }

  static func color(_ argb: UInt32) -> UIColor {
    UIColor(
      red: CGFloat((argb >> 16) & 0xff) / 255,
      green: CGFloat((argb >> 8) & 0xff) / 255,
      blue: CGFloat(argb & 0xff) / 255,
      alpha: CGFloat((argb >> 24) & 0xff) / 255
    )
  }
}

/// Transparent placeholder pages let UIKit own its native tab interaction.
/// They never replace or hold the Flutter feature screens above the dock.
@available(iOS 26.0, *)
private final class GlassNavigationPlaceholderController: UIViewController {
  override func loadView() {
    let placeholder = UIView()
    placeholder.backgroundColor = .clear
    placeholder.isOpaque = false
    placeholder.isUserInteractionEnabled = false
    placeholder.accessibilityElementsHidden = true
    view = placeholder
  }
}

@available(iOS 26.0, *)
private final class GlassNavigationTabBarController: UITabBarController {
  var onLayout: (() -> Void)?

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    onLayout?()
  }
}

@available(iOS 26.0, *)
private final class GlassNavigationDockHostView: UIView, UITabBarControllerDelegate {
  private struct Entry {
    let controller: GlassNavigationPlaceholderController
    let tab: UITab
  }

  private let tabController = GlassNavigationTabBarController()
  private let channel: FlutterMethodChannel
  private let parentProvider: () -> UIViewController?
  private var containmentConstraints: [NSLayoutConstraint] = []
  private var entries: [Entry] = []
  private var payload: GlassNavigationDockPayload?
  private var visible = true
  private var presentationReady = false
  private var measurementSequence = 0
  private var disposed = false
  private var selectionRevision: UInt64 = 0
  private var layoutRevision = 0
  private var lastLayoutMetrics: [String: Any]?
  #if DEBUG
    private var lastLayoutReport: String?
  #endif

  init(
    frame: CGRect, viewId: Int64, messenger: FlutterBinaryMessenger, arguments: Any?,
    parentProvider: @escaping () -> UIViewController?
  ) {
    channel = FlutterMethodChannel(
      name: "cupertino_bottom_nav_bar/native_navigation_dock/\(viewId)", binaryMessenger: messenger
    )
    self.parentProvider = parentProvider
    super.init(frame: frame)
    backgroundColor = .clear
    isOpaque = false
    clipsToBounds = true
    isAccessibilityElement = false
    tabController.mode = .tabBar
    tabController.tabBarMinimizeBehavior = .never
    tabController.delegate = self
    tabController.view.backgroundColor = .clear
    tabController.view.isOpaque = false
    tabController.view.clipsToBounds = true
    tabController.onLayout = { [weak self] in
      self?.configureBarItems()
      self?.reportLayoutMetrics()
    }
    setVisible(true)

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self, !self.disposed else {
        result(FlutterError(code: "dock_disposed", message: "Dock is unavailable.", details: nil))
        return
      }
      switch call.method {
      case "update":
        guard let next = GlassNavigationDockPayload(call.arguments) else {
          result(
            FlutterError(
              code: "invalid_dock", message: "Invalid dock presentation data.", details: nil)
          )
          return
        }
        guard next.captionsFit else {
          result(
            FlutterError(
              code: "caption_overflow",
              message: "Native dock captions exceed their available width.", details: nil)
          )
          return
        }
        guard let values = call.arguments as? [String: Any],
          let revision = values["layoutRevision"] as? Int, revision > 0
        else {
          result(
            FlutterError(code: "invalid_dock", message: "Invalid layout revision.", details: nil))
          return
        }
        self.layoutRevision = revision
        self.update(next)
        result(nil)
      case "layoutMetrics":
        self.tabController.view.setNeedsLayout()
        self.tabController.view.layoutIfNeeded()
        result(self.sequencedLayoutMetrics())
      case "presentation":
        guard let values = call.arguments as? [String: Any],
          let ready = values["ready"] as? Bool
        else {
          result(
            FlutterError(
              code: "invalid_presentation", message: "Invalid presentation readiness.", details: nil
            ))
          return
        }
        if ready {
          guard let revision = values["layoutRevision"] as? Int,
            revision == self.layoutRevision, let metrics = self.layoutMetrics(),
            let height = metrics["height"] as? CGFloat,
            let minimum = metrics["minimumHeight"] as? CGFloat,
            let overflow = metrics["topOverflow"] as? CGFloat
          else {
            result(false)
            return
          }
          let tolerance = 1 / max(1, self.traitCollection.displayScale)
          guard height + tolerance >= minimum, overflow <= tolerance else {
            result(false)
            return
          }
        }
        if self.presentationReady != ready { self.selectionRevision &+= 1 }
        self.presentationReady = ready
        self.setVisible(self.visible)
        result(ready)
      case "visibility":
        guard let values = call.arguments as? [String: Any],
          let visible = values["visible"] as? Bool
        else {
          result(
            FlutterError(
              code: "invalid_visibility", message: "Invalid dock visibility.", details: nil)
          )
          return
        }
        self.setVisible(visible)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    if let initial = GlassNavigationDockPayload(arguments), initial.captionsFit,
      let values = arguments as? [String: Any],
      let revision = values["layoutRevision"] as? Int, revision > 0
    {
      layoutRevision = revision
      update(initial)
    }
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window == nil {
      lastLayoutMetrics = nil
      detachController()
    } else if !disposed {
      attachController()
    }
  }

  func dispose() {
    guard !disposed else { return }
    disposed = true
    setVisible(false)
    channel.setMethodCallHandler(nil)
    tabController.delegate = nil
    tabController.onLayout = nil
    detachController()
  }

  private func attachController() {
    var responder: UIResponder? = superview
    var ancestor: UIViewController?
    while let current = responder {
      if let controller = current as? UIViewController {
        ancestor = controller
        break
      }
      responder = current.next
    }
    guard let parent = ancestor ?? parentProvider(), parent !== tabController else { return }
    if tabController.parent === parent { return }
    detachController()
    parent.addChild(tabController)
    let childView = tabController.view!
    childView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(childView)
    containmentConstraints = [
      childView.leadingAnchor.constraint(equalTo: leadingAnchor),
      childView.trailingAnchor.constraint(equalTo: trailingAnchor),
      childView.topAnchor.constraint(equalTo: topAnchor),
      childView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ]
    NSLayoutConstraint.activate(containmentConstraints)
    tabController.didMove(toParent: parent)
  }

  private func detachController() {
    guard tabController.parent != nil else { return }
    tabController.willMove(toParent: nil)
    NSLayoutConstraint.deactivate(containmentConstraints)
    containmentConstraints.removeAll()
    tabController.view.removeFromSuperview()
    tabController.removeFromParent()
  }

  private func update(_ next: GlassNavigationDockPayload) {
    selectionRevision &+= 1
    let previous = payload
    let reduceMotion = next.reduceMotion || UIAccessibility.isReduceMotionEnabled
    let apply = {
      self.overrideUserInterfaceStyle = next.style
      self.tabController.overrideUserInterfaceStyle = next.style
      while self.entries.count < next.items.count {
        let index = self.entries.count
        let placeholder = GlassNavigationPlaceholderController()
        let tab = UITab(title: "", image: nil, identifier: "destination_\(index)") { _ in
          placeholder
        }
        tab.preferredPlacement = .fixed
        tab.allowsHiding = false
        self.entries.append(Entry(controller: placeholder, tab: tab))
      }
      for index in next.items.indices {
        let entry = self.entries[index]
        let item = next.items[index]
        let old = previous?.items.indices.contains(index) == true ? previous?.items[index] : nil
        if old?.label != item.label { entry.tab.title = item.label }
        if old?.semanticLabel != item.semanticLabel {
          entry.tab.accessibilityLabel = item.semanticLabel
        }
        if old?.badge != item.badge { entry.tab.badgeValue = item.badge }
        if old?.enabled != item.enabled { entry.tab.isEnabled = item.enabled }
        let imagesChanged =
          old?.iconData != item.iconData
          || old?.selectedIconData != item.selectedIconData
          || old?.originalImage != item.originalImage || previous?.imageScale != next.imageScale
        if #available(iOS 26.1, *) {
          if imagesChanged {
            entry.tab.image = item.icon
            entry.tab.selectedImage = item.selectedIcon
          }
        } else if imagesChanged || previous?.selectedIndex != next.selectedIndex {
          entry.tab.image = index == next.selectedIndex ? item.selectedIcon : item.icon
        }
      }
      if self.tabController.tabs.count != next.items.count {
        self.tabController.setTabs(
          Array(self.entries.prefix(next.items.count)).map(\.tab),
          animated: previous != nil && !reduceMotion
        )
      }
      self.payload = next
      if !next.hasSameAppearance(as: previous) { self.configureAppearance(next) }
      self.tabController.tabBar.accessibilityLabel = next.semanticLabel
      self.tabController.tabBar.isAccessibilityElement = false
      if self.tabController.selectedTab !== self.entries[next.selectedIndex].tab {
        self.tabController.selectedTab = self.entries[next.selectedIndex].tab
      }
      self.setVisible(next.visible)
      self.configureBarItems()
      self.tabController.view.setNeedsLayout()
      self.tabController.view.layoutIfNeeded()
    }
    if reduceMotion {
      UIView.performWithoutAnimation(apply)
    } else {
      apply()
    }
  }

  private func configureAppearance(_ presentation: GlassNavigationDockPayload) {
    let selected = GlassNavigationDockPayload.color(presentation.selectedARGB)
    let foreground = GlassNavigationDockPayload.color(presentation.foregroundARGB)
    tabController.tabBar.tintColor = selected
    tabController.tabBar.unselectedItemTintColor = foreground
    // Copy UIKit's appearance and edit only item foregrounds. Its system
    // background, Liquid Glass material and selection indicator stay intact.
    let standard = tabController.tabBar.standardAppearance.copy()
    configureItemAppearance(standard, presentation: presentation)
    tabController.tabBar.standardAppearance = standard
    if let edge = tabController.tabBar.scrollEdgeAppearance?.copy() {
      configureItemAppearance(edge, presentation: presentation)
      tabController.tabBar.scrollEdgeAppearance = edge
    }
  }

  private func configureItemAppearance(
    _ appearance: UITabBarAppearance, presentation: GlassNavigationDockPayload
  ) {
    let foreground = GlassNavigationDockPayload.color(presentation.foregroundARGB)
    let selected = GlassNavigationDockPayload.color(presentation.selectedARGB)
    let font = UIFont.systemFont(ofSize: presentation.labelSize)
    for item in [
      appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance,
      appearance.compactInlineLayoutAppearance,
    ] {
      item.normal.iconColor = foreground
      item.normal.titleTextAttributes = [.font: font, .foregroundColor: foreground]
      item.selected.iconColor = selected
      item.selected.titleTextAttributes = [.font: font, .foregroundColor: selected]
      for state in [item.normal, item.selected, item.disabled, item.focused] {
        state.badgeBackgroundColor = GlassNavigationDockPayload.color(presentation.badgeARGB)
        state.badgeTextAttributes = [
          .foregroundColor: GlassNavigationDockPayload.color(presentation.badgeForegroundARGB)
        ]
      }
    }
  }

  private func configureBarItems() {
    guard let payload else { return }
    for (index, barItem) in (tabController.tabBar.items ?? []).enumerated()
    where payload.items.indices.contains(index) {
      let item = payload.items[index]
      if barItem.accessibilityLabel != item.semanticLabel {
        barItem.accessibilityLabel = item.semanticLabel
      }
      let badgeColor = GlassNavigationDockPayload.color(payload.badgeARGB)
      if barItem.badgeColor != badgeColor { barItem.badgeColor = badgeColor }
      let badgeForeground = GlassNavigationDockPayload.color(payload.badgeForegroundARGB)
      let badgeAttributes: [NSAttributedString.Key: Any] = [
        .foregroundColor: badgeForeground
      ]
      for state in [UIControl.State.normal, .selected, .disabled, .focused, .highlighted] {
        let currentColor = barItem.badgeTextAttributes(for: state)?[.foregroundColor] as? UIColor
        if currentColor != badgeForeground {
          barItem.setBadgeTextAttributes(badgeAttributes, for: state)
        }
      }
    }
    #if DEBUG
      reportLayout()
    #endif
  }

  private func setVisible(_ visible: Bool) {
    if self.visible != visible { selectionRevision &+= 1 }
    self.visible = visible
    let presented = visible && presentationReady
    alpha = presented ? 1 : 0
    // A preparing view stays attached and laid out, but cannot paint or interact.
    isHidden = !visible
    isUserInteractionEnabled = presented
    accessibilityElementsHidden = !presented
    tabController.view.isUserInteractionEnabled = presented
    tabController.view.accessibilityElementsHidden = !presented
    if !presented { endEditing(true) }
  }

  /// Measure UIKit's system bar without changing its frame or safe area.
  private func layoutMetrics() -> [String: Any]? {
    guard !disposed, payload != nil, layoutRevision > 0, window != nil,
      bounds.width.isFinite, bounds.height.isFinite, bounds.width > 0, bounds.height > 0
    else { return nil }
    let barFrame = tabController.tabBar.convert(tabController.tabBar.bounds, to: self)
    let fitting = tabController.tabBar.sizeThatFits(
      CGSize(width: bounds.width, height: CGFloat.greatestFiniteMagnitude)
    ).height
    guard fitting.isFinite, fitting > 0, barFrame.minY.isFinite,
      barFrame.height.isFinite, barFrame.height > 0
    else { return nil }
    let overflow = max(0, -barFrame.minY)
    let overflowMinimum = overflow > 0 ? bounds.height + overflow : 0
    let minimum = max(fitting, max(barFrame.height, overflowMinimum))
    guard minimum.isFinite, minimum > 0 else { return nil }
    return [
      "revision": layoutRevision, "width": bounds.width, "height": bounds.height,
      "minimumHeight": minimum, "topOverflow": overflow,
    ]
  }

  private func reportLayoutMetrics() {
    guard let metrics = layoutMetrics() else { return }
    if let previous = lastLayoutMetrics, NSDictionary(dictionary: metrics).isEqual(to: previous) {
      return
    }
    lastLayoutMetrics = metrics
    channel.invokeMethod("layoutMetrics", arguments: sequence(metrics))
  }

  // One publication order covers both unsolicited callbacks and query replies.
  // Presentation checks still measure without publishing or advancing it.
  private func sequence(_ metrics: [String: Any]) -> [String: Any] {
    measurementSequence += 1
    var result = metrics
    result["measurementSequence"] = measurementSequence
    return result
  }

  private func sequencedLayoutMetrics() -> [String: Any]? {
    guard let metrics = layoutMetrics() else { return nil }
    return sequence(metrics)
  }

  func tabBarController(_ tabBarController: UITabBarController, shouldSelectTab tab: UITab) -> Bool
  {
    guard !disposed, visible, presentationReady, window != nil, let payload,
      let index = entries.prefix(payload.items.count).firstIndex(where: { $0.tab === tab }),
      payload.items[index].enabled
    else { return false }
    selectionRevision &+= 1
    let revision = selectionRevision
    channel.invokeMethod("select", arguments: index) { [weak self] response in
      guard let self, !self.disposed, self.visible, self.presentationReady, self.window != nil,
        self.selectionRevision == revision, let latest = self.payload
      else { return }
      let acceptedIndex: Int
      if let acknowledgedIndex = response as? Int,
        latest.items.indices.contains(acknowledgedIndex)
      {
        acceptedIndex = acknowledgedIndex
      } else {
        // Failed, absent or malformed acknowledgements cannot accept a request.
        // The last supplied selection was already validated by the payload.
        acceptedIndex = latest.selectedIndex
      }
      // Flutter replies after its frame with the host's accepted selection.
      // A no-op, rejected or failed callback can restore the existing tab,
      // without cancelling UIKit's immediate native gesture feedback.
      let settle = {
        if #unavailable(iOS 26.1) {
          for itemIndex in latest.items.indices {
            let item = latest.items[itemIndex]
            self.entries[itemIndex].tab.image =
              itemIndex == acceptedIndex ? item.selectedIcon : item.icon
          }
        }
        let acceptedTab = self.entries[acceptedIndex].tab
        if self.tabController.selectedTab !== acceptedTab {
          self.tabController.selectedTab = acceptedTab
        }
        self.tabController.view.layoutIfNeeded()
      }
      if latest.reduceMotion || UIAccessibility.isReduceMotionEnabled {
        UIView.performWithoutAnimation(settle)
      } else {
        settle()
      }
    }
    return true
  }

  #if DEBUG
    /// Only reports public UIKit geometry; the bar's system frame is never changed.
    private func reportLayout() {
      guard window != nil, bounds.width > 0, bounds.height > 0 else { return }
      let barFrame = tabController.tabBar.convert(tabController.tabBar.bounds, to: self)
      let fitting = tabController.tabBar.sizeThatFits(
        CGSize(width: bounds.width, height: CGFloat.greatestFiniteMagnitude)
      ).height
      let report =
        "host=\(NSCoder.string(for: bounds)) tabBar=\(NSCoder.string(for: barFrame)) "
        + "fittingHeight=\(fitting) safeBottom=\(tabController.view.safeAreaInsets.bottom)"
      guard report != lastLayoutReport else { return }
      lastLayoutReport = report
      NSLog("[NativeNavigationDock] %@", report)
    }
  #endif
}

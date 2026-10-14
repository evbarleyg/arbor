// A stand-in for AppKit: menus and the status bar. See Application.swift.

@MainActor public protocol NSMenuDelegate: NSObjectProtocol {
  func menuNeedsUpdate(_ menu: NSMenu)
  func numberOfItems(in menu: NSMenu) -> Int
  func menu(_ menu: NSMenu, update item: NSMenuItem, at index: Int, shouldCancel: Bool) -> Bool
  func menuWillOpen(_ menu: NSMenu)
  func menuDidClose(_ menu: NSMenu)
  func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?)
  func confinementRect(for menu: NSMenu, on screen: NSScreen?) -> NSRect
}
extension NSMenuDelegate {
  public func menuNeedsUpdate(_ menu: NSMenu) {}
  public func numberOfItems(in menu: NSMenu) -> Int { -1 }
  public func menu(_ menu: NSMenu, update item: NSMenuItem, at index: Int, shouldCancel: Bool) -> Bool { true }
  public func menuWillOpen(_ menu: NSMenu) {}
  public func menuDidClose(_ menu: NSMenu) {}
  public func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {}
  public func confinementRect(for menu: NSMenu, on screen: NSScreen?) -> NSRect { .zero }
}
@MainActor public protocol NSMenuItemValidation: NSObjectProtocol {
  func validateMenuItem(_ menuItem: NSMenuItem) -> Bool
}

@MainActor open class NSMenu: NSObject {
  public init(title: String) {}
  public required init(coder: NSCoder) {}
  public convenience override init() { self.init(title: "") }
  open var title = ""
  open var items: [NSMenuItem] = []
  open var numberOfItems: Int { 0 }
  open weak var delegate: (any NSMenuDelegate)?
  open var supermenu: NSMenu?
  open var autoenablesItems = true
  open var showsStateColumn = true
  open var allowsContextMenuPlugIns = true
  open var minimumWidth: CGFloat = 0
  open var size: NSSize { .zero }
  open var font: NSFont!
  open var highlightedItem: NSMenuItem? { nil }
  open var userInterfaceLayoutDirection: NSUserInterfaceLayoutDirection = .leftToRight
  open class func popUpContextMenu(_ menu: NSMenu, with event: NSEvent, for view: NSView) {}
  open class func menuBarVisible() -> Bool { true }
  open class func setMenuBarVisible(_ visible: Bool) {}
  open func addItem(_ newItem: NSMenuItem) {}
  @discardableResult open func addItem(withTitle string: String, action selector: Selector?, keyEquivalent charCode: String) -> NSMenuItem {
    NSMenuItem()
  }
  open func insertItem(_ newItem: NSMenuItem, at index: Int) {}
  @discardableResult open func insertItem(withTitle string: String, action selector: Selector?, keyEquivalent charCode: String, at index: Int)
    -> NSMenuItem
  { NSMenuItem() }
  open func removeItem(_ item: NSMenuItem) {}
  open func removeItem(at index: Int) {}
  open func removeAllItems() {}
  open func setSubmenu(_ menu: NSMenu?, for item: NSMenuItem) {}
  open func item(at index: Int) -> NSMenuItem? { nil }
  open func item(withTitle title: String) -> NSMenuItem? { nil }
  open func item(withTag tag: Int) -> NSMenuItem? { nil }
  open func index(of item: NSMenuItem) -> Int { -1 }
  open func indexOfItem(withTitle title: String) -> Int { -1 }
  open func indexOfItem(withTag tag: Int) -> Int { -1 }
  open func indexOfItem(withRepresentedObject object: Any?) -> Int { -1 }
  open func update() {}
  open func itemChanged(_ item: NSMenuItem) {}
  open func performActionForItem(at index: Int) {}
  open func performKeyEquivalent(with event: NSEvent) -> Bool { false }
  open func cancelTracking() {}
  open func cancelTrackingWithoutAnimation() {}
  @discardableResult open func popUp(positioning item: NSMenuItem?, at location: NSPoint, in view: NSView?) -> Bool { false }
  public nonisolated static let didBeginTrackingNotification = NSNotification.Name("NSMenuDidBeginTrackingNotification")
  public nonisolated static let didEndTrackingNotification = NSNotification.Name("NSMenuDidEndTrackingNotification")
}

@MainActor open class NSMenuItem: NSObject, NSValidatedUserInterfaceItem, NSUserInterfaceItemIdentification {
  public init(title string: String, action selector: Selector?, keyEquivalent charCode: String) {}
  public required init(coder: NSCoder) {}
  public convenience override init() { self.init(title: "", action: nil, keyEquivalent: "") }
  open class func separator() -> NSMenuItem { NSMenuItem() }
  open class func sectionHeader(title: String) -> NSMenuItem { NSMenuItem() }
  open var title = ""
  open var attributedTitle: NSAttributedString?
  open var subtitle: String?
  open var menu: NSMenu?
  open var submenu: NSMenu?
  open var hasSubmenu: Bool { false }
  open var parent: NSMenuItem? { nil }
  open var isSeparatorItem: Bool { false }
  open var isSectionHeader: Bool { false }
  open var keyEquivalent = ""
  open var keyEquivalentModifierMask: NSEvent.ModifierFlags = .command
  open var allowsKeyEquivalentWhenHidden = false
  open var allowsAutomaticKeyEquivalentLocalization = true
  open var allowsAutomaticKeyEquivalentMirroring = true
  open var image: NSImage?
  open var state: NSControl.StateValue = .off
  open var onStateImage: NSImage!
  open var offStateImage: NSImage?
  open var mixedStateImage: NSImage!
  open var isEnabled = true
  open var isHidden = false
  open var isHiddenOrHasHiddenAncestor: Bool { false }
  open var isAlternate = false
  open var isHighlighted: Bool { false }
  open var indentationLevel = 0
  open weak var target: AnyObject?
  open var action: Selector?
  open var tag = 0
  open var representedObject: Any?
  open var view: NSView?
  open var toolTip: String?
  open var identifier: NSUserInterfaceItemIdentifier?
  open var badge: NSMenuItemBadge?
}
open class NSMenuItemBadge: NSObject {
  public enum BadgeType: Int, Sendable { case none = 0, updates, newItems, alerts }
  public init(count itemCount: Int) {}
  public init(string: String) {}
}

@MainActor open class NSStatusBar: NSObject {
  open class var system: NSStatusBar { NSStatusBar() }
  open var thickness: CGFloat { 22 }
  open var isVertical: Bool { false }
  open func statusItem(withLength length: CGFloat) -> NSStatusItem { NSStatusItem() }
  open func removeStatusItem(_ item: NSStatusItem) {}
}
@MainActor open class NSStatusItem: NSObject {
  public typealias AutosaveName = String
  public struct Behavior: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let removalAllowed = Behavior(rawValue: 2)
    public static let terminationOnRemoval = Behavior(rawValue: 4)
  }
  public nonisolated static let variableLength: CGFloat = -1
  public nonisolated static let squareLength: CGFloat = -2
  open var statusBar: NSStatusBar? { nil }
  open var length: CGFloat = 0
  open var menu: NSMenu?
  open var button: NSStatusBarButton? { nil }
  open var behavior: Behavior = []
  open var isVisible = true
  open var autosaveName: AutosaveName!
}
@MainActor open class NSStatusBarButton: NSButton {
  open var appearsDisabled = false
}

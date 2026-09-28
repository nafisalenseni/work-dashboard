import AppKit
import SwiftUI

// Reparent one hosting view, preserving the editor rather than opening a duplicate.
struct TodayWindowPortal: NSViewRepresentable {
  @Binding var detached: Bool
  let pinned: Bool
  let collapsed: Bool
  let dragEvent: NSEvent?
  let content: AnyView

  func makeCoordinator() -> Coordinator { Coordinator(content: content) }

  func makeNSView(context: Context) -> NSView {
    let container = NSView()
    context.coordinator.container = container
    context.coordinator.attachToPanel()
    return container
  }

  func updateNSView(_ view: NSView, context: Context) {
    let coordinator = context.coordinator
    coordinator.onClose = { detached = false }
    coordinator.host.rootView = content
    coordinator.update(detached: detached, pinned: pinned, collapsed: collapsed, dragEvent: dragEvent)
  }

  func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSView, context: Context) -> CGSize? {
    let width = proposal.width ?? 320
    if detached { return CGSize(width: width, height: 0) }
    let height = context.coordinator.host.sizeThatFits(
      in: CGSize(width: width, height: .greatestFiniteMagnitude)
    ).height
    return CGSize(width: width, height: height)
  }

  static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
    coordinator.floatingWindow?.delegate = nil
    coordinator.floatingWindow?.close()
    coordinator.floatingWindow = nil
    coordinator.onClose = nil
  }

  @MainActor final class Coordinator: NSObject, NSWindowDelegate {
    let host: NSHostingController<AnyView>
    weak var container: NSView?
    var floatingWindow: NSWindow?
    var onClose: (() -> Void)?
    private var isDetached = false
    private var isCollapsed = false
    private var expandedSize = NSSize(width: 400, height: 540)

    init(content: AnyView) {
      host = NSHostingController(rootView: content)
      host.safeAreaRegions = []
      super.init()
    }

    func attachToPanel() {
      guard let container else { return }
      host.view.removeFromSuperview()
      host.view.translatesAutoresizingMaskIntoConstraints = true
      host.view.frame = container.bounds
      host.view.autoresizingMask = [.width, .height]
      container.addSubview(host.view)
    }

    func update(detached: Bool, pinned: Bool, collapsed: Bool, dragEvent: NSEvent?) {
      if detached && !isDetached {
        isDetached = true
        isCollapsed = false
        let window = NSWindow(
          contentRect: NSRect(x: 0, y: 0, width: 400, height: 540),
          styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
          backing: .buffered,
          defer: false)
        window.title = "Today"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
          window.standardWindowButton(button)?.isHidden = true
        }
        window.minSize = NSSize(width: 300, height: 260)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setFrameAutosaveName("DailyGlow.Today")
        host.view.removeFromSuperview()
        host.view.autoresizingMask = [.width, .height]
        let backdrop = NSBox()
        backdrop.boxType = .custom
        backdrop.borderType = .noBorder
        backdrop.contentViewMargins = .zero
        backdrop.fillColor = NSColor(name: nil) { appearance in
          appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(red: 0.22, green: 0.20, blue: 0.13, alpha: 1)
            : NSColor(red: 1, green: 0.965, blue: 0.83, alpha: 1)
        }
        window.contentView = backdrop
        let canvas = backdrop.contentView ?? backdrop
        host.view.frame = canvas.bounds
        canvas.addSubview(host.view)
        floatingWindow = window
        if dragEvent != nil {
          let cursor = NSEvent.mouseLocation
          window.setFrameTopLeftPoint(NSPoint(x: cursor.x - 28, y: cursor.y + 28))
        } else {
          window.center()
        }
        window.makeKeyAndOrderFront(nil)
        if let event = dragEvent {
          DispatchQueue.main.async { [weak window] in
            guard let window, NSEvent.pressedMouseButtons & 1 != 0,
              let start = NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: window.convertPoint(fromScreen: NSEvent.mouseLocation),
                modifierFlags: event.modifierFlags, timestamp: event.timestamp,
                windowNumber: window.windowNumber, context: nil,
                eventNumber: event.eventNumber, clickCount: 1, pressure: event.pressure)
            else { return }
            window.performDrag(with: start)
          }
        }
      } else if !detached && isDetached {
        isDetached = false
        floatingWindow?.delegate = nil
        attachToPanel()
        floatingWindow?.close()
        floatingWindow = nil
      }
      if let window = floatingWindow, collapsed != isCollapsed {
        if collapsed { expandedSize = window.frame.size }
        isCollapsed = collapsed
        window.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: collapsed ? 58 : CGFloat.greatestFiniteMagnitude)
        window.minSize = NSSize(width: 300, height: collapsed ? 58 : 260)
        var frame = window.frame
        let top = frame.maxY
        frame.size.height = collapsed ? 58 : expandedSize.height
        frame.origin.y = top - frame.height
        window.setFrame(frame, display: true)
      }
      floatingWindow?.level = pinned ? .floating : .normal
      resizeDocument()
    }

    func resizeDocument() {
      guard isDetached, let canvas = host.view.superview else { return }
      host.view.frame = canvas.bounds
    }

    func windowDidResize(_ notification: Notification) { resizeDocument() }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
      // Returning Today to the panel is the only close behavior.
      onClose?()
      return false
    }
  }
}

struct TodayWindowDragHandle: NSViewRepresentable {
  let detached: Bool
  let onDetach: (NSEvent) -> Void
  let onClick: () -> Void

  func makeNSView(context: Context) -> DragView { DragView() }
  func updateNSView(_ view: DragView, context: Context) {
    view.detached = detached
    view.onDetach = onDetach
    view.onClick = onClick
  }

  final class DragView: NSView {
    var detached = false
    var onDetach: ((NSEvent) -> Void)?
    var onClick: (() -> Void)?
    private var start: NSPoint?
    private var dragged = false

    override func mouseDown(with event: NSEvent) {
      start = NSEvent.mouseLocation
      dragged = false
    }
    override func mouseDragged(with event: NSEvent) {
      guard !dragged, let start else { return }
      let cursor = NSEvent.mouseLocation
      guard hypot(cursor.x - start.x, cursor.y - start.y) > 5 else { return }
      dragged = true
      if detached { window?.performDrag(with: event) } else { onDetach?(event) }
    }
    override func mouseUp(with event: NSEvent) {
      if !dragged { onClick?() }
      start = nil
    }
    override func resetCursorRects() {
      addCursorRect(bounds, cursor: .openHand)
    }
  }
}

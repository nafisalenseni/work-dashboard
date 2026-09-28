import SwiftUI
import WebKit

struct BlockNoteEditorView: NSViewRepresentable {
  var storageKey = "dailyglow.notes.blocknote.document"
  var compact = false
  private static let messageHandlerName = "blockNoteDocument"

  func makeCoordinator() -> Coordinator {
    Coordinator(storageKey: storageKey)
  }

  // SwiftUI hosts a small web page because BlockNote is a React editor.
  func makeNSView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    if compact {
      configuration.userContentController.addUserScript(WKUserScript(
        source: """
          const style = document.createElement('style');
          style.textContent = '#root { padding: 20px 0; } .bn-container { --bn-font-family: -apple-system, BlinkMacSystemFont, sans-serif; } .bn-container .bn-editor { font-size: 14px; padding-inline: 36px 24px; }';
          document.head.appendChild(style);
          """,
        injectionTime: .atDocumentEnd,
        forMainFrameOnly: true
      ))
    }
    configuration.userContentController.add(
      context.coordinator,
      name: Self.messageHandlerName
    )

    // Inject saved notes before the HTML's editor script runs.
    let savedDocument = UserDefaults.standard.string(forKey: storageKey) ?? ""
    let encodedDocument = Data(savedDocument.utf8).base64EncodedString()
    configuration.userContentController.addUserScript(
      WKUserScript(
        source: "window.dailyGlowSavedDocument = '\(encodedDocument)';",
        injectionTime: .atDocumentStart,
        forMainFrameOnly: true
      ))

    let webView = WKWebView(
      frame: .zero,
      configuration: configuration
    )
    if let editorURL = Bundle.main.url(
      forResource: "index", withExtension: "html", subdirectory: "NotesEditorWeb")
    {
      webView.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())
    } else {
      webView.loadHTMLString(
        "<p>The notes editor build is missing from the app bundle.</p>", baseURL: nil)
    }

    return webView
  }

  func updateNSView(_ webView: WKWebView, context: Context) {}

  static func dismantleNSView(
    _ webView: WKWebView,
    coordinator: Coordinator
  ) {
    webView.configuration.userContentController.removeScriptMessageHandler(
      forName: Self.messageHandlerName
    )
  }

  // Receives JavaScript messages and saves the block document locally.
  final class Coordinator: NSObject, WKScriptMessageHandler {
    private let storageKey: String

    init(storageKey: String) {
      self.storageKey = storageKey
    }

    func userContentController(
      _ userContentController: WKUserContentController,
      didReceive message: WKScriptMessage
    ) {
      guard let document = message.body as? String else { return }
      UserDefaults.standard.set(document, forKey: storageKey)
    }
  }
}

#if DEBUG
  #Preview("BlockNote Editor") {
    BlockNoteEditorView()
      .frame(width: 420, height: 640)
  }
#endif

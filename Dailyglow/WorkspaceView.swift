import SwiftUI
import WebKit
import Network

struct WorkspaceView: View {
    var body: some View {
        PullDashWebView()
            .panelStyle()
    }
}

private struct PullDashWebView: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.addScriptMessageHandler(context.coordinator, contentWorld: .page, name: "dailyglowGitHub")
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        context.coordinator.start(view)
        return view
    }
    func updateNSView(_ view: WKWebView, context: Context) {}
    static func dismantleNSView(_ view: WKWebView, coordinator: Coordinator) {
        view.configuration.userContentController.removeScriptMessageHandler(forName: "dailyglowGitHub", contentWorld: .page)
        coordinator.server?.stop()
    }

    @MainActor final class Coordinator: NSObject, WKScriptMessageHandlerWithReply, WKNavigationDelegate, WKUIDelegate {
        var server: WorkspaceAssetServer?
        var origin: URL?
        func start(_ view: WKWebView) {
            guard let root = Bundle.main.url(forResource: "PullDashWeb", withExtension: nil) else {
                view.loadHTMLString("<p>Workspace assets are missing. Run npm run bundle from pulldash-workspace, then rebuild Dailyglow.</p>", baseURL: nil)
                return
            }
            do {
                server = try WorkspaceAssetServer(root: root)
                server?.start { [weak self, weak view] port in
                    Task { @MainActor in
                        let url = URL(string: "http://127.0.0.1:\(port)/")!
                        self?.origin = url
                        view?.load(URLRequest(url: url))
                    }
                }
            } catch {
                view.loadHTMLString("<p>Could not start the bundled workspace.</p>", baseURL: nil)
            }
        }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage, replyHandler: @escaping @MainActor @Sendable (Any?, String?) -> Void) {
            guard message.frameInfo.isMainFrame,
                  let origin, message.frameInfo.securityOrigin.host == "127.0.0.1",
                  message.frameInfo.securityOrigin.port == origin.port,
                  let args = message.body as? [String: Any], let path = args["path"] as? String,
                  let method = args["method"] as? String else { replyHandler(nil, "Untrusted workspace request"); return }
            let body = args["body"] as? String
            let headers = args["headers"] as? [String: String] ?? [:]
            Task {
                do {
                    let result = try await WorkspaceGitHub.request(path: path, method: method, headers: headers, body: body)
                    replyHandler(result, nil)
                } catch {
                    replyHandler(["status": 503, "headers": ["content-type": "application/json"], "body": "{\"message\":\"GitHub connection unavailable. Run gh auth login in Terminal, then reload Dailyglow.\"}"], nil)
                }
            }
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
            if url.host == origin?.host && url.port == origin?.port && url.scheme == "http" { decisionHandler(.allow) }
            else {
                if ["https", "http"].contains(url.scheme ?? "") { NSWorkspace.shared.open(url) }
                decisionHandler(.cancel)
            }
        }
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url, ["https", "http"].contains(url.scheme ?? "") { NSWorkspace.shared.open(url) }
            return nil
        }
    }
}

// Credentials stay native and come from the signed-in GitHub CLI session.
private enum WorkspaceGitHub {
    static func request(path: String, method: String, headers: [String: String], body: String?) async throws -> [String: Any] {
        let endpoint: String
        if path == "/api/session" && method == "GET" { endpoint = "user" }
        else if path.hasPrefix("/api/github/") { endpoint = String(path.dropFirst("/api/github/".count)) }
        else { throw URLError(.badURL) }
        guard ["GET", "POST", "PATCH", "PUT", "DELETE", "HEAD"].contains(method),
              let url = URL(string: "https://api.github.com/" + endpoint), url.host == "api.github.com",
              !endpoint.contains(".."), !endpoint.contains("\\"),
              ["user", "users", "repos", "search", "graphql", "orgs"].contains(url.path.split(separator: "/").first.map(String.init) ?? "") else { throw URLError(.badURL) }
        let token = try await Task.detached {
            guard let executable = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh"].first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else { throw URLError(.userAuthenticationRequired) }
            let process = Process(), output = Pipe()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = ["auth", "token", "--hostname", "github.com"]
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0, let value = String(data: data, encoding: .utf8), !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw URLError(.userAuthenticationRequired) }
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }.value
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = method
        request.httpBody = body.map { Data($0.utf8) }
        for key in ["accept", "content-type", "x-github-api-version"] { if let value = headers[key] { request.setValue(value, forHTTPHeaderField: key) } }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("Dailyglow", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        var resultHeaders: [String: String] = [:]
        for key in ["content-type", "x-ratelimit-remaining", "x-ratelimit-reset", "retry-after"] { resultHeaders[key] = response.value(forHTTPHeaderField: key) }
        return ["status": response.statusCode, "headers": resultHeaders, "body": String(decoding: data, as: UTF8.self)]
    }
}

// Serves only bundled public assets. GitHub credentials/API calls never use this socket.
nonisolated private final class WorkspaceAssetServer: @unchecked Sendable {
    private let listener: NWListener
    private let root: URL
    private let queue = DispatchQueue(label: "dailyglow.workspace.assets")
    init(root: URL) throws {
        self.root = root.resolvingSymlinksInPath()
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        listener = try NWListener(using: parameters)
    }
    func start(ready: @escaping @Sendable (UInt16) -> Void) {
        listener.stateUpdateHandler = { [weak self] state in
            if case .ready = state, let port = self?.listener.port { ready(port.rawValue) }
        }
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { connection.cancel(); return }
            connection.start(queue: self.queue)
            self.receive(connection, buffer: Data())
        }
        listener.start(queue: queue)
    }
    func stop() { listener.cancel() }
    private func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16384) { [weak self] data, _, complete, error in
            guard let self else { connection.cancel(); return }
            var buffer = buffer
            if let data { buffer.append(data) }
            guard buffer.count <= 32768, error == nil else { connection.cancel(); return }
            if buffer.range(of: Data("\r\n\r\n".utf8)) == nil {
                if complete { connection.cancel() } else { self.receive(connection, buffer: buffer) }
                return
            }
            let line = String(decoding: buffer, as: UTF8.self).components(separatedBy: "\r\n")[0].split(separator: " ")
            guard line.count >= 2, line[0] == "GET" else { connection.cancel(); return }
            let path = String(line[1]).components(separatedBy: "?")[0].removingPercentEncoding ?? ""
            let candidate = self.root.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))).standardizedFileURL.resolvingSymlinksInPath()
            guard candidate.path.hasPrefix(self.root.path + "/") || path == "/" else { connection.cancel(); return }
            let file = candidate.pathExtension.isEmpty ? self.root.appendingPathComponent("index.html") : candidate
            let data = try? Data(contentsOf: file)
            let mime = ["html": "text/html", "js": "text/javascript", "css": "text/css", "svg": "image/svg+xml", "woff2": "font/woff2", "png": "image/png"][file.pathExtension] ?? "application/octet-stream"
            let body = data ?? Data("Not found".utf8)
            let header = "HTTP/1.1 \(data == nil ? "404 Not Found" : "200 OK")\r\nContent-Type: \(mime)\r\nContent-Length: \(body.count)\r\nConnection: close\r\nCache-Control: no-cache\r\n\r\n"
            connection.send(content: Data(header.utf8) + body, completion: .contentProcessed { _ in connection.cancel() })
        }
    }
}

import Foundation
import Hummingbird
import HTTPTypes
import NIOCore
import NIOPosix

// MARK: - Response Helpers

func htmlResponse(_ content: String) -> Response {
  var headers = HTTPFields()
  headers[.contentType] = "text/html; charset=utf-8"
  return Response(status: .ok, headers: headers, body: .init { writer in
    let buffer = ByteBuffer(string: content)
    try await writer.write(buffer)
    try await writer.finish(nil)
  })
}

func cssResponse(_ content: String) -> Response {
  var headers = HTTPFields()
  headers[.contentType] = "text/css; charset=utf-8"
  return Response(status: .ok, headers: headers, body: .init { writer in
    let buffer = ByteBuffer(string: content)
    try await writer.write(buffer)
    try await writer.finish(nil)
  })
}

func jsResponse(_ content: String) -> Response {
  var headers = HTTPFields()
  headers[.contentType] = "application/javascript; charset=utf-8"
  return Response(status: .ok, headers: headers, body: .init { writer in
    let buffer = ByteBuffer(string: content)
    try await writer.write(buffer)
    try await writer.finish(nil)
  })
}

// MARK: - Request Context

struct WebRequestContext: RequestContext, RemoteAddressRequestContext {
  var coreContext: CoreRequestContextStorage
  let remoteAddress: SocketAddress?

  init(source: Source) {
    coreContext = .init(source: source)
    remoteAddress = source.channel.remoteAddress
  }
}

struct LocalNetworkMiddleware: RouterMiddleware {
  func handle(
    _ request: Request,
    context: WebRequestContext,
    next: (Request, WebRequestContext) async throws -> Response
  ) async throws -> Response {
    guard LocalNetworkMiddleware.isAllowedRemoteAddress(context.remoteAddress) else {
      return Response(status: .forbidden, headers: [.contentType: "text/plain"], body: .init { writer in
        let buffer = ByteBuffer(string: "Forbidden")
        try await writer.write(buffer)
        try await writer.finish(nil)
      })
    }

    return try await next(request, context)
  }

  static func isAllowedRemoteAddress(_ address: SocketAddress?) -> Bool {
    guard let address else { return false }
    guard let ip = address.ipAddress else { return false }

    if ip == "127.0.0.1" || ip == "::1" {
      return true
    }

    if ip.hasPrefix("192.168.") {
      return true
    }

    if ip.hasPrefix("10.") {
      return true
    }

    if ip.hasPrefix("172.") {
      let components = ip.split(separator: ".")
      if components.count >= 2, let second = Int(components[1]) {
        return second >= 16 && second <= 31
      }
    }

    if ip.hasPrefix("169.254.") {
      return true
    }

    if ip.hasPrefix("fc") || ip.hasPrefix("fd") {
      return true
    }

    return false
  }
}

/// HTTP server for exposing CCHistory sessions via web UI
/// Serves static files and provides JSON API endpoints
final class WebServer: @unchecked Sendable {
  // MARK: - Configuration

  private struct Configuration {
    static let defaultPort: UInt16 = 8000
    static let portKey = "webServerPort"
    static let enabledKey = "webServerEnabled"

    static var port: UInt16 {
      let saved = UserDefaults.standard.integer(forKey: portKey)
      return saved > 0 ? UInt16(saved) : defaultPort
    }

    static var isEnabled: Bool {
      get { UserDefaults.standard.bool(forKey: enabledKey) }
      set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }
  }

  // MARK: - Properties

  private var app: Application<RouterResponder<WebRequestContext>>?
  private var eventLoopGroup: EventLoopGroup?
  private var serverTask: Task<Void, Never>?
  private var eventSourceClients: [UUID: EventSourceClient] = [:]
  private var lastStartError: Error?

  /// Whether the server is currently running
  var isRunning: Bool { app != nil }

  /// The configured port number
  var port: UInt16 { Configuration.port }

  /// The server URL accessible on the local network
  var serverURL: URL? {
    return getLocalNetworkIP().flatMap { ip in
      URL(string: "http://\(ip):\(port)")
    }
  }

  /// Status string for settings UI
  var statusDescription: String {
    if let lastStartError {
      return "Failed to start: \(lastStartError.localizedDescription)"
    }
    return isRunning ? "Running on :\(port)" : "Stopped"
  }

  func recordStartError(_ error: Error) {
    lastStartError = error
  }

  // MARK: - Server Lifecycle

  /// Start the HTTP server
  func start() async throws {
    print("[WebServer] start() called, isRunning: \(isRunning)")
    guard !isRunning else {
      print("[WebServer] Already running, returning")
      return
    }

    lastStartError = nil

    // Create event loop group
    eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

    // Capture current port value
    let currentPort = Int(port)

    // Create router with web context
    let router = Router(context: WebRequestContext.self)
    router.middlewares.add(LocalNetworkMiddleware())

    let indexHtml = loadResource("index.html") ?? "<!DOCTYPE html><html><body><h1>CCHistory</h1><p>Web UI not found.</p></body></html>"
    let cssContent = loadResource("styles.css") ?? "/* CSS not found */"
    let jsContent = loadResource("app.js") ?? "// JS not found"

    // API: Get all sessions (fetch fresh data on each request)
    router.get("/api/sessions") { request, _ async throws -> Response in
      let query = request.uri.queryParameters["q"].map { String($0) }?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let projectFilter = request.uri.queryParameters["project"].map { String($0) }?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let sinceParam = request.uri.queryParameters["since"].map { String($0) }
      let untilParam = request.uri.queryParameters["until"].map { String($0) }

      let sinceDate = sinceParam.flatMap { Double($0) }.map { Date(timeIntervalSince1970: $0) }
      let untilDate = untilParam.flatMap { Double($0) }.map { Date(timeIntervalSince1970: $0) }

      let sessions = await MainActor.run {
        let source = query.isEmpty ? SessionCache.shared.getAllSessions() : SessionCache.shared.searchSessions(query)
        return source.filter { session in
          let matchesProject = projectFilter.isEmpty || session.projectPath.localizedCaseInsensitiveContains(projectFilter)
          let afterSince = sinceDate.map { session.timestamp >= $0 } ?? true
          let beforeUntil = untilDate.map { session.timestamp <= $0 } ?? true
          return matchesProject && afterSince && beforeUntil
        }
      }

      var headers = HTTPFields()
      headers[.contentType] = "application/json; charset=utf-8"
      headers[.cacheControl] = "no-store"
      let encoder = JSONEncoder()
      let data = try encoder.encode(sessions)
      return Response(status: .ok, headers: headers, body: .init { writer in
        let buffer = ByteBuffer(data: data)
        try await writer.write(buffer)
        try await writer.finish(nil)
      })
    }

    // API: Get messages for a session
    router.get("/api/sessions/:id/messages") { request, context async throws -> Response in
      let sessionId = context.parameters.get("id") ?? ""

      let messages = await MainActor.run {
        SessionCache.shared.getMessages(id: sessionId)
      }

      var headers = HTTPFields()
      headers[.contentType] = "application/json; charset=utf-8"
      headers[.cacheControl] = "no-store"
      let encoder = JSONEncoder()
      let data = try encoder.encode(messages)
      return Response(status: .ok, headers: headers, body: .init { writer in
        let buffer = ByteBuffer(data: data)
        try await writer.write(buffer)
        try await writer.finish(nil)
      })
    }

    // API: Server-sent events for updates
    router.get("/api/stream") { _, _ async throws -> Response in
      var headers = HTTPFields()
      headers[.contentType] = "text/event-stream"
      headers[.cacheControl] = "no-store"
      headers[.connection] = "keep-alive"

      let clientId = UUID()
      let stream = AsyncStream<ByteBuffer> { [weak self] continuation in
        continuation.yield(ByteBuffer(string: ": connected\n\n"))

        guard let self else { return }
        let client = EventSourceClient(id: clientId, continuation: continuation)
        self.eventSourceClients[clientId] = client
        continuation.onTermination = { [weak self] _ in
          self?.eventSourceClients.removeValue(forKey: clientId)
        }
      }

      let body = ResponseBody(asyncSequence: stream)
      return Response(status: .ok, headers: headers, body: body)
    }

    // API: Health check / server info
    router.get("/api/info") { _, _ in
      return ServerInfo(
        version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
        hostname: Host.current().localizedName ?? "Mac",
        port: currentPort
      )
    }

    // Serve static files - index.html at root
    router.get("/") { _, _ in
      return htmlResponse(indexHtml)
    }

    // Serve CSS files
    router.get("/css/styles.css") { _, _ in
      return cssResponse(cssContent)
    }

    // Serve JS files
    router.get("/js/app.js") { _, _ in
      return jsResponse(jsContent)
    }

    // Create application
    let app = Application(
      responder: router.buildResponder(),
      configuration: .init(
        address: .hostname("0.0.0.0", port: currentPort),
        serverName: "CCHistory"
      ),
      eventLoopGroupProvider: .shared(eventLoopGroup!)
    )

    self.app = app

    // Run server in background task so start() returns immediately
    serverTask = Task {
      do {
        try await app.runService()
        print("[WebServer] Server stopped")
      } catch {
        print("[WebServer] Server error: \(error)")
        DispatchQueue.main.async { [weak self] in
          self?.lastStartError = error
          self?.app = nil
        }
      }
    }

    print("[WebServer] Server started on port \(currentPort)")
  }

  /// Stop the HTTP server
  func stop() async {
    // Cancel server task and clear app reference
    serverTask?.cancel()
    serverTask = nil
    app = nil
    lastStartError = nil

    // Shutdown event loop group - this stops all server activity
    try? await eventLoopGroup?.shutdownGracefully()
    eventLoopGroup = nil

    // Close all SSE clients
    for client in eventSourceClients.values {
      client.close()
    }
    eventSourceClients.removeAll()

    print("[WebServer] Stopped")
  }

  /// Broadcast a session change event to all SSE clients
  func broadcastSessionChange() {
    guard !eventSourceClients.isEmpty else { return }
    let payload = "event: sessions\ndata: updated\n\n"
    let buffer = ByteBuffer(string: payload)
    for client in eventSourceClients.values {
      client.send(buffer)
    }
  }

  // MARK: - Helpers

  private func loadResource(_ name: String) -> String? {
    if let resourcesURL = Bundle.main.resourceURL {
      let resourcePath = resourcesURL.appendingPathComponent(name)
      if let content = try? String(contentsOf: resourcePath, encoding: .utf8) {
        return content
      }
    }

    let execURL = URL(fileURLWithPath: CommandLine.arguments[0])
    let execDir = execURL.deletingLastPathComponent()
    let bundlePath = execDir.appendingPathComponent("CCHistory_CCHistory.bundle").appendingPathComponent(name)
    if let content = try? String(contentsOfFile: bundlePath.path, encoding: .utf8) {
      return content
    }

    return nil
  }

  /// Get the primary local network IP address
  private func getLocalNetworkIP() -> String? {
    var address: String?
    var ifaddr: UnsafeMutablePointer<ifaddrs>?

    guard getifaddrs(&ifaddr) == 0 else { return nil }
    defer { freeifaddrs(ifaddr) }

    var ptr = ifaddr
    while ptr != nil {
      defer { ptr = ptr?.pointee.ifa_next }

      guard let interface = ptr?.pointee else { continue }
      let addrFamily = interface.ifa_addr.pointee.sa_family

      if addrFamily == UInt8(AF_INET) {
        let name = String(cString: interface.ifa_name)
        // Look for en0 (WiFi) or en1 (Ethernet)
        if name == "en0" || name == "en1" {
          var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
          getnameinfo(
            interface.ifa_addr,
            socklen_t(interface.ifa_addr.pointee.sa_len),
            &hostname,
            socklen_t(hostname.count),
            nil,
            socklen_t(0),
            NI_NUMERICHOST
          )
          // Find null terminator
          if let nullIdx = hostname.firstIndex(of: 0) {
            address = String(decoding: hostname[0..<nullIdx].withUnsafeBytes { buffer in
              Data(buffer: buffer.bindMemory(to: UInt8.self))
            }, as: UTF8.self)
          }
        }
      }
    }

    return address
  }
}

final class EventSourceClient {
  let id: UUID
  private let continuation: AsyncStream<ByteBuffer>.Continuation

  init(id: UUID, continuation: AsyncStream<ByteBuffer>.Continuation) {
    self.id = id
    self.continuation = continuation
  }

  func send(_ buffer: ByteBuffer) {
    continuation.yield(buffer)
  }

  func close() {
    continuation.finish()
  }
}

// MARK: - Supporting Types


/// Server information endpoint response
struct ServerInfo: ResponseCodable {
  let version: String
  let hostname: String
  let port: Int
}

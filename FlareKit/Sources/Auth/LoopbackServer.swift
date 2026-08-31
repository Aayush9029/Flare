import Foundation
import Network
import os

/// Single-shot HTTP listener for the OAuth redirect.
///
/// The port is not ours to choose: `app_EMoamEEZ73f0CkXaXp7hrann` registers
/// `http://localhost:1455/auth/callback` as its only redirect URI.
public actor LoopbackServer {
    public struct CallbackTimeout: Error {}
    public struct PortUnavailable: Error {}

    private let port: NWEndpoint.Port
    private var listener: NWListener?

    public init(port: UInt16) {
        self.port = NWEndpoint.Port(rawValue: port)!
    }

    public func awaitCallback(path: String, timeout: Duration = .seconds(300)) async throws -> [String: String] {
        let listener: NWListener
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            parameters.requiredInterfaceType = .loopback
            listener = try NWListener(using: parameters, on: port)
        } catch {
            throw PortUnavailable()
        }
        self.listener = listener

        return try await withThrowingTaskGroup(of: [String: String].self) { group in
            group.addTask {
                try await Self.accept(on: listener, path: path)
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw CallbackTimeout()
            }
            defer { group.cancelAll() }
            let result = try await group.next()!
            listener.cancel()
            return result
        }
    }

    public func stop() {
        listener?.cancel()
        listener = nil
    }

    private static func accept(on listener: NWListener, path: String) async throws -> [String: String] {
        try await withCheckedThrowingContinuation { continuation in
            let resumed = OSAllocatedUnfairLock(initialState: false)
            func finish(_ result: Result<[String: String], Error>) {
                let alreadyResumed = resumed.withLock { done -> Bool in
                    defer { done = true }
                    return done
                }
                guard !alreadyResumed else { return }
                continuation.resume(with: result)
            }

            listener.newConnectionHandler = { connection in
                connection.start(queue: .global(qos: .userInitiated))
                connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { data, _, _, error in
                    if let error {
                        finish(.failure(error))
                        connection.cancel()
                        return
                    }
                    guard let data, let request = String(data: data, encoding: .utf8) else {
                        connection.cancel()
                        return
                    }
                    guard let target = Self.requestTarget(request), target.path == path else {
                        connection.send(content: Self.response(status: "404 Not Found", body: "Not found"), completion: .contentProcessed { _ in
                            connection.cancel()
                        })
                        return
                    }
                    let body = target.query["error"] == nil ? Self.successPage : Self.failurePage(target.query["error"]!)
                    connection.send(content: Self.response(status: "200 OK", body: body), completion: .contentProcessed { _ in
                        connection.cancel()
                        finish(.success(target.query))
                    })
                }
            }
            listener.stateUpdateHandler = { state in
                if case .failed(let error) = state { finish(.failure(error)) }
            }
            listener.start(queue: .global(qos: .userInitiated))
        }
    }

    private static func requestTarget(_ request: String) -> (path: String, query: [String: String])? {
        guard let line = request.split(separator: "\r\n").first else { return nil }
        let fields = line.split(separator: " ")
        guard fields.count >= 2 else { return nil }
        guard let components = URLComponents(string: "http://localhost\(fields[1])") else { return nil }
        let query = Dictionary(
            (components.queryItems ?? []).compactMap { item in item.value.map { (item.name, $0) } },
            uniquingKeysWith: { _, last in last }
        )
        return (components.path, query)
    }

    private static func response(status: String, body: String) -> Data {
        let bytes = Data(body.utf8)
        let header = """
        HTTP/1.1 \(status)\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(bytes.count)\r
        Connection: close\r
        \r

        """
        return Data(header.utf8) + bytes
    }

    private static let successPage = page(
        title: "You're signed in",
        message: "Flare is connected to your ChatGPT account. You can close this tab."
    )

    private static func failurePage(_ error: String) -> String {
        page(title: "Sign-in failed", message: error)
    }

    private static func page(title: String, message: String) -> String {
        """
        <!doctype html><html><head><meta charset="utf-8"><title>\(title)</title></head>
        <body style="margin:0;height:100vh;display:grid;place-items:center;background:#0b0b0f;color:#f5f5f7;
        font:16px/1.5 -apple-system,BlinkMacSystemFont,'SF Pro Text',sans-serif">
        <div style="text-align:center;max-width:32rem;padding:2rem">
        <h1 style="font-size:1.5rem;margin:0 0 .5rem">\(title)</h1>
        <p style="margin:0;opacity:.7">\(message)</p></div></body></html>
        """
    }
}

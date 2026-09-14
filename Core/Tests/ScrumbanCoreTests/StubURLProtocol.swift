import Foundation
import os

final class StubURLProtocol: URLProtocol {
    private static let bodies = OSAllocatedUnfairLock(initialState: [String]())
    private static let requested = OSAllocatedUnfairLock(initialState: [URL]())

    static func reset() {
        bodies.withLock { $0 = [] }
        requested.withLock { $0 = [] }
    }

    static func enqueue(_ body: String) {
        bodies.withLock { $0.append(body) }
    }

    static var requestedURLs: [URL] { requested.withLock { $0 } }

    static var session: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let url = request.url {
            Self.requested.withLock { $0.append(url) }
        }

        let body = Self.bodies.withLock { queue -> String in
            guard let next = queue.first else { return "" }
            if queue.count > 1 { queue.removeFirst() }
            return next
        }

        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

import Foundation

/// URLSession wrapper that yields response body chunks as they arrive (real streaming, not byte-by-byte).
final class StreamingHTTP: NSObject, URLSessionDataDelegate {
    private var continuation: AsyncThrowingStream<Data, Error>.Continuation?
    private var response: HTTPURLResponse?
    private var errorBody = Data()
    private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)

    func stream(_ request: URLRequest) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            self.continuation = continuation
            let task = session.dataTask(with: request)
            continuation.onTermination = { _ in task.cancel() }
            task.resume()
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        self.response = response as? HTTPURLResponse
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if let code = response?.statusCode, code >= 400 { errorBody.append(data) } else { continuation?.yield(data) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let code = response?.statusCode, code >= 400 {
            let body = String(data: errorBody, encoding: .utf8) ?? ""
            continuation?.finish(throwing: SpeechError(message: Self.friendly(code: code, body: body)))
        } else if let error {
            continuation?.finish(throwing: error)
        } else {
            continuation?.finish()
        }
        session.finishTasksAndInvalidate()
    }

    private static func friendly(code: Int, body: String) -> String {
        switch code {
        case 401, 403: return "API key was rejected (\(code)). Check it in Settings."
        case 402: return "Account needs credits (402)."
        case 429: return "Rate limited (429). Try again in a moment."
        default:
            let snippet = body.prefix(160).replacingOccurrences(of: "\n", with: " ")
            return "Voice service error \(code). \(snippet)"
        }
    }
}

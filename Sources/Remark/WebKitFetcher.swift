import Foundation
import WebKit

/// A class responsible for fetching HTML content from web pages using `WKWebView`.
/// This class is `@MainActor` to ensure safe usage of `WKWebView` and other UI elements.
@MainActor
public class WebKitFetcher: HTMLFetching, @unchecked Sendable {
    
    private var webView: WKWebView
    private var navigationDelegate: NavigationDelegate?
    
    /// Initializes a new instance of `WebKitFetcher`.
    public init() {
        self.webView = WKWebView()
    }
    
    /// Fetches HTML content from the specified URL with an optional referer and timeout.
    /// - Parameters:
    ///   - url: The URL to fetch HTML content from.
    ///   - referer: An optional referer URL to include in the request.
    ///   - timeout: The timeout duration in seconds for the operation.
    /// - Returns: The fetched HTML content as a `String`.
    /// - Throws: An error if the fetch operation fails or times out.
    public func fetchHTML(from url: URL, referer: URL? = nil, timeout: TimeInterval = 15) async throws -> String {
        return try await withTimeout(timeout: timeout) { [weak self] in
            guard let self = self else {
                throw TimeoutError()
            }
            return try await self.performFetchHTML(from: url, referer: referer)
        }
    }
    
    /// Performs the actual HTML fetching process.
    /// - Parameters:
    ///   - url: The URL to fetch HTML content from.
    ///   - referer: An optional referer URL to include in the request.
    /// - Returns: The fetched HTML content as a `String`.
    /// - Throws: An error if the fetch operation fails.
    private func performFetchHTML(from url: URL, referer: URL?) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            // Create a URL request
            var request = URLRequest(url: url)
            if let referer = referer {
                request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer")
            }
            
            // Set up the navigation delegate
            let delegate = NavigationDelegate { [weak self] result in
                self?.navigationDelegate = nil // Release the delegate
                switch result {
                case .success:
                    // Execute JavaScript to retrieve the HTML
                    self?.webView.evaluateJavaScript("document.documentElement.outerHTML.toString()") { html, error in
                        if let html = html as? String {
                            continuation.resume(returning: html)
                        } else if let error = error {
                            continuation.resume(throwing: error)
                        }
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            self.navigationDelegate = delegate // Retain the delegate
            self.webView.navigationDelegate = delegate
            self.webView.load(request)
        }
    }
}

/// A helper class that manages `WKWebView` navigation events.
private class NavigationDelegate: NSObject, WKNavigationDelegate {
    private let onComplete: (Result<Void, Error>) -> Void
    
    /// Initializes a new instance of `NavigationDelegate`.
    /// - Parameter onComplete: A closure called when navigation finishes or fails.
    init(onComplete: @escaping (Result<Void, Error>) -> Void) {
        self.onComplete = onComplete
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onComplete(.success(()))
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onComplete(.failure(error))
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        onComplete(.failure(error))
    }
}

/// A utility function to execute an asynchronous operation with a timeout.
/// - Parameters:
///   - timeout: The maximum time to wait for the operation, in seconds.
///   - operation: The asynchronous operation to execute.
/// - Returns: The result of the operation.
/// - Throws: A `TimeoutError` if the operation times out or any error from the operation itself.
func withTimeout<T: Sendable>(timeout: TimeInterval, operation: @Sendable @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // Add the main operation
        group.addTask {
            try await operation()
        }
        
        // Add the timeout task
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            throw TimeoutError() // Throw timeout error
        }
        
        // Wait for the first completed task
        guard let result = try await group.next() else {
            group.cancelAll() // Cancel remaining tasks
            throw TimeoutError() // Throw timeout error
        }
        
        group.cancelAll() // Cancel remaining tasks
        return result
    }
}

/// An error representing a timeout in an asynchronous operation.
struct TimeoutError: Error {
    /// A description of the timeout error.
    var localizedDescription: String {
        "Operation timed out."
    }
}

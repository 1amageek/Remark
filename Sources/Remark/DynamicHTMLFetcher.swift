import WebKit
import Foundation

/// A class that fetches and monitors HTML content from web pages using WebKit.
/// This class supports both single-fetch and streaming modes for dynamic content observation.
@MainActor
class DynamicHTMLFetcher: NSObject, WKNavigationDelegate, HTMLFetching, @unchecked Sendable {
    /// Internal WebView instance used for content fetching
    private var webView: WKWebView?
    
    /// Completion handler for single-fetch operations
    private var completionHandler: ((Result<String, Error>) -> Void)?
    
    /// Current referer URL for the request
    private var currentReferer: URL?
    
    /// Timer for checking content changes
    private var contentCheckTimer: Timer?
    
    /// Previously fetched HTML content
    private var previousHTML: String?
    
    /// Counter for tracking stable content occurrences
    private var stableContentCount = 0
    
    /// Continuation for streaming content updates
    private var contentStreamContinuation: AsyncStream<String>.Continuation?
    
    /// Generates a browser-like User-Agent string based on the current platform
    /// - Returns: A formatted User-Agent string
    private static func generateUserAgent() -> String {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let osVersionFormatted = osVersion.replacingOccurrences(of: "Version ", with: "")
        
#if os(macOS)
        let platform = "Macintosh; Intel Mac OS X \(osVersionFormatted)"
#elseif os(iOS)
        let platform = "iPhone; CPU iPhone OS \(osVersionFormatted.replacingOccurrences(of: ".", with: "_")) like Mac OS X"
#else
        let platform = "Unknown Platform"
#endif
        
        let webView = WKWebView()
        let webKitVersion = webView.configuration.applicationNameForUserAgent ?? "AppleWebKit/537.36"
        
        return "Mozilla/5.0 (\(platform)) \(webKitVersion) (KHTML, like Gecko) Safari/\(webKitVersion.components(separatedBy: "/").last ?? "537.36")"
    }
    
    /// Generates the Accept-Language header based on system preferences
    /// - Returns: A formatted Accept-Language string
    private static func generateAcceptLanguage() -> String {
        let languages = Locale.preferredLanguages
        let languagesWithQuality = languages.enumerated().map { index, language -> String in
            let quality = 1.0 - (Double(index) * 0.1)
            if index == 0 {
                return language
            } else {
                return "\(language);q=\(String(format: "%.1f", quality))"
            }
        }
        return languagesWithQuality.joined(separator: ",")
    }
    
    /// Creates an async stream of HTML content that monitors changes until content stabilizes.
    /// - Parameters:
    ///   - url: The URL to fetch content from.
    ///   - referer: Optional referer URL for the request.
    ///   - checkInterval: Time interval between content checks in seconds.
    ///   - requiredStableCount: Number of consecutive identical content checks required to consider content stable.
    ///   - timeout: Maximum time to wait for content stabilization in seconds.
    /// - Returns: An AsyncStream of HTML content strings.
    func contentCheckStream(
        from url: URL,
        referer: URL? = nil,
        checkInterval: TimeInterval = 0.4,
        requiredStableCount: Int = 3,
        timeout: TimeInterval = 30
    ) -> AsyncStream<String> {
        return AsyncStream { continuation in
            self.contentStreamContinuation = continuation
            var localPreviousHTML: String?
            var localStableCount = 0
            
            Task { @MainActor in
                self.currentReferer = referer
                self.setupWebView()
                
                var request = URLRequest(url: url)
                let userAgent = Self.generateUserAgent()
                request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
                
                if let referer = referer {
                    request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer")
                }
                
                request.setValue(Self.generateAcceptLanguage(), forHTTPHeaderField: "Accept-Language")
                request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
                request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
                
                webView?.customUserAgent = userAgent
                webView?.load(request)
                
                // Periodically check HTML content using a timer.
                contentCheckTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
                    Task { @MainActor in
                        guard let webView = self?.webView else { return }
                        
                        do {
                            let currentHTML = try await webView.evaluateJavaScript("document.documentElement.outerHTML") as? String
                            if let html = currentHTML {
                                continuation.yield(html)
                                
                                if html == localPreviousHTML {
                                    localStableCount += 1
                                    if localStableCount >= requiredStableCount {
                                        self?.contentCheckTimer?.invalidate()
                                        continuation.finish()
                                    }
                                } else {
                                    localStableCount = 0
                                    localPreviousHTML = html
                                }
                            }
                        } catch {
                            continuation.finish()
                        }
                    }
                }
                
                // Finish the stream after the timeout.
                DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
                    self?.contentCheckTimer?.invalidate()
                    continuation.finish()
                }
            }
        }
    }
    
    /// Fetches HTML content from a URL and waits for content to stabilize.
    /// - Parameters:
    ///   - url: The URL to fetch content from.
    ///   - referer: Optional referer URL for the request.
    ///   - timeout: Maximum time to wait for content stabilization in seconds.
    /// - Returns: The stabilized HTML content.
    /// - Throws: An error if the fetch fails or times out.
    func fetchHTML(from url: URL, referer: URL? = nil, timeout: TimeInterval = 30) async throws -> String {
        self.currentReferer = referer
        
        return try await withCheckedThrowingContinuation { continuation in
            setupWebView()
            
            // Wrap the completion handler to ensure it is called only once.
            completionHandler = { [weak self] result in
                continuation.resume(with: result)
                self?.completionHandler = nil
            }
            
            var request = URLRequest(url: url)
            let userAgent = Self.generateUserAgent()
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            
            if let referer = referer {
                request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer")
            }
            
            request.setValue(Self.generateAcceptLanguage(), forHTTPHeaderField: "Accept-Language")
            request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
            request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
            
            webView?.customUserAgent = userAgent
            webView?.load(request)
            
            // Handle timeout logic.
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.contentCheckTimer?.invalidate()
                
                // Ensure the completion handler is called if it hasn't already been called.
                if let html = strongSelf.previousHTML, let handler = strongSelf.completionHandler {
                    handler(.success(html))
                } else if let handler = strongSelf.completionHandler {
                    handler(.failure(ValidationError("Timeout waiting for stable content")))
                }
            }
        }
    }
    
    /// Sets up the WebKit configuration and creates the WebView.
    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        configuration.applicationNameForUserAgent = Self.generateUserAgent()
        
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences
        
#if os(macOS)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        
        webView = WKWebView(frame: window.contentView!.bounds, configuration: configuration)
        window.contentView?.addSubview(webView!)
#else
        webView = WKWebView(frame: .zero, configuration: configuration)
#endif
        
        webView?.navigationDelegate = self
    }
    
    // MARK: - WKNavigationDelegate Methods
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Start periodic checks every 2 seconds when the page finishes loading.
        contentCheckTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkContentStability(webView)
            }
        }
    }
    
    /// Checks if the content has stabilized.
    /// - Parameter webView: The WebView instance to check.
    private func checkContentStability(_ webView: WKWebView) {
        webView.evaluateJavaScript("document.documentElement.outerHTML") { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.contentCheckTimer?.invalidate()
                // Ensure the completion handler is called if an error occurs.
                if let handler = self.completionHandler {
                    handler(.failure(error))
                    self.completionHandler = nil
                }
                return
            }
            
            guard let currentHTML = result as? String else {
                self.contentCheckTimer?.invalidate()
                if let handler = self.completionHandler {
                    handler(.failure(ValidationError("Could not extract HTML content")))
                    self.completionHandler = nil
                }
                return
            }
            
            if currentHTML == self.previousHTML {
                self.stableContentCount += 1
                if self.stableContentCount >= 3 {
                    self.contentCheckTimer?.invalidate()
                    if let handler = self.completionHandler {
                        handler(.success(currentHTML))
                        self.completionHandler = nil
                    }
                }
            } else {
                self.stableContentCount = 0
                self.previousHTML = currentHTML
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        contentCheckTimer?.invalidate()
        if let handler = completionHandler {
            handler(.failure(error))
            completionHandler = nil
        }
    }
    
    private func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        var request = navigationAction.request
        
        request.setValue(Self.generateUserAgent(), forHTTPHeaderField: "User-Agent")
        request.setValue(Self.generateAcceptLanguage(), forHTTPHeaderField: "Accept-Language")
        
        if let referer = currentReferer {
            request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer")
        }
        
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        contentCheckTimer?.invalidate()
        if let handler = completionHandler {
            handler(.failure(error))
            completionHandler = nil
        }
    }
    
    deinit {
        // Finish the stream mode properly when the object is deallocated.
        contentStreamContinuation?.finish()
        
        // Invalidate the timer if still active.
        DispatchQueue.main.sync {
            contentCheckTimer?.invalidate()
        }
    }
}

/// Error type for validation failures
struct ValidationError: Error {
    /// Error message describing the validation failure
    let message: String
    
    /// Creates a new validation error.
    /// - Parameter message: Description of the error.
    init(_ message: String) {
        self.message = message
    }
}

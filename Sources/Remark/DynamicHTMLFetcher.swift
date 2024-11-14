import WebKit
import Foundation

/// A class that fetches and monitors HTML content from web pages using WebKit.
/// This class provides both one-time fetching and continuous monitoring capabilities.
@MainActor
public class DynamicHTMLFetcher: NSObject, WKNavigationDelegate, @unchecked Sendable {
    private var webView: WKWebView?
    private var completionHandler: ((Result<String, Error>) -> Void)?
    private var currentReferer: URL?
    private var contentCheckTimer: Timer?
    private var previousHTML: String?
    private var stableContentCount = 0
    private var contentStreamContinuation: AsyncStream<String>.Continuation?
    
    /// Generates a browser-like User-Agent string based on the current platform and system information.
    /// - Returns: A string containing the User-Agent header value.
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
    
    /// Generates the Accept-Language header value based on system language preferences.
    /// - Returns: A string containing the Accept-Language header value.
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
    
    /// Fetches HTML content from a specified URL with optional referrer and timeout settings.
    /// - Parameters:
    ///   - url: The URL to fetch HTML content from
    ///   - referer: Optional referrer URL to include in the request headers
    ///   - timeout: Maximum time to wait for stable content in seconds (default: 30)
    /// - Returns: A string containing the HTML content
    /// - Throws: An error if the fetch operation fails or times out
    public func fetchHTML(from url: URL, referer: URL? = nil, timeout: TimeInterval = 30) async throws -> String {
        self.currentReferer = referer
        
        return try await withCheckedThrowingContinuation { continuation in
            setupWebView()
            completionHandler = { result in
                continuation.resume(with: result)
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
            
            let preferences = WKWebpagePreferences()
            preferences.allowsContentJavaScript = true
            webView?.configuration.defaultWebpagePreferences = preferences
            
            webView?.load(request)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
                self?.contentCheckTimer?.invalidate()
                if let html = self?.previousHTML {
                    self?.completionHandler?(.success(html))
                } else {
                    self?.completionHandler?(.failure(ValidationError("Timeout waiting for stable content")))
                }
            }
        }
    }
    
    /// Creates an async stream that emits HTML content whenever the page content changes.
    /// - Parameters:
    ///   - url: The URL to monitor for HTML content changes
    ///   - referer: Optional referrer URL to include in the request headers
    ///   - checkInterval: The interval in seconds between content checks (default: 0.35)
    /// - Returns: An AsyncStream that emits String values containing HTML content
    public func contentCheckStream(from url: URL, referer: URL? = nil, checkInterval: TimeInterval = 0.35) -> AsyncStream<String> {
        return AsyncStream { continuation in
            self.contentStreamContinuation = continuation
            
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
                
                contentCheckTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
                    Task { @MainActor in
                        await self?.checkContentForStream()
                    }
                }
            }
        }
    }
    
    /// Sets up the WKWebView instance with appropriate configuration.
    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        configuration.applicationNameForUserAgent = Self.generateUserAgent()
        
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences
        configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView?.navigationDelegate = self
    }
    
    /// Performs content check for the stream and emits new HTML content.
    private func checkContentForStream() async {
        guard let webView = webView else { return }
        
        do {
            let currentHTML = try await webView.evaluateJavaScript("document.documentElement.outerHTML") as? String
            if let html = currentHTML {
                contentStreamContinuation?.yield(html)
            }
        } catch {
            contentStreamContinuation?.finish()
        }
    }
    
    /// Handles the completion of web page loading.
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        contentCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkContentStability(webView)
            }
        }
    }
    
    /// Checks if the content has stabilized by comparing consecutive HTML snapshots.
    private func checkContentStability(_ webView: WKWebView) {
        webView.evaluateJavaScript("document.documentElement.outerHTML") { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.contentCheckTimer?.invalidate()
                self.completionHandler?(.failure(error))
                return
            }
            
            guard let currentHTML = result as? String else {
                self.contentCheckTimer?.invalidate()
                self.completionHandler?(.failure(ValidationError("Could not extract HTML content")))
                return
            }
            
            if currentHTML == self.previousHTML {
                self.stableContentCount += 1
                if self.stableContentCount >= 3 {
                    self.contentCheckTimer?.invalidate()
                    self.completionHandler?(.success(currentHTML))
                }
            } else {
                self.stableContentCount = 0
                self.previousHTML = currentHTML
            }
        }
    }
    
    /// Handles navigation failures.
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        contentCheckTimer?.invalidate()
        completionHandler?(.failure(error))
    }
    
    /// Handles navigation policy decisions.
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
    
    /// Handles provisional navigation failures.
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        contentCheckTimer?.invalidate()
        completionHandler?(.failure(error))
    }
    
    deinit {
        contentStreamContinuation?.finish()
        DispatchQueue.main.sync {
            contentCheckTimer?.invalidate()
        }
    }
}

/// Represents validation errors that can occur during HTML fetching.
public struct ValidationError: Error {
    /// The error message describing the validation failure.
    public let message: String
    
    /// Creates a new validation error with the specified message.
    /// - Parameter message: A description of the validation error
    public init(_ message: String) {
        self.message = message
    }
}

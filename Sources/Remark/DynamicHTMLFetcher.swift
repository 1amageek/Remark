import WebKit
import Foundation

@MainActor
class DynamicHTMLFetcher: NSObject, WKNavigationDelegate, @unchecked Sendable {
    private var webView: WKWebView?
    private var completionHandler: ((Result<String, Error>) -> Void)?
    private var currentReferer: URL?
    private var contentCheckTimer: Timer?
    private var previousHTML: String?
    private var stableContentCount = 0
    
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
    
    func fetchHTML(from url: URL, referer: URL? = nil, timeout: TimeInterval = 30) async throws -> String {
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
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        contentCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkContentStability(webView)
            }
        }
    }
    
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
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        contentCheckTimer?.invalidate()
        completionHandler?(.failure(error))
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
        completionHandler?(.failure(error))
    }
    
    deinit {
        DispatchQueue.main.sync {
            contentCheckTimer?.invalidate()
        }
    }
}

struct ValidationError: Error {
    let message: String
    
    init(_ message: String) {
        self.message = message
    }
}


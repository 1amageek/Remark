import WebKit
import Foundation
import os.log

@MainActor
class DynamicHTMLFetcher: NSObject, WKNavigationDelegate, HTMLFetching, @unchecked Sendable {
    private var webView: WKWebView?
    private var completionHandler: ((Result<String, Error>) -> Void)?
    private var currentReferer: URL?
    private var contentCheckTimer: Timer?
    private var previousHTML: String?
    private var stableContentCount = 0
    private var contentStreamContinuation: AsyncStream<String>.Continuation?
    
    private static func generateUserAgent() -> String {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let osVersionFormatted = osVersion.replacingOccurrences(of: "Version ", with: "")
        let platform = "Macintosh; Intel Mac OS X \(osVersionFormatted)"
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
    
    func contentCheckStream(
        from url: URL,
        referer: URL? = nil,
        checkInterval: TimeInterval = 0.2,
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
                
                DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
                    self?.contentCheckTimer?.invalidate()
                    continuation.finish()
                }
            }
        }
    }
    
    func fetchHTML(from url: URL, referer: URL? = nil, timeout: TimeInterval = 30) async throws -> String {
        self.currentReferer = referer
        
        return try await withCheckedThrowingContinuation { continuation in
            setupWebView()
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
            
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.contentCheckTimer?.invalidate()
                
                if let html = strongSelf.previousHTML, let handler = strongSelf.completionHandler {
                    handler(.success(html))
                } else if let handler = strongSelf.completionHandler {
                    handler(.failure(ValidationError("Timeout waiting for stable content")))
                }
            }
        }
    }
    
    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        configuration.applicationNameForUserAgent = Self.generateUserAgent()
        configuration.defaultWebpagePreferences = WKWebpagePreferences()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.websiteDataStore = .nonPersistent()
        configuration.suppressesIncrementalRendering = true
        
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView?.navigationDelegate = self
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        contentCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkContentStability(webView)
            }
        }
    }
    
    private func checkContentStability(_ webView: WKWebView) {
        webView.evaluateJavaScript("document.documentElement.outerHTML") { [weak self] result, error in
            guard let self = self else { return }
            if let error = error {
                self.handleError(error)
                return
            }
            
            guard let currentHTML = result as? String else {
                self.handleError(ValidationError("Could not extract HTML content"))
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
    
    private func handleError(_ error: Error) {
        contentCheckTimer?.invalidate()
        if let handler = completionHandler {
            handler(.failure(error))
            completionHandler = nil
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
        contentStreamContinuation?.finish()
        
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

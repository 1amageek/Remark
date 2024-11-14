import WebKit
import Foundation

@MainActor
class DynamicHTMLFetcher: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var completionHandler: ((Result<String, Error>) -> Void)?
    private var currentReferer: URL?
    
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
        // システムの優先言語リストを取得
        let languages = Locale.preferredLanguages
        
        // 言語コードとquality値のペアを作成
        let languagesWithQuality = languages.enumerated().map { index, language -> String in
            // 最初の言語は最高優先度（q=1.0）、以降は徐々に下げていく
            let quality = 1.0 - (Double(index) * 0.1)
            if index == 0 {
                return language
            } else {
                return "\(language);q=\(String(format: "%.1f", quality))"
            }
        }
        
        // カンマ区切りの文字列に結合
        return languagesWithQuality.joined(separator: ",")
    }
    
    func fetchHTML(from url: URL, referer: URL? = nil) async throws -> String {
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
            webView?.load(request)
        }
    }
    
    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        configuration.applicationNameForUserAgent = Self.generateUserAgent()
        
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView?.navigationDelegate = self
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("document.documentElement.outerHTML") { [weak self] result, error in
            if let error = error {
                self?.completionHandler?(.failure(error))
                return
            }
            
            if let html = result as? String {
                self?.completionHandler?(.success(html))
            } else {
                self?.completionHandler?(.failure(ValidationError("Could not extract HTML content")))
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
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
}

struct ValidationError: Error {
    let message: String
    
    init(_ message: String) {
        self.message = message
    }
}

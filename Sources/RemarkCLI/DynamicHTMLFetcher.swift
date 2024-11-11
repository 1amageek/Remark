//
//  DynamicHTMLFetcher.swift
//  Remark
//
//  Created by Norikazu Muramoto on 2024/11/11.
//

import Foundation
import WebKit

@MainActor
class DynamicHTMLFetcher: NSObject, WKNavigationDelegate, @unchecked Sendable {
    private var webView: WKWebView?
    private var completionHandler: ((Result<String, Error>) -> Void)?
    
    func fetchHTML(from url: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async { [weak self] in
                self?.setupWebView()
                self?.completionHandler = { result in
                    continuation.resume(with: result)
                }
                self?.webView?.load(URLRequest(url: url))
            }
        }
    }
    
    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView?.navigationDelegate = self
    }
    
    // WKNavigationDelegate methods
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
}


struct ValidationError: Error {
    let message: String
    
    init(_ message: String) {
        self.message = message
    }
}

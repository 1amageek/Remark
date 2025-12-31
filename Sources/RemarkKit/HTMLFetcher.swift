//
//  URLSessionHTMLFetcher.swift
//  Remark
//
//  Created by Norikazu Muramoto on 2025/01/23.
//

import Foundation

class HTMLFetcher: HTMLFetching {
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func fetchHTML(from url: URL, referer: URL? = nil, timeout: TimeInterval = 30) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue(Self.generateUserAgent(), forHTTPHeaderField: "User-Agent")
        request.setValue(Self.generateAcceptLanguage(), forHTTPHeaderField: "Accept-Language")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        
        if let referer {
            request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        
        return html
    }
    
    private static func generateUserAgent() -> String {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
            .replacingOccurrences(of: "Version ", with: "")
        
#if os(macOS)
        let platform = "Macintosh; Intel Mac OS X \(osVersion)"
#elseif os(iOS)
        let platform = "iPhone; CPU iPhone OS \(osVersion.replacingOccurrences(of: ".", with: "_")) like Mac OS X"
#else
        let platform = "Unknown Platform"
#endif
        
        return "Mozilla/5.0 (\(platform)) AppleWebKit/605.1.15 (KHTML, like Gecko) Safari/605.1.15"
    }
    
    private static func generateAcceptLanguage() -> String {
        Locale.preferredLanguages
            .enumerated()
            .map { index, language in
                if index == 0 { return language }
                let quality = 1.0 - (Double(index) * 0.1)
                return "\(language);q=\(String(format: "%.1f", quality))"
            }
            .joined(separator: ",")
    }
}

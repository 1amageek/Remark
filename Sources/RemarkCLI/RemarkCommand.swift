import Foundation
import ArgumentParser
import Remark

@main
struct RemarkCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remark",
        abstract: "Convert HTML content from URLs to Markdown format",
        version: "1.0.0"
    )
    
    @Argument(help: "The URL to fetch and convert to Markdown")
    var url: String
    
    @Flag(name: .shortAndLong, help: "Include front matter in the output")
    var includeFrontMatter: Bool = false
    
    @Flag(name: .shortAndLong, help: "Show only the plain text content")
    var plainText: Bool = false
    
    // HTMLを非同期で取得する関数
    private func fetchHTML(from url: URL) async throws -> String {
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ValidationError("Invalid HTTP response")
        }
        
        // Get encoding from Content-Type header
        let encoding = detectEncoding(from: httpResponse, data: data)                
        guard let html = String(data: data, encoding: encoding) else {
            throw ValidationError("Could not decode HTML content")
        }
        
        return html
    }
    
    // Detect encoding from Content-Type header and meta tags
    private func detectEncoding(from response: HTTPURLResponse, data: Data) -> String.Encoding {
        // First, try to get encoding from Content-Type header
        if let contentType = response.value(forHTTPHeaderField: "Content-Type"),
           let charset = contentType.components(separatedBy: "charset=").last?.trimmingCharacters(in: .whitespaces) {
            switch charset.lowercased() {
            case "shift_jis", "shift-jis", "shiftjis":
                return .shiftJIS
            case "euc-jp":
                return .japaneseEUC
            case "iso-2022-jp":
                return .iso2022JP
            case "utf-8":
                return .utf8
            default:
                break
            }
        }
        
        // If Content-Type header doesn't specify encoding, try to detect from meta tags
        if let content = String(data: data, encoding: .ascii),
           let metaCharset = content.range(of: "charset=", options: [.caseInsensitive]) {
            let startIndex = metaCharset.upperBound
            let endIndex = content[startIndex...].firstIndex(where: { !$0.isLetter && !$0.isNumber && $0 != "-" && $0 != "_" }) ?? content.endIndex
            let charset = content[startIndex..<endIndex].lowercased()
            
            switch charset {
            case "shift_jis", "shift-jis", "shiftjis":
                return .shiftJIS
            case "euc-jp":
                return .japaneseEUC
            case "iso-2022-jp":
                return .iso2022JP
            case "utf-8":
                return .utf8
            default:
                break
            }
        }
        
        // Default to UTF-8 if no encoding is specified
        return .utf8
    }
    
    mutating func run() async throws {
        // URLの検証
        guard let inputURL = URL(string: url) else {
            throw ValidationError("Invalid URL provided")
        }
        
        // HTMLの取得
        let html = try await fetchHTML(from: inputURL)
        
        // HTMLのパースとMarkdownへの変換
        let remark = try Remark(html, url: inputURL)
        
        // 出力の生成
        if plainText {
            print(remark.body)
        } else {
            if includeFrontMatter {
                print(remark.page)
            } else {
                print(remark.markdown)
            }
        }
    }
}

// エラーハンドリングの拡張
extension RemarkCommand {
    struct ValidationError: Error, LocalizedError {
        let message: String
        
        init(_ message: String) {
            self.message = message
        }
        
        var errorDescription: String? {
            return message
        }
    }
}

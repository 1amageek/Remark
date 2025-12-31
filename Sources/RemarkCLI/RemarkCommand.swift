import Foundation
import ArgumentParser
import RemarkKit


@main
struct RemarkCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remark",
        abstract: "Convert HTML content from URLs to Markdown format",
        version: "1.1.0"
    )

    @Argument(help: "The URL to fetch and convert to Markdown")
    var url: String
    
    @Flag(name: .shortAndLong, help: "Include front matter in the output")
    var includeFrontMatter: Bool = false
    
    @Flag(name: .shortAndLong, help: "Show only the plain text content")
    var plainText: Bool = false
    
    mutating func run() async throws {
        // URLの検証
        guard let inputURL = URL(string: url) else {
            throw ValidationError("Invalid URL provided")
        }
        
        let remark = try await Remark.fetch(from: inputURL)
        print(remark.markdown)
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

import Foundation
import ArgumentParser
import RemarkKit


@main
struct RemarkCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remark",
        abstract: "Convert HTML content from URLs to Markdown format",
        version: "1.4.1"
    )

    @Argument(help: "The URL to fetch and convert to Markdown")
    var url: String
    
    @Flag(name: .shortAndLong, help: "Include front matter in the output")
    var includeFrontMatter: Bool = false
    
    @Flag(name: .shortAndLong, help: "Show only the plain text content")
    var plainText: Bool = false

    @Option(name: .shortAndLong, help: "Timeout in seconds for fetching content (default: 15)")
    var timeout: Int = 15

    @Option(name: .long, parsing: .upToNextOption, help: "Resource types to block during fetch. Values: image, media, font, stylesheet, script, raw, svg, popup, ping, websocket, visual, style, active, network, nonessential, all, none. Default: nonessential")
    var block: [String] = []

    mutating func run() async throws {
        // URLの検証
        guard let inputURL = URL(string: url) else {
            throw ValidationError("Invalid URL provided")
        }

        guard timeout > 0 else {
            throw ValidationError("Timeout must be a positive number")
        }

        let blockedTypes = try parseBlockedResourceTypes()
        let remark = try await Remark.fetch(from: inputURL, blockedResourceTypes: blockedTypes, timeout: TimeInterval(timeout))
        print(remark.markdown)
    }

    private func parseBlockedResourceTypes() throws -> BlockedResourceType {
        if block.isEmpty {
            return .nonessential
        }

        if block.count == 1 && block[0].lowercased() == "none" {
            return []
        }

        var result: BlockedResourceType = []
        for name in block {
            guard let type = BlockedResourceType.fromName(name) else {
                let validNames = BlockedResourceType.namedValues.map(\.name).joined(separator: ", ")
                throw ValidationError("Unknown block type '\(name)'. Valid values: \(validNames), none")
            }
            result.insert(type)
        }
        return result
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

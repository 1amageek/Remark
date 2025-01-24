

import Foundation
import WebKit
import SwiftSoup

/// A struct for parsing HTML content and extracting data into Markdown, with support for front matter metadata such as title, description, and Open Graph (OG) data.
public struct Remark: Sendable {
    /// The base URL of the page being processed
    public let url: URL?
    
    /// The page title extracted from the HTML.
    public let title: String
    
    /// The meta description extracted from the HTML.
    public let description: String
    
    /// The Open Graph (OG) data extracted from the HTML.
    public let ogData: [String: String]
    
    /// The plain text content of the main body extracted from the HTML.
    public let body: String
    
    /// The Markdown representation of the main content of the HTML.
    public let markdown: String
    
    /// The raw HTML
    public let html: String
    
    /// Initializes a `Remark` instance by parsing the provided HTML.
    /// - Parameters:
    ///   - html: The HTML string to be parsed.
    ///   - baseURL: The base URL of the page being processed (optional).
    /// - Throws: An error if the HTML cannot be parsed.
    public init(_ html: String, url: URL? = nil) throws {
        self.url = url
        self.html = html
        let doc = try SwiftSoup.parse(html)
        
        // Extract title, description, and Open Graph data
        self.title = try Remark.extractTitle(from: doc)
        self.description = try Remark.extractDescription(from: doc)
        self.ogData = try Remark.extractOGPData(from: doc)
        
        // Extract main content and convert to Markdown
        let mainContent = try Remark.extractMainContent(from: doc)
        self.markdown = try mainContent.array().map { try Remark.convertNodeToMarkdown($0, pageURL: url) }.joined()
        
        // Extract plain text body
        self.body = try mainContent.text()
    }
}

extension Remark {
    
    public enum FetchMethod: CaseIterable {
        case `default`   // Basic HTTP fetch
        case interactive // Fetches with JavaScript execution
    }
    
    /// Fetches and parses HTML content from a given URL.
    /// - Parameter url: The URL to fetch the HTML content from.
    /// - Returns: A `Remark` instance containing the parsed HTML content with metadata and Markdown conversion.
    /// - Throws: An error if the HTML content cannot be fetched or parsed.
    ///
    /// This method creates a dynamic HTML fetcher on the main actor, fetches the HTML content,
    /// and initializes a new `Remark` instance with the fetched content.
    public static func fetch(from url: URL, method: FetchMethod = .default) async throws -> Remark {
        let html = try await {
            switch method {
            case .interactive:
                let fetcher = await MainActor.run { DynamicHTMLFetcher() }
                return try await fetcher.fetchHTML(from: url)
            case .default:
                let fetcher = HTMLFetcher()
                return try await fetcher.fetchHTML(from: url)
            }
        }()
        return try Remark(html, url: url)
    }
}

extension Remark {
    /// Creates an async stream that emits `Remark` instances whenever the page content changes.
    /// - Parameters:
    ///   - url: The URL to monitor for HTML content changes.
    ///   - checkInterval: The interval in seconds between content checks (default: 0.35).
    /// - Returns: An AsyncStream that emits `Remark` instances containing the parsed HTML content with metadata and Markdown conversion.
    ///
    /// This method creates a dynamic HTML fetcher on the main actor and monitors the HTML content for changes.
    /// Each time the content changes, it creates a new `Remark` instance with the updated content.
    ///
    /// Example usage:
    /// ```swift
    /// for await remark in await Remark.stream(from: url) {
    ///     print("Title: \(remark.title)")
    ///     print("Content: \(remark.markdown)")
    /// }
    /// ```
    public static func stream(
        from url: URL,
        checkInterval: TimeInterval = 0.35
    ) -> AsyncStream<Result<Remark, Error>> {
        AsyncStream { continuation in
            Task {
                let fetcher = await MainActor.run { DynamicHTMLFetcher() }
                let htmlStream = await fetcher.contentCheckStream(
                    from: url,
                    checkInterval: checkInterval
                )                
                for await html in htmlStream {
                    do {
                        let remark = try Remark(html, url: url)
                        continuation.yield(.success(remark))
                    } catch {
                        continuation.yield(.failure(error))
                    }
                }
                
                continuation.finish()
            }
        }
    }
    
    /// Creates an async stream that emits `Remark` instances whenever the page content changes,
    /// throwing an error if parsing fails.
    /// - Parameters:
    ///   - url: The URL to monitor for HTML content changes.
    ///   - checkInterval: The interval in seconds between content checks (default: 0.35).
    /// - Returns: An AsyncStream that emits `Remark` instances.
    /// - Throws: An error if HTML parsing fails.
    ///
    /// This method is similar to `stream(from:checkInterval:)` but throws errors instead of wrapping
    /// results in a Result type.
    ///
    /// Example usage:
    /// ```swift
    /// do {
    ///     for try await remark in await Remark.throwingStream(from: url) {
    ///         print("Title: \(remark.title)")
    ///         print("Content: \(remark.markdown)")
    ///     }
    /// } catch {
    ///     print("Error: \(error)")
    /// }
    /// ```
    public static func throwingStream(
        from url: URL,
        checkInterval: TimeInterval = 0.35
    ) -> AsyncThrowingStream<Remark, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let fetcher = await MainActor.run { DynamicHTMLFetcher() }
                let htmlStream = await fetcher.contentCheckStream(
                    from: url,
                    checkInterval: checkInterval
                )
                do {
                    for await html in htmlStream {
                        let remark = try Remark(html, url: url)
                        continuation.yield(remark)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

extension Remark {
    
    /// Extracts the title from the HTML document.
    /// - Parameter doc: The HTML document.
    /// - Returns: The title as a string.
    /// - Throws: An error if the title cannot be extracted.
    static func extractTitle(from doc: Document) throws -> String {
        return try doc.title()
    }
    
    /// Extracts the description from the HTML document.
    /// - Parameter doc: The HTML document.
    /// - Returns: The description as a string if it exists, or an empty string if not.
    static func extractDescription(from doc: Document) throws -> String {
        if let description = try doc.select("meta[name=description]").first() {
            return try description.attr("content")
        }
        return ""
    }
    
    /// Extracts Open Graph (OG) data from the HTML document.
    /// - Parameter doc: The HTML document.
    /// - Returns: A dictionary containing the OG data where the keys are OG properties.
    /// - Throws: An error if OG data extraction fails.
    static func extractOGPData(from doc: Document) throws -> [String: String] {
        var ogData: [String: String] = [:]
        let ogProperties = try doc.select("meta[property^=og:]")
        
        for element in ogProperties {
            let property = try element.attr("property")
            let content = try element.attr("content")
            let key = property.replacingOccurrences(of: "og:", with: "og_")
            ogData[key] = content
        }
        return ogData
    }
}

extension Remark {
    
    /// Extracts the main content section from the HTML document.
    /// - Parameter doc: The HTML document.
    /// - Returns: The main content as an `Elements` collection.
    /// - Throws: An error if extraction fails.
    private static func extractMainContent(from doc: Document) throws -> Elements {
        var mainContent = try doc.select("main, article, section")
        
        if mainContent.isEmpty() {
            mainContent = try fallbackMainContent(from: doc)
        }
        
        try removeUnwantedElements(from: mainContent)
        return mainContent
    }
    
    /// Fallback function to select content based on text length or div element if main content is not found.
    /// - Parameter doc: The HTML document.
    /// - Returns: The fallback content as `Elements`.
    private static func fallbackMainContent(from doc: Document) throws -> Elements {
        let divs = try doc.select("div").filter { element in
            let textLength = try element.text().count
            return textLength > 500
        }
        if !divs.isEmpty {
            return Elements(divs)
        }
        return Elements([doc.body()!])
    }
    
    /// Removes unwanted elements like `nav`, `header`, `footer`, and `aside` from the main content.
    /// - Parameter elements: The main content elements.
    /// - Throws: An error if removal fails.
    private static func removeUnwantedElements(from elements: Elements) throws {
        let removableElements = try elements.select("nav, header, footer, aside")
        let mainTextLength = try elements.text().count
        if mainTextLength < 500 {
            return
        }
        try removableElements.remove()
    }
}

extension Remark {
    /// Extracts the text content from a link element according to priority order.
    ///
    /// This method follows the priority order below:
    /// 1. aria-label attribute
    /// 2. alt text of the first image inside the link
    /// 3. title attribute
    /// 4. text content
    /// 5. URL itself (as fallback)
    ///
    /// - Parameter element: The element to extract text from
    /// - Returns: The extracted text content according to priority
    /// - Throws: SwiftSoup errors if HTML parsing fails
    private static func extractLinkText(from element: Element, pageURL: URL?) throws -> String {
        // 1. Check aria-label
        let ariaLabel = try element.attr("aria-label").trimmingCharacters(in: .whitespacesAndNewlines)
        if !ariaLabel.isEmpty {
            return ariaLabel
        }
        
        // 2. Check for non-empty alt text in images
        if let firstValidAlt = try element.select("img")
            .array()
            .lazy
            .compactMap({ img -> String? in
                let alt = try img.attr("alt").trimmingCharacters(in: .whitespacesAndNewlines)
                return alt.isEmpty ? nil : alt
            })
                .first {
            return firstValidAlt
        }
        
        // 3. Check title
        let title = try element.attr("title").trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            return title
        }
        
        // 4. Check text content
        let text = try element.text().trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            return text
        }
        
        // 5. Use URL as fallback
        let href = try element.attr("href")
        return resolveURL(href, pageURL: pageURL)
    }
    
    /// Resolves a URL against a base URL.
    ///
    /// This method handles various types of URLs:
    /// - Absolute URLs (starting with http:// or https://)
    /// - Protocol-relative URLs (starting with //)
    /// - Root-relative URLs (starting with /)
    /// - Relative URLs
    ///
    /// - Parameters:
    ///   - href: The URL string to resolve
    ///   - baseURL: The base URL to resolve against
    /// - Returns: The resolved absolute URL string
    private static func resolveURL(_ href: String, pageURL: URL?) -> String {
        guard let pageURL = pageURL else { return href }
        
        // Return if already absolute
        if let _ = URL(string: href), href.hasPrefix("http://") || href.hasPrefix("https://") {
            return href
        }
        
        // Handle protocol-relative URLs
        if href.hasPrefix("//") {
            return pageURL.scheme! + ":" + href
        }
        
        // Handle root-relative URLs
        if href.hasPrefix("/") {
            var components = URLComponents(url: pageURL, resolvingAgainstBaseURL: true)!
            components.path = href
            components.query = nil
            components.fragment = nil
            return components.url?.absoluteString ?? href
        }
        
        // Handle relative URLs
        if let resolvedURL = URL(string: href, relativeTo: pageURL)?.absoluteURL {
            var components = URLComponents(url: resolvedURL, resolvingAgainstBaseURL: true)!
            components.query = nil
            components.fragment = nil
            return components.url?.absoluteString ?? href
        }
        
        return href
    }
    
    /// Recursively converts a `Node` to Markdown.
    /// - Parameters:
    ///   - node: The HTML node to convert.
    ///   - quoteLevel: The quote level, used for nested blockquotes.
    ///   - pageURL: The URL of the page being processed.
    /// - Returns: The converted Markdown as a string.
    /// - Throws: An error if conversion fails.
    static func convertNodeToMarkdown(_ node: Node, quoteLevel: Int = 0, pageURL: URL? = nil) throws -> String {
        var markdown = ""
        
        if let textNode = node as? TextNode {
            let text = textNode.text().trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                markdown += text
            }
        } else if let element = node as? Element {
            let tagName = element.tagName()
            
            switch tagName {
            case "a":
                let href = try element.attr("href")
                let resolvedHref = resolveURL(href, pageURL: pageURL)
                let text = try extractLinkText(from: element, pageURL: pageURL)
                markdown += "[\(text)](\(resolvedHref))"
                
            case "img":
                let src = try element.attr("src")
                let resolvedSrc = resolveURL(src, pageURL: pageURL)
                let alt = try element.attr("alt")
                markdown += "![\(alt)](\(resolvedSrc))"
                
            case "video":
                let src = try element.attr("src")
                let resolvedSrc = resolveURL(src, pageURL: pageURL)
                let title = try element.attr("title").isEmpty ? "video" : element.attr("title")
                markdown += "[\(title)](\(resolvedSrc))"
                
            case "h1", "h2", "h3", "h4", "h5", "h6":
                let headerLevel = Int(String(tagName.dropFirst())) ?? 1
                let content = try element.getChildMarkdown(quoteLevel: quoteLevel, pageURL: pageURL)
                markdown += "\n" + String(repeating: "#", count: headerLevel) + " " + content + "\n"
                
            case "p":
                let content = try element.getChildMarkdown(quoteLevel: quoteLevel, pageURL: pageURL)
                markdown += "\n" + content + "\n"
                
            case "ul":
                let content = try convertListToMarkdown(element, isOrdered: false, pageURL: pageURL)
                markdown += content
                
            case "ol":
                let content = try convertListToMarkdown(element, isOrdered: true, pageURL: pageURL)
                markdown += content
                
            case "table":
                let content = try convertTableToMarkdown(element, pageURL: pageURL)
                markdown += content
                
            case "blockquote":
                let innerContent = try element.getChildMarkdown(quoteLevel: 0, pageURL: pageURL)
                let quotePrefix = String(repeating: "> ", count: quoteLevel + 1)
                let quotedContent = innerContent
                    .split(separator: "\n")
                    .map { quotePrefix + $0 }
                    .joined(separator: "\n")
                markdown += "\n" + quotedContent + "\n"
                
            case "pre":
                let code = try element.text()
                markdown += "\n```\n\(code)\n```\n"
                
            case "code":
                let codeText = try element.getChildMarkdown(quoteLevel: quoteLevel, pageURL: pageURL)
                markdown += "`\(codeText)`"
                
            case "strong", "b":
                let content = try element.getChildMarkdown(quoteLevel: quoteLevel, pageURL: pageURL)
                markdown += "**\(content)**"
                
            case "em", "i":
                let content = try element.getChildMarkdown(quoteLevel: quoteLevel, pageURL: pageURL)
                markdown += "*\(content)*"
                
            case "hr":
                markdown += "\n---\n"
                
            default:
                let content = try element.getChildMarkdown(quoteLevel: quoteLevel, pageURL: pageURL)
                markdown += content
            }
        }
        return markdown
    }
    
    /// Converts HTML lists to Markdown.
    /// - Parameters:
    ///   - element: The list element.
    ///   - isOrdered: A boolean indicating if the list is ordered.
    ///   - indentLevel: The indentation level.
    ///   - pageURL: The URL of the page being processed.
    /// - Returns: The Markdown string for the list.
    /// - Throws: An error if conversion fails.
    static func convertListToMarkdown(_ element: Element, isOrdered: Bool, indentLevel: Int = 0, pageURL: URL? = nil) throws -> String {
        var markdown = ""
        if indentLevel == 0 {
            markdown += "\n"
        }
        
        let items = try element.select("> li")
        let indent = String(repeating: "  ", count: indentLevel)
        
        for (index, item) in items.array().enumerated() {
            let prefix = isOrdered ? "\(index + 1). " : "- "
            let childNodes = item.getChildNodes().filter { node in
                if let elem = node as? Element, ["ul", "ol"].contains(elem.tagName()) {
                    return false
                }
                return true
            }
            
            var content = ""
            for child in childNodes {
                content += try convertNodeToMarkdown(child, pageURL: pageURL)
            }
            
            content = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty {
                let itemContent = "\(prefix)\(content)"
                markdown += "\(indent)\(itemContent)"
                
                let childUlLists = try item.select("> ul")
                let childOlLists = try item.select("> ol")
                let childLists = childUlLists.array() + childOlLists.array()
                
                if !childLists.isEmpty {
                    markdown += "\n"
                    for childList in childLists {
                        let isChildOrdered = childList.tagName() == "ol"
                        markdown += try convertListToMarkdown(childList, isOrdered: isChildOrdered, indentLevel: indentLevel + 1, pageURL: pageURL)
                    }
                }
                
                if index < items.array().count - 1 {
                    markdown += "\n"
                }
            }
        }
        
        if indentLevel == 0 {
            markdown += "\n"
        }
        return markdown
    }
    
    /// Converts a table element to Markdown.
    /// - Parameters:
    ///   - element: The table element.
    ///   - pageURL: The URL of the page being processed.
    /// - Returns: The Markdown string for the table.
    /// - Throws: An error if conversion fails.
    static func convertTableToMarkdown(_ element: Element, pageURL: URL? = nil) throws -> String {
        var markdown = "\n"
        let rows = try element.select("tr")
        for (rowIndex, row) in rows.array().enumerated() {
            let cells = try row.select("th, td")
            let cellContents = try cells.array().map { cell in
                try convertNodeToMarkdown(cell, pageURL: pageURL)
            }
            markdown += "| " + cellContents.joined(separator: " | ") + " |\n"
            if rowIndex == 0 {
                markdown += "| " + [String](repeating: "---", count: cellContents.count).joined(separator: " | ") + " |\n"
            }
        }
        markdown += "\n"
        return markdown
    }
}

extension Element {
    /// Retrieves the Markdown content for all child nodes of an element.
    /// - Parameters:
    ///   - quoteLevel: The quote level for blockquotes.
    ///   - pageURL: The URL of the page being processed.
    /// - Returns: The Markdown content as a string.
    /// - Throws: An error if conversion fails.
    func getChildMarkdown(quoteLevel: Int = 0, pageURL: URL? = nil) throws -> String {
        var markdown = ""
        for child in self.getChildNodes() {
            markdown += try Remark.convertNodeToMarkdown(child, quoteLevel: quoteLevel, pageURL: pageURL)
        }
        return markdown
    }
}

extension Remark {
    /// Generates the front matter with title, description, and OGP data.
    /// - Returns: The front matter as a string.
    public func generateFrontMatter() -> String {
        var frontMatter = """
        ---
        title: "\(self.title)"
        description: "\(self.description)"
        """
        
        for (key, value) in ogData {
            frontMatter += "\n\(key): \"\(value)\""
        }
        
        frontMatter += "\n---\n"
        return frontMatter
    }
    
    /// Combines the front matter and Markdown content for the full page.
    public var page: String {
        return generateFrontMatter() + "\n" + self.markdown
    }
}

extension Remark {
    
    public var plainText: String {
        let pattern = /\[(.*?)\]\(.*?\)/
        return markdown.replacing(pattern) { match in
            String(match.1)
        }
    }
}

extension Remark {
    /// Extracts all links from the HTML content.
    /// - Returns: An array of Link objects found in the HTML.
    /// - Throws: An error if link extraction fails.
    public func extractLinks() throws -> [Link] {
        let doc = try SwiftSoup.parse(html)
        let linkElements = try doc.select("a")
        
        return try linkElements.array().compactMap { element in
            let href = try element.attr("href")
            let resolvedHref = Self.resolveURL(href, pageURL: url)
            let text = try Self.extractLinkText(from: element, pageURL: url)
            return Link(url: resolvedHref, text: text)
        }
    }
}

extension Remark {
    /// Returns the heading level from a given line of text.
    /// - Parameter line: The line of text to examine.
    /// - Returns: The heading level (1-6) if the line is a valid Markdown heading, or `nil` if it's not.
    private func headerLevel(from line: String) -> Int? {
        let headerPattern = /^(#{1,6})\s+\S/
        guard let match = line.firstMatch(of: headerPattern) else {
            return nil
        }
        return match.1.count
    }
    
    /// Normalizes Markdown text by removing excessive newlines and whitespace.
    /// - Parameter text: The Markdown text to normalize.
    /// - Returns: The normalized Markdown text with consistent line breaks and trimmed whitespace.
    private func normalizeMarkdown(_ text: String) -> String {
        let normalized = text.replacingOccurrences(of: "\n{2,}", with: "\n", options: .regularExpression)
        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Splits the Markdown content into sections based on headings.
    /// - Parameter maxLevel: The maximum heading level to consider for section splitting (default is 1).
    /// - Returns: An array of `Section` objects, each containing the content and associated media.
    ///
    /// This method divides the Markdown content into sections based on headings up to the specified level.
    /// Each section includes all content until the next heading of the same or higher level is encountered.
    /// The first media element (image or video) found in each section is stored in the section's media property.
    ///
    /// Example:
    /// ```markdown
    /// # Section 1
    /// Content for section 1
    /// ![Image](url)
    /// More content
    ///
    /// # Section 2
    /// Content for section 2
    /// ```
    /// This would create two sections, with the first section containing the image as its media.
    public func sections(with maxLevel: Int = 1) -> [Section] {
        let lines = markdown.components(separatedBy: .newlines)
        var sections: [Section] = []
        var currentLines: [String] = []
        var currentMedia = Media.none
        var hasStartedSection = false
        
        for line in lines {
            if let headerLevel = headerLevel(from: line), headerLevel <= maxLevel {
                // Save the existing section if exists
                if hasStartedSection {
                    let content = normalizeMarkdown(currentLines.joined(separator: "\n"))
                    if !content.isEmpty {
                        let section = Section(
                            content: content,
                            media: currentMedia
                        )
                        sections.append(section)
                    }
                }
                
                // Prepare for new section
                currentLines = [line]
                currentMedia = .none
                hasStartedSection = true
                continue
            }
            
            // Skip if section hasn't started
            guard hasStartedSection else { continue }
            
            // Detect media if none found in current section
            if currentMedia == .none {
                if let media = extractMedia(from: line) {
                    currentMedia = media
                }
            }
            
            currentLines.append(line)
        }
        
        // Save the last section
        if hasStartedSection && !currentLines.isEmpty {
            let content = normalizeMarkdown(currentLines.joined(separator: "\n"))
            if !content.isEmpty {
                let section = Section(
                    content: content,
                    media: currentMedia
                )
                sections.append(section)
            }
        }
        
        return sections
    }
    
    /// Extracts media information from a line of Markdown text.
    /// - Parameter line: The line of text to examine.
    /// - Returns: A `Media` object if the line contains an image or video reference, or `nil` if no media is found.
    ///
    /// This method checks for two types of media references:
    /// - Images: Markdown image syntax `![alt](url)`
    /// - Videos: Markdown link syntax at the start of a line `[title](url)`
    private func extractMedia(from line: String) -> Media? {
        // Check for image (syntax with !)
        if let imageMatch = line.firstMatch(of: /!\[(.*?)\]\((.*?)\)/) {
            return .image(url: String(imageMatch.2), alt: String(imageMatch.1))
        }
        
        // Check for video (simple link syntax)
        if let videoMatch = line.firstMatch(of: /^\[(.*?)\]\((.*?)\)$/) {
            return .video(url: String(videoMatch.2))
        }
        
        return nil
    }
}

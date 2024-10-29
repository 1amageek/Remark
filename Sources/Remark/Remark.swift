

import Foundation
import SwiftSoup

/// A struct for parsing HTML content and extracting data into Markdown, with support for front matter metadata such as title, description, and Open Graph (OG) data.
public struct Remark: Sendable {
    
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
    
    /// Initializes a `Remark` instance by parsing the provided HTML.
    /// - Parameter html: The HTML string to be parsed.
    /// - Throws: An error if the HTML cannot be parsed.
    public init(_ html: String) throws {
        let doc = try SwiftSoup.parse(html)
        
        // Extract title, description, and Open Graph data
        self.title = try Remark.extractTitle(from: doc)
        self.description = try Remark.extractDescription(from: doc)
        self.ogData = try Remark.extractOGPData(from: doc)
        
        // Extract main content and convert to Markdown
        let mainContent = try Remark.extractMainContent(from: doc)
        self.markdown = try mainContent.array().map { try Remark.convertNodeToMarkdown($0) }.joined()
        
        // Extract plain text body
        self.body = try mainContent.text()
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
    
    /// Recursively converts a `Node` to Markdown.
    /// - Parameters:
    ///   - node: The HTML node to convert.
    ///   - quoteLevel: The quote level, used for nested blockquotes.
    /// - Returns: The converted Markdown as a string.
    /// - Throws: An error if conversion fails.
    static func convertNodeToMarkdown(_ node: Node, quoteLevel: Int = 0) throws -> String {
        var markdown = ""        
        if let textNode = node as? TextNode {
            let text = textNode.text().trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                markdown += text
            }
        } else if let element = node as? Element {
            let tagName = element.tagName()
            
            switch tagName {
            case "h1", "h2", "h3", "h4", "h5", "h6":
                let headerLevel = Int(String(tagName.dropFirst())) ?? 1
                let content = try element.getChildMarkdown(quoteLevel: quoteLevel)
                markdown += "\n" + String(repeating: "#", count: headerLevel) + " " + content + "\n"
                
            case "p":
                let content = try element.getChildMarkdown(quoteLevel: quoteLevel)
                markdown += "\n" + content + "\n"
                
            case "ul":
                let content = try convertListToMarkdown(element, isOrdered: false)
                markdown += content
                
            case "ol":
                let content = try convertListToMarkdown(element, isOrdered: true)
                markdown += content
                
            case "a":
                let href = try element.attr("href")
                let text = try element.attr("aria-label").isEmpty ? try element.getChildMarkdown(quoteLevel: quoteLevel) : try element.attr("aria-label")
                markdown += "[\(text)](\(href))"
                
            case "img":
                let src = try element.attr("src")
                let alt = try element.attr("alt")
                markdown += "![\(alt)](\(src))"
                
            case "table":
                let content = try convertTableToMarkdown(element)
                markdown += content
                
            case "blockquote":
                let innerContent = try element.getChildMarkdown(quoteLevel: 0)
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
                let codeText = try element.getChildMarkdown(quoteLevel: quoteLevel)
                markdown += "`\(codeText)`"
                
            case "strong", "b":
                let content = try element.getChildMarkdown(quoteLevel: quoteLevel)
                markdown += "**\(content)**"
                
            case "em", "i":
                let content = try element.getChildMarkdown(quoteLevel: quoteLevel)
                markdown += "*\(content)*"
                
            case "hr":
                markdown += "\n---\n"
                
            default:
                let content = try element.getChildMarkdown(quoteLevel: quoteLevel)
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
    /// - Returns: The Markdown string for the list.
    /// - Throws: An error if conversion fails.
    static func convertListToMarkdown(_ element: Element, isOrdered: Bool, indentLevel: Int = 0) throws -> String {
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
                content += try convertNodeToMarkdown(child)
            }
            
            let itemContent = "\(prefix)\(content)".trimmingCharacters(in: .whitespacesAndNewlines)
            markdown += "\(indent)\(itemContent)"
            
            let childUlLists = try item.select("> ul")
            let childOlLists = try item.select("> ol")
            let childLists = childUlLists.array() + childOlLists.array()
            
            if !childLists.isEmpty {
                markdown += "\n"
                for childList in childLists {
                    let isChildOrdered = childList.tagName() == "ol"
                    markdown += try convertListToMarkdown(childList, isOrdered: isChildOrdered, indentLevel: indentLevel + 1)
                }
            }
            
            if index < items.array().count - 1 {
                markdown += "\n"
            }
        }
        
        if indentLevel == 0 {
            markdown += "\n"
        }
        return markdown
    }

    /// Converts a table element to Markdown.
    /// - Parameter element: The table element.
    /// - Returns: The Markdown string for the table.
    /// - Throws: An error if conversion fails.
    static func convertTableToMarkdown(_ element: Element) throws -> String {
        var markdown = "\n"
        let rows = try element.select("tr")
        for (rowIndex, row) in rows.array().enumerated() {
            let cells = try row.select("th, td")
            let cellTexts = try cells.array().map { try $0.text() }
            markdown += "| " + cellTexts.joined(separator: " | ") + " |\n"
            if rowIndex == 0 {
                markdown += "| " + [String](repeating: "---", count: cellTexts.count).joined(separator: " | ") + " |\n"
            }
        }
        markdown += "\n"
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

extension Element {
    /// Retrieves the Markdown content for all child nodes of an element.
    /// - Parameter quoteLevel: The quote level for blockquotes.
    /// - Returns: The Markdown content as a string.
    /// - Throws: An error if conversion fails.
    func getChildMarkdown(quoteLevel: Int = 0) throws -> String {
        var markdown = ""
        for child in self.getChildNodes() {
            markdown += try Remark.convertNodeToMarkdown(child, quoteLevel: quoteLevel)
        }
        return markdown
    }
}

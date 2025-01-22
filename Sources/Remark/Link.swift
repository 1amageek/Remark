//
//  Link.swift
//  Remark
//
//  Created by Norikazu Muramoto on 2025/01/22.
//

/// A struct representing a link with its URL and text content.
public struct Link: Equatable, Hashable, Sendable {
    /// The URL of the link
    public let url: String
    
    /// The display text of the link
    public let text: String
    
    /// Creates a new link.
    /// - Parameters:
    ///   - url: The URL of the link
    ///   - text: The display text of the link
    public init(url: String, text: String) {
        self.url = url
        self.text = text
    }
    
    /// Returns the link in Markdown format.
    public var markdown: String {
        "[\(text)](\(url))"
    }
}

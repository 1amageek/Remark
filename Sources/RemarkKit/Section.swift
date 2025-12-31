//
//  Section.swift
//  Remark
//
//  Created by Norikazu Muramoto on 2025/01/22.
//

import Foundation

extension Remark {
    /// A section of markdown content
    public struct Section: Equatable, Sendable {
        /// The markdown text content
        public let content: String
        /// The first media element found in the section
        public let media: Media
        
        /// Creates a new section with content and media
        /// - Parameters:
        ///   - content: The markdown text content
        ///   - media: The first media element found in the section
        public init(content: String, media: Media) {
            self.content = content
            self.media = media
        }
    }
}

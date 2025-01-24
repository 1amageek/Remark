//
//  Media.swift
//  Remark
//
//  Created by Norikazu Muramoto on 2025/01/22.
//

import Foundation

/// Media type for sections content
public enum Media: Equatable, Sendable {
    /// An image with URL and alt text
    case image(url: String, alt: String)
    /// A video with URL
    case video(url: String)
    /// No media
    case none
}

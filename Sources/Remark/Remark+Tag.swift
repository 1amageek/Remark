//
//  Remark+Semantic.swift
//  Remark
//
//  Created by Norikazu Muramoto on 2025/01/25.
//

import Foundation

extension Remark {
    public enum Tag: String, Sendable {
        // Document Structure
        case main = "main"
        case section = "section"
        case article = "article"
        case header = "header"
        case footer = "footer"
        case nav = "nav"
        case aside = "aside"
        
        // Text Content
        case p = "p"
        case h1 = "h1"
        case h2 = "h2"
        case h3 = "h3"
        case h4 = "h4"
        case h5 = "h5"
        case h6 = "h6"
        case blockquote = "blockquote"
        case pre = "pre"
        case code = "code"
        
        // Lists
        case ul = "ul"
        case ol = "ol"
        case li = "li"
        
        // Media & Figures
        case figure = "figure"
        case figcaption = "figcaption"
        case img = "img"
        case video = "video"
        case audio = "audio"
        
        // Interactive Elements
        case details = "details"
        case summary = "summary"
        
        // Table Elements
        case table = "table"
        case thead = "thead"
        case tbody = "tbody"
        case tr = "tr"
        case th = "th"
        case td = "td"
        
        // Inline Elements
        case a = "a"
        case strong = "strong"
        case em = "em"
        case b = "b"
        case i = "i"
        case mark = "mark"
        case cite = "cite"
    }
}


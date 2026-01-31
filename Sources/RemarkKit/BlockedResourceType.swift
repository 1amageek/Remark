import Foundation

/// A set of WebKit resource types that can be blocked during HTML fetching.
///
/// Each case corresponds to a WebKit Content Blocker `resource-type` value.
/// Combine individual types or use predefined groups to control which resources are blocked.
///
/// ```swift
/// // Block images and fonts
/// let types: BlockedResourceType = [.image, .font]
///
/// // Block all non-essential resources (default)
/// let types: BlockedResourceType = .nonessential
///
/// // Block everything
/// let types: BlockedResourceType = .all
/// ```
public struct BlockedResourceType: OptionSet, Sendable, Hashable {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    // MARK: - Individual Types

    /// Images (`image`)
    public static let image          = BlockedResourceType(rawValue: 1 << 0)
    /// Audio and video (`media`)
    public static let media          = BlockedResourceType(rawValue: 1 << 1)
    /// Web fonts (`font`)
    public static let font           = BlockedResourceType(rawValue: 1 << 2)
    /// CSS stylesheets (`style-sheet`)
    public static let styleSheet     = BlockedResourceType(rawValue: 1 << 3)
    /// JavaScript (`script`)
    public static let script         = BlockedResourceType(rawValue: 1 << 4)
    /// XHR / fetch requests (`raw`)
    public static let raw            = BlockedResourceType(rawValue: 1 << 5)
    /// SVG documents (`svg-document`)
    public static let svgDocument    = BlockedResourceType(rawValue: 1 << 6)
    /// Popups (`popup`)
    public static let popup          = BlockedResourceType(rawValue: 1 << 7)
    /// Tracking pings (`ping`)
    public static let ping           = BlockedResourceType(rawValue: 1 << 8)
    /// WebSocket connections (`websocket`)
    public static let websocket      = BlockedResourceType(rawValue: 1 << 9)

    // MARK: - Groups

    /// Visual media: image, media, svgDocument
    public static let visual: BlockedResourceType = [.image, .media, .svgDocument]
    /// Styling: styleSheet, font
    public static let style: BlockedResourceType = [.styleSheet, .font]
    /// Active content: script, popup
    public static let active: BlockedResourceType = [.script, .popup]
    /// Network / tracking: raw, websocket, ping
    public static let network: BlockedResourceType = [.raw, .websocket, .ping]

    /// Non-essential resources for text extraction: visual + font + ping + popup.
    /// Scripts, XHR, WebSocket, and stylesheets are kept because dynamic pages (SPAs) may
    /// depend on them to load content correctly.
    public static let nonessential: BlockedResourceType = [.image, .media, .svgDocument, .font, .ping, .popup]

    /// All resource types.
    public static let all: BlockedResourceType = [.image, .media, .font, .styleSheet, .script, .raw, .svgDocument, .popup, .ping, .websocket]

    // MARK: - WebKit resource-type Mapping

    /// All individual types with their WebKit `resource-type` string.
    private static let typeMapping: [(type: BlockedResourceType, resourceType: String)] = [
        (.image,       "image"),
        (.media,       "media"),
        (.font,        "font"),
        (.styleSheet,  "style-sheet"),
        (.script,      "script"),
        (.raw,         "raw"),
        (.svgDocument, "svg-document"),
        (.popup,       "popup"),
        (.ping,        "ping"),
        (.websocket,   "websocket"),
    ]

    /// Returns the WebKit `resource-type` strings for all types in this set.
    public var resourceTypeStrings: [String] {
        Self.typeMapping.compactMap { mapping in
            self.contains(mapping.type) ? mapping.resourceType : nil
        }
    }
}

// MARK: - CLI Parsing

extension BlockedResourceType {
    /// All recognized CLI names mapped to their `BlockedResourceType` value.
    /// Includes both individual types and group names.
    public static let namedValues: [(name: String, value: BlockedResourceType)] = [
        // Individual types
        ("image",       .image),
        ("media",       .media),
        ("font",        .font),
        ("stylesheet",  .styleSheet),
        ("script",      .script),
        ("raw",         .raw),
        ("svg",         .svgDocument),
        ("popup",       .popup),
        ("ping",        .ping),
        ("websocket",   .websocket),
        // Groups
        ("visual",      .visual),
        ("style",       .style),
        ("active",      .active),
        ("network",     .network),
        ("nonessential", .nonessential),
        ("all",         .all),
    ]

    /// Parses a single CLI token into a `BlockedResourceType`.
    /// - Returns: The matching type or `nil` if the name is not recognized.
    public static func fromName(_ name: String) -> BlockedResourceType? {
        let lowered = name.lowercased()
        return namedValues.first(where: { $0.name == lowered })?.value
    }
}

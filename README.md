# Remark

Remark is a Swift library designed to parse HTML content into Markdown, with support for extracting Open Graph (OG) metadata and front matter generation. It provides a simple interface for HTML-to-Markdown conversion, metadata extraction, and formatting into a Markdown-ready format suitable for static site generators or Markdown-based applications.

## Features

- **HTML to Markdown Conversion**: Convert HTML elements (headings, lists, blockquotes, tables, etc.) to Markdown.
- **Open Graph (OG) Data Extraction**: Extract OG metadata for social media tags.
- **Front Matter Generation**: Automatically generate front matter including title, description, and OG metadata.
- **Customizable Indentation and Quote Levels**: Handles nested lists, blockquotes, and other elements with flexible levels of indentation and quoting.

## Installation

### Swift Package Manager

To install Remark, add it as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/1amageek/Remark.git", branch: "main")
]
```

## Usage

### Basic Usage

To convert HTML to Markdown and extract metadata, initialize a Remark instance with your HTML content:

```swift
import Remark

let htmlContent = """
<!DOCTYPE html>
<html>
<head>
    <title>My Page</title>
    <meta name="description" content="This is a sample description.">
    <meta property="og:image" content="https://example.com/image.jpg">
    <meta property="og:title" content="My Page Title">
    <meta property="og:description" content="An amazing page to explore.">
</head>
<body>
    <main>
        <h1>Welcome to My Page</h1>
        <p>This is some <strong>important</strong> content.</p>
        <blockquote>
            <p>A thoughtful quote.</p>
            <blockquote>
                <p>A nested insightful thought.</p>
            </blockquote>
        </blockquote>
        <ul>
            <li>Item 1</li>
            <li>Item 2</li>
        </ul>
    </main>
</body>
</html>
"""

do {
    let remark = try Remark(htmlContent)
    print("Title:", remark.title)
    print("Description:", remark.description)
    print("OG Data:", remark.ogData)
    print("Markdown:\n", remark.page)
} catch {
    print("Error:", error)
}
```

### Example Output
With the example HTML above, the output would look like:

```swift
---
title: "My Page"
description: "This is a sample description."
og_image: "https://example.com/image.jpg"
og_title: "My Page Title"
og_description: "An amazing page to explore."
---

# Welcome to My Page

This is some **important** content.

> A thoughtful quote.
> > A nested insightful thought.

- Item 1
- Item 2

```

## Tests

### Example Test for OGP Data Extraction

```swift
import XCTest
@testable import Remark

final class RemarkTests: XCTestCase {
    func testOGPDataExtraction() throws {
        let htmlContent = """
        <meta property="og:image" content="https://example.com/image.jpg" />
        <meta property="og:title" content="Example Page" />
        <meta property="og:description" content="A page description." />
        """
        
        let remark = try Remark(htmlContent)
        XCTAssertEqual(remark.ogData["og_image"], "https://example.com/image.jpg")
        XCTAssertEqual(remark.ogData["og_title"], "Example Page")
        XCTAssertEqual(remark.ogData["og_description"], "A page description.")
    }
}
```
To test OGP data extraction functionality, you might use:

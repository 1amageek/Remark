# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Remark is a Swift library and CLI tool for converting HTML to Markdown with support for:
- Open Graph (OG) metadata extraction
- Front matter generation
- URL resolution for links and images
- Semantic HTML element handling
- Live content streaming from web pages

## Development Commands

### Building
```bash
make build      # Release build
make debug      # Debug build
```

### Testing
```bash
make test       # Run all tests
swift test      # Alternative test command
```

### Installation
```bash
make install    # Install to /usr/local/bin
PREFIX=/custom/path make install  # Install to custom location
```

### Dependency Management
```bash
make update     # Update all dependencies
make resolve    # Resolve dependencies
```

### Cleanup
```bash
make clean      # Clean build artifacts
```

## Architecture

### Core Components

- **Remark.swift**: Main library containing HTML parsing and Markdown conversion logic
- **RemarkCommand.swift**: CLI interface using Swift ArgumentParser
- **RemarkUI/**: SwiftUI components for UI integration
- **HTML Fetchers**: Support for both static (`HTMLFetcher`) and dynamic (`DynamicHTMLFetcher`) content fetching

### Key Features

1. **HTML to Markdown Conversion**: Uses SwiftSoup for parsing, converts semantic HTML elements to Markdown
2. **Link Text Extraction**: Prioritizes accessibility (aria-label > img[alt] > title > text content)
3. **URL Resolution**: Handles absolute, relative, and root-relative URLs
4. **Semantic Element Handling**: Processes `main`, `article`, `section`, etc. with HTML comments
5. **Media Detection**: Extracts images and videos from content sections
6. **Streaming**: Real-time content monitoring with AsyncStream

### Dependencies

- **SwiftSoup**: HTML parsing
- **Swift ArgumentParser**: CLI argument handling
- **WebKit**: For dynamic content fetching

## Testing

The project uses Swift Testing framework (not XCTest). Tests cover:
- HTML element conversion to Markdown
- URL resolution with different base URLs
- OGP metadata extraction
- Link text extraction priority
- Section splitting functionality
- Nested content handling

## Important Implementation Details

- **Tag Masking**: By default masks `header`, `footer`, `aside`, `nav` elements
- **Fetch Methods**: Supports `.default` (static) and `.interactive` (JavaScript-enabled) fetching
- **Section Splitting**: Can split content by heading levels (default: H1)
- **Media Priority**: First media element in each section is captured
- **URL Validation**: Only accepts valid URL schemes for links

## CLI Usage

```bash
remark https://example.com                    # Convert to Markdown
remark --include-front-matter https://...     # Include front matter
remark --plain-text https://...               # Plain text output
```

## Common Patterns

When working with HTML conversion:
1. Use `Remark.init()` for string HTML content
2. Use `Remark.fetch()` for URL-based content
3. Use `Remark.stream()` for real-time content monitoring
4. Access `.markdown` for converted content, `.page` for content with front matter
# Remark 🎨✨

Convert HTML to beautiful Markdown with ease! ✨ Remark is a Swift library and command-line tool designed to parse HTML content into Markdown, with support for extracting Open Graph (OG) metadata and front matter generation. Perfect for static site generators and Markdown-based applications! 🚀

## ✨ Features

- 📝 **HTML to Markdown Conversion**: Convert HTML elements to clean, readable Markdown
- 🌐 **Open Graph (OG) Data Extraction**: Extract social media tags automatically
- 📋 **Front Matter Generation**: Generate front matter with title, description, and OG metadata
- 🎯 **Smart Indentation**: Perfect handling of nested lists and quotes
- 🔗 **URL Resolution**: Automatically resolves relative URLs to absolute URLs
- 🎨 **Intelligent Link Text**: Prioritizes accessibility with aria-label > img[alt] > title > text

## 🚀 Installation

### 📚 As a Library (Swift Package Manager)

Add Remark to your `Package.swift`: 

```swift
dependencies: [
    .package(url: "https://github.com/1amageek/Remark.git", branch: "main")
]
```

### 💻 As a Command Line Tool

#### 🛠 Using Make (Recommended)

1. Clone the repo and move into it:
```bash
git clone https://github.com/1amageek/Remark.git
cd Remark
```

2. Install with make:
```bash
make install
```

Want a custom location? No problem! 🎯
```bash
PREFIX=/your/custom/path make install
```

#### 🔧 Manual Installation

1. Clone the repo 📦
2. Build release version:
```bash
swift build -c release
```
3. Copy to your bin:
```bash
cp .build/release/RemarkCLI /usr/local/bin/remark
```

## 🎮 Usage

### 🖥 Command Line Interface

Convert HTML from any URL to Markdown: ✨
```bash
remark https://example.com
```

Include the fancy front matter: 📋
```bash
remark --include-front-matter https://example.com
```

Just the plain text, please! 📝
```bash
remark --plain-text https://example.com
```

### 📚 Library Usage

Here's a quick example to get you started! 🚀

```swift
import Remark

let htmlContent = """
<!DOCTYPE html>
<html>
<head>
    <title>My Amazing Page ✨</title>
    <meta name="description" content="Something awesome!">
    <meta property="og:image" content="https://example.com/cool.jpg">
</head>
<body>
    <h1>Welcome! 🎉</h1>
    <p>This is <strong>amazing</strong> content.</p>
</body>
</html>
"""

do {
    let remark = try Remark(htmlContent)
    print("✨ Title:", remark.title)
    print("📝 Description:", remark.description)
    print("🌐 OG Data:", remark.ogData)
    print("📄 Markdown:\n", remark.page)
} catch {
    print("❌ Error:", error)
}
```

### 🎨 Example Output

Your HTML becomes beautiful Markdown:

```markdown
---
title: "My Amazing Page ✨"
description: "Something awesome!"
og_image: "https://example.com/cool.jpg"
---

# Welcome! 🎉

This is **amazing** content.
```

## 🛠 Development

### 🏗 Building

```bash
make build      # 🚀 Release build
make debug      # 🔍 Debug build
```

### 🧪 Testing

```bash
make test       # 🎯 Run tests
```

### 🧹 Cleaning

```bash
make clean      # 🧹 Clean build artifacts
```

### 📦 Dependencies

```bash
make update     # 🔄 Update all dependencies
make resolve    # 🎯 Resolve dependencies
```

## 🧪 Tests

Here's an example test for OGP extraction:

```swift
import XCTest
@testable import Remark

final class RemarkTests: XCTestCase {
    func testOGPDataExtraction() throws {
        let htmlContent = """
        <meta property="og:image" content="https://example.com/cool.jpg" />
        <meta property="og:title" content="Amazing Page ✨" />
        """
        
        let remark = try Remark(htmlContent)
        XCTAssertEqual(remark.ogData["og_image"], "https://example.com/cool.jpg")
        XCTAssertEqual(remark.ogData["og_title"], "Amazing Page ✨")
    }
}
```

## 🌟 Contributing

Love Remark? Want to make it better? Contributions are welcome! 🎉

1. 🍴 Fork it
2. 🔨 Make your changes
3. 🧪 Test them
4. 🎯 Send a PR

## 📝 License

Remark is available under the MIT license. See the LICENSE file for more info. ✨

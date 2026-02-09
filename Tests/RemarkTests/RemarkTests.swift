import Testing
import Foundation
@testable import RemarkKit
import SwiftSoup

// MARK: - Public API Tests

@Test("Remark initialization extracts title, description, and body")
func testRemarkInitialization() throws {
    let htmlContent = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>テストページ</title>
        <meta name="description" content="ページの説明文です。">
    </head>
    <body>
        <main>
            <h1>メインタイトル</h1>
            <p>本文のテキストです。</p>
        </main>
    </body>
    </html>
    """

    let remark = try Remark(htmlContent)

    #expect(remark.title == "テストページ")
    #expect(remark.description == "ページの説明文です。")
    #expect(remark.body.contains("メインタイトル"))
    #expect(remark.body.contains("本文のテキストです"))
    #expect(remark.markdown.contains("# メインタイトル"))
}

@Test("Remark mask parameter removes specified elements")
func testRemarkMaskParameter() throws {
    let htmlContent = """
    <html>
    <body>
        <header><p>ヘッダー</p></header>
        <nav><p>ナビゲーション</p></nav>
        <main><p>メインコンテンツ</p></main>
        <aside><p>サイドバー</p></aside>
        <footer><p>フッター</p></footer>
    </body>
    </html>
    """

    // Default mask removes header, footer, aside, nav
    let remarkDefault = try Remark(htmlContent)
    #expect(!remarkDefault.markdown.contains("ヘッダー"))
    #expect(!remarkDefault.markdown.contains("ナビゲーション"))
    #expect(!remarkDefault.markdown.contains("サイドバー"))
    #expect(!remarkDefault.markdown.contains("フッター"))
    #expect(remarkDefault.markdown.contains("メインコンテンツ"))

    // Empty mask keeps all elements
    let remarkNoMask = try Remark(htmlContent, mask: [])
    #expect(remarkNoMask.markdown.contains("ヘッダー"))
    #expect(remarkNoMask.markdown.contains("ナビゲーション"))
    #expect(remarkNoMask.markdown.contains("メインコンテンツ"))
}

@Test("generateFrontMatter creates valid YAML front matter")
func testGenerateFrontMatter() throws {
    let htmlContent = """
    <html>
    <head>
        <title>フロントマターテスト</title>
        <meta name="description" content="説明文">
        <meta property="og:image" content="https://example.com/image.jpg">
        <meta property="og:type" content="article">
    </head>
    <body><p>コンテンツ</p></body>
    </html>
    """

    let remark = try Remark(htmlContent)
    let frontMatter = remark.generateFrontMatter()

    #expect(frontMatter.hasPrefix("---"))
    #expect(frontMatter.hasSuffix("---\n"))
    #expect(frontMatter.contains("title: \"フロントマターテスト\""))
    #expect(frontMatter.contains("description: \"説明文\""))
    #expect(frontMatter.contains("og_image: \"https://example.com/image.jpg\""))
    #expect(frontMatter.contains("og_type: \"article\""))
}

@Test("page property combines front matter and markdown")
func testPageProperty() throws {
    let htmlContent = """
    <html>
    <head>
        <title>ページテスト</title>
        <meta name="description" content="テスト説明">
    </head>
    <body><main><h1>見出し</h1><p>段落</p></main></body>
    </html>
    """

    let remark = try Remark(htmlContent)
    let page = remark.page

    // Front matter comes first
    #expect(page.hasPrefix("---"))
    #expect(page.contains("title: \"ページテスト\""))

    // Markdown content follows
    #expect(page.contains("# 見出し"))
    #expect(page.contains("段落"))
}

@Test("plainText removes markdown link syntax")
func testPlainTextProperty() throws {
    let htmlContent = """
    <html><body>
        <p>これは<a href="https://example.com">リンク</a>です。</p>
        <p>画像: <img src="img.jpg" alt="画像"></p>
    </body></html>
    """

    let remark = try Remark(htmlContent)
    let plainText = remark.plainText

    // Link text is preserved, URL syntax is removed
    #expect(plainText.contains("リンク"))
    #expect(!plainText.contains("]("))
    #expect(!plainText.contains("https://example.com"))
}

@Test("Heading tags conversion")
func testHeadingTags() throws {
    for level in 1...6 {
        let tagName = "h\(level)"
        let html = "<\(tagName)>見出しレベル\(level)</\(tagName)>"
        let element = try SwiftSoup.parse(html).body()!.child(0)
        let expectedMarkdown = "\n" + String(repeating: "#", count: level) + " 見出しレベル\(level)\n"
        
        let markdown = try Remark.convertNodeToMarkdown(element)
        #expect(markdown == expectedMarkdown)
    }
}

@Test("Paragraph tag conversion")
func testParagraphTag() throws {
    let html = "<p>これは段落です。</p>"
    let element = try SwiftSoup.parse(html).body()!.child(0)
    let expectedMarkdown = "\nこれは段落です。\n"
    
    let markdown = try Remark.convertNodeToMarkdown(element)
    #expect(markdown == expectedMarkdown)
}

@Test("Unordered list conversion")
func testUnorderedList() throws {
    let html = """
    <ul>
        <li>アイテム1</li>
        <li>アイテム2</li>
    </ul>
    """
    let element = try SwiftSoup.parse(html).body()!.child(0)
    let expectedMarkdown = "\n- アイテム1\n- アイテム2\n"
    
    let markdown = try Remark.convertNodeToMarkdown(element)
    #expect(markdown == expectedMarkdown)
}

@Test("Ordered list conversion")
func testOrderedList() throws {
    let html = """
    <ol>
        <li>ステップ1</li>
        <li>ステップ2</li>
    </ol>
    """
    let element = try SwiftSoup.parse(html).body()!.child(0)
    let expectedMarkdown = "\n1. ステップ1\n2. ステップ2\n"
    
    let markdown = try Remark.convertNodeToMarkdown(element)
    #expect(markdown == expectedMarkdown)
}

@Test("Anchor tag conversion with aria-label")
func testAnchorTagWithAriaLabel() throws {
    let html = "<a href=\"https://example.com\" aria-label=\"例のサイト\">リンク</a>"
    let element = try SwiftSoup.parse(html).body()!.child(0)
    let expectedMarkdown = "[例のサイト](https://example.com)"
    
    let markdown = try Remark.convertNodeToMarkdown(element)
    #expect(markdown == expectedMarkdown)
}

@Test("Anchor tag conversion without aria-label")
func testAnchorTagWithoutAriaLabel() throws {
    let html = "<a href=\"https://example.com\">リンク</a>"
    let element = try SwiftSoup.parse(html).body()!.child(0)
    let expectedMarkdown = "[リンク](https://example.com)"
    
    let markdown = try Remark.convertNodeToMarkdown(element)
    #expect(markdown == expectedMarkdown)
}

@Test("Image tag conversion")
func testImageTag() throws {
    let html = "<img src=\"https://example.com/image.png\" alt=\"サンプル画像\">"
    let element = try SwiftSoup.parse(html).body()!.child(0)
    let expectedMarkdown = "![サンプル画像](https://example.com/image.png)"
    
    let markdown = try Remark.convertNodeToMarkdown(element)
    #expect(markdown == expectedMarkdown)
}

@Test("Table tag conversion")
func testTableTag() throws {
    let html = """
    <table>
        <tr>
            <th>見出し1</th>
            <th>見出し2</th>
        </tr>
        <tr>
            <td>データ1</td>
            <td>データ2</td>
        </tr>
    </table>
    """
    let element = try SwiftSoup.parse(html).body()!.child(0)
    let expectedMarkdown = """
    | 見出し1 | 見出し2 |
    | --- | --- |
    | データ1 | データ2 |
    """
    
    let markdown = try Remark.convertNodeToMarkdown(element)
    #expect(markdown.trimmingCharacters(in: .whitespacesAndNewlines) == expectedMarkdown.trimmingCharacters(in: .whitespacesAndNewlines))
}

@Test("Blockquote tag conversion")
func testBlockquoteTag() throws {
    let html = "<blockquote>これは引用です。</blockquote>"
    let element = try SwiftSoup.parse(html).body()!.child(0)
    let expectedMarkdown = "\n> これは引用です。\n"
    
    let markdown = try Remark.convertNodeToMarkdown(element)
    #expect(markdown == expectedMarkdown)
}

@Test("Preformatted text conversion")
func testPreTag() throws {
    let html = "<pre><code>print(\"Hello, World!\")</code></pre>"
    let element = try SwiftSoup.parse(html).body()!.child(0)
    let expectedMarkdown = "\n```\nprint(\"Hello, World!\")\n```\n"
    
    let markdown = try Remark.convertNodeToMarkdown(element)
    #expect(markdown == expectedMarkdown)
}

@Test("Strong tag conversion")
func testStrongTag() throws {
    let html = "<strong>重要なテキスト</strong>"
    let element = try SwiftSoup.parse(html).body()!.child(0)
    let expectedMarkdown = "**重要なテキスト**"
    
    let markdown = try Remark.convertNodeToMarkdown(element)
    #expect(markdown == expectedMarkdown)
}

@Test("Emphasis tag conversion")
func testEmphasisTag() throws {
    let html = "<em>強調テキスト</em>"
    let element = try SwiftSoup.parse(html).body()!.child(0)
    let expectedMarkdown = "*強調テキスト*"
    
    let markdown = try Remark.convertNodeToMarkdown(element)
    #expect(markdown == expectedMarkdown)
}

@Test("Horizontal rule conversion")
func testHorizontalRule() throws {
    let html = "<hr>"
    let element = try SwiftSoup.parse(html).body()!.child(0)
    let expectedMarkdown = "\n---\n"
    
    let markdown = try Remark.convertNodeToMarkdown(element)
    #expect(markdown == expectedMarkdown)
}

@Test("Default case with child elements")
func testDefaultCase() throws {
    let html = "<div><span>テキスト</span></div>"
    let element = try SwiftSoup.parse(html).body()!.child(0)
    let expectedMarkdown = "テキスト"
    
    let markdown = try Remark.convertNodeToMarkdown(element)
    #expect(markdown == expectedMarkdown)
}

@Test("Nested list conversion")
func testNestedList() throws {
    let html = """
    <ul>
        <li>親アイテム1
            <ul>
                <li>子アイテム1</li>
                <li>子アイテム2</li>
            </ul>
        </li>
        <li>親アイテム2</li>
    </ul>
    """
    let element = try SwiftSoup.parse(html).body()!.child(0)
    let expectedMarkdown = "\n- 親アイテム1\n  - 子アイテム1\n  - 子アイテム2\n- 親アイテム2\n"
    
    let markdown = try Remark.convertNodeToMarkdown(element)
    #expect(markdown == expectedMarkdown)
}

@Test("Inline code conversion")
func testInlineCode() throws {
    let html = "<p>このコードは<code>print('Hello')</code>です。</p>"
    let element = try SwiftSoup.parse(html).body()!.child(0)
    let expectedMarkdown = "\nこのコードは`print('Hello')`です。\n"
    
    let markdown = try Remark.convertNodeToMarkdown(element)
    #expect(markdown == expectedMarkdown)
}

@Test("Complex nested structure conversion")
func testComplexNestedStructure() throws {
    let html = """
    <article>
        <h1>タイトル</h1>
        <p>これは<strong>重要な</strong>情報です。</p>
        <blockquote>
            <p>これは引用です。</p>
        </blockquote>
        <ul>
            <li>項目1</li>
            <li>項目2
                <ul>
                    <li>サブ項目1</li>
                    <li>サブ項目2</li>
                </ul>
            </li>
        </ul>
    </article>
    """
    let element = try SwiftSoup.parse(html).body()!.child(0)
    let expectedMarkdown = "\n<!-- article -->\n\n# タイトル\n\nこれは**重要な**情報です。\n\n> これは引用です。\n\n- 項目1\n- 項目2\n  - サブ項目1\n  - サブ項目2\n\n<!-- /article -->\n"

    let markdown = try Remark.convertNodeToMarkdown(element)
    #expect(markdown == expectedMarkdown)
}


@Test("Strong and emphasis combination")
func testStrongAndEmphasisCombination() throws {
    let html = "<p>このテキストは<strong><em>強調されています</em></strong>。</p>"
    let element = try SwiftSoup.parse(html).body()!.child(0)
    let expectedMarkdown = "\nこのテキストは***強調されています***。\n"
    let markdown = try Remark.convertNodeToMarkdown(element)
    #expect(markdown == expectedMarkdown)
}

@Test("Nested blockquotes conversion")
func testNestedBlockquotes() throws {
    let html = """
    <blockquote>
        <p>外側の引用</p>
        <blockquote>
            <p>内側の引用</p>
        </blockquote>
    </blockquote>
    """
    let element = try SwiftSoup.parse(html).body()!.child(0)
    let expectedMarkdown = "\n> 外側の引用\n> > 内側の引用\n"
    
    let markdown = try Remark.convertNodeToMarkdown(element)
    #expect(markdown == expectedMarkdown)
}

@Test("OGP data extraction")
func testOGPDataExtraction() throws {
    let htmlContent = """
    <html>
    <head>
        <title>テストページ</title>
        <meta name="description" content="これはテストページの説明です。">
        <meta property="og:image" content="https://example.com/image.jpg" />
        <meta property="og:title" content="テストタイトル" />
        <meta property="og:description" content="テストの説明文です。" />
        <meta property="og:url" content="https://example.com" />
        <meta property="og:locale" content="ja_JP" />
        <meta property="og:site_name" content="テストサイト" />
        <meta property="og:type" content="website" />
    </head>
    <body>
        <main>
            <h1>メインタイトル</h1>
            <p>これはテストコンテンツです。</p>
        </main>
    </body>
    </html>
    """
    
    let remark = try Remark(htmlContent)
    
    // 期待されるOGPデータ
    let expectedOGPData: [String: String] = [
        "og_image": "https://example.com/image.jpg",
        "og_title": "テストタイトル",
        "og_description": "テストの説明文です。",
        "og_url": "https://example.com",
        "og_locale": "ja_JP",
        "og_site_name": "テストサイト",
        "og_type": "website"
    ]
    
    // OGPデータのテスト
    for (key, expectedValue) in expectedOGPData {
        let actualValue = remark.ogData[key]
        #expect(actualValue == expectedValue, "OGP data for \(key) did not match. Expected \(expectedValue), got \(String(describing: actualValue))")
    }
}

@Test("URL resolution for absolute, relative, and root-relative paths")
func testURLResolution() throws {
    let pageURL = URL(string: "https://example.com/articles/post.html")!
    
    // 異なるパターンのURLを含むHTML
    let html = """
    <div>
        <a href="https://example.com/absolute">絶対パス</a>
        <a href="/root/path">ルート相対パス</a>
        <a href="../category/page">上位相対パス</a>
        <a href="./local/page">現在位置相対パス</a>
        <a href="direct/path">直接相対パス</a>
        <img src="//cdn.example.com/image.jpg" alt="プロトコル相対">
        <img src="/images/photo.jpg" alt="ルート相対画像">
        <img src="../images/pic.jpg" alt="相対画像">
    </div>
    """
    
    let remark = try Remark(html, url: pageURL)
    let markdown = remark.markdown
    
    // 絶対パスはそのまま
    #expect(markdown.contains("(https://example.com/absolute)"))
    
    // ルート相対パスは絶対パスに変換
    #expect(markdown.contains("(https://example.com/root/path)"))
    
    // 上位相対パスは正しく解決
    #expect(markdown.contains("(https://example.com/category/page)"))
    
    // 現在位置相対パスは正しく解決
    #expect(markdown.contains("(https://example.com/articles/local/page)"))
    
    // 直接相対パスは正しく解決
    #expect(markdown.contains("(https://example.com/articles/direct/path)"))
    
    // プロトコル相対URLは正しく解決
    #expect(markdown.contains("(https://cdn.example.com/image.jpg)"))
    
    // 画像のルート相対パスは絶対パスに変換
    #expect(markdown.contains("(https://example.com/images/photo.jpg)"))
    
    // 画像の相対パスは正しく解決
    #expect(markdown.contains("(https://example.com/images/pic.jpg)"))
}

@Test("URL resolution with no base URL")
func testURLResolutionWithoutBaseURL() throws {
    let html = """
    <div>
        <a href="https://example.com/absolute">絶対パス</a>
        <a href="/relative/path">相対パス</a>
        <img src="/images/photo.jpg" alt="画像">
    </div>
    """
    
    let remark = try Remark(html)
    let markdown = remark.markdown
    
    // 絶対パスはそのまま
    #expect(markdown.contains("(https://example.com/absolute)"))
    
    // ベースURLがない場合、相対パスはそのまま
    #expect(markdown.contains("(/relative/path)"))
    
    // 画像の相対パスもそのまま
    #expect(markdown.contains("(/images/photo.jpg)"))
}

@Test("Video tag conversion")
func testVideoTag() throws {
    let html = "<video src=\"https://example.com/video.mp4\" title=\"サンプルビデオ\"></video>"
    let element = try SwiftSoup.parse(html).body()!.child(0)
    let expectedMarkdown = "[サンプルビデオ](https://example.com/video.mp4)"
    
    let markdown = try Remark.convertNodeToMarkdown(element)
    #expect(markdown == expectedMarkdown)
}

@Test("Video tag without title")
func testVideoTagWithoutTitle() throws {
    let html = "<video src=\"https://example.com/video.mp4\"></video>"
    let element = try SwiftSoup.parse(html).body()!.child(0)
    let expectedMarkdown = "[video](https://example.com/video.mp4)"
    
    let markdown = try Remark.convertNodeToMarkdown(element)
    #expect(markdown == expectedMarkdown)
}

@Test("Video tag with attributes")
func testVideoTagWithAttributes() throws {
    let html = """
    <video src="https://example.com/video.mp4" title="プレゼンテーション" controls width="640" height="360"></video>
    """
    let element = try SwiftSoup.parse(html).body()!.child(0)
    let expectedMarkdown = "[プレゼンテーション](https://example.com/video.mp4)"
    
    let markdown = try Remark.convertNodeToMarkdown(element)
    #expect(markdown == expectedMarkdown)
}

@Test("Basic section splitting with h1")
func testBasicSectionSplitting() throws {
    let html = """
    <main>
        <h1>Section 1</h1>
        <p>Content 1</p>
        <h2>Subsection 1</h2>
        <p>Content 1.1</p>
        <h1>Section 2</h1>
        <img src="url" alt="Image">
        <p>Content 2</p>
    </main>
    """
    
    let remark = try Remark(html)
    let sections = remark.sections()

    #expect(sections.count == 2)
    #expect(sections[0].content == "# Section 1\nContent 1\n## Subsection 1\nContent 1.1")
    #expect(sections[1].content == "# Section 2\n![Image](url)\nContent 2")
    #expect(sections[1].media == .image(url: "url", alt: "Image"))
}

@Test("Section splitting with different levels")
func testSectionSplittingWithLevels() throws {
    let html = """
    <article>
        <h1>H1 Section</h1>
        <p>Content 1</p>
        <h2>H2 Section</h2>
        <p>Content 2</p>
        <h3>H3 Section</h3>
        <p>Content 3</p>
        <h2>Another H2</h2>
        <p>Content 4</p>
    </article>
    """
    
    let remark = try Remark(html)
    
    // Level 1
    let h1Sections = remark.sections(with: 1)
    #expect(h1Sections.count == 1)
    #expect(h1Sections[0].content.contains("# H1 Section"))
    
    // Level 2
    let h2Sections = remark.sections(with: 2)
    #expect(h2Sections.count == 3)
    #expect(h2Sections[1].content.contains("## H2 Section"))
    
    // Level 3
    let h3Sections = remark.sections(with: 3)
    #expect(h3Sections.count == 4)
    #expect(h3Sections[2].content.contains("### H3 Section"))
}

@Test("Section splitting with media detection")
func testSectionSplittingWithMedia() throws {
    let html = """
    <article>
        <h1>Section 1</h1>
        <img src="url1" alt="Image 1">
        <p>Content 1</p>
        <h1>Section 2</h1>
        <video src="video1"></video>
        <p>Content 2</p>
        <h1>Section 3</h1>
        <p>Content 3</p>
        <img src="url2" alt="Image 2">
    </article>
    """
    
    let remark = try Remark(html)
    let sections = remark.sections()
    
    #expect(sections.count == 3)
    #expect(sections[0].media == .image(url: "url1", alt: "Image 1"))
    #expect(sections[1].media == .video(url: "video1"))
    #expect(sections[2].media == .image(url: "url2", alt: "Image 2"))
}

@Test("Empty and invalid section handling")
func testEmptyAndInvalidSections() throws {
    let html = """
    <article>
        <h1>Section 1</h1>
        <h1>Section 2</h1>
        <p>Content 2</p>
        <p>#Invalid Header</p>
        <h3>Valid Header</h3>
    </article>
    """
    
    let remark = try Remark(html)
    let sections = remark.sections()
    
    #expect(sections.count == 2)
    #expect(sections[0].content == "# Section 1")
    #expect(sections[1].content.contains("# Section 2"))
    #expect(sections[1].content.contains("#Invalid Header"))
}

@Test("Section splitting with nested content")
func testSectionSplittingWithNestedContent() throws {
    let html = """
    <article>
        <h1>Main Section</h1>
        <h2>Subsection 1</h2>
        <ul>
            <li>List item 1</li>
            <li>List item 2
                <ul>
                    <li>Nested item</li>
                </ul>
            </li>
        </ul>
        <h2>Subsection 2</h2>
        <blockquote>
            <p>Blockquote</p>
            <blockquote>
                <p>Nested quote</p>
            </blockquote>
        </blockquote>
    </article>
    """
    
    let remark = try Remark(html)
    
    // Level 1
    let h1Sections = remark.sections()
    #expect(h1Sections.count == 1)
    #expect(h1Sections[0].content.contains("# Main Section"))
    #expect(h1Sections[0].content.contains("- List item 1"))
    
    // Level 2
    let h2Sections = remark.sections(with: 2)
    #expect(h2Sections.count == 3)
    print(h2Sections[1].content)
    print("----")
    print(h2Sections[2].content)
    print("----")
    #expect(h2Sections[1].content.contains("## Subsection 1"))
    #expect(h2Sections[2].content.contains("> > Nested quote"))
}

@Test("Section splitting with multiple media types")
func testSectionSplittingWithMultipleMedia() throws {
    let html = """
    <article>
        <h1>Section 1</h1>
        <img src="url1" alt="First">
        <p>Content</p>
        <img src="url2" alt="Second">
        <h1>Section 2</h1>
        <video src="video1"></video>
        <p>Content</p>
        <img src="url3" alt="Image">
    </article>
    """
    
    let remark = try Remark(html)
    let sections = remark.sections()
    
    #expect(sections.count == 2)
    // 各セクションの最初のメディアのみが保持される
    #expect(sections[0].media == .image(url: "url1", alt: "First"))
    #expect(sections[1].media == .video(url: "video1"))
}

@Test("Section splitting ignores invalid headers")
func testSectionSplittingInvalidHeaders() throws {
    let html = """
    <article>
        <h1>Valid Header 1</h1>
        <p>Content 1</p>
        <p>#Invalid Header</p>
        <p>Content 2</p>
        <h1>Valid Header 2</h1>
        <p>##Invalid Header</p>
        <p>Content 3</p>
    </article>
    """
    
    let remark = try Remark(html)
    let sections = remark.sections()
    
    #expect(sections.count == 2)
    #expect(sections[0].content.contains("#Invalid Header"))
    #expect(sections[1].content.contains("##Invalid Header"))
}

@Test("Link text extraction priority")
func testLinkTextExtractionPriority() throws {
    // Test all text sources present
    let html1 = """
    <a href="https://example.com" 
       aria-label="Aria Label" 
       title="Title">
       <img src="image.jpg" alt="Image Alt">Link Text
    </a>
    """
    let element1 = try SwiftSoup.parse(html1).body()!.child(0)
    let markdown1 = try Remark.convertNodeToMarkdown(element1)
    // Aria-label should take precedence
    #expect(markdown1 == "[Aria Label](https://example.com)")
    
    // Test without aria-label
    let html2 = """
    <a href="https://example.com" title="Title">
       <img src="image.jpg" alt="Image Alt">Link Text
    </a>
    """
    let element2 = try SwiftSoup.parse(html2).body()!.child(0)
    let markdown2 = try Remark.convertNodeToMarkdown(element2)
    // Image alt should take precedence
    #expect(markdown2 == "[Image Alt](https://example.com)")
    
    // Test without aria-label and image
    let html3 = """
    <a href="https://example.com" title="Title">Link Text</a>
    """
    let element3 = try SwiftSoup.parse(html3).body()!.child(0)
    let markdown3 = try Remark.convertNodeToMarkdown(element3)
    // Title should take precedence over link text
    #expect(markdown3 == "[Title](https://example.com)")
    
    // Test with only link text
    let html4 = """
    <a href="https://example.com">Link Text</a>
    """
    let element4 = try SwiftSoup.parse(html4).body()!.child(0)
    let markdown4 = try Remark.convertNodeToMarkdown(element4)
    // Should use link text
    #expect(markdown4 == "[Link Text](https://example.com)")
    
    // Test with empty content
    let html5 = """
    <a href="https://example.com"></a>
    """
    let element5 = try SwiftSoup.parse(html5).body()!.child(0)
    let markdown5 = try Remark.convertNodeToMarkdown(element5)
    // Should fall back to URL
    #expect(markdown5 == "[https://example.com](https://example.com)")
}

@Test("Link text extraction with nested image priority")
func testLinkTextExtractionWithNestedImage() throws {
    // Multiple nested images
    let html = """
    <a href="https://example.com">
        <img src="first.jpg" alt="">
        <img src="second.jpg" alt="Second Image">
        <img src="third.jpg" alt="Third Image">
    </a>
    """
    let element = try SwiftSoup.parse(html).body()!.child(0)
    let markdown = try Remark.convertNodeToMarkdown(element)
    // Should use first non-empty alt text
    #expect(markdown == "[Second Image](https://example.com)")
}

@Test("Link text extraction with mixed content")
func testLinkTextExtractionWithMixedContent() throws {
    let html = """
    <a href="https://example.com">
        Text Before
        <img src="image.jpg" alt="Image Alt">
        Text After
    </a>
    """
    let element = try SwiftSoup.parse(html).body()!.child(0)
    let markdown = try Remark.convertNodeToMarkdown(element)
    // Should use image alt text over mixed content
    #expect(markdown == "[Image Alt](https://example.com)")
}

@Test("Link text extraction with empty attributes")
func testLinkTextExtractionWithEmptyAttributes() throws {
    let html = """
    <a href="https://example.com"
       aria-label=""
       title="">
       <img src="image.jpg" alt="">
       <img src="image2.jpg" alt="    ">
    </a>
    """
    let element = try SwiftSoup.parse(html).body()!.child(0)
    let markdown = try Remark.convertNodeToMarkdown(element)
    // Should fall back to URL when all other options are empty
    #expect(markdown == "[https://example.com](https://example.com)")
}

@Test("Link text extraction with whitespace handling")
func testLinkTextExtractionWithWhitespace() throws {
    let html = """
    <a href="https://example.com"
       aria-label="  Aria Label  "
       title="  Title  ">
       <img src="image.jpg" alt="  Image Alt  ">
       Text Content
    </a>
    """
    let element = try SwiftSoup.parse(html).body()!.child(0)
    let markdown = try Remark.convertNodeToMarkdown(element)
    // Should trim whitespace but use aria-label
    #expect(markdown == "[Aria Label](https://example.com)")
}

// MARK: - extractLinks() Tests

@Test("extractLinks returns valid HTTP/HTTPS links")
func testExtractLinksBasic() throws {
    let htmlContent = """
    <html><body>
        <a href="https://example.com">Example</a>
        <a href="http://test.com/page">Test Page</a>
        <a href="https://another.com" aria-label="Another Site">Link</a>
    </body></html>
    """

    let remark = try Remark(htmlContent)
    let links = try remark.extractLinks()

    #expect(links.count == 3)
    #expect(links.contains { $0.url == "https://example.com" && $0.text == "Example" })
    #expect(links.contains { $0.url == "http://test.com/page" && $0.text == "Test Page" })
    #expect(links.contains { $0.text == "Another Site" })
}

@Test("extractLinks filters out invalid schemes")
func testExtractLinksFiltersInvalidSchemes() throws {
    let htmlContent = """
    <html><body>
        <a href="https://valid.com">Valid</a>
        <a href="javascript:void(0)">JavaScript</a>
        <a href="mailto:test@example.com">Email</a>
        <a href="tel:+1234567890">Phone</a>
        <a href="#anchor">Anchor</a>
    </body></html>
    """

    let remark = try Remark(htmlContent)
    let links = try remark.extractLinks()

    #expect(links.count == 1)
    #expect(links[0].url == "https://valid.com")
}

@Test("extractLinks handles empty href")
func testExtractLinksEmptyHref() throws {
    let htmlContent = """
    <html><body>
        <a href="">Empty</a>
        <a>No href</a>
        <a href="https://valid.com">Valid</a>
    </body></html>
    """

    let remark = try Remark(htmlContent)
    let links = try remark.extractLinks()

    #expect(links.count == 1)
    #expect(links[0].url == "https://valid.com")
}

// MARK: - Edge Case Tests

@Test("Empty HTML produces empty content")
func testEmptyHTML() throws {
    let htmlContent = "<html><body></body></html>"

    let remark = try Remark(htmlContent)

    #expect(remark.title.isEmpty)
    #expect(remark.description.isEmpty)
    #expect(remark.body.isEmpty)
}

@Test("HTML with only whitespace")
func testWhitespaceOnlyHTML() throws {
    let htmlContent = """
    <html>
    <body>
        <p>   </p>
        <div>
        </div>
    </body>
    </html>
    """

    let remark = try Remark(htmlContent)
    #expect(remark.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
}

@Test("Special characters are preserved")
func testSpecialCharacters() throws {
    let htmlContent = """
    <html><body>
        <p>特殊文字: &amp; &lt; &gt; &quot; &#39;</p>
        <p>絵文字: 🎉 🚀 ✨</p>
        <p>記号: © ® ™ € ¥</p>
    </body></html>
    """

    let remark = try Remark(htmlContent)

    #expect(remark.markdown.contains("&"))
    #expect(remark.markdown.contains("<"))
    #expect(remark.markdown.contains(">"))
    #expect(remark.markdown.contains("🎉"))
    #expect(remark.markdown.contains("©"))
}

@Test("Deeply nested elements are handled")
func testDeeplyNestedElements() throws {
    let htmlContent = """
    <html><body>
        <div><div><div><div><div>
            <p>深くネストされた段落</p>
        </div></div></div></div></div>
    </body></html>
    """

    let remark = try Remark(htmlContent)
    #expect(remark.markdown.contains("深くネストされた段落"))
}

// MARK: - Iterative traversal tests

@Test("Extreme depth div nesting does not crash")
func testExtremeDepthDivNesting() throws {
    let depth = 500
    let opening = String(repeating: "<div>", count: depth)
    let closing = String(repeating: "</div>", count: depth)
    let html = "\(opening)<p>Deep content</p>\(closing)"
    let element = try SwiftSoup.parse(html).body()!
    let markdown = try Remark.convertNodeToMarkdown(element)

    #expect(markdown.contains("Deep content"))
}

@Test("Extreme depth span nesting does not crash")
func testExtremeDepthSpanNesting() throws {
    let depth = 300
    let opening = String(repeating: "<span>", count: depth)
    let closing = String(repeating: "</span>", count: depth)
    let html = "<p>\(opening)Nested text\(closing)</p>"
    let element = try SwiftSoup.parse(html).body()!
    let markdown = try Remark.convertNodeToMarkdown(element)

    #expect(markdown.contains("Nested text"))
}

@Test("Child order is preserved through transparent elements")
func testChildOrderPreserved() throws {
    let html = "<div><p>A</p><p>B</p><p>C</p></div>"
    let element = try SwiftSoup.parse(html).body()!
    let markdown = try Remark.convertNodeToMarkdown(element)

    guard let rangeA = markdown.range(of: "A"),
          let rangeB = markdown.range(of: "B"),
          let rangeC = markdown.range(of: "C") else {
        Issue.record("A, B, C not all found in output")
        return
    }
    #expect(rangeA.lowerBound < rangeB.lowerBound)
    #expect(rangeB.lowerBound < rangeC.lowerBound)
}

@Test("Child order preserved across nested transparent elements")
func testChildOrderNestedTransparent() throws {
    let html = """
    <div>
        <div><p>First</p></div>
        <div><p>Second</p></div>
        <div><p>Third</p></div>
    </div>
    """
    let element = try SwiftSoup.parse(html).body()!
    let markdown = try Remark.convertNodeToMarkdown(element)

    guard let r1 = markdown.range(of: "First"),
          let r2 = markdown.range(of: "Second"),
          let r3 = markdown.range(of: "Third") else {
        Issue.record("Not all items found")
        return
    }
    #expect(r1.lowerBound < r2.lowerBound)
    #expect(r2.lowerBound < r3.lowerBound)
}

@Test("quoteLevel propagates through transparent elements")
func testQuoteLevelThroughTransparent() throws {
    let html = "<blockquote><div><div><p>Quoted text</p></div></div></blockquote>"
    let element = try SwiftSoup.parse(html).body()!
    let markdown = try Remark.convertNodeToMarkdown(element)

    #expect(markdown.contains("> Quoted text"))
}

@Test("Nested blockquotes through transparent elements")
func testNestedBlockquotesThroughTransparent() throws {
    let html = "<blockquote><div><blockquote><div><p>Deep quote</p></div></blockquote></div></blockquote>"
    let element = try SwiftSoup.parse(html).body()!
    let markdown = try Remark.convertNodeToMarkdown(element)

    #expect(markdown.contains("> > Deep quote"))
}

@Test("Text nodes interleaved with elements in transparent container")
func testTextNodesInterleavedWithElements() throws {
    let html = "<div>Before <p>Middle</p> After</div>"
    let element = try SwiftSoup.parse(html).body()!
    let markdown = try Remark.convertNodeToMarkdown(element)

    #expect(markdown.contains("Before"))
    #expect(markdown.contains("Middle"))
    #expect(markdown.contains("After"))
    // Verify order
    guard let rBefore = markdown.range(of: "Before"),
          let rMiddle = markdown.range(of: "Middle"),
          let rAfter = markdown.range(of: "After") else {
        Issue.record("Not all text found")
        return
    }
    #expect(rBefore.lowerBound < rMiddle.lowerBound)
    #expect(rMiddle.lowerBound < rAfter.lowerBound)
}

@Test("Semantic element is wrapped in HTML comments")
func testSemanticElementHTMLComments() throws {
    let html = "<article><p>Article content</p></article>"
    let element = try SwiftSoup.parse(html).body()!
    let markdown = try Remark.convertNodeToMarkdown(element)

    #expect(markdown.contains("<!-- article -->"))
    #expect(markdown.contains("<!-- /article -->"))
    #expect(markdown.contains("Article content"))
}

@Test("Empty semantic element produces no output")
func testEmptySemanticElement() throws {
    let html = "<section></section><p>Visible</p>"
    let element = try SwiftSoup.parse(html).body()!
    let markdown = try Remark.convertNodeToMarkdown(element)

    #expect(!markdown.contains("<!-- section -->"))
    #expect(markdown.contains("Visible"))
}

@Test("Multiple semantic elements each get comments")
func testMultipleSemanticElements() throws {
    let html = """
    <article><p>Art</p></article>
    <section><p>Sec</p></section>
    """
    let element = try SwiftSoup.parse(html).body()!
    let markdown = try Remark.convertNodeToMarkdown(element)

    #expect(markdown.contains("<!-- article -->"))
    #expect(markdown.contains("<!-- /article -->"))
    #expect(markdown.contains("<!-- section -->"))
    #expect(markdown.contains("<!-- /section -->"))
}

@Test("Semantic element inside transparent element")
func testSemanticInsideTransparent() throws {
    let html = "<div><div><article><p>Deep article</p></article></div></div>"
    let element = try SwiftSoup.parse(html).body()!
    let markdown = try Remark.convertNodeToMarkdown(element)

    #expect(markdown.contains("<!-- article -->"))
    #expect(markdown.contains("Deep article"))
    #expect(markdown.contains("<!-- /article -->"))
}

@Test("Button with link is processed")
func testButtonWithLink() throws {
    let html = "<button><a href=\"https://example.com\">Click</a></button>"
    let element = try SwiftSoup.parse(html).body()!
    let markdown = try Remark.convertNodeToMarkdown(element)

    #expect(markdown.contains("[Click](https://example.com)"))
}

@Test("Button without link is skipped")
func testButtonWithoutLink() throws {
    let html = "<button>Just text</button><p>After</p>"
    let element = try SwiftSoup.parse(html).body()!
    let markdown = try Remark.convertNodeToMarkdown(element)

    #expect(!markdown.contains("Just text"))
    #expect(markdown.contains("After"))
}

@Test("Leaf element: img inside transparent elements")
func testImgInsideTransparent() throws {
    let html = "<div><div><img src=\"pic.jpg\" alt=\"Photo\"></div></div>"
    let element = try SwiftSoup.parse(html).body()!
    let markdown = try Remark.convertNodeToMarkdown(element)

    #expect(markdown == "![Photo](pic.jpg)")
}

@Test("Leaf element: hr inside transparent elements")
func testHrInsideTransparent() throws {
    let html = "<div><p>Before</p><hr><p>After</p></div>"
    let element = try SwiftSoup.parse(html).body()!
    let markdown = try Remark.convertNodeToMarkdown(element)

    #expect(markdown.contains("Before"))
    #expect(markdown.contains("---"))
    #expect(markdown.contains("After"))
    guard let rBefore = markdown.range(of: "Before"),
          let rHr = markdown.range(of: "---"),
          let rAfter = markdown.range(of: "After") else {
        Issue.record("Not all content found")
        return
    }
    #expect(rBefore.lowerBound < rHr.lowerBound)
    #expect(rHr.lowerBound < rAfter.lowerBound)
}

@Test("Leaf element: video inside transparent elements")
func testVideoInsideTransparent() throws {
    let html = "<div><video src=\"movie.mp4\" title=\"My Movie\"></video></div>"
    let element = try SwiftSoup.parse(html).body()!
    let markdown = try Remark.convertNodeToMarkdown(element)

    #expect(markdown == "[My Movie](movie.mp4)")
}

@Test("Leaf element: dialog produces no output")
func testDialogProducesNothing() throws {
    let html = "<div><dialog>Hidden</dialog><p>Shown</p></div>"
    let element = try SwiftSoup.parse(html).body()!
    let markdown = try Remark.convertNodeToMarkdown(element)

    #expect(!markdown.contains("Hidden"))
    #expect(markdown.contains("Shown"))
}

@Test("Formatting inside transparent: heading levels")
func testHeadingLevelsInsideTransparent() throws {
    let html = "<div><h1>H1</h1><h2>H2</h2><h3>H3</h3><h4>H4</h4><h5>H5</h5><h6>H6</h6></div>"
    let element = try SwiftSoup.parse(html).body()!
    let markdown = try Remark.convertNodeToMarkdown(element)

    #expect(markdown.contains("# H1"))
    #expect(markdown.contains("## H2"))
    #expect(markdown.contains("### H3"))
    #expect(markdown.contains("#### H4"))
    #expect(markdown.contains("##### H5"))
    #expect(markdown.contains("###### H6"))
}

@Test("Formatting inside transparent: strong and em")
func testInlineFormattingInsideTransparent() throws {
    let html = "<div><p><strong>Bold</strong> and <em>Italic</em></p></div>"
    let element = try SwiftSoup.parse(html).body()!
    let markdown = try Remark.convertNodeToMarkdown(element)

    #expect(markdown.contains("**Bold**"))
    #expect(markdown.contains("*Italic*"))
}

@Test("Formatting inside transparent: list")
func testListInsideTransparent() throws {
    let html = "<div><div><ul><li>A</li><li>B</li></ul></div></div>"
    let element = try SwiftSoup.parse(html).body()!
    let markdown = try Remark.convertNodeToMarkdown(element)

    #expect(markdown.contains("- A"))
    #expect(markdown.contains("- B"))
}

@Test("Formatting inside transparent: table")
func testTableInsideTransparent() throws {
    let html = "<div><div><table><tr><th>Col</th></tr><tr><td>Val</td></tr></table></div></div>"
    let element = try SwiftSoup.parse(html).body()!
    let markdown = try Remark.convertNodeToMarkdown(element)

    #expect(markdown.contains("| Col |"))
    #expect(markdown.contains("| --- |"))
    #expect(markdown.contains("| Val |"))
}

@Test("Formatting inside transparent: code block")
func testCodeBlockInsideTransparent() throws {
    let html = "<div><pre>let x = 1</pre></div>"
    let element = try SwiftSoup.parse(html).body()!
    let markdown = try Remark.convertNodeToMarkdown(element)

    #expect(markdown.contains("```"))
    #expect(markdown.contains("let x = 1"))
}

@Test("Empty transparent elements produce no output")
func testEmptyTransparentElements() throws {
    let html = "<div><div><div></div></div></div><p>Visible</p>"
    let element = try SwiftSoup.parse(html).body()!
    let markdown = try Remark.convertNodeToMarkdown(element)

    let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
    #expect(trimmed == "Visible")
}

@Test("Empty paragraph produces no output")
func testEmptyParagraph() throws {
    let html = "<p></p><p>Content</p>"
    let element = try SwiftSoup.parse(html).body()!
    let markdown = try Remark.convertNodeToMarkdown(element)

    let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
    #expect(trimmed == "Content")
}

@Test("Whitespace-only text nodes are skipped")
func testWhitespaceOnlyTextNodes() throws {
    let html = "<div>   \n   <p>Real content</p>   \n   </div>"
    let element = try SwiftSoup.parse(html).body()!
    let markdown = try Remark.convertNodeToMarkdown(element)

    let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
    #expect(trimmed == "Real content")
}

@Test("Wide tree with many siblings at same level")
func testWideSiblingTree() throws {
    var html = "<div>"
    for i in 1...50 {
        html += "<p>Item \(i)</p>"
    }
    html += "</div>"
    let element = try SwiftSoup.parse(html).body()!
    let markdown = try Remark.convertNodeToMarkdown(element)

    for i in 1...50 {
        #expect(markdown.contains("Item \(i)"))
    }
}

@Test("Real-world wrapper div pattern")
func testRealWorldWrapperDivs() throws {
    let html = """
    <div class="page">
      <div class="container">
        <div class="row">
          <div class="col-md-8">
            <div class="content-wrapper">
              <div class="article-body">
                <h1>Title</h1>
                <p>First paragraph.</p>
                <div class="image-wrapper">
                  <img src="photo.jpg" alt="Photo">
                </div>
                <p>Second paragraph with <a href="https://example.com">link</a>.</p>
                <ul>
                  <li>Item A</li>
                  <li>Item B</li>
                </ul>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
    let element = try SwiftSoup.parse(html).body()!
    let markdown = try Remark.convertNodeToMarkdown(element)

    #expect(markdown.contains("# Title"))
    #expect(markdown.contains("First paragraph."))
    #expect(markdown.contains("![Photo](photo.jpg)"))
    #expect(markdown.contains("[link](https://example.com)"))
    #expect(markdown.contains("Second paragraph with"))
    #expect(markdown.contains("- Item A"))
    #expect(markdown.contains("- Item B"))

    // Verify ordering
    guard let rTitle = markdown.range(of: "# Title"),
          let rFirst = markdown.range(of: "First paragraph"),
          let rPhoto = markdown.range(of: "![Photo]"),
          let rSecond = markdown.range(of: "Second paragraph"),
          let rItems = markdown.range(of: "- Item A") else {
        Issue.record("Missing content")
        return
    }
    #expect(rTitle.lowerBound < rFirst.lowerBound)
    #expect(rFirst.lowerBound < rPhoto.lowerBound)
    #expect(rPhoto.lowerBound < rSecond.lowerBound)
    #expect(rSecond.lowerBound < rItems.lowerBound)
}

@Test("Link with image child inside transparent element")
func testLinkWithImageInsideTransparent() throws {
    let html = """
    <div><div><a href="https://example.com"><img src="banner.jpg" alt="Banner"></a></div></div>
    """
    let element = try SwiftSoup.parse(html).body()!
    let markdown = try Remark.convertNodeToMarkdown(element)

    #expect(markdown.contains("["))
    #expect(markdown.contains("](https://example.com)"))
}

@Test("Mixed transparent elements: form, label, fieldset")
func testFormLabelFieldsetTransparent() throws {
    let html = """
    <form>
      <fieldset>
        <label><span>Name:</span></label>
      </fieldset>
      <fieldset>
        <label><span>Email:</span></label>
      </fieldset>
    </form>
    """
    let element = try SwiftSoup.parse(html).body()!
    let markdown = try Remark.convertNodeToMarkdown(element)

    #expect(markdown.contains("Name:"))
    #expect(markdown.contains("Email:"))
}

@Test("Deeply nested transparent with formatting at each level")
func testFormattingAtEachDepthLevel() throws {
    let html = """
    <div>
      <p>Level 1</p>
      <div>
        <p>Level 2</p>
        <div>
          <p>Level 3</p>
          <div>
            <p>Level 4</p>
          </div>
        </div>
      </div>
    </div>
    """
    let element = try SwiftSoup.parse(html).body()!
    let markdown = try Remark.convertNodeToMarkdown(element)

    for i in 1...4 {
        #expect(markdown.contains("Level \(i)"))
    }
    guard let r1 = markdown.range(of: "Level 1"),
          let r2 = markdown.range(of: "Level 2"),
          let r3 = markdown.range(of: "Level 3"),
          let r4 = markdown.range(of: "Level 4") else {
        Issue.record("Not all levels found")
        return
    }
    #expect(r1.lowerBound < r2.lowerBound)
    #expect(r2.lowerBound < r3.lowerBound)
    #expect(r3.lowerBound < r4.lowerBound)
}

@Test("Multiple same-level headings")
func testMultipleSameLevelHeadings() throws {
    let htmlContent = """
    <html><body>
        <h1>First H1</h1>
        <p>Content 1</p>
        <h1>Second H1</h1>
        <p>Content 2</p>
        <h1>Third H1</h1>
        <p>Content 3</p>
    </body></html>
    """

    let remark = try Remark(htmlContent)
    let sections = remark.sections(with: 1)

    #expect(sections.count == 3)
    #expect(sections[0].content.contains("# First H1"))
    #expect(sections[1].content.contains("# Second H1"))
    #expect(sections[2].content.contains("# Third H1"))
}

@Test("Mixed content with inline elements")
func testMixedInlineContent() throws {
    let htmlContent = """
    <html><body>
        <p>This is <strong>bold</strong> and <em>italic</em> and <code>code</code> text.</p>
    </body></html>
    """

    let remark = try Remark(htmlContent)

    #expect(remark.markdown.contains("**bold**"))
    #expect(remark.markdown.contains("*italic*"))
    #expect(remark.markdown.contains("`code`"))
}

@Test("Table with empty cells")
func testTableWithEmptyCells() throws {
    let html = """
    <table>
        <tr><th>Header 1</th><th></th></tr>
        <tr><td></td><td>Data</td></tr>
    </table>
    """
    let element = try SwiftSoup.parse(html).body()!.child(0)
    let markdown = try Remark.convertNodeToMarkdown(element)

    #expect(markdown.contains("| Header 1 |"))
    #expect(markdown.contains("| Data |"))
}

@Test("Code block with language hint")
func testCodeBlockPreservesContent() throws {
    let htmlContent = """
    <html><body>
        <pre><code>func hello() { print("Hello, World!") }</code></pre>
    </body></html>
    """

    let remark = try Remark(htmlContent)

    #expect(remark.markdown.contains("```"))
    #expect(remark.markdown.contains("func hello()"))
    #expect(remark.markdown.contains("print"))
}

@Test("URL with base URL resolves correctly")
func testURLWithBaseURL() throws {
    let htmlContent = """
    <html><body>
        <a href="/page">Relative Link</a>
        <img src="../image.jpg" alt="Image">
    </body></html>
    """

    let baseURL = URL(string: "https://example.com/docs/intro.html")!
    let remark = try Remark(htmlContent, url: baseURL)

    #expect(remark.markdown.contains("(https://example.com/page)"))
    #expect(remark.markdown.contains("(https://example.com/image.jpg)"))
}

// MARK: - Timeout Tests

@Test("Fetch with short timeout throws error for slow responses")
func testFetchWithShortTimeout() async throws {
    // Use an invalid/non-routable IP to trigger timeout
    let url = URL(string: "http://10.255.255.1/")!

    do {
        _ = try await Remark.fetch(from: url, method: .default, timeout: 1)
        Issue.record("Expected timeout error but fetch succeeded")
    } catch {
        // Expected: timeout or connection error
        #expect(true)
    }
}

@Test("Fetch accepts custom timeout parameter")
func testFetchAcceptsCustomTimeout() async throws {
    // This test verifies the API accepts the timeout parameter
    // We use a very short timeout with an unreachable address
    let url = URL(string: "http://10.255.255.1/")!

    let startTime = Date()
    _ = try? await Remark.fetch(from: url, method: .default, timeout: 2)
    let elapsed = Date().timeIntervalSince(startTime)

    // Should timeout within reasonable bounds (timeout + some buffer)
    #expect(elapsed < 10, "Fetch should respect timeout parameter")
}

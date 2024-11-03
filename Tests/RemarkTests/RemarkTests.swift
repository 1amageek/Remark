import Testing
import Foundation
@testable import Remark
import SwiftSoup

@Test func example() async throws {
    let htmlContent = """
<!DOCTYPE html>
<html>
<head>
    <title>旅館のページ</title>
    <meta name="description" content="素晴らしい旅館でのご宿泊をお楽しみください。">
</head>
<body>
    <main>
        <h1>ようこそ</h1>
        <p>この旅館は、最高の体験を提供します。</p>
        <section>
            <h2>お部屋情報</h2>
            <p>和室や洋室などさまざまな部屋をご用意しております。</p>
        </section>
        <section>
            <h2>プランのご紹介</h2>
            <ul>
                <li>朝食付きプラン</li>
                <li>温泉満喫プラン</li>
            </ul>
        </section>
        <img src="https://example.com/image.jpg" alt="旅館の外観">
        <a href="https://example.com/contact" aria-label="お問い合わせ">お問い合わせ</a>
    </main>
</body>
</html>
"""
    
    do {
        let remark = try Remark(htmlContent)
        print("タイトル: \(remark.title)")
        print("説明: \(remark.description)")
        print("本文: \(remark.body)")
        print("Markdown:\n\(remark.page)")
    } catch {
        print("Error: \(error)")
    }
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
    let expectedMarkdown = "\n# タイトル\n\nこれは**重要な**情報です。\n\n> これは引用です。\n\n- 項目1\n- 項目2\n  - サブ項目1\n  - サブ項目2\n"
    
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

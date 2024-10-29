import Testing
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

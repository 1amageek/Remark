//
//  RemarkView.swift
//  Remark
//
//  Created by Norikazu Muramoto on 2024/11/13.
//

import Foundation
import SwiftUI
import Remark

public struct RemarkView: View {
    
    @State var viewModel: ViewModel = .init()
    
    public var body: some View {
        @Bindable var model = viewModel
        ScrollView {
            LazyVStack {
                ForEach(model.sections, id: \.self) { section in
                    Text(section.content)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    Divider()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack {
                    TextField("URL", text: $model.url)
                        .frame(minWidth: 90)
                    Button {
                        Task {
                            try? await viewModel.fetch()
                        }
                    } label: {
                        Text("Go")
                    }
                }
            }
        }
        .task {
            await measure(label: "fetch() 実行時間") {
                try? await viewModel.fetch()
            }
        }
    }
}

extension Remark.Section: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(content)
    }
}


extension String {
    func getAttributedString() -> AttributedString {
        do {
            let attributedString = try AttributedString(markdown: self)
            return attributedString
        } catch {
            print("Couldn't parse: \(error)")
        }
        return AttributedString("Error parsing markdown")
    }
}

/// 実行時間を計測するユーティリティ関数
/// - Parameters:
///   - label: 計測結果に付けるラベル（任意）
///   - block: 実行したい処理
/// - Returns: 処理結果（戻り値がある場合）
func measure<T>(label: String = "Execution Time", block: @Sendable () async throws -> T) async rethrows -> T {
    let startTime = Date() // 計測開始時刻
    let result = try await block() // 測定対象の処理を実行
    let endTime = Date() // 計測終了時刻
    let elapsedTime = endTime.timeIntervalSince(startTime) // 経過時間を計算
    print("\(label): \(String(format: "%.2f 秒", elapsedTime))")
    return result
}


@Observable
class ViewModel: @unchecked Sendable {
    
    var url: String = "https://www.apple.com/"
    
    var content: String = ""
    
    var remark: Remark?
    
    var sections: [Remark.Section] = []
    
    init() {
        
    }
    
    func fetch() async throws {
        guard let url = URL(string: url) else {
            return
        }
        let fetcher = await WebKitFetcher()
        let webpage = try await fetcher.fetchHTML(from: url)
        self.remark = try Remark(webpage, url: url)
        self.content = self.remark?.page ?? ""
        self.sections = self.remark?.sections(with: 2) ?? []
    }
    
//    func fetch() async throws {
//        guard let url = URL(string: url) else {
//            return
//        }
//        let (data, response) = try await URLSession.shared.data(from: url)
//        guard let httpResponse = response as? HTTPURLResponse else {
//            return
//        }
//        guard (200...299).contains(httpResponse.statusCode) else {
//            return
//        }
//        guard let webpage = String(data: data, encoding: .utf8) else {
//            return
//        }
//        self.remark = try Remark(webpage, url: url)
//        self.content = self.remark?.page ?? ""
//        self.sections = self.remark?.sections(with: 2) ?? []
//    }
}

#Preview {
    NavigationStack {
        RemarkView()
    }
    .frame(width: 440, height: 440)
    .presentedWindowToolbarStyle(.unifiedCompact(showsTitle: false))
}

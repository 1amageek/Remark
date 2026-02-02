//
//  HTMLFetching.swift
//  Remark
//
//  Created by Norikazu Muramoto on 2025/01/23.
//

import Foundation

protocol HTMLFetching {
    func fetchHTML(from url: URL, referer: URL?, timeout: TimeInterval, customHeaders: [String: String]?) async throws -> String
}

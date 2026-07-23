//
//  BlockedItem.swift
//  Iris
//
//  A single entry on the focus block list — either a macOS app (matched by
//  bundle ID) or a website (matched by domain substring in the browser URL).
//

import Foundation

struct BlockedItem: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var kind: Kind
    var bundleID: String?
    var domain: String?
    var isEnabled: Bool

    enum Kind: String, Codable {
        case app
        case website
    }

    static func app(name: String, bundleID: String) -> BlockedItem {
        BlockedItem(id: UUID(), name: name, kind: .app,
                    bundleID: bundleID, domain: nil, isEnabled: true)
    }

    static func website(domain: String) -> BlockedItem {
        let trimmed = domain
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
        let name = trimmed.components(separatedBy: "/").first ?? trimmed
        return BlockedItem(id: UUID(), name: name, kind: .website,
                           bundleID: nil, domain: name, isEnabled: true)
    }
}

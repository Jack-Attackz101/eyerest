//
//  ProblemArea.swift
//  Iris
//

import Foundation

enum ProblemArea: String, CaseIterable, Identifiable, Codable {
    case eyes
    case neck
    case back
    case wrists

    var id: String { rawValue }

    var label: String {
        switch self {
        case .eyes:   return "Eyes"
        case .neck:   return "Neck"
        case .back:   return "Back"
        case .wrists: return "Wrists"
        }
    }

    var symbol: String {
        switch self {
        case .eyes:   return "eye.circle"
        case .neck:   return "figure.stand"
        case .back:   return "figure.seated.side"
        case .wrists: return "hand.raised.circle"
        }
    }
}

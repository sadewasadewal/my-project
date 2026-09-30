//
//  CanvasModels.swift
//  ArtworkEditor
//
//  Created for mobile artwork and sticker editor in SwiftUI.
//

import SwiftUI
import UIKit

// MARK: - Canvas Item Type

/// Dynamic content type for canvas items: either an image sticker or styled text.
public enum CanvasItemType: Equatable {
    case image(UIImage)
    case text(String, Color, Font)

    public static func == (lhs: CanvasItemType, rhs: CanvasItemType) -> Bool {
        switch (lhs, rhs) {
        case (.image(let img1), .image(let img2)):
            return img1 === img2 || img1.pngData() == img2.pngData()
        case (.text(let s1, let c1, _), .text(let s2, let c2, _)):
            // Font doesn't conform to Equatable across all SwiftUI versions,
            // so we compare string and color values.
            return s1 == s2 && c1 == c2
        default:
            return false
        }
    }
}

// MARK: - Canvas Item Model

/// Core data model representing an interactive artwork or sticker element on the canvas.
public struct CanvasItem: Identifiable, Equatable {
    /// Unique identifier for each item.
    public let id: UUID

    /// Dynamic content type (.image or .text).
    public var itemType: CanvasItemType

    /// Center position coordinate on the canvas.
    public var position: CGPoint

    /// Scale multiplier (default: 1.0).
    public var scale: CGFloat

    /// Rotation angle (default: 0).
    public var rotation: Angle

    /// Visibility of the bounding box and editing controls.
    public var boundsVisible: Bool

    public init(
        id: UUID = UUID(),
        itemType: CanvasItemType,
        position: CGPoint = .zero,
        scale: CGFloat = 1.0,
        rotation: Angle = .zero,
        boundsVisible: Bool = false
    ) {
        self.id = id
        self.itemType = itemType
        self.position = position
        self.scale = scale
        self.rotation = rotation
        self.boundsVisible = boundsVisible
    }

    public static func == (lhs: CanvasItem, rhs: CanvasItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.itemType == rhs.itemType &&
        lhs.position == rhs.position &&
        lhs.scale == rhs.scale &&
        lhs.rotation == rhs.rotation &&
        lhs.boundsVisible == rhs.boundsVisible
    }
}

// MARK: - Canvas Background

/// Canvas background definition supporting linear gradients, solid colors, and photos.
public enum CanvasBackground: Equatable {
    case gradient([Color])
    case color(Color)
    case photo(UIImage)

    public static func == (lhs: CanvasBackground, rhs: CanvasBackground) -> Bool {
        switch (lhs, rhs) {
        case (.gradient(let g1), .gradient(let g2)):
            return g1 == g2
        case (.color(let c1), .color(let c2)):
            return c1 == c2
        case (.photo(let p1), .photo(let p2)):
            return p1 === p2 || p1.pngData() == p2.pngData()
        default:
            return false
        }
    }
}

// MARK: - Preset Gradients

public struct GradientPreset: Identifiable {
    public let id: String
    public let name: String
    public let colors: [Color]

    public init(name: String, colors: [Color]) {
        self.id = name
        self.name = name
        self.colors = colors
    }

    public static let presets: [GradientPreset] = [
        GradientPreset(name: "Sunset", colors: [Color(red: 1.0, green: 0.45, blue: 0.2), Color(red: 0.95, green: 0.2, blue: 0.6), Color(red: 0.5, green: 0.1, blue: 0.8)]),
        GradientPreset(name: "Ocean", colors: [Color(red: 0.0, green: 0.75, blue: 0.85), Color(red: 0.1, green: 0.4, blue: 0.9), Color(red: 0.15, green: 0.15, blue: 0.6)]),
        GradientPreset(name: "Aurora", colors: [Color(red: 0.15, green: 0.9, blue: 0.6), Color(red: 0.1, green: 0.7, blue: 0.8), Color(red: 0.4, green: 0.2, blue: 0.85)]),
        GradientPreset(name: "Berry", colors: [Color(red: 0.95, green: 0.2, blue: 0.45), Color(red: 0.7, green: 0.1, blue: 0.6), Color(red: 0.35, green: 0.05, blue: 0.4)]),
        GradientPreset(name: "Midnight", colors: [Color(red: 0.08, green: 0.1, blue: 0.22), Color(red: 0.04, green: 0.05, blue: 0.12), Color.black]),
        GradientPreset(name: "Peach", colors: [Color(red: 1.0, green: 0.7, blue: 0.5), Color(red: 1.0, green: 0.4, blue: 0.45)]),
        GradientPreset(name: "Neon", colors: [Color(red: 0.0, green: 1.0, blue: 0.8), Color(red: 0.8, green: 0.0, blue: 1.0)])
    ]
}

// MARK: - Aspect Ratio Presets

/// Supported frame aspect ratios for mobile content creation.
public enum CanvasAspectRatio: String, CaseIterable, Identifiable {
    case square = "1:1"
    case portrait = "4:5"
    case story = "9:16"

    public var id: String { rawValue }

    public var ratio: CGFloat {
        switch self {
        case .square: return 1.0
        case .portrait: return 4.0 / 5.0
        case .story: return 9.0 / 16.0
        }
    }

    public var title: String {
        switch self {
        case .square: return "1:1 Square"
        case .portrait: return "4:5 Portrait"
        case .story: return "9:16 Story"
        }
    }

    public var icon: String {
        switch self {
        case .square: return "square"
        case .portrait: return "rectangle.portrait"
        case .story: return "iphone"
        }
    }
}

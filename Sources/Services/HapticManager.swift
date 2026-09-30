//
//  HapticManager.swift
//  ArtworkEditor
//
//  Created for mobile artwork and sticker editor in SwiftUI.
//

import UIKit

/// Centralized manager for physical haptic feedback across interactions.
@MainActor
public final class HapticManager {
    public static let shared = HapticManager()

    private let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    private init() {
        prepare()
    }

    /// Prepares generators to reduce latency.
    public func prepare() {
        lightImpactGenerator.prepare()
        mediumImpactGenerator.prepare()
        notificationGenerator.prepare()
    }

    /// Triggers a light impact haptic feedback (e.g. entering trash zone or dropping item).
    public func lightImpact() {
        lightImpactGenerator.impactOccurred()
    }

    /// Triggers a medium impact haptic feedback.
    public func mediumImpact() {
        mediumImpactGenerator.impactOccurred()
    }

    /// Triggers a notification feedback (success, warning, error).
    public func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationGenerator.notificationOccurred(type)
    }
}

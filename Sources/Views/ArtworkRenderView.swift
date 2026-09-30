//
//  ArtworkRenderView.swift
//  ArtworkEditor
//
//  Created for mobile artwork and sticker editor in SwiftUI.
//

import SwiftUI
import UIKit
import CoreTransferable

// MARK: - Transferable Share Wrapper

/// Transferable container for exporting high-resolution rendered PNG artwork.
public struct ArtworkExportItem: Transferable {
    public let uiImage: UIImage
    public let title: String

    public init(uiImage: UIImage, title: String = "My Artwork") {
        self.uiImage = uiImage
        self.title = title
    }

    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            guard let data = item.uiImage.pngData() else {
                throw NSError(domain: "ArtworkExportError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to PNG format."])
            }
            return data
        }
    }
}

// MARK: - Clean Isolated Canvas View

/// Isolated artwork canvas context containing solely the artwork layers (background, stickers, text).
/// This view is completely free of any application controls, status bars, or editing overlays.
public struct CleanCanvasArtworkView: View {
    public let items: [CanvasItem]
    public let background: CanvasBackground
    public let canvasSize: CGSize

    public init(items: [CanvasItem], background: CanvasBackground, canvasSize: CGSize) {
        self.items = items
        self.background = background
        self.canvasSize = canvasSize
    }

    public var body: some View {
        ZStack {
            // Layer 1: Background
            backgroundLayer

            // Layer 2: Canvas Items (images and text)
            ForEach(items) { item in
                ItemContentRawView(item: item)
                    .scaleEffect(item.scale)
                    .rotationEffect(item.rotation)
                    .position(item.position)
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .clipped()
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        switch background {
        case .color(let color):
            color
                .frame(width: canvasSize.width, height: canvasSize.height)

        case .gradient(let colors):
            LinearGradient(
                colors: colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: canvasSize.width, height: canvasSize.height)

        case .photo(let uiImage):
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: canvasSize.width, height: canvasSize.height)
                .clipped()
        }
    }
}

// MARK: - Pure Item Content Renderer

/// Renders pure sticker image or text without bounding borders, handles, or gesture targets.
public struct ItemContentRawView: View {
    public let item: CanvasItem

    public init(item: CanvasItem) {
        self.item = item
    }

    public var body: some View {
        switch item.itemType {
        case .image(let uiImage):
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 160, maxHeight: 160)

        case .text(let content, let color, let font):
            Text(content)
                .font(font)
                .foregroundColor(color)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: true, vertical: true)
                .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 1)
        }
    }
}

// MARK: - High-Res Isolated Rendering Service

/// Uses ImageRenderer to snapshot ONLY the CleanCanvasArtworkView context.
@MainActor
public enum ArtworkRenderService {
    /// Renders the clean isolated artwork view into a high-resolution UIImage.
    /// Explicitly sets renderer.scale to UIScreen.main.scale to ensure retina resolution.
    public static func renderHighResImage(
        items: [CanvasItem],
        background: CanvasBackground,
        canvasSize: CGSize
    ) -> UIImage? {
        let artworkView = CleanCanvasArtworkView(
            items: items,
            background: background,
            canvasSize: canvasSize
        )

        let renderer = ImageRenderer(content: artworkView)

        // Ensure retina display fidelity using device screen scale
        let screenScale = (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen.scale) ?? UIScreen.main.scale

        renderer.scale = screenScale
        renderer.isOpaque = true

        return renderer.uiImage
    }
}

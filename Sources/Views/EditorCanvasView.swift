//
//  EditorCanvasView.swift
//  ArtworkEditor
//
//  Created for mobile artwork and sticker editor in SwiftUI.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Editor Mode

private enum EditorBottomTab: String, CaseIterable, Identifiable {
    case stickers = "Stickers"
    case text = "Text"
    case background = "Background"
    case layers = "Layers"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .stickers: return "sparkles"
        case .text: return "textformat"
        case .background: return "paintpalette.fill"
        case .layers: return "square.2.layers.3d"
        }
    }
}

// MARK: - Main Editor Canvas View

/// Complete, professional-grade mobile artwork and sticker editor in SwiftUI.
public struct EditorCanvasView: View {

    // MARK: - Canvas State
    @State private var items: [CanvasItem] = []
    @State private var canvasBackground: CanvasBackground = .gradient(GradientPreset.presets[0].colors)
    @State private var aspectRatio: CanvasAspectRatio = .square
    @State private var activeItemId: UUID? = nil
    @State private var showBoundingBox: Bool = true

    // MARK: - History & Services
    @StateObject private var historyManager = CanvasHistoryManager()
    @StateObject private var photoLibraryManager = PhotoLibraryManager.shared

    // MARK: - Active Gesture Transformation State
    @State private var gestureDragOffset: CGSize = .zero
    @State private var gestureScale: CGFloat = 1.0
    @State private var gestureRotation: Angle = .zero
    @State private var isDraggingItem: Bool = false
    @State private var isHoveringTrash: Bool = false

    // MARK: - UI & Sheet States
    @State private var currentTab: EditorBottomTab = .stickers
    @State private var showTextEditorSheet: Bool = false
    @State private var showExportSheet: Bool = false
    @State private var isDropTargeted: Bool = false
    @State private var selectedBackgroundColor: Color = .white
    @State private var showClearConfirmation: Bool = false

    // MARK: - PhotosPicker Selections
    @State private var selectedBgPhotoItem: PhotosPickerItem? = nil
    @State private var selectedStickerPhotoItem: PhotosPickerItem? = nil

    // MARK: - Export Cache
    @State private var renderedExportImage: UIImage? = nil
    @State private var currentCanvasRenderSize: CGSize = CGSize(width: 350, height: 350)

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                // Background of the entire editor screen
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top Navigation & Action Bar
                    topActionBar
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 6)

                    // Aspect Ratio Presets Bar
                    aspectRatioSelectorBar
                        .padding(.horizontal)
                        .padding(.bottom, 8)

                    // Main Artwork Canvas Area
                    GeometryReader { containerGeometry in
                        let canvasSize = calculateCanvasSize(in: containerGeometry.size, for: aspectRatio)

                        ZStack {
                            // Canvas Border Shadow & Card
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
                                .frame(width: canvasSize.width, height: canvasSize.height)

                            // Clean Canvas with Interactive Layers
                            interactiveCanvas(size: canvasSize)
                                .frame(width: canvasSize.width, height: canvasSize.height)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .onAppear {
                                    currentCanvasRenderSize = canvasSize
                                    if items.isEmpty {
                                        loadDefaultSampleStickers(canvasSize: canvasSize)
                                    }
                                }
                                .onChange(of: canvasSize) { newSize in
                                    currentCanvasRenderSize = newSize
                                }

                            // Trash Zone Overlay (Presents dynamically during drag)
                            if isDraggingItem {
                                trashZoneOverlay(canvasSize: canvasSize)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    // Bottom Control Studio (Tabs & Panel)
                    bottomEditorStudio
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showTextEditorSheet) {
                TextEntrySheet { text, color, font in
                    addTextItem(text: text, color: color, font: font)
                }
            }
            .sheet(isPresented: $showExportSheet) {
                if let image = renderedExportImage {
                    ExportArtworkSheet(
                        artworkImage: image,
                        canvasSize: currentCanvasRenderSize,
                        aspectRatio: aspectRatio
                    )
                }
            }
            .alert("Clear Canvas?", isPresented: $showClearConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear All", role: .destructive) {
                    clearCanvas()
                }
            } message: {
                Text("This will remove all stickers and text items from the canvas. You can undo this action.")
            }
            .alert(photoLibraryManager.alertMessage ?? "", isPresented: $photoLibraryManager.showAlert) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    // MARK: - Top Action Bar (Undo, Redo, Clear, Bounds Toggle, Export)

    private var topActionBar: some View {
        HStack(spacing: 12) {
            // Undo Button
            Button {
                undoAction()
            } label: {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(historyManager.canUndo ? .primary : Color.secondary.opacity(0.4))
            }
            .disabled(!historyManager.canUndo)
            .accessibilityLabel("Undo")

            // Redo Button
            Button {
                redoAction()
            } label: {
                Image(systemName: "arrow.uturn.forward.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(historyManager.canRedo ? .primary : Color.secondary.opacity(0.4))
            }
            .disabled(!historyManager.canRedo)
            .accessibilityLabel("Redo")

            // Clear Canvas Button
            Button {
                if !items.isEmpty {
                    showClearConfirmation = true
                }
            } label: {
                Image(systemName: "trash.circle")
                    .font(.system(size: 24))
                    .foregroundColor(items.isEmpty ? Color.secondary.opacity(0.4) : .red)
            }
            .disabled(items.isEmpty)
            .accessibilityLabel("Clear Canvas")

            Spacer()

            // Bounding Box Toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showBoundingBox.toggle()
                    if let activeId = activeItemId, let index = items.firstIndex(where: { $0.id == activeId }) {
                        items[index].boundsVisible = showBoundingBox
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: showBoundingBox ? "rectangle.dashed.badge.record" : "rectangle.dashed")
                        .font(.system(size: 15, weight: .semibold))
                    Text(showBoundingBox ? "Bounds On" : "Bounds Off")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(showBoundingBox ? Color.accentColor.opacity(0.15) : Color(uiColor: .tertiarySystemFill))
                .foregroundColor(showBoundingBox ? .accentColor : .secondary)
                .clipShape(Capsule())
            }

            // Export Button (Prepares high-res isolated render)
            Button {
                prepareAndPresentExport()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .bold))
                    Text("Export")
                        .font(.system(size: 13, weight: .bold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(Capsule())
                .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
            }
        }
    }

    // MARK: - Aspect Ratio Selector Bar

    private var aspectRatioSelectorBar: some View {
        HStack(spacing: 8) {
            Text("Ratio:")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)

            ForEach(CanvasAspectRatio.allCases) { ratio in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        recordHistorySnapshot()
                        aspectRatio = ratio
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: ratio.icon)
                            .font(.system(size: 11))
                        Text(ratio.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(aspectRatio == ratio ? Color.primary : Color(uiColor: .secondarySystemBackground))
                    .foregroundColor(aspectRatio == ratio ? Color(uiColor: .systemBackground) : .primary)
                    .clipShape(Capsule())
                }
            }

            Spacer()
        }
    }

    // MARK: - Interactive Canvas

    private func interactiveCanvas(size: CGSize) -> some View {
        ZStack {
            // Layer 1: Background Fill
            canvasBackgroundLayer(size: size)
                .contentShape(Rectangle())
                .onTapGesture {
                    // Deselect active item when tapping canvas background
                    withAnimation(.easeInOut(duration: 0.15)) {
                        activeItemId = nil
                    }
                }

            // Layer 2: Canvas Items (Image stickers and text)
            ForEach(items) { item in
                let isActive = item.id == activeItemId

                CanvasItemInteractiveView(
                    item: item,
                    isActive: isActive,
                    showBoundingBox: showBoundingBox && item.boundsVisible,
                    activeDragOffset: isActive ? gestureDragOffset : .zero,
                    activeScale: isActive ? gestureScale : 1.0,
                    activeRotation: isActive ? gestureRotation : .zero,
                    onTap: {
                        bringToFront(item)
                    },
                    onDelete: {
                        deleteItem(item)
                    }
                )
                // Attach combined gestures exclusively to the active item
                .simultaneousGesture(
                    isActive ? combinedTransformGesture(for: item, canvasSize: size) : nil
                )
                .simultaneousGesture(
                    isActive ? dragItemGesture(for: item, canvasSize: size) : nil
                )
            }

            // Empty State Hint
            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "hand.draw")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Add a sticker, text, or drop an image here")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
        }
        // Native Drag-and-Drop Image Handler
        .onDrop(of: [UTType.image.identifier], isTargeted: $isDropTargeted) { providers, location in
            handleDroppedImage(providers: providers, dropLocation: location, canvasSize: size)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isDropTargeted ? Color.accentColor : Color.clear, lineWidth: 3)
        )
    }

    // MARK: - Canvas Background Layer

    @ViewBuilder
    private func canvasBackgroundLayer(size: CGSize) -> some View {
        switch canvasBackground {
        case .color(let color):
            color
                .frame(width: size.width, height: size.height)

        case .gradient(let colors):
            LinearGradient(
                colors: colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: size.width, height: size.height)

        case .photo(let uiImage):
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
        }
    }

    // MARK: - Trash Zone Overlay

    private func trashZoneOverlay(canvasSize: CGSize) -> some View {
        VStack {
            Spacer()

            HStack(spacing: 8) {
                Image(systemName: isHoveringTrash ? "trash.fill" : "trash")
                    .font(.system(size: isHoveringTrash ? 24 : 18, weight: .bold))
                Text(isHoveringTrash ? "Release to Delete" : "Drag here to Delete")
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, isHoveringTrash ? 22 : 16)
            .padding(.vertical, isHoveringTrash ? 14 : 10)
            .background(
                Capsule()
                    .fill(isHoveringTrash ? Color.red : Color.black.opacity(0.75))
                    .shadow(color: isHoveringTrash ? Color.red.opacity(0.6) : Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
            )
            .foregroundColor(.white)
            .scaleEffect(isHoveringTrash ? 1.15 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isHoveringTrash)
            .padding(.bottom, 20)
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }

    // MARK: - Bottom Studio Panel

    private var bottomEditorStudio: some View {
        VStack(spacing: 0) {
            Divider()

            // Studio Mode Tab Selector
            HStack {
                ForEach(EditorBottomTab.allCases) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentTab = tab
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 18))
                            Text(tab.rawValue)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(currentTab == tab ? .accentColor : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            currentTab == tab ?
                                Color.accentColor.opacity(0.08) : Color.clear
                        )
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)

            Divider()

            // Tab Content Panel
            Group {
                switch currentTab {
                case .stickers:
                    stickersControlPanel
                case .text:
                    textControlPanel
                case .background:
                    backgroundControlPanel
                case .layers:
                    layersControlPanel
                }
            }
            .frame(height: 125)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
        }
    }

    // MARK: - Panel: Stickers

    private var stickersControlPanel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                // PhotosPicker for adding custom photo sticker
                PhotosPicker(
                    selection: $selectedStickerPhotoItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    VStack(spacing: 6) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 26))
                            .foregroundColor(.accentColor)
                        Text("Add Photo")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .frame(width: 80, height: 95)
                    .background(Color(uiColor: .systemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1.5)
                    )
                }
                .onChange(of: selectedStickerPhotoItem) { newItem in
                    guard let newItem = newItem else { return }
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            await MainActor.run {
                                addImageSticker(image)
                                selectedStickerPhotoItem = nil
                            }
                        }
                    }
                }

                // Preset Vector / Emoji Stickers
                ForEach(SampleStickers.all, id: \.name) { sticker in
                    Button {
                        if let image = sticker.renderImage() {
                            addImageSticker(image)
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Text(sticker.emoji)
                                .font(.system(size: 34))
                            Text(sticker.name)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 72, height: 95)
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Panel: Text

    private var textControlPanel: some View {
        HStack(spacing: 16) {
            Button {
                showTextEditorSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.bubble.fill")
                        .font(.system(size: 20))
                    Text("Add New Text")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity, maxHeight: 70)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }

            if let activeId = activeItemId,
               let item = items.first(where: { $0.id == activeId }),
               case .text(let str, _, _) = item.itemType {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active Text: \"\(str.prefix(15))\"")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)

                    Text("Pinch to scale or rotate directly on canvas")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
            }
        }
    }

    // MARK: - Panel: Background Control

    private var backgroundControlPanel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                // Color Picker for Solid Color
                VStack(spacing: 4) {
                    ColorPicker("", selection: $selectedBackgroundColor)
                        .labelsHidden()
                        .onChange(of: selectedBackgroundColor) { newColor in
                            recordHistorySnapshot()
                            canvasBackground = .color(newColor)
                        }
                    Text("Solid")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(width: 60, height: 90)
                .background(Color(uiColor: .systemBackground))
                .cornerRadius(12)

                // PhotosPicker for Background Photo
                PhotosPicker(
                    selection: $selectedBgPhotoItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    VStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 22))
                            .foregroundColor(.blue)
                        Text("Photo")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .frame(width: 60, height: 90)
                    .background(Color(uiColor: .systemBackground))
                    .cornerRadius(12)
                }
                .onChange(of: selectedBgPhotoItem) { newItem in
                    guard let newItem = newItem else { return }
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            await MainActor.run {
                                recordHistorySnapshot()
                                canvasBackground = .photo(image)
                                selectedBgPhotoItem = nil
                            }
                        }
                    }
                }

                // Preset Gradients Carousel
                ForEach(GradientPreset.presets) { preset in
                    Button {
                        recordHistorySnapshot()
                        canvasBackground = .gradient(preset.colors)
                    } label: {
                        VStack(spacing: 4) {
                            LinearGradient(
                                colors: preset.colors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(Color.white, lineWidth: 2)
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 3)

                            Text(preset.name)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        .frame(width: 65, height: 90)
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Panel: Layers & Transformations

    private var layersControlPanel: some View {
        HStack(spacing: 12) {
            if let activeId = activeItemId, let item = items.first(where: { $0.id == activeId }) {
                Button {
                    bringToFront(item)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "square.3.layers.3d.top.filled")
                            .font(.system(size: 20))
                        Text("To Front")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .frame(maxWidth: .infinity, maxHeight: 75)
                    .background(Color(uiColor: .systemBackground))
                    .cornerRadius(10)
                }

                Button {
                    sendToBack(item)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "square.3.layers.3d.bottom.filled")
                            .font(.system(size: 20))
                        Text("To Back")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .frame(maxWidth: .infinity, maxHeight: 75)
                    .background(Color(uiColor: .systemBackground))
                    .cornerRadius(10)
                }

                Button {
                    duplicateItem(item)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "plus.square.on.square")
                            .font(.system(size: 20))
                        Text("Duplicate")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .frame(maxWidth: .infinity, maxHeight: 75)
                    .background(Color(uiColor: .systemBackground))
                    .cornerRadius(10)
                }

                Button {
                    deleteItem(item)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 20))
                        Text("Delete")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .frame(maxWidth: .infinity, maxHeight: 75)
                    .foregroundColor(.red)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                }
            } else {
                Text("Tap any sticker or text item on canvas to arrange layers.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    // MARK: - Gestures: Pinch & Rotation (Simultaneous)

    private func combinedTransformGesture(for item: CanvasItem, canvasSize: CGSize) -> some Gesture {
        let magnification = MagnificationGesture()
            .onChanged { scale in
                gestureScale = scale
            }
            .onEnded { finalScale in
                if let index = items.firstIndex(where: { $0.id == item.id }) {
                    recordHistorySnapshot()
                    items[index].scale = max(0.2, min(5.0, items[index].scale * finalScale))
                }
                gestureScale = 1.0
            }

        let rotation = RotationGesture()
            .onChanged { angle in
                gestureRotation = angle
            }
            .onEnded { finalAngle in
                if let index = items.firstIndex(where: { $0.id == item.id }) {
                    recordHistorySnapshot()
                    items[index].rotation += finalAngle
                }
                gestureRotation = .zero
            }

        return SimultaneousGesture(magnification, rotation)
    }

    // MARK: - Gestures: Drag & Trash Detection

    private func dragItemGesture(for item: CanvasItem, canvasSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                isDraggingItem = true
                gestureDragOffset = value.translation

                // Trash detection calculation: bottom 85pt of canvas
                let currentItemY = item.position.y + value.translation.height
                let wasHovering = isHoveringTrash
                let nowHovering = currentItemY > (canvasSize.height - 85)

                if nowHovering != wasHovering {
                    isHoveringTrash = nowHovering
                    if nowHovering {
                        HapticManager.shared.lightImpact()
                    }
                }
            }
            .onEnded { value in
                isDraggingItem = false

                if isHoveringTrash {
                    // Item dropped into trash zone: delete!
                    deleteItem(item)
                    HapticManager.shared.notification(type: .success)
                } else {
                    // Update item position
                    if let index = items.firstIndex(where: { $0.id == item.id }) {
                        recordHistorySnapshot()
                        items[index].position.x += value.translation.width
                        items[index].position.y += value.translation.height
                    }
                }

                gestureDragOffset = .zero
                isHoveringTrash = false
            }
    }

    // MARK: - Canvas Actions & Operations

    private func bringToFront(_ item: CanvasItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        recordHistorySnapshot()
        let removed = items.remove(at: index)
        items.append(removed)
        activeItemId = removed.id
        HapticManager.shared.lightImpact()
    }

    private func sendToBack(_ item: CanvasItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        recordHistorySnapshot()
        let removed = items.remove(at: index)
        items.insert(removed, at: 0)
        activeItemId = removed.id
        HapticManager.shared.lightImpact()
    }

    private func duplicateItem(_ item: CanvasItem) {
        recordHistorySnapshot()
        let duplicated = CanvasItem(
            itemType: item.itemType,
            position: CGPoint(x: item.position.x + 20, y: item.position.y + 20),
            scale: item.scale,
            rotation: item.rotation,
            boundsVisible: item.boundsVisible
        )
        items.append(duplicated)
        activeItemId = duplicated.id
        HapticManager.shared.lightImpact()
    }

    private func deleteItem(_ item: CanvasItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        recordHistorySnapshot()
        items.remove(at: index)
        if activeItemId == item.id {
            activeItemId = nil
        }
        HapticManager.shared.lightImpact()
    }

    private func clearCanvas() {
        recordHistorySnapshot()
        items.removeAll()
        activeItemId = nil
        HapticManager.shared.notification(type: .warning)
    }

    private func addImageSticker(_ image: UIImage) {
        recordHistorySnapshot()
        let center = CGPoint(x: currentCanvasRenderSize.width / 2, y: currentCanvasRenderSize.height / 2)
        let newItem = CanvasItem(
            itemType: .image(image),
            position: center,
            scale: 1.0,
            rotation: .zero,
            boundsVisible: showBoundingBox
        )
        items.append(newItem)
        activeItemId = newItem.id
        HapticManager.shared.lightImpact()
    }

    private func addTextItem(text: String, color: Color, font: Font) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        recordHistorySnapshot()
        let center = CGPoint(x: currentCanvasRenderSize.width / 2, y: currentCanvasRenderSize.height / 2)
        let newItem = CanvasItem(
            itemType: .text(text, color, font),
            position: center,
            scale: 1.0,
            rotation: .zero,
            boundsVisible: showBoundingBox
        )
        items.append(newItem)
        activeItemId = newItem.id
        HapticManager.shared.lightImpact()
    }

    // MARK: - Native Drag and Drop

    private func handleDroppedImage(providers: [NSItemProvider], dropLocation: CGPoint, canvasSize: CGSize) -> Bool {
        guard let provider = providers.first else { return false }

        _ = provider.loadObject(ofClass: UIImage.self) { image, _ in
            if let droppedImage = image as? UIImage {
                DispatchQueue.main.async {
                    recordHistorySnapshot()
                    let newItem = CanvasItem(
                        itemType: .image(droppedImage),
                        position: dropLocation,
                        scale: 1.0,
                        rotation: .zero,
                        boundsVisible: self.showBoundingBox
                    )
                    self.items.append(newItem)
                    self.activeItemId = newItem.id
                    HapticManager.shared.lightImpact()
                }
            }
        }
        return true
    }

    // MARK: - Undo / Redo Operations

    private func recordHistorySnapshot() {
        let snapshot = CanvasSnapshot(
            items: items,
            background: canvasBackground,
            aspectRatio: aspectRatio
        )
        historyManager.registerSnapshot(snapshot)
    }

    private func undoAction() {
        let currentSnapshot = CanvasSnapshot(
            items: items,
            background: canvasBackground,
            aspectRatio: aspectRatio
        )
        if let restored = historyManager.undo(currentSnapshot: currentSnapshot) {
            items = restored.items
            canvasBackground = restored.background
            aspectRatio = restored.aspectRatio
            activeItemId = nil
            HapticManager.shared.lightImpact()
        }
    }

    private func redoAction() {
        let currentSnapshot = CanvasSnapshot(
            items: items,
            background: canvasBackground,
            aspectRatio: aspectRatio
        )
        if let restored = historyManager.redo(currentSnapshot: currentSnapshot) {
            items = restored.items
            canvasBackground = restored.background
            aspectRatio = restored.aspectRatio
            activeItemId = nil
            HapticManager.shared.lightImpact()
        }
    }

    // MARK: - High-Res Isolated Export

    private func prepareAndPresentExport() {
        // High-res isolated view capture via ImageRenderer with UIScreen.main.scale
        if let rendered = ArtworkRenderService.renderHighResImage(
            items: items,
            background: canvasBackground,
            canvasSize: currentCanvasRenderSize
        ) {
            renderedExportImage = rendered
            showExportSheet = true
            HapticManager.shared.lightImpact()
        }
    }

    // MARK: - Canvas Sizing Helper

    private func calculateCanvasSize(in containerSize: CGSize, for ratio: CanvasAspectRatio) -> CGSize {
        let horizontalPadding: CGFloat = 24
        let verticalPadding: CGFloat = 24
        let maxWidth = max(100, containerSize.width - horizontalPadding)
        let maxHeight = max(100, containerSize.height - verticalPadding)

        let targetRatio = ratio.ratio
        var calculatedWidth = maxWidth
        var calculatedHeight = calculatedWidth / targetRatio

        if calculatedHeight > maxHeight {
            calculatedHeight = maxHeight
            calculatedWidth = calculatedHeight * targetRatio
        }

        return CGSize(width: calculatedWidth, height: calculatedHeight)
    }

    // MARK: - Initial Sample Stickers

    private func loadDefaultSampleStickers(canvasSize: CGSize) {
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)

        let welcomeText = CanvasItem(
            itemType: .text("Create Magic ✨", .white, .system(size: 32, weight: .heavy, design: .rounded)),
            position: CGPoint(x: center.x, y: center.y - 30),
            scale: 1.0,
            rotation: .zero,
            boundsVisible: true
        )

        if let starImage = SampleStickers.all[0].renderImage() {
            let starItem = CanvasItem(
                itemType: .image(starImage),
                position: CGPoint(x: center.x + 80, y: center.y + 50),
                scale: 1.1,
                rotation: Angle(degrees: 15),
                boundsVisible: false
            )
            items = [welcomeText, starItem]
        } else {
            items = [welcomeText]
        }
        activeItemId = welcomeText.id
    }
}

// MARK: - Canvas Item Interactive View (with Bounding Box & Handles)

private struct CanvasItemInteractiveView: View {
    let item: CanvasItem
    let isActive: Bool
    let showBoundingBox: Bool
    let activeDragOffset: CGSize
    let activeScale: CGFloat
    let activeRotation: Angle
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ItemContentRawView(item: item)
            .overlay(
                // Bounding Box Overlay with Corner Dots and Delete Badge
                Group {
                    if isActive && showBoundingBox {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(
                                    Color.accentColor,
                                    style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                                )
                                .padding(-10)

                            // Corner Handles
                            ForEach([-1.0, 1.0], id: \.self) { xSign in
                                ForEach([-1.0, 1.0], id: \.self) { ySign in
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 10, height: 10)
                                        .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
                                        .offset(x: xSign * 35, y: ySign * 35)
                                }
                            }

                            // Quick Delete Handle at Top-Right
                            VStack {
                                HStack {
                                    Spacer()
                                    Button(action: onDelete) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(.red)
                                            .background(Circle().fill(Color.white))
                                    }
                                    .offset(x: 16, y: -16)
                                }
                                Spacer()
                            }
                        }
                    }
                }
            )
            .scaleEffect(item.scale * activeScale)
            .rotationEffect(item.rotation + activeRotation)
            .position(
                x: item.position.x + activeDragOffset.width,
                y: item.position.y + activeDragOffset.height
            )
            .onTapGesture {
                onTap()
            }
    }
}

// MARK: - Text Entry Modal Sheet

private struct TextEntrySheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var textInput: String = ""
    @State private var selectedColor: Color = .white
    @State private var fontSize: CGFloat = 28
    @State private var selectedDesign: Font.Design = .rounded
    @State private var isBold: Bool = true

    let onCommit: (String, Color, Font) -> Void

    private let colorPalette: [Color] = [
        .white, .black, .yellow, .orange, .pink, .red,
        .purple, .blue, .cyan, .green, .mint
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Live Text Preview Area
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.85))

                    Text(textInput.isEmpty ? "Type Something..." : textInput)
                        .font(makeFont())
                        .foregroundColor(selectedColor)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .frame(height: 140)
                .padding(.horizontal)

                // Text Input Field
                TextField("Enter sticker text", text: $textInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 16))
                    .padding(.horizontal)

                // Font Size Slider
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Font Size")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Text("\(Int(fontSize)) pt")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $fontSize, in: 16...64, step: 2)
                }
                .padding(.horizontal)

                // Font Design Selector
                HStack(spacing: 8) {
                    fontDesignButton(name: "Rounded", design: .rounded)
                    fontDesignButton(name: "Default", design: .default)
                    fontDesignButton(name: "Serif", design: .serif)
                    fontDesignButton(name: "Mono", design: .monospaced)
                }
                .padding(.horizontal)

                // Color Swatches & ColorPicker
                HStack(spacing: 10) {
                    ColorPicker("", selection: $selectedColor)
                        .labelsHidden()

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(colorPalette, id: \.self) { color in
                                Circle()
                                    .fill(color)
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle().stroke(selectedColor == color ? Color.primary : Color.gray.opacity(0.3), lineWidth: selectedColor == color ? 3 : 1)
                                    )
                                    .onTapGesture {
                                        selectedColor = color
                                    }
                            }
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 16)
            .navigationTitle("Add Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        onCommit(textInput, selectedColor, makeFont())
                        dismiss()
                    }
                    .font(.headline)
                    .disabled(textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func makeFont() -> Font {
        .system(size: fontSize, weight: isBold ? .bold : .regular, design: selectedDesign)
    }

    private func fontDesignButton(name: String, design: Font.Design) -> some View {
        Button {
            selectedDesign = design
        } label: {
            Text(name)
                .font(.system(size: 12, weight: .semibold, design: design))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(selectedDesign == design ? Color.accentColor : Color(uiColor: .tertiarySystemFill))
                .foregroundColor(selectedDesign == design ? .white : .primary)
                .cornerRadius(8)
        }
    }
}

// MARK: - Export Artwork Sheet (ShareLink & Camera Roll)

private struct ExportArtworkSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var photoManager = PhotoLibraryManager.shared

    let artworkImage: UIImage
    let canvasSize: CGSize
    let aspectRatio: CanvasAspectRatio

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Isolated Artwork Preview (strictly artwork only, no status bar, no UI elements)
                Image(uiImage: artworkImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 380)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 6)
                    .padding()

                // High-Res Specs Badge
                HStack(spacing: 16) {
                    Label("\(Int(artworkImage.size.width * artworkImage.scale)) × \(Int(artworkImage.size.height * artworkImage.scale)) px", systemImage: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                    Label("\(aspectRatio.rawValue)", systemImage: "aspectratio")
                        .font(.system(size: 12, weight: .semibold))
                    Label("Retina Scale", systemImage: "display")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(20)

                // ShareLink & Save Buttons
                VStack(spacing: 12) {
                    // Standard SwiftUI ShareLink
                    ShareLink(
                        item: ArtworkExportItem(uiImage: artworkImage, title: "Artwork Creation"),
                        preview: SharePreview("Artwork Export", image: Image(uiImage: artworkImage))
                    ) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .bold))
                            Text("Share Artwork via ShareSheet")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }

                    // Save to Camera Roll Button
                    Button {
                        photoManager.saveToCameraRoll(image: artworkImage)
                    } label: {
                        HStack {
                            if photoManager.isSaving {
                                ProgressView()
                                    .tint(.primary)
                            } else {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 16, weight: .bold))
                                Text("Save to Camera Roll")
                                    .font(.system(size: 15, weight: .bold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .foregroundColor(.primary)
                        .cornerRadius(14)
                    }
                    .disabled(photoManager.isSaving)
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .navigationTitle("Export Artwork")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.headline)
                }
            }
        }
    }
}

// MARK: - Built-in Sample Sticker Generator

private struct SampleStickerItem {
    let name: String
    let emoji: String

    func renderImage() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 120))
        return renderer.image { _ in
            let font = UIFont.systemFont(ofSize: 80)
            let attributes: [NSAttributedString.Key: Any] = [.font: font]
            let string = NSAttributedString(string: emoji, attributes: attributes)
            let size = string.size()
            let rect = CGRect(
                x: (120 - size.width) / 2,
                y: (120 - size.height) / 2,
                width: size.width,
                height: size.height
            )
            string.draw(in: rect)
        }
    }
}

private enum SampleStickers {
    static let all: [SampleStickerItem] = [
        SampleStickerItem(name: "Star", emoji: "⭐"),
        SampleStickerItem(name: "Heart", emoji: "❤️"),
        SampleStickerItem(name: "Sparkles", emoji: "✨"),
        SampleStickerItem(name: "Fire", emoji: "🔥"),
        SampleStickerItem(name: "Crown", emoji: "👑"),
        SampleStickerItem(name: "Cool", emoji: "😎"),
        SampleStickerItem(name: "Rocket", emoji: "🚀"),
        SampleStickerItem(name: "Rainbow", emoji: "🌈"),
        SampleStickerItem(name: "Coffee", emoji: "☕"),
        SampleStickerItem(name: "Planet", emoji: "🪐")
    ]
}

// MARK: - Preview Provider

#Preview {
    EditorCanvasView()
}
